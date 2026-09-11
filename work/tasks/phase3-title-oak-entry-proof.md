# Task: prove title/new-game entry through Oak intro into bedroom

- Status: `ACTIVE`
- AGI status: `AGI READY`
- Type: `EVIDENCE / BOUNDED INTEGRATION`
- Owner: project maintainer
- Risk: `MEDIUM`
- Parent gate: `work/tasks/phase3-exit-proof.md`

## Goal

Close the smallest remaining unproven Phase 3 entry boundary by producing
repeatable runtime evidence for:

```text
boot
→ title screen / new-game entry
→ Oak intro / identity flow
→ fresh session initialization
→ Player's House 2F bedroom
```

This task proves reachability and state continuity across the existing pieces.
It does not require visual completion of every Phase 2 Oak-intro animation.

## Source of truth

- `docs/roadmap.md` Phase 3 exit path.
- `work/tasks/phase3-exit-proof.md` parent acceptance.
- `docs/handoffs/firered-recomp-checklist.md` for existing title, Oak intro,
  naming, fresh-save bootstrap, and runtime evidence.
- Verified FireRed US v1.0 ROM SHA-1
  `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc` when retail/source evidence is
  required.
- Existing runtime behavior and tests on current `main` are evidence; older
  handoff prose is not allowed to override live code/test results.

## Established prerequisites

Already implemented/evidenced and therefore not to be rebuilt here:

- FireRed title-screen rendering and runtime view support;
- static Oak speech scene rendering;
- gender/player/rival naming flow and `NewGameFlow`;
- fresh-save bootstrap/session initialization;
- Player's House 2F → 1F → Pallet runtime movement/warp replay;
- downstream Phase 3 Route 1 battle/capture/save/reload evidence;
- canonical Viridian Parcel/Dex/capture persistence evidence.

The parent Phase 3 proof still records the preceding Oak/title entry as open.
This task exists to determine and close that exact integration/evidence gap.

## MAY CHANGE

Only the smallest files needed to prove this boundary, expected to be drawn
from:

- focused Phase 3 entry replay/test support under `tests/` and/or `scripts/`;
- `main.lua` only if a narrow existing runtime seam must be exposed or wired;
- existing title/new-game/Oak/fresh-session core modules only if direct
  evidence shows a bounded integration defect in this path;
- this task, parent task, review/evidence, and coordination documentation.

Any concrete implementation file beyond these categories must be justified by
an observed failing boundary before modification.

## MUST NOT CHANGE

- Phase 2 visual-parity scope such as Nidoran/platform/fade/shrink completion,
  true hardware screenshot parity, or camera parity;
- general script-interpreter expansion;
- generic trainer battle logic or Phase 4 move/effect work;
- Mart/Parcel/Dex presenter behavior already independently passed;
- save format/layout expansion, PC sectors, or release engineering;
- supported-ROM policy;
- ROM, cache, BIOS, or extracted asset/content tracked in git.

## Acceptance criteria

1. A deterministic automated or scripted runtime replay starts from normal
   application boot and reaches the normal new-game/title entry path without
   directly constructing a post-Oak session fixture.
2. The replay advances the existing Oak/new-game identity flow using normal
   runtime input/event seams and reaches a freshly initialized session in the
   Player's House 2F bedroom.
3. Evidence verifies at minimum player identity/gender/name, rival name,
   initial location/map/coordinates, initial party/bag/money/Dex-relevant
   state expected at that boundary, and that no synthetic state injection was
   used to skip the entry flow.
4. The replay hands off cleanly to the already-proven bedroom → Pallet runtime
   path, or the same artifact continues through that boundary if doing so is
   simpler without widening scope.
5. Focused tests pass; `bash scripts/test_all.sh` passes; with the verified ROM,
   `POKEPORT_ROM=/path/to/pokefirered.gba bash scripts/test_all.sh` passes.
6. Independent Reviewer verifies the exact revision and evidence before this
   leaf is treated as closed.

## Deterministic evidence plan

Worker should first characterize current `main` rather than assume a missing
feature:

1. identify the normal boot/title/new-game input path and the current Oak /
   naming / fresh-session transition;
2. try to drive it through the same fixed-tick/runtime input mechanisms used
   by existing replays;
3. if it already works, add the smallest replay/assertion artifact needed to
   prove it and avoid gameplay changes;
4. if it fails, record the first exact missing seam, make only the narrow
   integration correction needed for this task, and prove the corrected path;
5. preserve downstream Phase 3 evidence and run the required suites.

Prefer evidence-only characterization over implementation when current runtime
behavior already satisfies the parent gate.

## Stop / escalate

Stop and return `BLOCKED` rather than widening scope if closing this boundary
requires any of the following:

- completing the Phase 2 Nidoran/platform/fade/shrink Oak animation sequence;
- a new general scene-stack architecture;
- a missing general script opcode or trainer-battle capability;
- a menu redesign;
- a save-layout/sector feature;
- unsupported-ROM behavior or distribution of copyrighted content;
- any product/scope decision not already implied by the Phase 3 exit path.

If the only remaining discrepancy is visual/reference parity rather than
functional Phase 3 reachability, record that separately under Phase 2 and do
not turn it into a Phase 3 blocker without direct roadmap evidence.

## Completion / handoff

Completion means the title/new-game → Oak/identity → bedroom boundary has an
exact reproducible evidence artifact and independent `PASS`. It closes only
this Phase 3 entry leaf. Orchestrator must then re-evaluate the full
`phase3-exit-proof.md` acceptance before changing canonical Phase 3 status.
