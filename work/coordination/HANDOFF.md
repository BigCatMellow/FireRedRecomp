# FireRedRecomp Coordination Handoff

- Record role: `HANDOFF`
- Primary information class: `TASK CONTEXT`
- Status: `READY_FOR_WORKER`
- Lifecycle: `ACTIVE`
- Authority: coordination state only; root `AGENTS.md` and active task contracts own authority
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Completed prerequisite: [`../tasks/local-worker-bridge-phase2-camera-route.md`](../tasks/local-worker-bridge-phase2-camera-route.md)
- Active package: [`../tasks/phase2-gba-camera-viewport-proof.md`](../tasks/phase2-gba-camera-viewport-proof.md)
- Machine state: [`STATE.json`](STATE.json)

## Summary

Phase 3 remains canonically `DONE` after its independently reviewed continuous
runtime replay. The Phase 2 camera bridge prerequisite is now also complete:
route revision `27867add` received independent `PASS`, and the trusted one-file
probe succeeded as Local Worker Bridge run `34735602055` at `518c1ca6`.

The sole active Worker package is now the true 240×160 overworld camera viewport
proof. It must turn the existing inline crop into tested, deterministic camera
geometry and prove normal runtime behavior; it may not change world simulation,
outer window scaling, Oak presentation, or reference-parity scope.

## Active Worker package

Execute only `work/tasks/phase2-gba-camera-viewport-proof.md`.

Required result:

```text
normal live overworld
→ logical 240×160 viewport
→ continuous live-player camera follow
→ deterministic edge/small-map clamp
→ map/player/NPC/overlay alignment
→ existing outer letterbox/scaling unchanged
```

Require focused geometry and integration/runtime evidence, full no-ROM and
verified-ROM suites, and independent review before changing any parent status.

## Boundaries

May change only the camera module/integration, focused test and optional runtime
probe, plus task/coordination/review documentation. Must not change movement,
collision, story, battle, save, world simulation, `ViewportScale` semantics,
Oak/title presentation, ROM policy, or prohibited content.

## Next after independent PASS

Reconcile the camera leaf, then scope the remaining Oak/reference screenshot
parity task from trustworthy external reference evidence. Do not mark Phase 2
`DONE` before that second leaf is independently reviewed.

## Goal-continuity commitment

The coordinator continues autonomously through:

```text
camera implementation → evidence/review → reconciliation → Oak/reference parity scope
```

Only a genuine authority/safety boundary, failed required evidence gate, or missing
external retail-reference input may interrupt this chain. Record the first exact
blocker; do not substitute a smaller goal or wait for routine approval.
