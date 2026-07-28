# Mobile Single-Screen Scoring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the active-session scoring workflow fit in one 360×800-or-larger portrait viewport while keeping all scoring behavior, undo behavior, PWA behavior, and accessible fallbacks intact.

**Architecture:** Keep the existing single-file HTML/CSS/JavaScript application and add two small UI state boundaries: an accessible disclosure for recent rounds and an accessible pull-down disclosure for the preview-only page menu. Remove the redundant score preview element, compact the existing layout through scoped CSS, and bump the service-worker shell cache so installed phones receive the change.

**Tech Stack:** Static HTML/CSS/JavaScript, Node.js built-in `node:test`, existing zero-dependency DOM shim, Service Worker Cache API, in-app browser viewport verification.

## Global Constraints

- The design baseline is portrait viewports of exactly 360×800, 390×844, and 430×932 pixels.
- Core controls must remain usable without page scrolling at 360×800 and larger; smaller heights and enlarged system fonts may scroll normally.
- Do not change scoring rules, active-session data, localStorage schema, undo behavior, history snapshots, manifest identity, or offline startup behavior.
- Preserve the dark/gold/red visual language and player identity colors.
- Keep primary touch targets close to 44×44 pixels; do not shrink the circular bomb buttons.
- Use `env(safe-area-inset-*)`, `aria-expanded`, `aria-controls`, `aria-hidden`, `inert`, and `prefers-reduced-motion` where specified.
- All code remains in the established `doudizhu_app/preview.html` structure; do not introduce a framework or third-party dependency.

## File Structure

- Modify `doudizhu_app/preview.html`: own the active-session markup, compact styling, recent-round disclosure, preview-menu disclosure, and touch gesture wiring.
- Modify `doudizhu_app/test/preview_interactions.test.mjs`: own DOM behavior and static responsive-contract regression tests.
- Modify `doudizhu_app/sw.js`: advance the PWA shell cache from `v1` to `v2`.
- Modify `doudizhu_app/test/service_worker.test.mjs`: prove the new cache namespace is opened and the previous shell cache is deleted.

---

### Task 1: Compact Scoring Markup and Recent-Rounds Disclosure

**Files:**
- Modify: `doudizhu_app/preview.html:133-163`
- Modify: `doudizhu_app/preview.html:446-535`
- Test: `doudizhu_app/test/preview_interactions.test.mjs`

**Interfaces:**
- Consumes: existing `renderHomeSession()`, `renderDraft()`, `appState.activeSession.rounds`, and `#confirm-round`.
- Produces: `#recent-rounds-toggle`, `#recent-rounds`, `.bomb-control-row`, and `setRecentRoundsExpanded(expanded: boolean): void`.

- [ ] **Step 1: Write failing DOM tests for the compact form contract**

Add these tests after the existing scoring-panel tests:

```js
test('compact scoring form removes the redundant score preview and aligns bomb controls', () => {
  const { document } = loadPreview();
  assert.equal(document.getElementById('round-preview'), null);
  const bombRow = document.querySelector('.bomb-control-row');
  assert.ok(bombRow, 'bomb label and counter need one shared row');
  assert.ok(bombRow.textContent.includes('炸弹数'));
  assert.ok(bombRow.querySelector('#bomb-minus'));
  assert.ok(bombRow.querySelector('#bomb-count'));
  assert.ok(bombRow.querySelector('#bomb-plus'));
  assert.ok(document.getElementById('round-feedback'));
  assert.ok(document.getElementById('confirm-round'));
});

test('recent rounds are collapsed by default and toggle accessibly', () => {
  const first = loadPreview();
  let state = first.window.previewApp.defaultState();
  const ids = state.players.slice(0, 3).map(player => player.id);
  state = first.window.previewApp.createSession(state, ids);
  state = first.window.previewApp.confirmRound(state, {
    landlordId: ids[0], isLandlordWin: true, bombCount: 0, kickStates: {},
  });
  const { document } = loadPreview({ seed: { doudizhu_state: JSON.stringify(state) } });
  const toggle = document.getElementById('recent-rounds-toggle');
  const list = document.getElementById('recent-rounds');
  assert.equal(toggle.getAttribute('aria-expanded'), 'false');
  assert.equal(list.hasAttribute('hidden'), true);
  toggle.click();
  assert.equal(toggle.getAttribute('aria-expanded'), 'true');
  assert.equal(list.hasAttribute('hidden'), false);
  toggle.click();
  assert.equal(toggle.getAttribute('aria-expanded'), 'false');
  assert.equal(list.hasAttribute('hidden'), true);
});
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```powershell
node --test --test-name-pattern="compact scoring form|recent rounds are collapsed" doudizhu_app/test/preview_interactions.test.mjs
```

Expected: FAIL because `#round-preview` still exists, `.bomb-control-row` and `#recent-rounds-toggle` do not exist, and recent rounds are always expanded.

