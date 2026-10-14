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
| Actions | `party_menu.c:2963-2988` appends SUMMARY first and CANCEL last; field Eggs use ACTIONS_SWITCH at `:2996-3001`, mapped to SUMMARY/SWITCH/CANCEL in `data/party_menu.h:1093,1127` | No submenu yet | Expose only SUMMARY/CANCEL for ordinary records and valid Eggs; explicitly reduced scope |
| Action cursor | `party_menu.c:3062-3093` uses `Menu_ProcessInputNoWrapAround_other` for ≤3 actions; `menu.c:425-450` uses new A/B but repeated D-pad | Shared `MenuCursor:processInputNoWrap` uses new D-pad only, so it is not equivalent | Implement repeated no-wrap input locally in action flow; reuse only `moveCursorNoWrap`; do not change shared helpers |
| Enter SUMMARY | `CursorCB_Summary` → `CB2_ShowPokemonSummaryScreen` | `PartyScreen:rowData` decodes nickname/species and cached HP/level | Read-only saved-stat/info projection. No GBA summary graphics or move pages claimed |
| Return from SUMMARY | `party_menu.c:3109-3114` restores `GetLastViewedMonIndex()`, not necessarily the original slot; `pokemon_summary_screen.c:1168-1177,3387-3390` permits Up/Down mon cycling and returns the last index | Discarding `PartyScreen` loses selected position | Explicitly exclude summary mon cycling; only under that restriction does B return to actions on the same slot |
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

Summary Up/Down, Left/Right and L/R do not change the selected Pokémon or page;
A does not open move or other actions. Only newly pressed B returns to actions.
This deliberately omits the retail mon-cycling/page behavior. The same-slot
return above is a property of this reduced view, not a general source claim.

Valid saved Eggs can enter SUMMARY: source does not reject them. Their view
must be explicitly labeled as a reduced **Egg saved-data projection**, not a
retail Egg-stat screen. It may expose the decoded nickname, numeric species,
Egg marker and already cached level/HP/status/stat values as saved values;
it must not invent hatch progress, Egg messages, graphics, hidden-stat rules
or retail page parity. Retail has separate Egg tilemap and display branches
(`pokemon_summary_screen.c:1938-1951,2428-2441`). Invalid/checksum-failing
records retain existing decode failure behavior; no repair or new Bad Egg
support is implied.

## Follow-on implementation task PROPOSAL — not active authority

Proposed task: `P6-04-PARTY-SUMMARY`, to be reconciled by the Orchestrator with
the existing separate draft PR #6 only after independent design acceptance.
This proposal neither changes PR #6 nor approves its current implementation.

### Outcome and literal MAY CHANGE

Implement only normal field START → POKÉMON → occupied slot → SUMMARY/CANCEL
→ reduced read-only SUMMARY, with the exact reduced return chain and Egg/input
constraints above. Preserve existing Party list semantics and the still-open
START menu. The complete proposed six-path allowlist is:

| Literal path | Permitted implementation responsibility |
| --- | --- |
| `main.lua` | Only Party imports, entry/cleanup, active input dispatch and existing text overlay display; retain normal START entry and isolate field input |
| `src/core/PartyScreen.lua` | Read-only summary projection and explicit resume-to-browsing on the previously confirmed slot; no party mutation |
| `src/core/PartySelectionFlow.lua` | New pure two-action state machine, selected-slot ownership and local repeated no-wrap action input |
| `tests/party_screen_test.lua` | Existing list-return and decoded/cached projection tests, including valid Egg and byte/value integrity cases |
| `tests/party_selection_flow_test.lua` | New no-ROM flow/input/isolation/Egg tests, including bounded production Party input-dispatch checks with synthetic state |
| `work/tasks/phase6-party-summary.md` | Successor contract, source lock, explicit acceptance and Worker evidence/handoff; not broader coordination status |

No seventh implementation/test path is implicitly allowed. The current design
task still permits edits only to its own two documents. The separate review
artifact is authored by the independent Reviewer, not implementation authority.

### Proposed local input contract

In actions, process newly pressed A first, then newly pressed B, then repeated
D-pad per `menu.c:425-450`. Move only when the repeated D-pad mask equals UP
alone or DOWN alone; diagonal/opposite-direction chords must not move it.
Use the existing `InputState` repeat stream and `MenuCursor:moveCursorNoWrap`
to clamp at SUMMARY/CANCEL. Do not call `processInputNoWrap` and claim it
matches the source, and do not change shared `MenuCursor` or `InputState`.
No input event may cascade through more than one screen in the same tick.

### Proposed acceptance assertions

1. Normal START's party adapter opens the existing list without developer
   keys. A on each occupied slot opens SUMMARY/CANCEL for that 1-based slot;
   empty-party handling and list CANCEL remain unchanged.
