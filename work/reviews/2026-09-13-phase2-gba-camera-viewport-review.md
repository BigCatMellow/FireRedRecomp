# Independent review: Phase 2 GBA camera viewport

- Date: 2026-09-13
- Role: REVIEWER
- Task: `work/tasks/phase2-gba-camera-viewport-proof.md`
- Published implementation revision: `4c5456f3`
- Reviewed implementation: `ab8bdc718c097092caad92dedc92b377c18c1ef6`
- Verdict: `PASS`

## Findings

1. **Geometry — PASS.** `CameraViewport` fixes the field viewport at 240×160,
   covers follow/clamp/small-map behavior, and retains sub-tile camera motion.
2. **Integration — PASS.** Normal map, NPC, and player draws share the same
   transform; the field-only scissor prevents off-camera sprites from leaking.
3. **Runtime — PASS.** A live Route 1 replay drives normal PlayerMovement and
   reports a moving camera with stable world state.
4. **Regression — PASS.** Focused geometry/integration tests, the 125-file
   no-ROM and verified-ROM suites, and guarded run `34753297372` all passed.
5. **Scope — PASS.** No movement, collision, story, battle, save, `ViewportScale`,
   title/Oak scene, asset-policy, or external-content behavior changed.

## Verdict

`PASS`

The camera leaf is complete. This review does not certify Oak/reference screenshot
parity or all of Phase 2.
