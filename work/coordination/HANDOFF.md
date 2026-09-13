# FireRedRecomp Coordination Handoff

- Record role: `HANDOFF`
- Primary information class: `TASK CONTEXT`
- Status: `READY_FOR_WORKER`
- Lifecycle: `ACTIVE`
- Authority: coordination state only; root `AGENTS.md` and active task contracts own authority
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Completed parent gate: [`../tasks/phase3-exit-proof.md`](../tasks/phase3-exit-proof.md)
- Scoped Phase 2 implementation leaf: [`../tasks/phase2-gba-camera-viewport-proof.md`](../tasks/phase2-gba-camera-viewport-proof.md)
- Active prerequisite: [`../tasks/local-worker-bridge-phase2-camera-route.md`](../tasks/local-worker-bridge-phase2-camera-route.md)
- Machine state: [`STATE.json`](STATE.json)

## Summary

Phase 3 is complete and canonically `DONE` after independent review of the continuous runtime replay at `4f4f29ec`.

The next canonical unmet gate is Phase 2. The detailed checklist's earliest mechanical gap is now actionable because Phase 3 supplied live player movement: the overworld still needs a true camera-clipped 240×160 GBA viewport rather than exposing a full composed map.

That bounded implementation task is now defined in:

`work/tasks/phase2-gba-camera-viewport-proof.md`

It is intentionally narrow: camera geometry, clipping/transform integration, deterministic movement/edge evidence, and required regression suites. It does not authorize Oak-art/choreography work, general renderer rewrites, gameplay changes, or reference-asset commits.

Before that implementation can safely run on the verified-ROM self-hosted substrate, the guarded Local Worker Bridge needs one explicit route for the new task. That predictable prerequisite is being handled first rather than waiting for Worker to rediscover the same bridge blocker.

## Active Worker package

Execute only:

`work/tasks/local-worker-bridge-phase2-camera-route.md`

Expected result:

1. add one explicit `phase2-gba-camera-viewport-proof` route;
2. hard-code only the camera task's authorized target surface;
3. preserve fail-closed handling for unknown routes;
4. preserve trusted `push` to `main` only;
5. preserve the prohibition on `pull_request` / `pull_request_target` self-hosted execution;
6. preserve exact FireRed US v1.0 SHA-1 verification;
7. preserve focused + no-ROM + verified-ROM test-before-publish gates;
8. preserve explicit publish staging limited to task-authorized files;
9. prove route recognition with a non-gameplay probe or equivalent deterministic validation;
10. publish only inside the bounded infrastructure task and route the exact revision to independent Reviewer.

Do not implement camera behavior inside this prerequisite.

## Boundaries

### MAY CHANGE

- `.github/workflows/local-worker-bridge.yml`
- `work/coordination/LOCAL_RUNNER_BRIDGE.md` if needed
- focused bridge validation/probe support if required
- active task / coordination / review documentation

### MUST NOT CHANGE

- `main.lua` or normal camera/gameplay/runtime behavior
- camera modules under `src/core/`
- public-PR execution policy
- supported-ROM policy or exact ROM SHA gate
- ROM/cache/BIOS/reference screenshots/extracted content
- repository permissions beyond the existing bridge needs
- independent-review requirement

## After independent PASS

Orchestrator must restore:

`work/tasks/phase2-gba-camera-viewport-proof.md`

as `READY_FOR_WORKER`.

That task's required observable result is:

```text
normal live overworld
→ logical viewport exactly 240×160
→ camera follows live player continuously during tile movement
→ deterministic clamp behavior at map edges/small maps
→ player/NPC/map layers retain world alignment
→ outer ViewportScale still handles window scaling/letterboxing
```

Focused tests, full no-ROM, full verified-ROM evidence, and independent review are required.

## What remains after camera PASS

Phase 2 still will not be complete. The roadmap/checklist also require Oak-intro/reference screenshot discrepancy evidence. Existing pixel-diff tooling proves the comparison mechanism, not FireRed parity by itself. Orchestrator should scope that as the next smallest leaf only after the 240×160 camera prerequisite passes.

No ROM-derived reference screenshots or extracted assets may be committed.

## Status truth

- Phase 3: `DONE`
- Phase 3 continuous replay: `CLOSED — REVIEWED PASS` at `4f4f29ec`
- Phase 2: `IN PROGRESS`
- Phase 2 camera task: scoped, blocked only on explicit bridge route
- active package: `local-worker-bridge-phase2-camera-route.md`
- next role: `WORKER`

## Continuous-improvement check

The previous two large-file task transitions hit the same guarded-bridge routing prerequisite. That is intentional fail-closed security behavior, not a reason to make the bridge generic. This turn anticipates the known dependency by defining the implementation task first and dispatching its explicit route prerequisite immediately, avoiding another wasted Worker turn while preserving the same security boundary.

## Goal-continuity commitment

The active coordinating goal is intentionally broader than the current bridge
leaf. The Orchestrator continues autonomously through this chain without routine
user check-ins:

```text
camera bridge route → independent bridge review → camera viewport implementation
→ required evidence and independent review → canonical reconciliation
→ Oak/reference parity task scoping and dispatch
```

Only a genuine authority/safety boundary, a failed required evidence gate, or a
missing external retail-reference input may interrupt that chain. On such an
interruption, record the first exact blocker and preserve the current bounded
task; do not silently substitute a smaller goal or wait for a routine approval.
