# FireRedRecomp Coordination Handoff

- Record role: `HANDOFF`
- Primary information class: `TASK CONTEXT`
- Status: `READY_FOR_WORKER`
- Lifecycle: `ACTIVE`
- Authority: coordination state only; root `AGENTS.md` and active task contracts own authority
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Completed Phase 2 leaf: [`../tasks/phase2-gba-camera-viewport-proof.md`](../tasks/phase2-gba-camera-viewport-proof.md)
- Active prerequisite: [`../tasks/local-worker-bridge-phase2-oak-reference-evidence-route.md`](../tasks/local-worker-bridge-phase2-oak-reference-evidence-route.md)
- Machine state: [`STATE.json`](STATE.json)

## Summary

The true 240×160 camera viewport is complete and independently reviewed at
`4c5456f3`. Guarded Local Worker Bridge run `34753297372` passed target
validation, two focused tests, no-ROM and verified-ROM suites, the live Route 1
replay, and final publication. Phase 2 remains `IN PROGRESS` only for its
Oak/reference visual-parity gate.

The next bounded leaf is evidence infrastructure, not an unmeasured visual fix:
the Oak/reference harness must produce deterministic 240×160 implementation
captures and an honest external retail-reference protocol without committing
reference media or treating self-diff as parity.

## Active Worker package

Execute only `work/tasks/local-worker-bridge-phase2-oak-reference-evidence-route.md`.
It adds the harness's one explicit fail-closed route and probe only; it must not
modify capture, Oak, camera, or gameplay behavior.

## After independent PASS

Dispatch `work/tasks/phase2-oak-reference-evidence-harness.md` immediately.
After its evidence is independently reviewed, scope the external comparison leaf.
If a trusted external retail reference is unavailable at that stage, record it as
the precise external-input blocker rather than fabricating a parity claim.

## Goal-continuity commitment

The coordinator continues automatically through:

```text
Oak/reference bridge route → capture harness → review → external comparison scope
```

Only a genuine authority/safety boundary, failed required evidence gate, or missing
external retail reference may interrupt that chain.
