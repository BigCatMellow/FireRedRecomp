# P6-03 — Wire the normal START Pokédex count guard

- Task ID: `P6-03-START-DEX-SANITY`
- Status: `READY_FOR_REVIEWER` — implementation published to draft PR #5; no phase completion claim
- Type: `IMPLEMENTATION / BOUNDED, NO-ROM-TESTABLE`
- Parent: Phase 6; disjoint from pending Party-selection design PR #3 and blocked private-ROM P4/P5 tasks
- Baseline: `main` at `503ea1e674baed88a27050dc54efd961baed1c9e`
- Source lock: `pret/pokefirered` at `c75f352304d529f6ba92d4f74b9cf8b5c3810788`, `src/pokedex.c:GetNationalPokedexCount(FLAG_GET_SEEN)` and `src/start_menu.c:StartMenuPokedexSanityCheck`; read/save layout `GameSession` `saveBlock2.pokedex.seen` is a 52-byte string

## Goal and acceptance

The existing `StartMenu` model already ignores A on POKÉDEX when `nationalDexCount == 0`. The live caller `world.openStartMenu` omits that option. On a real session whose Pokédex-get flag is set and whose valid seen array has zero entries, pressing A on the Pokédex entry must not select it. With at least one genuinely seen National Dex entry, the menu may select normally. The count must use the real seen bitfield, not caught bits, and exclude unused post-411 bits.

## MAY CHANGE (literal paths)

- `main.lua`: require a pure counter through the existing `Battle` table and pass the count when opening the normal field START menu; correct the stale comment about Dex acquisition.
- `src/core/DexTracker.lua`: add a read-only counter for the existing 52-byte serialized seen bitfield; preserve existing tracker data model/behavior.
- `tests/dex_tracker_test.lua`: no-ROM counter cases for zero/one, cross-byte, last valid species, excluded trailing bits and invalid input.
- This task record.

## MUST NOT CHANGE

No save schema/codec, flags, story logic, importer, rendered Pokédex screen, menu item ordering, ROM/runner, workflows, private paths, P4/P5 routes, Phase 6 party task, external environment, or canonical capability status. The existing POKÉDEX selection action remains an explicitly unavailable UI stub; this fix only corrects the zero-entry admission guard.

## Verification and review

Check a clean diff for only the four allowed paths; run `lua5.1 tests/dex_tracker_test.lua` and `lua5.1 tests/start_menu_test.lua`, repository checker, and `bash scripts/test_all.sh` without a ROM. If local Lua is unavailable, report that limitation and use exact-head GitHub CI as the public no-ROM test evidence. A different reviewer must inspect the exact substantive branch head and source/behavior assertions before acceptance. Do not self-certify or merge from this worker context.

## Stop conditions

Stop if reference source disagrees with seen-count semantics, save-block seen is not a 52-byte string, a private ROM becomes necessary, or a required edit leaves the four-path boundary.

## Worker handoff — 2026-10-09

- Branch: `work/p6-start-menu-dex-count-20261009`; implementation and no-ROM tests at `01d2eeaa188fe44f58d1b50df22c4f52731a51bf`; draft PR #5.
- Diff inspected against pinned base `503ea1e674baed88a27050dc54efd961baed1c9e`: exactly the four allowed paths (`main.lua`, `src/core/DexTracker.lua`, `tests/dex_tracker_test.lua`, this task).
- [Exact-head public run 37945534748](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/37945534748): PASS; [same-head parallel run 37945504804](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/37945504804): PASS. Workflow installs Lua 5.1, invokes repository checks and `scripts/test_all.sh` without ROM. Local Lua is unavailable to this worker; no local execution/ROM/gameplay proof claimed.
- Semantics tested: zero/first/cross-byte seen entries, valid #411, ignored #412–416 trailing bits, all 411 seen, and absent/malformed bitfields; `StartMenu` already has its own blocked/unblocked test cases.
- **Reviewer needed:** independently inspect exact substantive diff and source semantics, including actual `main.lua` live session wiring. Re-run tests if warranted. No merged change, runtime gameplay proof or Phase 6 status advancement follows solely from these passing checks.
