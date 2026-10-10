# Task: rerank the next bounded Phase 4 effect discovery

- Task ID: `P4-NEXT-EFFECT-RERANK`
- Status: `CLOSED — REVIEWED PASS`
- Type: `RESEARCH / READ-ONLY`
- Parent capability gate: Phase 4 move/effect matrix
- Assigned role: `RESEARCHER`
- Independent reviewer: `REVIEWER`
- Prerequisites: accepted inventory `c10bfa7`, Restore HP `dc8ad06`, current
  `BattleEngine` and accepted effect task/review evidence.
- Risk: `LOW` — a mistaken ranking could misroute later work; this task changes
  no behavior, tests, routes, or capability status.

## Goal

Replace the now-consumed Restore HP shortlist entry with one evidence-backed
next source-lock discovery candidate, ranked by early-story use, missing
prerequisites, and bounded testability.

## MAY CHANGE

- `work/reports/phase4-next-effect-rerank.md`
- this task's handoff section

## MUST NOT CHANGE

Runtime, tests, battle admission, route/workflow, runner/ROM configuration,
save/UI/AI, existing task results, capability status, and any implementation
artifact. Do not treat ordinary positive-power fallback as effect coverage.

## Acceptance criteria

1. Reconcile current accepted coverage, including Restore HP, against the
   inventory's candidate/blocked families.
2. Rank a short list using pinned source and explicit early-story evidence.
3. Name exactly one next source-lock discovery or explicitly report that all
   viable candidates need a prior subsystem design.
4. Preserve source links, exclusions, uncertainty, and no-ROM/data boundary.
5. Independent review assesses only the exact report/task revision.

## Required evidence

- Baseline: current accepted task/review/register records.
- Focused: source and existing-test inspection; no ROM execution required.
- Full: N/A — research only; `git diff --check` required.
- Review: independent exact revision review.

## Stop / escalate when

Source or early-story evidence cannot support a ranking, an implementation is
needed to answer it, or a candidate requires an unmodeled subsystem. Record
the blocker; do not implement or widen scope.

## Completion and handoff

- Researcher records ranked evidence and one successor recommendation.
- Reviewer decides `PASS | NEEDS_FIX | BLOCK`.
- Orchestrator compiles only the selected source-lock task after PASS.

## Result

Independent [PASS review](../reviews/2026-10-10-next-effect-rerank-review.md)
accepted `23d0b46`. The sole successor is `P4-F1-MAGNITUDE-DISCOVERY`; no
implementation, route, ROM, or capability authority follows.

## Researcher handoff — 2026-10-10

[`phase4-next-effect-rerank.md`](../reports/phase4-next-effect-rerank.md)
reconciles accepted Restore HP coverage and selects exactly one successor:
read-only `P4-F1-MAGNITUDE-DISCOVERY` for effect 126 / move 222. Defense Curl,
Trap, and poison-hit remain explicitly blocked on unmodeled state/lifecycle;
Haze ranks below Magnitude on demonstrated early-story priority. The report is
source-only, retains all exclusions, and authorizes neither implementation nor
route/ROM work. Independent exact-revision review is required.
