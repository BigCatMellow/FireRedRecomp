# Independent review: Phase 3 title → Oak entry proof

- Date: 2026-09-11
- Role: REVIEWER
- Task: `work/tasks/phase3-title-oak-entry-proof.md`
- Exact implementation revision: `8bdbda903fb0574cb169968976d4b40ce96d3563`
- Verdict: `PASS`

## Scope checked

Reviewed only the existing task acceptance, stop conditions, repository invariants, exact implementation diff, and recorded deterministic evidence. No Phase 3 parent-gate completion judgment is made here.

## Material findings

1. **Bounded implementation surface — PASS.** Exact revision changes only `main.lua`, `tests/phase3_title_oak_entry_test.lua`, and `scripts/runtime_title_oak_entry_replay.sh`, all explicitly allowed by the active task.
2. **Normal title input seam — PASS.** `A` or `START` while the title view is active clears the title view and activates the already-existing Oak scene. Oak still owns the normal `A` continuation into the existing identity flow; no generic scene architecture was introduced.
3. **No post-Oak fixture injection — PASS.** The route-specific replay starts at the title view, drives title/Oak/identity using the runtime input seam, and does not call `GameSession.fromNewGame` directly.
4. **Identity/state continuity — PASS.** The replay verifies player gender/name, rival name, fresh-session map and coordinates, party count, starting money, empty bag, PC Potion, and zeroed Dex state at Player's House 2F.
5. **Required deterministic evidence — PASS.** Local Worker Bridge run `34604493910` completed successfully on `firered-mint` after verifying FireRed US v1.0 SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`. The focused test passed; the no-ROM suite passed all 122 test files; the verified-ROM suite passed all 122 test files; `phase3_exit_path_rom_test` passed 12/12; and the route replay emitted:

   `RUNTIME_REPLAY title_oak_entry PASS title=true oak=true identity=true map=1025 pos=6,6 party=0 money=3000 bagEmpty=true pcPotion=true dexZero=true names=RED/GREEN gender=0`

6. **Regression / widening check — PASS.** No unrelated runtime subsystem, Phase 2 visual-parity work, battle logic, Mart/Parcel/Dex behavior, save layout, ROM policy, or prohibited content was changed.

## Verdict

`PASS`

The bounded title/new-game → Oak/identity → fresh-bedroom leaf satisfies its existing acceptance criteria at exact revision `8bdbda903fb0574cb169968976d4b40ce96d3563`.

## Exact next allowance

Orchestrator may treat only this leaf as independently passed and must re-evaluate the complete `work/tasks/phase3-exit-proof.md` acceptance against accumulated evidence before changing canonical Phase 3 status. This review does **not** declare Phase 3 complete.
