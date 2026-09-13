# Task: prove the true 240×160 GBA overworld camera viewport

- Status: `CLOSED — REVIEWED PASS`
- AGI status: `AGI READY`
- Type: `PHASE 2 / RENDERING / BOUNDED INTEGRATION`
- Owner: project maintainer
- Risk: `MEDIUM`
- Parent gate: Phase 2 — rendering, input, and scene runtime

## Goal

Close the earliest measurable Phase 2 gap by replacing full-map overworld presentation with a deterministic 240×160 camera-clipped view centered/following the live player, while preserving the existing world simulation and window scaling.

This task is about the **native GBA-sized gameplay viewport**, not broad visual polish. The window may still scale/letterbox through the already-passed `ViewportScale` layer; the rendered gameplay canvas itself must represent exactly one 240×160 GBA screen.

## Source of truth

- `docs/roadmap.md`, Phase 2: 240×160 virtual canvas and representative screenshot comparison.
- `docs/handoffs/firered-recomp-checklist.md`, Phase 2 open item: `True 240×160 GBA-screen viewport (camera-clipped to what a real GBA would show at once)`.
- `work/roadmaps/CAPABILITY_CHECKLIST.md`: Phase 2 remains `IN PROGRESS` specifically on camera/Oak-reference parity.
- Existing `src/core/ViewportScale.lua` and its tests own outer-window scaling; do not replace that responsibility.
- Existing `src/core/PlayerMovement.lua` owns live player pixel/tile motion.
- Existing map renderer/compositor and current `main.lua` overworld draw path are the implementation baseline.
- Verified FireRed US v1.0 ROM SHA-1: `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`.

## Prerequisites already satisfied — do not rebuild

- Player position and deterministic movement exist.
- Phase 3 proves normal boot → live overworld movement → battle → save/reload.
- Integer/arbitrary window scaling already exists and is independently exercised.
- Imported map composites and object/player rendering already exist.
- Pixel-diff comparison tooling already exists; true external-reference comparison remains a later acceptance item unless a trustworthy reference can be generated without committing copyrighted assets.
- The guarded Local Worker Bridge route for this task received independent `PASS` at `27867addb8a32cf4afdcff27a5d8e6c95b650333`, with trusted route probe run `34735602055` at `518c1ca6d682f6ebe07d9e5873823b0d83b1119c`.

## MAY CHANGE

Only the smallest camera/view support surface, expected to be drawn from:

- a new or existing focused camera/viewport module under `src/core/`;
- `main.lua` only where required to derive and apply the camera transform/clip during normal overworld rendering;
- focused camera/viewport tests under `tests/`;
- one deterministic runtime replay/probe under `scripts/` if needed to prove live movement and edge behavior;
- this task, review/evidence, and coordination documentation.

## MUST NOT CHANGE

- map collision, movement rules, story progression, battle behavior, save format, or world simulation;
- `ViewportScale` semantics for scaling/letterboxing the already-rendered virtual canvas unless direct evidence proves a camera integration defect there;
- Oak-intro artwork/choreography or Phase 8 presentation work;
- generic scene-stack architecture;
- supported-ROM policy;
- ROM, BIOS, generated cache, emulator screenshots, extracted game assets, or other copyrighted content in git.

## Required behavior

1. Normal overworld gameplay renders through a logical 240×160 viewport rather than exposing the entire composed map.
2. Camera position is derived from the live player position and updates continuously during the existing 16-frame tile walk, without changing movement state.
3. On maps larger than the viewport, the player remains within the intended screen-relative camera framing while the world scrolls behind them.
4. At map edges/small maps, the camera clamps deterministically and does not reveal out-of-map garbage or shift the outer window-scaling contract.
5. The player sprite, NPCs, map layers, and any currently supported overlays share the same camera transform so relative world alignment is preserved.
6. Existing title/menu/non-overworld views are not unintentionally camera-transformed.

## Acceptance criteria

1. A pure deterministic camera test pins viewport size to exactly `240×160` and covers center-follow, horizontal/vertical clamping, small-map behavior, and sub-tile player movement.
2. A focused integration test or replay demonstrates that moving the live player by one or more tiles changes camera/world screen coordinates continuously while world-space coordinates remain unchanged.
3. At least one ROM-backed normal-runtime proof renders/observes Pallet Town or another existing live map through the 240×160 viewport. Evidence may be numeric/runtime assertions; do not commit a ROM-derived screenshot.
4. `bash scripts/test_all.sh` passes.
5. With the verified ROM, `POKEPORT_ROM=/path/to/pokefirered.gba bash scripts/test_all.sh` passes.
6. Independent Reviewer verifies the exact implementation revision before Phase 2 status or the parent visual-parity gate advances.

## Deterministic evidence plan

Prefer a small pure module such as `CameraViewport` whose inputs are:

- map pixel width/height;
- player world pixel position;
- viewport width/height fixed at 240×160;

and whose outputs are camera origin and world→screen transform. Pin edge cases in plain Lua tests. Then exercise the same module from the normal overworld render path and, if required, a runtime replay that logs/asserts camera origin before, during, and after a real player step.

The Worker must characterize the current draw path before editing. If a suitable camera abstraction already exists under another name, reuse it rather than adding a duplicate.

## Stop / escalate

Return `BLOCKED` rather than widening scope if closure requires:

- changing gameplay or movement semantics;
- inventing undocumented FireRed camera behavior beyond the bounded viewport/clamp requirement;
- committing reference screenshots or ROM-derived assets;
- broad renderer/layer rewrites;
- Oak-intro/reference-image parity work beyond establishing the 240×160 camera prerequisite;
- unsupported-ROM behavior.

If exact retail camera anchoring/edge rules cannot be established from source or deterministic existing behavior, implement only source-supported geometry and mark the uncertain retail-parity detail `UNKNOWN` for a separate reference task.

## Completion / handoff

Completion means the live overworld uses a tested 240×160 camera-clipped viewport, focused and full suites pass including verified-ROM evidence, and an independent Reviewer returns `PASS` on the exact revision.

This task alone does **not** make Phase 2 `DONE`. After PASS, Orchestrator must re-evaluate the remaining Oak-intro/reference screenshot discrepancy gate and dispatch its smallest measurable leaf.

## Completion evidence

- Published implementation: `4c5456f3`.
- Independent review: `PASS`; see
  `work/reviews/2026-09-13-phase2-gba-camera-viewport-review.md`.
- Guarded Local Worker Bridge run `34753297372`: all target validation, two
  focused tests, no-ROM suite, verified-ROM suite, runtime replay, and final
  publication steps passed.
- Runtime evidence: Route 1 map `787`, viewport `240x160`, camera `208,264`,
  live movement/camera movement true, and world state stable.
