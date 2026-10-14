# P6-03 — Wire the normal START Pokédex count guard

- Task ID: `P6-03-START-DEX-SANITY`
- Status: `CLOSED — REVIEWED PASS` — corrected implementation independently accepted and PR #5 merged at `52fbf69` on 2026-10-14; no phase completion claim
- Type: `IMPLEMENTATION / BOUNDED, NO-ROM-TESTABLE`
- Parent: Phase 6; disjoint from pending Party-selection design PR #3 and blocked private-ROM P4/P5 tasks
- Baseline: `main` at `503ea1e674baed88a27050dc54efd961baed1c9e`
- Source lock: `pret/pokefirered` at `c75f352304d529f6ba92d4f74b9cf8b5c3810788`, `src/pokedex.c:GetNationalPokedexCount(FLAG_GET_SEEN)` and `src/start_menu.c:StartMenuPokedexSanityCheck`; read/save layout `GameSession` `saveBlock2.pokedex.seen` is a 52-byte string

## Goal and acceptance

The existing `StartMenu` model already ignores A on POKÉDEX when `nationalDexCount == 0`. The live caller `world.openStartMenu` omits that option. On a real session whose Pokédex-get flag is set and whose valid seen array has zero entries, pressing A on the Pokédex entry must not select it. With at least one genuinely seen National Dex entry, the menu may select normally. The count must use the real seen bitfield, not caught bits, and count only National Dex entries 1–386; bits 387–416 never contribute.

## Corrected source lock and bounded design — 2026-10-13

Independent [BLOCK](../reviews/2026-10-13-start-dex-sanity-review.md) at
`118cd11` proves the original 411-entry premise false. At pinned `c75f352`:
`include/constants/pokedex.h:6–426` enumerates Deoxys as 386 and defines
NATIONAL_DEX_COUNT as Deoxys; 411 is an old Unown enum entry, not the count.
`src/pokedex.c:29–49` counts 1–386; `src/start_menu.c:458–463` refuses selection
for zero seen. The 52-byte storage remains unchanged. Mirror-corruption
validation remains the explicitly excluded existing tracker layer.

Orchestrator authorizes the smallest correction within the same implementation
paths: change the erroneous existing tracker NATIONAL_DEX_COUNT/range bound
to 386, correct its old range tests as well as the new serialized-count tests,
and preserve the existing normal START wiring. This explicitly supersedes
"preserve behavior" only for the erroneous 387–411 tracker range. Valid
1–386 get/set semantics, 52-byte arrays, save schema and all other behavior
must remain unchanged. No new menu feature is authorized.

Acceptance includes literal source-derived #386 admitted, #387/#411/#416
excluded, all-set serialized bytes = 386, unchanged 52-byte shape, old zero/
one/cross-byte/malformed behavior, and getter/setter rejection above 386.
Use existing real StartMenu with synthetic serialized bytes to prove that
trailing-only seen flags leave the menu open and #386 permits selection;
retain the original live main.lua wiring for independent inspection. Tests
must fail against the old 411 implementation. No new test file is needed.

## MAY CHANGE (literal paths)

- `main.lua`: require a pure counter through the existing `Battle` table and pass the count when opening the normal field START menu; correct the stale comment about Dex acquisition.
- `src/core/DexTracker.lua`: read-only serialized seen counter plus correction of the existing National Dex bound to 386 as specified above; preserve 52-byte data model and valid-entry behavior.
- `tests/dex_tracker_test.lua`: source-bound counter/range cases and real StartMenu zero-seen integration using synthetic bytes; no private input.
- This task record.

Independent review records under `work/reviews/` may be added/appended by the
separate Reviewer; they are not Worker implementation authority.

## MUST NOT CHANGE

No save schema/codec, flags, story logic, importer, rendered Pokédex screen, menu item ordering, ROM/runner, workflows, private paths, P4/P5 routes, Phase 6 party task, external environment, or canonical capability status. The existing POKÉDEX selection action remains an explicitly unavailable UI stub; this fix only corrects the zero-entry admission guard.

## Verification and review

Check a clean diff for only the four allowed paths; run `lua5.1 tests/dex_tracker_test.lua` and `lua5.1 tests/start_menu_test.lua`, repository checker, and `bash scripts/test_all.sh` without a ROM. If local Lua is unavailable, report that limitation and use exact-head GitHub CI as the public no-ROM test evidence. A different reviewer must inspect the exact substantive branch head and source/behavior assertions before acceptance. Do not self-certify or merge from this worker context.

## Stop conditions

Stop if reference source disagrees with seen-count semantics, save-block seen is not a 52-byte string, a private ROM becomes necessary, or a required edit leaves the four-path boundary.

## Historical Worker handoff — 2026-10-09 (source bound superseded)

