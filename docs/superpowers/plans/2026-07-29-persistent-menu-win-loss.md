# Persistent Menu and Win/Loss Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the pull-down preview menu with an always-visible six-item row and make the scoring outcome controls larger, shorter, and visually distinct as “赢 / 输”.

**Architecture:** Keep the existing static single-file application and remove the preview menu’s transient UI state entirely. The menu returns to normal document flow as a six-column navigation grid, while the existing boolean win/loss state continues to drive two purpose-specific visual classes. Publish the changed precached shell as Service Worker cache `v4`.

**Tech Stack:** Static HTML/CSS/JavaScript, Node.js built-in `node:test`, existing zero-dependency DOM shim, Service Worker Cache API, in-app browser viewport verification.

## Global Constraints

- The menu labels are exactly `空桌 / 对局 / 新建 / 历史 / 详情 / 设置`, in that order.
- All six menu items remain visible in one row at widths 360, 390, and 430 pixels, with no horizontal scrolling or wrapping.
- Menu buttons remain close to 44 pixels high and retain active-page styling.
- The outcome labels are exactly `赢` and `输`; both buttons remain equal width and at least 48 pixels high.
- The selected “赢” state uses red with gold/white text; the selected “输” state uses blue-green with white text.
- Keep the confirm button visible without page scrolling at 360×800, 390×844, and 430×932.
- Do not change scoring rules, boolean outcome data, sessions, localStorage schema, undo behavior, history snapshots, or PWA update semantics.
- Preserve player colors and the existing dark/gold/red application language outside the loss-specific selected state.
- Keep `env(safe-area-inset-top)` and `env(safe-area-inset-bottom)` support.
- Do not introduce a framework or third-party dependency.

## File Structure

- Modify `doudizhu_app/preview.html`: own the persistent navigation markup/CSS, remove obsolete disclosure JavaScript, and style the two outcome controls.
- Modify `doudizhu_app/test/preview_interactions.test.mjs`: own persistent-menu, navigation, outcome-text, selection-state, and responsive CSS contracts.
- Modify `doudizhu_app/sw.js`: advance the precached shell release from `v3` to `v4`.
- Modify `doudizhu_app/test/service_worker.test.mjs`: prove `v4` opens and all older same-scope shell caches are retired without touching other scopes.

---

### Task 1: Persistent Navigation and Distinct Win/Loss Controls

**Files:**
- Modify: `doudizhu_app/preview.html:24-34`
- Modify: `doudizhu_app/preview.html:77-79`
- Modify: `doudizhu_app/preview.html:101-127`
- Modify: `doudizhu_app/preview.html:132-146`
- Modify: `doudizhu_app/preview.html:450-475`
- Modify: `doudizhu_app/preview.html:632-655`
- Test: `doudizhu_app/test/preview_interactions.test.mjs`

**Interfaces:**
- Consumes: existing `showScreen(id)`, `syncTabs(id)`, `draftRound.isLandlordWin`, and the `#landlord-win` / `#landlord-loss` click handlers.
- Produces: always-visible `#preview-menu`, six short labels, `.outcome-toggle`, `.outcome-win`, and `.outcome-loss`.

- [ ] **Step 1: Replace obsolete pull-down tests with failing persistent-menu tests**

Delete the tests whose names begin with:

```text
preview page menu starts closed
scrolling down closes the preview menu
preview menu CSS keeps the closed menu
preview menu handle has
preview menu reserves
preview menu pull gesture
choosing a preview menu destination closes
```

Add:

```js
test('preview menu is always visible as six short navigation choices', () => {
  const { document } = loadPreview();
  const menu = document.getElementById('preview-menu');
  assert.equal(document.getElementById('preview-menu-handle'), null);
  assert.equal(menu.hasAttribute('aria-hidden'), false);
  assert.equal(menu.hasAttribute('inert'), false);
  assert.deepEqual(
    [...menu.querySelectorAll('button')].map(button => button.textContent.trim()),
    ['空桌', '对局', '新建', '历史', '详情', '设置'],
  );
});

test('persistent preview choices still navigate and update the active item', () => {
  const { document } = loadPreview();
  const menuButtons = [...document.querySelectorAll('#preview-menu button')];
  assert.equal(menuButtons.length, 6);
  menuButtons[3].click();
  assert.equal(activeScreen(document)?.id, 'screen-history');
  assert.equal(menuButtons[3].classList.contains('active'), true);
  assert.equal(menuButtons[0].classList.contains('active'), false);
});

test('persistent menu CSS keeps six touchable choices on one row', () => {
  const html = readPreview();
  const menuRule = html.match(/\.tab-bar\s*\{([^}]*)\}/s)?.[1] || '';
  const buttonRule = html.match(/\.tab-bar button\s*\{([^}]*)\}/s)?.[1] || '';
  assert.match(menuRule, /display:\s*grid\s*;/);
  assert.match(menuRule, /grid-template-columns:\s*repeat\(6,\s*minmax\(0,\s*1fr\)\)\s*;/);
  assert.match(menuRule, /position:\s*static\s*;/);
  assert.match(menuRule, /width:\s*min\(100%,\s*430px\)\s*;/);
  assert.match(buttonRule, /min-height:\s*44px\s*;/);
  assert.match(buttonRule, /white-space:\s*nowrap\s*;/);
});
```

