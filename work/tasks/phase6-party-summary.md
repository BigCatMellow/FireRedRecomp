# P6-04 — Read-only Party SUMMARY interaction

- Task ID: `P6-04-PARTY-SUMMARY`
- Status: `READY_FOR_REVIEWER` — aligned 2026-10-15 with independently accepted corrected design; exact-head independent implementation review still required
- Parent capability: Phase 6 (no phase-status update)
- Basis: accepted P6-01 inventory (`ee7535d6`); corrected P6-02 design `f3f9065` independently PASS in review `2ad1d7e`. Orchestrator explicitly adopts its bounded six-path successor proposal in this contract on 2026-10-14. This grants alignment authority, not acceptance of existing code.
- Human dispatch: 2026-10-09 request to continue gameplay code progress.
- Base: `503ea1e674baed88a27050dc54efd961baed1c9e`
- Public reference: `pret/pokefirered` at `c75f352304d529f6ba92d4f74b9cf8b5c3810788`, `src/party_menu.c` `HandleChooseMonSelection`, `Task_TryCreateSelectionWindow`, `SetPartyMonFieldSelectionActions`, `CursorCB_Summary`, `CB2_ReturnToPartyMenuFromSummaryScreen`.

## Alignment authority — 2026-10-14

Read the accepted [design](../reports/phase6-party-selection-design.md) and
[independent recheck](../reviews/2026-10-14-party-selection-design-review.md)
after normally integrating current main (including merged PR3/PR5) into the
existing PR6 branch. Preserve all concurrent main changes; no force/reset.
Reuse the existing implementation and correct only the gaps below within its
six original paths. No separate design/route/probe package is required by
this existing no-ROM-testable UI contract. This is not the P4 fast lane.

Pinned source distinctions now required:

- `party_menu.c:2963–3001`, `data/party_menu.h:1093,1127`: ordinary and valid
  Egg records offer SUMMARY. This slice offers only SUMMARY/CANCEL.
- `party_menu.c:3109–3114`, `pokemon_summary_screen.c:1168–1177,3387–3390`:
  source returns to the last viewed mon; same-slot return here is justified
  only by explicitly excluding mon cycling and page switching.
- `party_menu.c:3062–3093`, `menu.c:425–450`: process new A, then new B, then
  repeated D-pad. Move only for an exact UP-only or DOWN-only repeated mask.
  Implement this locally in PartySelectionFlow using existing InputState
  repeat and MenuCursor moveCursorNoWrap; shared input/menu helpers unchanged.
- Retail Egg display differs (`pokemon_summary_screen.c:1938–1951,2428–2441`).
  Label a valid Egg's reduced view as an Egg saved-data projection; cached
  numeric values are saved data, not a claim about the retail Egg stat screen.

Summary directional/L/R inputs cannot change slot or page, A is inert, and
only newly pressed B returns. No same-tick input cascading through views.
Do not invent Egg hatch progress/messages or repair invalid records. Preserve
the already merged source386 Dex guard and all non-Party main.lua behavior.

## Bounded outcome

Normal field START → POKÉMON → one party slot → small per-mon action menu → SUMMARY shows legitimate read-only saved Pokémon information. B in SUMMARY returns to the action menu for the same Pokémon; B/CANCEL there returns to the party list with the original cursor, and B at that list returns to START. Party, Bag, world movement, save data, and battle state must not change. This is a subset of the real field menu, **not** retail visual/menu parity.

## MAY CHANGE

- `main.lua`: exclusively Party input/overlay branches, imports and Party cleanup, including explicit reduced Egg saved-data label; no other scene behavior.
- `src/core/PartyScreen.lua`: read-only summary row data, and an explicit reset-to-browsing operation for a previously confirmed selected slot.
- `src/core/PartySelectionFlow.lua` (new): pure SUMMARY/CANCEL state machine, local repeated no-wrap input as above, no ROM or game writes.
- `tests/party_screen_test.lua`: confirmed-list return and decoded field assertions.
- `tests/party_selection_flow_test.lua` (new): fresh isolated no-ROM input/cancel/summary/Egg cases, production Party-dispatch isolation with synthetic state, and unchanged party bytes/cached values.
- This task record.

Independent Reviewer may add/append its own record under `work/reviews/`;
that record is separate from the six-path Worker implementation boundary.

## MUST NOT CHANGE

Do not implement SWITCH, ITEM, field moves, PC, Pokédex screens, any mutation to battle/save/capture/story state, input engine, map scripts, ROM/cache, workflows, runner, phase status, public reference, or other task/PR branches. Do not claim graphical sprite parity, a full retail SUMMARY screen or a full field-route replay solely from unit evidence.

Also exclude Summary mon cycling, page switching, retail Egg graphics/stat
rules, hatch progress, Bad Egg support/record repair, shared MenuCursor or
InputState changes. A source or production isolation gap that needs a seventh
implementation path stops this package for explicit re-scope.

## Verification gates

1. Source lock must match the above path/return/cancellation semantics.
2. Focused no-ROM tests for action menu, summary fields, input isolation, the full cancel chain and persisted slot selection.
3. Public CI `scripts/check_repository.lua` and `scripts/test_all.sh` at an exact implementation head, recording any skips; no private ROM testing assumed.
4. Independent reviewer of exact substantive head and CI receipts, including state/mutation boundary and prerequisite design, before merge/acceptance.

5. Source-literal tests with at least two distinctive saved records verify
   selected slot/projection survives summary Up/Down/Left/Right/L/R/A input;
   new B and the complete cancel/reopen chain work without stale state.
6. Valid synthetic Egg can enter the labeled reduced projection and return;
   ordinary/Egg cached fields and decoded identity are asserted directly.