- [ ] **Step 3: Replace the recent-round heading and bomb markup**

Replace the active-session recent-round block with:

```html
<button id="recent-rounds-toggle" class="recent-rounds-toggle" type="button"
        aria-expanded="false" aria-controls="recent-rounds">
  <span class="recent-rounds-label">最近三局</span>
  <span id="recent-rounds-summary" class="recent-rounds-summary">暂无记录</span>
  <span class="disclosure-icon" aria-hidden="true">⌄</span>
</button>
<div id="recent-rounds" hidden></div>
<h2 class="section-title scoring-title">本局记分</h2>
```

Replace the bomb heading, bomb row, preview card, feedback, and confirm block with:

```html
<div class="bomb-control-row">
  <span class="muted">炸弹数</span>
  <div class="bomb-row">
    <button id="bomb-minus" aria-label="减少炸弹">−</button>
    <strong id="bomb-count">0</strong>
    <button id="bomb-plus" aria-label="增加炸弹">＋</button>
  </div>
</div>
<div id="round-feedback" class="feedback" aria-live="polite"></div>
<button id="confirm-round" class="primary wide" disabled>确认记分</button>
```

- [ ] **Step 4: Implement recent-round disclosure state and remove preview rendering**

Add before `renderHomeSession()`:

```js
let recentRoundsExpanded = false;

function setRecentRoundsExpanded(expanded) {
  recentRoundsExpanded = !!expanded;
  const toggle = byId('recent-rounds-toggle');
  const list = byId('recent-rounds');
  if (!toggle || !list) return;
  toggle.setAttribute('aria-expanded', String(recentRoundsExpanded));
  if (recentRoundsExpanded) list.removeAttribute('hidden');
  else list.setAttribute('hidden', '');
}
```

In `renderHomeSession()`, after calculating `recent`, populate the summary and restore the collapsed state:

```js
const summary = byId('recent-rounds-summary');
summary.textContent = recent.length
  ? '第 ' + recent[0].index + ' 局 · ' + playerById(recent[0].landlordId).name +
    '地主 ' + (recent[0].isLandlordWin ? '胜' : '负')
  : '暂无记录';
setRecentRoundsExpanded(false);
```

Delete both branches that write to `#round-preview` from `renderDraft()`. Score calculation remains inside `confirmRound()` and must not move into presentation code.

Wire the disclosure beside the existing DOM listeners:

```js
byId('recent-rounds-toggle').addEventListener('click', () => {
  setRecentRoundsExpanded(!recentRoundsExpanded);
});
```

- [ ] **Step 5: Run the focused tests and verify GREEN**

Run:

```powershell
node --test --test-name-pattern="compact scoring form|recent rounds are collapsed" doudizhu_app/test/preview_interactions.test.mjs
```

Expected: 2 tests PASS and 0 tests FAIL.

- [ ] **Step 6: Run the full interaction suite**

Run:

```powershell
node --test doudizhu_app/test/preview_interactions.test.mjs
```

Expected: all interaction tests PASS, including scoring math, independent kick states, confirmation, and undo.

- [ ] **Step 7: Commit the self-contained disclosure change**

