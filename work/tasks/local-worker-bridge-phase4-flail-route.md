# Task: plan Local Worker Bridge route for Phase 4 Flail/Reversal

- Status: `CLOSED — REVIEWED PASS; PROBE PASSED`
- Type: `INFRASTRUCTURE / EXECUTION SUBSTRATE / PLAN`

## Goal

Define the fail-closed Worker route for only FireRed `EFFECT_FLAIL` (99): Flail
#175 and Reversal #179. It must set the stock HP-scaled dynamic base power
before the ordinary Hit path without widening to other dynamic formulas.

## Exact later-worker surface

Selector `phase4-flail-effects` must allow only:

1. `src/core/BattleEngine.lua`
2. `tests/battle_engine_test.lua`
3. `tests/phase4_flail_effect_rom_test.lua`
4. `scripts/runtime_phase4_flail_replay.sh`
5. `work/tasks/phase4-flail-effects.md`
6. `work/coordination/STATE.json`
7. `work/coordination/HANDOFF.md`

Focused execution is exactly `lua5.1 tests/battle_engine_test.lua`, then
`lua5.1 tests/phase4_flail_effect_rom_test.lua`; full no-ROM is
`env -u POKEPORT_ROM bash scripts/test_all.sh`; verified-ROM is
`bash scripts/test_all.sh` with the SHA-verified `POKEPORT_ROM`; replay is
`bash scripts/runtime_phase4_flail_replay.sh`. Publish staging must individually
add the same seven literal paths only when present. Require one separate one-file probe at
`work/local-runner/probes/phase4-flail-effects-route-YYYYMMDD.probe`.

## Acceptance and exclusions

Effect 99 alone must calculate scaled attacker HP exactly
`floor(hp*48/maxHP)` with positive-underflow-to-one and select the six locked
power bands before the ordinary cancellation/accuracy/PP/crit/type/random/HP
path. Tests must cover both parsed moves, every boundary, ordinary RNG/immunity,
and no leakage to stored-power-1 moves. Exclude Super Fang, other dynamic
formulas, generic admission, status/items/UI/controller/main, doubles/links.
Preserve trusted-main-only dispatch, exact one request, SHA gate, literal
allowlist/staging, and independent post-publication review.

## MUST NOT CHANGE

No workflow configuration, code, tests, bridge request, or behavior here.

## Review

Independent route-plan review passed at `db6f7cb5`. Configure the literal route
next, then independently review configuration and run its separate probe before
any Worker request.

## Configured route and probe

Configuration independently passed at `d0e151e2`; probe `883536b0` passed
guarded Local Worker Bridge run `34994516318`, including trusted checkout,
explicit route selection, Lua toolchain, and private-ROM SHA verification.
Patch/test/replay/publication steps were correctly skipped. One reviewed
effect-99 Worker request is now eligible.
