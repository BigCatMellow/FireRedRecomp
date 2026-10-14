Verdict: **NEEDS_FIX** (behavior matches the source; two Medium test-evidence gaps, where acceptance criteria claim coverage that the tests do not assert, plus Low/informational documentation findings)

# Batch 3 status moves (fast lane): independent review

- Branch `claude/wizardly-faraday-o45q9z`, head `15f1874dc180311ae6d8fe4a4947e4d5f36d07c2`, base/merge-base `origin/main` `b3cf0407cd1f6731823df20f009d2f6c5f9057b9`.
- Task: [P4-FL3-STATUS-MOVES](../tasks/phase4-batch3-status-moves.md). Lane: AGENTS.md "Battle-effect fast lane" (AGENTS.md:84-115).
- Families: 25 Haze (114), 85 Splash (150), 142 Belly Drum (187), 143 Psych Up (244), 157 Softboiled (135 Soft-Boiled, 208 Milk Drink). Ordinary singles only.
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
- Reviewer: independent reviewer subagent. It did not construct the change. It modified, committed and pushed nothing in the checkout. Mutations ran on a scratch copy at `/tmp/claude-0/review3/repo`.

## Scope

- 8 files. All are MAY CHANGE paths or the task file (lane rule 1):
  `src/core/BattleEngine.lua` (+66/-1), `src/core/BattleSceneController.lua` (+11), `tests/battle_engine_test.lua` (+96),
  `tests/battle_scene_controller_test.lua` (+38), `tests/phase4_batch3_status_effect_rom_test.lua` (new, 39),
  `tests/phase4_move_effect_inventory_test.lua` (8/8), `work/reports/phase4-move-effect-inventory.md` (summary table plus rows 25/85/142/143/157),
  `work/tasks/phase4-batch3-status-moves.md` (new).
- No ROM bytes, extracted tables or binaries. The fixture holds literals derived from `battle_moves.h`, the same pattern as the accepted batch 1 and batch 2 fixtures.
- `git diff --check origin/main...HEAD` is clean.

## Source conformance

