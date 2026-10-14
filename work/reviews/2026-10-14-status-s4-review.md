# Review: P4-STATUS-S4 thaw-hit burn, Facade, Smelling Salt, Refresh

- Reviewer: independent Reviewer (Claude), per `AGENTS.md` rule 6
- Date: 2026-10-14
- Commit under review: `6f3168f` (Status S4: thaw-hit burn, Facade, Smelling Salt, Refresh)
- Task: [`work/tasks/phase4-status-s4.md`](../tasks/phase4-status-s4.md)
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
- Verdict: **PASS** (no Blocker or Major findings. One Minor test-strength finding and three Info findings are listed below. All are optional follow-ups.)

## Summary

All four scripts match source. That covers the Facade/Smelling Salt
`dmgMultiplier` position, Smelling Salt's CERTAIN-byte RNG behavior and its
cure guards, Refresh's mask, PP, missing RNG and failure path, and the
thaw-hit burn interactions. The two new texts, the 5 ROM fixture records and
the inventory arithmetic also match. Changed files stay inside MAY CHANGE,
and `main.lua` is not touched. AI_CBM_Refresh was already implemented
(`src/core/AICheckBadMove.lua:476-485`, `[193] = refresh`) and matches
`data/battle_ai_scripts.s:567-569`.

Mutation testing killed 17 of the 21 mutants. Three survivors (M3, M4, M13)
are equivalent in this engine because no admitted path runs Facade or
Refresh while the user is asleep or frozen. One survivor (M11) is a missing
draw-count assertion. The implementation is correct in that case.

## Verification performed

### Scripts and commands

| Item | Source | Engine (`src/core/BattleEngine.lua`) | Result |
| --- | --- | --- | --- |
| Thaw Hit | `bs1.s:1675-1677` `setmoveeffect MOVE_EFFECT_BURN` → EffectHit | `STATUS_HIT_MOVES[125]="burn"` → `applySecondaryStatus(...,chance>=100)` | match |
| Frozen thaw-hit user | `battle_util.c` CANCELLER_FROZEN (`Random()%5`, thaw-hit passes), CANCELLER_THAW ("defrosted by") before attackstring | S1 code unchanged; probe: freeze draw 1 → `defrostedByMove,useMove,damage,statusApplied`, 5 draws (freeze, acc, crit, dmg, burn) | match |
| Sacred Fire vs frozen target | seteffectwithchance burn fails on STATUS1_ANY; MOVEEND_DEFROST (`bsc.c:4103-4116`) runs later | probe: burn roll 50 consumed, no burn, then `defrostedByFire` | match (order correct) |
| Facade | `bs1.s:2247-2253` `jumpifstatus BS_ATTACKER PSN\|BRN\|PAR\|TOX` → `sDMG_MULTIPLIER 2` | same 4-flag mask, ×2 | match |
| dmgMultiplier position | `bsc.c:1211-1216` `CalculateBaseDamage(...) * gCritMultiplier * dmgMultiplier` (base includes +2 and burn halving), before typecalc/random | after `calculateBaseDamage` and the crit ×2, before `typeCalc`/`applyRandomDamageMultiplier` | match (integer product, so order vs crit is immaterial) |
| dmgMultiplier lifetime | reset to 1 in `HandleAction_UseMove` (`battle_main.c:3975`) and `MoveValuesCleanUp` (`bsc.c:3472`) | computed locally for each move, so it cannot persist | match |
| Status checked before attackcanceler | `jumpifstatus` runs before `attackcanceler` | engine reads `attacker.status` after cancellers | equivalent: the canceller changes only SLP/FRZ → 0 and leaves PAR alone. None of these is in the mask, so the result is the same |
| Smelling Salt | `bs1.s:2263-2270` Substitute → EffectHit; `setmoveeffect REMOVE_PARALYSIS\|CERTAIN`; PAR → ×2 | ×2 vs PAR target; Substitute unmodeled (stated) | match |
| seteffectwithchance CERTAIN | `bsc.c:2783-2801`: CERTAIN and not NO_EFFECT → SetMoveEffect with no Random(); otherwise `Random()%100 <= 0` is drawn first | hit: no draw (test draws==4); noEffect branch draws once (probe: Ghost → 4 draws: acc, crit, dmg, roll) | match |
| REMOVE_PARALYSIS guards | value 36 (`include/constants/battle.h:257`), so Shield Dust (`<=9`) and Safeguard (`<=7`) never block it; `hp==0` returns (`:2140`); not-paralyzed → no-op (`:2691`); clears the PAR bit (`:2697`) | no Shield Dust check, `defender.hp > 0`, `isParalyzed` guard, `status - PARALYSIS` | match |
| Smelling Salt order | `BattleScript_TargetPRLZHeal` (`bs1.s:3803`) runs inside seteffectwithchance, after damage/resultmessage and before `tryfaintmon` | `paralysisHealed` after damage, before the caller's faint check | match |
| Refresh | `bs1.s:2515-2525` attackcanceler/attackstring/ppreduce → `cureifburnedparalysedorpoisoned` (`bsc.c:8728-8742`: PSN\|BRN\|PAR\|TOX → `status1 = 0`, else ButItFailed) | PP−1, same mask, `status = 0` (also clears toxic counter), else `moveFailed`; no RNG | match |
| Refresh admission | power 0, `MOVE_TARGET_USER` | `supportsMove`: `power == 0 and target == MOVE_TARGET_USER` (0x10) | match |
| Refresh with cancellers | fully paralyzed → no PP; frozen → 80% blocked, 20% thawed then fails | probe: `fullyParalyzed`, PP 10; thawed → `thawed,useMove,moveFailed`, PP 9 | match |

