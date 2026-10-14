# Phase 4 Magnitude Local Worker Bridge route configuration

- Task: `P4-F3-MAGNITUDE-ROUTE-CONFIG`.
- Status: worker configuration evidence; independent exact review pending.
- Base: `1174634`.
- Authority: reviewed [Magnitude route plan](phase4-magnitude-route-plan.md)
  and its [independent PASS](../reviews/2026-10-10-magnitude-route-plan-review.md).

## Exact configuration

The Local Worker Bridge adds exactly five `phase4-magnitude-effect` arms:

1. Selector acceptance only for `phase4-magnitude-effect*.patch` and
   `phase4-magnitude-effect*.probe`.
2. Patch-target validation only for these nine literal paths:
   - `src/core/BattleEngine.lua`
   - `src/core/BattleSceneController.lua`
   - `tests/battle_engine_test.lua`
   - `tests/battle_scene_controller_test.lua`
   - `tests/phase4_move_effect_inventory_test.lua`
   - `tests/phase4_magnitude_effect_rom_test.lua`
   - `scripts/runtime_phase4_magnitude_replay.sh`
   - `work/tasks/phase4-magnitude-implementation.md`
   - `work/reports/phase4-magnitude-implementation.md`
3. Focused commands, through the bridge-selected `$LUA`, in this order:

   ```bash
   "$LUA" tests/battle_engine_test.lua
   "$LUA" tests/battle_scene_controller_test.lua
   "$LUA" tests/phase4_move_effect_inventory_test.lua
   "$LUA" tests/phase4_magnitude_effect_rom_test.lua
   ```

4. Mandatory replay command:

   ```bash
   bash scripts/runtime_phase4_magnitude_replay.sh
   ```

5. Publication staging of exactly the same nine literal paths, with the
   existing per-path `git add -- "$path"` form.

The unchanged shared commands remain `env -u POKEPORT_ROM bash
scripts/test_all.sh` and, with step-level `POKEPORT_ROM:
${{ steps.rom.outputs.path }}`, `bash scripts/test_all.sh`.

## Static evidence

Static-only verification was used for this configuration package. It did not
run a bridge request/probe, private runner, ROM, game suite, replay, or
publication.

- `git diff --check` passed.
- PyYAML parsed the workflow successfully, and `bash -n` passed for all 12
  workflow shell blocks.
- Safe-stub execution accepted four reviewed selector examples (two `.patch`
  and two `.probe`) and rejected four near-prefix/wrong-extension examples.
- The actual validation block accepted each of the nine paths individually and
  their combined set (10 positive checks), while rejecting eight unlisted or
  nonliteral paths and an unknown route (9 negative checks).
- Safe stubs recorded the four focused `$LUA` invocations in the required
  order, exactly one required replay invocation, and nine `git add -- "$path"`
  calls for the same validation set; each corresponding unknown-route branch
  failed closed.

Independent review must reproduce the relevant checks against the final
revision.

## Boundary

This configuration is not a readiness receipt and authorizes no Magnitude
behavior. After independent configuration PASS, the only possible successor is
one separately bounded one-file substrate-only probe named
`work/local-runner/probes/phase4-magnitude-effect-route-YYYYMMDD.probe`.
That probe must still skip patch validation/application, focused/full suites,
replay, staging, commit, and publication. No implementation request is
eligible until that probe is independently reviewed.
