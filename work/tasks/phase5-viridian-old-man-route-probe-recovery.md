# Task: recover one Viridian Old Man route-readiness probe

- Task ID: `P5-04-ROUTE-PROBE-RECOVERY`
- Status: `READY_FOR_REVIEWER`
- Type: `RECONCILIATION / GUARDED READINESS PROBE`
- Parent capability gate: P5-04 route readiness; no implementation authority or capability-completion change
- Assigned role: `ORCHESTRATOR`
- Independent reviewer: `REVIEWER` — fresh context, no shared editing of this task, the original probe, or any projection implementation
- Prerequisites: P5 route plan/configuration passed; original sole probe exhausted before ROM access; `RUNNER-ROM-CONFIG-RECOVERY` closed with checkout/Lua/private-ROM-SHA substrate evidence.
- Risk: `MEDIUM` — probe mode has no patch behavior, but a false readiness claim could improperly unlock a later implementation request.

## Goal

Authorize one new metadata-only route-admitted probe to establish that the existing P5 selector reaches all runner readiness guards. It must not create or test a projection implementation.

## Source of truth

- [P5 implementation task](phase5-viridian-old-man-projection-implementation.md): map/local-ID behavior boundary and no-patch-before-readiness rule.
- [P5 route configuration review](../reviews/2026-10-03-viridian-old-man-projection-route-configuration-review.md): selector and later five-path implementation boundary.
- `work/local-runner/probes/phase5-viridian-old-man-projection-route-20261003.probe`: canonical probe, SHA-256 `ae9485f5348376bf139d45279c5bb773c750cab70227bb2c48c3a25412eff212`.
- [ROM-configuration outcome review](../reviews/2026-10-09-rom-configuration-recovery-outcome-review.md): runner substrate proof only.

Unknown: whether the dedicated P5 selector completes checkout, Lua, private-ROM SHA, and probe mode on a fresh runner job.

## MAY CHANGE

Only after independent `PASS` and a fresh GitHub observation that runner `24` is online, idle, and labeled `firered-local`, create and push exactly:

- `work/local-runner/probes/phase5-viridian-old-man-projection-route-20261009-recovery.probe`

Its bytes and SHA-256 must exactly equal the canonical probe/digest above. Record run/job identifiers, named job-step outcomes, and terminal result. An independent outcome review is mandatory before any P5 patch task is prepared.

## MUST NOT CHANGE

- Do not create a patch/request, modify `main.lua`, introduce a helper, change tests/task/report implementation files, workflow, route allowlist, runner service, private configuration, or ROM files.
- Do not retry `37125167854`, amend `f6b9148`, or create another P5 probe.
- Do not modify P4 artifacts, P5 design/behavior scope, map/script behavior, capability status, or legal-content boundary.
- Do not record a private ROM path, ROM bytes, private hash output, credential, or derived ROM asset.
- Do not treat success as gameplay, projection, or implementation evidence.

## Acceptance criteria

1. Independent review confirms fresh one-probe authority, canonical digest, and absence of implementation scope.
2. Immediately before dispatch, runner `24` is online, idle, and labeled `firered-local`.
3. The artifact is byte-identical to the canonical probe, passes `git diff --check`, and is the triggering commit's sole bridge artifact.
4. The guarded job succeeds through checkout, explicit P5 route selection, Lua, private-ROM SHA verification, and `Probe complete`; otherwise record the exact guard/result and stop.
5. An independent outcome review accepts the exact job evidence before a separately compiled P5 implementation request exists.

## Required evidence

- Baseline: canonical SHA-256 match and fresh GitHub runner metadata.
- Focused verification: artifact digest, `git diff --check`, and exact route selection in the guarded job.
- Full verification: guarded readiness job; patch/test/replay steps remain skipped in probe mode.
- Review evidence: this authorization review, then a separate outcome review of the executed probe.

## Stop / escalate when

Runner state changes, GitHub refuses dispatch, digest differs, any readiness guard fails, a patch/behavior/private-config action is requested, or the selector does not retain explicit P5 route. Record the exact state; do not repair, substitute, or retry.

## Completion and handoff

- Worker records: artifact revision/digest, GitHub run/job identifiers, step outcomes, and terminal result without private details.
- Reviewer decides: `PASS | NEEDS_FIX | BLOCK` for authorization and separately for exact probe outcome.
- Orchestrator reconciles only after outcome review and preserves original exhaustion history.
- Eligible successor: separately compiled and independently reviewed P5 implementation authority only after this probe is accepted.
