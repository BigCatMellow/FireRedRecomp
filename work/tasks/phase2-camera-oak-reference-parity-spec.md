# Task: specify and prove the Phase 2 camera/Oak reference-parity gate

- Status: `READY FOR REVIEWER — EXTERNAL REFERENCE CORPUS BLOCKED`
- AGI status: `AGI READY`
- Type: `EVIDENCE HARNESS / BOUNDED RENDERING SUPPORT`
- Owner: project maintainer
- Risk: `MEDIUM`
- Canonical gate: Phase 2 in `work/roadmaps/CAPABILITY_CHECKLIST.md`

## Goal

Create a deterministic, fail-closed comparison harness and contract for the
three Phase 2 reference cases below. This task makes the visual-parity gate
measurable; it does **not** claim Phase 2 is visually complete.

1. Static Oak-intro frame at exactly 240×160.
2. Player-centred Pallet Town walk-camera frame at exactly 240×160.
3. Edge-clamped walk-camera frame at exactly 240×160.

## Source of truth and established prerequisites

- `docs/roadmap.md` Phase 2 early visual target and exit criterion.
- `work/roadmaps/CAPABILITY_CHECKLIST.md` Phase 2 exit gate.
- `main.lua`: existing `POKEPORT_OAKSCENE`, `POKEPORT_WALK`,
  `POKEPORT_WALK_MOVES`, and `POKEPORT_SCREENSHOT` deterministic capture
  seams; the live 240×160 walk crop and scissor behavior are the subject.
- `tests/oak_speech_scene_test.lua`: existing ROM-decoded Oak structural
  assertions.
- `tools/pixeldiff/main.lua`: existing PNG comparison tool.
- Verified private FireRed US v1.0 SHA-1:
  `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`.

## MAY CHANGE

- one task-local reference manifest/template and concise instructions;
- a focused pure camera-geometry test or narrowly extracted pure helper if
  that is necessary to assert the live crop math;
- a focused deterministic screenshot-capture/diff wrapper under `scripts/`
  or `tools/`, plus its tests;
- `tests/oak_speech_scene_test.lua` only for assertions directly needed to
  lock the named static Oak capture;
- task/evidence/coordination documentation.

## MUST NOT CHANGE

- normal game behavior, game content, camera policy, map movement, scene
  flow, save layout, supported-ROM policy, or Phase 3 proof;
- rendering implementation merely to lower a diff score;
- Phase 4+ systems, importer data, gameplay scripts, or visual assets;
- ROMs, BIOS, emulator images, extracted game assets, reference PNGs, or
  other copyrighted/prohibited content in git;
- phase/capability status. Only independent review of a later parity result
  can advance Phase 2.

## Required reference contract

The harness must require externally supplied, untracked reference PNGs and a
provenance manifest. For every named case the manifest must record:

- supported-ROM SHA-1, emulator name/version, capture dimensions, and PNG
  SHA-256;
- exact boot/save state and deterministic input sequence/capture point;
- project capture environment/command and the pixel-diff threshold used;
- a stable local path or explicit command-line mapping, without embedding a
  machine-specific private path in tracked files.

References must be 240×160. Missing, malformed, wrong-size, or checksum-
mismatched references must make the wrapper fail before a parity result is
reported. The tracked template may contain no reference image or copyrighted
pixel data.

## Acceptance criteria

1. A single documented command captures all three deterministic project cases
   and compares each against an externally supplied reference mapping with
   `tools/pixeldiff/main.lua` (or a tested equivalent that preserves its
   dimension and discrepancy semantics).
2. Focused assertions prove the camera crop is 240×160, player-centred where
   map bounds allow, edge-clamped where they do not, and uses the same crop
   coordinates for map and object drawing/scissoring. Do not rely only on a
   screenshot existing.
3. The wrapper emits machine-readable per-case result data including capture
   size, reference SHA-256, differing-pixel count/percent, max and mean
   channel delta, threshold, and PASS/FAIL/BLOCKED reason.
4. The wrapper fails closed before comparison for absent/invalid provenance or
   reference files; deterministic tests prove those negative paths.
5. `lua5.1 tests/oak_speech_scene_test.lua`, all new focused tests,
   `env -u POKEPORT_ROM bash scripts/test_all.sh`, and the verified-ROM full
   suite pass. With compliant external references supplied, the wrapper must
   run its three comparisons deterministically; a visual mismatch is evidence
   for a separately scoped correction, not permission to change rendering.
