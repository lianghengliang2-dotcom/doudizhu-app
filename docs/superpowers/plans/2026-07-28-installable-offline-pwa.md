# Installable Offline PWA Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `doudizhu_app/preview.html` into an installable PWA that continues to open, score, undo, and show history after the phone goes fully offline.

**Architecture:** Keep the existing single-page application and `localStorage` data model unchanged. Add a relative-path web manifest, deterministic PNG icons, a versioned cache-first Service Worker, and a small page-side update controller that lets a waiting worker activate without interrupting a game.

**Tech Stack:** Static HTML/CSS/JavaScript, Web App Manifest, Service Worker API, Cache Storage API, Node.js `node:test`, PowerShell/.NET `System.Drawing` for deterministic icon generation.

## Global Constraints

- Application entry remains `doudizhu_app/preview.html`; do not add `index.html`.
- Manifest values are exactly `start_url: "./preview.html"`, `scope: "./"`, and `id: "./"`.
- All manifest, icon, and Service Worker URLs are relative and must work below a GitHub Pages repository subdirectory.
- Keep the existing `localStorage` key `doudizhu_state`, schema, scoring rules, and all current interactions unchanged.
- The application shell uses cache-first behavior; the active Service Worker must not rewrite cached shell assets in the background.
- Do not call `skipWaiting()` during `install`; call it only after a `SKIP_WAITING` message.
- Check for a new worker after registration and when the browser fires `online`; do not poll.
- Do not add runtime dependencies, frameworks, authentication, remote storage, synchronization, IndexedDB, or app-store packaging.
- Service Worker failure must degrade to the existing online/localStorage web application without blocking startup.
- Follow strict TDD: add a focused failing test, run it and record the expected failure, add the minimum implementation, then rerun the focused and full test suites.

---

## File Structure

- `doudizhu_app/manifest.webmanifest`: install identity, standalone presentation, theme, and icon declarations.
- `doudizhu_app/icons/icon-192.png`: 192px general-purpose icon.
- `doudizhu_app/icons/icon-512.png`: 512px general-purpose icon.
- `doudizhu_app/icons/maskable-192.png`: 192px maskable icon with the subject inside the central safe zone.
- `doudizhu_app/icons/maskable-512.png`: 512px maskable icon with the subject inside the central safe zone.
- `doudizhu_app/tools/generate_pwa_icons.ps1`: deterministic, dependency-free source for regenerating the four PNG files.
- `doudizhu_app/sw.js`: versioned shell cache and worker lifecycle behavior.
- `doudizhu_app/preview.html`: manifest/icon links, update notice, worker registration, and update activation controller.
- `doudizhu_app/test/pwa_assets.test.mjs`: manifest and generated PNG contract tests.
- `doudizhu_app/test/service_worker.test.mjs`: worker install/activate/fetch/message behavior tests using VM fakes.
- `doudizhu_app/test/preview_interactions.test.mjs`: existing interaction suite plus page integration and update-controller tests.
- `doudizhu_app/运行指南.md`: phone installation, offline verification, and release cache-version instructions.

### Task 1: Manifest and deterministic install icons

**Files:**
- Create: `doudizhu_app/manifest.webmanifest`
- Create: `doudizhu_app/tools/generate_pwa_icons.ps1`
- Create: `doudizhu_app/icons/icon-192.png`
- Create: `doudizhu_app/icons/icon-512.png`
- Create: `doudizhu_app/icons/maskable-192.png`
- Create: `doudizhu_app/icons/maskable-512.png`
- Create: `doudizhu_app/test/pwa_assets.test.mjs`

**Interfaces:**
- Produces: a valid manifest at `./manifest.webmanifest` and four PNGs referenced by its `icons` array.
- Consumes: no earlier task output.

- [ ] **Step 1: Write the failing asset contract test**

Create `doudizhu_app/test/pwa_assets.test.mjs` with tests that parse the manifest and inspect PNG IHDR dimensions:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');

