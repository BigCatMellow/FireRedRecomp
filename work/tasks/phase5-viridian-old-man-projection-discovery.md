# Task: source-lock Viridian Old Man state projection

- Task ID: `P5-02-OLD-MAN-DISCOVERY`
- Status: `CLOSED — REVIEWED PASS`
- Type: `RESEARCH / SOURCE-LOCK DISCOVERY`
- Prerequisite: [P5-01 inventory PASS](../reviews/2026-10-02-world-coverage-inventory-review.md), exact `7712d63`.

## Goal

Lock the smallest source behavior required for Viridian City's Old Man scene
transition to project into live map/object state: source variables/flags, map
hook/script labels, object/template/graphics changes and their ordering. Compare
that source behavior to current decoded map scripts and live runtime seams.

## MAY CHANGE

1. `work/reports/phase5-viridian-old-man-projection-discovery.md`.
2. This task's evidence/handoff section.

## MUST NOT CHANGE

Runtime, importer/scripts/maps, tests, task routes, state/UI/battle policy,
ROM/media, map dumps or external state. Do not implement a generic script
callback, old-man tutorial, coordinate movement, battle, parcel progression,
object renderer or full Viridian traversal.

## Acceptance

1. Pin all required reference source records and distinguish map-script
decoding from live callback/projected world state.
2. Establish the minimal object/template/graphics/state delta and source order
for the selected scene transition; mark unknown/unsupported commands exactly.
3. Name current runtime owners and missing seams without claiming they are
implemented. Preserve all tutorial, coordinate, battle, UI and progression
exclusions.
4. Propose at most one later bounded design task, not implementation.
5. Independent exact report review is required before any design route.

## Stop

Stop if the behavior requires a private ROM, a general script VM design, or a
product decision about persistent world-state semantics. Record the boundary;
do not expand the task.

## Review

Exact `4fbd0d6` passed [independent review](../reviews/2026-10-02-viridian-old-man-projection-discovery-review.md).
Only a bounded scene/template projection design may follow; tutorial, movement,
battle, UI and generic script work remain excluded.

## Research handoff — 2026-10-02

The source-lock report identifies the exact scene-variable transition projection
for local ID 4 and its dynamic graphics slot without implementing it. The
report records scene 0/1/2+ order, decoded-template facts, current session,
object-state, graphics and script-hook seams, and the tutorial/coordinate/battle
exclusions. Only this task and its report changed. A separate independent
exact-revision review is required; at most one later design-only projection
contract may be considered after PASS.
