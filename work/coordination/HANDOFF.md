# FireRedRecomp Coordination Handoff

- Record role: `HANDOFF`
- Primary information class: `TASK CONTEXT`
- Status: `READY_FOR_WORKER`
- Lifecycle: `ACTIVE`
- Authority: coordination state only; root `AGENTS.md` and active task contracts own authority
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Completed prerequisite: [`../tasks/local-worker-bridge-phase2-camera-route.md`](../tasks/local-worker-bridge-phase2-camera-route.md)
- Active route correction: [`../tasks/local-worker-bridge-phase2-camera-optional-staging-fix.md`](../tasks/local-worker-bridge-phase2-camera-optional-staging-fix.md)
- Machine state: [`STATE.json`](STATE.json)

## Summary

Phase 3 remains canonically `DONE` after its independently reviewed continuous
runtime replay. The Phase 2 camera bridge prerequisite is complete: route
revision `27867add` received independent `PASS`, and the trusted one-file probe
succeeded as Local Worker Bridge run `34735602055` at `518c1ca6`.

A stale task-header inconsistency was corrected this turn: the camera task still
said `BLOCKED ON BRIDGE ROUTE` even though that prerequisite had already passed.
The task now explicitly says `READY FOR WORKER`; its implementation scope,
acceptance criteria, and safety boundaries are unchanged.

The camera implementation at `ab8bdc71` passed independent local review, focused
tests, both 125-file suites, and a ROM-backed Route 1 replay. Guarded run
`34753075794` then repeated all target, focused, full-suite, verified-ROM, and
runtime gates successfully, but failed only in final staging because an absent
optional review document shares one `git add` invocation with required files.
The active correction stages only the existing exact allowlist entries that exist;
it adds no path and changes no evidence gate.

## Active Worker package

Execute only `work/tasks/local-worker-bridge-phase2-camera-optional-staging-fix.md`.

Required result:

```text
exact existing staging list
→ stage each listed present file
→ absent optional review doc does not suppress required files
→ all prior bridge guardrails unchanged
```

Require static/no-ROM evidence and independent review. Then submit the unchanged
`ab8bdc71` camera package through the corrected route for guarded focused/full/
verified-ROM/runtime evidence.

## Boundaries

May change only the bridge workflow/procedure and task/coordination/review
documentation. Must not change camera/gameplay implementation or tests, movement,
collision, story, battle, save, world simulation, `ViewportScale` semantics,
Oak/title presentation, ROM policy, or prohibited content.

## Next after independent PASS

Publish and reconcile the camera leaf, then scope the remaining Oak/reference
screenshot parity task from trustworthy external reference evidence. Do not mark
Phase 2 `DONE` before that second leaf is independently reviewed.

## Goal-continuity commitment

The coordinator continues autonomously through:

```text
camera implementation → evidence/review → reconciliation → Oak/reference parity scope
```

Only a genuine authority/safety boundary, failed required evidence gate, or missing
external retail-reference input may interrupt this chain. Record the first exact
blocker; do not substitute a smaller goal or wait for routine approval.
