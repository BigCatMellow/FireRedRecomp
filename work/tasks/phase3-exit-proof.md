# Task: prove the Phase 3 vertical-slice exit path

## Contract

- Status: `ACTIVE — FINAL COMPLETE-RUNTIME PROOF OPEN`
- Owner: project maintainer
- Source of truth: `docs/roadmap.md` Phase 3 and `docs/handoffs/firered-recomp-checklist.md`
- Output boundary: deterministic test/support code and documentation needed to prove the existing Phase 3 path; no ROM, extracted assets, or unrelated Phase 4–10 work
- Authority: implementation may expose existing runtime seams; changes to game behavior or scope require a new task contract

## Goal

Produce repeatable evidence for: boot → new game → Oak intro → bedroom →
Pallet → Route 1 → wild battle → catch or defeat → save → reload.

## Acceptance criteria

1. A ROM-backed automated test drives the complete stated path, or documents
   the smallest remaining untestable boundary with a deterministic replay
   artifact and precise manual steps.
2. The test verifies persistent identity, map/location, party/Dex outcome, bag
   change when catching, money/HP outcome when defeating, and save/load state.
3. `POKEPORT_ROM=/path/to/pokefirered.gba bash scripts/test_all.sh` passes.
4. The Phase 3 exit criterion and capability checklist change status only when
   all parts of the path are evidenced.

## Progress

The major component seams are now individually evidenced.

### Entry boundary — independently passed

`work/tasks/phase3-title-oak-entry-proof.md` is `CLOSED — REVIEWED PASS` at exact implementation revision `8bdbda903fb0574cb169968976d4b40ce96d3563`.

The verified-ROM runtime replay proves:

```text
normal title input
→ existing Oak scene
→ existing identity/new-game flow
→ fresh Player's House 2F session
```

without constructing a post-Oak `GameSession` fixture. It verifies identity, map/coordinates, initial party/bag/money/PC Potion/Dex state, and passes the focused, full no-ROM, full verified-ROM, and Phase 3 ROM suites. See `work/reviews/2026-09-11-phase3-title-oak-entry-review.md`.

### Downstream runtime evidence already present

The ROM-gated component replay in `tests/phase3_exit_path_rom_test.lua` proves the bounded session, starter, Route 1 encounter, capture/defeat, and codec seams.

`scripts/runtime_replay_smoke.sh` proves a real LÖVE boot, fixed-tick input path, and the Player's House 2F → 1F → Pallet warp chain.

`route1_wild_defeat` supplies the bounded Route 1 runtime-loss replay and reaches the starter, tutorial battle, Route 1, a real grass encounter, and whiteout through live LÖVE input/update paths.

`route1_wild_win` proves the corresponding seeded Route 1 wild victory through normal FIGHT/default-move input without injecting combat state or an outcome.

The verified-ROM natural-capture replay reaches the visible first-Mart Parcel progression, the independently passed north-facing Oak Parcel/Dex scene, the real post-Dex shop, capture, K-save, and fresh-process L-load with persistent Dex/Lab/Mart/Parcel/party state.

`scripts/runtime_save_restart_replay.sh` separately proves the cross-process save boundary: it runs the bounded loss replay in a fresh XDG sandbox, saves through the normal K callback, verifies the sandbox save file, then starts a fresh LÖVE process and loads through normal L handling.

### Remaining parent gap

The earlier functional title/Oak seam is no longer open. The remaining issue is now purely the parent acceptance shape: the existing evidence is split across overlapping deterministic artifacts rather than one automated runtime command that continuously drives the complete stated Phase 3 path.

Because acceptance criterion 1 explicitly calls for a ROM-backed automated test of the complete path when no untestable boundary remains, Phase 3 is **not yet eligible for `DONE`** merely by stitching claims together in prose.

The bounded final continuation is:

`work/tasks/phase3-complete-runtime-exit-replay.md`

Its job is evidence integration only: reuse the already-passed runtime seams and prove normal boot → title/Oak/identity → bedroom/Pallet → Route 1 → first wild battle → catch or defeat → save → fresh-process reload in one deterministic automated artifact. It may add replay-driver/test plumbing but may not change normal gameplay behavior. If the continuous run reveals a real gameplay defect, it must stop and report the first exact failing seam for separate Orchestrator scoping.

## Stop conditions

Stop and re-scope if the path requires a missing script opcode, a general trainer battle, a menu redesign, a save-sector feature, completion of Phase 2 Oak visual-animation parity, a new general scene-stack architecture, or any other gameplay behavior change not already authorized by a narrower implementation task.
