# P6-02 proposal — normal Party selection design

- Task ID: `P6-02-PARTY-SELECTION-DESIGN`
- Status: `READY_FOR_REVIEWER` — 2026-10-14 bounded correction after independent NEEDS_FIX; no implementation acceptance
- Type: `DESIGN / SOURCE-LOCK; NO IMPLEMENTATION AUTHORITY`
- Parent: Phase 6; separate from P4/P5 private-ROM bridge work
- Basis: independently accepted `P6-01-FIELD-MENU-INVENTORY` at `ee7535d6`; see [inventory](../reports/phase6-field-menu-coverage-inventory.md)
- Risk: low for this design; later runtime modifications require their own bounded authorization and review

## Parent outcome

Replace guesswork about what happens when a player selects a Pokémon from the ordinary field START → POKÉMON path with a tested, reference-grounded design for one smallest useful player-facing action. Completion of this *design* does **not** imply a working Party submenu, Phase 6 closure, or retail parity.

## Verified starting point and source of truth

The accepted P6-01 inventory identifies `main.world.handleStartMenuSelection` as START→Party entry and `PartyScreen` as the list-state owner. Selecting a party slot reaches `confirmed`, but the production caller currently logs the slot and returns to START instead of opening the retail action menu. The existing `tests/party_screen_test.lua` checks selection/cancel, not a completed submenu action. Reference: pinned upstream `pokefirered` `c75f352304d529f6ba92d4f74b9cf8b5c3810788`, `src/party_menu.c`, especially `HandleChooseMonSelection` and `Task_TryCreateSelectionWindow`.

## Next bounded worker assignment

Read the pinned reference symbols, current `src/core/PartyScreen.lua`, `main.lua` Party handling, and `tests/party_screen_test.lua`. Choose **one** minimal ordinary-player action (prefer read-only SUMMARY if the reference/source dependencies make it feasible; do not assume that choice in advance). Produce:

1. An entry/selection/cancel/return state-transition table grounded in actual code and reference symbols.
2. Exact allowable implementation files and anticipated focused test assertions, including field-input isolation and no party mutation on cancel.
3. A dependency list separating necessary UI primitives from move switching, items, battle logic, saving, and developer shortcuts.
4. Explicit UNKNOWNs where reference behavior or runtime wiring cannot be verified; precise stop conditions when a ROM/private proof is essential.
5. A follow-on implementation task proposal with its own bounded MAY CHANGE/MUST NOT CHANGE and review gates, **not** implementation under this design.

## Authorized design-only write boundary if independently accepted

- `work/reports/phase6-party-selection-design.md`
- `work/tasks/phase6-party-selection-design.md` (this task record)

Do not edit `main.lua`, `src/`, `tests/`, workflow/runner configuration, save format, private-ROM paths, active P4/P5 artifacts, coordination state, or the canonical capability checklist. No new private-runner request/probe. No public extracted ROM assets.

## Verification and review

Check that the proposed design corresponds to source and tested runtime branches at explicitly identified revisions; distinguish code existence, component tests, and actual normal-route replay. Review independently before marking this discovery/design accepted. Later behavior changes must have their own bounded task, test evidence, and independent exact-head review.

## Stop conditions

Stop if the selected action requires broad new UI infrastructure, an unverified ROM-dependent assumption, unrelated progression work, or overlapping active implementation. Return a narrower source-lock/UNKNOWN rather than expanding the scope.

## Historical relationship to runner blocker

The 2026-10-09 dispatch was disjoint research while `RUNNER-LUA5-RECOVERY`
was blocked by private ROM availability. That observation is historical,
not current runner readiness. This design grants no retry of probe
`37554725384`, P4 implementation, P5 readiness, or private-runner action;
fresh coordination and separate bounded authority govern any such work.

## Evidence handoff — 2026-10-09

The source-locked [design report](../reports/phase6-party-selection-design.md) was prepared at `e46652afd7998a142e6c418ace7ecf9a046f5332` using pinned `pret/pokefirered` source symbols and current production Party/START code. It selects reduced read-only SUMMARY/CANCEL navigation with explicit exclusions for SWITCH/ITEM/field moves, documents the input/return chain and test matrix, and does not change runtime or canonical status. Independent acceptance of this design is required before implementation acceptance. Separate draft PR #6 is **not** approved by this handoff.

## Correction handoff — 2026-10-14

The independent [NEEDS_FIX review](../reviews/2026-10-14-party-selection-design-review.md)
of PR #3 head `8a9ca761bb407d9b498052626893ffb33564508d` remains unchanged.
The corrected report addresses its three findings within this two-document
design scope:

- F1: complete successor **PROPOSAL**, not authority, with six literal paths
  (`main.lua`, `src/core/PartyScreen.lua`, `src/core/PartySelectionFlow.lua`,
  `tests/party_screen_test.lua`, `tests/party_selection_flow_test.lua`,
  `work/tasks/phase6-party-summary.md`), explicit exclusions, focused source
  assertions, production field-input isolation, byte/value-identical records,
  stops and exact-head public CI/independent-review gates.
- F2: source restores the last-viewed mon; same-slot return is justified only
  by excluding mon cycling in this reduced view. Valid Eggs are supported
  only as a labeled, read-only saved-data projection; Egg retail display/stat
  parity is explicitly not claimed. Proposal requires ordinary/Egg integrity
  tests and no selection changes under summary navigation input.
- F3: source uses new A/B and repeated no-wrap D-pad. Proposed action flow
  implements that variant locally, including exact direction-mask matching;
  shared MenuCursor/InputState remain unchanged. Held-input tests must detect
  repetition even at a clamped two-row boundary, not merely assert no wrap.

Pinned source remains `c75f352304d529f6ba92d4f74b9cf8b5c3810788`; newly checked
anchors are recorded in the report. Existing runtime seams were read at the
unchanged PR baseline/head; no runtime or test implementation was altered.
Do not infer that the existing draft PR #6 already meets the corrected proposal.
Orchestrator must reconcile/authorize its contract after design review, and
its implementation still needs separate exact-head review before acceptance.

Worker checks: baseline repository checker PASS (276 tracked Lua / 205
Markdown / 620 local targets); after correction and preservation of the
independent report, checker PASS (276 / 206 / 621), and `git diff --check`
clean. Authored diff is exactly the two design documents. The independent
review is included separately at `e093612`, byte-for-byte SHA-256
`12e7089308edfc2775f690f2e9a0bbf145914f416dbc6844a23376d79ff08a18`.
No local runtime/test suite, ROM, replay or PR #6 action was performed for
this documentation correction. Publish only to existing PR #3 and route the
exact published head/public CI to an independent recheck; no self-review,
merge, implementation authority or capability advancement is claimed.
