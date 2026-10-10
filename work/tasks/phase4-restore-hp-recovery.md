# Task: recover one bounded Restore HP guarded request

- Task ID: `P4-F3-RESTORE-HP-RECOVERY`
- Status: `READY_FOR_REVIEWER`
- Type: `RECONCILIATION / GUARDED IMPLEMENTATION RECOVERY`
- Parent capability gate: Phase 4 smallest unmet Restore HP leaf; no phase-completion change
- Assigned role: `ORCHESTRATOR`
- Independent reviewer: `REVIEWER` — fresh context, no shared editing of this task or the Restore HP implementation surface
- Prerequisites: `P4-F3-ROUTE` passed, its sole guarded request exhausted before ROM access, and `RUNNER-ROM-CONFIG-RECOVERY` closed with checkout/Lua/private-ROM-SHA substrate evidence.
- Risk: `HIGH` — a patch route can publish battle behavior, so exact patch identity, guarded evidence, and independent review remain required.

## Goal

Authorize one new route-admitted Restore HP patch artifact whose bytes are identical to the already prepared bounded implementation patch, so the proven runner can produce required guarded evidence exactly once.

## Source of truth

- [Restore HP implementation task](phase4-restore-hp-implementation.md): accepted Recover (105) / Slack Off (303) effect-32 boundary and evidence requirements.
- [Route configuration review](../reviews/2026-10-02-restore-hp-route-configuration-review.md) and [route-probe review](../reviews/2026-10-02-restore-hp-route-probe-review.md): nine-path route boundary.
- `work/local-runner/requests/phase4-restore-hp-effect-20261002-v1.patch`: canonical prepared patch, SHA-256 `a5b28ccbbbb9dc4c5ec9ba869c17e9c3abfcb241b2b2bd912a057f79afd5bf0d`.
- [ROM-configuration outcome review](../reviews/2026-10-09-rom-configuration-recovery-outcome-review.md): substrate proof only, not behavior evidence.

Unknown: whether the exact patch applies and passes focused, no-ROM, SHA-ROM, and deterministic replay checks on a fresh guarded job.

## MAY CHANGE

Only after independent `PASS` and a fresh GitHub observation that runner `24` is online, idle, and labeled `firered-local`, create and push exactly:

- `work/local-runner/requests/phase4-restore-hp-effect-20261009-recovery.patch`

Its bytes and SHA-256 must exactly equal the canonical patch/digest above. Its triggering commit contains exactly that one bridge artifact. After completion, record only revision, run/job identifiers, named job-step outcomes, and terminal result; an independent exact outcome review is mandatory before accepting published implementation.

## MUST NOT CHANGE

- Do not modify the canonical patch, implementation source/tests/replay/task/report payload, workflow, route allowlist, runner service, private configuration, or ROM files.
- Do not create another Restore HP artifact, retry `37080060017`, or amend `6395a47` / the original request.
- Do not change P5 artifacts, capability status, general healing, source/design scope, or legal-content boundary.
- Do not record a private ROM path, ROM bytes, private hash output, credential, or derived ROM asset.
- Do not claim Phase 4, the effect family, or implementation completion from runner substrate evidence alone.

## Acceptance criteria

1. Independent review confirms fresh one-artifact authority, pinned digest, and literal route boundary.
2. Immediately before dispatch, runner `24` is online, idle, and labeled `firered-local`.
3. The artifact is byte-identical to the canonical patch, passes `git diff --check`, and is the triggering commit's sole bridge artifact.
4. The workflow validates/applies the patch and passes route-required focused, no-ROM, SHA-ROM, and deterministic replay checks; otherwise record the exact failure and stop.
5. An independent reviewer accepts the exact executed implementation/result before capability reconciliation.

## Required evidence

- Baseline: canonical SHA-256 match; fresh runner metadata; local no-ROM evidence is supplementary only.
- Focused verification: artifact digest, `git diff --check`, and route focused job step.
- Full verification: guarded workflow's no-ROM/SHA-ROM/replay steps.
- Review evidence: this authorization review, then a separate review of the exact executed result.

## Stop / escalate when

Runner state changes, GitHub refuses dispatch, digest differs, validation/application/check fails, a needed action is outside the nine-path route, or private information would be exposed. Record the exact state; do not repair, substitute, or retry.

## Completion and handoff

- Worker records: artifact revision/digest, GitHub run/job identifiers, step outcomes, and terminal result without private details.
- Reviewer decides: `PASS | NEEDS_FIX | BLOCK` for authorization and separately for exact output.
- Orchestrator reconciles only after outcome review and preserves original exhaustion history.
- Eligible successor: none until outcome review decides whether the existing implementation task can be reconciled.
