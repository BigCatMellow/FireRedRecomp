# Two-stat self UP batch (fast lane): independent review

Verdict: **PASS** for branch `claude/wizardly-faraday-o45q9z` head
`d55ad2578ecec916fddd9889167a98d88666927e` against base `origin/main`
`e44ba3347295d29604ea3873e16905c303eb4fd5`. Covers effects 206 Cosmic Power (322),
208 Bulk Up (339), 211 Calm Mind (347) and 212 Dragon Dance (349), in ordinary singles only.
One low-severity process finding is listed below. It does not block merge, but it should be
fixed in this PR or during merge reconciliation. The ROM fixture is still pending.

- Task: [P4-FL1-DUAL-STAT-UP](../tasks/phase4-dual-stat-up-batch.md). Lane: AGENTS.md "Battle-effect fast lane".
- Reviewer: independent reviewer subagent. It did not construct the change, and it modified, committed and pushed nothing.
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.

## Scope

- The diff touches 7 files: the 6 MAY CHANGE paths plus the task file. Lane rule 1 allows the task file.
  The 6 paths are `src/core/BattleEngine.lua` (+37), `src/core/BattleSceneController.lua` (+3),
  `tests/battle_engine_test.lua` (+58), `tests/battle_scene_controller_test.lua` (+34),
  `tests/phase4_dual_stat_up_effect_rom_test.lua` (new, 32), `tests/phase4_move_effect_inventory_test.lua` (7/7).
- No ROM bytes, extracted tables or binaries. `git diff --check` is clean. Merge-base equals `origin/main`.

## Source conformance

| Source (c75f352) | Implementation | Result |
| --- | --- | --- |
| `bs1.s:2679-2788`: setstatchanger order DEF→SPDEF, ATK→DEF, SPATK→SPDEF, ATK→SPEED | `BattleEngine.lua:563-568` table; ordered `ipairs` at `:1206` | Match |
| `jumpifstat ATK-stat < MAX → anim; else jumpifstat 2nd == MAX → CantRaiseMultipleStats` (fails only if both are at MAX) | `:1202` `first == 12 and second == 12` → `statsWontRise` | Match |
| `ChangeStatBuffs` `bsc.c:6795-6812`: a stat at MAX stays clamped, `B_MSG_STAT_WONT_INCREASE`, WORKED with ALLOW_PTR; script `jumpifbyte` skips the message | `:1207` only raises a stat below 12; nothing is emitted for a maxed stat | Match |
| No `accuracycheck` and no Random in any of the 4 scripts | `:1103` `and not dualStatUp` excludes them from `needsAccuracyCheck` | Match |
| `ppreduce` runs before both jumpifstat checks | Shared ppreduce at `:1125` runs before the `power == 0` branch, including on fail | Match |
| `bm.c:311` `sText_StatsWontIncrease2` "{ATK}'s stats won't\ngo any higher!" | `BattleSceneController.lua:259-261` | Match |
| `bm.c:306` `sText_AttackersStatRose` "{ATK}'s {BUFF1}\n{BUFF2}" (rose!) | Existing `statChange` message with stages=1 | Match |
| `bmv.h:4189/4410/4514/4540`: power 0, target `MOVE_TARGET_USER` | `supportsMove` `:900-902` requires power 0 and target == 0x10 | Match |
| `BattleScript_CantRaiseMultipleStats` `orbyte MOVE_RESULT_FAILED`; skipped-stat `MOVE_RESULT_MISSED` (`bsc.c:6806`) | Not represented (no consumer); the task lists this as excluded | Excluded, acceptable |
| Oak first-battle stat tip fires only on `STRINGID_DEFENDERSSTATFELL` (`battle_controller_oak_old_man.c:1768`) | The new path sets no tutorial flag or tip | Match |

## Regression check (`resolveMove`)

- `dualStatUp` is non-nil only for effects 206/208/211/212. `isSelfTargetStat`, `screenStatusKey`, the other
  accuracy exemptions, `tutorialAccuracy` (which needs `needsAccuracyCheck`), the effect-45 miss path and the
  single-stat `STAT_STAGE_MOVES` path behave as before.
- Auto-Struggle and the noPP guard come earlier in the function, and Struggle's effect is not in the table.
- `supportsMove` adds a branch that only these 4 effects reach. It did not exist before, so moves 322/339/347/349
  used to be rejected. The controller menu gate (`BattleSceneController.lua:352`) now admits them.
