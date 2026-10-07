# Task: prove repaired private-runner toolchain

- Task ID: `RUNNER-LUA5-RECOVERY`
- Status: `READY_FOR_REVIEWER`
- Type: `RECONCILIATION / EXECUTION SUBSTRATE / READINESS PROBE`
- Parent capability gate: guarded bridge availability; no capability row changes
- Assigned role: `ORCHESTRATOR`
- Independent reviewer: `REVIEWER` — fresh context, no shared editing of this task
- Prerequisites: `MediaCenter` runner `24` observed online, idle, and labeled
  `firered-local`; `lua5.1 -v` locally reports Lua 5.1.5; the prior exact
  retries `37080060017` and `37125167854` are terminal failures at the missing
  Lua guard and may not be retried again.
- Risk: `MEDIUM` — a new probe reaches the private-ROM hash gate, but contains
  no game patch and must not create implementation evidence.

## Goal

Obtain one independent authorization for one metadata-only `runner-readiness`
probe that proves the repaired runner can check out trusted `main`, select its
existing fail-closed route, invoke Lua, and verify the private FireRed US v1.0
ROM hash.

## Source of truth

- `.github/workflows/local-worker-bridge.yml`: existing `runner-online*.probe`
  selector and its checkout, Lua, and ROM-hash guards.
- `work/coordination/HANDOFF.md`: both prior exact reruns failed before checkout
  and ROM access only because `lua5.1` was absent.
- `work/coordination/STATE.json`: live runner and exhausted-retry authority.

Unknowns requiring discovery: none. This task is not a repair to the workflow,
the runner service, the private-ROM location, or the ROM itself.

## MAY CHANGE

After independent `PASS` and a fresh GitHub online/idle observation, create and
push exactly this one new file:

- `work/local-runner/probes/runner-online-lua5-recovery-20261007.probe`

Its exact UTF-8 text is:

```text
task=runner-readiness
reason=verify-lua5-recovery
scope=checkout-route-lua-rom-hash-only
```

Record the resulting run ID, job steps, and terminal result in the existing
coordination handoff/register/state. An independent reviewer must review the
probe result before it can inform any subsequent recovery authority.

## MUST NOT CHANGE

- Do not modify `.github/workflows/local-worker-bridge.yml`, runner service
  configuration, ROM location/configuration, or any private ROM file.
- Do not create, amend, duplicate, or rerun the Restore HP artifact at `6395a47`
  or the P5 probe artifact at `f6b9148`.
- Do not change source, tests, runtime scripts, route allowlists, task scopes,
  capability checklist, or behavior status.
- Do not treat a readiness success as Restore HP implementation evidence or P5
  projection/readiness evidence.
- Do not commit ROMs, ROM-derived files, credentials, or absolute private paths.

## Acceptance criteria

1. Independent review confirms the one-file, existing-route boundary and that
   the prior retry authority is not silently extended.
2. Immediately before dispatch, GitHub reports `MediaCenter` online, idle, and
   labeled `firered-local`.
3. The resulting job succeeds through checkout, `Verify local toolchain`,
   `Locate and verify private FireRed ROM`, and `Probe complete`; otherwise
   record the exact failing guard and stop.
4. No implementation, route, capability, or ROM-derived artifact is published.

## Required evidence

- Baseline: `lua5.1 -v` reports Lua 5.1.5; GitHub runner `24` reports online,
  idle, and includes `firered-local`.
- Focused verification: exact probe filename and bytes; `git diff --check`.
- Full verification: the existing guarded bridge job; its success is substrate
  evidence only, not game-behavior evidence.
- Review evidence: exact authorization revision plus an independent review file,
  then a separate independent review of the resulting job evidence.

## Stop / escalate when

- the runner is offline or busy;
- GitHub refuses the probe or any guard fails;
- the workflow requests a route, path, credential, ROM, or behavior change;
- the intended change differs from the literal one-file content above.

Stop, record the exact state, and compile a separate task. Do not retry this
probe or substitute either exhausted P4/P5 run.

## Completion and handoff

- Worker records: the new probe revision, GitHub run/job URL, exact job steps,
  and terminal result.
- Reviewer decides: `PASS | NEEDS_FIX | BLOCK` for the authorization and,
  separately, for any executed probe evidence.
- Orchestrator reconciles: update only the task register, state, and handoff;
  do not advance P4 or P5 without their own new reviewed authority.
- Eligible successor: explicit, separately compiled recovery authority for the
  smallest affected P4 or P5 artifact; no successor is implied by this task.
