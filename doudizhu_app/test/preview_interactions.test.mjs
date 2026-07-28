// RED-phase test for doudizhu_app/preview.html
// Runs with: node --test doudizhu_app/test/preview_interactions.test.mjs
// Zero third-party dependencies: uses node:test + node:assert + node:vm + a
// self-contained minimal DOM/localStorage shim bundled in this file.
//
// Contract this test expects preview.html to provide (exposed on window.previewApp):
//   calcBaseScore(n) -> number                                 // user-confirmed landlord award scale
//   calcRoundScores({ isLandlordWin, spring, blind, kickCount, bombCount })
//       -> { landlordScore, farmerAScore, farmerBScore }        // matches calculateRoundScores
//   defaultState() -> { players, activeSession, history, draftRound, schemaVersion }
//   loadState(storage) -> state                                 // safe fallback on corrupt/incompatible
//   saveState(storage, state)                                   // single-namespace persistence
//   createSession(state, playerIds) -> state                    // requires exactly 3 player ids
//   confirmRound(state, draft) -> state                         // appends round, updates totals
//   undoLastRound(state) -> state                               // removes last round, restores totals/draft
//   endSession(state) -> state                                  // moves activeSession into history snapshot
//
// Supported DOM APIs in the shim (GREEN implementation should stay within this subset):
//   document.getElementById/querySelector/querySelectorAll, document.createElement
//   el.classList.add/remove/toggle/contains, el.addEventListener, el.click()
//   el.querySelector/querySelectorAll, el.children, el.parentElement
//   el.innerHTML/textContent/value/dataset/style, el.appendChild/removeChild/setAttribute
//   localStorage.getItem/setItem/removeItem/key/length, window, globalThis, event
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import vm from 'node:vm';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PREVIEW = join(__dirname, '..', 'preview.html');

function readPreview() {
  return readFileSync(PREVIEW, 'utf8');
}

// ---- minimal DOM / localStorage shim (no external deps) ----------------------
const VOID = new Set(['meta','br','hr','img','input','link','base','col','area','source','track','wbr','!doctype']);

class Node {
  constructor(tag, attrs = {}) {
    this.tagName = (tag || '').toUpperCase();
    this.nodeType = 1;
    this.attributes = { ...attrs };
    this.children = [];
    this.parentNode = null;
    this.eventListeners = {};
    this.style = {};
    this.value = attrs.value != null ? String(attrs.value) : '';
    this._text = '';
    if (this.tagName === 'INPUT' || this.tagName === 'TEXTAREA') {
      this._value = attrs.value != null ? String(attrs.value) : '';
    }
  }
  get id() { return this.attributes.id || ''; }
  get className() { return this.attributes.class || ''; }
  get dataset() {
    const ds = {};
    for (const k of Object.keys(this.attributes)) {
      if (k.startsWith('data-')) {
        ds[k.slice(5).replace(/-([a-z])/g, (_, c) => c.toUpperCase())] = this.attributes[k];
      }
    }
    return ds;
  }
  get classList() {
    const self = this;
    const tokens = () => (self.className || '').split(/\s+/).filter(Boolean);
    return {
      get length() { return tokens().length; },
      add(...t) { const s = new Set(tokens()); t.forEach(x => s.add(x)); self.setAttribute('class', [...s].join(' ')); },
      remove(...t) { const s = new Set(tokens()); t.forEach(x => s.delete(x)); self.setAttribute('class', [...s].join(' ')); },
      toggle(t, force) {
        const list = tokens(); const has = list.includes(t);
        const next = force === undefined ? !has : force;
        if (next && !has) list.push(t);
        if (!next && has) { const i = list.indexOf(t); if (i >= 0) list.splice(i, 1); }
        self.setAttribute('class', list.join(' '));
        return next;
      },
      contains(t) { return tokens().includes(t); },
    };
  }
  setAttribute(k, v) { this.attributes[k] = String(v); if (k === 'value') this.value = String(v); }
  getAttribute(k) { return this.attributes[k] != null ? this.attributes[k] : null; }
  hasAttribute(k) { return k in this.attributes; }
  removeAttribute(k) { delete this.attributes[k]; }
  get parentElement() { return this.parentNode && this.parentNode.nodeType === 1 ? this.parentNode : null; }
  appendChild(c) { c.parentNode = this; this.children.push(c); return c; }
  removeChild(c) { const i = this.children.indexOf(c); if (i >= 0) { this.children.splice(i, 1); c.parentNode = null; } return c; }
  addEventListener(type, fn) { (this.eventListeners[type] ||= []).push(fn); }
  removeEventListener(type, fn) {
    const a = this.eventListeners[type]; if (!a) return;
    const i = a.indexOf(fn); if (i >= 0) a.splice(i, 1);
  }
  click(ev) { (this.eventListeners.click || []).forEach(fn => { try { fn.call(this, ev); } catch (e) { this.__clickError = e; throw e; } }); }
  querySelector(sel) { return queryAll(this, sel)[0] || null; }
  querySelectorAll(sel) { return queryAll(this, sel); }
  get textContent() {
    let s = this._text || '';
    for (const c of this.children) s += (c.textContent != null ? c.textContent : '');
    return s;
  }
  set textContent(v) { this.children = []; this._text = String(v); }
  get innerHTML() {
    if (this._rawHtml != null) return this._rawHtml;
    let s = '';
    for (const c of this.children) s += serializeNode(c);
    return s + (this._text || '');
  }
  set innerHTML(v) { this.children = []; this._rawHtml = String(v); this._text = String(v); }
}

