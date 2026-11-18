# Review — P5-07 Viridian Old Man tutorial-trigger field-side discovery (PR #80)

- reviewer: independent REVIEWER (Claude subagent; not the author)
- head_sha: `7d1c94bc741a27ddf8edb8e0656a0ab7244f762b`
- base: origin/main `df53c7770c1df5884f4c3924e331c5efebe91925` (merge-base equals it)
- source: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788` (checkout HEAD equals the pin; `git status --short` empty)
- independent: true
- Verdict: **NEEDS_FIX** (two bounded report defects; the core finding is confirmed)

The verdict is advisory. No ROM read and no LÖVE run.

## Checks

| # | Check | Result | Evidence |
| --- | --- | --- | --- |
| a | C2/C3 coords, var, value, elevation | PASS | `map.json:221–238` gives (20,8)/(22,8), elevation 3, `VAR_MAP_SCENE_VIRIDIAN_CITY_OLD_MAN`, value "1", Left/Right scripts. `include/constants/vars.h:133` sets the var to `0x4051`. The predicate is `field_control_avatar.c:1039` plus `:1055` (equal elevation or event elevation 0). Coord events run before warps (`:620–623`). Scene-1 placement is `scripts.inc:8,17–21`, object `map.json:77–91`. The layout tiles (20,8)/(22,8) have elevation 3. |
| b | Script order up to the battle special | PASS | `scripts.inc:202–229` matches line for line: lockall 203/214; man turn 205/216; player turn 207/218; call 209/220; msgbox/closemessage 225–226; questlog 227; CutRecording 228; special 229. After it: waitstate 230, lock/faceplayer 231–232, setvar 2 at 234, giveitem 235, return 237. Release/end at 210–211/221–222. The movements are at `movement.inc:28–30,36–38`. `scrcmd.c:99–106` (special returns FALSE, so no wait), `:127–130` (waitstate), `:1195–1256` and `:1239,1253` all verified. |
| c | Engine falls through to the wild roll | PASS | `main.lua:1084–1093`. `ViridianRoadblock.lua:74,77` returns `not_selected` off (22,11) or at scene ≠0. `EarlyStory.lua:72,91,96` are Pallet/lab-only branches (no other `mapId ==` branch). `ViridianOldManProjection.lua:46–47` handles placement only. `ScriptBytecode.lua:377–379` decodes 0x27 as `unimplemented` (re-run). The grep finds no runtime tutorial/Teachy hit. |
| d | Cannot be skipped before Cut (recomputed) | PASS on conclusion; **FAIL on decode prose** | Independent BFS over `map.bin` plus both `metatile_attributes.bin` (`&0x1ff`). Rules: collision 0, no water behaviours, elevation equal or 0/15, ledges one-way. Start at the south edge; exclude (21,8) (man) and (18,5) (Cut tree). Result: row 0 reachable at x19–23. With (20,8)/(22,8) also excluded, row 0 is unreachable and row 8 is reached only at x8. See D1. |
| e | No battle design; post-battle state UNKNOWN | PASS | Report :121–124 and :204–207 state that party, bag and saved state are UNKNOWN with no rollback or restore assumed. The outside-dependency section (:126–138) records the unreviewed battle-lane finding only, and builds nothing on it. |
| f | No re-inventory of P5-05 | PASS | P5-05 (`phase5-viridian-northbound-gate-discovery.md:22–23,58–64,76–84`) holds the admission rows, an order summary and the tutorial-path anchors. This PR cites them and adds new facts at file:line depth (decode, runtime gap, UNKNOWNs). The admission table repeats only the two rows, which is acceptable. |
| g | P5-07 gate bounded, fails closed | PASS with defect D2 | Two docs paths. The gate refuses at the battle special, with no scene 2, no Teachy TV and no silent pass. Stops are listed. The elevation wording conflicts with P5-05 (D2). |
| h | Exactly 2 files; checks | PASS | `git diff --name-only origin/main...HEAD` lists the two files. `lua5.1 scripts/check_repository.lua` PASS (336 Lua, 417 MD, 1370 targets). `git diff --check origin/main` clean. Both were re-run at `7d1c94b`. |

## Defects (required fixes)

**D1. Decode prose is factually wrong (report :62–70, :218).**
- "Row 9 is open only at x20–22" is false. In the collision-only print, row 9 is also passable at x8, x29–32 and x39–41.
- The receipt "and no ledges" is also false. Tiles (29..41,12) have behaviour `0x3B` `MB_JUMP_SOUTH` (`include/constants/metatile_behaviors.h:50`) and collision 1.
- That south-only ledge row is the actual reason the east/gym-front pocket (x29–41, rows 4–11) is not a northbound bypass. The report asserts that this pocket "connects only to the north" without naming the cause.

Required fix:
- Correct the row-9 statement. The chokepoint is row 12, which is open only at x8 and x19–26.
- Name the row-12 `0x3B` ledges as the reason the east pocket is one-way.
- Correct the receipt so it says no ledges in the x=8 column only.

**D2. The gate admission hardcodes elevation (report :164).**
- "(20,8)/(22,8) and elevation 3" conflicts with P5-05 :154 ("Do not hardcode elevation 3").
- C0's actual contract (`ViridianRoadblock.lua:93–95`) compares the decoded event elevation with the effective player elevation. Event elevation 0 is a wildcard, and an unknown player elevation is refused.

Required fix: state that admission matches the decoded C2/C3 event elevation under that same contract, not a literal 3.

## Non-blocking observation

`scripts.inc:101,122–125`: talking to the man at scene 1 also enters `DoTutorialBattle`. That path sets `gSelectedObjectEvent` (`field_control_avatar.c:426/452`), unlike C2/C3. It is outside the agreed C2/C3 split. The report's UNKNOWN on the `lock`/`faceplayer` target remains correct as worded.
