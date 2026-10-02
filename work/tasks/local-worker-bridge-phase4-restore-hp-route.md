# Task: plan Local Worker Bridge route for Restore HP

- Task ID: `P4-F3-ROUTE`
- Status: `PLAN COMPLETE — PENDING INDEPENDENT REVIEW`
- Type: `INFRASTRUCTURE / EXECUTION SUBSTRATE / PLAN`
- Authority: [P4-F3 implementation contract](phase4-restore-hp-implementation.md) and [F2 design PASS](../reviews/2026-10-01-restore-hp-design-review.md).

## Goal

Define a fail-closed bridge route for only ordinary Recover (105) and Slack Off
(303), effect 32. This plan changes no workflow, patch, runtime behavior, test,
probe or runner state.

## Exact later Worker surface

Selector `phase4-restore-hp-effect` must recognize only
`phase4-restore-hp-effect*.patch` and `phase4-restore-hp-effect*.probe` and
allow/stage exactly these nine paths:

1. `src/core/BattleEngine.lua`
2. `src/core/BattleSceneController.lua`
3. `tests/battle_engine_test.lua`
4. `tests/battle_scene_controller_test.lua`
5. `tests/phase4_move_effect_inventory_test.lua`
6. `tests/phase4_restore_hp_effect_rom_test.lua`
7. `scripts/runtime_phase4_restore_hp_replay.sh`
8. `work/tasks/phase4-restore-hp-implementation.md`
9. `work/reports/phase4-restore-hp-implementation.md`

`main.lua`, importer/data-model paths, save/AI/UI/coordination files and every
other effect family are excluded. If a future patch needs them, stop for a new
contract rather than widening this route.

Focused execution must run the engine, controller, inventory and Restore-HP ROM
fixture tests with the selected Lua interpreter; the fixture may skip without
an inherited ROM, but the unchanged full SHA-ROM suite must execute it. Retain
the shared no-ROM and verified-ROM suites. Require a deterministic
`runtime_phase4_restore_hp_replay.sh` that exercises only the represented
engine/controller trace; it is not visible LÖVE or retail-animation evidence.

Publication must individually stage the same nine literal paths. Require a
separate one-file probe named
`work/local-runner/probes/phase4-restore-hp-effect-route-YYYYMMDD.probe` after
independent configuration review. Its PASS may prove trusted checkout, selector,
Lua toolchain and supported-ROM SHA only; all patch/tests/replay/publication
steps must skip. One later bounded request remains independently reviewed.

## Exclusions

No generic route, fallback selector, wildcard allowlist, ROM content, code,
test, probe or behavior change. Snatch/cancellation/MoveEnd, status/item/
ability interactions, Milk Drink/effect 157, other healing and Phase 4 closure
are outside this plan.

## Handoff

Independent review must accept this exact plan before the Orchestrator configures
the workflow. Configuration then requires its own review and one substrate-only
probe before any Worker request.
