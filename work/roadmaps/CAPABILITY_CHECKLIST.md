# FireRed ReComp capability checklist

Last verified: 2026-08-24 against `main` at `10b43a25`.

Status vocabulary is intentionally narrow:

- `DONE` — implemented, tested, and meets the phase's stated exit criterion.
- `IN PROGRESS` — real implementation exists, but an explicit exit criterion or production wiring remains open.
- `NOT STARTED` — no implementation-backed claim yet.

This is the project-wide status surface. Detailed history and checkboxes live in
[`docs/handoffs/firered-recomp-checklist.md`](../../docs/handoffs/firered-recomp-checklist.md); this table must be updated in the same change that closes an exit gate.

| Capability | Status | Evidence | Remaining gate |
| --- | --- | --- | --- |
| Phase 0 — charter and reproducibility | IN PROGRESS | `PARITY_CONTRACT.md`, `docs/behavior-ledger.md`, `scripts/test_all.sh`, CI workflow | Save-version contract and first CI run must be verified; behavior ledger needs rows as subsystems grow |
| Phase 1 — ROM importer and canonical model | DONE | 117-test suite; `tests/full_sweep_validation_test.lua`; data viewer | All supported data-viewer records are reachable and decoded |
| Phase 2 — rendering, input, scene runtime | IN PROGRESS | Rendering, sprite, title, palette, and viewport tests | True 240×160 camera parity and Oak-intro/reference screenshot gate |
| Phase 3 — playable vertical slice | IN PROGRESS | New game, movement, wild battle, capture, save/load tests; ROM-gated `tests/phase3_exit_path_rom_test.lua` composition replay | Literal boot/input/warp traversal and LÖVE replay artifact for boot → new game → Route 1 → battle → catch/defeat → save → reload |
| Phase 4 — full Gen 3 battle engine | IN PROGRESS | `BattleEngine`, trainer AI, capture, EXP, and battle-scene tests | General trainer battles, switching, full move/effect and stress matrix |
| Phase 5 — overworld and field systems | IN PROGRESS | map, warp, object-event, movement, and script tests | Scripted Pallet-to-Elite-Four traversal without blocked or invalid paths |
| Phase 6 — menus, inventory, progression UI | IN PROGRESS | bag, party, mart, PC, and menu tests | Complete player-facing UI; no dev-key fallbacks |
| Phase 7 — story and cutscenes | IN PROGRESS | early-story and script tests | New game through credits without manual state edits or story skips |
| Phase 8 — audio and presentation parity | IN PROGRESS | song, audio, title, and graphics tests | Reference playthrough has no major missing audio/visual system |
| Phase 9 — postgame and secondary modes | NOT STARTED | Roadmap only | Offline single-player content complete from a normal save |
| Phase 10 — modding and release engineering | NOT STARTED | Architecture constraints in checklist | Import/play/mod/update/diagnose flow needs no manual filesystem work |

## Dispatch order

1. Prove the Phase 3 exit path with deterministic, ROM-backed evidence; see
   [`work/tasks/phase3-exit-proof.md`](../tasks/phase3-exit-proof.md).
2. Close the Phase 2 camera/Oak-intro parity gate only after its reference
   screenshots and acceptance assertions are specified.
3. Generalize trainer battles and move effects behind explicit Phase 4 test
   matrices; do not add story content that depends on unverified battle rules.
4. Expand overworld scripts/story only when their required opcode, save, menu,
   and battle gates are represented here.

Run `bash scripts/test_all.sh` before every change. With a legally obtained
verified ROM, run `POKEPORT_ROM=/path/to/pokefirered.gba bash scripts/test_all.sh`.