| Source (c75f352) | Implementation | Result |
| --- | --- | --- |
| `bs1.s:564-573` Haze: attackcanceler, attackstring, ppreduce, anim, `normalisebuffs`, `STRINGID_STATCHANGESGONE`. No accuracycheck or Random | `BattleEngine.lua:1159` excludes it from accuracy. Handler at `:1224-1233`. PP is spent by the shared ppreduce `:1184` | Match |
| `bsc.c:6826-6837` Cmd_normalisebuffs: every battler, every j < NUM_BATTLE_STATS (8, including the STAT_HP slot, `pokemon.h:166,178`) set to DEFAULT | Loops over player and foe and all `statStages` keys (the 7 real stages; the engine has no HP stage, and nothing reads the source's HP slot) | Match |
| `bs1.s:1168-1177` Splash: ppreduce, `incrementgamestat GAME_STAT_USED_SPLASH`, `STRINGID_BUTNOTHINGHAPPENED` | `:1220-1223` emits `splash`. The game stat is not modeled (task exclusion) | Match (game stat excluded) |
| `bs1.s:1772-1784` Belly Drum: ppreduce **before** `maxattackhalvehp BattleScript_ButItFailed`. Then attacker `healthbarupdate`/`datahpupdate`, then `STRINGID_PKMNCUTHPMAXEDATTACK` | `:1242-1256`. PP is spent before the gate. The controller inserts the HP entry before the text (`BattleSceneController.lua:269-272`) | Match |
| `bsc.c:8399-8418` Cmd_maxattackhalvehp: halfHp = maxHP/2, or 1 when that is 0. Succeeds iff ATK < 12 **and** hp > halfHp. Sets ATK = 12 and damage = max(1, maxHP/2) | `halfHP = max(1, floor(maxHP/2))`. Fails on `atk >= 12 or hp <= halfHP`. Subtracts halfHP. No clamp is needed because hp > halfHP | Match |
| `bs1.s:2054-2059` ButItFailed: `orbyte MOVE_RESULT_FAILED`, `resultmessage`. `bsc.c:1959-1960` gives "But it failed!" (no MISSED flag on this path) | `moveFailed`, which shows "But it failed!" | Match |
| `bs1.s:1786-1795` Psych Up: ppreduce, `copyfoestats BattleScript_ButItFailed`, `STRINGID_PKMNCOPIEDSTATCHANGES` | `:1234-1241`. Excluded from accuracy | Match |
| `bsc.c:8423-8433` Cmd_copyfoestats: copies all NUM_BATTLE_STATS from target to attacker. The jump pointer is unused, so the move never fails | Copies every defender stage key to the attacker. No fail path | Match |
| `bs1.s:2023-2042` Softboiled: ppreduce, `tryhealhalfhealth BattleScript_AlreadyAtFullHp, BS_TARGET`, then healthbar/datahp BS_TARGET, then `STRINGID_PKMNREGAINEDHEALTH`. On fail, `STRINGID_PKMNHPFULL` | Shares the accepted Restore HP branch `:1257-` (`restoreHP`/`restoreHPFull`) | Match in behavior; wording is a project choice (F5) |
| `bsc.c:6332-6347` Cmd_tryhealhalfhealth: only BS_ATTACKER rewrites the target. Otherwise it uses gBattlerTarget. Heal = max(1, maxHP/2). Fails iff hp == maxHP | See the BS_TARGET analysis below | Match |
| `bm.c:124,125,209,210,335,356` texts | Splash "But nothing happened!", Haze "All stat changes were\neliminated!", Psych Up "{ATK} copied\n{DEF}'s stat changes!", Belly Drum "{ATK} cut its own HP\nand maximized ATTACK!" (`BattleSceneController.lua:262-272`) | Match |
| `bmv.h:1485,1758,1953,2434,2707,3175`; `battle_move_effects.h:29,89,146,147,161`; `moves.h:118,139,154,191,212,248`; `pokemon.h:112` (TYPE_ICE=15), `:238-243` (flags); `include/battle.h:59-64` (targets) | Fixture `tests/phase4_batch3_status_effect_rom_test.lua:17-24`, checked field by field: Haze {25, ICE 15, acc 0, pp 30, USER 0x10, PROTECT 0x02}; Splash {85, 0, 0, 40, 0x10, 0}; Belly Drum {142, 0, 0, 10, 0x10, SNATCH 0x08}; Psych Up {143, 0, 0, 10, SELECTED 0, 0x08}; Soft-Boiled {157, 0, 100, 10, 0x10, SNATCH or MIRROR 0x18}; Milk Drink {157, 0, 0, 10, 0x10, PROTECT or SNATCH 0x0A}. All have power 0, chance 0 and priority 0. A grep of `bmv.h` finds exactly 6 members across the 5 effects | Match |
| First battle: `bsc.c:1003-1018` bypasses only *inside* `Cmd_accuracycheck`. Flag 2 is set only on `STRINGID_DEFENDERSSTATFELL` (`battle_controller_oak_old_man.c:1766-1772`) | None of these scripts has accuracycheck, so the Oak bypass never applies. The engine puts `needsAccuracyCheck` first in `tutorialAccuracy` (`:1167-1170`), which makes `tutorialAccuracy` false for all five. None of the handlers sets `tutorialPlayerStatDone`, and none of these moves prints DEFENDERSSTATFELL | Match |

### Softboiled BS_TARGET compared with Restore HP BS_ATTACKER (item 2)

`HandleAction_UseMove` sets `gBattlerTarget = gBattleStruct->moveTarget[attacker]` (`battle_main.c:4116`). The absent-battler redirect does not fire, because the user is present. For a MOVE_TARGET_USER move the controllers always set that target to the user:

- player: `battle_controller_player.c:460-461` (`gMultiUsePlayerCursor = gActiveBattler`). This also covers the Oak first battle, because `battle_controller_oak_old_man.c:338-340` calls the same `HandleInputChooseMove`.
- trainer AI: `battle_controller_opponent.c:1370-1371`.
- wild: `battle_controller_opponent.c:1393-1394`.

The Electric/Lightning Rod and Follow Me branches (`:4027-4040`) need a double battle or MOVE_TARGET_SELECTED, so they cannot apply. In singles, BS_TARGET therefore resolves to the attacker. Cmd_tryhealhalfhealth then computes exactly what it computes for Restore HP, and the script tail (`PresentHealTarget`, `bs1.s:2028-2036`) is the same one Restore HP's own tail mirrors. Reusing the Restore HP events is correct for singles. The only source differences are Snatch and Protect (the Milk Drink flag), and the task excludes both.

## Regression check (`resolveMove` / `supportsMove`)

- `supportsMove` (`BattleEngine.lua:932-942`) adds branches that only effects 25/85/142/143/157 reach. A source-only scan feeds every `battle_moves.h` record (ids 1-354) to `supportsMove`. Main gives 255/99 admitted/rejected and the head gives 261/93. The difference is exactly the six new members, which matches the inventory totals. The scan script is at `/tmp/claude-0/review3/scan/scan.lua`.
- The `needsAccuracyCheck` additions are keyed on these five effect ids only. The new handlers sit inside `move.power == 0` ahead of Restore HP and return. No other effect can reach them.
- `AICheckBadMove.lua:517,572,573` already scores 25/142/143 and is unchanged.
- The full no-ROM suite passes. No pre-existing test changed outside the diff. On main the engine count is 440 and the controller count 92. On the head they are 483 and 96.

## Assertions and mutations

- The oracles are literals from the scripts and commands: half of 101 = 50, the boundaries 51/50, ATK 12, maxHP 1, clamp 11, `rng.draws == 0` and PP literals. They are not read back from the implementation.
- Count arithmetic: per side, 6 admissions + 1 Splash + 1 Haze + 1 Psych Up + 5 Belly Drum + 6 Softboiled = 20. Two sides give 40, plus 3 admission rejections = 43, and 440 + 43 = 483 matches. Controller: 92 + 4 = 96. The ROM fixture prints "7 passed" (6 records + membership).
- The inventory partition test passes. The edits are 255 → 261 admitted, 99 → 93 rejected, represented 60/150/110/40 → 65/156/110/46 and candidate 10/12/4/8 → 5/6/4/2. The report summary table (`phase4-move-effect-inventory.md:37-41`) and rows 25/85/142/143/157 agree. The uncovered positive count (105 / 57 effects) is correctly unchanged, because all six moves have zero power.

Mutation run on the scratch copy (`/tmp/claude-0/review3/mut/run.sh`). The no-op control passes (483/96).

| # | Mutant | Result |
| --- | --- | --- |
| M1 | Belly Drum `hp <= half` becomes `hp < half` | caught (4 engine) |
| M2 | Belly Drum ceil(maxHP/2) | caught (4) |
| M2b | Belly Drum without the max(1) promotion | caught (2) |
| M2c | Belly Drum half of current HP | caught (4) |
| M3 / M4 / M4b | Haze on attacker only / defender only / player only | caught (2 each) |
| M5 | Psych Up skips evasion | caught (2) |
| M5b | Psych Up copies in reverse | caught (2) |
| M6 x5 | each effect put back under accuracycheck | caught (Soft 8, Splash 2+1, Haze 2+1, Belly Drum 10+1, Psych Up 2+1) |
| M7 / M7d / M7e / M7f | PP not spent: Belly Drum / Splash / Haze / Softboiled | caught |
| **M7c** | **PP not spent: Psych Up** | **SURVIVED** (F1) |
| M8 | Belly Drum message before the HP entry | caught (controller) |
| M8b | Belly Drum without the HP entry | caught (controller) |
| M9 | Belly Drum ATK gate `>` instead of `>=` | caught (2) |
| M10 / M10b | Softboiled any id / only 135 | caught |
| M12 / M12b | Belly Drum no ATK change / +6 relative | caught |
| M15 | Psych Up accepts any target | caught |
| M16 | Psych Up text with names swapped | caught (controller) |
| M17 | Splash emits moveFailed | caught |
| M18 | Softboiled not routed to the heal | caught (error) |
| M19 / M22 / M23 | Haze / Belly Drum / Splash text altered | caught (controller) |
| M20 | Splash/Haze/Belly Drum accept any target | caught |
| **M21** | **Softboiled accepts any target** | **SURVIVED** (F2) |
| M24 / M25 / M26 | power==0 gate dropped (user family / Psych Up / Softboiled) | survived (F3, Low) |
| M27 | Haze resets to 0 | caught |
| M28 | Belly Drum event hpRemaining wrong | caught |

## Test results

- `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY bash scripts/test_all.sh`: `PASS: 158 test files (no-ROM mode; ROM-dependent checks skip cleanly)`.
- `lua5.1 scripts/check_repository.lua`: `PASS: repository checks (284 tracked Lua, 287 tracked Markdown, 955 local targets)`.
- `tests/battle_engine_test.lua` 483/0. `tests/battle_scene_controller_test.lua` 96/0. `tests/phase4_move_effect_inventory_test.lua` partition checked, then a clean SKIP. `tests/phase4_batch3_status_effect_rom_test.lua` clean SKIP.

## Findings

1. **Medium: Psych Up PP is never asserted.** Location: `tests/battle_engine_test.lua` "psych up copies target stages" check (`:2071-2072`). Acceptance 1 says "PP −1 each". Every other family asserts `a.moves[1].pp`, but the Psych Up check does not, and mutant M7c (Psych Up skips ppreduce) survives. Source `bs1.s:1789` runs ppreduce. Fix: add `and a.moves[1].pp==9` to that check.
2. **Medium: Softboiled wrong-target rejection is not tested.** Location: `tests/battle_engine_test.lua`, admission checks at the end of the batch 3 block (`:2107-2112`). Acceptance 2 says "Admission rejects wrong target", but the target clause at `BattleEngine.lua:934` has no test, and mutant M21 survives. Fix: add `check("softboiled requires user target", not b:supportsMove({effect=157,power=0,target=SELECTED},135))`.
3. **Low: the power==0 admission gates are untested for all five families.** Locations: `BattleEngine.lua:933-941`; mutants M24-M26 survive. Real records all have power 0, so retail admission does not change. The gate is still part of the stated admission design. Fix: add one `power=40` rejection check per branch (user family, Psych Up, Softboiled).
4. **Low: a header comment is now false.** Location: `src/core/BattleEngine.lua:238-240` still says "Still explicitly not ported: ... (EFFECT_HAZE, ...). supportsMove() correctly rejects those." This change admits and ports Haze. Fix: remove EFFECT_HAZE from that list, or reword it to point at the batch 3 handler.
5. **Low (informational, pre-existing accepted design): Softboiled reuses non-source wording.** Location: `BattleSceneController.lua:216-220`. The texts are "X recovered HP!" and "X is already at full HP!". Source is `bm.c:124` "{DEF} regained\nhealth!" and `bm.c:125` "{DEF}'s\nHP is full!". The Restore HP design (`work/reports/phase4-restore-hp-design.md:138-140`) documents this as a project choice and the task states the reuse, so it does not block. It is now inconsistent with the four new batch 3 messages, which use the literal source texts. Suggest a follow-up task that switches both effects 32 and 157 to the source texts.
6. **Low (informational): the inventory text understates a limit and keeps stale prose.** Location: `work/reports/phase4-move-effect-inventory.md:190`. The Splash row drops the previous note that `incrementgamestat GAME_STAT_USED_SPLASH` is unmodeled, and the task excludes that game stat. Fix: append "game stat not modeled". Separately, `:349-352` still lists `Cmd_tryhealhalfhealth/normalisebuffs/maxattackhalvehp/copyfoestats` as inspections "for uncovered rows", and `:384` "Do not bundle Softboiled/Milk Drink" is now historical. Optional cleanup.

No Blocker or High findings. Every behavior check (conditions, boundaries, what is copied or reset, message texts and order, no accuracycheck or Random, PP before the gate, BS_TARGET equivalence, admission totals, fixture fields) matches the pinned source. NEEDS_FIX covers F1 and F2: test-only one-line fixes that make the stated acceptance criteria actually asserted. F3 and F4 should go in the same pass.

Signed: independent reviewer subagent; did not construct the change.

## Re-check (delta 15f1874..772a2cd)

Verdict: **PASS**

- The delta covers `src`, `tests` and `work/reports`. F1: `battle_engine_test.lua:2072` now asserts Psych Up PP 9. F2: `:2109` adds the Softboiled user-target rejection. F3: `:2110-2113` adds power-40 rejections for all five families. F4: the `BattleEngine.lua:238-241` comment no longer lists Haze. F6: inventory row 85 now says "game stat not modeled", and the stale prose at `:349-351` and `:386-387` is updated. No behavior code changed.
- I re-ran the surviving mutants on a fresh copy of 772a2cd. The no-op control passes (485/96). All are now caught: M7c (2 failures), M21 (1), M24 (1), M25 (1), M26 (1).
- `scripts/test_all.sh`: `PASS: 158 test files`. `check_repository.lua`: PASS (288 Markdown, 957 targets). `git diff --check` is clean. Engine 485/0.
- F5 (Softboiled/Restore HP wording) stays open as a documented follow-up. It is accepted existing design and does not block.

Signed: independent reviewer subagent; did not construct the change.
