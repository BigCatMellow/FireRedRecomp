# Review: weather slice W3b implementation (`4092985`)

- Reviewed: commit `4092985` on `claude/wizardly-faraday-o45q9z` (parent `de9f4a8`), read through `git show 4092985`
- Task: `work/tasks/phase4-weather-w3b.md`. Spec: `work/reports/phase4-weather-design-proposal.md` ("Abilities (W3b: switch-in hook)", the "Battle starts" inventory, the events table, the W3b verification row) and `work/reviews/2026-10-14-weather-design-review.md` (D3, F7)
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`. I fetched these files from raw.githubusercontent.com at the pin myself: `src/battle_util.c`, `src/battle_main.c`, `src/battle_script_commands.c`, `data/battle_scripts_1.s`, `src/battle_message.c`, `src/data/text/abilities.h`, `src/battle_controller_oak_old_man.c` and `include/constants/battle.h`. My `battle_util.c` and `abilities.h` are byte-identical to the implementer's `/tmp/claude-0/w3b/bu.c` and `abtext.h`.
- Reviewer role: independent implementation review. I did not edit `main.lua`, `TrainerBattleOrchestrator.lua` or any other tracked file. I changed source files only temporarily, for mutation testing, and restored them from backups. `git status` is clean apart from this file, which is left uncommitted.

## Verdict: **PASS**

The engine hook, battle-start ordering, voluntary and forced call sites and controller texts match the pinned source. I traced the deviation from the design, which resolves battle start in `BattleSceneController.new` instead of in three new `main.lua` calls, through every live controller construction in `main.lua` and through the orchestrator. It resolves battle start exactly once per battle, at the right moment. It also presents forced-switch switch-in text after the caller's send-out text on both the player and the foe path. Battles without a weather ability draw no extra RNG. All 27 mutations I tried were caught. The full suite and the repository checker pass. The findings below are Minor, Info or Nit, and none blocks merge.

## 1. Ability effects (`AbilityBattleEffects` ON_SWITCHIN, `battle_util.c:1704-1815`)

| Point | Source | Engine (`src/core/BattleEngine.lua`) | Result |
| --- | --- | --- | --- |
| Drizzle guard and write | `:1748-1756`: `if (!(gBattleWeather & B_WEATHER_RAIN_PERMANENT))`, then `gBattleWeather = RAIN_PERMANENT \| RAIN_TEMPORARY` | `resolveSwitchInAbility` `:3359-3366`: return if `kind == "rain" and permanent`, else `{kind="rain", permanent=true}` | Confirmed |
| Sand Stream | `:1757-1765`: guard `SANDSTORM_PERMANENT`; assign `B_WEATHER_SANDSTORM` (both bits) | same function, family `"sandstorm"` | Confirmed |
| Drought | `:1766-1774`: guard `SUN_PERMANENT`; assign `B_WEATHER_SUN` | same function, family `"sun"` | Confirmed |
| Same-family permanent skipped silently | guard false → no script pushed, `effect` stays 0 | early `return` with no event | Confirmed |
| Temporary becomes permanent | the guard tests only the permanent bit, so temporary rain passes and is rewritten with both bits | `kind == family` but `permanent == false` passes the guard | Confirmed; the test pins counter 3 kept |
| Overwrite rules | whole-word `=` assignment overwrites any other family, permanent or temporary, hail included | the whole `self.weather` table is replaced | Confirmed. Rain Dance and similar moves still fail against permanent rain (`:2061` tests `kind` only, matching `gBattleWeather & B_WEATHER_RAIN`), and they still overwrite permanent weather of another family with the temporary bit (`:2064`) |
| Timer untouched | no write to `gWishFutureKnock.weatherDuration`; `ENDTURN_RAIN/SANDSTORM/SUN` skip the decrement while the permanent bit is set (`:624-691`) | the hook does not touch `weatherDuration`; `resolveWeatherEndTurn` (`:3514-3521`) decrements only when not permanent | Confirmed |
| No Cloud Nine check | no `WEATHER_HAS_EFFECT` in these cases; Cloud Nine and Air Lock (`:1798-1813`) only loop `CastformDataTypeChange` | no `activeWeather()` test in the hook; abilities 13 and 77 emit nothing | Confirmed |
| Safari skip | `:1678` | not modelled (no Safari battle) | Documented |
| Texts | `battle_message.c:263/284/285`: `"{B_SCR_ACTIVE_NAME_WITH_PREFIX}'s {B_SCR_ACTIVE_ABILITY}\nmade it rain!"` / `"…\nwhipped up a sandstorm!"` / `"…\nintensified the sun's rays!"`; names `abilities.h:166/209/234` DRIZZLE, SAND STREAM, DROUGHT | `BattleSceneController.lua:68-75`, `:554-558` | Confirmed, character for character, including the single `\n` after the ability name. The Wild/Foe prefix is omitted (finding 6) |
| Scripts | `battle_scripts_1.s:3918-3924`, `:3946-3952`, `:4013-4019`: pause, printstring, animation, Forecast check; no RNG | one text event, no draw | Confirmed |

## 2. Battle-start order (`TryDoEventsBeforeFirstTurn`, `battle_main.c:2856-2927`)

- **Order computed once, then every lead's ON_SWITCHIN fastest first.** At `switchInAbilitiesCounter == 0`, source sorts `gBattlerByTurnOrder` with `GetWhoStrikesFirst(i, j, TRUE)` (`:2864-2872`). It then calls `AbilityBattleEffects(ABILITYEFFECT_ON_SWITCHIN, gBattlerByTurnOrder[counter])` for each battler (`:2879-2887`). The function returns after each effect and resumes with the counter, so it does not sort again. The engine's `battleStartOrder` (`:3385-3396`) runs once, and `resolveBattleStart` (`:3409-3419`) loops it. Confirmed: the slower setter runs last, and its weather stays.
- **Speed only.** With `ignoreChosenMoves = TRUE`, both moves are `MOVE_NONE`, so priority is 0 and only speed counts (`:3478-3482`, `:3517-3523`). The engine uses `effectiveSpeed` (stage and paralysis). Weather is always clear at this point, so Swift Swim and Chlorophyll cannot apply. Confirmed.
- **Deferred tie draw (D3).** Source: `if (speedBattler1 == speedBattler2 && Random() & 1) strikesFirst = 2`. Battler 0 is the player, and a return value other than 0 swaps the pair. A draw of 0 puts the player first, and a draw of 1 puts the foe first. `breakBattleStartSpeedTie` (`:3375-3377`) returns player first and draws nothing. This is the single named helper that D3 asked for. A test pins it with scripted draws of 1, and the limit is recorded in the task's Known limits. Confirmed.
- **Nothing else should come first.** The intro ends `BattleIntroPrintPlayerSendsOut` → `BattleIntroPlayerSendsOutMonAnimation` → `gBattleMainFunc = TryDoEventsBeforeFirstTurn` (`battle_main.c:2797-2831`). Trainer battles run: "would like to battle", "sent out", foe send-out, "Go!". Wild battles run: "appeared", "Go!". The only thing between the sort and ON_SWITCHIN is `ABILITYEFFECT_SWITCH_IN_WEATHER` (`:2873-2878`), which is unreachable in FRLG at the pin (review F7). The engine asserts on those weather ids (`OVERWORLD_BATTLE_WEATHERS`, `:3410-3411`). The Oak tutorial's "For Pete's sake" text is printed by the Oak/Old Man controller's send-out step (`battle_controller_oak_old_man.c:452`, `PrintOakText_ForPetesSake`). That is before `TryDoEventsBeforeFirstTurn`, so ability text after the Oak intro lines is the correct order.

## 3. Event ordering and integration of voluntary and forced switches

- **Voluntary switch.** `BattleScript_ActionSwitch` reaches `switchineffects BS_ATTACKER` at `battle_scripts_1.s:3076`, before the foe's action. The engine calls the hook directly after the `switch` event and before `resolveMove(FOE)` (`:3709-3713`). `Cmd_switchineffects` (`battle_script_commands.c:4961-5010`) checks Spikes first, but Spikes are not represented. Confirmed.
- **Forced replacement.** In `BattleScript_HandleFaintedMon`, `printstring STRINGID_SWITCHINMON` and `switchinanim` come before `switchineffects BS_FAINTED` (`:2879-2884`). The engine appends the hook after `forcedSwitchResolved` (`:3315-3326`). The controller shows the queued events after the callback's own send-out text (`BattleSceneController.lua:216`, `:722-725`). Confirmed.
- **`takeForcedSwitchEvents` queue.** It is filled only by `resolveForcedSwitch`. `takeForcedSwitchEvents` (`:3331-3335`) returns the queue and resets it, and `runTurn` clears it at turn start (`:3657`). `forcedSwitchResolved` has no controller text, so the drained list adds only the ability line and no duplicate send-out.
- **Double faint.** `finalizeFaintSequence` queues the player before the foe (`:1300-1310`), as `HandleFaintedMonActions` walks battler ids in order. In the controller, when the messages drain, main's `onMessagesComplete` returns nil for a pending player switch, and the PARTY selector opens. `onForcedSwitchChoice` then runs `resolveForcedSwitch("player")`, and the controller drains only the player's events. After those messages, `onMessagesComplete` resolves the foe through the orchestrator, and the second drain holds only the foe's events. The result is the player's setter, then the foe's "sent out", then the foe's setter, which matches source's per-battler `BattleScript_HandleFaintedMon` sequence. A test covers both sides queued in resolution order.

## 4. Integration: `main.lua` and `TrainerBattleOrchestrator.lua` (read-only trace)

There are exactly three `Battle.Controller.new` calls in the repository outside the controller itself: `main.lua:1329`, `:1398` and `:1554`. No tool, script or other `src` module constructs a `BattleEngine`. `world.battle` is assigned a controller only at `:1345`, `:1437` and `:1731`, and otherwise only set to nil. No path recreates a controller mid-battle or reuses an engine for a second controller. The constructor guard (`not battleStartResolved and turn == 0`, `BattleSceneController.lua:131-132`) and the engine assert (`:3410`) would also protect against that.

| Battle | Engine, then controller | Intro before the battle-start text | Resolves |
| --- | --- | --- | --- |
| Wild (`startWildBattle`) | `:1315` then `:1329`; nothing in between touches the engine | default `"Wild X appeared!"`, `"Go! Y!"` | once, after "Go!" ✔ |
| Oak-lab rival / first battle (`startRivalBattle`) | `:1390` (`firstBattle=true`) then `:1398`, inside `pcall` | rival lines, "would like to battle", "sent out", "Go!", then the three OAK lines | once, after the Oak lines, matching source (section 2) ✔. The level-5 starters have no weather ability |
| Trainer, one foe (`startTrainerBattle`) | `:1538` then `:1554`, inside `pcall` | "would like to battle", "sent out", "Go!" | once ✔ |
| Trainer, two foes (orchestrator) | same | same | once at the start ✔. The second foe's ability runs through `resolveForcedSwitch` and is not a new battle start |
| Early rival in the field | goes through `startTrainerBattle` (RivalAI flags are accepted at `:1505-1507`) | same | once ✔ |

Forced-switch messages in the real flow:

- **Foe replacement.** In `TrainerBattleOrchestrator.lua:36`, `engine:resolveForcedSwitch("foe", …)` runs inside main's `onMessagesComplete` (`main.lua:1557-1593`), which ignores the return value. Main sets `controller.foeName` before it returns `{trainerName .. " sent out " .. incomingName .. "!"}`. The controller then appends `_takeForcedSwitchMessages()` at `:216`, so the text uses the new foe's name and comes after the send-out line. ✔
- **Player replacement.** In `main.lua:1621`, `resolveForcedSwitch("player", incoming)` runs inside `onForcedSwitchChoice`, which ignores the return value. `controller.playerName` is updated before the callback returns `{"…, come back!\nGo! X!"}`. The controller appends the drained events after it (`:722-725`). ✔
- **Voluntary switch.** In `main.lua:1690`, `controller:_runTurn({action="switch", …})` runs the hook inside `runTurn`, and the text appears in turn order. The callback returns nil, the drain is empty after `runTurn`'s clear, and `_runTurn`'s messages are kept. ✔
- **Wild battle.** It has no `hasReplacement`, so there is no forced switch.

The design review's lane note ("W3b touches `main.lua`") is now moot: neither file changed, and the behaviour the design asked for is delivered.

## 5. Regressions and RNG

- The commit changes no existing test. `bash scripts/test_all.sh` passes all 185 files in no-ROM mode, `lua5.1 tests/battle_weather_w3b_test.lua` reports 111 passed and 0 failed, and `lua5.1 scripts/check_repository.lua` passes. `git diff --check 4092985~1 4092985` is clean.
- **RNG.** The hook, `battleStartOrder` and `resolveBattleStart` never touch `self.rng`. With no ability 2, 45 or 70 present, `resolveBattleStart` returns `{}`, and the controller's intro is unchanged. To check that the existing suites would notice a change in draw counts, I added one draw to `resolveBattleStart` (mutation M26). Besides the W3b test, it broke existing controller tests elsewhere in `test_all` (the Double Kick KO order checks). Draw counts in battles without a weather ability are therefore unchanged and protected.
- **Earlier weather slices.** W0's `ENDTURN_ORDER`, W1's weather moves and end-of-turn tick, W2's consumers and W3a's speed, Sand Veil and Rain Dish all pass unchanged. W1's `resolveWeatherEndTurn` already honoured `permanent`, and W3b is the first slice that makes it true.
- The ROM-gated end-to-end tests (`tests/phase4_*_rom_test.lua`) skip without `POKEPORT_ROM`, so neither I nor the implementer ran them. Their fixture (trainer 89, two foes) has no weather ability, so the new code is a no-op there (finding 7).

## 6. Mutation testing

Each mutation was applied to a pristine copy from a backup in my scratchpad. I ran both `lua5.1 tests/battle_weather_w3b_test.lua` and `bash scripts/test_all.sh` on each, then restored the file. `git status` was clean afterwards. **All 27 mutations were caught by both runs.**

| # | Mutation | W3b failures |
| --- | --- | --- |
| M1 | guard on any bit of the family | 3 |
| M2 | no guard | 5 |
| M3 | sets temporary instead of permanent | 37 |
| M4 | hook resets `weatherDuration = 5` | 17 |
| M5 | battle-start order reversed | 6 |
| M6 | tie helper puts the foe first | 4 |
| M6b | tie draws `next16() % 2` like source | 8 |
| M7 | no voluntary hook | 7 |
| M8 | voluntary hook after the foe's move | 3 |
| M9 | no forced hook | 9 |
| M10 | no queue clear in `runTurn` | 1 |
| M11 | `take` does not clear | 4 |
| M12 | `battleStartResolved` never set | 4 |
| M13 | Sand Stream and Drought families swapped | 35 |
| M14 | controller skips the battle start | 5 |
| M15 | controller drops the `turn == 0` guard | 1 |
| M16 | controller battle start disabled | 5 |
| M17 | foe drain before the send-out | 1 |
| M18 | no foe-path drain | 1 |
| M19 | no player-path drain | 2 |
| M20 | player drain before the send-out | 1 |
| M21 | "made it rain." | 4 |
| M22 | "SANDSTREAM" | 4 |
| M23 | space instead of `\n` | 9 |
| M24 | wrong sun text | 2 |
| M25 | start order uses raw speed (ignores paralysis) | 1 |
| M26 | battle start always draws once | 13 (plus existing controller tests) |
| M27 | battle start draws on any tie | 4 |

## Findings

1. **Minor (advisory): the queue duplicates the return value.** `resolveForcedSwitch` both returns its events and queues them (`BattleEngine.lua:3315-3326`), and the controller drains the queue after `onForcedSwitchChoice` and `onMessagesComplete`. Today both callers ignore the return value, so nothing is shown twice. A future caller that runs inside a controller callback and presents the returned list (as the design originally proposed for `main.lua:1621` and `TrainerBattleOrchestrator.lua:36`) would show the switch-in text twice. The comment at `:3328-3330` describes the intended use. Recommendation: when that wiring is next touched, add a one-line warning in the engine header's forced-switch paragraph, or in the orchestrator, saying that callers hosted by the controller must not also present the returned list. No change is needed for this slice.
2. **Minor (design note): rule execution sits in a presentation constructor.** `BattleSceneController.new` now mutates engine state by calling `resolveBattleStart`. The trace in section 4 shows this is correct for every live path, and no consumer builds a `BattleEngine` without a controller. A future headless consumer (a replay runner or simulator) must call `engine:resolveBattleStart()` itself. The engine comment at `:3401-3403` says so. Info only.
3. **Nit: timing wording.** The engine comment says to call `resolveBattleStart` "after the intro/send-out messages" (`BattleEngine.lua:3401`). In practice it runs at controller construction, before the intro is displayed, and only its messages are queued after the intro. Nothing reads `engine.weather` during the intro (`main.lua` has no reference to battle weather), so this is not observable. The comment could say "presented after".
4. **Info: the badge boost at battle start is not modelled.** Source applies `*110/100` to player-side speed with `FLAG_BADGE03_GET` in `GetWhoStrikesFirst` (`battle_main.c:3443-3446`), including at battle start. The engine omits it everywhere, as before. For W3b this could flip which weather stays in a reachable case: a traded Kyogre or Groudon lead after the third badge facing a trainer Tyranitar with a slightly higher raw speed. The gap is already in the task's Known limits ("badge boost … not represented"). It belongs with the existing turn-order gap, not this slice.
5. **Info: the SHIFT-style prompt is pre-existing and out of scope.** In trainer battles with the default SHIFT style, source asks the player whether to switch before the foe's replacement (`battle_scripts_1.s:2842-2873`). A switch there would run the player's `switchineffects` before the foe's. The orchestrator does not model the prompt. This predates W3b, and W3b does not make it worse.
6. **Info: the "Wild"/"Foe" prefix is omitted.** `B_SCR_ACTIVE_NAME_WITH_PREFIX` would give "Foe TYRANITAR's SAND STREAM…". The controller leaves out the prefix, consistent with every existing controller text, and the task's Known limits record this.
7. **Info: the ROM-gated tests were not run.** The `phase4_*_rom_test.lua` files exercise `main.lua`'s trainer start through `App.configureTrainerBattleTest`, but no verified ROM is available here. Their fixture has no weather ability, so the W3b paths are no-ops there. Running them once with `POKEPORT_ROM` set before merge would confirm the constructor change against the live seam.

## Citations checked

The commit's line citations match the pin: `battle_util.c:1704-1815`, `:1748-1756`, `:1757-1765`, `:1766-1774`, `:1798-1813`, `:1709-1746`, `:1678`; `battle_main.c:2856-2927`, `:2864-2872`, `:2873-2878`, `:2879-2887`, `:2926`; `battle_script_commands.c:4961-5010`; `battle_scripts_1.s:3046-3078` (`:3076`), `:2824-2884` (`:2879-2884`), `:3918-3924`, `:3946-3952`, `:4013-4019`; `battle_message.c:263`, `:284`, `:285`; `abilities.h:166`, `:209`, `:234`.
