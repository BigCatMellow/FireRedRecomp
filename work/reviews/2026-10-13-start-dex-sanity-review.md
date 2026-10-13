# START Pokédex count guard — independent review

Verdict: **BLOCK** for `P6-03-START-DEX-SANITY` at exact PR #5 head
`118cd11e6925da143027810200ff17e04e45e52f` (substantive implementation
`01d2eeaa188fe44f58d1b50df22c4f52731a51bf`; task baseline
`503ea1e674baed88a27050dc54efd961baed1c9e`). The task's explicit stop condition
applies: the pinned source disagrees with its 411-entry count semantics.
Passing tests do not resolve that contradiction. Do not merge this revision.

Review performed independently on 2026-10-13 in an isolated detached worktree.
Canonical AGENTS/Reviewer rules were read at main `a49e103`; the exact branch
task is READY_FOR_REVIEWER. The Orchestrator explicitly assigned this disjoint
review while reconciling stale global effect-45 coordination. No implementation,
coordination, ROM, runner, replay, or publication changes were made.

## Blocking source/contract contradiction

At verified public pret/pokefirered revision
`c75f352304d529f6ba92d4f74b9cf8b5c3810788`:

- `include/constants/pokedex.h:6-420` enumerates `NATIONAL_DEX_NONE = 0`,
  `NATIONAL_DEX_DEOXYS = 386`, then old Unown entries through
  `NATIONAL_DEX_OLD_UNOWN_Z = 411`. Independent enumeration of the header
  confirms those literal values.
- `include/constants/pokedex.h:426` defines `NATIONAL_DEX_COUNT` as
  `NATIONAL_DEX_DEOXYS`, not the final enum entry.
- `src/pokedex.c:29-49` counts only National Dex entries **1–386**.
  `src/start_menu.c:458-463` refuses Pokédex selection when that count is zero.
- The existing `DexTracker.NATIONAL_DEX_COUNT = 411` is therefore a pre-existing
  source-label error. The new `countSeenSaveBytes` uses it, and the new tests
  specifically require #411 to count and an all-set array to return 411.
  This newly wires the wrong bound into the live START guard.

Read-only Lua witnesses exercised the exact `world.openStartMenu` function
extracted from this revision, with the real DexTracker and StartMenu modules,
session-shaped synthetic bytes, and A-button input:

| Seen bits | Actual count / menu after A | Source-bound expected result |
| --- | --- | --- |
| None (owned bytes all set) | 0 / open | 0 / open |
| #1 only | 1 / selected | 1 / selected |
| #386 only | 1 / selected | 1 / selected |
| #387 only | 1 / selected | **0 / open** |
| #411 only | 1 / selected | **0 / open** |
| All 52 bytes set | 411 / selected | **386** / selected |

The 52-byte storage size is correct and distinct from the counting bound.
No save-schema change is needed. The task must first replace its incorrect
"post-411" acceptance/handoff assertions with the source boundary. A bounded
Worker correction can then cap the serialized count at 386 and assert #386,
#387, #411 and #416 boundaries plus all-set = 386. Orchestrator must explicitly
resolve whether correcting the existing tracker constant/range tests is in
scope under "preserve existing tracker data model/behavior"; Reviewer did not
silently broaden that authority or implement either option.

## Other reviewed evidence

- Exact baseline-to-head diff contains only the four authorized paths:
  `main.lua`, `src/core/DexTracker.lua`, `tests/dex_tracker_test.lua`, and the
  task. No ROM, extracted content, generated cache, workflow or schema edits.
- Normal wiring is otherwise correct: `Battle.DexTracker` is required;
  `world.openStartMenu` reads `newGame.session.state.saveBlock2.pokedex.seen`
  (not owned) and passes the result to the existing menu guard. New-game
  initialization at `main.lua:333-334` supplies 52-byte strings; saved-session
  reconstruction retains the decoded save state. The unavailable Pokédex UI
  action and menu ordering are unchanged.
- Missing/malformed bytes return nil and retain the existing unspecified-count
  menu behavior. This is not proof of malformed-save handling.
- Source `src/pokedex_screen.c:2239-2247` additionally checks seen mirror
  agreement. The existing tracker explicitly excludes that corruption-detection
  layer; the task addresses a valid seen array. No mirror-corruption parity is
  claimed or newly required by this review.

## Independently reproduced checks

With both `POKEPORT_ROM` and `POKEPORT_RUNTIME_REPLAY` unset:

- `lua5.1 tests/dex_tracker_test.lua`: **21/0**.
- `lua5.1 tests/start_menu_test.lua`: **21/0**.
- `lua5.1 scripts/check_repository.lua`: **PASS**, 276 tracked Lua,
  204 tracked Markdown, 616 local targets (before this untracked review).
- `bash scripts/test_all.sh`: **PASS**, 151 test files, no-ROM mode.
- `git diff --check 503ea1e674baed88a27050dc54efd961baed1c9e HEAD`: clean.

Live PR #5 was independently recovered as open/draft at the exact head above.
Public CI metadata confirms completed SUCCESS at that exact head for
[pull-request run 37945677448](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/37945677448)
and [push run 37945670727](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/37945670727).
These green checks enforce the incorrect 411 oracle; they are not source parity.

## Exact next allowance

Orchestrator may correct/re-scope this existing four-path contract using the
pinned 386 boundary, then dispatch the smallest Worker correction and an
independent exact-revision recheck. Keep PR #5 unmerged until that passes.
No ROM/bridge work, Pokédex screen implementation, unrelated P6 work, or phase
completion is authorized or established by this review.
