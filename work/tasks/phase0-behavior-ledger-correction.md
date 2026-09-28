# Task: apply the bounded behavior-ledger evidence correction

- Task ID: `P0-01-CORRECTION`
- Status: `READY_FOR_WORKER`
- Type: `DOCUMENTATION / EVIDENCE RECONCILIATION`
- Parent capability gate: Phase 0 behavior ledger.
- Prerequisite: [P0-01 audit PASS](../reviews/2026-09-27-behavior-ledger-audit-review.md) for exact report `61f1a77`.
- Risk: `LOW` — an inaccurate documentation claim could misroute later work.

## Goal and source of truth

Apply only the audit's evidence-backed corrections to
[`docs/behavior-ledger.md`](../../docs/behavior-ledger.md). The audit report,
its independent review, canonical capability checklist, and cited accepted
review receipts are authoritative. Preserve the already accepted post-pin save
rollover wording at `9c81b90`; do not treat historical `eac7d69` limitations as
current facts when later acceptance corrects them.

## MAY CHANGE

1. `docs/behavior-ledger.md`.
2. This task's completion/handoff section.

## MUST NOT CHANGE

Runtime, tests, workflows, capability statuses, task/register/state files,
save policy, private runner, ROM/media, or external state. Do not add an
unqualified completeness claim, invent a missing acceptance receipt, or turn
component evidence into retail parity. Do not create a new implementation or
proof program.

## Acceptance criteria

1. Qualify each of the existing nine rows with the exact audit distinctions:
source, runtime ownership, assertion coverage, recorded execution, independent
acceptance, and UNKNOWN limits where applicable.
2. Replace the blanket PC-overflow negative with bounded routing/backing and
serialization evidence while retaining UNKNOWN for a full-party live capture →
PC → fresh-reload acceptance receipt.
3. Add exactly one adjacent bounded row for ordinary trainer parties and
replacement, with the five accepted leaves and their one/two-foe, no-item,
singles, AI/UI and layout limits. Do not call it general trainer completion.
4. Preserve Pain Split exclusions, post-pin save rollover wording, supported
ROM policy, Phase 2 visual-parity block, and every named UNKNOWN boundary.
5. Add the audit's omitted input/scheduler/title-entry/camera anchors to the
renderer/input/scene row; self-diff remains distinct from retail comparison.
6. Run only documentation-local checks appropriate to the change and record
them. Independent review must accept the exact revision before reconciliation.

## Stop / escalate when

An edit requires a claim beyond the audit/report evidence, alters canonical
phase state, or suggests runtime/test work. Leave the claim UNKNOWN, record the
specific boundary, and do not widen scope.

## Completion and handoff

Worker records exact changed paths and local checks. A different independent
Reviewer returns PASS / NEEDS_FIX / BLOCK. Parent reconciles only after PASS;
Phase 0 remains open for clean-clone and broader save-safety gates.
