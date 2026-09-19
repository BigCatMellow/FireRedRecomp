# Independent review: Phase 3 complete runtime exit replay identity correction

- Date: 2026-09-19
- Role: REVIEWER
- Task: `work/tasks/phase3-complete-runtime-exit-replay.md`
- Implementation subject: `333d048809c2c3a53f51cee016e685afdea911cb`
- Coordination subject: `ad622ab242bd0d0a7f492664bf6faad757b93ec7`
- Publication: `origin/master` resolves to `ad622ab`; it contains `333d048`.
- Verdict: `PASS`

## Independent findings

1. **Identity predicates are live assertions, not a generic-PASS decoration — PASS.**
   `isExpectedReplayIdentity` tests the actual gender and decodes the actual
   player/rival name buffers. The normal-save route can pass only when both the
   identity returned by the normal Oak/new-game flow and the active session
   identity are `RED/GREEN/0`. Its reported identity is read from that active
   session, rather than synthesized for output.
2. **Fresh-process identity is independently asserted — PASS.** The `restart_load`
   process invokes the normal `L` callback, obtains the resulting session, and
   includes `isExpectedReplayIdentity(session.identity)` in its PASS predicate.
   It reports fields decoded from that loaded session.
3. **Wrapper/sandbox boundary — PASS.** The wrapper creates one temporary XDG
   sandbox, runs normal title/Oak/input/save, verifies the normal save file is
   nonempty, then launches a separate process against the same sandbox. It
   requires `identity=RED/GREEN/0` from *each* process before it emits the final
   `identity=asserted` aggregate marker. The aggregate does not claim literal
   identity values itself.
4. **Continuous normal path and scope — PASS.** The implementation diff is
   limited to `main.lua` replay plumbing, its wrapper, focused contract test,
   and task evidence. The replay uses title START, Oak/input flow, live movement
   and battle, normal `K` save, and normal `L` load; it introduces no session
   fixture, gameplay rule, save-layout, ROM-policy, or prohibited-content change.

## Reproduced evidence

- Verified local private ROM SHA-1:
  `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`.
- Archived exact subject `333d048`: `lua5.1
  tests/phase3_complete_runtime_exit_replay_test.lua`, `luac5.1 -p main.lua`,
  and `bash -n scripts/runtime_phase3_complete_exit_replay.sh` all passed.
- Archived exact subject, verified-ROM complete replay passed. The save process
  emitted `identity=RED/GREEN/0`; the separate reload process independently
  emitted `identity=RED/GREEN/0`; then the wrapper emitted the aggregate PASS.
- Archived exact subject: `env -u POKEPORT_ROM bash scripts/test_all.sh` passed
  144 test files; `POKEPORT_ROM=<SHA-verified private ROM> bash
  scripts/test_all.sh` also passed 144 test files.

## Allowance

`PASS` authorizes only the Orchestrator to reconcile the already-published
Phase 3 parent-proof/canonical-status records. It does not authorize gameplay,
save-format, ROM-policy, or Phase 4 changes.
