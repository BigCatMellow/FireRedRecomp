# FireRedRecomp Coordination Handoff

- Record role: `HANDOFF`
- Primary information class: `TASK CONTEXT`
- Status: `READY_FOR_WORKER`
- Lifecycle: `ACTIVE`
- Authority: coordination state only; root `AGENTS.md` and active task contracts own authority
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Completed Phase 2 leaf: [`../tasks/phase2-gba-camera-viewport-proof.md`](../tasks/phase2-gba-camera-viewport-proof.md)
- Active Worker package: [`../tasks/phase2-oak-reference-evidence-harness.md`](../tasks/phase2-oak-reference-evidence-harness.md)
- Machine state: [`STATE.json`](STATE.json)

## Summary

Phase 2 remains `IN PROGRESS`. The true 240×160 camera viewport is already
independently reviewed at `4c5456f3`; the only current critical-path work is the
Oak/reference visual-evidence harness and later external comparison.

The first guarded harness attempt did **not** publish implementation. Local Worker
Bridge run `34754826666` successfully selected the explicit route, verified the
private FireRed US v1.0 ROM SHA, applied the bounded v1 patch, and passed the
focused harness test plus the complete no-ROM and verified-ROM suites. Publication
was correctly withheld when the route-specific runtime capture failed.

The runtime evidence isolates a small contract error in the unpublished patch:
Oak capture printed
`PHASE2_CAPTURE_SURFACE PASS anchor=oak-static dimensions=240x160` and exited with
status `0`, but the proposed shell harness accepted only status `1`, then reported
`error: oak-static capture failed (exit 0)`. There is no evidence of an Oak,
camera, or gameplay defect.

## Active Worker package

Continue only `work/tasks/phase2-oak-reference-evidence-harness.md`, now narrowed
to the observed runtime correction:

1. Correct the capture script's supported-runner exit-status handling so the
   evidenced successful status `0` is accepted.
2. Preserve the required PASS marker, screenshot existence, exact 240×160
   dimension checks, external `/tmp` isolation, ROM SHA verification, and all
   existing route/security gates.
3. Update the focused contract assertion only if needed for that exact correction.
4. Submit a new bounded patch through the existing
   `phase2-oak-reference-evidence-harness` bridge route and rerun all required
   focused, no-ROM, verified-ROM, and runtime evidence.
5. Do not change Oak visuals, camera behavior, gameplay, output/content policy,
   outer scaling, bridge security policy, or supported-ROM policy.

The v1 patch is unpublished and therefore is not a reviewed implementation
revision. Do not create a Reviewer handoff until the guarded route publishes an
exact revision successfully.

## After successful guarded publication

Route the exact published harness revision to an independent Reviewer. A Reviewer
PASS closes only the evidence-harness leaf. It does **not** establish retail Oak
parity and does not make Phase 2 `DONE`.

After that PASS, Orchestrator should scope the smallest external comparison leaf
using the text-only protocol and user-owned/trusted retail-reference input. If no
such reference is available, record that exact external-input blocker rather than
fabricating a parity claim.

## Goal-continuity commitment

The coordinator continues through:

```text
bounded exit-status correction → guarded publication → independent review
→ external retail-reference comparison scope
```

Only a genuine authority/safety boundary, failed required evidence gate, or missing
external retail reference may interrupt that chain.
