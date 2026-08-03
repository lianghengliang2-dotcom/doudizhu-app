# Round Score Details Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show named per-player score changes in recent rounds and history details, show final totals in history cards, and make recent rounds open by default.

**Architecture:** Keep the existing single-file static application and reuse the already persisted `round.scores` and `session.totals`. Add small HTML-formatting helpers shared by the active-session and history renderers, then publish the changed precached shell as Service Worker cache `v5`.

**Tech Stack:** Static HTML/CSS/JavaScript, Node.js built-in `node:test`, existing zero-dependency DOM shim, Service Worker Cache API, in-app browser viewport verification.

## Global Constraints

- Recent rounds show at most three rounds, newest first, and are expanded by default.
- Clicking the recent-rounds header still collapses and re-expands the list with correct `aria-expanded`, `aria-controls`, and `hidden` state.
- Every round card shows `第 N 局 · 玩家名地主 · 胜/负` plus all three player names and signed score changes in session player order.
- Positive scores include `+`; negative scores retain `-`; zero displays as `0`.
- Player identity uses the existing player color; score numbers use the existing positive, negative, and zero score colors.
- History list cards show player names, end time, round count, and all three final totals.
- History detail shows every round newest first using the same two-line round card.
- Missing `round.scores[playerId]` or `session.totals[playerId]` displays `0` without throwing.
- Do not change scoring formulas, undo behavior, player data, session shape, localStorage schema, history snapshots, update prompt semantics, or Service Worker fetch behavior.
- Keep player names HTML-escaped and introduce no framework or third-party dependency.
- Layout must not overflow horizontally at 360, 390, or 430 CSS pixels; vertical scrolling is allowed.

## File Structure

- Modify `doudizhu_app/preview.html`: own score formatting helpers, shared round-detail markup, recent-round default state, history totals, and responsive styling.
- Modify `doudizhu_app/test/preview_interactions.test.mjs`: own active recent-round, history-list, history-detail, fallback, and regression contracts.
- Modify `doudizhu_app/sw.js`: advance the changed precached shell from `v4` to `v5`.
- Modify `doudizhu_app/test/service_worker.test.mjs`: prove the v5 cache release cleans only older caches in the same scope.

---

### Task 1: Shared Round Breakdown and Default-Open Recent Rounds

**Files:**
- Modify: `doudizhu_app/preview.html:78-129`
- Modify: `doudizhu_app/preview.html:477-559`
- Test: `doudizhu_app/test/preview_interactions.test.mjs:752-775`

**Interfaces:**
- Consumes: `escapeHtml(text)`, active-session `session.playerIds`, `round.landlordId`, `round.isLandlordWin`, and `round.scores`.
- Produces: `formatSignedScore(value) -> string`, `scorePolarity(value) -> "positive" | "negative" | "zero"`, `scoreBreakdownMarkup(players, scores) -> string`, and `roundDetailMarkup(round, players) -> string`.

- [ ] **Step 1: Replace the collapsed-default test with a failing detailed/default-open test**

Replace `recent rounds are collapsed by default and toggle accessibly` with:

```js
test('recent rounds open by default and show named signed score changes', () => {
  const first = loadPreview();
  let state = first.window.previewApp.defaultState();
  const ids = state.players.slice(0, 3).map(player => player.id);
  state = first.window.previewApp.createSession(state, ids);
  state = first.window.previewApp.confirmRound(state, {
    landlordId: ids[2], isLandlordWin: true, bombCount: 1, kickStates: {},
  });

  const { document } = loadPreview({ seed: { doudizhu_state: JSON.stringify(state) } });
  const toggle = document.getElementById('recent-rounds-toggle');
  const list = document.getElementById('recent-rounds');
  assert.equal(toggle.getAttribute('aria-expanded'), 'true');
  assert.equal(list.hasAttribute('hidden'), false);

  const detail = list.querySelector('.round-detail');
  assert.ok(detail);
  assert.match(detail.textContent, /第 1 局/);
  assert.match(detail.textContent, /王五地主/);
  assert.match(detail.textContent, /胜/);
  assert.match(detail.textContent, /张三\s*-10/);
  assert.match(detail.textContent, /李四\s*-10/);
  assert.match(detail.textContent, /王五\s*\+20/);
  const text = detail.textContent;
  assert.ok(text.indexOf('张三') < text.indexOf('李四'));
  assert.ok(text.indexOf('李四') < text.indexOf('王五'));

  toggle.click();
  assert.equal(toggle.getAttribute('aria-expanded'), 'false');
  assert.equal(list.hasAttribute('hidden'), true);
  toggle.click();
  assert.equal(toggle.getAttribute('aria-expanded'), 'true');
  assert.equal(list.hasAttribute('hidden'), false);
});
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
node --test --test-name-pattern="recent rounds open by default" doudizhu_app/test/preview_interactions.test.mjs
```

