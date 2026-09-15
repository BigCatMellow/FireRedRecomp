# Task: plan Local Worker Bridge route for Phase 4 Eruption/Water Spout

- Status: `REVIEWED PASS — READY FOR CONFIGURATION`
- Type: `INFRASTRUCTURE / EXECUTION SUBSTRATE / PLAN`

## Goal

Define the fail-closed route for only FireRed `EFFECT_ERUPTION` (190): Eruption
#284 and Water Spout #323, bounded to this engine's one opposing battler.

## Exact later-worker surface

Selector `phase4-eruption-effects` must allow only:

1. `src/core/BattleEngine.lua`
2. `tests/battle_engine_test.lua`
3. `tests/phase4_eruption_effect_rom_test.lua`
4. `scripts/runtime_phase4_eruption_replay.sh`
5. `work/tasks/phase4-eruption-effects.md`
6. `work/coordination/STATE.json`
7. `work/coordination/HANDOFF.md`

Focused execution is exactly `lua5.1 tests/battle_engine_test.lua`, then
`lua5.1 tests/phase4_eruption_effect_rom_test.lua`; full no-ROM is
`env -u POKEPORT_ROM bash scripts/test_all.sh`; verified-ROM is
`bash scripts/test_all.sh` with the SHA-verified `POKEPORT_ROM`; replay is
`bash scripts/runtime_phase4_eruption_replay.sh`. Publication stages the same
seven literal paths individually when present. Require a separate one-file
probe `work/local-runner/probes/phase4-eruption-effects-route-YYYYMMDD.probe`.

## Acceptance and exclusions

Effect 190 alone must clone transient dynamic power and calculate
floor(HP*storedPower/maxHP) minimum one before ordinary Hit, preserving data.
Do not add a generic/preseed dynamic-power state: stock's preseed guard is an
excluded interaction because this engine has no such state. Tests cover both ROM records, full/partial/
underflow HP, ordinary RNG/immunity, power-150 no leakage, and singles-only
targeting. Exclude all doubles/multi-target behavior, other formulas, generic
admission, status/items/UI/controller/main. Preserve trusted-main-only dispatch,
one request, SHA gate, literal validation/staging, and independent publication
review.

## MUST NOT CHANGE

No configuration, code, tests, bridge request, or behavior in this plan.

## Review

Independent route-plan review passed at `ad56217c`. Configure the literal route
next, then independently review configuration and run its separate probe before
any Worker request.
