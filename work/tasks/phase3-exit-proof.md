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
Neither proof alone completes this task.

`route1_wild_defeat` supplies the bounded Route 1 runtime-loss replay: it
reaches the starter, tutorial battle, Route 1, a real grass encounter, and
whiteout through live LÖVE input/update paths. It drives the post-Oak
BOY/RED/GREEN identity flow with normal input masks, but does not prove the
preceding title/Oak entry.

`route1_wild_win` proves the corresponding seeded Route 1 wild victory through
normal FIGHT/default-move input without injecting combat state or an outcome.

The earlier natural-capture gap has now been closed by the bounded canonical
Viridian work. The verified-ROM natural-capture replay reaches the visible
first-Mart Parcel progression, the north-facing Oak Parcel/Dex scene, the real
post-Dex shop, capture, K-save, and fresh-process L-load with persistent
Dex/Lab/Mart/Parcel/party state. The north-facing Oak leaf was independently
reviewed `PASS` at implementation revision
`2d8c3221775044a54668683e500055307fe4d20b`; see
`work/reviews/oak-parcel-dex-presentation-north-final-review.md`.

`scripts/runtime_save_restart_replay.sh` separately proves the cross-process
save boundary: it runs the bounded loss replay in a fresh XDG sandbox, saves
through the normal **K** callback, verifies the sandbox save file, then starts
a fresh LÖVE process and loads through normal **L** handling. This is nominal
persistence evidence, not retail-save compatibility or crash safety.

### Smallest remaining parent gap

The remaining Phase 3 entry gap is now the preceding runtime transition:

```text
normal boot
→ title/new-game entry
→ Oak intro / identity flow
→ fresh session
→ Player's House 2F bedroom
```

Existing title rendering, static Oak speech presentation, gender/player/rival
naming, fresh-save bootstrap, and the downstream bedroom→Pallet replay are
implemented, but the parent task does not yet have deterministic evidence that
a normal runtime boot drives those pieces continuously without constructing a
post-Oak session fixture.

The bounded continuation contract is
[`work/tasks/phase3-title-oak-entry-proof.md`](phase3-title-oak-entry-proof.md).
Prefer an evidence-only replay if current runtime behavior already satisfies
this boundary; do not rebuild title/Oak systems merely because the proof is
missing.

## Stop conditions

Stop and re-scope if the path requires a missing script opcode, a general
trainer battle, a menu redesign, a save-sector feature, completion of Phase 2
Oak visual-animation parity, or a new general scene-stack architecture. Each
is a separate capability with its own tests and acceptance criteria.
