# Mobile final fix report

## Scope and files

- `doudizhu_app/preview.html`
  - Reserves `48px + safe-area-inset-top` above the first menu action, preserving the existing 44px handle target.
  - Closes the preview menu on `scroll` when `scrollY > 0` through `setPreviewMenuOpen(false)`.
  - Keeps the round feedback region in the accessibility tree as `role="status"` and visually collapses an empty region without `display: none`.
  - Disables toast transitions under `prefers-reduced-motion`.
- `doudizhu_app/test/preview_interactions.test.mjs`
  - Adds direct `.open` and `inert` assertions for menu opening and closing.
  - Extends the local DOM shim with reflected `inert` and minimal window event dispatch so the test triggers the production scroll listener.
  - Adds regression coverage for scroll-to-close, menu handle clearance, feedback status behavior, and toast reduced motion.

## TDD evidence

### RED

Command:

```powershell
node --test --test-name-pattern "preview page menu starts|scrolling down closes|reserves the handle|feedback remains" doudizhu_app/test/preview_interactions.test.mjs
```

Key output: 1 passed, 3 failed. The failures were the expected missing production behavior:

- Scroll test: expected `aria-expanded` to become `false`, received `true`.
- Clearance test: expected `padding: calc(48px + env(safe-area-inset-top))`, found `22px`.
- Accessibility/motion test: expected `role="status"`, found only `aria-live="polite"` (with `display: none` empty feedback and no toast reduced-motion override).

### GREEN

Command:

```powershell
node --test --test-name-pattern "preview page menu starts|scrolling down closes|reserves the handle|feedback remains" doudizhu_app/test/preview_interactions.test.mjs
```

Key output: 4 tests passed, 0 failed.

## Regression verification

| Command | Result |
| --- | --- |
| `node --test doudizhu_app/test/preview_interactions.test.mjs` | 44 passed, 0 failed |
| `node --test doudizhu_app/test/pwa_assets.test.mjs` | 5 passed, 0 failed |
| `node --test doudizhu_app/test/service_worker.test.mjs` | 7 passed, 0 failed |
| `git diff --check` | Exit 0; no whitespace errors |

## Self-check

- The menu remains closed by default; no existing default-hidden behavior was reverted.
- The scroll handler calls the existing `setPreviewMenuOpen(false)`, so `.open`, `inert`, `aria-expanded`, and `aria-hidden` change together.
- The handle remains `min-height: 44px`; the menu content begins beneath its capture area.
- No browser evidence is claimed here; real menu-hit testing and the three viewport checks remain for the parent agent.

## Concerns

- The headless interaction test validates the production event listener through a deliberately minimal shim. It cannot replace a real-device hit-target or viewport check.
