const SCOPE_PATH = new URL(self.registration.scope).pathname.replace(/\/+$/, '') || '/';
const CACHE_PREFIX = `doudizhu-shell-${encodeURIComponent(SCOPE_PATH)}::`;
const CACHE_NAME = CACHE_PREFIX + 'v3';
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
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(shellUrls())));
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
    const cache = await caches.open(CACHE_NAME);
    const known = shellUrls().includes(request.url);
    if (known || request.mode === 'navigate') {
      return (await cache.match(request)) ||
        (request.mode === 'navigate' && await cache.match(new URL('./preview.html', self.registration.scope).href)) ||
        fetch(request);
    }
    try {
      const response = await fetch(request);
      await cache.put(request, response.clone());
      return response;
    } catch (_) {
      return (await cache.match(request)) ||
        new Response('当前离线，资源尚未缓存。', { status: 503, headers: { 'Content-Type': 'text/plain; charset=utf-8' } });
    }
  })());
});
