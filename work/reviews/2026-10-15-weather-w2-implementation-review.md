# Review: weather slice W2 implementation (commit cecf1cb)

- Reviewed: `cecf1cb` on `claude/wizardly-faraday-o45q9z` (base `285d8c3`, W0 and W1 merged)
- Task: [phase4-weather-w2](../tasks/phase4-weather-w2.md)
- Spec: [weather design proposal](../reports/phase4-weather-design-proposal.md) (W2 parts), [design review](2026-10-14-weather-design-review.md) (F2, F5)
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
- Date: 2026-10-15

## Verdict: **PASS WITH CORRECTIONS**

I checked every W2 behaviour against source and found it faithful. Thunder, the Solar Beam sun path (including the F2 oracle), Weather Ball and the three sunlight heals all match source. I found no behaviour defect.

The one correction is a test gap (finding 1): the suite cannot tell Weather Ball's sandstorm type (Rock) from Ground. It needs one added assertion. The other findings are informational and need no action.

## Commands run

- `lua5.1 tests/battle_weather_w2_test.lua`: 204 passed, 0 failed.
- `bash scripts/test_all.sh`: PASS, 183 test files in no-ROM mode (ROM fixtures skip cleanly).
- `lua5.1 scripts/check_repository.lua`: PASS.
- Admission check, independent of the commit's own:
  - I parsed all 354 records from the pinned `src/data/battle_moves.h` and the effect ids from `include/constants/battle_move_effects.h`.
  - I ran `BattleEngine:supportsMove` over every record.
  - Result: **292/62** at `cecf1cb` and **289/65** at `285d8c3`.
  - The three new admissions are exactly moves 234, 235 and 236. Moves 76, 87 and 311 were already admitted.
- 25 mutations, listed below. I applied each one, ran both suites, then restored the file with `git checkout -- src/core/BattleEngine.lua`. The tree was clean afterwards. This review file is the only change, and it is uncommitted.

## Source checks (all confirmed)

### 1. Thunder (`BattleEngine.lua:1663-1673`)

- **Rain.**
  - Source: `AccuracyCalcHelper` (`bsc.c:993-998`) returns a sure hit with no `Random()` under `WEATHER_HAS_EFFECT && B_WEATHER_RAIN && EFFECT_THUNDER`.
  - It comes after the ON_AIR check, which Thunder ignores through `HITMARKER_IGNORE_ON_AIR` (`bs1.s:1916-1919`), and after the UNDERGROUND and UNDERWATER misses (`:966-991`).
  - Engine: `accuracyRoll` calls `semiInvulnerableMiss` first and then returns `true` with no draw. `HITS_AIR[152] = 1` gives the Fly case: a sure hit at ×1.
- **Sun.**
  - Source: `Cmd_accuracycheck` sets `moveAcc = 50` before `sAccuracyStageRatios` (`bsc.c:1062-1064`), and then takes the single draw.
  - Engine: passes `accuracy = 50` into `BattleFormulas.accuracyCheck`, which applies the stage ratio and then Hustle.
  - The tests pin the 50/51 edge and the +1-stage 66/67 edge.
- **Cloud Nine / Air Lock.** The engine uses `activeWeather()`, which is HP-gated `WEATHER_HAS_EFFECT`. That matches both source sites.
- **M2 interaction.**
  - On the main hit path, `resolveMoveCore` computes `semiMiss` (`:2169`) before it calls `accuracyRoll`. So Thunder in rain against Dig or Dive misses with zero draws, and against Fly it hits.
  - The check inside `accuracyRoll` is redundant on that path (see finding 2).

### 2. Solar Beam sun path (`BattleEngine.lua:1793-1810`)