### Texts (`src/battle_message.c`)

- `:108` `sText_PkmnHealedParalysis` "{B_DEF_NAME_WITH_PREFIX} was\nhealed of paralysis!" matches the controller.
- `:222` `sText_PkmnStatusNormal` "{B_ATK_NAME_WITH_PREFIX}'s status\nreturned to normal!" matches the controller (`possessive(name(side))`).

### ROM fixture and inventory

- `tests/phase4_status_s4_effect_rom_test.lua`: all 5 records (172, 221, 263,
  265, 287) match `src/data/battle_moves.h` in effect, power, type,
  accuracy, PP, chance, target and flags (0x13/0x12/0x13/0x13/0x08). Priority
  is 0 for all. Exactly 5 moves use effects 125/169/171/193. The fixture
  skips without a ROM, as the fast-lane rules allow. Its "2 passed" print is
  cosmetic.
- Inventory deltas: represented 81→85 families, 198→203 moves, 137→141
  positive, 61→62 zero. Blocked 116→112, 155→150, 78→74, 77→76. Admitted
  276→277 / 77. Uncovered 78→74 records and 48→45 effects (125, 169 and 171
  removed). An independent recount from the test table gives 45 effects / 74
  records, and the list matches the report exactly. Report rows 125/169/171/193
  are updated to R. Row 193 is admitted "yes".

### Scope and regressions

- Changed files are `BattleEngine.lua`, `BattleSceneController.lua`, the
  status-engine, controller and inventory tests, the new ROM fixture, the
  inventory report and the task file. All are inside MAY CHANGE.
  `main.lua` is untouched.
- AI: `AI_CBM_Refresh` was already handled. `AI_CV_Facade`,
  `AI_CV_SmellingSalt` and `AI_CV_Refresh` belong to CheckViability, which
  this engine models only for the Oak-lab rival. The AI damage estimate does
  not use the new multiplier, which matches `AI_CalcDmg` because
  dmgMultiplier is 1 at AI time.

### Test runs (unmodified tree)

- `lua5.1 tests/battle_status_engine_test.lua`: 201 passed, 0 failed
- `lua5.1 tests/battle_scene_controller_test.lua`: 137 passed, 0 failed
- `lua5.1 tests/phase4_move_effect_inventory_test.lua`: expected partition checked; ROM part SKIP
- `lua5.1 tests/ai_check_bad_move_test.lua`: 38 passed, 0 failed
- `bash scripts/test_all.sh`: PASS, 166 test files (no-ROM mode)
- `lua5.1 scripts/check_repository.lua`: PASS

## Findings

1. **Minor (test strength): the draw on a no-effect Smelling Salt is not asserted.**
   Evidence: the "Smelling Salt vs Ghost" test (`tests/battle_status_engine_test.lua`, S4 block) checks only `noEffect` and that paralysis remains. Mutant M11 removes `EFFECT_SMELLINGSALT` from the noEffect roll list, and it survives: the foe's Tackle then reads 99 (=MISS) either way. The implementation is correct. A probe with `resolveMove` alone gives 4 draws, as `bsc.c:2789` requires.
   Fix: in that test, call `b:resolveMove("player", 1, ev)` alone and assert `b.rng.draws == 4`.