function serializeNode(n) {
  if (!n || n.nodeType !== 1) return '';
  const attrs = Object.entries(n.attributes).map(([k, v]) => ` ${k}="${v}"`).join('');
  return `<${n.tagName.toLowerCase()}${attrs}>${(n._text || '')}</${n.tagName.toLowerCase()}>`;
}

function parseHtml(html) {
  const root = new Node('#document');
  const stack = [root];
  let lastIndex = 0;
  const tagRe = /<(\/?)([a-zA-Z][\w-]*)((?:[^>]*?))>/g;
  let m;
  while ((m = tagRe.exec(html)) !== null) {
    const [full, closing, tag, attrStrRaw] = m;
    const text = html.slice(lastIndex, m.index);
    if (text.trim()) {
      const tn = new Node('#text'); tn._text = text; tn.textContent = text;
      stack[stack.length - 1].appendChild(tn);
    }
    lastIndex = m.index + full.length;
    const lower = tag.toLowerCase();
    if (closing) {
      // pop until matching tag
      for (let i = stack.length - 1; i >= 1; i--) {
        if (stack[i].tagName === lower.toUpperCase()) { stack.length = i; break; }
      }
      continue;
    }
    const attrs = {};
    const attrRe = /([a-zA-Z_:][\w:.-]*)(?:\s*=\s*"([^"]*)")?/g;
    let a;
    while ((a = attrRe.exec(attrStrRaw)) !== null) {
      attrs[a[1].toLowerCase()] = a[2] != null ? a[2] : '';
    }
    const el = new Node(lower, attrs);
    el._rawAttrs = attrStrRaw;
    stack[stack.length - 1].appendChild(el);
    if (!VOID.has(lower)) stack.push(el);
  }
  return root;
}

