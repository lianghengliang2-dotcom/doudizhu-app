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
  const addAllCalls = [];
  const openedCaches = [];
  const deletedCaches = [];
  const cacheMatchCalls = [];
  const globalMatchCalls = [];
  let skipWaitingCalls = 0;
  let claimCalls = 0;
  let fetchCalls = 0;
  const cacheKeys = options.cacheKeys || ['doudizhu-shell-%2Frepo%2Fdoudizhu_app::v4'];
  const cache = {
    add: async url => {
      addedUrls.push(String(url));
      if (options.precacheError) throw options.precacheError;
    },
    addAll: async urls => {
      const normalized = [...urls].map(String);
      addAllCalls.push(normalized);
      if (options.precacheError) throw options.precacheError;
      addedUrls.push(...normalized);
    },
    match: async request => {
      cacheMatchCalls.push(request);
      return options.cachedResponse;
    },
    put: async () => {},
  };
  const caches = {
    open: async name => { openedCaches.push(name); return cache; },
    keys: async () => cacheKeys,
    delete: async key => { deletedCaches.push(key); return true; },
    match: async request => {
      globalMatchCalls.push(request);
      return options.globalCachedResponse;
    },
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
    addAllCalls,
    openedCaches,
    deletedCaches,
    cacheMatchCalls,
    globalMatchCalls,
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
  const expected = [
    'https://example.test/repo/doudizhu_app/preview.html',
    'https://example.test/repo/doudizhu_app/manifest.webmanifest',
    'https://example.test/repo/doudizhu_app/icons/icon-192.png',
    'https://example.test/repo/doudizhu_app/icons/icon-512.png',
    'https://example.test/repo/doudizhu_app/icons/maskable-192.png',
    'https://example.test/repo/doudizhu_app/icons/maskable-512.png',
  ];
  assert.deepEqual(h.addAllCalls, [expected]);
  assert.deepEqual(h.addedUrls, expected);
  assert.equal(h.skipWaitingCalls, 0);
});

test('install rejects atomically when any required shell resource fails', async () => {
  const failure = new Error('required shell resource failed');
  const h = loadWorker({ precacheError: failure });
  await assert.rejects(h.dispatchExtendable('install'), failure);
  assert.equal(h.addAllCalls.length, 1);
  assert.equal(h.skipWaitingCalls, 0);
});

test('SKIP_WAITING message is the only path that activates immediately', async () => {
  const h = loadWorker();
  h.dispatchMessage({ type: 'OTHER' });
  assert.equal(h.skipWaitingCalls, 0);
  h.dispatchMessage({ type: 'SKIP_WAITING' });
  assert.equal(h.skipWaitingCalls, 1);
});

test('activate deletes older same-scope shell caches and claims clients', async () => {
  const h = loadWorker({
    cacheKeys: [
      'doudizhu-shell-%2Frepo%2Fdoudizhu_app::v0',
      'doudizhu-shell-%2Frepo%2Fdoudizhu_app::v1',
      'doudizhu-shell-%2Frepo%2Fdoudizhu_app::v2',
      'doudizhu-shell-%2Frepo%2Fdoudizhu_app::v3',
      'doudizhu-shell-%2Frepo%2Fdoudizhu_app::v4',
      'doudizhu-shell-%2Frepo%2Fdoudizhu_app-v2::v0',
      'doudizhu-shell-%2Frepo%2Fother_app::v0',
      'unrelated-cache',
    ],
  });
  await h.dispatchExtendable('activate');
  assert.deepEqual(h.deletedCaches, [
    'doudizhu-shell-%2Frepo%2Fdoudizhu_app::v0',
    'doudizhu-shell-%2Frepo%2Fdoudizhu_app::v1',
    'doudizhu-shell-%2Frepo%2Fdoudizhu_app::v2',
    'doudizhu-shell-%2Frepo%2Fdoudizhu_app::v3',
  ]);
  assert.equal(h.claimCalls, 1);
});

test('v4 release opens the current cache, retires v1 through v3, and preserves other scopes', async () => {
  const h = loadWorker({
    cacheKeys: [
      'doudizhu-shell-%2Frepo%2Fdoudizhu_app::v1',
      'doudizhu-shell-%2Frepo%2Fdoudizhu_app::v2',
      'doudizhu-shell-%2Frepo%2Fdoudizhu_app::v3',
      'doudizhu-shell-%2Frepo%2Fdoudizhu_app::v4',
      'doudizhu-shell-%2Frepo%2Fdoudizhu_app-v4::v3',
      'doudizhu-shell-%2Frepo%2Fother_app::v3',
    ],
  });
  await h.dispatchExtendable('install');
  await h.dispatchExtendable('activate');
  assert.ok(h.openedCaches.includes('doudizhu-shell-%2Frepo%2Fdoudizhu_app::v4'));
  assert.deepEqual(h.deletedCaches, [
    'doudizhu-shell-%2Frepo%2Fdoudizhu_app::v1',
    'doudizhu-shell-%2Frepo%2Fdoudizhu_app::v2',
    'doudizhu-shell-%2Frepo%2Fdoudizhu_app::v3',
  ]);
});

test('known shell requests use the current scope cache without a global lookup or background fetch', async () => {
  const h = loadWorker({
    cachedResponse: new Response('current-scope'),
    globalCachedResponse: new Response('other-scope'),
  });
  const response = await h.dispatchFetch('https://example.test/repo/doudizhu_app/preview.html');
  assert.equal(await response.text(), 'current-scope');
  assert.equal(h.cacheMatchCalls.length, 1);
  assert.equal(h.globalMatchCalls.length, 0);
  assert.equal(h.fetchCalls, 0);
});

test('unknown same-scope GET falls back from network to cache then offline response', async () => {
  const cached = loadWorker({
    networkError: true,
    cachedResponse: new Response('fallback'),
    globalCachedResponse: new Response('other-scope'),
  });
  assert.equal(await (await cached.dispatchFetch('https://example.test/repo/doudizhu_app/other.txt')).text(), 'fallback');
  assert.equal(cached.cacheMatchCalls.length, 1);
  assert.equal(cached.globalMatchCalls.length, 0);
  const missing = loadWorker({ networkError: true, cachedResponse: undefined });
  const response = await missing.dispatchFetch('https://example.test/repo/doudizhu_app/missing.txt');
  assert.equal(response.status, 503);
});
