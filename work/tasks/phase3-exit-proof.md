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
Neither proof completes this task: the remaining gate is Oak/title entry and
a natural-capture route.

`route1_wild_defeat` now supplies the bounded Route 1 runtime-loss replay:
it reaches the starter, tutorial battle, Route 1, a real grass encounter, and
whiteout through live LÖVE input/update paths. It drives the post-Oak
BOY/RED/GREEN identity flow with normal input masks, but does not prove the
preceding Oak/title entry or a player-win/catch path.

`route1_wild_win` now proves the corresponding seeded Route 1 wild victory
through normal FIGHT/default-move input without injecting combat state or an
outcome. Capture remains separate: a fresh natural route has no Poké Ball, so
it needs an independently evidenced normal purchase path rather than test
inventory injection.

Natural purchase was blocked by a scoped field-interaction gap:
the real Viridian Mart clerk sits behind a collision counter, but the runtime
only targets the immediately adjacent tile. See
[`work/tasks/mart-counter-interaction.md`](mart-counter-interaction.md);
do not bypass this with a synthetic Mart trigger or inventory fixture.

The counter rule is now implemented and unit-tested. The next capture probe
must use it through the real Viridian Mart map/NPC/script route and report
separately that generic first-visit map-script parity remains open.

`scripts/runtime_save_restart_replay.sh` now proves the cross-process save
boundary separately: it runs the bounded loss replay in a fresh XDG sandbox,
saves through the normal **K** callback, verifies the sandbox save file, then
starts a fresh LÖVE process and loads through normal **L** handling. This is
nominal persistence evidence, not retail-save compatibility or crash safety.

## Stop conditions

Stop and re-scope if the path requires a missing script opcode, a general
trainer battle, a menu redesign, or a save-sector feature. Each is a separate
capability with its own tests and acceptance criteria.
