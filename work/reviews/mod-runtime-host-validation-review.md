# Review: declared-host ModRuntime validation

- Scope: `src/core/ModRuntime.lua`, `tests/mod_runtime_test.lua`,
  `docs/modding.md`, and modding handoff/checklist text
- Reviewer: `/root/oak_dex_review` (independent helper)
- Verdict: `APPROVED`

## Acceptance check

- `PASS` — entrypoint environments now copy `math` and explicitly remove
  `math.random` and `math.randomseed`, so callback execution cannot consume
  or reseed Lua 5.1's process-global PRNG. No sandbox escape to the original
  `math` table is exposed by the permitted API.
- `PASS` — `tests/mod_runtime_test.lua` preserves an expected seeded host-RNG
  value across a successful declared-host validation and across a failed
  validation whose callback attempts `math.randomseed(1)`. The latter fails
  cleanly because the function is unavailable. The direct code boundary also
  removes `math.random`.
- `PASS` — fresh registry/hook construction, forced resolution of every
  declared namespace, and unload/rollback behavior remain intact. Existing
  fixtures still reject unknown namespaces and invalid lazy patches.
- `PASS` — `docs/modding.md` now describes the absent ambient RNG surface;
  the modding handoff accurately records 138 passing files in no-ROM and
  verified-ROM modes, and the Phase 10 checklist remains accurate.

## Evidence checked

- `lua5.1 tests/mod_runtime_test.lua` — 18 passed, 0 failed.
- `lua5.1 tests/mod_entrypoint_test.lua` — 7 passed, 0 failed.
- `git diff --check` for the reviewed files — clean.
- Manual trace of the sandbox environment and declared-host validation/load/
  resolve/unload path.

## Findings

No remaining blockers in the declared-host validation scope. This approval is
limited to the specified runtime/test/documentation boundary and excludes
unrelated concurrent worktree changes.
