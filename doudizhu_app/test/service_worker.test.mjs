import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const appRoot = join(dirname(fileURLToPath(import.meta.url)), '..');

function loadWorker(options = {}) {
  const handlers = new Map();
  const addedUrls = [];
  const deletedCaches = [];
  let skipWaitingCalls = 0;
  let claimCalls = 0;
  let fetchCalls = 0;
  const cacheKeys = options.cacheKeys || ['doudizhu-shell-v1'];
  const cache = {
    add: async url => { addedUrls.push(String(url)); },
    put: async () => {},
  };
  const caches = {
    open: async () => cache,
    keys: async () => cacheKeys,
    delete: async key => { deletedCaches.push(key); return true; },
    match: async () => options.cachedResponse,
  };
  const self = {
    registration: { scope: 'https://example.test/repo/doudizhu_app/' },
    clients: { claim: async () => { claimCalls += 1; } },
    addEventListener: (type, handler) => handlers.set(type, handler),
    skipWaiting: () => { skipWaitingCalls += 1; },
  };
  const fetch = async request => {
    fetchCalls += 1;
    if (options.networkError) throw new Error('offline');
    return new Response(`network:${request.url}`);
  };
  vm.runInNewContext(readFileSync(join(appRoot, 'sw.js'), 'utf8'), {
    self, caches, fetch, URL, Response, Promise,
  });

  return {
    addedUrls,
    deletedCaches,
    get skipWaitingCalls() { return skipWaitingCalls; },
    get claimCalls() { return claimCalls; },
    get fetchCalls() { return fetchCalls; },
    async dispatchExtendable(type) {
      let work = Promise.resolve();
      handlers.get(type)({ waitUntil(promise) { work = Promise.resolve(promise); } });
      await work;
    },
    dispatchMessage(data) { handlers.get('message')({ data }); },
    async dispatchFetch(url, mode = 'cors') {
      let responsePromise;
      handlers.get('fetch')({
        request: { url, method: 'GET', mode },
        respondWith(promise) { responsePromise = Promise.resolve(promise); },
      });
      return responsePromise;
    },
  };
}

test('install precaches the complete shell without skipping waiting', async () => {
  const h = loadWorker();
  await h.dispatchExtendable('install');
  assert.deepEqual(h.addedUrls, [
    'https://example.test/repo/doudizhu_app/preview.html',
    'https://example.test/repo/doudizhu_app/manifest.webmanifest',
    'https://example.test/repo/doudizhu_app/icons/icon-192.png',
    'https://example.test/repo/doudizhu_app/icons/icon-512.png',
    'https://example.test/repo/doudizhu_app/icons/maskable-192.png',
    'https://example.test/repo/doudizhu_app/icons/maskable-512.png',
  ]);
  assert.equal(h.skipWaitingCalls, 0);
});

test('SKIP_WAITING message is the only path that activates immediately', async () => {
  const h = loadWorker();
  h.dispatchMessage({ type: 'OTHER' });
  assert.equal(h.skipWaitingCalls, 0);
  h.dispatchMessage({ type: 'SKIP_WAITING' });
  assert.equal(h.skipWaitingCalls, 1);
});

test('activate deletes old shell caches and claims clients', async () => {
  const h = loadWorker({ cacheKeys: ['doudizhu-shell-v0', 'doudizhu-shell-v1', 'unrelated-cache'] });
  await h.dispatchExtendable('activate');
  assert.deepEqual(h.deletedCaches, ['doudizhu-shell-v0']);
  assert.equal(h.claimCalls, 1);
});

test('known shell requests are cache-first without background fetch', async () => {
  const h = loadWorker({ cachedResponse: new Response('cached') });
  const response = await h.dispatchFetch('https://example.test/repo/doudizhu_app/preview.html');
  assert.equal(await response.text(), 'cached');
  assert.equal(h.fetchCalls, 0);
});

test('unknown same-scope GET falls back from network to cache then offline response', async () => {
  const cached = loadWorker({ networkError: true, cachedResponse: new Response('fallback') });
  assert.equal(await (await cached.dispatchFetch('https://example.test/repo/doudizhu_app/other.txt')).text(), 'fallback');
  const missing = loadWorker({ networkError: true, cachedResponse: undefined });
  const response = await missing.dispatchFetch('https://example.test/repo/doudizhu_app/missing.txt');
  assert.equal(response.status, 503);
});