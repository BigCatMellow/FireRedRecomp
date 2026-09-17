# Task: plan Local Worker Bridge route for Phase 4 Endeavor

- Status: `CLOSED — REVIEWED PASS; AMENDED PROBE PASSED`
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
5. `src/core/BattleSceneController.lua`
6. `tests/battle_scene_controller_test.lua`
7. `work/tasks/phase4-endeavor-effects.md`
8. `work/coordination/STATE.json`
9. `work/coordination/HANDOFF.md`

Focused execution is exactly `lua5.1 tests/battle_engine_test.lua`, then
`lua5.1 tests/battle_scene_controller_test.lua`, then
`lua5.1 tests/phase4_endeavor_effect_rom_test.lua`; full no-ROM is
`env -u POKEPORT_ROM bash scripts/test_all.sh`; verified-ROM is
`bash scripts/test_all.sh` with the SHA-verified `POKEPORT_ROM`; replay is
`bash scripts/runtime_phase4_endeavor_replay.sh`. Publication stages the same
nine literal paths individually when present. Require a separate one-file
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
doubles/links, generic current-HP formula support, other effects, unrelated
UI/controller/main behavior, and Phase 4 completion are excluded. A minimal generic move-failure
event and its existing-scene text presentation are required because
`BattleScript_ButItFailed` is not the screen-only failure event; this must not
reuse `screenFailed` or alter screen behavior. Tests must prove the
single ROM record, viability boundary and zero-draw failure, viable hit/miss
and PP/RNG order, immunity after accuracy with no HP loss, presentation
clearing, positive-HP target landing/no-faint behavior, excluded formula draws,
and ordinary-move regression.

Preserve trusted-main-only dispatch, one request, SHA gate, literal validation
and staging, and independent publication review.

## MUST NOT CHANGE

No gameplay code, bridge request, or behavior in this plan.

## Review

The original route and probe passed, but independent candidate review found its
generic failure message must use a dedicated event rather than the screen-only
`screenFailed` event. This amendment adds only the scene/controller-test paths
needed for that event and its text. Independent amendment review, configuration
review, and its separate one-file probe all passed before this corrected
implementation-contract review.

## Configured route

The original seven-path configuration and probe are superseded for Endeavor by
this nine-path amendment. The literal amended selector, focused commands,
replay, and publication staging independently passed review. The new one-file
probe passed; the corrected implementation contract still requires
independent review before any Worker request.

## Probe

Probe `b3090013` passed the original route, but did not validate the amended
nine-path contract. Fresh probe `14c164e9` passed guarded Local Worker Bridge
run `35206557769`: trusted checkout, explicit route selection, Lua toolchain,
and private-ROM SHA verification passed; patch apply/tests/replay/publication
were skipped as required. The corrected implementation contract requires fresh
independent review before any Worker request.
