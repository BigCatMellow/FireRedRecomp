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

## Stop conditions

Stop and re-scope if the path requires a missing script opcode, a general
trainer battle, a menu redesign, or a save-sector feature. Each is a separate
capability with its own tests and acceptance criteria.