Expected: FAIL because the list starts hidden and the current round rows omit player score changes.

- [ ] **Step 3: Add shared score and round markup helpers**

Add immediately after `formatTime(value)`:

```js
function formatSignedScore(value) {
  const score = Number(value || 0);
  return score > 0 ? '+' + score : String(score);
}
function scorePolarity(value) {
  const score = Number(value || 0);
  return score > 0 ? 'positive' : (score < 0 ? 'negative' : 'zero');
}
function scoreBreakdownMarkup(players, scores) {
  return '<div class="round-scores">' + players.map(player => {
    const score = Number((scores && scores[player.id]) || 0);
    return '<span class="round-player-score" style="--player-color:'+
      escapeHtml(player.color || '#c9a227')+'"><i aria-hidden="true"></i><span>'+
      escapeHtml(player.name)+'</span><strong class="score '+scorePolarity(score)+'">'+
      formatSignedScore(score)+'</strong></span>';
  }).join('') + '</div>';
}
function roundDetailMarkup(round, players) {
  const landlord = players.find(player => player.id === round.landlordId) || { name: '?' };
  return '<div class="card round-detail"><div class="round-heading"><span>第 '+
    round.index+' 局 · '+escapeHtml(landlord.name)+'地主</span><strong>'+
    (round.isLandlordWin ? '胜' : '负')+'</strong></div>'+
    scoreBreakdownMarkup(players, round.scores)+'</div>';
}
```

- [ ] **Step 4: Add compact responsive styles**

Add near the current `.round-row` and history styles:

```css
.round-detail { display: grid; gap: 6px; margin-bottom: 8px; }
.round-heading { display: flex; justify-content: space-between; gap: 10px; align-items: center; }
.round-scores { display: flex; flex-wrap: wrap; gap: 5px 10px; }
.round-player-score { display: inline-flex; align-items: center; gap: 4px; min-width: 0; font-size: 13px; }
.round-player-score i { width: 8px; height: 8px; flex: 0 0 8px; border-radius: 50%; background: var(--player-color); }
.round-player-score .score { font-size: 14px; line-height: 1; }
```

- [ ] **Step 5: Make recent rounds default open and reuse the shared card**

Change the initial markup to `aria-expanded="true"` and remove `hidden` from `#recent-rounds`. Initialize:

```js
let recentRoundsExpanded = true;
```

In `renderHomeSession()`, replace the recent-row mapping with:

```js
const recentPlayers = session.playerIds.map(id => playerById(id));
byId('recent-rounds').innerHTML = recent.length
  ? recent.map(round => roundDetailMarkup(round, recentPlayers)).join('')
  : '<div class="card empty-card">还没有记分记录</div>';
```

Replace the final reset with:

```js
setRecentRoundsExpanded(true);
```

- [ ] **Step 6: Run focused and complete interaction tests**

Run:

```powershell
node --test --test-name-pattern="recent rounds open by default" doudizhu_app/test/preview_interactions.test.mjs
node --test doudizhu_app/test/preview_interactions.test.mjs
git diff --check
```

Expected: focused test PASS, all interaction tests PASS, and no whitespace errors.

- [ ] **Step 7: Commit Task 1**

```powershell
git add -- doudizhu_app/preview.html doudizhu_app/test/preview_interactions.test.mjs
git commit -m "feat: show detailed recent round scores"
```

---

### Task 2: History Totals and Per-Round Score Changes

**Files:**
- Modify: `doudizhu_app/preview.html:618-641`
- Test: `doudizhu_app/test/preview_interactions.test.mjs`

**Interfaces:**
- Consumes: Task 1 `scoreBreakdownMarkup(players, scores)` and `roundDetailMarkup(round, players)`.
- Produces: history list cards with totals and history detail cards with per-round breakdowns.

- [ ] **Step 1: Add failing history list/detail tests**

Add before `script executes without throwing on load`:

