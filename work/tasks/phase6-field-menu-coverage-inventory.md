# Task: inventory normal-field menu coverage and developer fallbacks

- Task ID: `P6-01-FIELD-MENU-INVENTORY`
- Status: `READY_FOR_WORKER`
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
