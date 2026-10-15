# P6-04 Party SUMMARY — independent implementation review

Verdict: **PASS** for exact PR #6 implementation
`cb2a2dee735834148d226a5ae44d5d408b2014a2`, under amended authority
`6ff4464` and accepted corrected design `f3f9065` / review `2ad1d7e`.
Acceptance is only the reduced read-only normal-field Party SUMMARY/CANCEL
interaction. No retail presentation, live ROM route, save/reload or Phase 6
completion is established.

Independent Reviewer inspected the full six-path PR delta against integrated
main `8f5e6d31ec304d64f2c9c2c0fa855c979966dc29`, not only the last alignment
commit. Canonical coordination subsequently records READY_FOR_REVIEWER at
`c857133`; that main advance changes none of the six implementation paths.
Review used a separate detached worktree and made no implementation edits.

## Source and behavioral acceptance

Pinned public source remains pret/pokefirered
`c75f352304d529f6ba92d4f74b9cf8b5c3810788`.

| Contract requirement | Independent finding |
| --- | --- |
| Normal START → Party → selected slot | Existing live party adapter is retained; confirmed list selection creates the new flow without processing the same input again. No developer-key prerequisite. |
| SUMMARY/CANCEL scope | Source `party_menu.c:2963-3001` and `data/party_menu.h:1093,1127` allow Summary for ordinary mons and field Eggs. The two-action subset deliberately excludes SWITCH/ITEM/field moves. |
| Source action input | `menu.c:425-450` checks new A, new B, then exact repeated UP/DOWN mask. Flow implements that priority and isolates bits 4–7 arithmetically; chords do not move, endpoints clamp, shared helpers are unchanged. |
| Summary return | Source `party_menu.c:3109-3114` restores the last viewed mon. This slice never cycles mons/pages, so returning to actions on its fixed slot is correct within the accepted restriction. Summary A/directional/L/R inputs are inert; fresh B alone unwinds. |
| Actions/list return | B or action CANCEL closes only the flow, resumes the confirmed Party list with unchanged cursor, and consumes no list input in that tick. List B/CANCEL returns to retained START. Entry/cleanup clears stale flow state. |
| Saved-data projection | `summaryData` builds a fresh projection from decoded saved identity/EXP/OT plus cached level/HP/status/stats. It never recalculates or writes records. Valid Eggs get the explicit `EGG - saved-data projection` label, not a retail Egg-stat claim. |
| Production input isolation | Tests extract and execute actual `love.update`, START entry/selection/cleanup and Party overlay function bodies. Actions/summary leave list, retained START, Bag, field movement/interaction and save sentinels untouched. A positive control reaches field movement/interaction after menus close. |
| No mutation | Deep synthetic session snapshots include both encoded records, cached values, PP in encoded data, count/order and record identity. Ordinary/Egg projections and cancel/reopen boundaries preserve them. Mutating returned scalar projection fields does not mutate saves. |

The production-function extraction includes the complete dispatch chain, not
a copied model of it. Dependencies outside those functions are synthetic and
the scheduler is a no-op; this is bounded no-ROM wiring evidence, not execution
of the complete LÖVE scheduler/render loop or a normal-route replay. That limit
matches the task's required evidence rather than being represented as broader
runtime proof.

The source386 Dex guard and non-Party main behavior are retained. Exactly six
implementation/task paths differ from integrated main: `main.lua`,
`src/core/PartyScreen.lua`, `src/core/PartySelectionFlow.lua`,
`tests/party_screen_test.lua`, `tests/party_selection_flow_test.lua`, and
`work/tasks/phase6-party-summary.md`. No shared InputState/MenuCursor, save
codec/schema, battle/story, importer, workflow, ROM/cache or extracted-content
change entered this package. This review record is separate authority.

## Independently reproduced checks

All local tests explicitly unset `POKEPORT_ROM` and `POKEPORT_RUNTIME_REPLAY`:

- PartyScreen **33 passed / 0 failed**.
- PartySelectionFlow **162/0**.
- MenuCursor **14/0**.
- Full suite **PASS, 188 test files, no-ROM mode**, expected ROM skips.
- Repository checker **PASS, 316 Lua / 356 Markdown / 1175 local targets**
  before adding this review.
- `git diff --check 8f5e6d3 HEAD`: clean. Worktree clean before this report.

Assertions use literal, distinguishable ordinary/Egg identity and cached
values; real InputState timing checks the 40-tick initial delay and 5-tick
repeat spacing. Cursor-call witnesses catch missing repeats even when a
two-row cursor remains clamped. Fresh A/B priority, chords, held A/B across
transitions, no cycling and the complete return chain are exercised.

Independent in-memory negative witnesses, with no source-file mutation:

| Deliberate negative | Result |
| --- | --- |
| Exact pre-alignment `ff11dd0` flow and main function bodies against new tests | **149 passed / 13 failed**, exit 1 |
| Inject list input processing into active production Party actions | **138/24**, exit 1 |
| Inject an HP decrement into every summary projection call | **112/50**, exit 1 |

The HP witness differs from the Worker's particular injection and is reported
as independently observed, not copied. These failures show that repeated-input,
Egg-label, production-isolation and no-write tests detect the intended classes
of regression. Unmodified tests pass as above.

Live GitHub metadata independently confirms open/draft PR #6 at exact
`cb2a2de`, with both completed SUCCESS checks at that head:
[PR run 38720555643](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/38720555643)
and [push run 38720556716](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/38720556716).
Remote branch remained at the reviewed revision before review-only publication.

## Disposition and next allowance

No blocking or required-fix finding remains against this contract. Orchestrator
may perform final publication checks and accept/merge this bounded PR, then
reconcile only P6-04. Reviewer publishes only this review and does not merge.

Preserve exclusions: no mon cycling/pages, SWITCH/ITEM/field actions, retail
Egg graphics/stat rules, hatch progress, Bad Egg repair, full Summary parity,
ROM presentation/replay, save/reload or phase completion. Broader battle changes
integrated from main are not reviewed or accepted by this Party review.
