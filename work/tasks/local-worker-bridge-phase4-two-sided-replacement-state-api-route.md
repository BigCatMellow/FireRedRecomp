# Task: add Local Worker Bridge route for Phase 4 two-sided replacement state

- Status: `ACTIVE`
- Type: `INFRASTRUCTURE / EXECUTION SUBSTRATE`

## Goal

Add one exact fail-closed bridge route for
`phase4-two-sided-replacement-state-api` before implementation. It authorizes
only the reviewed state/API migration designed in
`phase4-two-sided-replacement-state-api-design.md`; it does not authorize
Explosion or any additional move effect.

## Required later-worker surface

The literal patch allowlist, focused test commands, runtime replay, and publish
staging surface must be exactly:

1. `src/core/BattleEngine.lua`
2. `src/core/BattleSceneController.lua`
3. `src/core/TrainerBattleOrchestrator.lua`
4. `main.lua`
5. `tests/battle_engine_test.lua`
6. `tests/battle_scene_controller_test.lua`
7. `tests/phase4_two_sided_replacement_state_test.lua`
8. `tests/phase4_two_sided_replacement_state_rom_test.lua`
9. `scripts/runtime_phase4_two_sided_replacement_replay.sh`
10. `work/tasks/phase4-two-sided-replacement-state-api-design.md`
11. `work/coordination/STATE.json`
12. `work/coordination/HANDOFF.md`

Preserve trusted-main-only dispatch, exact SHA-1 private-ROM gate,
one-request-only selection, no wildcard target or staging behavior, apply/diff
validation, focused → no-ROM → verified-ROM → replay execution order, and
independent review after publication. Add one separate one-file non-gameplay
probe before Worker eligibility.

## MUST NOT CHANGE

No gameplay implementation, tests, move effect, state API, UI behavior, AI,
trainer layouts, or Phase-completion status. Do not add a generic fallback
route or broaden another task's route.
