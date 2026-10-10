# Task: source-lock bounded Magnitude behavior

- Task ID: `P4-F1-MAGNITUDE-DISCOVERY`
- Status: `CLOSED — REVIEWED PASS`
- Type: `RESEARCH / SOURCE LOCK`
- Parent capability gate: Phase 4 move/effect matrix
- Assigned role: `RESEARCHER`
- Independent reviewer: `REVIEWER`
- Prerequisite: [accepted rerank](../reviews/2026-10-10-next-effect-rerank-review.md)
- Risk: `LOW` — source misreading could misroute later design; this task changes
  no runtime behavior, admission, route, or ROM content.

## Goal

Lock the exact represented-singles source contract for Magnitude, effect 126 /
move 222, including RNG, dynamic-power, event/message order and exclusions.

## Source of truth

- Pinned `pret/pokefirered` `c75f352304d529f6ba92d4f74b9cf8b5c3810788`:
  Magnitude script and command implementation named by the accepted rerank.
- Current `BattleEngine` RNG, ordinary hit/event, PP and move-admission seams.

## MAY CHANGE

- `work/reports/phase4-magnitude-source-discovery.md`
- this task's handoff/result section

## MUST NOT CHANGE

Runtime/tests/admission, bridge route/workflow, runner/ROM configuration,
save/UI/AI, current effect implementations, coordination/capability status,
and implementation artifacts. No ROM or derived content in git.

## Acceptance criteria

1. State exact `Random() % 100` threshold-to-level/power table and draw order.
2. Trace cancellation, announcement, PP, target, magnitude message and shared
   hit ordering, distinguishing source fact from project seam uncertainty.
3. Identify the smallest later design boundary and literal exclusions:
   Underground, target loops/doubles, abilities/items, cancellation expansion,
   visual timing, and generic dynamic-power abstractions.
4. Make no implementation, admission, ROM, or parity claim.

## Required evidence

- Baseline/focused: pinned source plus current code inspection.
- Full: N/A; `git diff --check` required.
- Review: independent exact report/task review.

## Stop / escalate when

Source cannot settle a required branch, or a conclusion requires code/ROM or
unmodeled multi-target state. Record `UNKNOWN`; do not implement.

## Completion and handoff

- Researcher records source anchors, table/order, unknowns and one design successor.
- Reviewer decides `PASS | NEEDS_FIX | BLOCK`.
- Orchestrator compiles only that accepted design successor after PASS.

### Researcher handoff — 2026-10-10

- Report: [phase4-magnitude-source-discovery.md](../reports/phase4-magnitude-source-discovery.md).
- Locked source fact: `BattleScript_EffectMagnitude` does cancellation,
  announcement, PP reduction, and first-target selection before its one
  `Random() % 100` Magnitude table draw; it announces the rolled level before
  the shared Underground-aware, all-target hit loop.
- Locked table: rolls `0-4/5-14/15-34/35-64/65-84/85-94/95-99` map to
  levels `4/5/6/7/8/9/10` and powers `10/30/50/70/90/110/150`.
- Project uncertainty: current bounded-singles events have no settled
  Magnitude-strength event/presentation shape and no target-loop or
  Underground state.  The report records these as `UNKNOWN`, not behavior.
- Proposed sole successor after review: design-only `P4-F2-MAGNITUDE-DESIGN`;
  it must preserve singleton, no-Underground/no-doubles/no-generic-framework
  boundaries.  No implementation or bridge action is authorized by this task.

## Result

Independent [PASS review](../reviews/2026-10-10-magnitude-source-discovery-review.md)
accepted `5770a4d`. The sole successor is design-only
[`P4-F2-MAGNITUDE-DESIGN`](phase4-magnitude-design.md); no implementation
authority follows.