const SIMPLE_SELECTOR_RE = /^([a-zA-Z][\w-]*)?(?:#([\w-]+))?(?:\.([\w-]+))?$/;
function matchesSimple(el, sel) {
  const m = sel.match(SIMPLE_SELECTOR_RE);
  if (!m) return false;
  const [, tag, id, cls] = m;
  if (tag && el.tagName !== tag.toUpperCase()) return false;
  if (id && el.id !== id) return false;
  if (cls && !(el.className || '').split(/\s+/).includes(cls)) return false;
  return true;
}

function queryAll(root, selector) {
  const result = [];
  const sels = selector.split(',').map(s => s.trim()).filter(Boolean);
  const walk = (n) => {
    if (n.nodeType === 1) {
      for (const s of sels) {
        // comma of simple selectors or descendant "a b"
        if (s.includes(' ')) {
          // descendant handled at query level below
        } else if (matchesSimple(n, s)) { result.push(n); break; }
      }
    }
    for (const c of n.children) walk(c);
  };
  walk(root);
  // descendant selectors "a b"
  for (const s of sels) {
    if (s.includes(' ')) {
      const parts = s.trim().split(/\s+/);
      // find all matching last part whose ancestors chain matches
      const all = [];
      const collect = (n) => { if (n.nodeType === 1) all.push(n); for (const c of n.children) collect(c); };
      collect(root);
      for (const el of all) {
        if (!matchesSimple(el, parts[parts.length - 1])) continue;
        let cur = el.parentElement; let pi = parts.length - 2; let ok = true;
        while (pi >= 0 && cur) { if (matchesSimple(cur, parts[pi])) pi--; else cur = cur.parentElement; }
        if (pi < 0 && !result.includes(el)) result.push(el);
      }
    }
  }
  return result;
}

class Document {
  constructor(root) { this.root = root; this.body = root.children.find(c => c.tagName === 'BODY') || root; this.head = root.children.find(c => c.tagName === 'HEAD'); }
  getElementById(id) { const r = queryAll(this.root, `#${id}`); return r[0] || null; }
  querySelector(sel) { return queryAll(this.root, sel)[0] || null; }
  querySelectorAll(sel) { return queryAll(this.root, sel); }
  createElement(tag) { return new Node(tag.toLowerCase()); }
}

class Storage {
  constructor() { this._m = new Map(); this._keys = []; }
  getItem(k) { return this._m.has(k) ? this._m.get(k) : null; }
  setItem(k, v) { if (!this._m.has(k)) this._keys.push(k); this._m.set(k, String(v)); }
  removeItem(k) { this._m.delete(k); this._keys = this._keys.filter(x => x !== k); }
  key(i) { return this._keys[i] != null ? this._keys[i] : null; }
  get length() { return this._keys.length; }
  clear() { this._m.clear(); this._keys = []; }
}

function loadPreview(options = {}) {
  const html = readPreview();
  const docRoot = parseHtml(html);
  const doc = new Document(docRoot);
  const localStorage = new Storage();
  if (options.seed) for (const [k, v] of Object.entries(options.seed)) localStorage.setItem(k, v);

  const window = {};
  const sandbox = {
    window,
    document: doc,
    localStorage,
    console,
    setTimeout: () => {}, clearTimeout: () => {},
    event: undefined,
  };
  sandbox.globalThis = sandbox;
  sandbox.window = sandbox;
  sandbox.self = sandbox;

  // Extract source text directly. The minimal HTML parser intentionally does
  // not implement raw-text elements, so serialising a parsed <script> would
  // turn its text node into a fake "<#text>" tag.
  const code = extractScript();
  const ctx = vm.createContext(sandbox);
  try { vm.runInContext(code, ctx); } catch (e) { sandbox.__scriptError = e; }

  return { sandbox, window: sandbox, document: doc, localStorage, scriptError: sandbox.__scriptError };
}

function extractScript() {
  const html = readPreview();
  const m = html.match(/<script>([\s\S]*?)<\/script>/);
  return m ? m[1] : '';
}

// ====== Part A: pure business logic + persistence contract ==================

test('previewApp namespace is exposed for headless testing', () => {
  const { window } = loadPreview();
  assert.ok(window.previewApp, 'preview.html must expose window.previewApp so business logic is testable without a browser');
});

test('calcBaseScore follows the user-confirmed landlord award scale', () => {
  const { window } = loadPreview();
  const { calcBaseScore } = window.previewApp;
  assert.equal(typeof calcBaseScore, 'function', 'calcBaseScore must be a function');
  // User-confirmed preview rule: landlord base award starts at 10 and doubles.
  assert.equal(calcBaseScore(0), 10);
  assert.equal(calcBaseScore(1), 20);
  assert.equal(calcBaseScore(2), 40);
  assert.equal(calcBaseScore(3), 80);
  assert.equal(calcBaseScore(4), 160);
  assert.equal(calcBaseScore(5), 320);
  assert.equal(calcBaseScore(6), 420);
  assert.equal(calcBaseScore(7), 520);
});

test('calcRoundScores uses the confirmed base award and sums to zero (landlord win)', () => {
  const { window } = loadPreview();
  const { calcRoundScores } = window.previewApp;
  assert.equal(typeof calcRoundScores, 'function');
  // landlord win, no spring/blind/kick/bomb
  const r0 = calcRoundScores({ isLandlordWin: true, spring: false, blind: false, kickCount: 0, bombCount: 0 });
  // nBase=0 => landlord +10; each farmer pays 5.
  assert.equal(r0.landlordScore, 10);
  assert.equal(r0.farmerAScore, -5);
  assert.equal(r0.farmerBScore, -5);
  assert.equal(r0.landlordScore + r0.farmerAScore + r0.farmerBScore, 0);
});

test('calcRoundScores landlord loss flips signs', () => {
  const { window } = loadPreview();
  const { calcRoundScores } = window.previewApp;
  const r = calcRoundScores({ isLandlordWin: false, spring: false, blind: false, kickCount: 0, bombCount: 0 });
  assert.equal(r.landlordScore, -10);
  assert.equal(r.farmerAScore, 5);
  assert.equal(r.farmerBScore, 5);
  assert.equal(r.landlordScore + r.farmerAScore + r.farmerBScore, 0);
});

test('calcRoundScores applies bombs (multiplier) and three scores sum to zero', () => {
  const { window } = loadPreview();
  const { calcRoundScores } = window.previewApp;
  // 1 bomb => nBase=1 => landlord +20
  const r = calcRoundScores({ isLandlordWin: true, spring: false, blind: false, kickCount: 0, bombCount: 1 });
  assert.equal(r.landlordScore, 20);
  assert.equal(r.farmerAScore, -10);
  assert.equal(r.farmerBScore, -10);
  assert.equal(r.landlordScore + r.farmerAScore + r.farmerBScore, 0);
});

test('calcRoundScores gives landlord 40 for two bombs', () => {
  const { window } = loadPreview();
  const r = window.previewApp.calcRoundScores({ isLandlordWin: true, spring: false, blind: false, kickCount: 0, bombCount: 2 });
  assert.equal(r.landlordScore, 40);
  assert.equal(r.farmerAScore, -20);
  assert.equal(r.farmerBScore, -20);
  assert.equal(r.landlordScore + r.farmerAScore + r.farmerBScore, 0);
});

test('calcRoundScores applies kick (asymmetric farmer halves) and sums to zero', () => {
  const { window } = loadPreview();
  const { calcRoundScores } = window.previewApp;
  // nBase=0 => 10; kick=1 => kick side 20. Farmer A pays 10, farmer B pays 5.
  const r = calcRoundScores({ isLandlordWin: true, spring: false, blind: false, kickCount: 1, bombCount: 0 });
  assert.equal(r.landlordScore, 15);
  assert.equal(r.farmerAScore, -10);
  assert.equal(r.farmerBScore, -5);
  assert.equal(r.landlordScore + r.farmerAScore + r.farmerBScore, 0);
});

test('calcRoundScores supports independent three-state choices for both farmers', () => {
  const { window } = loadPreview();
  const calc = window.previewApp.calcRoundScores;
  const base = { isLandlordWin: true, spring: false, blind: false, bombCount: 0 };
  const cases = [
    { farmerAKickCount: 0, farmerBKickCount: 0, expected: [10, -5, -5] },
    { farmerAKickCount: 1, farmerBKickCount: 0, expected: [15, -10, -5] },
    { farmerAKickCount: 2, farmerBKickCount: 0, expected: [25, -20, -5] },
    { farmerAKickCount: 1, farmerBKickCount: 2, expected: [30, -10, -20] },
  ];
  for (const item of cases) {
    const result = calc({ ...base, farmerAKickCount: item.farmerAKickCount, farmerBKickCount: item.farmerBKickCount });
    assert.deepEqual(
      [result.landlordScore, result.farmerAScore, result.farmerBScore],
      item.expected,
      `independent states ${item.farmerAKickCount}/${item.farmerBKickCount}`,
    );
    assert.equal(result.landlordScore + result.farmerAScore + result.farmerBScore, 0);
  }
});

test('independent farmer states flip all score signs when landlord loses', () => {
  const { window } = loadPreview();
  const result = window.previewApp.calcRoundScores({
    isLandlordWin: false, spring: false, blind: false, bombCount: 0,
    farmerAKickCount: 1, farmerBKickCount: 2,
  });
  assert.deepEqual(
    [result.landlordScore, result.farmerAScore, result.farmerBScore],
    [-30, 10, 20],
  );
});

test('defaultState has 5 players, no active session, empty history, schemaVersion', () => {
  const { window } = loadPreview();
  const state = window.previewApp.defaultState();
  assert.equal(state.players.length, 5);
  assert.equal(state.activeSession, null);
  assert.deepEqual(JSON.parse(JSON.stringify(state.history)), []);
  assert.ok(state.schemaVersion != null);
});

test('persistence round-trips state via a single namespaced key', () => {
  const { window, localStorage } = loadPreview();
  const { defaultState, saveState, loadState } = window.previewApp;
  const state = defaultState();
  saveState(localStorage, state);
  const loaded = loadState(localStorage);
  assert.deepEqual(loaded, state);
  // exactly one key used for app state
  const usedKeys = [];
  for (let i = 0; i < localStorage.length; i++) usedKeys.push(localStorage.key(i));
  assert.equal(usedKeys.length, 1, 'state should persist under a single namespace key');
});

test('loadState safely falls back to defaults on corrupt data', () => {
  const { window } = loadPreview();
  const localStorage = new Storage();
  localStorage.setItem('doudizhu_state', '{ this is not valid json ((((');
  const state = window.previewApp.loadState(localStorage);
  assert.deepEqual(state, window.previewApp.defaultState(), 'corrupt storage must not throw and must return defaults');
});

test('loadState safely falls back on incompatible schema version', () => {
  const { window } = loadPreview();
  const localStorage = new Storage();
  const bogus = window.previewApp.defaultState();
  bogus.schemaVersion = 999999;
  // store under whatever key the app uses by saving then corrupting version in place
  window.previewApp.saveState(localStorage, bogus);
  const state = window.previewApp.loadState(localStorage);
  assert.deepEqual(state, window.previewApp.defaultState(), 'incompatible schema must fall back to defaults');
});

test('createSession requires exactly 3 players', () => {
  const { window } = loadPreview();
  const state = window.previewApp.defaultState();
  const ids = state.players.map(p => p.id);
  assert.throws(() => window.previewApp.createSession(state, ids.slice(0, 2)), /3|三|玩家/i, 'two players must be rejected');
  assert.throws(() => window.previewApp.createSession(state, ids), /3|三|玩家/i, 'five players must be rejected');
});

test('createSession with 3 players starts an active session with zero totals', () => {
  const { window } = loadPreview();
  const state = window.previewApp.defaultState();
  const ids = state.players.slice(0, 3).map(p => p.id);
  const next = window.previewApp.createSession(state, ids);
  assert.ok(next.activeSession);
  assert.equal(next.activeSession.playerIds.length, 3);
  next.activeSession.playerIds.forEach(id => {
    assert.equal(next.activeSession.totals[id], 0);
  });
  assert.deepEqual(JSON.parse(JSON.stringify(next.activeSession.rounds)), []);
  assert.ok(next.activeSession.startedAt);
});

test('confirmRound appends a record and updates totals, three scores sum to zero', () => {
  const { window } = loadPreview();
  let state = window.previewApp.defaultState();
  const ids = state.players.slice(0, 3).map(p => p.id);
  state = window.previewApp.createSession(state, ids);
  const [landlord, fa, fb] = ids;
  const draft = {
    landlordId: landlord,
    isLandlordWin: true,
    spring: false,
    blind: false,
    kickCount: 0,
    bombCount: 1,
    kickFarmer: fa, // which farmer is on the kick side
  };
  state = window.previewApp.confirmRound(state, draft);
  assert.equal(state.activeSession.rounds.length, 1);
  const round = state.activeSession.rounds[0];
  // 1 bomb => landlord +20, farmers -10/-10
  assert.equal(round.scores[landlord], 20);
  assert.equal(round.scores[fa], -10);
  assert.equal(round.scores[fb], -10);
  assert.equal(round.scores[landlord] + round.scores[fa] + round.scores[fb], 0);
  assert.equal(state.activeSession.totals[landlord], 20);
  assert.equal(state.activeSession.totals[fa], -10);
  assert.equal(state.activeSession.totals[fb], -10);
});

test('confirmRound persists and scores both farmers independent kick states', () => {
  const { window } = loadPreview();
  let state = window.previewApp.defaultState();
  const ids = state.players.slice(0, 3).map(p => p.id);
  state = window.previewApp.createSession(state, ids);
  const [landlord, fa, fb] = ids;
  state = window.previewApp.confirmRound(state, {
    landlordId: landlord,
    isLandlordWin: true,
    spring: false,
    blind: false,
    bombCount: 0,
    kickStates: { [fa]: 1, [fb]: 2 },
  });
  const round = state.activeSession.rounds[0];
  assert.equal(round.scores[landlord], 30);
  assert.equal(round.scores[fa], -10);
  assert.equal(round.scores[fb], -20);
  assert.deepEqual(JSON.parse(JSON.stringify(round.kickStates)), { [fa]: 1, [fb]: 2 });
});

test('undoLastRound removes only the latest round, rolls back totals, and restores its draft', () => {
  const { window } = loadPreview();
  let state = window.previewApp.defaultState();
  const ids = state.players.slice(0, 3).map(p => p.id);
  const [landlord, fa, fb] = ids;
  state = window.previewApp.createSession(state, ids);
  state = window.previewApp.confirmRound(state, {
    landlordId: landlord, isLandlordWin: true, spring: false, blind: false,
    bombCount: 0, kickStates: { [fa]: 0, [fb]: 0 },
  });
  state = window.previewApp.confirmRound(state, {
    landlordId: landlord, isLandlordWin: false, spring: true, blind: false,
    bombCount: 1, kickStates: { [fa]: 1, [fb]: 2 },
  });
  const totalsAfterFirst = { [landlord]: 10, [fa]: -5, [fb]: -5 };
  state = window.previewApp.undoLastRound(state);
  assert.equal(state.activeSession.rounds.length, 1);
  assert.deepEqual(JSON.parse(JSON.stringify(state.activeSession.totals)), totalsAfterFirst);
  assert.deepEqual(JSON.parse(JSON.stringify(state.draftRound)), {
    landlordId: landlord,
    isLandlordWin: false,
    spring: false,
    blind: false,
    kickStates: { [fa]: 1, [fb]: 2 },
    bombCount: 1,
  });
});

test('undoLastRound rejects when the active session has no recorded rounds', () => {
  const { window } = loadPreview();
  let state = window.previewApp.defaultState();
  state = window.previewApp.createSession(state, state.players.slice(0, 3).map(p => p.id));
  assert.throws(() => window.previewApp.undoLastRound(state), /没有|记录|撤回/);
});

test('endSession moves active session into history with a name snapshot', () => {
  const { window } = loadPreview();
  let state = window.previewApp.defaultState();
  const ids = state.players.slice(0, 3).map(p => p.id);
  state = window.previewApp.createSession(state, ids);
  state = window.previewApp.endSession(state);
  assert.equal(state.activeSession, null);
  assert.equal(state.history.length, 1);
  const snap = state.history[0];
  assert.ok(snap.players, 'history entry must carry a player-name snapshot');
  snap.players.forEach(p => assert.ok(p.name != null));
});

test('history name snapshot is not mutated by later player-name edits', () => {
  const { window } = loadPreview();
  let state = window.previewApp.defaultState();
  const ids = state.players.slice(0, 3).map(p => p.id);
  state = window.previewApp.createSession(state, ids);
  state = window.previewApp.endSession(state);
  const before = JSON.parse(JSON.stringify(state.history[0].players));
  // later rename a player
  state.players[0] = { ...state.players[0], name: '改名后的玩家' };
  assert.deepEqual(JSON.parse(JSON.stringify(state.history[0].players)), before, 'old history snapshot must not change when names are edited');
});

// ====== Part B: DOM wiring — app-internal navigation & controls ===============

function activeScreen(document) {
  const screens = document.querySelectorAll('.screen');
  return [...screens].find(s => s.classList.contains('active')) || null;
}

function findClickableByText(document, scopeSel, substring) {
  const scope = scopeSel ? document.querySelector(scopeSel) : document.body;
  if (!scope) return null;
  const cands = queryAll(scope, 'button, .player-item, .btn-option, .btn-small, [onclick], .history-item, .app-bar .actions span');
  return cands.find(el => (el.textContent || '').includes(substring)) || null;
}

test('app-internal "新建场次" navigates from empty home to new-session screen', () => {
  const { document } = loadPreview();
  // start on empty home
  const homeEmpty = document.getElementById('screen-home-empty');
  assert.ok(homeEmpty, 'home-empty screen must exist');
  homeEmpty.classList.add('active');
  const before = activeScreen(document);
  assert.equal(before && before.id, 'screen-home-empty');
  const btn = findClickableByText(document, '#screen-home-empty', '新建场次');
  assert.ok(btn, 'empty home must have a "新建场次" control');
  btn.click();
  const after = activeScreen(document);
  assert.equal(after && after.id, 'screen-new-session', 'clicking 新建场次 must navigate to new-session screen');
});

test('selecting fewer than 3 players blocks starting a session', () => {
  const { document } = loadPreview();
  const ns = document.getElementById('screen-new-session');
  document.querySelectorAll('.screen').forEach(screen => screen.classList.remove('active'));
  ns.classList.add('active');
  // select only two players
  const items = document.querySelectorAll('#screen-new-session .player-item');
  assert.ok(items.length >= 3, 'new-session screen must list at least 3 selectable players');
  items[0].click(); items[1].click();
  const startBtn = findClickableByText(document, '#screen-new-session', '开始');
  assert.ok(startBtn, 'new-session screen must have a start/confirm control');
  startBtn.click();
  // still on new-session (blocked) -> no active session created
  const { window } = { window: undefined };
  assert.equal(activeScreen(document) && activeScreen(document).id, 'screen-new-session', 'must remain on new-session when < 3 players selected');
});

test('active-session score cards show each player name once without a duplicate initial avatar', () => {
  const firstLoad = loadPreview();
  let state = firstLoad.window.previewApp.defaultState();
  state = firstLoad.window.previewApp.createSession(state, state.players.slice(0, 3).map(p => p.id));
  const { document } = loadPreview({ seed: { doudizhu_state: JSON.stringify(state) } });
  const scoreGrid = document.getElementById('score-grid');
  assert.ok(scoreGrid.innerHTML.includes('张三'));
  assert.equal(scoreGrid.innerHTML.includes('class="avatar"'), false, 'score cards should not repeat names as single-character avatars');
});

test('active-session score cards emphasize player identity and score polarity', () => {
  const firstLoad = loadPreview();
  let state = firstLoad.window.previewApp.defaultState();
  const ids = state.players.slice(0, 3).map(p => p.id);
  state = firstLoad.window.previewApp.createSession(state, ids);
  state.activeSession.totals[ids[0]] = 50;
  state.activeSession.totals[ids[1]] = -40;
  state.activeSession.totals[ids[2]] = -10;
  const { document } = loadPreview({ seed: { doudizhu_state: JSON.stringify(state) } });
  const html = document.getElementById('score-grid').innerHTML;
  assert.ok(html.includes('class="player-name"'), 'player names need a dedicated visual hierarchy');
  assert.ok(html.includes('--player-color:#e53935'), 'each card needs its player-specific identity color');
  assert.ok(html.includes('class="score positive"'), 'positive scores need a distinct class');
  assert.ok(html.includes('class="score negative"'), 'negative scores need a distinct class');
});

test('landlord choices reuse player colors without showing score values', () => {
  const firstLoad = loadPreview();
  let state = firstLoad.window.previewApp.defaultState();
  state = firstLoad.window.previewApp.createSession(state, state.players.slice(0, 3).map(p => p.id));
  const { document } = loadPreview({ seed: { doudizhu_state: JSON.stringify(state) } });
  const choices = document.querySelectorAll('#landlord-options .btn-option');
  assert.equal(choices.length, 3);
  choices.forEach((choice, index) => {
    assert.ok((choice.getAttribute('style') || '').includes(`--player-color:${state.players[index].color}`));
    assert.ok(choice.querySelector('.player-dot'), 'landlord choice needs a player-color dot');
    assert.ok(choice.querySelector('.player-label'), 'landlord choice needs a dedicated name label');
    assert.equal(choice.querySelector('.score'), null, 'landlord choice must not show score values');
  });
});

test('scoring panel removes spring/blind controls and clears legacy hidden draft flags', () => {
  const firstLoad = loadPreview();
  let state = firstLoad.window.previewApp.defaultState();
  state = firstLoad.window.previewApp.createSession(state, state.players.slice(0, 3).map(p => p.id));
  state.draftRound.spring = true;
  state.draftRound.blind = true;
  const loaded = loadPreview({ seed: { doudizhu_state: JSON.stringify(state) } });
  assert.equal(loaded.scriptError, undefined, 'legacy draft normalization must not break page startup');
  assert.equal(loaded.document.getElementById('spring-toggle'), null);
  assert.equal(loaded.document.getElementById('blind-toggle'), null);
  const persisted = JSON.parse(loaded.localStorage.getItem('doudizhu_state'));
  assert.equal(persisted.draftRound.spring, false);
  assert.equal(persisted.draftRound.blind, false);
});

test('script executes without throwing on load', () => {
  const { scriptError } = loadPreview();
  assert.equal(scriptError, undefined, 'preview.html inline script must not throw on load');
});

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
  assert.match(html, /\.update-notice\[hidden\]\s*\{\s*display:\s*none;\s*\}/);
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
  assert.deepEqual(JSON.parse(JSON.stringify(fakes.registerCalls)), [['./sw.js', { scope: './' }]]);
  assert.equal(fakes.updateCalls, 1);
  await fakes.fireWindow('online');
  assert.equal(fakes.updateCalls, 2);
});

