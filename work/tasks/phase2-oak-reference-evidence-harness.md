# Task: establish Phase 2 Oak/reference visual-evidence capture

- Status: `CLOSED — REVIEWED PASS`
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

## Resolved runtime correction gate

Guarded Local Worker Bridge run `34754826666` applied the bounded v1 patch and
passed target validation, the focused harness test, the complete no-ROM suite,
and the complete verified-ROM suite. Publication was correctly withheld because
the route-specific runtime capture failed.

The failure is narrow and directly evidenced: the Oak capture emitted
`PHASE2_CAPTURE_SURFACE PASS anchor=oak-static dimensions=240x160` and the LÖVE
process returned status `0`, but the proposed capture script treated anything
other than status `1` as failure and reported `error: oak-static capture failed
(exit 0)`.

The corrected v3 request accepted only the two demonstrated LÖVE exit conventions
(`0` or `1`) while retaining the exact marker and fresh-image requirements. Guarded
run `34767029627` then passed focused, no-ROM, verified-ROM, runtime capture, and
publication at `0017727c`. Independent review passed that exact published revision.

## Capture and external-reference protocol

Run the checked-in implementation harness only with the verified ROM, retaining
its printed external output directory outside this repository:

```bash
POKEPORT_ROM=/path/to/FireRed-US-v1.0.gba \
  bash scripts/phase2_oak_reference_evidence_capture.sh
```

It emits two `240x160` PNGs for `oak-static` and two for
`pallet-camera-anchor`, verifies each pair with `tools/pixeldiff/`, and prints
the output directory and image SHA-1 values. These are implementation captures,
not retail-reference artifacts; do not add them to git.

The next comparison leaf must create a text-only report using this schema:

```text
status: NO_REFERENCE_INPUT | COMPARED | DISCREPANCY_RECORDED
implementation_revision: <full git revision>
implementation_rom_sha1: 41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc
implementation_command: <exact harness command>
anchor: oak-static | pallet-camera-anchor
implementation_dimensions: 240x160
implementation_capture_sha1: <SHA-1>
repeat_self_diff: IDENTICAL | DIFFERENT
reference_provenance: <user-owned retail/emulator source, or ABSENT>
reference_rom_revision: <known revision, or UNKNOWN>
reference_emulator_and_version: <value, or UNKNOWN>
reference_frame_or_timing: <value, or UNKNOWN>
reference_crop: <exact 240x160 crop coordinates, or UNKNOWN>
reference_scaling_and_filter: <nearest/integer settings, or UNKNOWN>
comparison_command: <exact external command, or NOT_RUN>
discrepancy_summary: <measured result, or NOT_RUN — no trusted reference input>
parity_claim: YES | NO
```

`NO_REFERENCE_INPUT`, `UNKNOWN`, or a self-diff is never parity evidence. A
trusted, user-owned external retail capture is required for a future
`parity_claim: YES`; keep that media and any emulator output outside git.

## Stop / escalate

Stop if exact virtual capture requires a renderer rewrite, gameplay/Oak/camera
change, committing reference media, or a generic screenshot subsystem. If no
trusted external retail reference is available after the harness is complete,
record that as the next leaf's external-input blocker; do not fabricate parity.

## Completion / handoff

The next task is `phase2-oak-reference-comparison.md`, using this protocol and
user-owned external reference input. That task, not this harness, determines
whether Oak/reference parity can advance.
