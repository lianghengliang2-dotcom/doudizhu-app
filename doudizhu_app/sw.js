const CACHE_PREFIX = 'doudizhu-shell-';
const CACHE_NAME = CACHE_PREFIX + 'v1';
const SHELL_PATHS = [
  './preview.html',
  './manifest.webmanifest',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './icons/maskable-192.png',
  './icons/maskable-512.png',
];
const shellUrls = () => SHELL_PATHS.map(path => new URL(path, self.registration.scope).href);

self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE_NAME).then(async cache => {
    for (const url of shellUrls()) {
      try { await cache.add(url); } catch (_) {}
    }
  }));
});

self.addEventListener('activate', event => {
  event.waitUntil(Promise.all([
    caches.keys().then(keys => Promise.all(
      keys.filter(key => key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME)
        .map(key => caches.delete(key))
    )),
    self.clients.claim(),
  ]));
});

self.addEventListener('message', event => {
  if (event.data && event.data.type === 'SKIP_WAITING') self.skipWaiting();
});

self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET' || new URL(request.url).origin !== new URL(self.registration.scope).origin) return;
  event.respondWith((async () => {
    const known = shellUrls().includes(request.url);
    if (known || request.mode === 'navigate') {
      return (await caches.match(request)) ||
        (request.mode === 'navigate' && await caches.match(new URL('./preview.html', self.registration.scope).href)) ||
        fetch(request);
    }
    try {
      const response = await fetch(request);
      const cache = await caches.open(CACHE_NAME);
      await cache.put(request, response.clone());
      return response;
    } catch (_) {
      return (await caches.match(request)) ||
        new Response('当前离线，资源尚未缓存。', { status: 503, headers: { 'Content-Type': 'text/plain; charset=utf-8' } });
    }
  })());
});