- [ ] **Step 2: Add failing win/loss text and styling tests**

```js
test('outcome controls use large short labels and purpose-specific classes', () => {
  const { document } = loadPreview();
  const win = document.getElementById('landlord-win');
  const loss = document.getElementById('landlord-loss');
  assert.equal(win.textContent.trim(), '赢');
  assert.equal(loss.textContent.trim(), '输');
  assert.equal(win.classList.contains('outcome-win'), true);
  assert.equal(loss.classList.contains('outcome-loss'), true);
  const html = readPreview();
  assert.match(html, /\.outcome-toggle\s*\{[^}]*min-height:\s*48px\s*;[^}]*font-size:\s*23px\s*;[^}]*font-weight:\s*900\s*;/s);
  assert.match(html, /\.outcome-win\.selected\s*\{[^}]*background:\s*#b91c1c\s*;[^}]*color:\s*#fff4cf\s*;/s);
  assert.match(html, /\.outcome-loss\.selected\s*\{[^}]*background:\s*#176b68\s*;[^}]*color:\s*#fff\s*;/s);
});

test('win and loss selection still map to the existing boolean draft state', () => {
  const first = loadPreview();
  let state = first.window.previewApp.defaultState();
  state = first.window.previewApp.createSession(
    state,
    state.players.slice(0, 3).map(player => player.id),
  );
  const loaded = loadPreview({ seed: { doudizhu_state: JSON.stringify(state) } });
  const win = loaded.document.getElementById('landlord-win');
  const loss = loaded.document.getElementById('landlord-loss');
  win.click();
  assert.equal(win.classList.contains('selected'), true);
  assert.equal(loss.classList.contains('selected'), false);
  loss.click();
  assert.equal(win.classList.contains('selected'), false);
  assert.equal(loss.classList.contains('selected'), true);
  const persisted = JSON.parse(loaded.localStorage.getItem('doudizhu_state'));
  assert.equal(persisted.draftRound.isLandlordWin, false);
});
```

- [ ] **Step 3: Run the focused tests and verify RED**

Run:

```powershell
node --test --test-name-pattern="preview menu is always|persistent preview choices|persistent menu CSS|outcome controls use|win and loss selection" doudizhu_app/test/preview_interactions.test.mjs
```

Expected: FAIL because the handle/disclosure attributes still exist, labels remain long, menu CSS is fixed/hidden, outcome labels remain “地主赢 / 地主输”, and purpose-specific classes/styles do not exist.

- [ ] **Step 4: Replace the menu CSS with a normal-flow six-column grid**

Delete `.sr-only`, `.preview-menu-handle`, `.handle-bar`, `.tab-bar.open`, and the existing fixed/hidden `.tab-bar` rules. Replace the menu and button rules with:

```css
.tab-bar {
  position: static;
  width: min(100%, 430px);
  display: grid;
  grid-template-columns: repeat(6, minmax(0, 1fr));
  gap: 4px;
  margin: 0 auto 6px;
  padding: calc(4px + env(safe-area-inset-top)) 6px 0;
}
.tab-bar button {
  min-width: 0;
  min-height: 44px;
  padding: 6px 2px;
  border: 1px solid var(--gold-soft);
  border-radius: 8px;
  background: #1c1410;
  color: var(--text);
  font-size: 14px;
  font-weight: 800;
  white-space: nowrap;
}
.tab-bar button:hover, .tab-bar button.active { border-color: var(--gold); }
.tab-bar button.active { background: var(--red); }
```

Change the base reduced-motion rule to:

```css
@media (prefers-reduced-motion: reduce) { .disclosure-icon, .toast { transition: none; } }
```

Keep the existing phone and screen rules, but account for the 54-pixel menu row on mobile:

```css
@media (max-width: 480px) {
  .preview-shell { min-height: 100dvh; padding: 0 0 env(safe-area-inset-bottom); }
  .phone { width: 100%; min-height: calc(100dvh - 54px - env(safe-area-inset-top)); border: 0; border-radius: 0; }
  .screen { min-height: calc(100dvh - 54px - env(safe-area-inset-top)); }
}
```

- [ ] **Step 5: Replace the menu markup and labels**

Replace the handle plus navigation start with:

```html
<nav id="preview-menu" class="tab-bar" aria-label="预览页面">
  <button class="active" data-screen="home-empty">空桌</button>
  <button data-screen="home-session">对局</button>
  <button data-screen="new-session">新建</button>
  <button data-screen="history">历史</button>
  <button data-screen="detail">详情</button>
  <button data-screen="settings">设置</button>
</nav>
```

- [ ] **Step 6: Remove obsolete menu state and gesture JavaScript**

Remove `setPreviewMenuOpen` and `shouldRevealPreviewMenu` from `window.previewApp`.

Delete the full implementations of:

```js
function shouldRevealPreviewMenu(startY, currentY, scrollY) { ... }
function setPreviewMenuOpen(open) { ... }
```

