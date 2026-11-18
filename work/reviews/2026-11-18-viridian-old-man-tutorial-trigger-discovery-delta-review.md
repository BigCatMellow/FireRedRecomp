# Delta review — P5-07 Old Man tutorial-trigger discovery (PR #80), D1/D2

- reviewer: independent REVIEWER (Claude subagent; not the author)
- head_sha: `cc287e5afcec15e25122ea02657b5daefb14bf09`
- delta: `73091be..cc287e5`, one commit; only the report changes
- prior review: [2026-11-17 review](2026-11-17-viridian-old-man-tutorial-trigger-discovery-review.md) (NEEDS_FIX, D1/D2)
- independent: true
- Verdict: **PASS** (advisory; no ROM read and no LÖVE run)

## D1 — decode prose: RESOLVED

Each corrected statement matches the source:

- Row 12 is open only at x8 and x19–26.
- Row 9 is open at x8, x20–22, x29–32 and x39–41.
- Tiles (29..41,12) have behaviour `0x3B` `MB_JUMP_SOUTH` (`include/constants/metatile_behaviors.h:50`).
- The receipt now limits "no ledges" to the x=8 column.

Re-run of the independent path search (same rules as the prior review) with (20,8)/(22,8) also blocked: row 0 is unreachable, and row 8 is reached only at (8,8).

## D2 — elevation hardcode: RESOLVED

Admission now follows the decoded-event elevation contract, citing `src/core/ViridianRoadblock.lua:93–95`:

- `:94` refuses an unknown player elevation.
- `:95` treats event elevation 0 as a wildcard and otherwise requires equal elevation.

The report forbids a literal 3. The citation to P5-05 `phase5-viridian-northbound-gate-discovery.md:155` is correct: that line holds "Do not hardcode elevation 3".

## Author's corrections to the prior review's citations: verified

- The talk-to path is `scripts.inc:102` (the scene-1 branch to `TutorialStart`) plus `:123–125` (label, `call DoTutorialBattle`, `release`). The prior review's `:101,122–125` was off by one.
- P5-05's elevation line is `:155`, not `:154`. The prior review was off by one.

## Checks at head

- `git diff --name-only origin/main...HEAD` lists the two P5-07 files plus the prior review file. That review file is the reviewer-allowed addition.
- `lua5.1 scripts/check_repository.lua` PASS (336 Lua, 418 MD, 1370 targets).
- `git diff --check origin/main` is clean.

## Non-blocking

"Row 8 is open from x19 to x32" leaves out the other open spans, (8,8) and x39–41. The conclusion does not depend on them.