async function pngSize(relativePath) {
  const bytes = await readFile(join(root, relativePath));
  assert.deepEqual([...bytes.subarray(0, 8)], [137, 80, 78, 71, 13, 10, 26, 10]);
  return { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) };
}

test('manifest uses a relative preview entry and standalone scope', async () => {
  const manifest = JSON.parse(await readFile(join(root, 'manifest.webmanifest'), 'utf8'));
  assert.equal(manifest.name, '斗地主记分');
  assert.equal(manifest.short_name, '斗地主');
  assert.equal(manifest.id, './');
  assert.equal(manifest.start_url, './preview.html');
  assert.equal(manifest.scope, './');
  assert.equal(manifest.display, 'standalone');
  assert.equal(manifest.orientation, 'portrait');
  assert.equal(manifest.theme_color, '#151515');
  assert.equal(manifest.background_color, '#151515');
});

test('manifest declares any and maskable PNG icons at 192 and 512', async () => {
  const manifest = JSON.parse(await readFile(join(root, 'manifest.webmanifest'), 'utf8'));
  const contracts = [
    ['./icons/icon-192.png', '192x192', 'any'],
    ['./icons/icon-512.png', '512x512', 'any'],
    ['./icons/maskable-192.png', '192x192', 'maskable'],
    ['./icons/maskable-512.png', '512x512', 'maskable'],
  ];
  assert.deepEqual(manifest.icons.map(({ src, sizes, purpose }) => [src, sizes, purpose]), contracts);
  for (const [src, sizes] of contracts) {
    const expected = Number(sizes.split('x')[0]);
    assert.deepEqual(await pngSize(src.slice(2)), { width: expected, height: expected });
  }
});
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
node --test doudizhu_app/test/pwa_assets.test.mjs
```

Expected: FAIL with `ENOENT` for `manifest.webmanifest`.

- [ ] **Step 3: Add the manifest and deterministic icon generator**

Create the manifest with the exact values from the design:

```json
{
  "name": "斗地主记分",
  "short_name": "斗地主",
  "description": "离线可用的斗地主三人记分工具",
  "id": "./",
  "start_url": "./preview.html",
  "scope": "./",
  "display": "standalone",
  "orientation": "portrait",
  "background_color": "#151515",
  "theme_color": "#151515",
  "lang": "zh-CN",
  "icons": [
    { "src": "./icons/icon-192.png", "sizes": "192x192", "type": "image/png", "purpose": "any" },
    { "src": "./icons/icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any" },
    { "src": "./icons/maskable-192.png", "sizes": "192x192", "type": "image/png", "purpose": "maskable" },
    { "src": "./icons/maskable-512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable" }
  ]
}
```

Create `generate_pwa_icons.ps1`:

```powershell
Add-Type -AssemblyName System.Drawing

$appRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$iconRoot = Join-Path $appRoot 'icons'
[System.IO.Directory]::CreateDirectory($iconRoot) | Out-Null

function New-PwaIcon {
  param(
    [int]$Size,
    [bool]$Maskable,
    [string]$FileName
  )

  $bitmap = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $background = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml('#151515'))
  $panel = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml('#201914'))
  $gold = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml('#e2b84b'))
  $red = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml('#c82121'))
  $goldPen = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml('#e2b84b'), [Math]::Max(3, $Size * 0.025))
  $font = New-Object System.Drawing.Font('Arial', [single]($Size * 0.15), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
  $format = New-Object System.Drawing.StringFormat
  try {
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.FillRectangle($background, 0, 0, $Size, $Size)
    $inset = if ($Maskable) { [int]($Size * 0.20) } else { [int]($Size * 0.10) }
    $card = New-Object System.Drawing.RectangleF($inset, $inset, $Size - 2 * $inset, $Size - 2 * $inset)
    $graphics.FillRectangle($panel, $card)
    $graphics.DrawRectangle($goldPen, $card.X, $card.Y, $card.Width, $card.Height)
    $sealSize = [single]($Size * 0.30)
    $sealX = [single](($Size - $sealSize) / 2)
    $sealY = [single]($Size * 0.25)
    $graphics.FillEllipse($red, $sealX, $sealY, $sealSize, $sealSize)
    $spade = @(
      [System.Drawing.PointF]::new($Size * 0.50, $Size * 0.29),
      [System.Drawing.PointF]::new($Size * 0.40, $Size * 0.43),
      [System.Drawing.PointF]::new($Size * 0.60, $Size * 0.43)
    )
    $graphics.FillPolygon($gold, $spade)
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    $label = New-Object System.Drawing.RectangleF(0, $Size * 0.52, $Size, $Size * 0.24)
    $graphics.DrawString('DDZ', $font, $gold, $label, $format)
    $bitmap.Save((Join-Path $iconRoot $FileName), [System.Drawing.Imaging.ImageFormat]::Png)
  }
  finally {
    $format.Dispose()
    $font.Dispose()
    $goldPen.Dispose()
    $red.Dispose()
    $gold.Dispose()
    $panel.Dispose()
    $background.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
  }
}

