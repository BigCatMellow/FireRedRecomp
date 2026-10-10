# Task: implement bounded ordinary Recover / Slack Off

- Task ID: `P4-F3-RESTORE-HP-IMPLEMENTATION`
- Status: `CLOSED — REVIEWED PASS`
- Type: `IMPLEMENTATION — GUARDED ROUTE REQUIRED`
- Prerequisites: [source lock](../reviews/2026-09-29-restore-hp-source-discovery-review.md) and [design PASS](../reviews/2026-10-01-restore-hp-design-review.md).
- Risk: `HIGH` — battle behavior, event ordering and private-ROM evidence.

## Authority and boundary

Implement only the reviewed ordinary non-intercepted effect-32 contract for
Recover (105) and Slack Off (303). A separate route configuration/review/probe
must PASS before any private-runner request. Do not begin a Worker patch before
that prerequisite exists.

## MAY CHANGE after route PASS

`src/core/BattleEngine.lua`, `src/core/BattleSceneController.lua`, the narrowly
necessary caller seams in `main.lua`, and focused engine/controller/inventory
tests plus this task/report. The Worker must state an exact allowlist before a
request; no other path is implied.

## MUST NOT CHANGE

Importer record shape, generic healing APIs, save/schema, AI policy, UI scenes,
other move families, Softboiled/Milk Drink, Rest/Wish/weather recovery, Snatch,
cancellation/MoveEnd/item/ability/status systems, doubles/links, or ROM policy.

## Acceptance

Use the exact F2 event/admission contract: ID-aware admission only for 105/303
effect 32, zero power, USER target; PP before success/full-HP viability;
half-own-max floor/minimum-one and own-max clamp; `restoreHP` versus
`restoreHPFull` ordered controller playback; inventory delta 248/106 → 250/104
only. Prove negative IDs/shapes, both sides, PP/RNG/event/HP boundaries,
controller snapshots and old-code regression. Require focused, no-ROM and
non-skipped SHA-ROM evidence plus independent exact implementation review.

## Stop

Stop for any needed generic abstraction, excluded interaction, route absence,
source ambiguity or ROM failure. Record the blocker; do not broaden scope.

## Route readiness

The dedicated route configuration and probe independently passed. Worker may
publish exactly one `phase4-restore-hp-effect` request using the reviewed
nine-path allowlist. The guarded run and independent exact implementation review
remain required; no completion claim follows request publication.

## Worker handoff — 2026-10-02

The bounded implementation/request is ready for the guarded private-runner
route. It changes only the route's nine literal paths: ID-aware effect-32
admission for Recover 105 and Slack Off 303; the ordinary own-HP event and
controller snapshot/text; source-locked ROM fixture; inventory expectation;
and deterministic represented-state replay. No caller outside the controller,
generic healing API, save/importer/AI/UI/coordination path, or excluded
interaction changed.

Local evidence before guarded execution: `battle_engine_test.lua` 242/0,
`battle_scene_controller_test.lua` 41/0, source partition check for the move
inventory PASS (ROM-dependent admission branch skipped without a local ROM),
and `scripts/test_all.sh` 152 no-ROM test files PASS. The new ROM fixture also
skips cleanly without `POKEPORT_ROM`; it is required to execute non-skipped on
the guarded SHA-verified runner. The worker does not self-review or claim task,
family, or Phase 4 completion.

## Guarded outcome — 2026-10-09

The separately authorized recovery artifact `dad1274` published implementation
revision `dc8ad06` after GitHub run `38008842308` / job `114083864362` passed
bounded patch validation/application, focused/no-ROM/SHA-ROM/replay checks and
publication. Independent [exact outcome review](../reviews/2026-10-09-restore-hp-implementation-outcome-review.md)
is **PASS**. This closes only the accepted ordinary Restore HP leaf; it does
not complete Phase 4 or broaden any excluded interaction.
