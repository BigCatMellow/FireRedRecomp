# Task: prove the Phase 3 vertical-slice exit path

## Contract

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

The ROM-gated component replay in `tests/phase3_exit_path_rom_test.lua` proves
the bounded session, starter, Route 1 encounter, capture/defeat, and codec
seams. `scripts/runtime_replay_smoke.sh` separately proves a real LÖVE boot,
fixed-tick input path, and the Player's House 2F → 1F → Pallet warp chain.
Neither proof completes this task: the remaining gate is Oak/title entry, a
player-win/catch route, and disk-save/restart/load replay.

`route1_wild_defeat` now supplies the bounded Route 1 runtime-loss replay:
it reaches the starter, tutorial battle, Route 1, a real grass encounter, and
whiteout through live LÖVE input/update paths. It drives the post-Oak
BOY/RED/GREEN identity flow with normal input masks, but does not prove the
preceding Oak/title entry, a player-win/catch path, or cross-process save/load.

## Stop conditions

Stop and re-scope if the path requires a missing script opcode, a general
trainer battle, a menu redesign, or a save-sector feature. Each is a separate
capability with its own tests and acceptance criteria.
