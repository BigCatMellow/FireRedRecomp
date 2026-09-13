# Review: north-facing Oak Parcel/Dex presentation

- Task: [`work/tasks/oak-parcel-dex-presentation-north.md`](../tasks/oak-parcel-dex-presentation-north.md)
- Reviewer: `/root/oak_dex_review` (independent helper)
- Verdict: `APPROVED`

## Acceptance criteria check

- `PASS` — the presenter retains its exact bounded north-facing guard,
  source-locked text/motion sequence, input lock, and terminal-only durable
  commit callback. Focused contract test: 26 passed, 0 failed.
- `PASS` — the failed `rival_exit` commit path now emits the same live-only
  local-id-8 removal descriptor as the success path. The runtime unlock
  handler filters that temporary rival from `world.npcs` and does not use a
  persistent-hide-flag operation. The regression asserts the failed command's
  `remove.localId` and `preserveHideFlag` fields.
- `PASS` — the sole runtime `abort` call is the missing-template branch before
  a rival can be created. It unlocks, clears motion/printer state, performs no
  durable write, and remains repeat-safe; the focused test covers this path.
- `PASS` — `docs/handoffs/oak-parcel-dex-presentation-north.md` now agrees
  with the task: integrated/verified state, 26/0 focused result, and review
  as the remaining owner gate.

## Evidence checked

- `lua5.1 tests/oak_parcel_dex_presentation_test.lua` — 26 passed, 0 failed.
- `luac5.1 -p main.lua` — passed.
- `git diff --check` for all reviewed source/test/task/handoff/review files —
  clean.
- Manual trace of the post-rival `commit_failed` command through the runtime
  unlock handler, and all `abort` call sites.

## Findings

No remaining blockers in the reviewed bounded Oak/Dex slice. This approval is
limited to the specified presenter/wiring/test/documentation boundary; it does
not review unrelated concurrent worktree changes.

## High-risk completion / release summary

N/A — medium-risk task; commit/publication remains owner-authorized.