- `AICheckBadMove.lua:599-603` already scores these effects and is unchanged.

## Assertions checked

- The engine oracles are literal stat names from the battle scripts (`battle_engine_test.lua:1827-1832`), not values read from `DUAL_STAT_UP_MOVES`.
- Each family and side is tested for: +1/+1 in order (stages 7/7), PP 20→19, zero draws, an untouched RNG sentinel and an untouched defender.
  The tests also cover a maxed first stat, a maxed second stat and both stats maxed (PP spent, zero draws), and admission with target 0 or power 40.
  That is 56 new checks (4 × 14), and 332 + 56 = 388 matches.
- Mutation run on a scratch copy; the checkout was untouched. All 9 mutants were caught:
  - wrong stat order for DD or CP: caught by 2 engine checks; DD is also caught by 1 controller check;
  - either-stat-maxed fail gate: 16 failures;
  - first-stat-only gate: 8;
  - no fail gate: 8 + 1;
  - accuracy check re-enabled: 40 + 2;
  - no PP spent on fail: 8;
  - ungated admission: 8;
  - stages=2 in the event: 8 + 1.
- Controller: the real engine events produce ATTACK rose! before SPEED rose!, and the both-maxed case gives the exact `StatsWontIncrease2` text with no "rose!".
- ROM fixture: types Psychic 14 / Fighting 1 / Psychic 14 / Dragon 16, power 0, accuracy 0, pp 20, sec 0,
  target 0x10, priority 0 and flags 0x08 (`FLAG_SNATCH_AFFECTED` = 1<<3) all match `bmv.h`. Membership is exactly 4.
  The style matches `phase4_recoil_if_miss_effect_rom_test.lua`.
- Inventory arithmetic: 4 zero-power rows move from candidate to represented and from not admitted to admitted.
  - represented: 53→57 families, 142→146 moves, zero 35→39.
  - candidate: 17→13 families, 20→16 moves, zero 13→9.
  - admitted: 250→254; rejected: 104→100.
  - Positive and uncovered-positive counts are unchanged. Correct.

## Test results (local, no ROM)

- `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY bash scripts/test_all.sh`: PASS, 156 test files.
- `lua5.1 scripts/check_repository.lua`: PASS (282 Lua, 283 Markdown, 931 local targets).
- `battle_engine_test` 388/0, `battle_scene_controller_test` 89/0, `phase4_move_effect_inventory_test` partition PASS
  (ROM section skipped), `phase4_dual_stat_up_effect_rom_test` skips cleanly. **ROM fixture pending** until the next guarded bridge run.

## Findings

1. **Low (process).** AGENTS.md:107-108 says that until the verified-ROM run "the inventory notes `ROM fixture pending`".
   The PR marks rows 206/208/211/212 `represented` (`tests/phase4_move_effect_inventory_test.lua:218,220,223,224`)
   but adds no such note anywhere in the inventory. The prose inventory `work/reports/phase4-move-effect-inventory.md:311-317`
   still says `no / C`. That file is outside this MAY CHANGE, and it was already stale before this PR (effect 45 is still `C`, totals 248/106).
   Fix: add `-- ROM fixture pending (phase4_dual_stat_up_effect_rom_test)` to those 4 row comments, and have the
   orchestrator update the report rows during merge reconciliation.
2. **Info (test strength).** `battle_engine_test.lua:1863` (first stat maxed) does not assert `ev[2].type=="statChange"` or `ev[2].stage==7`;
   it checks state only. The controller test (`battle_scene_controller_test.lua:338-369`) covers only Dragon Dance on the player side.
   Neither gap hides a defect: the mutants above are caught.
3. **Info (cosmetic).** `phase4_dual_stat_up_effect_rom_test.lua:20` scans from id 1 where the precedent scans from 0. Sentinel 0 is effect 0, so this is harmless.
   The pass count of 5 in `:32` is a fixed string, the same as the precedent's.
4. **Info (pre-existing, out of scope).** The single-stat path at `BattleEngine.lua:1241-1245` emits `tutorialTip` "stat" for any successful player stat move, including self-UP.
   The source triggers it only on `STRINGID_DEFENDERSSTATFELL` (`battle_controller_oak_old_man.c:1768`). The new path correctly does not emit the tip.

## Result

PASS. Families 206/208/211/212 may be reconciled as `represented` (ordinary singles), marked "ROM fixture pending",
with the task's exclusions kept: Snatch, Substitute/abilities, move-result flags, animation and doubles.