```js
test('history list shows final totals and detail shows every round score change', () => {
  const first = loadPreview();
  let state = first.window.previewApp.defaultState();
  const ids = state.players.slice(0, 3).map(player => player.id);
  state = first.window.previewApp.createSession(state, ids);
  state = first.window.previewApp.confirmRound(state, {
    landlordId: ids[2], isLandlordWin: true, bombCount: 1, kickStates: {},
  });
  state = first.window.previewApp.confirmRound(state, {
    landlordId: ids[0], isLandlordWin: false, bombCount: 0, kickStates: {},
  });
  state = first.window.previewApp.endSession(state);

  const { document } = loadPreview({ seed: { doudizhu_state: JSON.stringify(state) } });
  document.querySelector('[data-screen="history"]').click();
  const historyItem = document.querySelector('#history-list .history-item');
  assert.match(historyItem.textContent, /张三\s*-20/);
  assert.match(historyItem.textContent, /李四\s*-5/);
  assert.match(historyItem.textContent, /王五\s*\+25/);

  historyItem.click();
  const detail = document.getElementById('detail-content');
  const rounds = detail.querySelectorAll('.round-detail');
  assert.equal(rounds.length, 2);
  assert.match(rounds[0].textContent, /张三\s*-10/);
  assert.match(rounds[0].textContent, /李四\s*\+5/);
  assert.match(rounds[0].textContent, /王五\s*\+5/);
  assert.match(rounds[1].textContent, /张三\s*-10/);
  assert.match(rounds[1].textContent, /李四\s*-10/);
  assert.match(rounds[1].textContent, /王五\s*\+20/);
});

test('history score breakdown defaults missing saved scores to zero', () => {
  const first = loadPreview();
  let state = first.window.previewApp.defaultState();
  const ids = state.players.slice(0, 3).map(player => player.id);
  state = first.window.previewApp.createSession(state, ids);
  state = first.window.previewApp.confirmRound(state, {
    landlordId: ids[0], isLandlordWin: true, bombCount: 0, kickStates: {},
  });
  state = first.window.previewApp.endSession(state);
  delete state.history[0].totals[ids[1]];
  delete state.history[0].rounds[0].scores[ids[1]];

  const { document, scriptError } = loadPreview({ seed: { doudizhu_state: JSON.stringify(state) } });
  document.querySelector('[data-screen="history"]').click();
  assert.match(document.querySelector('#history-list .history-item').textContent, /李四\s*0/);
  document.querySelector('#history-list .history-item').click();
  assert.match(document.querySelector('#detail-content .round-detail').textContent, /李四\s*0/);
  assert.equal(scriptError, undefined);
});
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```powershell
node --test --test-name-pattern="history list shows final totals|history score breakdown defaults" doudizhu_app/test/preview_interactions.test.mjs
```

Expected: FAIL because history list cards omit totals and detail rows omit named per-player changes.

- [ ] **Step 3: Render final totals in history cards**

In `renderHistory()`, build each button with:

```js
const snapshots = session.players || session.playerIds.map(id => playerById(id));
button.innerHTML = '<div class="history-main"><strong>'+
  escapeHtml(snapshots.map(player => player.name).join('、'))+'</strong><span>'+
  escapeHtml(formatTime(session.endedAt || session.startedAt))+' · '+
  session.rounds.length+' 局</span>'+scoreBreakdownMarkup(snapshots, session.totals)+
  '</div><b aria-hidden="true">›</b>';
```

Add:

```css
.history-main { min-width: 0; flex: 1; display: grid; gap: 5px; }
.history-item .round-scores { margin-top: 2px; }
```

- [ ] **Step 4: Reuse detailed round cards in history detail**

In `renderDetail()`, replace the current `round-row` mapping with:

```js
session.rounds.length
  ? session.rounds.slice().reverse().map(round => roundDetailMarkup(round, snapshots)).join('')
  : '<div class="card empty-card">没有局记录</div>'
