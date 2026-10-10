# Task: prove private-ROM runner configuration

- Task ID: `RUNNER-ROM-CONFIG-RECOVERY`
- Status: `READY_FOR_REVIEWER`
- Type: `RECONCILIATION / EXECUTION SUBSTRATE / READINESS PROBE`
- Parent capability gate: guarded bridge availability; no capability row changes
- Assigned role: `ORCHESTRATOR`
- Independent reviewer: `REVIEWER` — fresh context, no shared editing of this task
- Prerequisites: `RUNNER-LUA5-RECOVERY` is terminal with independently reviewed
  evidence; `MediaCenter` runner `24` is freshly observed online, idle, and
  labeled `firered-local`; Lua 5.1.5 and a locally user-owned FireRed US v1.0
  file are available to the operator. The previous probe and P4/P5 retries are
  exhausted and must not be rerun.
- Risk: `MEDIUM` — the probe reaches the private-ROM hash guard, but contains
  no game patch and cannot establish gameplay behavior.

## Goal

Authorize one new metadata-only `runner-readiness` probe to prove that the
running self-hosted service inherits its private ROM configuration and passes
the existing checkout, Lua, and FireRed US v1.0 hash guards.

## Source of truth

- `.github/workflows/local-worker-bridge.yml`: existing `runner-online*.probe`
  selector and its checkout, Lua, and ROM-hash guards.
- `work/tasks/local-worker-bridge-lua5-toolchain-recovery.md` and its outcome
  review: the previous one-shot probe is terminal and creates no retry right.
- Fresh local/operator verification: the private candidate matches the supported
  FireRed US v1.0 SHA-1; no path, hash output, or ROM data belongs in Git.

Unknowns requiring discovery: whether the running service exposes its private
environment to a new GitHub Actions job. The new guarded probe is the only
permitted way to answer it.

## MAY CHANGE

After independent `PASS` and a fresh GitHub online/idle observation, create and
push exactly this one file:

- `work/local-runner/probes/runner-online-rom-config-recovery-20261009.probe`

Its exact UTF-8 text is:

```text
task=runner-readiness
reason=verify-private-rom-service-configuration
scope=checkout-route-lua-rom-hash-only
```

Record the resulting run ID, job steps, and terminal result in the existing
coordination handoff/register/state. An independent reviewer must review the
executed result before it can inform any later recovery authority.

## MUST NOT CHANGE

- Do not modify the workflow, runner service, service override, ROM location,
  private environment file, or any private ROM file.
- Do not record a private path, hash output, ROM byte, credential, or derived
  artifact in GitHub, Git, task evidence, logs, or review files.
- Do not create, amend, duplicate, or rerun the Restore HP artifact at `6395a47`
  or P5 probe artifact at `f6b9148`.
- Do not change source, tests, replay scripts, route allowlists, capability
  status, task scope, or behavior status.
- Do not treat a readiness success as P4 implementation evidence or P5
  projection/readiness evidence.

## Acceptance criteria

1. Independent review confirms the literal one-file boundary and that it does
   not extend the exhausted P4/P5 or prior readiness-probe authority.
2. Immediately before dispatch, GitHub reports `MediaCenter` online, idle, and
   labeled `firered-local`.
3. The resulting job succeeds through checkout, `Verify local toolchain`,
   `Locate and verify private FireRed ROM`, and `Probe complete`; otherwise
   record the exact guard and stop.
4. No implementation, route, capability, private configuration, or ROM-derived
   artifact is published.

## Required evidence

- Baseline: local private verification reports the supported v1.0 fingerprint;
  GitHub runner `24` reports online, idle, and includes `firered-local`.
- Focused verification: exact probe filename and bytes; `git diff --check`.
- Full verification: the existing guarded bridge job; success is substrate
  evidence only, not game-behavior evidence.
- Review evidence: exact authorization revision plus an independent review,
  then a separate independent review of the resulting job evidence.

## Stop / escalate when

- the runner is offline or busy;
- GitHub refuses the probe or any guard fails;
- the workflow requests a route, path, credential, ROM, or behavior change;
- the intended change differs from the literal one-file content above.

Stop, record the exact state, and compile a separate task. Do not retry this
probe or substitute any exhausted P4/P5 artifact.

## Completion and handoff

- Worker records: the new probe revision, GitHub run/job URL, exact job steps,
  and terminal result.
- Reviewer decides: `PASS | NEEDS_FIX | BLOCK` for the authorization and,
  separately, for any executed probe evidence.
- Orchestrator reconciles: update only task register, state, and handoff; do
  not advance P4 or P5 without their own newly reviewed authority.
- Eligible successor: explicit, separately compiled recovery authority for the
  smallest affected P4 or P5 artifact; no successor is implied by this task.