- **Script.** `bs1.s:1899-1914`:
  1. `jumpifabilitypresent` Cloud Nine, then Air Lock. These are HP-gated through `ABILITYEFFECT_CHECK_ON_FIELD` (`bsc.c:3836-3842`), so `activeWeather()` is the same test.
  2. `gBattleWeather & B_WEATHER_SUN` leads to `SolarBeamOnFirstTurn`.
  3. That label runs `MOVE_EFFECT_CHARGING|AFFECTS_USER` through `seteffectprimary`. This sets MULTIPLETURNS and `gLockedMoves` (`bsc.c:2477-2482`), and it is skipped silently when MULTIPLETURNS is already set (`:2396`). The result is the same either way.
  4. Then `ppreduce`, all **before** `attackcanceler` (in `TwoTurnMovesSecondTurn`, `:784-792`).
  - Engine: places the block immediately before `resolveStatusCancellers`. It spends a PP only while `pp > 0` (`bsc.c:1147`) and sets `charging` and `lockedSlot`.
- **Second PP.** On a release that was charged before the sun, the block runs again and spends the second PP. At 0 PP nothing is spent and the move still fires, because the lock bypasses the 0-PP check through MULTIPLETURNS (`bsc.c:838-839`). The engine's post-canceller `noPP` check is skipped while `charging`.
- **Cancellers.**
  - Paralysis, flinch and the confusion self-hit call `cancelMultiTurnMoves`, which clears the lock. PP has already been spent, as in source.
  - Freeze keeps the lock (`CANCELLER_FROZEN` does not cancel it).
  - Sleep keeps the lock until `resolveEndTurn` cancels it (`battle_main.c:2941-2942`).
- **F2.** I traced it end to end:
  1. Frozen first, then Solar Beam selected in sun: PP is spent and the lock is set. "Frozen solid" keeps the lock.
  2. Next turn the battler is locked through `isLocked`/`lockedThisTurn`. The sun path spends PP again.
  3. After the sun ends, the battler takes no sun path. The freeze canceller returns, so no PP is spent and the move stays locked.
  4. On the thaw turn (`%5 == 0`) the lock is live, the `noPP` check is skipped, and the charge block takes its second-turn arm with `noPPDeduct`. The move fires.
  - This matches the corrected oracle in the design review (F2).
- **Other locks.**
  - M1: the charge block's second-turn arm clears the lock, `semiInvulnerable` and PP.
  - M3 rampage and recharge cannot select Solar Beam, because a locked battler is forced into its locked slot.
  - A charge cancelled earlier in the turn (sleep from a faster foe) still uses the turn's locked slot. The sun path then re-locks the move and spends PP before "fast asleep", as in source.
  - I found no broken interaction.
- **Text.** No `chargeTurn` event is emitted, so "took in sunlight!" is not printed. `useMove` ("X used SOLARBEAM!") is emitted after the cancellers. That is the `attackstring` in `BattleScript_HitFromAccCheck`. On a cancel, only the canceller's text is printed. The controller test pins this.

### 3. Weather Ball (`BattleEngine.lua:1757-1775`, `:2646-2648`, `:890`)

- **Type.** Source: `Cmd_setweatherballtype` (`bsc.c:9345-9364`), under `WEATHER_HAS_EFFECT`. Rain gives Water (11), sandstorm Rock (5), sun Fire (10) and hail Ice (15). Any weather bit also sets `dmgMultiplier = 2`. The engine's `WEATHER_BALL_TYPES` matches. Clear weather, Cloud Nine or Air Lock leave the move Normal 50 at ×1.
- **×2 placement.** Source: `Cmd_damagecalc` computes `CalculateBaseDamage(...) * gCritMultiplier * dmgMultiplier` (`bsc.c:1214-1215`). The `+2` is inside `CalculateBaseDamage` (`BattleFormulas.lua:425`).
  - The engine doubles after the crit multiply. Integer products commute, so the result is the same.
  - STAB, effectiveness and the random factor all follow.
  - The tests witness that the ×2 comes after the `+2` and before STAB (mutation results below).