2. **Info (test labels / equivalent mutants): sleep and freeze cases never reach the mask.**
   Evidence: `facade(1)` uses sleep counter 1, so CANCELLER_ASLEEP wakes the user (status 0) before damagecalc. "Refresh fails on sleep" is cancelled as fast asleep before Refresh runs. M3 (Facade mask + sleep), M4 (Facade mask + freeze) and M13 (Refresh cures sleep) survive. They are equivalent today: the only source path that runs these scripts while the user is asleep is Sleep Talk (effect 97, not admitted). A frozen user is either blocked or thawed first.
   Fix: optional. Reword the labels (for example "woken user is not doubled"). Add sleep-mask tests when Sleep Talk is admitted.

3. **Info (report): row 169 does not mention the plain-hit zero-byte roll gap.**
   Evidence: in source, Facade's `seteffectwithchance` still evaluates `Random()%100 <= 0` (`bsc.c:2789`). The probe shows Facade vs Ghost drawing 3 times where source draws 4. The task's Known limits record this gap, but the inventory report row does not.
   Fix: add "shares the plain-hit seteffectwithchance roll gap" to row 169.

4. **Info (design): other dmgMultiplier consumers.**
   Evidence: the other source setters are Surf/Whirlpool vs underwater, Gust/Twister vs on-air, Earthquake/Magnitude vs underground, Stomp vs minimized (`bs1.s:243, 833, 1825, 1839, 1891, 1896`), Pursuit on switch (`:3049`), and `Cmd_doubledamagedealtifdamaged` (Revenge, `bsc.c:8953`). Each one depends on STATUS3/switch/damage-history state that the engine does not model, so nothing has to share the code yet.
   Fix: when the first of these lands, factor out one `dmgMultiplier` local, applied at the same point.

Also noted, not a finding: the Flame Wheel non-burn boundary (roll 11) is not tested. The Sacred Fire 50/51 boundary and Flame Wheel 10 together cover the shared path.

## Mutation testing

Originals were saved, and each mutant was applied to a fresh copy and then
restored. SHA-1 values after the run:
`d14db334dd7f995ff3f2a175ad31d9bfa51eb003` (BattleEngine.lua) and
`e1c72c31a3f21f8cd6d2dd0ab1c8c637418611b4` (BattleSceneController.lua), the
same as before. The suite was the status engine, controller and AI CheckBadMove tests.

| # | Mutant | Result |
| --- | --- | --- |
| M1 | Facade mask drops TOX | KILLED (Facade doubles ... badly poisoned) |
| M2 | Facade mask drops BRN | KILLED (burned Facade) |
| M3 | Facade mask includes sleep | SURVIVED, equivalent (finding 2) |
| M4 | Facade mask includes freeze | SURVIVED, equivalent (finding 2) |
| M5 | multiplier moved after typecalc | KILLED (Smelling Salt before STAB) |
| M6 | Smelling Salt doubles regardless of paralysis | KILLED |
| M7 | cure moved before damagecalc (paralysis checked after cure) | KILLED |
| M8 | cure without paralysis check | KILLED (healthy target: no heal) |
| M9 | cure ignores hp==0 | KILLED (KO: no heal message) |
| M10 | roll drawn on a CERTAIN hit | KILLED (draw count) |
| M11 | no roll on a no-effect hit | SURVIVED (finding 1) |
| M12 | Refresh does not spend PP | KILLED |
| M13 | Refresh mask includes sleep | SURVIVED, equivalent (finding 2) |
| M14 | Refresh keeps toxic counter | KILLED (status 1152) |
| M15 | Refresh mask drops PAR | KILLED |
| M16 | Refresh draws an RNG value | KILLED (draw count) |
| M17 | Refresh admission requires target 0 | KILLED (admission check; first attempt hit an unrelated earlier line and was redone on the Refresh branch) |
| M18 | thaw-hit `[125]="burn"` entry removed | KILLED (Flame Wheel / Sacred Fire burn) |
| M19 | Refresh text "." instead of "!" | KILLED |
| M20 | paralysis-heal text "." instead of "!" | KILLED |
| M21 | Refresh text not possessive | KILLED |

17 of 21 killed. Three survivors are equivalent and one is a test gap (Minor).

## Worker disposition (2026-10-14)

F1 draw-count test added; F2 labels reworded; F3 report row notes the gap; F4 recorded in the task limits.
