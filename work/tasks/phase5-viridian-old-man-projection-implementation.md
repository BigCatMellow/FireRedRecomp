# Task: implement bounded Viridian Old Man state projection

- Task ID: `P5-04-OLD-MAN-PROJECTION`
- Status: `CLOSED — REVIEWED PASS`
- Type: `IMPLEMENTATION — GUARDED ROUTE REQUIRED`
- Prerequisite: [P5-03 design PASS](../reviews/2026-10-02-viridian-old-man-projection-design-review.md), exact `87644b2`.

## Authority

Implement only the accepted map-specific pre-ObjectEventState projection of
Viridian Old Man local ID 4 from session scene `0x4051`, with exact scene 0/1/
>=2 outputs and fail-closed unknown/dynamic-ID behavior. A dedicated route
configuration, review and probe must PASS before any Worker request.

## MAY CHANGE after route PASS

The accepted [recovery authority](phase5-viridian-old-man-projection-recovery.md)
and reviewed route admit exactly:

1. `src/core/ViridianOldManProjection.lua`
2. `main.lua`
3. `tests/phase5_viridian_old_man_projection_test.lua`
4. `work/tasks/phase5-viridian-old-man-projection-implementation.md`
5. `work/reports/phase5-viridian-old-man-projection-implementation.md`

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

## Worker preparation evidence — 2026-10-09

- Prepared only in isolated worktree `/tmp/firered-p5-worker`, based on
  `8ec48cfe7e131ab62d54021ed5d382514314b2a2`; main checkout untouched.
- [Implementation report](../reports/phase5-viridian-old-man-projection-implementation.md)
  records the exact projection, refusal, immutable-input and pre-spawn limits.
- Baseline no-ROM suite: 152 test files PASS. Focused test: 115 passed,
  zero failed. Post-change no-ROM suite: 153 test files PASS, including the
  focused test. Lua 5.1 syntax and whitespace checks passed; repository checks
  passed 279 Lua files, 219 Markdown files and 675 local targets.
- Focused tests execute the actual production loader body with synthetic
  templates and stubbed external field/ROM services; this is not a LÖVE,
  private-ROM, rendered, tutorial or traversal replay.
- No bridge artifact, runner dispatch, push, workflow/coordination edit or
  independent acceptance was performed. Guarded focused/no-ROM/SHA-ROM
evidence and independent exact-result review remain required. The route's
explicit no-replay branch must not be reported as gameplay evidence.

## Guarded outcome — 2026-10-10

The reviewed five-path patch `5a7fbc3` published implementation `d280751`
through GitHub run `38037052963` / job `114169565555`. The guarded route passed
focused, no-ROM, and SHA-ROM suites and its explicit no-replay branch.
Independent [outcome review](../reviews/2026-10-10-viridian-old-man-projection-outcome-review.md)
is **PASS**. This closes only the bounded pre-spawn projection; no traversal,
renderer, tutorial, or generic callback claim follows.