2. SUMMARY projects decoded nickname/species/Egg marker and cached saved
   level/current-max HP/status/Attack/Defense/Speed/Sp. Attack/Sp. Defense.
   Synthetic records with distinctive literal values verify the fields;
   no recalculation, fabricated defaults, importer or ROM dependency is added.
3. B from summary returns to actions; B or A on action CANCEL resumes the
   same Party cursor; list B or A on list CANCEL returns to still-open START.
   Reopening the Party view must not retain stale flow state.
4. With at least two distinct records, summary directional/L/R input cannot
   change the selected slot or projection. A is inert there; newly pressed B
   alone unwinds. Test this restriction explicitly instead of treating the
   retail last-viewed index as always equal to the initially selected index.
5. A valid synthetic Egg is eligible for the reduced SUMMARY, carries the
   explicit non-retail saved-data label/marker and returns by the same chain.
   Assertions distinguish Egg from an ordinary record; no hatch state or
   retail Egg display semantics are inferred from cached numeric fields.
6. Action fresh/repeated UP/DOWN clamp at both ends. Use real InputState held
   timing and a local cursor-call observer or repeat-only event witness so
   tests distinguish repeated processing from a new-only implementation even
   when a two-row cursor is already clamped. Check no movement between repeat
   events, D-pad chords ignored, and held A/B never repeatedly confirm/cancel
   across state boundaries. Shared menu helper behavior must remain unchanged.
7. Verify production Party input dispatch with synthetic session/field state:
   action and summary ticks do not process list navigation, move the player,
   dispatch field interaction, open Bag, or reprocess the retained START menu.
   After closure, the inactive flow consumes no further input. Model tests
   alone must not be described as proof of production field-input isolation.
8. Snapshot every party record (encoded box bytes plus all cached values),
   party count/order and relevant synthetic session fields before opening,
   projection and every cancel transition. Require byte/value identity after
   each step for ordinary and Egg records, including nonselected records.
   Read-only inspection must not mutate HP, PP, status, inventory, flags,
   battle state or saves, nor recalculate stats or repair malformed records.

### Proposed MUST NOT CHANGE, evidence and stops

No SWITCH/reorder, ITEM/MAIL, field moves, move pages, summary mon cycling,
PC/Pokédex screens, retail graphics/audio, Egg-specific retail pages, importer,
save codec/schema, battle/story progression, shared input/menu helpers,
workflows, runner, ROM/cache, other PRs or canonical phase status. Existing
saved-data decoding remains the boundary, not a new corruption policy.

After Orchestrator approval of a successor contract, run no-ROM baseline and
after suites (`bash scripts/test_all.sh` with ROM/runtime opt-ins unset),
focused `lua5.1 tests/party_screen_test.lua`,
`lua5.1 tests/party_selection_flow_test.lua` and existing shared-helper
regression `lua5.1 tests/menu_cursor_test.lua`, plus
`lua5.1 scripts/check_repository.lua` and `git diff --check`. Require exact-head
public no-ROM CI and independent review of source, production dispatch,
assertions, six-path scope and no-mutation evidence before acceptance/merge.
Record expected skips. No unit/CI result establishes live ROM scene, rendered
parity, save/reload or normal-route replay proof.

Stop/re-scope if required source behavior is UNKNOWN, the six-path boundary
cannot establish the slice, field-input isolation needs a broader refactor,
valid saved records cannot be projected without writes, verified-ROM/runtime
proof becomes essential, or active work overlaps this behavior. Do not expand
the UI or claim a phase gate to resolve a stop. Design acceptance alone does
not permit implementation or accept the existing PR #6.

## Dependencies and explicit unknowns

- Already available: `PartyScreen`, `MenuCursor`, `InputState`,
  `BattlePartyBridge.decodeRecord`, `BoxPokemonCodec`, saved party stats.
- Excluded: summary mon cycling, retail SUMMARY/Egg pages and graphics, ability/held-item/move name display,
  Pokémon SWITCH mutation and reorder semantics, GIVE/TAKE ITEM, field moves,
  optional visual parity and full screen-to-screen ROM-backed replay.
- Unknown: production first-Gym traversal and full retail presentation;
  a clean no-ROM state test cannot establish either.
- The private-ROM runner blocker recorded on 2026-10-09 is historical, not a
  current readiness claim or retry authorization. This slice is proposed as
  no-ROM-verifiable regardless of runner state; ROM replay evidence is absent
  here and must not be fabricated.

## Handoff

A separately scoped draft implementation PR #6 has been prepared against
`main` from this source-locked seam. This report does **not** approve that
implementation. Independent review must first accept this design, then
inspect PR #6's exact head and its CI evidence, with no self-certification.