- **Split.** `calculateBaseDamage` reads the copy's `move.type`, so Rock is physical (burn and Reflect apply, Light Screen does not) and Water, Fire and Ice are special.
- **Rain/sun stacking.** The 1.5 term in the special branch (`pokemon.c:2605-2637`) uses the dynamic type: in rain, 6 → 9 → +2 → ×2 = 22. The type selection uses HP-gated `WEATHER_HAS_EFFECT`, while the 1.5 uses the HP-free `damageWeather()` (`WEATHER_HAS_EFFECT2`). This is the same split as source.
- **Readers of the dynamic type.** All of them see the copy:
  - STAB and type effectiveness: `typeCalc(move.type)`, so the Water version hits a Ghost.
  - Thick Fat and the pinch abilities, through `abilityAdjustedStats` and `PINCH_ABILITY_TYPES`.
  - Hustle accuracy: `accuracyRoll` passes `move.type`, as `GET_MOVE_TYPE` does at `bsc.c:1038`.
  - The move-end defrost, through `currentMove` (`:1859`, as `GET_MOVE_TYPE` does at `bsc.c:4080`).
  - The engine models none of the remaining source readers: Water/Volt Absorb, Flash Fire, Color Change, Counter/Mirror Coat, Rage, `gLastHitByType`, Charge, or held-item type boosts. The task already records this (F5).
- **AI.** The AI reads the shared `self.moves[311]`, which stays Normal. `Conversion` also reads static slot types, as in source. The task cites the AI's type reset (`battle_ai_script_commands.c:981-982`, `:1205-1206`).

### 4. Morning Sun, Synthesis, Moonlight (`BattleEngine.lua:2381-2411`, `:1315`, `:2144`)

- **Script.** `bs1.s:1726-1733`: `attackcanceler`, `attackstring`, `ppreduce`, `recoverbasedonsunlight`. There is no `accuracycheck`, and the engine excludes them from accuracy.
- **Amounts.** Source: `bsc.c:8478-8501`.
  - `maxHP/2` when `gBattleWeather == 0 || !WEATHER_HAS_EFFECT`.
  - `20*maxHP/30` in sun.
  - `maxHP/4` in any other weather.
  - `0 → 1`, then the heal is clamped by `datahpupdate`.
  - The engine computes the same values with `math.floor`. The arguments are small exact integers, so floating division is exact enough.
  - At maxHP 79 the values are 39/52/19. The sun case is a floor, not a rounding.
- **Full HP.** Jumps to `BattleScript_AlreadyAtFullHp` (`bs1.s:2038-2042`), which prints "X's\nHP is full!". PP has already been spent. The engine emits `restoreHPFull` and the controller renders that text. The brief's "But it failed!" was rightly rejected.
- **Cloud Nine / Air Lock** give 1/2.

### 5. Admission and inventory

- Admission is 292/62, confirmed independently (see Commands run).
- Inventory partition deltas:
  - represented 114/255/181/74 → 118/259/182/77;
  - blocked 83/98/34/64 → 79/94/33/61;
  - admitted-uncovered positive 34 → 33 records, 26 → 25 effects.
  - These match the four changed rows (234, 235, 236 zero-power; 311 positive).
- The text for rows 132-134, 151, 152 and 203 in `phase4-move-effect-inventory.md` describes the implemented behaviour accurately.
- The ROM fixture's expected records match the pinned `battle_moves.h`, flags included: Thunder 0x12, the heals 0x08, Weather Ball 0x32.
- Every file the commit touches is on the task's MAY CHANGE list. `AICheckBadMove.lua` is unchanged.

### 6. Regressions

- The full suite passes.
- The only change to an existing test is a comment in `battle_weather_test.lua`. The W1 "Solar Beam release in sun" case now spends a second PP, which is correct, and its damage and draw assertions are unchanged.
- The source citations I spot-checked (`bsc.c:838-839`, `:993-998`, `:1062-1064`, `:1146-1152`, `:1209-1220`, `:3836-3842`, `:8478-8501`, `:9345-9364`; `bs1.s:784-792`, `:1726-1733`, `:1899-1919`, `:2038-2042`, `:2636-2638`) are exact.

## Mutation results

Each line gives the failures in `battle_weather_w2_test`. I also ran `scripts/test_all.sh` for every mutation except "×2 moved after STAB" and "sun path moved after the cancellers". In each of those runs it failed in step with the test file, or passed where the test file passed.