test('waiting worker is shown and update button sends SKIP_WAITING', async () => {
  const fakes = createPwaFakes({ waiting: true });
  await loadPreview().window.previewApp.setupPwaUpdates(fakes.deps);
  assert.equal(fakes.banner.hidden, false);
  await fakes.clickUpdate();
  assert.deepEqual(JSON.parse(JSON.stringify(fakes.messages)), [{ type: 'SKIP_WAITING' }]);
});

test('controllerchange reloads only after an explicit waiting-worker update request', async () => {
  const firstInstall = createPwaFakes();
  await loadPreview().window.previewApp.setupPwaUpdates(firstInstall.deps);
  await firstInstall.fireServiceWorker('controllerchange');
  assert.equal(firstInstall.reloadCalls, 0);

  const fakes = createPwaFakes({ waiting: true });
  await loadPreview().window.previewApp.setupPwaUpdates(fakes.deps);
  await fakes.clickUpdate();
  assert.deepEqual(JSON.parse(JSON.stringify(fakes.messages)), [{ type: 'SKIP_WAITING' }]);
  await fakes.fireServiceWorker('controllerchange');
  await fakes.fireServiceWorker('controllerchange');
  assert.equal(fakes.reloadCalls, 1);

  const failed = createPwaFakes({ registrationError: new Error('offline') });
  assert.equal(await loadPreview().window.previewApp.setupPwaUpdates(failed.deps), null);
});
