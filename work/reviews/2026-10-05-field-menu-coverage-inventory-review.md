# P6-01 field-menu coverage inventory — independent review

Verdict: **PASS** — read-only evidence inventory only.

- Reviewed revision: `ee7535d6d9007afa12eecc25c0af894be4379ce8`.
- Task: [P6-01 field-menu inventory](../tasks/phase6-field-menu-coverage-inventory.md).
- Artifact: [field/menu coverage report](../reports/phase6-field-menu-coverage-inventory.md).
- Evidence pins: repository `8f9924bfaf96e2889627a56eff5a1e899cab135e` and
  `pret/pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788`.

## Independence and exact scope

I reviewed the exact inventory commit independently and authored only this
review file. Its diff contains only the permitted task and report; it changes
no runtime, test, route, save, UI, ROM, runner, or canonical status. `git
diff --check` passes. The stated repository pin is an ancestor of the reviewed
revision, with no `main.lua`, core, or test changes between the evidence pin
and this inventory commit; concurrent work therefore does not alter its
runtime evidence basis.

## Normal paths, developer fallbacks, and evidence limits

The report correctly identifies the ordinary START input branch as the entry to
`world.openStartMenu`, distinguishes fresh/starter/Dex profiles, and traces
selection ownership through `world.handleStartMenuSelection`. It accurately
labels Pokédex, Trainer Card, and Options as explicit unavailable frontiers,
not functioning screens. It also records that direct START save calls the
local save callback without claiming the retail confirmation flow.

Party and field-Bag state rows distinguish model assertions from a demonstrated
normal UI route, preserve the Party action-window and Bag use/give/register
gaps, and mark session synchronization and disk persistence separately. The
Mart matrix identifies both the ordinary script/dialogue path and the `M`
developer shortcut. Inspection confirms the developer shortcut uses fixed
stock from any session location, while the ordinary path depends on a decoded
interaction/script route. The report properly treats the former as no proof
of field access, and it does not promote bounded historical Mart receipts into
all-shop or SELL coverage.

The developer/fallback ledger is appropriately conservative: `M`, `K`, `L`,
view/new-game switches, and replay/environment controls are named as developer,
fixture, or diagnostic routes. In particular, the historical K/L save/load
replay is not counted as normal START-save confirmation or Continue-menu proof.

## PC distinction and UNKNOWNs

The PC section correctly keeps two axes separate. `GameSession` constructs
`PcBoxes` from save-backed `pokemonStorage`, and the inspected PC/capture
assertions support bounded container backing and overflow behavior. Those facts
do not imply a player-facing PC screen. No normal field opener, PC menu-state
machine, selection/cancel flow, or user-driven deposit/withdraw route is
identified, so `PC2` remains `UNKNOWN`. Conversely, it does not mistake the
missing screen for absence of persisted PC backing.

The report also preserves material UNKNOWNs: live zero-Dex-count wiring,
Party submenus, Bag close/save/reload sequence, retail save confirmation,
complete Mart SELL/script-return timing, cross-view isolation, and all
excluded Phase 6 service families. The source references, runtime anchors,
assertion bodies, and historical receipts are kept distinct; no test execution,
ROM observation, traversal, playable-menu, retail-parity, or Phase completion
claim is made.

This PASS permits only later selection of a separately bounded Phase 6 design
or implementation task. It authorizes neither a UI implementation nor a
no-developer-fallback conclusion, and it does not affect the pending P4/P5
packages.

Only this review file was authored. No task, register, code, state, or commit
was changed by the Reviewer.
