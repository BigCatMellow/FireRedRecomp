# Review: weather slice W3a implementation (`e2cb0ed`)

- Reviewed: commit `e2cb0ed` on `claude/wizardly-faraday-o45q9z` (parent `2eaeb4c`), read through `git diff e2cb0ed~1 e2cb0ed`
- Task: `work/tasks/phase4-weather-w3a.md`. Spec: `work/reports/phase4-weather-design-proposal.md` ("Abilities (W3a: no new hook)", the event table, the W3a verification and RNG notes) and `work/reviews/2026-10-14-weather-design-review.md`
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`. I fetched `src/battle_main.c`, `src/battle_util.c`, `src/battle_script_commands.c`, `data/battle_scripts_1.s`, `src/battle_message.c`, `include/battle_util.h` and `src/battle_ai_script_commands.c` from raw.githubusercontent.com at the pin. They are byte-identical to `/tmp/claude-0/status/battle_main.c`, `status/battle_util.c` and `bsc.c`. `/tmp/claude-0/bm.c` is a copy of `battle_message.c`, not `battle_main.c`. The `bm.c:` line numbers in the commit refer to the pinned `src/battle_main.c`, and that is the file I checked them against.
- Reviewer role: independent implementation review. I did not edit or commit anything except this file, which is left uncommitted.

## Verdict: **PASS**

Every changed line in `src/core/BattleEngine.lua` and `src/core/BattleFormulas.lua` matches its stated intent and the source. I found no leftover mutation from the failed restore step. The behaviour follows the pinned source in every area I checked. The new test kills every meaningful mutation I tried. The full suite and the repository checker pass. The findings below are all Info or Nit, and none needs a change before merge.

## 1. Stray-mutation audit (the restore step failed during the implementer's mutation testing)

- The commit touches exactly 6 files: the three `src/core` files, the new test, the task file and the inventory notes. No other source file changed.
- `git diff --check e2cb0ed~1 e2cb0ed` is clean. `git diff -w --ignore-blank-lines` gives the same stats as the plain diff, so there are no whitespace-only edits.
- Every hunk in `BattleEngine.lua` is intended: header comments (`:95`, `:272`, `:284`), the `ABILITY_RAIN_DISH = 44` constant (`:882`), `accuracyRoll` (`:1672-1683`), `endTurnOrder` (`:3311-3317`), the Rain Dish block and its comment (`:3433-3455`), and `runTurn` (`:3675-3677`).
- Every hunk in `BattleFormulas.lua` is intended: header comments (`:85-120`), `accuracyCheck` (`:541-570`), `effectiveSpeed` (`:627-650`) and `getWhoStrikesFirst` (`:652-665`).
- Only these code lines were removed:
  - the old `local weather` inside the Thunder branch, which was hoisted, not lost;
  - the old call lines and signatures, each replaced one for one by a version that adds the weather or Sand Veil argument.
- I checked each new line for an inverted test, a changed constant or a missing step:
  - doubling: `* 2`;
  - abilities: 33 with `"rain"` and 34 with `"sun"`;
  - Sand Veil: `* 80, 100`;
  - Rain Dish: `/ 16`, `math.max(1, ...)`, the `maxHP - hp` clamp, `hp > 0`, `hp < maxHP`, ability 44 and `"rain"`.

  All of them are correct. The Thunder rain sure hit and the sun accuracy of 50 are unchanged, and both still come before the Sand Veil term.
- The working tree was clean before the review and is clean after it. HEAD matches the commit.

## 2. Source checks (all confirmed)

| Area | Source | Engine | Result |
| --- | --- | --- | --- |
| Speed multiplier | `bm.c:3409-3426`: under `WEATHER_HAS_EFFECT`, Swift Swim with rain or Chlorophyll with sun gives 2, otherwise 1 | `BattleFormulas.lua:639-645` | Confirmed |
| Integer math | `bm.c:3428-3430`: `(speed * mult) * ratio[0] / ratio[1]`, one division | `speed * 2` then `applyStatMod` (`idiv(stat * r1, r2)`, `:220-223`) | Confirmed. The result is bit-exact (13 at -1 gives 17, not 16) |
| Step order | `bm.c:3432-3452`: stage, then badge boost and Macho Brace, then paralysis `/= 4`, then Quick Claw | stage, then paralysis (`:646-648`) | Confirmed. The badge boost, Macho Brace and Quick Claw are documented gaps, as before |
| Cloud Nine / Air Lock | `include/battle_util.h:49`, `bu.c:2354-2363`: the check skips holders at 0 HP | `activeWeather()` (`BattleEngine.lua:1191`) is passed at both call sites | Confirmed |
| Speed readers | `bm.c:3613` (turn start), `bu.c:494` (`ENDTURN_ORDER`), `bm.c:2870` (battle start, W3b), `aisc.c:1058/1066` (AI `if_user_goes_first`) | The only engine callers are `runTurn` (`:3675`) and `endTurnOrder` (`:3314`). No ported AI reads speed (grep finds nothing) | Confirmed. The run path (`:3645-3650`) still reads the raw `.speed`, matching `bm.c:4261-4263` |
| End-of-turn timing | `ENDTURN_ORDER` is field case 0, before `ENDTURN_RAIN..HAIL` (`bu.c:451-463`, `:484-501`) | `endTurnOrder` runs before `decaySideTimers` and `resolveWeatherEndTurn` (`:3350-3355`) | Confirmed. Weather set this turn counts, and the last turn of a weather still doubles |
| Sand Veil | `bsc.c:1066-1074`: stage ratio, Compound Eyes `*130/100`, then `WEATHER_HAS_EFFECT && target ability == SAND_VEIL && sandstorm` `*80/100`, then Hustle, each step truncating, then one `Random() % 100 + 1` | `accuracyCheck` (`:561-570`). The flag is `activeWeather() == "sandstorm" and defender.ability == 8` (`BattleEngine.lua:1680`) | Confirmed. Order and target are correct |
| Thunder and semi-invulnerable | `AccuracyCalcHelper` (`bsc.c:958-1001`): the on-air, underground and underwater misses, then the Thunder rain sure hit, all before the calculation. Sun accuracy 50 at `:1062-1064` | `semiInvulnerableMiss` first, then the Thunder rain return and the sun 50, then Sand Veil (`:1673-1683`) | Confirmed. Thunder in sand against Sand Veil gives 56 |
| Accuracy call sites | Each one is a `Cmd_accuracycheck` path: status moves, damaging moves, confusion moves, Swagger/Flatter, and Triple Kick (once per kick) | All of them go through `accuracyRoll` | Confirmed. No OHKO or other bespoke accuracy path exists in the engine |
| Rain Dish placement | `DoBattlerEndTurnEffects` (`bu.c:720-743`, `:774-778`, `:953`): `ENDTURN_ABILITIES` before `POISON/BAD_POISON/BURN` and `THRASH`, one battler at a time in `gBattlerByTurnOrder`, after every field case (weather damage included) | Start of each battler's iteration in `resolveStatusEndTurn` (`:3449-3455`). That function runs after `resolveWeatherEndTurn` and uses the same `sides` order | Confirmed |
| Rain Dish condition and amount | `bu.c:1816-1831`: `hp != 0`, `WEATHER_HAS_EFFECT && rain`, `maxHP > hp`; `maxHP/16`, 0 becomes 1, negated | `hp > 0`, ability 44, `activeWeather() == "rain"`, `hp < maxHP`; `max(1, floor(maxHP/16))`, clamped to the missing HP | Confirmed. `datahpupdate` clamps at maxHP. At full HP there is no script and no text. The weather check runs for each battler, so a Cloud Nine holder that fainted earlier in the phase no longer suppresses the heal, as in source |
| Rain Dish text | `bs1.s:3938-3944` prints the string, then runs `healthbarupdate`/`datahpupdate`. `msg.c:283` is `"{B_ATK_NAME_WITH_PREFIX}'s {B_ATK_ABILITY}\nrestored its HP a little!"`. `gBattlerAttacker` is the holder (`bu.c:1819`) | Controller `:507-513`: the text, then the HP entry | Confirmed |
| RNG | Rain Dish and Sand Veil add no draws. Swift Swim and Chlorophyll can add or remove the tie draw at turn start and at end of turn | Same | Confirmed |

## 3. Mutation testing

Each mutation was applied to the working file, then `lua5.1 tests/battle_weather_w3a_test.lua` and `bash scripts/test_all.sh` were run, then the file was restored with `git checkout -- <file>`. Afterwards `git status` and `git diff` were clean.

| Mutation | W3a test | Full suite |
| --- | --- | --- |
| No doubling (`* 1`) | 34 fail | fail |
| Doubling after the stage | 3 fail | fail |
| Doubling after paralysis | 6 fail | fail |
| Chlorophyll in rain | 12 fail | fail |
| Swift Swim in sun | 26 fail | fail |
| Battler 2 ignores weather | 2 fail | fail |
| End-of-turn order without weather | 21 fail | fail |
| End-of-turn order with raw `weather.kind` (ignores Cloud Nine) | 8 fail | fail |
| Turn start without weather | 17 fail | fail |
| Turn start with raw `weather.kind` | 8 fail | fail |
| No Sand Veil | 9 fail | fail |
| Sand Veil `*81` | 3 fail | fail |
| Sand Veil before Compound Eyes | 1 fail | fail |
| Sand Veil read from the attacker | 5 fail | fail |
| Sand Veil ignores Cloud Nine | 2 fail | fail |
| Sand Veil in any weather | 3 fail | fail |
| Thunder rain sure hit removed | 0 fail (W3a) | fail (W2 suite) |
| Rain Dish without the full-HP check | 2 fail | fail |
| Rain Dish `/8` | 9 fail | fail |
| Rain Dish without the minimum of 1 | 1 fail | fail |
| Rain Dish without the clamp | 1 fail | fail |
| Rain Dish ignores Cloud Nine | 3 fail | fail |
| Rain Dish in sun | 19 fail | fail |
| Rain Dish without the `hp > 0` check | 1 fail | fail |
| Rain Dish ability id 45 | 18 fail | fail |
| Rain Dish emits no event | 15 fail | fail |
| Rain Dish moved after status damage | 5 fail | fail |
| Rain Dish moved after the Thrash tick | 16 fail | fail |
| Controller text changed | 2 fail | fail |
| Controller HP entry dropped | 1 fail | fail |

Every mutation is killed by the W3a test or the full suite. With the tree unchanged, the W3a test passes 141/141, `bash scripts/test_all.sh` passes 184 files, and `lua5.1 scripts/check_repository.lua` passes.

## 4. Regressions (W0, W1, W2 and earlier slices)

- No existing assertion changed. All 184 test files pass unchanged, including the W0, W1 and W2 weather tests and the earlier status, confusion and flinch slices.
- The `getWhoStrikesFirst` and `accuracyCheck` signatures only gained trailing optional parameters. A nil weather or a nil Sand Veil flag gives the previous behaviour, so the older direct callers in tests still work.
- The W2 Thunder handling is unchanged. Hoisting `local weather` out of the branch changes no behaviour.
- `AICheckBadMove.lua`, `main.lua` and the W3b scope (the switch-in hook and battle-start ordering) are untouched, as the task requires.

## Findings

1. **Info. No stray mutation.** The commit contains only the intended hunks (see section 1). The hand restore left nothing behind in `BattleEngine.lua` or `BattleFormulas.lua`.
2. **Nit. Confusing test label.** `tests/battle_weather_w3a_test.lua:387` reads `"Compound Eyes then Sand Veil: 78 misses (not 78)"`. The assertion is correct: draw 77 gives roll 78, which misses the threshold of 77 and would hit 78 if Sand Veil came first. The `(not 78)` is meaningless, though. A clearer label would be `"78 misses (Sand Veil first would give 78 and hit)"`. Optional.
3. **Nit. Citation shorthand.** The commit message writes `bm.c:3409-3452` and `bu.c:...` in the proposal's abbreviation style, meaning `battle_main.c` and `battle_util.c`. The code comments use full `src/battle_main.c` paths, so nothing in the tree is ambiguous. The only confusion is with the unrelated scratch copy `/tmp/claude-0/bm.c`, which is `battle_message.c`. No action needed.
4. **Info. Task file's mutation count.** The task file says "x2 after paralysis fails 3". My version of that mutation, with the doubling moved after both the stage and paralysis, fails 6. The difference depends on how the mutation is built and does not affect the result: the mutation is killed either way.
5. **Info. Documented gaps confirmed.** Two gaps stay documented and correct:
   - The badge boost, Macho Brace and Quick Claw sit between the stage and paralysis, or after paralysis, in `GetWhoStrikesFirst` and are not modeled.
   - Bright Powder and Lax Incense (`HOLD_EFFECT_EVASION_UP`, after Hustle) are not modeled.

   With no items or badges in the engine, both are no-ops. The R2/D4 caveat also holds: a 0-HP battler awaiting its replacement gets no Rain Dish heal, consistent with W1 weather damage.