| Mutation | Failures |
|---|---|
| Thunder rain rolls | 6 |
| Thunder sun at 70 | 2 |
| Thunder ignores Cloud Nine/Air Lock | 8 |
| Thunder rain check moved before `semiInvulnerableMiss` | **0** (equivalent: see finding 2) |
| Sun path spends no PP | 14 |
| Sun path PP unguarded (`pp > 0` dropped) | 1 |
| No second PP on a charged release | 5 |
| Sun path ignores Cloud Nine/Air Lock | 4 |
| Sun path sets no lock | 17 |
| Sun path moved after the cancellers | 14 |
| Weather Ball without ×2 | 22 |
| Weather Ball ×2 moved after STAB/typecalc | 3 |
| Weather Ball ignores Cloud Nine/Air Lock | 10 |
| Weather Ball mutates the shared record | 17 |
| Weather Ball without the rain/sun damage term | 13 |
| Weather Ball sandstorm → Ground (4) | **0** (finding 1) |
| `currentMove` = static record (defrost) | 1 |
| Hustle accuracy reads the static type | 1 |
| Heal: sun rounded | 4 |
| Heal: 1/2 in other weather | 10 |
| Heal: no minimum 1 | 1 |
| Heal: ignores Cloud Nine/Air Lock | 8 |
| Heal: no full-HP check | 2 |
| Heal: accuracy check not excluded | 48 |
| Heal: not clamped | 1 |

The task file's own mutation counts all reproduced exactly: 6, 2, 8, 5, 14, 4, 22, 10, 8, 4, 1, 10.

## Findings

### 1. Minor (correction). Weather Ball's sandstorm type is not pinned against Ground

**Evidence.**
- The mutation `WEATHER_BALL_TYPES.sandstorm = 4` (Ground) passes all 204 W2 checks and `scripts/test_all.sh`.
- Every sandstorm assertion is satisfied by Ground as well as Rock. Ground is also physical (so the burn, Reflect and Hustle checks pass), and it is also super effective against Fire. The test `tests/battle_weather_w2_test.lua:529` ("Rock super effective vs Fire -> 56") gives 56 either way.
- The engine value is correct: `TYPE_ROCK = 5`, `bsc.c:9354`.

**Correction.** Add one sandstorm assertion that Rock and Ground resolve differently. For example, against a Flying target Rock is super effective, 28 → 56, while Ground has no effect. Against a Ground or Fighting target Rock is resisted, 28 → 14, while Ground is ×2 or ×1. No engine change is needed.

### 2. Info. The Thunder "after the Dig/Dive miss" order is enforced by the caller, not by `accuracyRoll`

**Evidence.**
- Moving the rain sure hit above `semiInvulnerableMiss` inside `accuracyRoll` (`BattleEngine.lua:1663-1673`) changes no result.
- `resolveMoveCore` already decides `semiMiss` (`:2169`) before it calls `accuracyRoll`. The only other direct caller is the Explosion path, and Thunder never reaches it.
- So the test "Thunder rain vs Dig misses with zero draws" pins the outer check. The order inside `accuracyRoll` is still source-correct.

**Action.** None required. If `accuracyRoll` ever gains a caller without the outer `semiMiss`, the existing internal order already gives the right answer.

### 3. Info. The W1 test comment and the W2 task describe the second-PP change accurately

`tests/battle_weather_test.lua:552-553` and the task's "Changed assertions" section agree with the behaviour. No other existing assertion moved. No action.

## Summary

- W2 is faithful to source in every area checked:
  - Thunder's rain and sun accuracy, Cloud Nine, and its interaction with M2;
  - the Solar Beam sun path: script order, second PP, F2, the other locks, and the text;
  - Weather Ball: type, ×2 placement, the split, weather stacking, the dynamic-type readers and the static AI view;
  - the sunlight heals: amounts, minimum 1, full-HP text, PP and Cloud Nine.
- Admission is 292/62 and the inventory is accurate.
- No regressions.
- One test assertion should be added (finding 1) before or alongside closing the task.
