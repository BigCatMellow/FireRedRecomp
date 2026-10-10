# Task: implement bounded Magnitude singles behavior

- Task ID: `P4-F3-MAGNITUDE-IMPLEMENTATION`
- Status: `READY_FOR_REVIEWER`
- Type: `IMPLEMENTATION AUTHORITY / GUARDED ROUTE`
- Parent capability gate: Phase 4 effect 126 / Magnitude move 222
- Assigned role: `ORCHESTRATOR`; independent authorization reviewer: `REVIEWER`
- Prerequisites: accepted [source lock](../reviews/2026-10-10-magnitude-source-discovery-review.md), accepted [design](../reviews/2026-10-10-magnitude-design-review.md), accepted [route configuration](../reviews/2026-10-10-magnitude-route-configuration-review.md), and accepted [route-probe outcome](../reviews/2026-10-10-magnitude-route-probe-outcome-review.md).
- Risk: `HIGH` — event/RNG ordering and a mutable catalog record would change battle behavior beyond the bounded leaf.

## Goal

Authorize review of one future, route-allowlisted request to implement only the
accepted one-attacker/one-defender Magnitude effect-126 projection. This
document itself authorizes no implementation, request, runner, ROM, replay,
or test execution.

## Exact future request boundary

Only after an independent authorization review returns `PASS`, a Worker may
create exactly one bridge input named
`work/local-runner/requests/phase4-magnitude-effect-YYYYMMDD.patch`. It must
be the sole request for this task and may change exactly these nine literal
paths, and no others:

1. `src/core/BattleEngine.lua`
2. `src/core/BattleSceneController.lua`
3. `tests/battle_engine_test.lua`
4. `tests/battle_scene_controller_test.lua`
5. `tests/phase4_move_effect_inventory_test.lua`
6. `tests/phase4_magnitude_effect_rom_test.lua`
7. `scripts/runtime_phase4_magnitude_replay.sh`
8. `work/tasks/phase4-magnitude-implementation.md`
9. `work/reports/phase4-magnitude-implementation.md`

The request must select only the existing reviewed `phase4-magnitude-effect`
bridge route. The bridge's validation and publication lists are already
set-equal to these nine paths. No replacement artifact, retry, route widening,
or second request is authorized. A fresh online/idle `firered-local` runner
observation is required immediately before that one future dispatch; a changed
runner state is a stop condition, not a reason to create another input.

## Required bounded behavior

Implement only Magnitude move ID 222 / effect 126 after the existing selected
slot, support, zero-PP, and `useMove` handling. Do not change admission: the
existing positive-power fallback continues to admit the unchanged nominal-power
1 record. Within the represented singles path, in this exact order:

1. Deduct exactly one PP from the selected permanent slot.
2. Draw exactly once with `rng:next16() % 100` and map it to a local transient
   power and level: `0-4 -> 4/10`, `5-14 -> 5/30`, `15-34 -> 6/50`,
   `35-64 -> 7/70`, `65-84 -> 8/90`, `85-94 -> 9/110`, and
   `95-99 -> 10/150` (level/power).
3. Append exactly `{ type = "magnitude", side = S, level = L }` after
   `useMove` and before any `miss`, `critical`, `noEffect`, or `damage` event.
4. Retain the existing one-defender accuracy and hit path. For a hit, use a
   shallow local move copy carrying only this transient power through the
   existing critical, damage, type, normal-random, no-effect, and post-hit
   paths; never mutate shared move/catalog data.
5. Have `BattleSceneController:_eventMessages` produce one bounded level
   announcement at that event position. Presentation must not infer power or a
   target, consume RNG, or mutate engine/model state.

## Acceptance evidence

The one guarded request must prove all of the following before an independent
outcome reviewer can accept it:

1. Engine tests cover every literal residue boundary/table result, exactly one
   Magnitude draw, one PP deduction, and unchanged shared nominal power 1.
2. Both acting sides retain the singleton contract. Ordinary hit/miss paths
   consume four/two explicit gameplay draws in order (Magnitude, accuracy,
   critical, damage; or Magnitude, accuracy). The existing first-player
   `firstBattle` accuracy bypass is separately proved as a three-draw hit and
   has no ordinary accuracy-miss branch. Non-126 paths retain their prior
   ordering and draws.
3. Tests prove ordered `useMove`, `magnitude`, then retained result events,
   including no-effect behavior after the normal post-accuracy draws, and the
   controller's one ordered announcement without model mutation.
4. The inventory test and the SHA-verified-ROM fixture establish the existing
   Magnitude 222/effect-126 record without retaining ROM content. The focused
   commands run in this exact order through the bridge-selected `$LUA`:

   ```bash
   "$LUA" tests/battle_engine_test.lua
   "$LUA" tests/battle_scene_controller_test.lua
   "$LUA" tests/phase4_move_effect_inventory_test.lua
   "$LUA" tests/phase4_magnitude_effect_rom_test.lua
   ```

5. The guarded job passes `git apply --check`, `git diff --check`, the full
   no-ROM suite (`env -u POKEPORT_ROM bash scripts/test_all.sh`), and the full
   SHA-verified-ROM suite (`bash scripts/test_all.sh` with only the bridge hash
   gate's private path). The verified-ROM inventory aggregate and Magnitude
   fixture must be non-skipped.
6. `bash scripts/runtime_phase4_magnitude_replay.sh` passes a deterministic
   represented engine/controller trace covering the table, PP/event ordering,
   ordinary hit/miss draw counts, and first-player `firstBattle` branch. It is
   not LÖVE, retail text/animation, full-turn, multi-target, or ROM-capture
   proof.
7. A fresh independent outcome review verifies the exact published revision,
   nine-path boundary, guarded results, and exclusions before reconciliation.

## MUST NOT CHANGE

- No workflow, bridge route/procedure, runner/service/credential/private-ROM
  configuration, probe, coordination, capability-status, or unrelated request
  change.
- No `main.lua`, importer/catalog/data-model path, save, AI, UI scene, generic
  dynamic-power abstraction, admission rule, or other effect family.
- No foes-and-ally traversal, target reselection, doubles, absent-battler
  state, Underground bonus/ignore marker, abilities, items, status or
  cancellation expansion, Substitute/MoveEnd behavior, visual timing,
  animation, localization, links, or full seeded retail-turn-parity claim.
- No ROM, BIOS, private path, ROM-derived asset, cache, or private content in
  the repository or evidence.

## Stop / escalation

Stop and record `BLOCKED` for any need for an unlisted path, admission or data
change, generic abstraction, unmodeled source behavior, route/runner/ROM
change, SHA failure, non-skipped-ROM failure, replay failure, or second
request. Do not substitute a probe, mutate the route, or retry the request.

## Review and handoff

The Reviewer must decide `PASS | NEEDS_FIX | BLOCK` for this exact authority
before a Worker may create the one future request. A PASS authorizes only that
one request after a fresh runner observation; it does not certify behavior or
Phase 4. The subsequent guarded result requires its own independent outcome
review before Orchestrator reconciliation. No runner or ROM action has occurred
while compiling this authority.
