# Wonder Guard independent correction review — 2026-11-01

**PASS** for the bounded local corrected implementation at exact
`aec82136113bd3a73fde1fbc004cbeeb706e5791`.

This is an R1–R3 delta review plus scope/regressions. The original exact
`47d88a62ff7bfeeb7ca40573daf4365eabbee834` remains NEEDS_FIX under its frozen
review; this result applies to the corrected descendant only. No further
correction identified or implemented by this Reviewer.

## Identity and scope

- Independent detached worktree:
  `/tmp/firered-wonder-guard-correction-review-20261101`.
- Correction authority: `08df0f1`; read the active task's exact R1–R3
  dispatch and completed Worker receipt. Original source/design review and
  independent failing probes retained; no broad source campaign repeated.
- Governing design SHA256 independently matches
  `f9718f67ad8a96d8095c683e00c7b286f2f1d741752d664f8949f2550835d1c9`.
  Source authority remains pret `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
- `08df0f1..aec8213` changes exactly BattleEngine, focused Wonder Guard test,
  and task receipt:156 insertions/9 deletions. The extra review artifact
  visible when comparing against old47 is parent metadata in08df0f1, not a
  Worker correction-delta scope expansion.
- Formula helpers, controller, ROM fixture, AI/history, admission, unrelated
  code/tests, and canonical state are unchanged by the correction delta.
  Exact review worktree is clean; original Worker tree was not edited.

## Corrections verified

1. **R1:** newly blocked Earthquake/Magnitude skip the secondary tail that
   their source hit-all script does not contain. Landed neutral Earthquake
   now draws accuracy+crit+random =3; Magnitude adds strength =4. Both-side
   literal oracles pass; Absorb3 and ordinary blocked4 remain controls.
2. **R2:** hit-all missed-label normal typecalc suppresses global super/resist
   flags under the known prior MISSED context, retaining actual immunity.
   Super Ground versus Fire/Wonder Guard now selects the source ability
   reason after protect/random/semi misses on both sides, without added
   draws or altered PP/HP. Ordinary random-miss OR and ordered typecalc2
   controls remain distinct. Existing global typeCalc semantics are unchanged.
3. **R3:** Brick Break records actual screen removal in an action-local
   boolean, performs the modeled source clear of MISSED/DOESNT_AFFECT after
   its first calculation/random, then applies the ordered static typecalc2
   result. Fighting versus Ghost/Dark yields noEffect after screen removal;
   no-screen retains the earlier Wonder Guard reason. Both defender type
   orders and both attacker sides pass with Reflect/Light Screen/both/none;
   target HP stays unchanged, PP remains1, and source total stays4 draws.
   Ghost-mono/neutral second-pass reassertion and super-effective unblocked
   three-draw controls pass. No persistent state or generic framework added.

These corrections implement the concrete pinned-source findings from the
original independent review. New expected values follow that existing
source evidence rather than implementation readback.

## Independently reproduced checks

All execution used `POKEPORT_ROM` and `POKEPORT_RUNTIME_REPLAY` unset:

- Unchanged `/tmp/firered-wonder-guard-review-probes-20261031.lua`:
  **30 passed/0 failed**, including the12 previously failing checks.
- `lua5.1 tests/battle_wonder_guard_test.lua`: **768/0**.
- `lua5.1 tests/battle_scene_controller_test.lua`: **144/0**.
- `bash scripts/test_all.sh`: **PASS211 files**, honest ROM skips. Log:
  `/tmp/firered-wonder-guard-correction-review-full-20261101.log`.
  Includes unchanged V3/V4a/H1/V4b, engine/controller, Rampage, multihit,
  leftovers and L2 regressions; no redundant earlier baseline repeated.
- `lua5.1 scripts/check_repository.lua`: **PASS340 tracked Lua,
  419 tracked Markdown,1351 local targets**.
- `git diff 08df0f1 aec8213 --check`: PASS; clean exact-head status.
- Explicit opt-in Wonder Guard fixture invocation: honest **SKIP**, reporting
  pending non-skipped supported-ROM evidence. No real ROM accessed/searched.

## Exact next allowance and limits

Parent may adopt this local corrected implementation review and reconcile
the bounded task. This review does not authorize publication, guarded
execution, runner/remote/canonical mutations, or merging. No such action
was performed here. All external supported-ROM/F4, applicable base/V3/full
relay, shared-main/public-CI/merge/publication gates remain pending under
their own authority. The preserved unblocked generic RNG gaps and excluded
ability-history/AI/counter behavior remain unclaimed. No full-runtime/replay,
Brock AI, whole-ability, or phase acceptance follows from this no-ROM PASS.