```powershell
git add -- doudizhu_app/preview.html doudizhu_app/test/preview_interactions.test.mjs
git commit -m "feat: compact scoring form and recent rounds"
```

---

### Task 2: Pull-Down Preview Menu

**Files:**
- Modify: `doudizhu_app/preview.html:22-29`
- Modify: `doudizhu_app/preview.html:96-105`
- Modify: `doudizhu_app/preview.html:395-430`
- Modify: `doudizhu_app/preview.html:560-570`
- Test: `doudizhu_app/test/preview_interactions.test.mjs`

**Interfaces:**
- Consumes: existing `.tab-bar` buttons and `showScreen(id)`.
- Produces: `#preview-menu-handle`, `setPreviewMenuOpen(open: boolean): void`, and `shouldRevealPreviewMenu(startY: number, currentY: number, scrollY: number): boolean` exposed on `window.previewApp`.

- [ ] **Step 1: Write failing tests for disclosure semantics and pull threshold**

```js
test('preview page menu starts closed and the handle toggles it accessibly', () => {
  const { document } = loadPreview();
  const menu = document.querySelector('.tab-bar');
  const handle = document.getElementById('preview-menu-handle');
  assert.equal(handle.getAttribute('aria-expanded'), 'false');
  assert.equal(menu.getAttribute('aria-hidden'), 'true');
  handle.click();
  assert.equal(handle.getAttribute('aria-expanded'), 'true');
  assert.equal(menu.getAttribute('aria-hidden'), 'false');
  handle.click();
  assert.equal(handle.getAttribute('aria-expanded'), 'false');
  assert.equal(menu.getAttribute('aria-hidden'), 'true');
});

test('preview menu pull gesture only reveals at page top after a 48px downward pull', () => {
  const { window } = loadPreview();
  const shouldReveal = window.previewApp.shouldRevealPreviewMenu;
  assert.equal(shouldReveal(100, 149, 0), true);
  assert.equal(shouldReveal(100, 147, 0), false);
  assert.equal(shouldReveal(100, 180, 1), false);
  assert.equal(shouldReveal(100, 20, 0), false);
});

test('choosing a preview menu destination closes the menu', () => {
  const { document } = loadPreview();
  const handle = document.getElementById('preview-menu-handle');
  handle.click();
  document.querySelector('.tab-bar button').click();
  assert.equal(handle.getAttribute('aria-expanded'), 'false');
  assert.equal(document.querySelector('.tab-bar').getAttribute('aria-hidden'), 'true');
});
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```powershell
node --test --test-name-pattern="preview page menu|preview menu pull|choosing a preview" doudizhu_app/test/preview_interactions.test.mjs
```

Expected: FAIL because the menu has no handle, closed state, or pull-threshold helper.

- [ ] **Step 3: Add the menu handle and initial accessibility state**

Place this immediately before the existing navigation:

```html
<button id="preview-menu-handle" class="preview-menu-handle" type="button"
        aria-expanded="false" aria-controls="preview-menu">
  <span class="handle-bar" aria-hidden="true"></span>
  <span class="sr-only">显示预览页面菜单</span>
</button>
<nav id="preview-menu" class="tab-bar" aria-label="预览页面" aria-hidden="true" inert>
```

Keep all six existing navigation buttons inside that `nav`.

- [ ] **Step 4: Implement menu state, threshold helper, and touch wiring**

Add the following functions before `syncTabs()` and include `shouldRevealPreviewMenu` in the existing `window.previewApp` export:

```js
function shouldRevealPreviewMenu(startY, currentY, scrollY) {
  return Number(scrollY) <= 0 && Number(currentY) - Number(startY) >= 48;
}

