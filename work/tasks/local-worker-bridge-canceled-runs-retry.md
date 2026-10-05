# Task: authorize retry of canceled guarded bridge runs

- Task ID: `BRIDGE-CANCELLED-RUNS-RETRY`
- Status: `CLOSED — REVIEWED PASS`
- Type: `COORDINATION / EXECUTION SUBSTRATE / RETRY AUTHORIZATION`

## Goal

Authorize at most one GitHub workflow **re-run** for each guarded job canceled
without any steps while the private runner was offline. This task creates no
patch, probe, route, workflow, runner, or behavior change.

## Exact permitted action after PASS

Only after GitHub reports `firered-mint` online and idle, the Orchestrator may
invoke one re-run of each existing workflow run, retaining its original event
and commit:

1. Restore HP request run `37080060017`, original request commit `6395a47`.
2. Viridian projection readiness probe run `37125167854`, original probe commit
   `f6b9148`.

Before each re-run, record the live runner observation. After each re-run,
recover its exact job evidence. Restore HP still requires guarded publication
and independent exact implementation review. P5 still requires an executed
probe and independent probe review before any implementation request.

## MUST NOT DO

Do not create, copy, rename, amend, or push a new request/probe artifact; do
not change patch bytes, routes, workflow, runner, ROM handling, code, tests,
or canonical capability status. Do not re-run while the runner is offline or
busy. Do not attempt a new artifact if GitHub refuses a re-run; stop for a
separate reviewed contract.

## Evidence

Runs `37080060017` and `37125167854` both reached terminal `cancelled` status
with no job steps, while `firered-mint` was offline. Existing task authority
permits exactly one request/probe artifact, already present at the commits
above. GitHub re-run preserves those artifacts and is therefore materially
different from a duplicate push.

## Handoff

Independent review must PASS before this authorization takes effect. A PASS is
not runner availability and does not itself invoke either re-run.

## Review

The independent [retry review](../reviews/2026-10-05-canceled-bridge-runs-retry-review.md)
accepted exact `98540c588c0c7fa2074f9cb1b8302948b8e6f28b`. This closes only the
coordination authorization. Fresh live online/idle evidence remains required
immediately before each original-run re-run.
