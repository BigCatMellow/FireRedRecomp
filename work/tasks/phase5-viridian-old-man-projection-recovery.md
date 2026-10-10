# Task: implement bounded Viridian Old Man projection

- Task ID: `P5-04-OLD-MAN-PROJECTION-RECOVERY`
- Status: `READY_FOR_REVIEWER`
- Type: `IMPLEMENTATION / GUARDED ROUTE`
- Parent capability gate: P5-04 single map-specific projection; no traversal or phase-completion change
- Assigned role: `WORKER`
- Independent reviewer: `REVIEWER` — fresh context, no shared editing of implementation or this contract
- Prerequisites: P5-03 design PASS `87644b2`; P5 route configuration PASS `7a45118`; P5 recovery-probe outcome PASS `b8dc901` / run `38009195083`.
- Risk: `HIGH` — map-load object state can affect live NPC construction; a generic hook or wrong template projection would widen behavior.

## Goal

Implement and prove only the accepted pre-`ObjectEventState.new` Viridian City
projection for local ID 4, reading the persisted scene variable and producing
the three reviewed source-derived static-template states.

## Source of truth

- [Accepted design](../reports/phase5-viridian-old-man-projection-design.md) and its [independent review](../reviews/2026-10-02-viridian-old-man-projection-design-review.md).
- [P5 route configuration review](../reviews/2026-10-03-viridian-old-man-projection-route-configuration-review.md): the literal five-path route.
- [Readiness recovery outcome](../reviews/2026-10-09-viridian-old-man-route-probe-recovery-outcome-review.md): route/substrate only, not behavior evidence.

## MAY CHANGE

Only these five paths, in one later reviewed `phase5-viridian-old-man-projection`
patch artifact:

1. `src/core/ViridianOldManProjection.lua`
2. `main.lua`
3. `tests/phase5_viridian_old_man_projection_test.lua`
4. `work/tasks/phase5-viridian-old-man-projection-implementation.md`
5. `work/reports/phase5-viridian-old-man-projection-implementation.md`

The helper must be pure/map-specific. `main.lua` may call it only after object
events decode and before `ObjectEventState.new` in `loadMapObjectEvents`.

## MUST NOT CHANGE

- No bridge workflow/route/service/private ROM/configuration/credential change
  and no request or probe under this authority.
- No generic map-script callback, opcode/VM/decoder, dynamic-graphics resolver,
  renderer, save/scene write, UI, tutorial movement/battle, parcel, item/flag,
  interaction, other map/template, or Phase 4 behavior.
- No mutation of source template lists; no private ROM data, paths, bytes, or
  derived assets in repository evidence.
- No additional P5 patch or retry; stop if the five-path route cannot express
  the required result.

## Acceptance criteria

1. Only Viridian group 3/map 1 local ID 4 with base graphics 240 is eligible;
   all unrelated templates remain unchanged.
2. It reads only `session:getVar(0x4051)` and fails closed for missing session,
   wrong map/template/base graphics, non-integer or negative scene.
3. Scene 0 projects graphics 34, `(21,11)`, movement 8; scene 1 projects
   graphics 32, `(21,8)`, movement 1; scene >=2 projects graphics 32 while
   retaining decoded `(21,6)` and movement 1.
4. Focused no-ROM tests cover all three scenes, refusal/local-ID controls and
   unmodified ordinary objects. Guarded patch evidence must pass focused,
   shared no-ROM and SHA-ROM suites; route's explicit no-replay branch remains
   a non-gameplay limitation.
5. Independent exact implementation review is required before reconciliation.

## Stop / escalate when

Any need for persistent template mutation, generic callback/dynamic graphics,
additional path, traversal proof, missing accepted source fact, runner failure,
or non-admitted bridge change appears. Record the blocker; do not patch or
substitute an artifact.

## Completion and handoff

- Worker records exact patch revision, five changed paths, commands/results,
  and explicit no-replay limitation without private data.
- Reviewer decides `PASS | NEEDS_FIX | BLOCK` on the exact guarded result.
- Orchestrator creates a fresh one-patch artifact only after this contract's
  independent PASS and runner observation; no authority follows automatically.
