# Review: `field.mapLoaded` seam

- Scope: `main.lua` map-load token/dispatch/sync wiring,
  `tests/mod_runtime_test.lua`, and modding documentation
- Reviewer: `/root/oak_dex_review` (independent helper)
- Verdict: `APPROVED`

## Acceptance check

- `PASS` — `loadGameFile()` now calls `syncSessionLocation()` immediately
  after setting the restored tile and movement state. It consumes the token
  produced by `loadMap()` before the walk view is enabled, so `field.mapLoaded`
  observes the saved final coordinates rather than a later player step.
- `PASS` — new-game bootstrap, ordinary warps, map connections, scripted Oak
  escort, and trainer/wild whiteout or teleport respawns all establish final
  coordinates then synchronize through the same dispatch path. Ordinary steps
  have no pending token and therefore do not re-notify map entry.
- `PASS` — the token is consumed before hook invocation; deterministic around
  hook ordering/short-circuit remains the existing `ModHooks` behavior. The
  bounded context exposes only status messaging and validated u16 flag/var
  writes, not direct map/object/render/filesystem authority.
- `PASS` — documentation accurately states final-destination, exact-once
  semantics and the restricted context.

## Evidence checked

- `lua5.1 tests/mod_runtime_test.lua` — 19 passed, 0 failed.
- `luac5.1 -p main.lua` — passed.
- `git diff --check` for reviewed files — clean.
- Manual trace of every active-session `loadMap()` call site and its final
  coordinate synchronization path, including restored-save flow.

## Findings

No remaining blockers in the field-map-loaded seam. This approval is limited
to the specified integration/test/documentation boundary and excludes
unrelated concurrent worktree changes.
