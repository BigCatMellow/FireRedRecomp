# Task: inventory normal-field menu coverage and developer fallbacks

- Task ID: `P6-01-FIELD-MENU-INVENTORY`
- Status: `CLOSED — REVIEWED PASS`
- Type: `RESEARCH / READ-ONLY COVERAGE INVENTORY`
- Parent capability: Phase 6 menus, inventory, progression UI.

## Goal

Produce a source-and-test-backed inventory of the smallest normal-field menu
path: START entry through Party, Bag, Mart, and PC boundaries, recording
implemented state, ordinary entry, mutation/cancel/return behavior,
developer-only fallbacks, existing assertions, and UNKNOWNs. This report is
not an implementation claim.

## MAY CHANGE

1. `work/tasks/phase6-field-menu-coverage-inventory.md`
2. `work/reports/phase6-field-menu-coverage-inventory.md`

## Required evidence

Use the repository at the dispatched revision and public reference source pin
`c75f352304d529f6ba92d4f74b9cf8b5c3810788`. Cover fresh/starter/Dex START
actions; Party and field-Bag states; Mart buy/sell/quit entry/exit; and PC as a
separate persisted-storage versus player-facing-access boundary. Each row must
name source symbol, runtime entry, state transition, mutation timing,
normal/developer-only route, inspected assertion/receipt, and an honest status.

## MUST NOT CHANGE / CLAIM

No Lua/runtime/test behavior, ROM access, private runner request, P4/P5 route,
generic script, battle menu, save format, graphics parity, UI implementation,
or canonical phase status. Do not claim a playable menu, retail parity, or
absence of persisted PC backing merely from a missing player-facing screen.

## Stop

Stop and record UNKNOWN rather than inferring a normal route from a hotkey,
developer override, parser, or storage model. Independent report review must
PASS before any Phase 6 design/implementation task.

## Review

The independent [inventory review](../reviews/2026-10-05-field-menu-coverage-inventory-review.md)
accepted exact `ee7535d6d9007afa12eecc25c0af894be4379ce8` as read-only
evidence. It closes P6-01 only; a later P6 design task must select one bounded
frontier without treating developer keys or PC backing as player-facing proof.

## Worker evidence / handoff — 2026-10-03

- [Inventory report](../reports/phase6-field-menu-coverage-inventory.md) is ready
  for independent review against repository
  `8f9924bfaf96e2889627a56eff5a1e899cab135e` and reference
  `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
- Matrix covers three START profiles/seven actions plus navigation; all 18
  declared START/Party/Bag/Mart model states; ordinary versus developer Mart
  entry and return; separate PC persistence and player-access boundaries.
  Every behavior row names source/runtime anchors, transition/mutation timing,
  assertion/receipt limits and status. Normal-route gaps remain UNKNOWN.
- Explicit boundaries include Party/Bag/START placeholders, missing live Dex
  sanity-count input, immediate SAVE versus retail confirmation, K/L replay
  usage, Mart transaction callback ordering, and persisted PC backing without
  a demonstrated player-facing screen. No playable-menu or parity claim.
- Evidence method: source and assertion-body inspection plus existing review
  receipts only. No tests, ROM, gameplay, runner, environment changes or
  implementation; concurrent P4 working-tree changes remain untouched.
- No commit/publication performed by Worker. Parent owns exact-revision
  publication/review dispatch and coordination; this handoff does not update
  canonical status or authorize a Phase 6 successor.
