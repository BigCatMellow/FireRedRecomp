# Review: weather slice W1 implementation (commit 59cbe01)

- Reviewed: `59cbe01` on `claude/wizardly-faraday-o45q9z` (base `b3dd0ba`, W0 merged)
- Task: [phase4-weather-w1](../tasks/phase4-weather-w1.md)
- Spec: [weather design proposal](../reports/phase4-weather-design-proposal.md) (W1 parts), [design review](2026-10-14-weather-design-review.md)
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
- Date: 2026-10-15

## Verdict: **PASS**

I checked every W1 behaviour against source and found it faithful. The two findings below are minor and do not block the slice: one inaccurate comment and one untested equivalence. Behaviour needs no correction.

## Commands run

- `lua5.1 tests/battle_weather_test.lua`: 220 passed, 0 failed.
- `bash scripts/test_all.sh`: PASS, 181 test files in no-ROM mode.
- `lua5.1 scripts/check_repository.lua`: PASS.
- 47 one-line mutations. Each one was applied, run, then restored with `git checkout -- <file>`. The tree was clean afterwards, and this review file is the only addition.

## Source checks (all confirmed)

### 1. Weather moves

- **Scripts.** `bs1.s:1585-1590`, `:1740-1758` and `:2128-2133` run `attackcanceler`, `attackstring`, `ppreduce`, then the set command. There is no `accuracycheck` and no RNG.
- **Commands.** `bsc.c:6399-6413`, `:7200-7214`, `:8381-8396` and `:8664-8678`:
  - The move fails when its own family mask, permanent bit included, is already set (`B_WEATHER_RAIN`, `_SANDSTORM`, `_SUN`, `_HAIL`, `battle.h:206-218`).
  - Otherwise the command assigns the whole word to `X_TEMPORARY` and sets the duration to 5.
- **Engine.** `BattleEngine.lua:1941-1961` matches this:
  - PP is spent before the test.
  - `moveFailed` on the same family.
  - `{kind, permanent=false}` plus `WEATHER_DURATION = 5` (`:874`) otherwise, which also overwrites a permanent family of another kind.
  - No draw.
- **Texts.** `battle_message.c:912-920` gives "It started to rain!", "A sandstorm brewed!", "The sunlight got bright!", "It started to hail!" and "But it failed!" (`:336`). These match `BattleSceneController.lua` `WEATHER_SET_TEXT` and the existing `moveFailed` text.
- **Admission.** `supportsMove` admits the four effects only with power 0 and `MOVE_TARGET_USER`. This matches the records at `battle_moves.h:2616`, `:3123`, `:3136` and `:3357`.

### 2. End of turn

- **Placement.**
  - `resolveEndTurn` (`BattleEngine.lua:3219-3237`) runs the flinch/sleep work, `endTurnOrder` (W0), `decaySideTimers`, `resolveWeatherEndTurn`, then `resolveStatusEndTurn`.
  - This is the source field order `ENDTURN_ORDER → REFLECT → LIGHT_SCREEN → (MIST/SAFEGUARD/WISH, not represented) → RAIN/SANDSTORM/SUN/HAIL` (`battle_util.c:451-463`).
  - All field cases come before `DoBattlerEndTurnEffects` (`battle_main.c:2958-2963`).
- **Timer.**
  - Source decrements the duration when the family is not permanent. Hail always decrements, because it has no permanent bit (`battle_util.c:624-711`).
  - At 0 source clears the weather and runs the end script, which has no damage loop (`bs1.s:3184-3198`). Otherwise it prints "continues".
  - The engine (`:3261-3273`) matches. Weather set on turn T prints "continues" on T..T+3 and "stopped" on T+4. That is exactly 4 damage ticks.
- **Damage.**
  - Source `Cmd_weatherdamage` (`bsc.c:7216-7268`) gives 0 unless `WEATHER_HAS_EFFECT`. It exempts Rock/Steel/Ground in either type slot, Sand Veil, UNDERGROUND and UNDERWATER in sand, and Ice, UNDERGROUND and UNDERWATER in hail. ON_AIR is not exempt. The amount is `maxHP/16` with a minimum of 1.
  - The engine matches. It uses the HP-gated `activeWeather()` and the same exemption set; Fly and Bounce are not exempt. The amount is `math.max(1, floor(maxHP/16))`, clamped to remaining HP.