6. Worker records exact commands and actual results without calling a missing
   corpus a PASS. Independent Reviewer must verify the implementation/evidence
   revision before the task can close.

## Deterministic evidence plan

1. Pin the three case IDs, project environment variables/input sequence, and
   expected 240×160 dimensions in a tracked template.
2. Capture project PNGs in an isolated temporary sandbox using the existing
   deterministic LÖVE capture seams; do not commit them.
3. Validate the supplied reference manifest and PNG SHA-256s, then invoke
   pixel diff for each case and write a structured result outside the repo.
4. Exercise valid synthetic metadata and every fail-closed validation branch
   in focused tests without requiring a private ROM or copyrighted PNG.
5. If compliant real references are available locally, run the verified-ROM
   command and report its result. Otherwise report exactly
   `BLOCKED: reference corpus unavailable` after the harness and non-ROM
   evidence are complete.

## Stop / escalate

Stop and report the first exact blocker instead of widening scope if:

- reference captures/provenance are unavailable or cannot be validated;
- a comparison exposes a rendering discrepancy requiring a behavior change;
- obtaining captures requires distributing ROM-derived content or changing
  supported-ROM policy;
- the current capture seam cannot produce a deterministic named case without
  changing normal gameplay or general scene architecture.

Do not fabricate an emulator reference, choose an unreviewed threshold to
declare parity, or mark Phase 2 complete. A rendering correction requires a
new bounded task after this package is independently reviewed.

## Completion / handoff

Worker supplies the exact implementation revision, changed-file list, focused
and suite results, real-reference result or the precise external-reference
blocker, and any first measured discrepancy. Reviewer independently verifies
the contract and returns `PASS`, `NEEDS_FIX`, or `BLOCK`. Orchestrator then
closes only this harness package and chooses the smallest measured rendering
correction, if any.

## Worker implementation and evidence — 2026-09-19

Implementation revision: `PENDING COMMIT` (bounded harness only).

- Added `src/core/CameraCrop.lua`; `main.lua` now uses this exact pure
  240×160 crop result for the map quad, while player/NPC coordinates and the
  scissor continue to use its `quadX`/`quadY` values. The opt-in
  `POKEPORT_CAPTURE_240=1` window mode makes LÖVE screenshots exactly
  240×160 without affecting normal desktop launch dimensions.
- Added `scripts/phase2_camera_oak_parity.sh`, which first preflights an
  explicitly mapped external reference corpus, then captures static Oak,
  Pallet edge-clamped, and asserted-centred Pallet cases in isolated XDG
  sandboxes and invokes the fail-closed checker.
- Added the untracked-reference manifest template at
  `work/reference-manifests/phase2-camera-oak-reference-parity.manifest.example`.
  It records the required ROM SHA-1, emulator/version, dimensions, per-case
  state/input/capture point, reference SHA-256, and declared diff thresholds.
- `tools/phase2_camera_oak_parity_check.lua` writes structured JSON with each
  requested size/checksum/diff statistic/threshold/status and rejects absent,
  malformed, checksum-mismatched, or non-240×160 external data before a
  comparison result.

Evidence reproduced by Worker:

- `lua5.1 tests/camera_crop_test.lua`: PASS (11 assertions).
- `lua5.1 tests/phase2_camera_oak_parity_harness_test.lua`: PASS (8
  assertions; valid synthetic comparison plus missing, malformed,
  checksum-mismatched, and wrong-sized rejection paths).
- `lua5.1 tests/oak_speech_scene_test.lua`: PASS with verified ROM (56
  assertions).
- `env -u POKEPORT_ROM bash scripts/test_all.sh`: PASS, 146 test files.
- `POKEPORT_ROM=<verified private ROM> bash scripts/test_all.sh`: PASS, 146
  test files; private ROM SHA-1 matched
  `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`.
- An isolated `POKEPORT_CAPTURE_240=1` live field capture decoded as exactly
  240×160; it is temporary and not retained in the repository.

`BLOCKED: reference corpus unavailable`. No untracked external emulator PNGs
plus complete provenance manifest are present, so no real comparison, parity
PASS, discrepancy, or Phase 2 advancement is claimed. Reviewer should inspect
the exact implementation revision and independently reproduce the focused and
suite evidence; once the corpus exists, run the documented wrapper and route
any mismatch as a new bounded rendering-correction task.
