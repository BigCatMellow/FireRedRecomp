# Lua 5.1 runner-recovery probe — independent review

Verdict: **PASS** — the correction resolves the material failure-boundary
error without expanding the one-probe authority.

- Reviewed contract baseline: `3c09fb1bc434a1d9fad95a046fabe500adaab430`.
- Reviewed correction revision: `571b452444e37796258ed7f1aa1a48d10b057d74`
  (`Correct runner failure boundary`).
- Task: [RUNNER-LUA5-RECOVERY](../tasks/local-worker-bridge-lua5-toolchain-recovery.md).

## Independence and boundary

I reviewed the exact contract independently and authored only this review
file. The proposed artifact is one new literal probe,
`work/local-runner/probes/runner-online-lua5-recovery-20261007.probe`, whose
filename matches the pre-existing `runner-online*.probe` selector. In probe
mode the workflow performs checkout, request identification, route selection,
Lua verification, ROM SHA verification, and `Probe complete`; all patch-only
validation, application, focused/full tests, replay, and publication steps are
skipped.

The task explicitly forbids touching the P4 Restore HP request and P5 route
probe, route/workflow changes, replacement artifacts, code, test, ROM, or
capability scope. It requires a subsequent separate evidence review and does
not treat readiness success as P4 implementation or P5 readiness evidence.
Therefore, this is a distinct one-probe substrate check and does **not**
improperly extend the exhausted one-rerun P4/P5 authority.

## Correction disposition

The baseline contract incorrectly said both exhausted retries failed before
checkout. The correction updates only the affected task and coordination
statements. It now records that both retries completed trusted checkout,
request identification, and route selection, then failed `Verify local
toolchain` before ROM discovery/access:

- Restore HP rerun `37080060017`, job `112575360972`, completed checkout,
  request identification, and route selection, then failed `Verify local
  toolchain`; ROM verification and all later steps skipped.
- P5 rerun `37125167854`, job `112575394107`, completed those same first four
  steps, then failed `Verify local toolchain`; ROM verification and all later
  steps skipped.

This matches the recorded runs and preserves the critical limits: neither
prior artifact gains another retry, nor does the recovery probe become P4 or
P5 implementation/readiness evidence. The correction touches no workflow,
route, request/probe artifact, runner, code, or test and passes whitespace
validation.

## Remaining gates

After a fresh immediately-pre-dispatch observation that runner `24`
(`MediaCenter`) is online, idle, and labeled `firered-local`, one probe may be
considered. Earlier GitHub metadata is not a substitute for that required
observation. If the probe cannot reach the Lua or ROM guard, it must stop with
the exact failing guard; it may not rerun, substitute, or revive either
exhausted P4/P5 run.

Only this review file was authored. No task, coordination state, workflow,
runner, request/probe artifact, code, or commit was changed by the Reviewer.