New-PwaIcon -Size 192 -Maskable $false -FileName 'icon-192.png'
New-PwaIcon -Size 512 -Maskable $false -FileName 'icon-512.png'
New-PwaIcon -Size 192 -Maskable $true -FileName 'maskable-192.png'
New-PwaIcon -Size 512 -Maskable $true -FileName 'maskable-512.png'
```

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File doudizhu_app/tools/generate_pwa_icons.ps1
```

- [ ] **Step 4: Verify GREEN and regression safety**

Run:

```powershell
node --test doudizhu_app/test/pwa_assets.test.mjs
node --test "doudizhu_app/test/*.test.mjs"
```

Expected: 2 asset tests pass; all existing 28 interaction tests also pass.

- [ ] **Step 5: Commit**

```powershell
git add doudizhu_app/manifest.webmanifest doudizhu_app/tools/generate_pwa_icons.ps1 doudizhu_app/icons doudizhu_app/test/pwa_assets.test.mjs
git commit -m "feat: add PWA manifest and install icons"
```

### Task 2: Versioned cache-first Service Worker

**Files:**
- Create: `doudizhu_app/sw.js`
- Create: `doudizhu_app/test/service_worker.test.mjs`

**Interfaces:**
- Produces: worker messages `{ type: "SKIP_WAITING" }`; cache `doudizhu-shell-v1`; precache URLs resolved with `new URL(relative, self.registration.scope).href`.
- Consumes: Task 1 asset paths.

- [ ] **Step 1: Write failing worker lifecycle tests**

Create `doudizhu_app/test/service_worker.test.mjs` with this complete VM harness and focused tests:

```js
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
```

- [ ] **Step 2: Run the test and verify RED**

```powershell
node --test doudizhu_app/test/service_worker.test.mjs
```

Expected: FAIL with `ENOENT` for `sw.js`.

- [ ] **Step 3: Implement the minimum Service Worker**

Create `sw.js` with:

```js
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
```

- [ ] **Step 4: Verify GREEN and full regression**

```powershell
node --test doudizhu_app/test/service_worker.test.mjs
node --test "doudizhu_app/test/*.test.mjs"
```

Expected: all Service Worker tests and all prior tests pass.

- [ ] **Step 5: Commit**

```powershell
git add doudizhu_app/sw.js doudizhu_app/test/service_worker.test.mjs
git commit -m "feat: add offline shell service worker"
```

### Task 3: Page installation metadata and safe update controller

**Files:**
- Modify: `doudizhu_app/preview.html`
- Modify: `doudizhu_app/test/preview_interactions.test.mjs`

**Interfaces:**
- Consumes: `./manifest.webmanifest`, `./icons/icon-192.png`, `./sw.js`, and worker message `{ type: "SKIP_WAITING" }`.
- Produces: `window.previewApp.canUseServiceWorker(location, navigator)` and `window.previewApp.setupPwaUpdates(deps) -> Promise<ServiceWorkerRegistration|null>`.

- [ ] **Step 1: Write failing page integration tests**

