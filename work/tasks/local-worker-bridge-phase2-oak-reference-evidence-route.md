# Task: add Local Worker Bridge route for Phase 2 Oak/reference evidence

- Status: `CLOSED — REVIEWED PASS`
- AGI status: `AGI READY`
- Type: `INFRASTRUCTURE / EXECUTION SUBSTRATE`
- Owner: project maintainer
- Risk: `LOW`
- Parent dependency: `work/tasks/phase2-oak-reference-evidence-harness.md`

## Goal

Add one explicit fail-closed Local Worker Bridge route for the bounded Phase 2
Oak/reference evidence harness. This task changes routing only, never visual or
gameplay behavior.

## MAY CHANGE

- `.github/workflows/local-worker-bridge.yml`;
- `work/coordination/LOCAL_RUNNER_BRIDGE.md` if needed;
- focused route probe/validation support;
- this task and coordination/review documentation.

## MUST NOT CHANGE

- `main.lua`, capture implementation, Oak/camera/gameplay behavior, or tests;
- public-PR policy, permissions, exact ROM SHA gate, full-suite gates, fail-closed
  routing, or independent review;
- ROM/BIOS/reference screenshots/extracted content.

## Acceptance criteria

1. One exact `phase2-oak-reference-evidence-harness` route selects explicit,
   task-bounded target, focused-test, optional runtime capture, and staging lists.
2. Unknown routes remain fail closed; no wildcard/generic fallback is introduced.
3. Existing trusted-main-only, no-public-PR, ROM SHA, validation-before-apply,
   focused/no-ROM/verified-ROM/runtime-before-publish invariants remain intact.
4. A one-file non-gameplay probe proves the route is recognized.
5. Independent Reviewer passes the exact route revision before the evidence
   harness becomes `READY FOR WORKER`.

## Completion / handoff

Restore `phase2-oak-reference-evidence-harness.md` as the sole active Worker
package after independent PASS.

## Completion evidence

- Route configuration `ff5ff890c0548f79b5c104f24a935ef07e739ad0` received
  independent `PASS` after the required runtime-capture script was made
  fail-closed.
- One-file non-gameplay probe `763bb37f617a87bbcdf9415aa7482b24b1e70b5f`
  passed guarded Local Worker Bridge run `34753855210`, including trusted-main
  selection and private-ROM SHA verification.
- The resulting route requires the exact capture script before publication;
  its absence cannot be converted into a successful skip.
