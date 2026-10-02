# Restore HP route plan — independent review

Verdict: **PASS** for the route plan only. No workflow configuration, probe or
implementation evidence is accepted by this review.

- Exact plan revision: `0b01c969d5b9b618bf54de7b9314ed8599de58aa`.
- Parent: `9415bddaf5e8ce45e02c251eaf1e1ec2a681fe64`.
- Task: [P4-F3-ROUTE](../tasks/local-worker-bridge-phase4-restore-hp-route.md).
- Implementation authority: [P4-F3](../tasks/phase4-restore-hp-implementation.md).
- Accepted design: `4863567dce1950aa15e9b33798f82953b3bda4df` and its
  [independent review](2026-10-01-restore-hp-design-review.md).

## Evidence and findings

Independently recovered public main at the exact plan revision; read the full
plan, F2 design/review, F3 contract, bridge procedure and relevant existing
workflow cases. Compared the Pain Split and inventory route conventions.
The exact commit changes only the route-plan task and its registration row;
`git diff --check` passes. No workflow, runtime, tests, script, probe, request,
ROM or generated content changed. The register explicitly routes this plan to
independent review; older general coordination wording is not implementation
authority.

1. **Selector is explicit.** `phase4-restore-hp-effect` and only its named
   `.patch`/`.probe` filename-prefix cases fit existing bridge selection. The
   planned `phase4-restore-hp-effect-route-YYYYMMDD.probe` selects that same
   route. The current workflow does not yet contain this selector, and the
   plan does not claim otherwise. No fallback or reuse of another route is
   proposed.
2. **Validation and staging are symmetric.** The plan contains exactly nine
   unique literal paths, independently recounted against its stated list:

   - `src/core/BattleEngine.lua`
   - `src/core/BattleSceneController.lua`
   - `tests/battle_engine_test.lua`
   - `tests/battle_scene_controller_test.lua`
   - `tests/phase4_move_effect_inventory_test.lua`
   - `tests/phase4_restore_hp_effect_rom_test.lua`
   - `scripts/runtime_phase4_restore_hp_replay.sh`
   - `work/tasks/phase4-restore-hp-implementation.md`
   - `work/reports/phase4-restore-hp-implementation.md`

   Publication must individually stage this same list. There are no wildcard,
   traversal, importer, main, save, AI, new UI-scene or coordination targets. F3's
   broad optional `main.lua` allowance does not survive this narrower route;
   F2 identifies no required main/persistence edit. Any newly needed caller
   path must stop the request rather than widen the route.
3. **Verification retains separate gates.** Focused execution names engine,
   controller, inventory and the new ROM fixture using the selected Lua
   interpreter. The shared no-ROM suite remains; the shared supported-SHA ROM
   suite must run the fixture and inventory without their no-ROM skip. An
   inherited-ROM absence in focused execution is not substituted for that
   later gate. The plan does not weaken F3's old-code regression, negative
   admission, both-side HP/PP/RNG/event, snapshot or inventory-delta criteria.
4. **Replay has the correct claim boundary.** The named script is required,
   not an inventory-style no-replay branch. Its proposed deterministic
   engine/controller trace matches the bounded effect task and existing
   headless effect-route convention. It is explicitly not a visible LÖVE,
   retail-animation, timing, persistence or whole-game parity receipt.
5. **Probe cannot become implementation evidence.** Configuration must first
   receive a separate exact review. Then one separate one-file probe may
   establish trusted checkout, selector, Lua and private supported-ROM SHA
   readiness only. All patch validation/application, focused/full tests,
   replay and publication steps must skip. A later implementation request
   and its independent review remain separate gates.
6. **Security and behavior exclusions remain intact.** The inherited bridge
   contract requires trusted-main push dispatch, one changed request/probe,
   unknown-selector/target refusal, `git apply --check`, whitespace checks,
   supported SHA verification and tests before literal publication. This plan
   does not authorize changes to those shared controls or other routes.
   Its scope stays with ordinary Recover 105 and Slack Off 303, effect 32;
   Milk Drink/effect 157, other healing, generic APIs, Snatch/shared
   cancellation/MoveEnd and status/item/ability machinery remain excluded.
   The referenced F2/F3 boundaries also continue to exclude doubles/links,
   save/persistence policy, UI redesign and Phase 4 closure.

The path recount and source/diff inspection are static plan checks. No game
suite, private runner, ROM, replay or probe was run. In particular, this review
does not claim the future workflow accepts valid targets, rejects malformed
ones or stages correctly until its actual configuration is separately tested
and reviewed.

## Exact next allowance

The Orchestrator may configure only this literal route, preserving all existing
shared controls and routes, then submit that exact configuration for independent
review. A separate successful substrate-only probe must follow configuration
PASS before any Worker patch/request under F3. No implementation may begin on
the strength of this plan PASS alone, and no effect or phase is complete.

Only this review file was authored; no workflow/task/coordination edit, commit,
push, dispatch or runner action was performed by the Reviewer.
