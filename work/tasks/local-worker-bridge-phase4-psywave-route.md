# Task: plan Local Worker Bridge route for Phase 4 Psywave

- Status: `CLOSED — REVIEWED PASS`
- Type: `INFRASTRUCTURE / EXECUTION SUBSTRATE / PLAN`

## Goal

Define the fail-closed route for only FireRed `EFFECT_PSYWAVE` (88), Psywave
#149, in the existing one-opponent engine.

## Exact later-worker surface

Selector `phase4-psywave-effects` must allow only:

1. `src/core/BattleEngine.lua`
2. `tests/battle_engine_test.lua`
3. `tests/phase4_psywave_effect_rom_test.lua`
4. `scripts/runtime_phase4_psywave_replay.sh`
5. `work/tasks/phase4-psywave-effects.md`
6. `work/coordination/STATE.json`
7. `work/coordination/HANDOFF.md`

Focused execution is exactly `lua5.1 tests/battle_engine_test.lua`, then
`lua5.1 tests/phase4_psywave_effect_rom_test.lua`; full no-ROM is
`env -u POKEPORT_ROM bash scripts/test_all.sh`; verified-ROM is
`bash scripts/test_all.sh` with the SHA-verified `POKEPORT_ROM`; replay is
`bash scripts/runtime_phase4_psywave_replay.sh`. Publication stages the same
seven literal paths individually when present. Require a separate one-file
probe `work/local-runner/probes/phase4-psywave-effects-route-YYYYMMDD.probe`.

## Acceptance and exclusions

Effect 88 alone must preserve shared cancellation, accuracy, PP and type
calculation, clear only nonzero effectiveness presentation, then rejection
sample `Random() % 16` until 0..10 and deal
floor(attacker level × (50 + 10r) / 100). Sampling must occur even after type
immunity, before no-effect HP suppression. Do not use ordinary critical,
base-damage, or normal random-damage operations. The engine has no held-item
or endure state, so those `adjustsetdamage` branches and their RNG are
excluded—not approximated. Tests must prove #149, accepted low/high values,
rejected retry/draw count, floor semantics, miss/PP, immune sampling order,
no ordinary crit/base/random draws, shared faint handling, and ordinary-move
regression. Exclude generic random-formula admission, all other effects,
held-item/endure/ability/status/UI/controller/main, doubles/links, and Phase 4
completion.

Preserve trusted-main-only dispatch, one request, SHA gate, literal validation
and staging, and independent publication review.

## MUST NOT CHANGE

No configuration, code, tests, bridge request, or behavior in this plan.

## Review

Independent route-plan review passed. Configure the literal route next, then
independently review configuration and run its separate probe before any Worker
request.