7. Real InputState held timing plus repeat-only/cursor-call witnesses detect
   repeated movement even at clamped two-row endpoints. Test no movement
   between repeat events, chords ignored, new A/B priority, held A/B inert
   across state transitions, and shared-helper regressions unchanged.
8. Exercise production Party input dispatch using synthetic state: actions/
   summary must not move list/player, interact with field, open Bag or consume
   retained START input. Component-only tests cannot establish that wiring.
   Read-only projection/entry/every cancel step must preserve selected and
   nonselected encoded records, cached HP/status/stats/PP, count/order and
   relevant synthetic session fields. No ROM/private fixtures required.

Run baseline and after `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY bash
scripts/test_all.sh`; focused PartyScreen/PartySelectionFlow/MenuCursor tests,
`lua5.1 scripts/check_repository.lua`, and `git diff --check`. Compare corrected
assertions against pre-alignment code where applicable, so new tests detect
the repeated-input/Egg/isolation gaps rather than merely remain green.
Publish only to existing PR6 branch, record exact public CI and route separate
independent review; no Worker merge/self-review. Source uncertainty, writes
needed for projection, or essential private-ROM/runtime proof stops alignment.

Stop and leave the PR draft if a verified-ROM test, broader field actions, or unapproved design expansion becomes necessary. Do not self-approve.

## Historical Worker evidence — 2026-10-09 (alignment still required)

- Draft [PR #6](https://github.com/BigCatMellow/FireRedRecomp/pull/6) on branch `work/p6-party-summary-20261009`; substantive implementation head `d3d9175bb3d88402215d1f5e8833bb60686ce217` (docs/status additions afterward are non-substantive).
- Exactly the six authorized paths changed relative to base, including this task. New pure state machine `PartySelectionFlow` takes control only after the confirmed list selection; B unwinds SUMMARY→action list→Party list→START without session writes.
- [Public no-ROM CI 37946867516](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/37946867516) passed at substantive head. Previous [run 37946553780](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/37946553780) explicitly reported 278 tracked Lua, 204 Markdown, 616 local link targets and 152 test files PASS, with expected ROM-dependent SKIPs.
- Local runtime, headless LÖVE field replay and ROM-backed tests **NOT RUN** here. Public checks prove only no-ROM tests and syntax/link checks, not graphical parity or live Party navigation.
- Prerequisite P6-02 source-lock design resides in draft [PR #3](https://github.com/BigCatMellow/FireRedRecomp/pull/3) and is awaiting independent review. An independent Reviewer must inspect the design and exact PR #6 head/CI, including whether this reduced-summary UI is an acceptable increment, before any approval/merge or capability advancement.

## Alignment Worker evidence — 2026-10-15

- Authority `6ff4464`; worktree `/tmp/firered-party-summary-align.8vCZJo`,
  local branch `work/p6-party-summary-alignment-20261014`; existing PR #6
  branch remains the sole publication target. Integrated main `239c25f`
  (accepted PR3/PR5) normally at `ff11dd0`, then inspected the disjoint
  advance to `8f5e6d31ec304d64f2c9c2c0fa855c979966dc29` and merged normally
  at `b6b5742f83e04503bf4e3dacbf1cf73bfd098549`. No conflict, reset or
  overwritten main changes; the source386 Dex guard is retained.
- Implementation changes are local action input (new A, new B, repeated
  exact UP/DOWN mask with no-wrap clamping), explicit Egg saved-data label
  retaining nickname, and clarification of the existing no-cycling view.
  Existing production exclusive Party dispatch and read-only projection
  remain intact. Shared MenuCursor/InputState and all non-Party behavior
  are unchanged. Diff against integrated main contains exactly six allowed
  paths, including this task; no review/runner/ROM/replay edits.
- Baseline: **179 no-ROM test files PASS** at integrated `ff11dd0` before
  alignment. Final focused checks: PartyScreen **33/0**, PartySelectionFlow
  **162/0**, MenuCursor **14/0**. Final full suite **188 files PASS**, with
  `POKEPORT_ROM` and `POKEPORT_RUNTIME_REPLAY` explicitly unset. Repository
  checker **PASS, 316 Lua / 356 Markdown / 1175 local targets**;
  `git diff --check` clean.
- Source-literal tests cover fresh/repeated/clamped D-pad timing, rejected
  direction chords, A-before-B-before-D-pad priority, held A/B across
  transitions, ordinary and valid Egg saved values/identity/PP, no summary
  mon/page cycling, both cancel paths, and clean reopening.
- Production evidence executes actual `main.lua` function bodies for
  `love.update`, START opening/selection/cleanup and Party overlay rendering
  with synthetic state and no ROM/LÖVE bootstrap. Tests assert no list,
  retained START, Bag, player movement or field-interaction input leakage
  during actions/summary; a positive control reaches field movement and
  interaction only after menus close. Full synthetic session snapshots
  preserve every encoded party byte and cached value, count/order and
  selected/nonselected record identity at projection and cancel boundaries.
- In-memory regression witnesses (no source-file mutation): current flow
  assertions against pre-alignment `ff11dd0` flow/main give **149 passed /
  13 failed**, exit 1 (repeat/chord handling and Egg label). Injecting list
  input into active Party actions gives **138/24**, exit 1. Injecting an HP
  write into summary projection gives **114/48**, exit 1. The unmodified
  aligned implementation passes **162/0**.
- These are no-ROM function/component assertions, not a LÖVE/retail visual
  replay, save/reload proof, Egg screen parity or Phase 6 completion. Final
  published head/public CI must be handed to the separate Reviewer. Worker
  does not merge PR #6, self-review, or advance capability status.