Replace the menu listeners with:

```js
document.querySelectorAll('.tab-bar button').forEach(button => {
  button.addEventListener('click', () => showScreen(button.getAttribute('data-screen')));
});
```

Delete the handle click listener and the entire touchstart/touchmove/scroll menu block.

- [ ] **Step 7: Add purpose-specific outcome markup and CSS**

Replace the generic selected rule:

```css
.toggle.selected { background: var(--red); border-color: #ef4438; }
```

with:

```css
.outcome-toggle {
  min-height: 48px;
  font-size: 23px;
  line-height: 1;
  font-weight: 900;
  letter-spacing: .16em;
  text-indent: .16em;
}
.outcome-win.selected {
  border-color: #ef4444;
  background: #b91c1c;
  color: #fff4cf;
  box-shadow: inset 0 0 0 1px var(--gold);
}
.outcome-loss.selected {
  border-color: #38b2ac;
  background: #176b68;
  color: #fff;
  box-shadow: inset 0 0 0 1px #5eead4;
}
```

Replace the outcome buttons with:

```html
<button id="landlord-win" class="toggle outcome-toggle outcome-win">赢</button>
<button id="landlord-loss" class="toggle outcome-toggle outcome-loss">输</button>
```

In the compact mobile rule, replace the shared toggle minimum with:

```css
.scoring-card .btn-option { min-height: 42px; padding: 7px 5px; }
.scoring-card .outcome-toggle { min-height: 48px; padding: 7px 5px; }
```

- [ ] **Step 8: Run focused and complete interaction tests**

Run:

```powershell
node --test --test-name-pattern="preview menu is always|persistent preview choices|persistent menu CSS|outcome controls use|win and loss selection" doudizhu_app/test/preview_interactions.test.mjs
node --test doudizhu_app/test/preview_interactions.test.mjs
git diff --check
```

Expected: focused tests PASS; the complete interaction suite PASS; no whitespace errors.

- [ ] **Step 9: Commit the UI behavior**

```powershell
git add -- doudizhu_app/preview.html doudizhu_app/test/preview_interactions.test.mjs
git commit -m "feat: show persistent menu and distinct outcomes"
```

---

### Task 2: PWA v4 Release and Mobile Viewport Verification

**Files:**
- Modify: `doudizhu_app/sw.js:3`
- Modify: `doudizhu_app/test/service_worker.test.mjs`
- Verify: `doudizhu_app/preview.html`

**Interfaces:**
- Consumes: final shell from Task 1 and the existing scope-qualified `CACHE_PREFIX`.
- Produces: shell cache `doudizhu-shell-<scope>::v4`.

- [ ] **Step 1: Write the failing v4 cache release test**

Update the current-version fixtures from v3 to v4 and replace the v3 release test with:

```js
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
```

- [ ] **Step 2: Run the v4 test and verify RED**

Run:

```powershell
node --test --test-name-pattern="v4 release opens" doudizhu_app/test/service_worker.test.mjs
```

Expected: FAIL because `sw.js` still opens `::v3`.

- [ ] **Step 3: Publish shell cache v4**

Change exactly:

```js
const CACHE_NAME = CACHE_PREFIX + 'v4';
```

Ensure the existing activate test treats `::v4` as current and expects `::v0` through `::v3` to be deleted.

- [ ] **Step 4: Run all automated tests**

Run:

```powershell
node --test doudizhu_app/test/preview_interactions.test.mjs doudizhu_app/test/pwa_assets.test.mjs doudizhu_app/test/service_worker.test.mjs
git diff --check
```

Expected: all tests PASS and `git diff --check` exits 0.

- [ ] **Step 5: Verify the final UI in three browser viewports**

Serve `doudizhu_app` locally, load or create an active session, and test:

```text
360 × 800
390 × 844
430 × 932
```

For each viewport verify in one bounded DOM measurement:

```text
- document.documentElement.scrollWidth === innerWidth
- the six #preview-menu buttons share one top/bottom row
- every menu button has height >= 44
- #confirm-round bottom <= innerHeight without scrolling
- the menu labels are 空桌/对局/新建/历史/详情/设置
```

Then click “赢” and “输” separately and verify:

```text
- each click selects only its own button
- the selected buttons have different computed background colors
- the labels remain visible and at least 23px
```

Capture one 360×800 screenshot with the menu and outcome controls visible.

- [ ] **Step 6: Verify update and offline behavior**

Using an origin that already has v3 installed:

```text
1. Load the v3 app.
2. Serve v4 and wait for the explicit update banner.
3. Click “立即更新”.
4. Confirm the persistent menu and “赢 / 输” controls load.
5. Stop the origin server and reopen the same URL.
6. Confirm v4 starts from the Service Worker cache.
```

- [ ] **Step 7: Commit the v4 release**

```powershell
git add -- doudizhu_app/sw.js doudizhu_app/test/service_worker.test.mjs
git commit -m "chore: release persistent menu shell cache"
```

- [ ] **Step 8: Final verification**

Run:

```powershell
git status --short
git log -5 --oneline
```

Expected: clean worktree and both implementation commits present after the design/plan commits.
