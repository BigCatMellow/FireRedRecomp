# FireRed ReComp capability checklist

Last verified: 2026-09-13 against the independently reviewed Phase 2 camera viewport and continuous Phase 3 replay.

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
| Phase 2 — rendering, input, scene runtime | IN PROGRESS | Rendering, sprite, title, palette, viewport tests, and camera proof at `4c5456f3` | Oak-intro/reference screenshot gate |
| Phase 3 — playable vertical slice | DONE | Independently reviewed continuous normal boot → title/Oak/identity → bedroom/Pallet → Route 1 defeat → normal save → fresh reload evidence at `4f4f29ec` | Visual/presentation parity remains Phase 2/8 work, not a Phase 3 exit blocker |
| Phase 4 — full Gen 3 battle engine | IN PROGRESS | `BattleEngine`, trainer AI, capture, EXP, and battle-scene tests | General trainer battles, switching, full move/effect and stress matrix |
| Phase 5 — overworld and field systems | IN PROGRESS | map, warp, object-event, movement, and script tests | Scripted Pallet-to-Elite-Four traversal without blocked or invalid paths |
| Phase 6 — menus, inventory, progression UI | IN PROGRESS | bag, party, mart, PC, and menu tests | Complete player-facing UI; no dev-key fallbacks |
| Phase 7 — story and cutscenes | IN PROGRESS | early-story and script tests | New game through credits without manual state edits or story skips |
| Phase 8 — audio and presentation parity | IN PROGRESS | song, audio, title, and graphics tests | Reference playthrough has no major missing audio/visual system |
| Phase 9 — postgame and secondary modes | NOT STARTED | Roadmap only | Offline single-player content complete from a normal save |
| Phase 10 — modding and release engineering | NOT STARTED | Architecture constraints in checklist | Import/play/mod/update/diagnose flow needs no manual filesystem work |

## Dispatch order

1. Close the remaining Phase 2 Oak-intro/reference parity gate only after its
   reference screenshots and acceptance assertions are specified.
2. Generalize trainer battles and move effects behind explicit Phase 4 test
   matrices; do not add story content that depends on unverified battle rules.
3. Expand overworld scripts/story only when their required opcode, save, menu,
   and battle gates are represented here.

Run `bash scripts/test_all.sh` before every change. With a legally obtained
verified ROM, run `POKEPORT_ROM=/path/to/pokefirered.gba bash scripts/test_all.sh`.