function setPreviewMenuOpen(open) {
  const menu = byId('preview-menu');
  const handle = byId('preview-menu-handle');
  const expanded = !!open;
  handle.setAttribute('aria-expanded', String(expanded));
  handle.querySelector('.sr-only').textContent =
    expanded ? '隐藏预览页面菜单' : '显示预览页面菜单';
  menu.setAttribute('aria-hidden', String(!expanded));
  menu.inert = !expanded;
  menu.classList.toggle('open', expanded);
}
```

Add the event wiring:

```js
byId('preview-menu-handle').addEventListener('click', () => {
  setPreviewMenuOpen(byId('preview-menu-handle').getAttribute('aria-expanded') !== 'true');
});

document.querySelectorAll('.tab-bar button').forEach(button => button.addEventListener('click', () => {
  showScreen(button.getAttribute('data-screen'));
  setPreviewMenuOpen(false);
}));

if (window.addEventListener) {
  let previewPullStartY = null;
  window.addEventListener('touchstart', touchEvent => {
    previewPullStartY = touchEvent.touches && touchEvent.touches[0]
      ? touchEvent.touches[0].clientY : null;
  }, { passive: true });
  window.addEventListener('touchmove', touchEvent => {
    const touch = touchEvent.touches && touchEvent.touches[0];
    if (touch && previewPullStartY != null &&
        shouldRevealPreviewMenu(previewPullStartY, touch.clientY, window.scrollY || 0)) {
      setPreviewMenuOpen(true);
      previewPullStartY = null;
    }
  }, { passive: true });
}
```

Remove the old duplicate `.tab-bar button` event listener.

- [ ] **Step 5: Run the focused tests and verify GREEN**

Run:

```powershell
node --test --test-name-pattern="preview page menu|preview menu pull|choosing a preview" doudizhu_app/test/preview_interactions.test.mjs
```

Expected: 3 tests PASS and 0 tests FAIL.

- [ ] **Step 6: Run the full interaction suite**

Run:

```powershell
node --test doudizhu_app/test/preview_interactions.test.mjs
```

Expected: all interaction tests PASS and the page script loads without throwing.

- [ ] **Step 7: Commit the menu disclosure**

```powershell
git add -- doudizhu_app/preview.html doudizhu_app/test/preview_interactions.test.mjs
git commit -m "feat: add pull-down preview menu"
```

---

### Task 3: Responsive Single-Screen Styling

**Files:**
- Modify: `doudizhu_app/preview.html:17-93`
- Test: `doudizhu_app/test/preview_interactions.test.mjs`

**Interfaces:**
- Consumes: markup and class names created in Tasks 1 and 2.
- Produces: `.session-content`, `.scoring-card`, `.recent-rounds-toggle`, `.bomb-control-row`, `.preview-menu-handle`, and the `@media (max-width: 480px) and (min-height: 800px)` single-screen layout contract.

- [ ] **Step 1: Write a failing static CSS contract test**

```js
test('mobile CSS declares the single-screen layout and safe-area contracts', () => {
  const html = readPreview();
  for (const contract of [
    '@media (max-width: 480px) and (min-height: 800px)',
    '.session-content',
    '.scoring-card',
    '.recent-rounds-toggle',
    '.bomb-control-row',
    '.preview-menu-handle',
    'env(safe-area-inset-top)',
    'env(safe-area-inset-bottom)',
    'prefers-reduced-motion',
  ]) {
    assert.ok(html.includes(contract), `missing responsive contract: ${contract}`);
  }
});
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
node --test --test-name-pattern="mobile CSS declares" doudizhu_app/test/preview_interactions.test.mjs
```

Expected: FAIL because the compact-layout classes and media query do not yet exist.

- [ ] **Step 3: Scope the active-session markup**

Change the active-session content container to:

```html
<div class="content session-content">
```

Change the scoring card to:

```html
<div class="card scoring-card">
```

- [ ] **Step 4: Add base disclosure and accessibility styles**

Add:

```css
.sr-only { position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px;
  overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0; }
.preview-menu-handle { position: fixed; top: env(safe-area-inset-top); left: 50%;
  z-index: 42; width: 54px; height: 24px; transform: translateX(-50%);
  border: 0; background: transparent; color: var(--muted); }
