# P6-02: selected Party slot — source-locked minimal SUMMARY design

- Status: `READY_FOR_INDEPENDENT_REVIEW` — design evidence only, not implementation acceptance
- Baseline: `main` at `503ea1e674baed88a27050dc54efd961baed1c9e`
- Reference: `pret/pokefirered` `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
- Origin: accepted [P6-01 inventory](phase6-field-menu-coverage-inventory.md)
- Governing [P6-02 task](../tasks/phase6-party-selection-design.md)

## Decision

Select the smallest read-only field-party action, **SUMMARY**, rather than SWITCH,
ITEM, held items, field moves or a full GBA-rendered information screen.
The executable source confirmed that ordinary START → POKÉMON selects a Party slot,
then constructs a second action menu. It does not return directly to START upon
A on a Pokémon, as the present runtime does.

The first new experience is the ability to inspect already saved party info without
mutating the party or using developer hotkeys. Missing retail pages, art, field
moves, switching and held-item actions must remain explicit limitations.

## Reference crosswalk

| Element | Pinned reference | Current runtime | Bounded design |
| --- | --- | --- | --- |
| START → Party | `src/start_menu.c:StartMenuPokemonCallback`, `src/party_menu.c:CB2_PartyMenuFromStartMenu` | `main.lua:world.handleStartMenuSelection` creates a `PartyScreen` adapter over `saveBlock1.playerParty` | Retain normal START entry and existing list input |
| A on Pokémon | `HandleChooseMonSelection` default → `Task_TryCreateSelectionWindow` | `PartyScreen.CONFIRMED`; `main.lua` currently discards the selection | Keep selected slot and open a second bounded action state |
| Actions | `SetPartyMonFieldSelectionActions` appends SUMMARY first, then conditionals, CANCEL last; Egg branch differs | No submenu yet | Expose only SUMMARY/CANCEL; label partial scope, do not invent SWITCH/ITEM |
| Action cursor | `Task_HandleSelectionMenuInput` uses no-wrap for ≤3 actions | `MenuCursor:processInputNoWrap` already exists | Reuse exactly two-row no-wrap action cursor |
| Enter SUMMARY | `CursorCB_Summary` → `CB2_ShowPokemonSummaryScreen` | `PartyScreen:rowData` decodes nickname/species and cached HP/level | Read-only saved-stat/info projection. No GBA summary graphics or move pages claimed |
| Return from SUMMARY | `CB2_ReturnToPartyMenuFromSummaryScreen` restores selected slot and selection-window callback | Discarding `PartyScreen` loses selected position | B returns to actions on same slot; B/CANCEL actions returns to list at the selected cursor |
| Exit Party | `HandleChooseMonCancel` → `CB2_ReturnToFieldWithOpenMenu` | List B/CANCEL closes Party, leaves START | Preserve this existing list exit |
| Integrity | `SetPartyMonFieldSelectionActions` only dispatches on subsequent input | `PartyScreen:rowData` is read-only and `PartyModel` owns mutation | No party/write operations in selection flow, summary, or cancel transitions |

## Minimal state flow

```text
field START menu (POKÉMON)
    → PartyScreen.browsing
    → A on occupied slot
    → PartySelection.actions [SUMMARY | CANCEL]
        → A on SUMMARY → PartySelection.summary (read-only)
            → B → PartySelection.actions (same slot)
        → B or A on CANCEL → PartyScreen.browsing (same cursor)
    → B or A on list CANCEL → still-open START
```

Input belongs to exactly one active screen on each fixed tick. The World input
branch must not process list movement while actions/summary is active.
The summary screen returns a data projection; it must not write to
`saveBlock1`, `playerParty`, decoded box bytes, inventory or session flags.

## Implementable boundary and required tests

The smallest expected implementation surface is:
`main.lua` (Party input/display/cleanup),
`src/core/PartyScreen.lua` (explicit resume and read-only saved-data projection),
one small pure action-flow module, focused no-ROM tests, and the implementation
task. No importer, ROM, runner, save codec, general menu, battle, or story edits.

Test obligations:
1. A on a populated slot enters actions for the correct 1-based slot.
2. SUMMARY reads real cached stats and decoded saved record, not fabricated data.
3. B from summary returns to actions for that slot; B/CANCEL from actions
   returns to same cursor in Party; list B returns to START.
4. No-wrap action navigation and inert input after closure.
5. Party count, encoded records, HP and status remain byte/value-identical.
6. No-ROM focused suite, repository checker, full public CI; record that
   public CI cannot prove live ROM scenes, presentation, or field replay.

## Dependencies and explicit unknowns

- Already available: `PartyScreen`, `MenuCursor`, `InputState`,
  `BattlePartyBridge.decodeRecord`, `BoxPokemonCodec`, saved party stats.
- Excluded: retail SUMMARY pages and graphics, ability/held-item/move name display,
  Pokémon SWITCH mutation and reorder semantics, GIVE/TAKE ITEM, field moves,
  optional visual parity and full screen-to-screen ROM-backed replay.
- Unknown: production first-Gym traversal and full retail presentation;
  a clean no-ROM state test cannot establish either.
- Private-ROM runner remains blocked separately. The code slice is designed
  to be verifiable without that private dependency, but ROM replay evidence
  must not be fabricated.

## Handoff

A separately scoped draft implementation PR #6 has been prepared against
`main` from this source-locked seam. This report does **not** approve that
implementation. Independent review must first accept this design, then
inspect PR #6's exact head and its CI evidence, with no self-certification.
