# P6-04 — Read-only Party SUMMARY interaction

- Task ID: `P6-04-PARTY-SUMMARY`
- Status: `READY_FOR_REVIEWER` — bounded draft implementation, not merged or accepted
- Parent capability: Phase 6 (no phase-status update)
- Basis: accepted P6-01 inventory (`ee7535d6`); P6-02 draft design PR #3 remains unreviewed, so this branch cannot be merged or treated as independently accepted until its prerequisite/design and this implementation are reviewed.
- Human dispatch: 2026-10-09 request to continue gameplay code progress.
- Base: `503ea1e674baed88a27050dc54efd961baed1c9e`
- Public reference: `pret/pokefirered` at `c75f352304d529f6ba92d4f74b9cf8b5c3810788`, `src/party_menu.c` `HandleChooseMonSelection`, `Task_TryCreateSelectionWindow`, `SetPartyMonFieldSelectionActions`, `CursorCB_Summary`, `CB2_ReturnToPartyMenuFromSummaryScreen`.

## Bounded outcome

Normal field START → POKÉMON → one party slot → small per-mon action menu → SUMMARY shows legitimate read-only saved Pokémon information. B in SUMMARY returns to the action menu for the same Pokémon; B/CANCEL there returns to the party list with the original cursor, and B at that list returns to START. Party, Bag, world movement, save data, and battle state must not change. This is a subset of the real field menu, **not** retail visual/menu parity.

## MAY CHANGE

- `main.lua`: exclusively Party input/overlay branches, imports and Party cleanup.
- `src/core/PartyScreen.lua`: read-only summary row data, and an explicit reset-to-browsing operation for a previously confirmed selected slot.
- `src/core/PartySelectionFlow.lua` (new): pure SUMMARY/CANCEL state machine, no ROM or game writes.
- `tests/party_screen_test.lua`: confirmed-list return and decoded field assertions.
- `tests/party_selection_flow_test.lua` (new): fresh isolated no-ROM input/cancel/summary cases and unchanged party bytes.
- This task record.

## MUST NOT CHANGE

Do not implement SWITCH, ITEM, field moves, PC, Pokédex screens, any mutation to battle/save/capture/story state, input engine, map scripts, ROM/cache, workflows, runner, phase status, public reference, or other task/PR branches. Do not claim graphical sprite parity, a full retail SUMMARY screen or a full field-route replay solely from unit evidence.

## Verification gates

1. Source lock must match the above path/return/cancellation semantics.
2. Focused no-ROM tests for action menu, summary fields, input isolation, the full cancel chain and persisted slot selection.
3. Public CI `scripts/check_repository.lua` and `scripts/test_all.sh` at an exact implementation head, recording any skips; no private ROM testing assumed.
4. Independent reviewer of exact substantive head and CI receipts, including state/mutation boundary and prerequisite design, before merge/acceptance.

Stop and leave the PR draft if a verified-ROM test, broader field actions, or unapproved design expansion becomes necessary. Do not self-approve.

## Worker evidence — 2026-10-09

- Draft [PR #6](https://github.com/BigCatMellow/FireRedRecomp/pull/6) on branch `work/p6-party-summary-20261009`; substantive implementation head `d3d9175bb3d88402215d1f5e8833bb60686ce217` (docs/status additions afterward are non-substantive).
- Exactly the six authorized paths changed relative to base, including this task. New pure state machine `PartySelectionFlow` takes control only after the confirmed list selection; B unwinds SUMMARY→action list→Party list→START without session writes.
- [Public no-ROM CI 37946867516](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/37946867516) passed at substantive head. Previous [run 37946553780](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/37946553780) explicitly reported 278 tracked Lua, 204 Markdown, 616 local link targets and 152 test files PASS, with expected ROM-dependent SKIPs.
- Local runtime, headless LÖVE field replay and ROM-backed tests **NOT RUN** here. Public checks prove only no-ROM tests and syntax/link checks, not graphical parity or live Party navigation.
- Prerequisite P6-02 source-lock design resides in draft [PR #3](https://github.com/BigCatMellow/FireRedRecomp/pull/3) and is awaiting independent review. An independent Reviewer must inspect the design and exact PR #6 head/CI, including whether this reduced-summary UI is an acceptable increment, before any approval/merge or capability advancement.
