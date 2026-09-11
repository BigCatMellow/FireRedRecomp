# Task: prove title/new-game entry through Oak intro into bedroom

- Status: `CLOSED — REVIEWED PASS`
- AGI status: `AGI READY`
- Type: `EVIDENCE / BOUNDED INTEGRATION`
- Owner: project maintainer
- Risk: `MEDIUM`
- Parent gate: `work/tasks/phase3-exit-proof.md`
- Reviewed implementation: `8bdbda903fb0574cb169968976d4b40ce96d3563`
- Independent review: `work/reviews/2026-09-11-phase3-title-oak-entry-review.md`

## Goal

Close the smallest remaining unproven Phase 3 entry boundary by producing repeatable runtime evidence for:

```text
boot
→ title screen / new-game entry
→ Oak intro / identity flow
→ fresh session initialization
→ Player's House 2F bedroom
```

This task proves reachability and state continuity across the existing pieces. It does not require visual completion of every Phase 2 Oak-intro animation.

## Result

Independent Reviewer returned `PASS` for exact implementation revision `8bdbda903fb0574cb169968976d4b40ce96d3563`.

Verified result:

- normal title `A` or `START` enters the existing Oak scene;
- Oak `A` continues through the existing identity/new-game flow;
- the replay starts at the title runtime view and does not construct a post-Oak `GameSession` fixture;
- identity continuity reaches a fresh Player's House 2F session at map group 4 / map 1, coordinate 6,6;
- player `RED`, rival `GREEN`, gender 0, party count 0, starting money 3000, empty bag, one PC Potion, and zeroed Dex state were asserted;
- focused test passed;
- all 122 no-ROM test files passed;
- all 122 verified-ROM test files passed;
- `phase3_exit_path_rom_test` passed 12/12;
- the verified-ROM runtime replay passed under FireRed US v1.0 SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`.

Runtime marker:

```text
RUNTIME_REPLAY title_oak_entry PASS title=true oak=true identity=true map=1025 pos=6,6 party=0 money=3000 bagEmpty=true pcPotion=true dexZero=true names=RED/GREEN gender=0
```

## Source of truth

- `docs/roadmap.md` Phase 3 exit path.
- `work/tasks/phase3-exit-proof.md` parent acceptance.
- `docs/handoffs/firered-recomp-checklist.md` for existing title, Oak intro, naming, fresh-save bootstrap, and runtime evidence.
- Verified FireRed US v1.0 ROM SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc` when retail/source evidence is required.
- `work/reviews/2026-09-11-phase3-title-oak-entry-review.md` for the independent verdict.

## Boundaries observed

The reviewed revision changed only:

- `main.lua`;
- `tests/phase3_title_oak_entry_test.lua`;
- `scripts/runtime_title_oak_entry_replay.sh`.

No Phase 2 visual-parity completion, generic scene-stack architecture, script-interpreter expansion, trainer-battle work, Mart/Parcel/Dex behavior, save-layout expansion, supported-ROM policy change, ROM/cache/BIOS, or extracted content was introduced.

## Completion / handoff

This leaf is closed. It does **not** by itself close `work/tasks/phase3-exit-proof.md` or change canonical Phase 3 status.

The parent still requires its complete-path acceptance to be reconciled. The next bounded package is `work/tasks/phase3-complete-runtime-exit-replay.md`, whose purpose is to prove the already-evidenced seams compose into one complete automated boot → title/Oak → bedroom/Pallet → Route 1 battle → save → fresh-process reload run.