- **Loop.**
  - Source walks `gBattlerByTurnOrder` (`bs1.s:3163-3182`) and skips a 0 result silently. Otherwise it prints the text, updates HP, then runs `tryfaintmon` and `checkteamslost`. A decided outcome ends the loop.
  - The engine walks `sides` from `endTurnOrder` and stops on `isOver()`. It skips 0-HP battlers (D4) and calls `checkFaint` at 0 HP. A decided battle then also skips `resolveStatusEndTurn` through its own `isOver` guard.
- **Cloud Nine / Air Lock.**
  - `DoFieldEndTurnEffects` never tests the abilities, so the timer and texts always run. Only `weatherdamage` reads `WEATHER_HAS_EFFECT`.
  - The engine reads `self.weather` for the timer and `activeWeather()` only for damage. This is correct.
  - `WEATHER_HAS_EFFECT` is `ABILITYEFFECT_CHECK_ON_FIELD`, which has an HP test (`battle_util.c:2354-2362`). `WEATHER_HAS_EFFECT2` is the `FIELD_SPORT` default arm, which has no HP test (`:2325-2352`; `gLastUsedAbility` is battler 0's ability there, so the arm is always the default). `WEATHER_HAS_EFFECT2` is used only at `pokemon.c:2608`.
  - `suppressesWeather(battler, ignoreHP)` models both.
- **Texts.** These match `battle_message.c:156-157`, `:339-352` and `:922-945`.

### 3. Damage formula

- **Source.** `pokemon.c:2605-2637` sits in the special branch only. It comes after Light Screen and the doubles halving, and before Flash Fire and `+ 2`:
  - rain (temporary bit): Fire `/2`, Water `(15*d)/10`;
  - rain, sandstorm or hail with `gCurrentMove == MOVE_SOLAR_BEAM`: `/2`;
  - sun: Fire `(15*d)/10`, Water `/2`.
- **Engine.** `BattleFormulas.lua:393-416` has the same order and integer truncation (`idiv`). It has no minimum-1 clamp, and the physical branch is untouched.
- **Call sites.** All five sites that can matter pass `self:damageWeather()` and the move id:
  - ordinary hit (`:2533`);
  - multi-hit (`:2998`);
  - Triple Kick (`:3089`);
  - Explosion (`:1838`).
- **Sites left at nil.** These are correct because each is physical:
  - crash (`:2163`): Jump Kick and Hi Jump Kick are Fighting;
  - confusion self-hit (`:1556`): Pound record, type 0. Source does test `gCurrentMove` for the Solar Beam halving, but that test sits inside the special branch, which a type-0 hit never enters;
  - `EarlyRivalAI.lua:25`: Tackle and Scratch only.
- **Solar Beam.** The halving keys on move id 76, as `gCurrentMove` does. On the release turn `moveId` is the slot move, 76.

### 4. Freeze in sun

- **Source.** In `bsc.c:2257-2265`, `WEATHER_HAS_EFFECT && sun` refuses silently after the chance draw has been taken.
- **Engine.** Every freeze path runs through `applySecondaryStatus` (`BattleEngine.lua:1443-1471`):
  - the S2 freeze-hit family (Ice Beam, Ice Punch, Blizzard, Powder Snow) at `:2722`;
  - Tri Attack's `%3` pick at `:2738`;
  - the multi-hit status path at `:3062`.
- **Guard.** The new guard at `:1464` uses the HP-gated `activeWeather()`. The draws are already spent by the callers, and the refusal emits no event. FRLG has no primary freeze move.

### 5. AI

- **Rows.** `battle_ai_scripts.s:455-458`, `:495-503` and `:526-529` run `get_weather` then `if_equal AI_WEATHER_X, Score_Minus8`. The ids are SUN 0, RAIN 1, SANDSTORM 2 and HAIL 3 (`battle_ai.h:26-29`), the same as the `WEATHER_TYPE_*` enum at `battle_ai_script_commands.c:1374-1381`.
- **Stale result.** `Cmd_get_weather` (`:1385-1397`) tests the bits only (no Cloud Nine) and leaves `funcResult` unchanged when no weather is set.
  - For a power-0 move, `get_how_powerful_move_is` jumps to `AI_CheckBadMove_CheckSoundproof`. Its `get_ability AI_TARGET` (`battle_ai_scripts.s:91-92`) is the last writer.
  - The `if_move` and `if_effect` commands do not write `funcResult`. This holds even for a Soundproof target, so the stale value is the target's ability id.
  - `weatherMove` (`AICheckBadMove.lua:527-534`) reproduces this, using the module's existing known-ability simplification.
- **Diff scope.** The `AICheckBadMove.lua` diff touches only:
  - the new handler;
  - rows 115, 136, 137 and 164;
  - the `score` signature (`:674`);
  - the handler call (`:702`).
- **Memento.** Memento and every other row are untouched. Source Memento's fall-through into `AI_CBM_BatonPass` is not affected.
- **TrainerAI.** `TrainerAI.lua:112-113` passes the raw `engine.weather.kind`. This is correct: the AI ignores Cloud Nine. `AICheckBadMove.score` has no other caller in `src/`.

### 6. Admission, inventory and ROM fixture

- **Totals.** Admission is 289/65. The class table is consistent:
  - families: 114 + 0 + 83 + 1 = 198;
  - moves: 255 + 98 + 1 = 354;
  - zero-power moves: 74 + 64 = 138;
  - admitted: 255 + 34 = 289.
- **Uncovered positive.** `admitted_uncovered_positive` correctly stays at 34, because the four new moves have power 0.
- **Inventory report.** The report rows and totals match the test.
- **ROM fixture.** `tests/phase4_weather_effect_rom_test.lua` matches `battle_moves.h` for all five records, checked field by field:
  - Sandstorm: Rock (5), PP 10, target 0x10, flags 0;
  - Rain Dance: Water (11), PP 5;
  - Sunny Day: Fire (10), PP 5;
  - Hail: Ice (15), PP 10, flags `FLAG_PROTECT_AFFECTED` 0x02;
  - Solar Beam: effect 151, power 120, Grass (12), accuracy 100, PP 10, flags 0x32.
- **Family membership.** Each effect has exactly one member, 5 records in all.
- **No-ROM run.** The fixture follows the sibling fixtures' shape and skips cleanly without a ROM.

### 7. Regressions

- The full suite passes, including the W0 order tests.
- The weather loop consumes W0's `sides`, adds no draw, and leaves every earlier draw count unchanged.
- No file outside the task's MAY CHANGE list was touched; `main.lua` is untouched.
- The new event types are consumed only by the controller.

## Mutation results

Every mutation below was caught by `tests/battle_weather_test.lua`, and therefore by `test_all.sh`; I confirmed `test_all.sh` exits 1 for M12, M19 and M33.

| # | Mutation | Failures |
| --- | --- | --- |
| M01 | weather move never fails | 13 |
| M02 | PP spent only on success | 8 |
| M03 | duration 6 | 19 |
| M04 | permanent bit kept on overwrite | 1 |
| M05 | damage on the "stopped" turn | 8 |
| M06 | `/8` | 4 |
| M07 | no minimum 1 | 1 |
| M08 | no Sand Veil | 1 |
| M09 | type slot 1 only | 4 |
| M10 | Dig not exempt | 2 |
| M11 | Fly exempt | 4 |
| M12 | weather after status | 3 |
| M13 | weather before screens | 1 |
| M14 | Cloud Nine stops the timer | 4 |
| M15 | no 0-HP skip | 1 |
| M16 | no `isOver` stop | 2 |
| M17 | fixed player-first loop | 3 |
| M18 | no Cloud Nine HP gate | 2 |
| M19 | no freeze-in-sun | 2 |
| M20 | freeze ignores Cloud Nine | 1 |
| M21 | ordinary site passes nil | 5 |
| M22 | multi-hit site passes nil | 1 |
| M23 | Triple Kick site passes nil | 1 |
| M24 | Explosion site passes nil | 1 |
| M26 | Solar Beam halved in sun | 2 |
| M27 | Solar Beam not halved in hail | 2 |
| M28 | rain Water rounds up | 3 |
| M29 | sun Fire rounds up | 1 |
| M30 | weather term before Light Screen | 1 |
| M31 | weather term after `+2` | 4 |
| M32 | weather halving in the physical branch | 1 |
| M33 | AI leftover not the ability | 5 |
| M34 | TrainerAI passes nil | 2 |
| M35 | TrainerAI Cloud Nine-gated | 1 |
| M36 | AI sun/rain ids swapped | 6 |
| M37 | continues text | 1 |
| M38 | hail damage text | 1 |
| M39 | hail obeys the permanent flag | 1 |
| M40 | Ice in slot 1 only | 1 |
| M41 | Steel not exempt | 2 |
| M42 | no clamp to HP | 1 |
| M43 | no `checkFaint` | 4 |
| M44 | Solar Beam keyed on the effect | 1 |
| M45 | rain Fire not halved | 2 |
| M47 | last damage tick skipped | 4 |

Two mutations survived. Both are equivalent today; see F2.

- **M25:** the ordinary site uses the HP-gated `activeWeather()`.
- **M46:** the Explosion site uses `activeWeather()`.

## Findings

### F1. Minor (comment accuracy). The R3 note says no damage calculation can see a 0-HP Cloud Nine holder, but the Explosion site can

**Evidence.**
- `BattleEngine.lua:1140-1147` says the two macros "differ only for a 0-HP holder awaiting its replacement, which no damage calculation can see today".
- Explosion sets `attacker.hp = 0` (`BattleEngine.lua:1819`, mirroring `tryexplosion`) before its `calculateBaseDamage` call (`:1838`).
- So a Cloud Nine or Air Lock user of Self-Destruct or Explosion is a 0-HP holder that the damage block does see.

**Impact.**
- The code is correct. It uses `damageWeather()` (HP-free, `WEATHER_HAS_EFFECT2`) at that site, which is exactly the source behaviour in this case.
- The case is unreachable with real data. The holders are Psyduck, Golduck and Rayquaza, and none of them learns Self-Destruct or Explosion by level-up (`level_up_learnsets.h`) or from the FRLG tutor (`tutor_learnsets.h`). Gen 3 TMs include neither move.

**Correction (non-blocking).** Reword the comment. For example: the macros also differ for a Self-Destruct/Explosion user, whose HP is already 0 at its own damage calculation; `damageWeather` is the source-correct choice there; the case is unreachable with FRLG species data.

### F2. Info (test gap). Nothing pins the HP-free choice at the damage sites

**Evidence.**
- Mutations M25 and M46, which swap `damageWeather()` for `activeWeather()`, survive.
- The R3 test (`battle_weather_test.lua:430-433`) pins the two helpers but not which helper each call site uses.
- M25 is truly equivalent: no damage calculation runs with a 0-HP non-attacker.
- M46 is equivalent only because of the species data in F1.

**Correction (optional).** Add a synthetic check: a Cloud Nine holder using a Water-type Explosion record in rain still suppresses the rain term. It costs one assertion and closes the only live distinction.

### F3. Info. A stale header in `AICheckBadMove.lua` is already disclosed

`AICheckBadMove.lua:83-90` still lists weather and `get_weather` in the "confirmed no-op class". The task file's Deviations section records this as deliberate, because file ownership limits that file to the weather rows. The new handler's comment states that the rows left that class. No action is needed in W1; the file's next owner should drop "weather" from that prose.

## Not findings (checked and correct)

- **Fainted-holder cases.** The engine skips a fainted battler awaiting replacement (D4/R2). A fainted Cloud Nine holder no longer suppresses the weather, because `WEATHER_HAS_EFFECT` is HP-gated. Both are the documented R2 consequence and are pinned by tests.
- **Hail flag.** Hail's `FLAG_PROTECT_AFFECTED` has no effect, because Protect is not represented.
- **Ghost exemption.** The Ghost-without-Scope exemption in `Cmd_weatherdamage` is unreachable in the represented battles, and the task records it in Known limits.
- **Two-ability species.** In source, `get_ability AI_TARGET`'s `Random() % 2` guess for a two-ability species could change the stale value. This module has always documented the known-ability simplification, and W1 inherits it, as the task records.
