Verdict: **NEEDS_FIX** (runtime behavior matches the source on every represented path checked; one Medium test-evidence gap lets the per-kick accuracy-stage rule regress undetected, plus Low oracle/citation findings)

# Triple Kick (fast lane batch 5): independent review

- Branch `claude/wizardly-faraday-o45q9z`, head `9d978b03d35ed00222c5a6da618475bb966075c4`, base `origin/main` (merge-base `b3dfb91`).
- Task: [P4-FL5-TRIPLE-KICK](../tasks/phase4-triple-kick.md). Lane: AGENTS.md "Battle-effect fast lane".
- Family: 104 Triple Kick (167). Ordinary singles only.
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788` (`bs1.s` = data/battle_scripts_1.s, `bsc.c` = src/battle_script_commands.c, plus src/battle_main.c, src/battle_util.c, src/pokemon.c, src/data/battle_moves.h, include/constants/*).
- Reviewer: independent reviewer subagent. It did not construct the change. Nothing was modified, committed or pushed in the checkout. Mutations ran on a `git archive HEAD` copy at `/tmp/claude-0/review5/repo` (harness `/tmp/claude-0/review5/mut/run.py`, `run2.py`).

## Scope

- 7 files, all MAY CHANGE paths or the task file: `src/core/BattleEngine.lua` (+59), `tests/battle_engine_test.lua` (+54), `tests/battle_scene_controller_test.lua` (+31), `tests/phase4_move_effect_inventory_test.lua` (4/4), `tests/phase4_triple_kick_effect_rom_test.lua` (new, 28), `work/reports/phase4-move-effect-inventory.md` (summary, uncovered list, row 104), `work/tasks/phase4-triple-kick.md` (new).
- No pre-existing test line removed or changed except the inventory row and totals.
- No ROM bytes, extracted tables or binaries. The fixture holds literals from `battle_moves.h:2174-2185`.
- `git diff --check origin/main...HEAD` is clean.

## Source conformance

| Source (c75f352) | Implementation | Result |
| --- | --- | --- |
| `bs1.s:1380-1385` attackcanceler → attackstring → ppreduce, **no outer accuracycheck**; `sethword sTRIPLE_KICK_POWER, 0`; `setmultihit 3` | Excluded from `needsAccuracyCheck` (`BattleEngine.lua:1183`), so `hit = true` and PP drops at `:1208`; loop `for _ = 1, 3` (`:1898`) with `power = 0` | Match |
| `bs1.s:1387` `jumpifhasnohp BS_ATTACKER` → End | Not ported | Unreachable in represented state: no recoil or contact-damage ability/item can hurt the attacker mid-loop |
| `bs1.s:1388` `jumpifhasnohp BS_TARGET` → NoMoreHits (count kept, hit text printed) | `if defender.hp <= 0 then break end` (`:1899`); `multiHit` still emitted (`:1931`) | Match |
| `bs1.s:1389-1390` Sleep Talk / attacker-asleep check | Not ported | Excluded (no sleep status in engine) |
| `bs1.s:1392` `accuracycheck NoMoreHits, ACC_CURR_MOVE` each kick; `bsc.c:1003-1103` stage-adjusted accuracy, one `Random()` | `BattleFormulas.accuracyCheck(move.accuracy, acc, evasion, rng)` per kick (`:1900-1901`) | Match. Stage use is untested (F1) |
| `bsc.c:1007-1018` FIRST_BATTLE bypass for player damaging moves | Triple Kick skips the engine's `tutorialAccuracy` path and rolls each kick | Deviation in an unreachable case: Oak's first battle has fixed Lv5 starters, none with Triple Kick. Declared excluded in the task |
| `bs1.s:1393` `movevaluescleanup` (`bsc.c:3469-3478`): clears result flags, crit multiplier and dmgMultiplier; runs **after** accuracy, so a miss keeps the previous kick's effectiveness flags | Fresh `isCrit`/`flags` locals each kick | Match for HP and RNG. Effectiveness text timing differs (F5) |
| `bs1.s:1394,1396` `addbyte sTRIPLE_KICK_POWER, 10`; `copyhword gDynamicBasePower`; `pokemon.c:2398-2401` powerOverride | `power = power + 10`; `setmetatable({power=power},{__index=move})` (`:1905-1906`) | Match (10/20/30) |
| gDynamicBasePower reset | `bsc.c:1209-1222` Cmd_damagecalc does **not** reset it (`:1231` is AI_CalcDmg). Resets are at `battle_main.c:3695` (turn start) and `:4471` (HandleAction_ActionFinished) | Engine keeps power local, so the behavior is right. The task's citation is wrong (F4) |
| `bs1.s:1395` `addbyte sMULTIHIT_STRING+4, 1`: after accuracy, before damage, so a miss does not count and an immune kick does | `hits = hits + 1` after `applyDamage` (`:1921`) | Equivalent: an immune kick can only be kick 1 (types are fixed), and `bs1.s:1426` DOESNT_AFFECT then suppresses the hit text. A missed kick is not counted in either |
| `bs1.s:1397` critcalc: `bsc.c:1196-1203` evaluates `Random()` before the FIRST_BATTLE flag test | `critRoll(rng, 0)` per kick, first-battle suppression after the roll (`:1907-1908`) | Match (same convention as the other paths) |
| `bs1.s:1398` damagecalc: base × crit (`bsc.c:1209-1222`); `pokemon.c:2385+` `attack*power*(2L/5+2)/def/50`, Reflect only when not crit, `+2` | `calculateBaseDamage(..., kick, isCrit, sideStatus[defenderSide])`, then `× CRIT_MULTIPLIER` | Match. Reflect is untested here (F2) |
| `bs1.s:1399-1401` typecalc → adjustnormaldamage (`bsc.c:1577-1580` `ApplyRandomDmgMultiplier` first) → `jumpifmovehadnoeffect`: random **before** the no-effect check. Contrast `bs1.s:625-627` MultiHitLoop: check before adjustnormaldamage | typeCalc → `applyRandomDamageMultiplier` → `if flags.noEffect` (`:1912-1918`) | Match. Focus Band/Endure branches excluded (no held items or Endure state) |
| Per-kick RNG order: accuracy, crit, damage random | Same | Match (asserted by draw counts and the crit-on-kick-2 vector) |
| `bs1.s:1402-1413` per-kick HP update, critmessage | `critical` then `damage` event per landed kick | Match (event order uses the existing project convention) |
| `bs1.s:1414` `moveendto MOVEEND_NEXT_TARGET` (cases 0-15 per kick: Rage, Defrost, Synchronize, abilities, King's Rock/Shell Bell, ...; `battle_script_commands.h:124-140`, `bsc.c` Cmd_moveend, `battle_util.c:2995-3011`) | Not ported | No effect in represented state: no Rage, freeze, abilities or held items. King's Rock rolls `Random()` only when the attacker holds a FLINCH item. Future note (F7) |
| `bs1.s:1415` FOE_ENDURED stop | Not ported | Excluded (no Endure state) |
| `bs1.s:1418-1421` NoMoreHits: count 0 → PrintStrings with MISSED; otherwise `bicbyte MISSED` | `hits == 0` → `miss`/`noEffect` (`:1923-1929`); otherwise only `multiHit` | Match |
| `bs1.s:1422-1429` resultmessage; count 0 or DOESNT_AFFECT → End; otherwise `STRINGID_HITXTIMES` (`battle_message.c:82`) | `multiHit` → "Hit N time(s)!" (`BattleSceneController.lua:301-308`) | Match |
| `bs1.s:1430-1432` End: `seteffectwithchance` (`bsc.c:2789`, `Random()` evaluated with effect byte 0) on **every** path, first-kick miss included; then `tryfaintmon BS_TARGET` | No roll. The defender faint is handled by `runTurn`'s `checkFaint(otherSide)` after `resolveMove` returns (`:2148`), so the order is hit count then faint | Faint order matches. Roll not spent, so engine/source draws are 9/10, 4/5, 1/2 and 3/4 (F3) |
| `bs1.s:1433` `moveendfrom MOVEEND_UPDATE_LAST_MOVES` | Not ported | No last-move or Mirror Move state |
| `battle_moves.h:2174-2185`; `moves.h:171`; `battle_move_effects.h:108`; `pokemon.h:98,238-243`; `battle.h:59` | Fixture: {104, 10, FIGHTING 1, 90, 10, 0, target 0, priority 0, CONTACT\|PROTECT\|MIRROR\|KINGS_ROCK = 0x33}. `grep` finds exactly one `EFFECT_TRIPLE_KICK` member | Match |

Oracle check (`pokemon.c` physical path): Lv20 gives `2*20/5+2 = 10`. Power 10: `40*10*10/40/50 = 2`, `+2 = 4`. Power 20: `4+2 = 6`. Power 30: `6+2 = 8`. Crit at power 20: `6*2 = 12`, from `bsc.c:1215` (`× gCritMultiplier` after `+2`). Random draw 0 gives ×100/100. A 99 accuracy draw gives `100 > 90`, a miss. A crit draw of 0 gives `0 % 16 == 0`, a crit. Total 4+6+8 = 18, so HP goes 200 → 182. KO vector: HP 10 − 4 − 6 = 0 on kick 2. These numbers come from the source, not from the implementation.

## Regression check

- The only shared-path edit is the extra `~= EFFECT_TRIPLE_KICK` term in `needsAccuracyCheck` (`:1183`) and the new branch (`:1485`), both keyed on effect 104. Effect 104 is in none of the earlier early-return tables (multi-hit, fixed, current-HP, Endeavor, Psywave, OHKO). Before this change it reached the ordinary fallback hit (outer accuracy, one power-10 hit). No other effect's RNG count or event order can change.
- `resolveTripleKick` never calls `checkFaint`, so all four `runTurn` callers (move order `:2148`; switch, capture and run branches) do the faint check and forced-switch handling after the loop.
- The existing `resolveMultiHit` calls `checkFaint` inside its loop (faint before the count). Triple Kick follows the source order instead (count, then faint). The two now differ, but Triple Kick's order is the source's.
- No pre-existing test changed. Main: engine 521, controller 98. Head: 533, 100.

## Assertions and mutations

Count arithmetic: 6 engine checks × 2 sides = 12, and 521 + 12 = 533. Controller 98 + 2 = 100. The ROM fixture prints "2 passed" (membership + record).

Inventory: represented 67/159/113 becomes 68/160/114 and candidate 3/3/1 becomes 2/2/0, matching `expectedClasses` and the summary table (`phase4-move-effect-inventory.md:37-38`). The uncovered list at `:56` now has 54 effects with 104 removed. A recount of the `yes / B` rows gives 101 records, matching `admitted_uncovered_positive = 101` and the text "None is a candidate record; all 101". Row 209 format matches the other fast-lane rows.

| Mutation (scratch copy) | Result |
| --- | --- |
| Outer accuracy check kept | Caught (engine ×10, controller) |
| Power constant 10 | Caught (engine ×6) |
| Power = move.power per kick (no accumulation) | Caught (engine ×6) |
| Damage random after the no-effect check | Caught (engine ×2) |
| Miss text after landed kicks | Caught (engine ×2, controller) |
| Count includes the missed kick | Caught (engine ×2, controller) |
| No loop stop on KO | Caught (engine ×2) |
| Faint before the hit count | Caught (engine ×2) |
| Crit sticks to later kicks | Caught (engine ×6) |
| Crit roll before accuracy | Caught (engine ×12, controller ×2) |
| No-effect reported as miss | Caught (engine ×2) |
| PP not spent | Caught (engine ×4) |
| Crit not doubled | Caught (engine ×2) |
| Crit always suppressed | Caught (engine ×2) |
| Loop of 2 | Caught (engine ×4) |
| Extra trailing roll | Caught (engine ×4) |
| **Evasion stage ignored (fixed 6)** | **Survived** (F1) |
| **Accuracy/evasion stages swapped** | **Survived** (F1) |
| **Defender Reflect ignored (`{}` sideStatus)** | **Survived** (F2) |

## Test results

- `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY bash scripts/test_all.sh`: PASS, 160 test files (no-ROM). The new fixture is discovered and skips.
- `lua5.1 scripts/check_repository.lua`: PASS (286 Lua, 291 Markdown, 969 local targets).
- `tests/battle_engine_test.lua` 533/0; `tests/battle_scene_controller_test.lua` 100/0; `tests/phase4_move_effect_inventory_test.lua` partition PASS, ROM part SKIP; `tests/phase4_triple_kick_effect_rom_test.lua` SKIP (no ROM).

## Findings

- **F1 Medium: per-kick accuracy stages are unasserted.** The family's main rule is a fresh stage-adjusted `accuracycheck ACC_CURR_MOVE` on every kick (`bs1.s:1392`, `bsc.c:1046-1061`). All tests run at neutral stages (`tests/battle_engine_test.lua:2218-2270`). A `resolveTripleKick` that ignores evasion or swaps the two stages (`BattleEngine.lua:1900-1901`) passes all 533 tests. Fix: add a case with defender evasion +1 (ratio 75/100, so calc = 67): accuracy draw 66 (67 ≤ 67) hits and draw 67 (68 > 67) misses. For example, use vector {0,1,0,67} and expect `useMove, damage, multiHit` with hits 1 and 4 draws. Optionally also test attacker accuracy −1.
- **F2 Low: Reflect through the kick power override is unasserted.** `resolveTripleKick` builds its own `calculateBaseDamage` call (`:1909-1910`), and passing `{}` instead of `self.sideStatus[defenderSide]` survives. Fix: set `b.sideStatus[defSide].reflect = true` and expect per-kick damage per `pokemon.c` (Reflect halves before `+2`: power 10 gives 2/2 = 1, +2 = 3; power 20 gives 2+2 = 4; power 30 gives 3+2 = 5). A crit kick ignores Reflect.
- **F3 Low: the RNG oracle and acceptance text present gap values as the contract, and this family's roll goes beyond the tracked plain-hit gap.** `work/tasks/phase4-triple-kick.md:48-51` and `tests/battle_engine_test.lua:2247,2251,2255,2259` assert 9/4/1/3 draws. Source spends one more draw in each case (10/5/2/4), because `BattleScript_TripleKickEnd` runs `seteffectwithchance` (`bs1.s:1431`, `bsc.c:2789`) on every path, including a **first-kick miss**. The tracked gap (`phase4-self-drop-tickle-batch.md:74-76`) covers only landed or immune Hit-script hits; an ordinary miss goes to PrintMoveMissed and spends nothing. Closing that gap in the ordinary path would not close it in `resolveTripleKick`. This repeats batch 4's F1. Fix: reword acceptance 1 as "9/4/1/3 draws, matching the tracked seteffectwithchance gap (source 10/5/2/4; the Triple Kick roll is spent on every path, miss included)". Put the same note beside each `draws==` assert and in the `resolveTripleKick` comment (`BattleEngine.lua:1893-1894`). Add "roll also spent on miss" to row 104 and to the gap follow-up list.
- **F4 Low: wrong source citation.** `work/tasks/phase4-triple-kick.md:24-25` says "`:1213-1231` damagecalc uses and resets gDynamicBasePower". Cmd_damagecalc (`bsc.c:1209-1222`) uses it but does not reset it. `:1231` is in `AI_CalcDmg`. The battle resets are at `battle_main.c:3695` (CheckFocusPunch_ClearVarsBeforeTurnStarts) and `:4471` (HandleAction_ActionFinished). Behavior is unaffected because `copyhword` rewrites it each kick and the engine keeps power local. Fix: correct the citation.
- **F5 Informational: effectiveness text timing.** Source prints the effectiveness message once, at `resultmessage` (`bs1.s:1422`), from the last landed kick's flags. After a later miss, `bicbyte MISSED` leaves the earlier kick's SUPER/NOT_VERY flags, so "It's super effective!" follows the miss. The controller prints it after every `damage` event (`BattleSceneController.lua:210`). The task excludes this as the existing multi-hit convention, so it does not block. Record it in row 104's limits.
- **F6 Informational: KO with a replacement is untested.** The KO test uses `hasReplacement = false`. The forced-switch path goes through the shared `checkFaint` at `:2148` and is structurally fine. Optional: add a `hasReplacement = true` variant that expects the hit count before `faint` and the pending switch.
- **F7 Informational: MOVEEND runs per kick.** `moveendto MOVEEND_NEXT_TARGET` runs cases 0-15 after every kick. That means Rage builds per kick, King's Rock rolls per kick (`battle_util.c:3000-3005`, only with a FLINCH item) and Defrost/Synchronize are checked per kick. None of that state exists today. Add a note to row 104 so future Rage or held-item work covers the per-kick path in `resolveTripleKick`.

No defect was found in runtime behavior for the represented state. F1 must be fixed before PASS. F2-F4 are cheap and should go in the same fix.

— independent reviewer subagent; did not construct the change

## Re-check (commit 37c0c5c on top of 9d978b0)

Verdict: **PASS**

- I reviewed only the delta `git diff 9d978b0 37c0c5c -- src tests work/reports work/tasks`. The one edit to `BattleEngine.lua` is a comment (`:1894-1895`), so runtime code is unchanged. `git diff --check` is clean. No ROM or extracted content was added. The committed `work/reviews/2026-10-13-triple-kick-review.md` is identical to the original record above.
- F1: two new tests, `triple kick per-kick evasion stage` and `per-kick accuracy stage`, use vector {66,1,0,67}. With evasion +1 (or accuracy −1) the threshold is 90×75/100 = 67 (`bsc.c:1046-1061`). Draw 66 hits and draw 67 misses, which pins both sides of the threshold. Fixed.
- F2: the new test `triple kick Reflect per kick` expects 3/4/5, which matches the `pokemon.c` arithmetic (Reflect halves before +2). Fixed.
- F3: acceptance 1 now says the draw counts match the tracked gap (source 10/5/2/4, roll spent on a miss too). The `resolveTripleKick` comment, row 104 and a new Follow-ups entry say the same. Fixed, with one residual: the note was not added beside the four `draws==` asserts (`tests/battle_engine_test.lua:2247,2251,2255,2259`). This does not block. The asserts fail on their own if the gap is closed, and the acceptance text now carries the contract.
- F4: the citation now reads Cmd_damagecalc `:1209-1222`, with resets at `battle_main.c:3695,4471`. Fixed.
- F5 and F7: row 104 records per-kick effectiveness text and the unmodeled per-kick MOVEEND. Fixed.
- F6: the new test `triple kick KO with replacement pending` expects `turnStart,useMove,damage,damage,multiHit,faint,forcedSwitchNeeded`, so the hit count comes before the faint. Fixed.
- I re-ran the three surviving mutants on a fresh `git archive 37c0c5c` copy (`/tmp/claude-0/review5/repo2`, harness `mut/run3.py`). All three are now caught:

  | Mutant | Result |
  | --- | --- |
  | Evasion stage ignored (fixed 6) | 539/2 (evasion-stage test, ×2) |
  | Accuracy/evasion stages swapped | 537/4 (both stage tests, ×2) |
  | Reflect ignored (`{}` sideStatus) | 539/2 (Reflect test, ×2) |

- Tests: `test_all.sh` passes (160 files, no ROM) in both the checkout (HEAD 37c0c5c) and the fresh copy. `check_repository.lua` passes (286 Lua, 292 Markdown, 971 targets). Engine 541/0 (533 + 4 checks × 2 sides). Controller 100/0.

— independent reviewer subagent; did not construct the change
