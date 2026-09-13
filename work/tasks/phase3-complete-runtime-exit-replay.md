# Task: prove the complete Phase 3 runtime exit path end to end

- Status: `ACTIVE`
- AGI status: `AGI READY`
- Type: `EVIDENCE / BOUNDED INTEGRATION`
- Owner: project maintainer
- Risk: `MEDIUM`
- Parent gate: `work/tasks/phase3-exit-proof.md`

## Goal

Close the final parent-proof gap by producing one deterministic automated runtime artifact for the complete Phase 3 path:

```text
normal boot
→ title / new game
→ Oak intro / identity
→ Player's House 2F bedroom
→ Pallet Town
→ Route 1
→ first wild battle
→ catch or defeat
→ save
→ fresh-process reload
```

The individual seams are already implemented and substantially evidenced. This task is primarily an evidence-integration task: prove that the already-passed pieces compose continuously without synthetic state injection or hidden fixture jumps.

## Source of truth

- `docs/roadmap.md` Phase 3 exit criterion.
- `work/tasks/phase3-exit-proof.md` parent acceptance.
- `work/reviews/2026-09-11-phase3-title-oak-entry-review.md` for the independently passed title/Oak/identity/bedroom leaf at `8bdbda903fb0574cb169968976d4b40ce96d3563`.
- Existing runtime replay artifacts for bedroom/Pallet, Route 1 battle, save/restart, and natural capture.
- Verified FireRed US v1.0 ROM SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`.
- Live code/tests on current `main`; older prose cannot override direct evidence.

## Established prerequisites — do not rebuild

- normal title `A`/`START` → existing Oak scene;
- Oak `A` → existing identity/new-game flow;
- fresh-session Player's House 2F initialization;
- Player's House 2F → 1F → Pallet runtime movement/warps;
- Route 1 encounter and wild battle runtime paths;
- capture/defeat outcome evidence;
- normal save callback and fresh-process load evidence;
- Viridian Parcel/Dex/capture progression and presentation evidence.

## MAY CHANGE

Only the smallest evidence/support surface required to run the already-proven pieces continuously, expected to be drawn from:

- `scripts/` runtime replay support;
- focused `tests/` assertions for the complete replay;
- `main.lua` replay-driver plumbing only if needed to connect already-existing runtime input stages without changing game behavior;
- this task, parent task, review/evidence, and coordination documentation.

A gameplay behavior change is **not** authorized by this evidence package. If the continuous replay exposes a real gameplay defect, stop and report the exact first failing seam so Orchestrator can decide whether a new bounded implementation task is required.

## MUST NOT CHANGE

- normal gameplay behavior merely to make the replay easier;
- Phase 2 camera/Oak visual-parity work;
- general script interpreter or scene-stack architecture;
- Phase 4 trainer-battle/move-effect work;
- Mart/Parcel/Dex behavior already independently passed;
- save format/layout, sectors, or supported-ROM policy;
- ROM, BIOS, generated cache, screenshots/assets extracted from the game, or other prohibited content in git.

## Acceptance criteria

1. One deterministic automated runtime command starts from normal application boot and drives the complete Phase 3 path through fresh-process reload without directly constructing a post-Oak/post-battle/post-save fixture.
2. The artifact uses normal runtime input/event seams for title/Oak/identity, movement, battle, save, and reload; deterministic RNG/input timing is allowed.
3. The replay verifies continuity across the path, including at minimum identity, bedroom/Pallet/Route 1 location progression, party/Dex outcome, relevant bag change when using the capture branch or HP/money outcome when using the defeat branch, and post-reload persistence.
4. The save/reload leg uses an isolated temporary XDG/save sandbox and proves the save file is produced by the normal runtime save path before a fresh process loads it.
5. Focused evidence passes; `bash scripts/test_all.sh` passes; and with the verified ROM, `POKEPORT_ROM=/path/to/pokefirered.gba bash scripts/test_all.sh` passes.
6. The exact evidence/implementation revision receives independent Reviewer verification before the parent Phase 3 gate or canonical capability status changes.

## Deterministic evidence plan

1. Reuse the passed `runtime_title_oak_entry` path as the beginning of the run rather than recreating title/Oak state.
2. Continue from its fresh Player's House session through the existing movement/warp and Route 1 battle runtime seams.
3. Prefer the already-proven defeat + save/restart branch if it yields the smallest continuous artifact; use capture only if simpler without widening scope.
4. Save through the normal runtime callback into a fresh temporary sandbox.
5. Start a second LÖVE process against that sandbox and load through the normal runtime load path.
6. Emit one unambiguous PASS marker containing the key continuity assertions.

## Stop / escalate

Return `BLOCKED` with the first exact failing seam rather than changing gameplay if continuous execution reveals a defect that is not merely replay-driver plumbing. In particular, stop if closure would require:

- new gameplay/story behavior;
- Phase 2 visual/camera parity work;
- a general script opcode or trainer-battle capability;
- a menu redesign;
- save-layout/sector expansion;
- unsupported-ROM behavior or copyrighted-content distribution.

## Completion / handoff

Completion means the complete Phase 3 exit path has one reproducible automated runtime artifact, required suites pass, and an independent Reviewer returns `PASS` on the exact revision. Orchestrator must then reconcile `work/tasks/phase3-exit-proof.md` and only then decide whether the canonical Phase 3 capability can advance to `DONE`.
