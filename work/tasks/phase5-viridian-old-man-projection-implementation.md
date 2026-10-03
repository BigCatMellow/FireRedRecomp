# Task: implement bounded Viridian Old Man state projection

- Task ID: `P5-04-OLD-MAN-PROJECTION`
- Status: `READY_FOR_PREPARATION`
- Type: `IMPLEMENTATION — GUARDED ROUTE REQUIRED`
- Prerequisite: [P5-03 design PASS](../reviews/2026-10-02-viridian-old-man-projection-design-review.md), exact `87644b2`.

## Authority

Implement only the accepted map-specific pre-ObjectEventState projection of
Viridian Old Man local ID 4 from session scene `0x4051`, with exact scene 0/1/
>=2 outputs and fail-closed unknown/dynamic-ID behavior. A dedicated route
configuration, review and probe must PASS before any Worker request.

## MAY CHANGE after route PASS

Only the exact helper/integration/test/report/task paths named by the later
route plan. No path is implied now.

## MUST NOT CHANGE

Generic script callbacks/VM, other maps/templates, tutorial movement/battle,
parcel progression, map rendering policy, save semantics, UI, ROM policy or
canonical phase status.

## Acceptance

Focused no-ROM tests must cover all three scene outputs, local-ID isolation,
dynamic-ID 240 refusal, unknown scene refusal and unchanged ordinary objects;
guarded evidence and independent exact review are required. Do not claim
playable Viridian or full traversal.

## Stop

Stop for any need to generalize callback/state semantics, change unrelated map
objects, or widen beyond the reviewed route. Record the blocker; do not patch.