Append this fake helper and the focused tests to the existing interaction suite:

```js
function createPwaFakes(options = {}) {
  const windowHandlers = new Map();
  const workerHandlers = new Map();
  const registrationHandlers = new Map();
  const installingHandlers = new Map();
  const buttonHandlers = new Map();
  const messages = [];
  const registerCalls = [];
  let updateCalls = 0;
  let reloadCalls = 0;
  const waiting = options.waiting ? { postMessage: message => messages.push(message) } : null;
  const registration = {
    waiting,
    installing: options.installing ? {
      state: 'installing',
      addEventListener: (type, handler) => installingHandlers.set(type, handler),
    } : null,
    update: async () => { updateCalls += 1; },
    addEventListener: (type, handler) => registrationHandlers.set(type, handler),
  };
  const serviceWorker = {
    controller: {},
    register: async (...args) => {
      registerCalls.push(args);
      if (options.registrationError) throw options.registrationError;
      return registration;
    },
    addEventListener: (type, handler) => workerHandlers.set(type, handler),
  };
  const banner = { hidden: true };
  const updateButton = { addEventListener: (type, handler) => buttonHandlers.set(type, handler) };
  const windowObj = {
    location: { reload: () => { reloadCalls += 1; } },
    addEventListener: (type, handler) => windowHandlers.set(type, handler),
  };
  return {
    deps: {
      navigatorObj: { serviceWorker },
      windowObj,
      locationObj: { protocol: 'https:', hostname: 'example.test' },
      banner,
      updateButton,
    },
    banner,
    messages,
    registerCalls,
    get updateCalls() { return updateCalls; },
    get reloadCalls() { return reloadCalls; },
    async fireWindow(type) { await windowHandlers.get(type)?.(); },
    async fireServiceWorker(type) { await workerHandlers.get(type)?.(); },
    async clickUpdate() { await buttonHandlers.get('click')?.(); },
  };
}

test('page links the relative manifest, theme color, favicon, and apple touch icon', () => {
  const html = readPreview();
  assert.match(html, /rel="manifest" href="\.\/manifest\.webmanifest"/);
  assert.match(html, /name="theme-color" content="#151515"/);
  assert.match(html, /rel="icon" href="\.\/icons\/icon-192\.png"/);
  assert.match(html, /rel="apple-touch-icon" href="\.\/icons\/icon-192\.png"/);
});

test('service worker eligibility accepts HTTPS and local development only', () => {
  const app = loadPreview().window.previewApp;
  assert.equal(app.canUseServiceWorker({ protocol: 'https:', hostname: 'example.test' }, { serviceWorker: {} }), true);
  assert.equal(app.canUseServiceWorker({ protocol: 'http:', hostname: 'localhost' }, { serviceWorker: {} }), true);
  assert.equal(app.canUseServiceWorker({ protocol: 'http:', hostname: '127.0.0.1' }, { serviceWorker: {} }), true);
  assert.equal(app.canUseServiceWorker({ protocol: 'http:', hostname: 'example.test' }, { serviceWorker: {} }), false);
  assert.equal(app.canUseServiceWorker({ protocol: 'file:', hostname: '' }, { serviceWorker: {} }), false);
});

test('setup registers relative scope and checks on load and online', async () => {
  const fakes = createPwaFakes();
  await loadPreview().window.previewApp.setupPwaUpdates(fakes.deps);
  assert.deepEqual(fakes.registerCalls, [['./sw.js', { scope: './' }]]);
  assert.equal(fakes.updateCalls, 1);
  await fakes.fireWindow('online');
  assert.equal(fakes.updateCalls, 2);
});

test('waiting worker is shown and update button sends SKIP_WAITING', async () => {
  const fakes = createPwaFakes({ waiting: true });
  await loadPreview().window.previewApp.setupPwaUpdates(fakes.deps);
  assert.equal(fakes.banner.hidden, false);
  await fakes.clickUpdate();
  assert.deepEqual(fakes.messages, [{ type: 'SKIP_WAITING' }]);
});

test('controllerchange reloads only after an explicit waiting-worker update request', async () => {
  const fakes = createPwaFakes({ waiting: true });
  await loadPreview().window.previewApp.setupPwaUpdates(fakes.deps);
  await fakes.fireServiceWorker('controllerchange');
  assert.equal(fakes.reloadCalls, 0);
  await fakes.clickUpdate();
  await fakes.fireServiceWorker('controllerchange');
  await fakes.fireServiceWorker('controllerchange');
  assert.equal(fakes.reloadCalls, 1);
  const failed = createPwaFakes({ registrationError: new Error('offline') });
  assert.equal(await loadPreview().window.previewApp.setupPwaUpdates(failed.deps), null);
});
```

