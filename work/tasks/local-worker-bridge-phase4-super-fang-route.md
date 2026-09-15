# Task: plan Local Worker Bridge route for Phase 4 Super Fang

- Status: `READY FOR INDEPENDENT REVIEW`
- Type: `INFRASTRUCTURE / EXECUTION SUBSTRATE / PLAN`

## Goal

Define the fail-closed Worker route needed before implementing only FireRed
`EFFECT_SUPER_FANG` (40). It must preserve the stock current-target-HP formula
and ordinary cancellation/accuracy/PP/type/faint semantics without broadening
to fixed damage, other formulas, or unrelated battle work.

## Exact later-worker surface

Selector: `phase4-super-fang-effects`. Its literal patch allowlist, focused
commands, replay, and publish staging list must be exactly:

1. `src/core/BattleEngine.lua`
2. `tests/battle_engine_test.lua`
3. `tests/phase4_super_fang_effect_rom_test.lua`
4. `scripts/runtime_phase4_super_fang_replay.sh`
5. `work/tasks/phase4-super-fang-effects.md`
6. `work/coordination/STATE.json`
7. `work/coordination/HANDOFF.md`

Focused execution must run `lua5.1 tests/battle_engine_test.lua`, then
`lua5.1 tests/phase4_super_fang_effect_rom_test.lua`, followed by existing full
no-ROM and verified-ROM suites and the replay. A separate one-file non-gameplay
probe is required at `work/local-runner/probes/phase4-super-fang-effects-route-
YYYYMMDD.probe` before a Worker request.

## Route rationale and acceptance

The implementation must be effect 40 alone: ordinary cancellation, accuracy
and PP; type immunity as no-effect; nonzero effectiveness presentation cleared;
damage `floor(target HP / 2)` with a minimum of one; shared HP/faint handling;
no ordinary critical/base/random-damage draws. Tests must prove the parsed
Super Fang #162 record, even/odd/one-HP targets, immunity, miss/PP/RNG order,
and no leakage to existing fixed-damage effects. Exclude effects 7/41/87/130,
other formulas, status/ability/items, UI, controller/main wiring, doubles and
links. Preserve trusted-main-only dispatch, exactly one request selection,
private-ROM SHA gate, literal target validation/staging, and independent
post-publication review.

## MUST NOT CHANGE

No workflow configuration, gameplay code, tests, bridge request, or behavior in
this planning task. Configuration and probe require their own later gates.
