# FireRedRecomp Coordination Handoff

- Record role: `HANDOFF`
- Primary information class: `TASK CONTEXT`
- Status: `READY_FOR_WORKER`
- Lifecycle: `ACTIVE`
- Authority: coordination state only; root `AGENTS.md` and the active task own authority
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Parent gameplay gate: [`../tasks/phase3-exit-proof.md`](../tasks/phase3-exit-proof.md)
- Blocked gameplay task: [`../tasks/phase3-title-oak-entry-proof.md`](../tasks/phase3-title-oak-entry-proof.md)
- Active task: [`../tasks/local-worker-bridge-task-routing.md`](../tasks/local-worker-bridge-task-routing.md)
- Machine state: [`STATE.json`](STATE.json)

## Summary

The previous Worker turn correctly stopped after characterization. It found a
real, narrow Phase 3 integration gap but could not safely implement it because
the verified Local Worker Bridge is still hard-coded to the already completed
Oak Parcel/Dex task.

Characterized runtime state:

```text
title view exists
Oak intro view exists
Oak intro A input -> beginNewGameFlow()
post-Oak identity flow -> fresh session -> Player's House 2F

missing seam:
normal title/new-game input -> Oak intro
```

No gameplay change was published and no test/ROM result was invented.

## Orchestrator reconciliation

This is an execution-substrate mismatch, not evidence that the Phase 3 title
entry task needs broader gameplay scope.

A separate bounded infrastructure task now owns the smallest prerequisite:

[`../tasks/local-worker-bridge-task-routing.md`](../tasks/local-worker-bridge-task-routing.md)

Its job is only to retarget the bridge so the already-authorized
title/Oak-entry task can use the safe local patch/test/publish substrate.

Phase 3 remains `IN PROGRESS`. The title/Oak entry leaf remains open. No
canonical capability status changed.

## Active Worker package

Worker should execute only the bridge-routing maintenance task.

Expected result:

1. replace the stale unconditional Oak Parcel/Dex-only route with an explicit,
   fail-closed task route that can support `phase3-title-oak-entry-proof.md`;
2. preserve explicit target validation;
3. preserve trusted `push` to `main` only;
4. preserve the prohibition on `pull_request` / `pull_request_target`
   self-hosted execution;
5. preserve exact FireRed v1.0 ROM SHA-1 verification;
6. preserve focused + no-ROM + verified-ROM test-before-publish behavior;
7. preserve explicit staging/publishing of only task-authorized files;
8. prove the title/Oak route is recognized with a non-gameplay validation or
   equivalent deterministic evidence;
9. route the exact bridge-maintenance revision to independent Reviewer.

## Boundaries

### MAY CHANGE

- `.github/workflows/local-worker-bridge.yml`
- `work/coordination/LOCAL_RUNNER_BRIDGE.md` if needed
- focused bridge validation support if required
- active task / coordination / review documentation

### MUST NOT CHANGE

- `main.lua` or gameplay/runtime behavior
- title/Oak gameplay implementation or replay content in this infrastructure
  package
- public-PR execution policy
- supported-ROM policy or exact ROM SHA gate
- ROM/cache/BIOS/extracted content
- repository permissions beyond what the existing bridge needs
- independent-review requirement

## Why a separate task is required

The current bridge procedure and workflow explicitly say their allowlist is for
the Oak Parcel/Dex task. The previous Worker did not have authority to alter
that execution substrate from inside the gameplay task. Keeping the repair in a
separate infrastructure leaf preserves the rule that capability does not widen
task authority.

## Next role

`WORKER`

Execute `work/tasks/local-worker-bridge-task-routing.md` only.

If the bridge cannot be safely retargeted without weakening the trusted-main,
explicit-allowlist, ROM-verification, or test-before-publish boundary, record
`BLOCKED` rather than making the bridge generic/permissive.

## After independent PASS

Orchestrator must restore:

`work/tasks/phase3-title-oak-entry-proof.md`

as the active `READY_FOR_WORKER` package.

The already-characterized smallest gameplay work is then:

```text
wire normal title/new-game input -> existing Oak intro
+ deterministic runtime entry replay/assertions
+ required focused/no-ROM/verified-ROM evidence
+ independent review
```

Do not substitute Phase 2 Oak visual parity, Phase 4 battles, generic scene
architecture, script-interpreter work, or save-layout expansion.

## Continuous-improvement check

A concrete process failure was found: the execution bridge encoded one
completed task directly and became stale when dispatch moved to the next task.
The bounded maintenance task should correct that routing defect while staying
explicit and fail-closed. No broader coordination redesign is justified by the
current evidence.

```text
Phase 3 title/Oak entry proof
-> CHARACTERIZED: narrow title -> Oak seam missing
-> BLOCKED by stale task-specific bridge
-> ACTIVE NOW: bounded bridge routing maintenance
-> WORKER
-> REVIEWER
-> ORCHESTRATOR restores same title/Oak gameplay task after PASS
```
