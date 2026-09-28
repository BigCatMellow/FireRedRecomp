# Task: recover evidence gaps in the behavior ledger

- Task ID: `P0-01-DISCOVERY`
- Status: `CLOSED — REVIEWED PASS`
- Execution: exact report commit `61f1a77` passed independent review on 2026-09-27; its ledger-only successor is separately bounded.
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

Researcher reported exact findings in `61f1a77`; the independent
[review](../reviews/2026-09-27-behavior-ledger-audit-review.md) returned PASS.
Parent owns reconciliation. A separately tasked ledger-only correction may use
the evidence, but this audit neither closes Phase 0 nor approves runtime work.
This read-only audit is disjoint from current save/CI implementations; their
independent implementation reviews take priority when ready.

## Research evidence and handoff — 2026-09-27

The [completed report](../reports/phase0-behavior-ledger-audit.md) maps all nine
rows at exact `eac7d6985e6bbf1c33c3c4b6e9c338c08f3d0990`, separating reference
source, runtime call sites, inspected assertions, recorded execution and
independent acceptance. It identifies the stale blanket PC-overflow negative,
decoded-but-unhooked script behavior and omitted accepted trainer/replacement
and input/scene evidence. Unsupported completeness claims remain UNKNOWN.

One ledger-only successor is proposed, conditional on independent report PASS.
No ledger edit, runtime/test/workflow/coordination change, new suite/ROM/replay
execution or phase advancement was performed. Later accepted rollover
`aec377a`, reconciled at `9c81b90`, is explicitly separate from the historical
pin; any successor must preserve its already-corrected save row.

Read-only checks: source/history comparison, review receipts and target paths;
`git diff --check` PASS, all 89 local link occurrences resolve, and the commit
is restricted to the exact two allowed paths. The resumed parent
dispatch explicitly authorizes the Researcher to commit only this task/report
with Codex identity, without pushing; this supersedes only the older parent-
owned commit sentence above. Parent retains publication and coordination.
Independent Reviewer next: judge the exact report against the six existing
criteria, without treating this handoff as acceptance or reopening unrelated
implementation reviews.
