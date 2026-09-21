# Task: recover evidence gaps in the behavior ledger

- Task ID: `P0-01-DISCOVERY`
- Status: `READY_FOR_WORKER`
- Type: `RESEARCH / READ-ONLY EVIDENCE AUDIT`
- Parent capability gate: Phase 0 behavior ledger, MAPSL `P0-01`.
- Assigned role: `RESEARCHER`; independent reviewer: a separate helper.
- Prerequisites: existing ledger and implemented subsystems at `eac7d69`.
- Risk: `LOW` — text report only; no runtime or evidence-status changes.

## Goal and source of truth

Audit the existing ledger's subsystem claims against specific source locations,
runtime owners and deterministic test/replay evidence. Identify the smallest
documentation correction, not a new subsystem implementation program.
Use `docs/behavior-ledger.md`, MAPSL P0-01, canonical capability status and
accepted task/review receipts. Pin findings to `eac7d69` or explicitly name a
later accepted revision; do not confuse concurrent save/CI drafts with evidence.

## MAY CHANGE

1. `work/reports/phase0-behavior-ledger-audit.md`.
2. This task's research evidence and handoff.

## MUST NOT CHANGE

Ledger, runtime, tests, workflows, other documentation, task/phase statuses
outside this task, save policy, private runner or external state. No ROM/media
access, generated/extracted assets, new broad parity claim or unrelated cleanup.
The ongoing counter correction and CI-check package have separate owners.

## Acceptance criteria

1. Cover every current ledger row, grouped into importer, map/script, battle/capture, save and renderer/input/scene domains. For each, name the concrete runtime owner, source/data basis and relevant existing tests/replay receipts, or mark the missing element UNKNOWN.
2. Distinguish source citation, code presence, executed tests and independent acceptance. Test filenames or globs alone cannot prove runtime completeness. Do not rerun the whole suite merely to support a prose audit.
3. Check stale positive and negative claims, including the current PC-overflow-incomplete claim against accepted capture/storage evidence. Do not replace a narrow historical limitation with an unqualified completeness claim.
4. Identify materially missing ledger coverage among the existing named domains, not every helper module or speculative future feature. Preserve all relevant state/ROM/visual-parity exclusions.
5. Recommend at most one bounded ledger-only correction package, with exact rows and source/evidence links. Separate any real missing behavior/test proof from documentation fixes; do not authorize their implementation.
6. Independent review must accept the exact report before ledger edits or parent-gate reconciliation. Phase 0 remains open.

## Required evidence

- Exact inspected revision, row-by-row map and source/test/review anchors.
- Read-only source/history/public-receipt checks only as needed to substantiate claims; report-only work needs no new full suite or ROM execution.
- Audit that only the two allowed text paths changed; independent exact-revision review.

## Stop / escalate when

Evidence cannot justify a claim, a runtime gap requires implementation, or a
claim depends on absent retail/private-runner evidence. Mark the precise UNKNOWN
and continue the other existing rows; do not invent completeness or widen scope.

## Completion and handoff

Researcher reports exact findings and writes only the two artifacts. Parent
owns the shared-checkout commit/publication. Independent Reviewer returns
PASS / NEEDS_FIX / BLOCK, then Orchestrator selects only an evidenced successor.
This read-only audit is disjoint from current save/CI implementations; their
independent implementation reviews take priority when ready.
