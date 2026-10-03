# Task: design bounded Viridian scene/template projection

- Task ID: `P5-03-OLD-MAN-DESIGN`
- Status: `CLOSED — REVIEWED PASS`
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

## Review

Exact `87644b2` passed [independent review](../reviews/2026-10-02-viridian-old-man-projection-design-review.md).
Only a separately routed map-specific helper/integration/test implementation
may follow; no generic callback or traversal work is authorized.

## Design handoff — 2026-10-02

The report specifies a single map-load, temporary local-ID-4 projection driven
only by the already-persisted scene var. It records exact three-state values,
owner/timing, refusal policy, source-vs-project lifetime boundary and one
future implementation boundary. No implementation, route, status or broader
world-state authority follows without independent design review.