```

Keep the existing top totals card and newest-first ordering.

- [ ] **Step 5: Run focused and complete tests**

Run:

```powershell
node --test --test-name-pattern="history list shows final totals|history score breakdown defaults" doudizhu_app/test/preview_interactions.test.mjs
node --test doudizhu_app/test/preview_interactions.test.mjs
git diff --check
```

Expected: focused tests PASS, complete interaction suite PASS, and no whitespace errors.

- [ ] **Step 6: Commit Task 2**

```powershell
git add -- doudizhu_app/preview.html doudizhu_app/test/preview_interactions.test.mjs
git commit -m "feat: show score changes in history"
```

---

### Task 3: PWA v5 Release and Mobile Verification

**Files:**
- Modify: `doudizhu_app/sw.js:3`
- Modify: `doudizhu_app/test/service_worker.test.mjs:21-160`
- Verify: `doudizhu_app/preview.html`

**Interfaces:**
- Consumes: the final changed shell from Tasks 1 and 2 and the existing scope-qualified `CACHE_PREFIX`.
- Produces: shell cache `doudizhu-shell-<scope>::v5`.

- [ ] **Step 1: Update cache fixtures and add the failing v5 release test**

Change current-cache fixtures from `::v4` to `::v5`. Replace the v4 release test with:

```js
test('v5 release opens the current cache, retires v1 through v4, and preserves other scopes', async () => {
  const h = loadWorker({
    cacheKeys: [
      'doudizhu-shell-%2Frepo%2Fdoudizhu_app::v1',
      'doudizhu-shell-%2Frepo%2Fdoudizhu_app::v2',
      'doudizhu-shell-%2Frepo%2Fdoudizhu_app::v3',
      'doudizhu-shell-%2Frepo%2Fdoudizhu_app::v4',
      'doudizhu-shell-%2Frepo%2Fdoudizhu_app::v5',
      'doudizhu-shell-%2Frepo%2Fdoudizhu_app-v5::v4',
      'doudizhu-shell-%2Frepo%2Fother_app::v4',
    ],
  });
  await h.dispatchExtendable('install');
  await h.dispatchExtendable('activate');
  assert.ok(h.openedCaches.includes('doudizhu-shell-%2Frepo%2Fdoudizhu_app::v5'));
  assert.deepEqual(h.deletedCaches, [
    'doudizhu-shell-%2Frepo%2Fdoudizhu_app::v1',
    'doudizhu-shell-%2Frepo%2Fdoudizhu_app::v2',
    'doudizhu-shell-%2Frepo%2Fdoudizhu_app::v3',
    'doudizhu-shell-%2Frepo%2Fdoudizhu_app::v4',
  ]);
});
```

- [ ] **Step 2: Run the v5 test and verify RED**

Run:

```powershell
node --test --test-name-pattern="v5 release opens" doudizhu_app/test/service_worker.test.mjs
```

Expected: FAIL because `sw.js` still opens `::v4`.

- [ ] **Step 3: Publish the shell as v5**

Change exactly:

```js
const CACHE_NAME = CACHE_PREFIX + 'v5';
```

Do not change install, activate, message, or fetch handlers.

- [ ] **Step 4: Run all automated tests**

Run:

```powershell
node --test doudizhu_app/test/preview_interactions.test.mjs doudizhu_app/test/pwa_assets.test.mjs doudizhu_app/test/service_worker.test.mjs
git diff --check
```

Expected: all tests PASS and `git diff --check` exits 0.

- [ ] **Step 5: Verify three mobile viewports in the browser**

Serve `doudizhu_app` from a fresh local origin, create an active three-player session, record at least three rounds, and verify at `360×800`, `390×844`, and `430×932`:

```text
- document.documentElement.scrollWidth === innerWidth
- #recent-rounds-toggle has aria-expanded="true" on entry
- #recent-rounds is visible and contains at most three .round-detail cards
- every visible .round-detail shows three .round-player-score items
- positive values include +, negative values include -, and player order is stable
- clicking the toggle hides the list and clicking again shows it
- vertical page scrolling remains usable
```

End the session, open History, and verify:

```text
- each history card displays all three final totals
- clicking a history card opens detail
- every saved round displays all three named score changes
- no horizontal overflow occurs in any target viewport
```

- [ ] **Step 6: Verify explicit update and offline restart**

Using an origin already controlled by v4:

```text
1. Load the v4 app.
2. Serve v5 and wait for the explicit update banner.
3. Click “立即更新”.
4. Confirm the detailed recent/history score UI loads.
5. Stop the server and reopen the same URL.
6. Confirm v5 starts from the Service Worker cache.
```

- [ ] **Step 7: Commit Task 3**

```powershell
git add -- doudizhu_app/sw.js doudizhu_app/test/service_worker.test.mjs
git commit -m "chore: release detailed score shell cache"
```

- [ ] **Step 8: Final branch verification**

Run:

```powershell
git status --short
git log -6 --oneline
```

Expected: clean worktree with all three implementation commits after the design and plan commits.
