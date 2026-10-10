# Task: design bounded Magnitude singles behavior

- Task ID: `P4-F2-MAGNITUDE-DESIGN`
- Status: `READY_FOR_WORKER`
- Type: `DESIGN / NO IMPLEMENTATION`
- Parent capability gate: Phase 4 effect 126
- Assigned role: `RESEARCHER`
- Independent reviewer: `REVIEWER`
- Prerequisite: [Magnitude source-lock PASS](../reviews/2026-10-10-magnitude-source-discovery-review.md)
- Risk: `MEDIUM` — ordering/event choices can affect deterministic battle evidence.

## Goal

Specify the smallest observable bounded-singles effect-126 contract: one
Magnitude roll/table, non-mutating local power, and a level event before the
single defender's existing hit path.

## MAY CHANGE

- `work/reports/phase4-magnitude-design.md`
- this task's handoff section

## MUST NOT CHANGE

Runtime/tests/admission, workflow/route, ROM, save/UI/AI, generic dynamic
power helpers, target loops/doubles, Underground, abilities/items, cancellation
expansion, visual timing, replay, or capability status.

## Acceptance criteria

1. Give literal roll→level/power mapping and exact event/RNG/PP/hit order.
2. Define minimal event payload/presentation owner and failure boundaries.
3. State concrete later implementation paths/tests only; no code authority.
4. Retain all source-lock unknowns and exclusions.

## Evidence

Pinned source-lock and current engine/controller seams; `git diff --check`;
independent exact design review. No ROM/runtime execution.

## Stop

Stop for a generic abstraction, multi-target/Underground state, or unresolved
event ownership. Record the issue; do not implement.

## Handoff

Reviewer decides `PASS | NEEDS_FIX | BLOCK`; only a reviewed route/implementation
successor may follow PASS.

## Researcher evidence and handoff — 2026-10-10

The proposed [bounded Magnitude design](../reports/phase4-magnitude-design.md)
is ready for independent exact-revision review, not implementation.  It keeps
existing positive-power admission unchanged; specifies the one post-`useMove`
PP deduction, one `% 100` draw, literal seven-row table, local non-mutating
power copy, and the ordered `{type="magnitude", side=, level=}` event before
the existing singleton hit path.

The design preserves the source-lock boundaries: no target traversal/doubles,
Underground, abilities/items, cancellation expansion, generic dynamic-power
API, visual timing, replay, ROM, or capability claim.  It names only later
engine/controller/focused-test proof requirements, all requiring a separately
reviewed implementation task after design PASS.

Read-only inspection covered the accepted source report/review and current
engine selection/PP/accuracy/formula/local-copy seams plus controller event
playback.  No runtime/tests/ROM were run or changed.  Authored scope is exactly
this report and this handoff; `git diff --check` is required before review.