.handle-bar { display: block; width: 30px; height: 4px; margin: 5px auto;
  border-radius: 999px; background: var(--gold-soft); }
.tab-bar { position: fixed; top: 0; left: 50%; z-index: 41;
  width: min(100%, 460px); margin: 0; padding: calc(22px + env(safe-area-inset-top)) 8px 8px;
  transform: translate(-50%, -110%); opacity: 0; pointer-events: none;
  background: #090909f5; border-bottom: 1px solid var(--gold-soft);
  box-shadow: 0 12px 30px #000a; transition: transform .18s ease, opacity .18s ease; }
.tab-bar.open { transform: translate(-50%, 0); opacity: 1; pointer-events: auto; }
.recent-rounds-toggle { width: 100%; min-height: 42px; display: grid;
  grid-template-columns: auto 1fr auto; align-items: center; gap: 8px;
  border: 1px solid #3a2d22; border-radius: 12px; padding: 8px 12px;
  background: var(--card); color: var(--text); text-align: left; }
.recent-rounds-label { color: var(--gold); font-weight: 800; }
.recent-rounds-summary { overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
  color: var(--muted); text-align: right; }
.recent-rounds-toggle[aria-expanded="true"] .disclosure-icon { transform: rotate(180deg); }
.bomb-control-row { display: flex; min-height: 44px; align-items: center;
  justify-content: space-between; gap: 12px; }
.bomb-control-row .bomb-row { gap: 12px; }
.feedback:empty { display: none; }
@media (prefers-reduced-motion: reduce) {
  .tab-bar, .disclosure-icon { transition: none; }
}
```

- [ ] **Step 5: Add the 360×800 compact layout rules**

Replace the existing mobile media rule with:

```css
@media (max-width: 480px) {
  .preview-shell { padding: 0 0 env(safe-area-inset-bottom); }
  .phone { width: 100%; min-height: 100dvh; border: 0; border-radius: 0; }
  .screen { min-height: 100dvh; }
}
@media (max-width: 480px) and (min-height: 800px) {
  .app-bar { min-height: 52px; padding: 8px 14px; }
  .app-bar h1 { font-size: 19px; }
  .session-content { padding: 10px 12px calc(8px + env(safe-area-inset-bottom)); }
  .score-grid { gap: 6px; }
  .score-card { padding: 9px 5px 8px; border-top-width: 3px; }
  .player-name { font-size: 16px; }
  .score { margin-top: 4px; font-size: 23px; }
  .toolbar { gap: 6px; margin: 8px 0; }
  .toolbar button { min-height: 44px; padding: 8px 5px; }
  .scoring-title { margin: 8px 0 5px; }
  .scoring-card { padding: 9px 10px 10px; border-radius: 12px; }
  .scoring-card .section-title { margin: 7px 0 4px; }
  .scoring-card .btn-option, .scoring-card .toggle { min-height: 42px; padding: 7px 5px; }
  .scoring-card .landlord-option { padding: 6px 4px 7px; }
  .bomb-control-row { margin-top: 5px; }
  .feedback { min-height: 0; margin: 4px 0; font-size: 13px; }
  #confirm-round { min-height: 46px; padding: 9px 14px; }
}
```

If the 360×800 browser measurement exceeds the viewport, reduce only vertical gaps and padding in this media query. Do not reduce bomb buttons below 38×38 pixels or primary actions below 44 pixels high.

- [ ] **Step 6: Run the focused test and full interaction suite**

Run:

```powershell
node --test --test-name-pattern="mobile CSS declares" doudizhu_app/test/preview_interactions.test.mjs
node --test doudizhu_app/test/preview_interactions.test.mjs
```

Expected: focused test PASS; full interaction suite PASS.

- [ ] **Step 7: Commit responsive styling**

```powershell
git add -- doudizhu_app/preview.html doudizhu_app/test/preview_interactions.test.mjs
git commit -m "style: fit active scoring into mobile viewport"
```

---

### Task 4: PWA Cache Release and End-to-End Verification

**Files:**
- Modify: `doudizhu_app/sw.js:3`
- Modify: `doudizhu_app/test/service_worker.test.mjs`
- Verify: `doudizhu_app/preview.html`

**Interfaces:**
- Consumes: complete HTML/CSS/JavaScript shell from Tasks 1–3.
- Produces: cache namespace `doudizhu-shell-<scope>::v2` and verified phone-size behavior.

- [ ] **Step 1: Extend the worker harness and write a failing cache-version test**

Track the names passed to `caches.open()`:

```js
const openedCaches = [];
const caches = {
  open: async name => { openedCaches.push(name); return cache; },
  // keep existing keys, delete, and match implementations
};
```

Return `openedCaches` from `loadWorker()` and add:

```js
test('release opens the v2 shell cache and retires v1', async () => {
  const h = loadWorker({
    cacheKeys: [
      'doudizhu-shell-%2Frepo%2Fdoudizhu_app::v1',
      'doudizhu-shell-%2Frepo%2Fdoudizhu_app::v2',
    ],
  });
  await h.dispatchExtendable('install');
  await h.dispatchExtendable('activate');
  assert.ok(h.openedCaches.includes('doudizhu-shell-%2Frepo%2Fdoudizhu_app::v2'));
  assert.deepEqual(h.deletedCaches, ['doudizhu-shell-%2Frepo%2Fdoudizhu_app::v1']);
});
```

- [ ] **Step 2: Run the focused worker test and verify RED**

Run:

```powershell
node --test --test-name-pattern="release opens the v2" doudizhu_app/test/service_worker.test.mjs
```

Expected: FAIL because the current shell cache is still `v1`.

- [ ] **Step 3: Bump the shell cache version**

Change exactly:

```js
const CACHE_NAME = CACHE_PREFIX + 'v2';
```

Update existing worker-test fixtures that identify the current cache from `::v1` to `::v2`; retain `::v1` as the previous-cache deletion case.

- [ ] **Step 4: Run all automated tests**

Run:

```powershell
node --test doudizhu_app/test/preview_interactions.test.mjs
node --test doudizhu_app/test/pwa_assets.test.mjs
node --test doudizhu_app/test/service_worker.test.mjs
git diff --check
```

Expected: every Node test PASS and `git diff --check` exits 0 with no whitespace errors.

- [ ] **Step 5: Verify the three target viewports in the browser**

Start or reuse a local static server rooted at `doudizhu_app`, open `preview.html`, seed or create an active session, and inspect these exact viewports:

```text
360 × 800
390 × 844
430 × 932
```

At each viewport verify:

```text
- document.documentElement.scrollWidth === viewport width
- #confirm-round is visible without scrolling when recent rounds and preview menu are collapsed
- score cards, toolbar, landlord, win/loss, kick states, bomb controls, and confirm button are not clipped
- preview menu is hidden initially, opens through the handle and downward pull at scrollY 0, then closes after navigation
- recent rounds opens and closes while aria-expanded changes
- selecting landlord/win/bombs and confirming adds the correct recent round
- undo restores totals and draft controls
```

Capture one 360×800 screenshot with the full core workflow visible.

- [ ] **Step 6: Verify installed/offline update behavior**

Using the local secure/PWA-capable host or the deployed HTTPS URL after release:

```text
1. Load the old v1 app once.
2. Publish or serve v2 and return the app to the foreground.
3. Confirm the update banner appears.
4. Choose “立即更新”.
5. Confirm the compact layout loads and remains available after enabling airplane mode and relaunching.
```

Expected: no automatic reload before user confirmation, v2 activates after confirmation, and offline relaunch succeeds.

- [ ] **Step 7: Commit the cache release**

```powershell
git add -- doudizhu_app/sw.js doudizhu_app/test/service_worker.test.mjs
git commit -m "chore: release compact mobile shell cache"
```

- [ ] **Step 8: Final repository verification**

Run:

```powershell
git status --short
git log -5 --oneline
```

Expected: clean worktree and four implementation commits after the design/plan documentation commits.
