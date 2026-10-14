# Task: establish effect-45 bridge readiness only

- Task ID: `P4-F3-RECOIL-IF-MISS-ROUTE-PROBE`
- Status: `READY_FOR_WORKER`
- Type: `GUARDED READINESS PROBE`
- Parent: [Phase 4 move/effect matrix](../roadmaps/CAPABILITY_CHECKLIST.md).
- Assigned role: `WORKER`; independent reviewer: `REVIEWER`.
- Prerequisite: configuration `1d40f3c` and
  [independent PASS](../reviews/2026-10-13-recoil-if-miss-route-configuration-review.md).
- Risk: `MEDIUM` — only substrate verification is authorized, not patch execution.

## Goal and source of truth

Create exactly one readiness-only probe at
`work/local-runner/probes/phase4-recoil-if-miss-effect-route-20261013.probe`.
Use the accepted [route plan](../reports/phase4-recoil-if-miss-route-plan.md),
configuration/review and current workflow. Before dispatch, recover existing
jobs and verify an online, idle `firered-local` runner; any active/queued
bridge input, changed route or unavailable required substrate is a stop.
The parent Orchestrator serializes publication and performs the final fresh
prerequisite check immediately before the one dispatch.

## MAY CHANGE / MUST NOT CHANGE

Only the literal probe file above may change in the Worker package. It must
be the triggering commit's sole changed file and sole bridge input. Its text
must identify this task and limit the outcome to trusted checkout, exact
route recognition, Lua toolchain and existing supported-ROM SHA readiness.

No patch/request, workflow, code/tests/replay, runner/credential/ROM
configuration, coordination, capability-status or gameplay change. No private
path/data, ROM contents or environment-bearing logs in public receipts.
Do not run gameplay tests or a replay directly. No second probe or retry.

## Acceptance and required evidence

1. Exact one-file probe commit selects `phase4-recoil-if-miss-effect`.
2. Guarded job passes trusted checkout, input identification, explicit route
   selection, Lua, supported-ROM SHA and `Probe complete`.
3. All seven patch-only steps skip: target validation, patch application,
   focused tests, no-ROM suite, verified-ROM suite, replay and publication.
4. Record only safe commit/run/job IDs and step statuses. `git diff --check`
   must pass; no gameplay suite is applicable to a substrate-only probe.
5. Independent exact outcome review must PASS before a separately reviewed
   implementation authority can be dispatched. Probe success is not behavior
   evidence and does not test the ten-path allowlist.

## Stop and handoff

Any failed prerequisite, guard or job is terminal for this task's one-probe
allowance. Record the precise failure and required unblock input; do not
retry, substitute an input or widen the route. Worker supplies the exact
artifact; Orchestrator publishes/monitors under this task, then Reviewer
returns `PASS | NEEDS_FIX | BLOCK`. Only the Orchestrator reconciles receipts
and compiles the later implementation authority after PASS.
