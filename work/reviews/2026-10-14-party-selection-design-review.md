# P6-02 Party selection design — independent review

Verdict: **NEEDS_FIX** for design-only PR #3 head
`8a9ca761bb407d9b498052626893ffb33564508d`, report prepared at
`e46652afd7998a142e6c418ace7ecf9a046f5332`, baseline
`503ea1e674baed88a27050dc54efd961baed1c9e`.

The reduced read-only SUMMARY/CANCEL direction and its principal return chain
are source-backed. Small documentation corrections below are needed to satisfy
the existing task's exact-boundary and source-lock criteria. This verdict does
not review or authorize PR #6 implementation.

## Verified source and runtime

Public source checkout HEAD is
`c75f352304d529f6ba92d4f74b9cf8b5c3810788`.

- `src/party_menu.c:5428-5430` enters FIELD / SINGLE / CHOOSE_MON with
  `CB2_ReturnToFieldWithOpenMenu` as exit callback. Ordinary selection reaches
  `Task_TryCreateSelectionWindow` through `HandleChooseMonSelection:1152-1215`.
- `SetPartyMonFieldSelectionActions:2963-2988` puts SUMMARY first and CANCEL
  last, with field moves, SWITCH and ITEM/MAIL between. Excluding those actions
  is an explicit reduced scope, not retail-complete menu parity.
- `Task_HandleSelectionMenuInput:3062-3093` sends B to the last action;
  `CursorCB_Cancel1:3391-3402` removes action windows and resumes list input.
  List cancel uses the field callback. This supports actions → list → START.
- `CursorCB_Summary:3095-3100` opens Summary; return at `:3109-3114` recreates
  the selection window. Returning to actions rather than directly to the list
  is correct, subject to F2 below.
- Actual baseline runtime `main.lua:2170-2187` adapts the live session party;
  `:4569-4582` discards confirmed selections and retains START. PartyScreen
  exposes decoded saved data and cached stats without mutation. At canonical
  main `3adc7e8`, PartyScreen is unchanged and the only main.lua delta from the
  baseline is the unrelated Viridian pre-spawn projection. This entry/input
  seam therefore still exists; no assertion about unchanged battle dependencies
  follows.

## Required bounded design corrections

### F1 — Exact follow-on proposal is incomplete

The task requires exact allowable implementation files and a follow-on task
proposal with MAY CHANGE / MUST NOT CHANGE / review gates. The report instead
names "one small pure action-flow module, focused no-ROM tests, and the
implementation task" without literal paths or a complete proposal. PR #6's
existence is not a substitute for this design deliverable.

Fix only the two design documents: enumerate the intended module/test/task
paths and place the proposed implementation boundary, existing exclusions,
acceptance assertions, evidence limits and stop/review gates together. This
is a proposal for Orchestrator approval, not permission to edit those paths.
Keep field-input isolation and byte/value-identical party records as explicit
test obligations. Do not broaden into retail graphics or additional actions.

### F2 — Same-slot return and Egg scope need precise source qualification

Source does not unconditionally restore the initially selected slot:
`CB2_ReturnToPartyMenuFromSummaryScreen` assigns `GetLastViewedMonIndex()`.
`src/pokemon_summary_screen.c:1168-1177` allows Up/Down to seek another mon;
`:3387-3390` returns that last-viewed index. A same-slot return is valid for
this reduced view only if mon cycling is explicitly excluded. State that
constraint and test that summary navigation cannot change the selection.

The report notes "Egg branch differs" without locking the result.
`GetPartyMenuActionsType:2996-3001` selects ACTIONS_SWITCH for a field Egg;
`src/data/party_menu.h:1093,1127` maps this to SUMMARY/SWITCH/CANCEL. Thus Eggs
are not rejected from Summary. The retail summary has Egg-specific display
branches (for example `pokemon_summary_screen.c:1938-1951,2428-2441`). State
whether the bounded read-only projection supports Eggs with an explicit
non-retail information limit or excludes them honestly; name the corresponding
acceptance case. Do not silently claim ordinary cached-stat display is the
retail Egg summary. No new Egg graphics/pages are requested by this finding.

### F3 — Reused no-wrap helper is not the exact source input variant

Source `Task_HandleSelectionMenuInput` uses
`Menu_ProcessInputNoWrapAround_other` for at most three actions.
`src/menu.c:425-450` uses newly pressed A/B but `JOY_REPT(DPAD_ANY)` for
movement. Existing `MenuCursor:processInputNoWrap` uses newly pressed D-pad
only. Both clamp at the ends, but their input contracts differ.

Qualify the report's reuse claim: either specify repeated no-wrap movement
locally in the proposed action-flow module without altering shared menu
semantics, or explicitly record a deliberate reduced-input limitation for
Orchestrator acceptance. Include the chosen held-input boundary in the proposed
tests; avoid claiming these helpers are exact equivalents.

## Evidence and scope

- Exact PR diff contains only its task and report. No runtime, tests, save,
  workflow, ROM, extracted data or coordination changes.
- Independently recovered PR #3 open/non-draft at the exact head above.
  Public CI SUCCESS: [run 37946869635](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/37946869635)
  and [run 37946862123](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/37946862123).
- Local no-ROM component checks at that head: `party_screen_test.lua` **21/0**;
  `menu_cursor_test.lua` **14/0**; repository checker **PASS**, 276 Lua,
  205 Markdown, 620 local targets before this untracked review.
- `git diff --check 503ea1e HEAD` clean. No local full suite, ROM access,
  gameplay replay, implementation mutation, merge or push was performed.
- These checks support existing components and document integrity, not an
  implemented submenu or normal-route replay.

## Next allowance

Orchestrator may dispatch the smallest correction to the existing two-document
design boundary, then request an independent exact-revision recheck. On design
PASS, any PR #6 implementation still requires its own exact contract, source,
code/assertion and evidence review. No Phase 6 completion follows.
