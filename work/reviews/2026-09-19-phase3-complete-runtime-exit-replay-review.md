# Independent review: complete Phase 3 runtime exit replay

- Date: 2026-09-19
- Role: REVIEWER
- Task: `work/tasks/phase3-complete-runtime-exit-replay.md`
- Implementation/evidence revision reviewed: `a675cdf8f632d4bf7a4b23aa0b0f55dc17644baa`
- Coordination revision recovered: `3727dc37150280f13c75cf835ca26ee57380a404`
- Verdict: `NEEDS_FIX`

## Evidence independently reproduced

- Fetched `origin/master`; it resolves to the stated coordination revision.
- Verified the available private FireRed US v1.0 image has SHA-1
  `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`.
- `lua5.1 tests/phase3_complete_runtime_exit_replay_test.lua`: PASS.
- `env -u POKEPORT_ROM bash scripts/test_all.sh`: PASS, 144 test files.
- `POKEPORT_ROM=<verified private ROM> bash scripts/runtime_phase3_complete_exit_replay.sh`:
  PASS. The two real LÖVE processes emitted the normal-title/Oak route,
  real wild defeat, normal K-save, and normal L-load markers.
- `POKEPORT_ROM=<verified private ROM> bash scripts/test_all.sh`: PASS, 144
  test files.

The exact diff is bounded to replay plumbing, the wrapper, a focused contract
test, and task/coordination records. It contains no ROM content, save-layout
change, or gameplay behavior change. The replay reaches title, Oak, identity
flow, bedroom, Pallet, Route 1, the normal rival and wild-loss paths, and the
normal save/load callbacks; no post-Oak, post-battle, or post-save fixture is
constructed.

## Required correction

Acceptance criterion 3 requires the artifact to **verify** identity continuity
and post-reload persistence. The implementation only prints identity from each
process. Its save-leg `passed` predicate does not require that
`world.runtimeReplayIdentity` is `RED/GREEN` (and expected gender), and the
`restart_load` predicate checks only bedroom location and party count, not the
loaded player/rival identity. The shell wrapper then emits a fixed
`identity=RED/GREEN` final marker after checking only generic `PASS` substrings.

Thus the observed run happened to print `RED/GREEN`, but the claimed identity
continuity is not an assertion: a regression that produces different identity
values could still yield both generic markers and the same hard-coded final
claim. This leaves the task's required deterministic continuity evidence
incomplete.

## Exact next allowance

Worker may make the smallest replay-evidence-only correction: require and emit
the expected identity values at the complete save leg and at the fresh reload
leg, and have the wrapper validate those asserted fields rather than synthesize
them. Add focused coverage for that contract and rerun the focused replay plus
both required suites. Do not change gameplay, save format/layout, ROM policy,
or any unrelated phase surface. A fresh independent review of the new exact
revision is required; this verdict does not authorize parent-gate or canonical
Phase 3 status advancement.