- [ ] **Step 2: Run the test and verify RED**

```powershell
node --test doudizhu_app/test/preview_interactions.test.mjs
```

Expected: metadata assertions fail and `canUseServiceWorker` is undefined.

- [ ] **Step 3: Add metadata, update notice, and controller**

Add to `<head>`:

```html
<meta name="theme-color" content="#151515">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<link rel="manifest" href="./manifest.webmanifest">
<link rel="icon" href="./icons/icon-192.png">
<link rel="apple-touch-icon" href="./icons/icon-192.png">
```

Add before `#toast`:

```html
<div id="pwa-update" class="update-notice" role="status" hidden>
  <span>发现新版本，可立即更新。</span>
  <button id="pwa-update-now" type="button">立即更新</button>
</div>
```

Add CSS that fixes the notice above the bottom safe area, uses the existing dark/gold/red palette, preserves the current mobile width, and includes `.update-notice[hidden] { display: none; }`.

Add the two exported functions before `window.previewApp` is assigned:

```js
function canUseServiceWorker(locationObj, navigatorObj) {
  if (!navigatorObj || !('serviceWorker' in navigatorObj)) return false;
  return locationObj.protocol === 'https:' ||
    (locationObj.protocol === 'http:' && (locationObj.hostname === 'localhost' || locationObj.hostname === '127.0.0.1'));
}

async function setupPwaUpdates(deps) {
  const { navigatorObj, windowObj, locationObj, banner, updateButton } = deps;
  if (!canUseServiceWorker(locationObj, navigatorObj)) return null;
  try {
    const registration = await navigatorObj.serviceWorker.register('./sw.js', { scope: './' });
    let refreshing = false;
    let updateRequested = false;
    const showWaiting = () => {
      if (!registration.waiting || !banner) return;
      banner.hidden = false;
    };
    showWaiting();
    registration.addEventListener('updatefound', () => {
      const installing = registration.installing;
      if (!installing) return;
      installing.addEventListener('statechange', () => {
        if (installing.state === 'installed' && navigatorObj.serviceWorker.controller) showWaiting();
      });
    });
    if (updateButton) updateButton.addEventListener('click', () => {
      if (!registration.waiting) return;
      try {
        registration.waiting.postMessage({ type: 'SKIP_WAITING' });
        updateRequested = true;
      } catch (_) {}
    });
    navigatorObj.serviceWorker.addEventListener('controllerchange', () => {
      if (!updateRequested || refreshing) return;
      refreshing = true;
      windowObj.location.reload();
    });
    const check = () => registration.update().catch(() => {});
    check();
    windowObj.addEventListener('online', check);
    return registration;
  } catch (_) {
    return null;
  }
}
```

Expose both functions on `window.previewApp`. At the end of the script, register a guarded load handler:

```js
if (typeof window.addEventListener === 'function') {
  window.addEventListener('load', () => setupPwaUpdates({
    navigatorObj: window.navigator,
    windowObj: window,
    locationObj: window.location,
    banner: byId('pwa-update'),
    updateButton: byId('pwa-update-now'),
  }));
}
```

- [ ] **Step 4: Verify GREEN and complete regression**

```powershell
node --test doudizhu_app/test/preview_interactions.test.mjs
node --test "doudizhu_app/test/*.test.mjs"
```

Expected: all PWA page tests and all prior tests pass with no thrown startup error.

