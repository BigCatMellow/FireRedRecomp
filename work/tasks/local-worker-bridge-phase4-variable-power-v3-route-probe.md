# Task: establish variable-power V3 bridge readiness only

- Task ID: `P4-VARIABLE-POWER-V3-ROUTE-PROBE`
- Status: `READY_FOR_REVIEWER` — probe contract drafted; the probe file is not
  yet created.
- Type: `GUARDED READINESS PROBE`
- Parent: [V3 route configuration](local-worker-bridge-phase4-variable-power-v3-route-configuration.md).
- Assigned role: `WORKER`; independent reviewer: a separate `REVIEWER`.
- Prerequisites:
  - Route configuration `20d8ba9` is merged at `5652093` and has an
    independent PASS: [`8d4c2ff`](../reviews/2026-11-15-variable-power-v3-route-configuration-review.md).
  - The merged workflow selects `phase4-variable-power-v3-effect` for the
    literal probe filename below.
  - Immediately before the one publication, the Orchestrator must freshly
    verify that the `firered-local` runner is online and idle, and that no
    bridge job is active or queued.
- Risk: `MEDIUM` — this verifies only the guarded execution substrate. It
  cannot establish gameplay or authorize an implementation patch.

## Goal and source of truth

Create exactly one readiness-only probe at
`work/local-runner/probes/phase4-variable-power-v3-effect-route-20261115.probe`.

The sources are:

- the merged, independently reviewed V3 route configuration;
- the [route plan](local-worker-bridge-phase4-variable-power-v3-route-plan.md);
- the then-current workflow and `work/coordination/LOCAL_RUNNER_BRIDGE.md`.

The probe may establish only trusted checkout, one-input identification,
exact route recognition, the Lua toolchain and the existing supported-ROM SHA
readiness.

If the calendar date is no longer 2026-11-15 when this task is adopted, the
Orchestrator must flag the filename as stale. It then selects one new
date-stamped literal filename before dispatch and records it in the adopted
contract. A filename or allowance is never reused.

## Exact probe content

The file content is exactly the following, with a trailing newline. It
mirrors the P5-06 probe `9472aec`:

```text
P4-VARIABLE-POWER-V3-ROUTE-PROBE

Readiness-only probe for the variable-power V3 bridge route.
Configuration: 20d8ba9 (merged 5652093), independently reviewed PASS 8d4c2ff.

Requested readiness:
- trusted checkout
- exact route recognition: phase4-variable-power-v3-effect
- Lua toolchain readiness
- existing supported FireRed US v1.0 ROM SHA-1 gate: 41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc

Patch-only steps explicitly skipped:
1. bounded target validation
2. patch application
3. Viridian roadblock pre-evidence artifact gate (route mismatch)
4. variable-power V3 pre-evidence artifact gate
5. route-focused tests
6. shared no-ROM suite
7. shared verified-ROM suite
8. route runtime replay
9. staging/publication

No gameplay, implementation patch, request, focused test, full suite, replay,
staging, or publication is requested or authorized by this readiness probe.
```

## MAY CHANGE / MUST NOT CHANGE

Only the literal probe file above may change in the Worker probe package. It
must be the sole changed file of the triggering commit, and the sole bridge
input. On a PR merge, that is the diff against the first parent.

This task must not change or create:

- a patch or request, the workflow, code, tests or a replay;
- the runner, credentials or ROM configuration;
- coordination records or capability status;
- any V3 package path or gameplay behavior.

While compiling this contract, do not inspect a ROM or submit a probe. Do not
expose private paths, ROM data, secrets or environment-bearing logs in the
probe, commit, review or receipt. Do not run gameplay tests or a replay
directly.

## Expected step outcomes (probe mode)

The steps that must succeed:

1. `Check out trusted main push`
2. `Identify bridge request` (`mode=probe`, exactly one input)
3. `Select explicit task route` (`phase4-variable-power-v3-effect`)
4. `Verify local toolchain`
5. `Locate and verify private FireRed ROM` (supported SHA-1)
6. `Probe complete`

The steps that must skip are all nine patch-only steps:

1. `Validate bounded patch targets`
2. `Apply bounded patch`
3. `Verify Viridian roadblock artifacts before evidence`
4. `Verify variable-power V3 artifacts before evidence`
5. `Run task-focused test`
6. `Run no-ROM suite`
7. `Run verified-ROM suite`
8. `Run task runtime replay`
9. `Publish verified bounded implementation`

## Acceptance and required evidence

1. **Authority.** The merged configuration and its independent PASS above
   remain the authority prerequisites. The fresh pre-publication checks are
   done by the Orchestrator, not the Worker, immediately before publication:
   - `origin/main` still contains `5652093`, and the workflow's
     `phase4-variable-power-v3-effect` selector is unchanged since then;
   - the `firered-local` runner is online and idle;
   - no Local Worker Bridge run is active or queued;
   - the probe filename has not been consumed before.
2. **The commit.** The Worker creates exactly the one-file probe commit with
   the content above. It selects only `phase4-variable-power-v3-effect`,
   contains no patch or request and no other changed file, and passes
   `git diff --check`.
3. **The run.** The guarded job shows exactly the step outcomes above. Record
   only:
   - the commit, run and job IDs;
   - the named step statuses;
   - the SHA-256 of the probe file.

   Do not copy logs, runner paths, ROM paths or ROM content.
4. **Scope of the evidence.** This probe is readiness evidence only. It does
   not exercise the 8-path allowlist, the focused commands, either full suite,
   the replay, gameplay or V3 behavior.
5. **Outcome review.** An independent exact probe-outcome review,
   `work/reviews/YYYY-MM-DD-variable-power-v3-route-probe-outcome-review.md`,
   returns `PASS | NEEDS_FIX | BLOCK`. That has to happen before the gate-4
   implementation authority
   (`work/tasks/local-worker-bridge-phase4-variable-power-v3-implementation-authorization.md`)
   can be compiled. A PASS does not by itself authorize a request.

## Stop and handoff

Stop without publication if any of these hold:

- the configuration is not exactly merged and independently passed;
- the selector differs;
- the runner is not freshly online and idle;
- a bridge job is active or queued;
- the one-file condition fails;
- the filename has already been consumed.

**No retry.** One publication consumes the sole allowance. Any failed
prerequisite, guard or job is terminal for this task. Record only the failure
step, its status and the input needed to unblock it. Do not retry, substitute
an input or widen scope.

Roles:

- The Worker creates the exact artifact only, in a separate probe PR.
- The Orchestrator performs the fresh prerequisite checks, then publishes and
  monitors the run.
- An independent Reviewer records the outcome verdict.

Gates 2-4 must not create or modify any V3 package path on main. No V3
acceptance or phase completion is claimed here.
