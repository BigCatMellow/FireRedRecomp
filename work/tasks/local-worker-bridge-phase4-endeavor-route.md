# Task: plan Local Worker Bridge route for Phase 4 Endeavor

- Status: `PLAN COMPLETE — PENDING INDEPENDENT REVIEW`
- Type: `INFRASTRUCTURE / EXECUTION SUBSTRATE / PLAN`

## Goal

Define the fail-closed route for only FireRed `EFFECT_ENDEAVOR` (189),
Endeavor #283, in the existing one-opponent engine.

## Exact later-worker surface

Selector `phase4-endeavor-effects` must allow only:

1. `src/core/BattleEngine.lua`
2. `tests/battle_engine_test.lua`
3. `tests/phase4_endeavor_effect_rom_test.lua`
4. `scripts/runtime_phase4_endeavor_replay.sh`
5. `work/tasks/phase4-endeavor-effects.md`
6. `work/coordination/STATE.json`
7. `work/coordination/HANDOFF.md`

Focused execution is exactly `lua5.1 tests/battle_engine_test.lua`, then
`lua5.1 tests/phase4_endeavor_effect_rom_test.lua`; full no-ROM is
`env -u POKEPORT_ROM bash scripts/test_all.sh`; verified-ROM is
`bash scripts/test_all.sh` with the SHA-verified `POKEPORT_ROM`; replay is
`bash scripts/runtime_phase4_endeavor_replay.sh`. Publication stages the same
seven literal paths individually when present. Require a separate one-file
probe `work/local-runner/probes/phase4-endeavor-effects-route-YYYYMMDD.probe`.

## Acceptance and exclusions

Effect 189 alone must preserve cancellation, announcement, and PP reduction;
then it must fail when target current HP is less than or equal to attacker
current HP without consuming accuracy RNG. When viable, it must consume the
ordinary accuracy path, run type calculation/no-effect after that roll, clear
only nonzero effectiveness presentation, and apply exactly target-current-HP
minus attacker-current-HP through shared HP/faint handling. Do not run ordinary
critical, base-damage, or normal random-damage operations. Protect, Substitute,
Focus Band, Endure, all item/ability/status state (and Focus Band RNG),
doubles/links, generic current-HP formula support, other effects, UI,
controller/main, and Phase 4 completion are excluded. Tests must prove the
single ROM record, viability boundary and zero-draw failure, viable hit/miss
and PP/RNG order, immunity after accuracy with no HP loss, presentation
clearing, shared faint, excluded formula draws, and ordinary-move regression.

Preserve trusted-main-only dispatch, one request, SHA gate, literal validation
and staging, and independent publication review.

## MUST NOT CHANGE

No configuration, code, tests, bridge request, or behavior in this plan.

## Review

Independent route-plan review passed. Configure only the literal route next,
then independently review its configuration and run the separate one-file probe
before any Worker request.

## Configured route

The literal selector, allowlist, focused execution, replay, and individual
publication staging configuration independently passed review. Run the separate
one-file probe next; no Worker request or behavior is authorized until it
passes.