- [ ] **Step 5: Commit**

```powershell
git add doudizhu_app/preview.html doudizhu_app/test/preview_interactions.test.mjs
git commit -m "feat: register PWA and surface safe updates"
```

### Task 4: Installation guide and complete release verification

**Files:**
- Modify: `doudizhu_app/运行指南.md`

**Interfaces:**
- Consumes: all PWA assets and behavior from Tasks 1–3.
- Produces: exact phone installation, offline validation, and cache-version release instructions.

- [ ] **Step 1: Add a failing documentation contract test**

Append to `doudizhu_app/test/pwa_assets.test.mjs`:

```js
test('run guide documents iPhone, Android, offline verification, and cache releases', async () => {
  const guide = await readFile(join(root, '运行指南.md'), 'utf8');
  for (const phrase of ['iPhone', 'Safari', '添加到主屏幕', 'Android', 'Chrome', '飞行模式', 'doudizhu-shell-v1']) {
    assert.ok(guide.includes(phrase), `missing guide phrase: ${phrase}`);
  }
});
```

- [ ] **Step 2: Run the focused test and verify RED**

```powershell
node --test doudizhu_app/test/pwa_assets.test.mjs
```

Expected: FAIL and name the first missing installation phrase.

- [ ] **Step 3: Document installation and release behavior**

Add sections to `运行指南.md` that state:

- Serve/deploy `doudizhu_app` over HTTPS; `file://` cannot install a Service Worker.
- iPhone: Safari → Share → 添加到主屏幕 → 作为 Web App 打开.
- Android: Chrome → menu → 添加到主屏幕/安装应用.
- First open once while online, then enable airplane mode and verify open/new session/score/undo/history/relaunch.
- Scores remain in the current phone’s `localStorage` and do not sync.
- `sw.js` declares `CACHE_NAME` as `CACHE_PREFIX + 'v1'`; every shell release must increment only the suffix (`'v1'` → `'v2'` → `'v3'`) while preserving `CACHE_PREFIX = 'doudizhu-shell-'`. After restoring internet, the page checks on load/online, shows the update notice, and activates only after “立即更新” or closing all old pages.

- [ ] **Step 4: Run all automated verification**

```powershell
node --test "doudizhu_app/test/*.test.mjs"
git diff --check
```

Expected: all tests pass and `git diff --check` exits 0.

- [ ] **Step 5: Commit**

```powershell
git add doudizhu_app/运行指南.md doudizhu_app/test/pwa_assets.test.mjs
git commit -m "docs: add PWA phone installation guide"
```

### Task 5: Browser installability and offline acceptance

**Files:**
- No production file changes expected.

**Interfaces:**
- Consumes: completed Tasks 1–4.
- Produces: fresh acceptance evidence recorded in the task report.

- [ ] **Step 1: Start a static server from the PWA root**

```powershell
python -m http.server 8765 --directory doudizhu_app
```

Expected: `http://127.0.0.1:8765/preview.html` returns HTTP 200.

- [ ] **Step 2: Verify install metadata in a real Chromium browser**

Open `http://127.0.0.1:8765/preview.html`; verify the manifest loads, all four icon requests return 200, `./sw.js` registers with scope ending `/`, and the active worker controls the page after one reload.

- [ ] **Step 3: Verify offline behavior**

Create a session and record one round while online. Switch browser network emulation to Offline, reload, then verify:

- the page loads without a network error;
- the current score and round remain;
- a second round can be recorded and undone;
- history/settings navigation works;
- closing and reopening the page while still offline preserves state.

- [ ] **Step 4: Verify safe update behavior**

Temporarily increment the `CACHE_NAME` suffix in the worktree, reload online, verify the “发现新版本” notice appears, click “立即更新”, and verify exactly one reload. Restore the intended committed suffix afterward and run:

```powershell
git diff --check
git status --short
node --test "doudizhu_app/test/*.test.mjs"
```

Expected: no temporary cache-version change remains; the worktree contains only intended committed changes; all tests pass.