- Branch: `work/p6-start-menu-dex-count-20261009`; implementation and no-ROM tests at `01d2eeaa188fe44f58d1b50df22c4f52731a51bf`; draft PR #5.
- Diff inspected against pinned base `503ea1e674baed88a27050dc54efd961baed1c9e`: exactly the four allowed paths (`main.lua`, `src/core/DexTracker.lua`, `tests/dex_tracker_test.lua`, this task).
- [Exact-head public run 37945534748](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/37945534748): PASS; [same-head parallel run 37945504804](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/37945504804): PASS. Workflow installs Lua 5.1, invokes repository checks and `scripts/test_all.sh` without ROM. Local Lua is unavailable to this worker; no local execution/ROM/gameplay proof claimed.
- Semantics tested: zero/first/cross-byte seen entries, valid #411, ignored #412–416 trailing bits, all 411 seen, and absent/malformed bitfields; `StartMenu` already has its own blocked/unblocked test cases.
- **Reviewer needed:** independently inspect exact substantive diff and source semantics, including actual `main.lua` live session wiring. Re-run tests if warranted. No merged change, runtime gameplay proof or Phase 6 status advancement follows solely from these passing checks.

## Correction Worker handoff — 2026-10-14

- Corrected the tracker bound to the pinned source's literal 386; retained
  52-byte owned/seen arrays and the original limited normal START wiring.
  No menu implementation, save schema, mirror validation or ROM work added.
- Existing PR #5 remains the publication target on
  `work/p6-start-menu-dex-count-20261009`; no competing PR. Authority
  `4eb53da` was clean before work. Fresh main
  `3adc7e85654cd04f3244b8e072f5ba4ab8317e84` merged normally without conflicts
  at `e658387c1ab405639ecf7039cdc052e2fdd009a5` before correction and final
  regression. Local worktree: `/tmp/firered-start-dex-review-UA2MPZ`.
- Baseline no-ROM suite: 151 files PASS at authority head; after fresh-main
  integration, 166 files PASS before implementation. Both
  `POKEPORT_ROM` and `POKEPORT_RUNTIME_REPLAY` were unset for execution.
- Regression witness: new source-literal assertions run against the old 411
  implementation produced **39 passed / 17 failed**, exit 1. Failures include
  getter/setter acceptance of #387/#411, serialized trailing-bit counts,
  all-set total and real StartMenu acceptance of trailing-only bytes.
- Corrected focused checks: `lua5.1 tests/dex_tracker_test.lua` **56/0**;
  `lua5.1 tests/start_menu_test.lua` **21/0**. New cases admit #386, reject
  #387/#411/#416, count all-set bytes as 386, preserve both array shapes and
  zero/first/cross-byte/malformed behavior, and use actual StartMenu/InputState
  to verify blocked and permitted A-button selection.
- After correction: `bash scripts/test_all.sh` **PASS, 166 files, no-ROM**;
  `lua5.1 scripts/check_repository.lua` **PASS, 293 tracked Lua, 312 tracked
  Markdown, 1018 local targets**; `git diff --check` clean.
- Correction delta after the integration merge is only tracker, existing
  Dex tests and this task. Against fresh main, the original limited
  `main.lua` wiring remains, plus the already-authored independent BLOCK
  report. That report is byte-identical to authority `4eb53da` (SHA-256
  `6af5d62d3e482478c9a54bef82a19e1694e7237d373a3ce7a84017527cdcadbe`);
  Worker did not modify or override its verdict.
- Corrected tracker SHA-256:
  `5b37e33dd4bf44690ebadd1b9fc526bf5cee6434f50b7ee9888dfe8d3663724d`.
  Dex tests SHA-256:
  `affebb11d99e972a1ed618554b540c8853b589186d1dd8c20475c429caedfd7a`.
- Publication head and public CI receipts are to be returned to the
  Orchestrator for the same independent Reviewer's exact-revision recheck.
  Local passing checks are not acceptance, merge authorization or phase
  completion; no non-skipped ROM/runtime evidence is claimed.

### Final integration receipt — 2026-10-14

- Substantive correction `b832e956587227fd3c10e77085708d189396aca4`
  fast-forward published to existing PR #5. Exact-head public no-ROM runs
  [38544831616](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/38544831616)
  and [38544830211](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/38544830211)
  both completed SUCCESS.
- Fresh main advanced during publication to
  `f50383e` (disjoint confusion/flinch package). Merged normally without
  conflicts at `54a08d78c3209cb04fa585cd9d1661d90ef9c3f0` and repeated
  final integration verification: Dex **56/0**, StartMenu **21/0**, full
  **167-file no-ROM suite PASS**, checker **294 Lua / 316 Markdown / 1025
  targets PASS**, and `git diff --check origin/main HEAD` clean.
- No correction code changed during that integration; tracker/test hashes
  above remain exact. Final publication's CI and independent review remain
  separate exact-head gates; this receipt is not a Reviewer verdict.
