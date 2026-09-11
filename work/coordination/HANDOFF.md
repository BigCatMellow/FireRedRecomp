# FireRedRecomp Coordination Handoff

- Record role: `HANDOFF`
- Primary information class: `TASK CONTEXT`
- Status: `BLOCKED_WORKER_EXECUTION_BRIDGE`
- Lifecycle: `ACTIVE`
- Authority: coordination state only; root `AGENTS.md` and the active task own authority
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Parent gate: [`../tasks/phase3-exit-proof.md`](../tasks/phase3-exit-proof.md)
- Active task: [`../tasks/phase3-title-oak-entry-proof.md`](../tasks/phase3-title-oak-entry-proof.md)
- Machine state: [`STATE.json`](STATE.json)

## Summary

Worker characterized the live title/new-game entry boundary and found the first
actual missing seam, but did **not** widen scope or publish an unsafe gameplay
change.

Current `main.lua` has the relevant pieces separately:

```text
title view
Oak intro view
Oak intro A input -> beginNewGameFlow()
post-Oak identity flow -> fresh session -> Player's House 2F
```

The title view has no normal runtime input transition into the Oak intro. The
existing Phase 3 replay starts by calling `beginNewGameFlow()` directly and
explicitly says it does not claim to automate the preceding Oak scene.
Therefore the current code does not yet satisfy this task's normal
boot/title -> Oak/identity reachability criterion.

## Smallest bounded implementation now known

The active task permits the narrow correction that evidence requires:

1. wire the normal title/new-game input seam into the existing Oak intro;
2. add deterministic runtime replay/assertion evidence that drives title ->
   Oak -> identity -> fresh session through ordinary runtime input/event seams;
3. assert identity plus initial bedroom/session state;
4. run focused, no-ROM, and verified-ROM suites;
5. route the exact revision to independent Reviewer.

This does **not** require Phase 2 Oak animation completion, a scene-stack
redesign, script-interpreter work, or downstream gameplay changes.

## Exact blocker

The verified local execution bridge is stale relative to the newly dispatched
task. `.github/workflows/local-worker-bridge.yml` still:

- describes its patch allowlist as the completed Oak Parcel/Dex task;
- permits only that task's implementation/test/replay files;
- always runs `tests/oak_parcel_dex_presentation_test.lua` as its focused test;
- always runs `scripts/runtime_natural_capture_replay.sh` as its runtime replay;
- stages only the previous task's files for publication.

A title-entry patch would therefore be rejected even though `main.lua` and
focused Phase 3 entry replay/test support are permitted by the current active
task.

Changing the bridge workflow itself is not in this Worker's current task MAY
CHANGE boundary. Worker therefore failed closed rather than weakening target
validation or reconstructing/replacing the large `main.lua` through an unsafe
whole-file edit.

No gameplay change was published and no new ROM-backed test result is claimed.

## Next role and smallest resolution

`ORCHESTRATOR`

Authorize/dispatch the smallest bridge-maintenance correction necessary to
support `work/tasks/phase3-title-oak-entry-proof.md` while preserving all
existing security invariants:

- trusted `push` to `main` only;
- never execute public PR/fork code on the self-hosted runner;
- explicit task-bounded target validation;
- verified FireRed v1.0 SHA-1 gate;
- publish only after required tests pass;
- no ROM/cache/assets in GitHub.

Then return the **same** title/Oak entry task to `READY_FOR_WORKER`. Do not
replace it with broader Phase 2 or Phase 4 work.

## Do not work around

- Do not treat the `T`, `S`, or `N` developer view hotkeys as proof of a normal
  title/new-game path.
- Do not weaken or bypass the bridge allowlist.
- Do not replace the roughly 224 KB `main.lua` from partial excerpts.
- Do not claim tests or ROM evidence that did not run.
- Do not advance Phase 3 status.

```text
Phase 3 title/Oak entry proof
-> CHARACTERIZED: missing title -> Oak runtime seam
-> BLOCKED: local bridge still scoped to prior Oak Parcel/Dex task
-> ORCHESTRATOR: repair/authorize execution substrate only
-> WORKER: resume same bounded title/Oak entry task
-> REVIEWER: independently verify exact revision/evidence
```
