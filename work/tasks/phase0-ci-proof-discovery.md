# Task: audit the current reproducibility checks

- Task ID: `P0-03-DISCOVERY`
- Status: `CLOSED — REVIEWED PASS`
- Type: `RESEARCH / READ-ONLY CI AUDIT`
- Parent capability gate: Phase 0 reproducibility in [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md); MAPSL `P0-03`.
- Assigned role: `RESEARCHER`.
- Independent reviewer: separate `REVIEWER` helper.
- Prerequisites: current workflow/test scripts and public GitHub run evidence; independent of save research and the offline private ROM runner.
- Risk: `LOW` — report only; no workflow execution changes.

## Goal and source of truth

Determine exactly which Phase 0 clean-checkout/no-ROM/syntax/documentation
checks already run in public CI, verify one exact current successful run, and
propose the smallest missing reproducibility package if evidence shows a gap.
Use `.github/workflows/test.yml`, `scripts/test_all.sh`, `AGENTS.md`, the
canonical capability checklist, MAPSL `P0-03`, and actual GitHub run/job logs.
Do not invent additional requirements from generic CI preferences.

## MAY CHANGE

1. `work/tasks/phase0-ci-proof-discovery.md`
2. `work/reports/phase0-ci-proof.md`

Temporary read-only diagnostic harnesses outside git are permitted. Coordination
and independent review records belong to their assigned owners.

## MUST NOT CHANGE

Workflows, tests, scripts, runtime, permissions, branch protection, dependencies,
save/inventory artifacts, or phase status. Do not dispatch or rerun workflows,
publish requests, access private ROM content, or upload artifacts. No broad
formatting or historical documentation cleanup.

## Acceptance criteria and evidence

1. Map each existing P0-03 requirement to the actual workflow command and a current exact commit/run/job result, or explicitly missing evidence. Confirm the no-ROM boundary and what the suite's skip behavior proves.
2. Distinguish Lua test execution from syntax checks of every tracked Lua file, and identify the current local-documentation link/check policy if any. Run read-only local characterization only when needed to make a proposed change concrete; no test or CI implementation.
3. Record the earliest/current supported public CI proof without inferring a whole Phase 0 gate from a green run. Keep first-run verification separate from newly proposed safeguards.
4. Propose at most one smallest bounded successor with exact file surface, commands, acceptance, and known failures. If the existing requirement is already met, say so and avoid manufacturing work.
5. Independent review must accept the exact findings before capability reconciliation or a subsequent implementation dispatch.

## Stop / escalate when

Required historical logs are unavailable, requirements conflict, a proposed
change widens execution permissions or needs external service configuration,
or reproducing an issue would mutate unrelated state. Record the precise gap
and continue independent evidence collection. User is unavailable; do not ask
repeatedly or block unrelated authorized work.

## Completion and handoff

Researcher commits only the two text artifacts and returns exact source/run/
command evidence. Reviewer returns PASS / NEEDS_FIX / BLOCK. Orchestrator
reconciles and selects only an evidenced successor; Phase 0 stays IN PROGRESS
until its complete exit criteria are met.

## Research handoff — 2026-09-21

Completed [the public CI proof report](../reports/phase0-ci-proof.md) against
live main/source `ea0960efdb5e790b995067af587b2726d09097a4`. Current public run
`35549967862` / job `106182752633` passed all 149 test files in explicit no-ROM
mode from a fresh hosted checkout. Earliest available workflow run number 1,
`32798335573` / job `97654137947` at `e511f08f52778b7eda8a9e9886245ca397e07f54`,
has independently retrieved checkout/skip/117-file PASS logs. Empty old-run
output from `gh run view --log` was resolved via the direct job-log API.

Local read-only checks: all 273 tracked Lua files parse; candidate extraction
from 135 tracked Markdown files finds 128 local destinations, zero missing
targets and zero targets absent from the pinned tracked tree. This is not a
full Markdown/external-link/heading audit. No full local suite rerun is claimed.

Only evidenced missing P0-03 enforcement is all-tracked-Lua syntax plus an
explicit executable local-documentation link/check policy. The report proposes
one four-file successor, with no known baseline code/link defect, new dependency,
permission change, or historical cleanup. No workflow/script/test/runtime was
changed or dispatched. Independent discovery review must precede successor
authorization; Orchestrator owns shared-checkout commit/publication and status
reconciliation. Phase 0 is not closed by these receipts.

## Orchestrator reconciliation — 2026-09-21

Exact report revision `b5b317b` independently
[passed review](../reviews/2026-09-20-ci-proof-discovery-review.md).
The first/current public-run facts are accepted, not the presence of the
proposed safeguards. Dispatch only the bounded
[repository-check package](phase0-ci-repository-checks.md); P0-03 and Phase 0
remain open until their remaining evidence gates pass.
