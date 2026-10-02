# Task: implement bounded ordinary Recover / Slack Off

- Task ID: `P4-F3-RESTORE-HP-IMPLEMENTATION`
- Status: `READY_FOR_PREPARATION`
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
