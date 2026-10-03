# Task: design bounded Viridian scene/template projection

- Task ID: `P5-03-OLD-MAN-DESIGN`
- Status: `READY_FOR_WORKER`
- Type: `DESIGN / NO IMPLEMENTATION`
- Prerequisite: [P5-02 source-lock PASS](../reviews/2026-10-02-viridian-old-man-projection-discovery-review.md), exact `4fbd0d6`.

## Goal

Specify the smallest data/runtime contract that projects the three accepted
Viridian Old Man scene states into map object graphics/template state at map
load/transition, without creating a generic script callback or story system.

## MAY CHANGE

1. `work/reports/phase5-viridian-old-man-projection-design.md`.
2. This task's evidence/handoff section.

## MUST NOT CHANGE

Runtime/maps/scripts/importer/tests/routes/save/UI/battle code or canonical
status. Do not implement the design, add flag/variable callbacks generally,
advance tutorial movement/battle/parcel logic, or claim traversal.

## Acceptance

Define exact input scene state, source-derived output graphics/template deltas,
load/transition timing, ownership and invalid/unknown state policy; compare
current data owners and name any required later paths. Preserve all source-lock
exclusions. Propose one later implementation boundary only; independent design
review is required.

## Stop

Stop for a required persistent-state model, general callback/VM, or unrelated
object/renderer behavior. Record the dependency rather than broadening scope.
