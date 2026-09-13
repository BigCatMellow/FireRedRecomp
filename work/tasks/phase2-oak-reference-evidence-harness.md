# Task: establish Phase 2 Oak/reference visual-evidence capture

- Status: `ACTIVE`
- AGI status: `AGI READY`
- Type: `PHASE 2 / EVIDENCE INFRASTRUCTURE / BOUNDED INTEGRATION`
- Owner: project maintainer
- Risk: `MEDIUM`
- Parent gate: Phase 2 camera + Oak/reference parity

## Goal

Make the remaining Phase 2 visual-parity gate measurable without committing
copyrighted reference images. Add deterministic, exact 240×160 implementation-side
capture/report support for the static Oak intro frame and one camera-clipped Pallet
anchor, then define the precise external-retail reference protocol and discrepancy
report inputs for the subsequent comparison leaf.

This task does not claim reference parity, change Oak art/choreography, or change
camera/gameplay behavior.

## Source of truth

- `docs/roadmap.md`, Phase 2 early visual target and screenshot-comparison exit
  criterion.
- `work/roadmaps/CAPABILITY_CHECKLIST.md`, remaining Oak/reference gate.
- `import/OakSpeechScene.lua`, published `CameraViewport`, existing screenshot
  support, and `tools/pixeldiff/`.
- Verified FireRed US v1.0 SHA-1
  `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`.

## MAY CHANGE

- a focused visual-evidence module or capture/report script under `scripts/`;
- focused tests under `tests/` and `tools/pixeldiff/` only if required;
- `main.lua` screenshot/capture plumbing only to export the existing virtual
  240×160 scene surface deterministically;
- this task and coordination/review documentation.

## MUST NOT CHANGE

- Oak scene visuals, timing, dialogue, title behavior, camera geometry, map/world
  simulation, movement, save/battle systems, or outer `ViewportScale` semantics;
- reference assets, ROM/BIOS/extracted content, generated screenshots/PNGs, or
  external emulator material in git;
- broader Phase 8 presentation work or Phase 2 completion status.

## Acceptance criteria

1. Commands produce exact 240×160 implementation captures for static Oak and a
   deterministic Pallet camera anchor into an external temporary directory, free
   of host window chrome/scale.
2. Repeated captures of each anchor compare identically with the existing
   pixel-diff tool.
3. Checked-in text-only report schema/protocol records implementation revision,
   ROM SHA verification, command, dimensions, external reference provenance,
   frame/timing/crop/filter settings, and discrepancy summary; it records absent
   reference input honestly rather than treating self-diff as parity.
4. Focused tests, no-ROM and verified-ROM suites pass; runtime capture support is
   proved against the verified ROM when changed.
5. Independent Reviewer verifies the exact implementation before this evidence
   leaf closes. Phase 2 remains `IN PROGRESS` pending a real external comparison.

## Stop / escalate

Stop if exact virtual capture requires a renderer rewrite, gameplay/Oak/camera
change, committing reference media, or a generic screenshot subsystem. If no
trusted external retail reference is available after the harness is complete,
record that as the next leaf's external-input blocker; do not fabricate parity.

## Completion / handoff

After independent PASS, Orchestrator dispatches the smallest reference-comparison
task using the produced protocol and user-owned external reference input. That task,
not this harness, determines whether Oak/reference parity can advance.
