# Task: source-faithful Pokédex numerical-list core

- Status: `REVIEW`
- AGI status: `AGI READY`
- Type: `IMPLEMENTATION`
- Owner: `/root`
- Risk: `LOW`
- Goal: provide a pure, render-agnostic controller for FireRed's numerical
  Kanto/National Pokédex list without claiming a live Pokédex screen.

## Source and scope

- Authoritative source: `src/pokedex_screen.c` in the local FireRed decomp,
  specifically `DexScreen_CountMonsInOrderedList` and
  `Task_DexScreen_NumericalOrder`.
- `src/core/PokedexScreen.lua` exposes numerical entries through the highest
  seen Kanto (maximum 151) or National (maximum 411) number. It retains unseen
  holes before that high-water mark with the retail `-----` label, reports
  seen and owned independently, gates National mode explicitly, and reproduces
  the nine-row clamped non-wrapping numerical-list viewport.
- A confirm event is emitted only for a seen entry; cancel emits a separate
  terminal event. The module does not render, mutate a save, read a ROM, own a
  detail page, or route input from `main.lua`.

## Acceptance criteria

- [x] Kanto/National list stops at its source-derived highest seen slot and
  does not leak unseen names from holes below it.
- [x] Seen/owned state and the selected National/species identifiers remain
  distinct and correct.
- [x] Cursor and nine-row viewport clamp at both ends without wrapping.
- [x] Focused pure-Lua test passes.
- [ ] Independent source/code review passes.

## Verification

`luac5.1 -p src/core/PokedexScreen.lua` and
`lua5.1 tests/pokedex_screen_test.lua` pass (14 checks). Full regression
suites are required after review. Runtime replay is not applicable until a
renderer/input route consumes this pure controller.

## Next action

Obtain an independent review, then run the full no-ROM and verified-ROM
regression suites. A later, separately scoped task may wire it into the Start
menu and supply renderer/detail-page behavior.
