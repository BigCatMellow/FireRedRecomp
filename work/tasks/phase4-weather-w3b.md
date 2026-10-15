# Task: weather slice W3b — Drizzle/Sand Stream/Drought switch-in weather

- Task ID: `P4-WEATHER-W3B`
- Status: `IMPLEMENTED — awaiting independent review`
- Lane: full relay (weather design proposal, W3b slice)
- Spec: [weather design proposal](../reports/phase4-weather-design-proposal.md)
  (§8 "Switch-in weather abilities", "Abilities (W3b: switch-in hook)", the
  events table, the W3b slice row and verification plan), with the
  [design review](../reviews/2026-10-14-weather-design-review.md) folded in
  (D3 accepted as a deferral; F7: keep the overworld-weather no-op
  assertion).
- Base: `de9f4a8` on `claude/wizardly-faraday-o45q9z` (W0, W1, W2 and W3a
  merged).

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

- `AbilityBattleEffects(ABILITYEFFECT_ON_SWITCHIN)`
  (`src/battle_util.c:1704-1815`):
  - Drizzle (`:1748-1756`): `if (!(gBattleWeather & B_WEATHER_RAIN_PERMANENT))`
    assign `RAIN_PERMANENT | RAIN_TEMPORARY`. A temporary rain is converted,
    with the text.
  - Sand Stream (`:1757-1765`): unless `SANDSTORM_PERMANENT`, assign
    `B_WEATHER_SANDSTORM` (both bits, `include/battle.h:210-212`).
  - Drought (`:1766-1774`): unless `SUN_PERMANENT`, assign `B_WEATHER_SUN`
    (both bits, `:213-215`).
  - Each is a whole-word assignment: it overwrites any other family,
    temporary or permanent, hail included. `weatherDuration` is not touched.
    No `WEATHER_HAS_EFFECT` test: under Cloud Nine/Air Lock the weather is
    still set and announced. No RNG.
  - Same family already permanent: nothing happens and nothing prints
    (verified: the guard is the family's permanent bit only).
  - Cloud Nine/Air Lock (`:1798-1813`) only re-check Castform: no text.
  - The whole function is skipped in Safari battles (`:1678`; not modelled).
- Scripts: `BattleScript_DrizzleActivates`/`SandstreamActivates`/
  `DroughtActivates` (`data/battle_scripts_1.s:3918-3924`, `:3946-3952`,
  `:4013-4019`): pause, printstring, animation,
  `BattleScript_WeatherFormChanges` (Forecast, not represented).
- Texts (`src/battle_message.c:263`, `:284`, `:285`):
  `"{B_SCR_ACTIVE_NAME_WITH_PREFIX}'s {B_SCR_ACTIVE_ABILITY}\nmade it rain!"`,
  `"...\nwhipped up a sandstorm!"`, `"...\nintensified the sun's rays!"`;
  one line break, after the ability name. Ability names
  `src/data/text/abilities.h:166` DRIZZLE, `:209` SAND STREAM, `:234`
  DROUGHT.
- Battle start, `TryDoEventsBeforeFirstTurn` (`src/battle_main.c:2856-2927`):
  order once with `GetWhoStrikesFirst(i, j, TRUE)` (`:2864-2872`; speed only,
  a tie draws `Random() & 1`), the overworld weather case (`:2873-2878`),
  then `ON_SWITCHIN` fastest first (`:2879-2887`). The slower setter runs
  last and its weather stays.
- Voluntary switch: `BattleScript_ActionSwitch`
  (`data/battle_scripts_1.s:3046-3078`) ends with `switchineffects
  BS_ATTACKER` (`:3076`) before the foe's action.
- Forced replacement: `BattleScript_HandleFaintedMon` (`:2824-2884`):
  `printstring STRINGID_SWITCHINMON`, `switchinanim`, then `switchineffects
  BS_FAINTED` (`:2884`). `Cmd_switchineffects`
  (`src/battle_script_commands.c:4961-5010`) calls `ON_SWITCHIN`.
- Overworld weathers acted on by `ABILITYEFFECT_SWITCH_IN_WEATHER`
  (`src/battle_util.c:1709-1746`): RAIN 3, RAIN_THUNDERSTORM 5, SANDSTORM 8,
  DROUGHT 12, DOWNPOUR 13 (`include/constants/weather.h`); unreachable in
  FRLG at the pin (review F7).

## Design (as implemented)

- `BattleEngine` constants `ABILITY_DRIZZLE = 2`, `ABILITY_SAND_STREAM = 45`,
  `ABILITY_DROUGHT = 70`, `SWITCH_IN_WEATHER_ABILITIES`, and
  `OVERWORLD_BATTLE_WEATHERS`.
- `BattleEngine:resolveSwitchInAbility(side, events)`: for a weather ability,
  unless `weather.kind == family and weather.permanent`, set
  `{kind = family, permanent = true}` and emit
  `weatherAbility{side, ability, kind}`. Duration untouched. Nothing for any
  other ability (Cloud Nine and Air Lock included).
- `BattleEngine:battleStartOrder()`: `effectiveSpeed` of each lead (no
  priority); a tie goes through `BattleEngine:breakBattleStartSpeedTie()`,
  the single D3 helper, which returns player first and draws nothing.
- `BattleEngine:resolveBattleStart(overworldWeather)`: once only (asserts);
  asserts that `overworldWeather` is not one of the unreachable battle
  weathers (any other value is a no-op); runs the hook for each lead in
  `battleStartOrder` and returns the events.
- `runTurn`'s switch branch: the hook runs after the `switch` event and
  before the foe's move.
- `resolveForcedSwitch`: the hook runs after `forcedSwitchResolved`; the
  returned list carries both. The same events are also queued on the
  engine; `BattleEngine:takeForcedSwitchEvents()` returns and clears that
  queue, and `runTurn` clears it at turn start.
- `BattleSceneController`:
  - `weatherAbility` → `"X's DRIZZLE\nmade it rain!"` /
    `"X's SAND STREAM\nwhipped up a sandstorm!"` /
    `"X's DROUGHT\nintensified the sun's rays!"` (names without the
    Wild/Foe prefix, as every existing controller text).
  - `new` resolves the battle start when the engine supports it, has not
    resolved it and is at turn 0, and appends its messages after the intro
    messages.
  - After `onForcedSwitchChoice` (player) and after `onMessagesComplete`
    (foe), it appends the messages of `takeForcedSwitchEvents()` behind the
    callback's send-out text. Engines without these methods (test fakes) are
    unaffected.
- Header notes updated in `BattleEngine.lua` (event list, forced-switch
  event, ability list, slice list).

## Wiring outside the engine and controller (none needed)

The design names call sites in `main.lua` (the three starts) and a caller
presentation change in `main.lua:1621` and
`TrainerBattleOrchestrator.lua:36`. Neither file is changed:

- Every live start (`startWildBattle`, `startRivalBattle`, the trainer
  start) builds a fresh engine and then its `BattleSceneController` with the
  intro messages; the controller now resolves and presents the battle start
  itself, after those messages.
- Both `resolveForcedSwitch` callers run inside controller callbacks
  (`onForcedSwitchChoice` and `onMessagesComplete`), so the controller takes
  the queued events after each callback and shows them after its send-out
  message.
- The voluntary path already goes through `controller:_runTurn`.

## MAY CHANGE

- `src/core/BattleEngine.lua`, `src/core/BattleSceneController.lua`
- `tests/battle_weather_w3b_test.lua` (new)
- `work/reports/phase4-move-effect-inventory.md` (notes only), this task file

## MUST NOT CHANGE

`main.lua`, party/Dex code, `TrainerBattleOrchestrator.lua`, coordination
and roadmap files, `AICheckBadMove.lua`, `BattleFormulas.lua`, Forecast.

## Changed assertions

None. Every existing test passes unchanged: no existing test gives a lead
or a replacement ability 2, 45 or 70; the battle start adds no draw; the
controller's added steps are no-ops for engines without the new methods and
for engines with no weather ability. The inventory's rows and totals are
unchanged; the notes of rows 115, 136, 137 and 164 and the common-limits
line now point to W3b.

## Acceptance

- `tests/battle_weather_w3b_test.lua`: 111 checks, exact `scriptedRng` draw
  counts:
  - The hook for all three abilities: from clear; same family permanent
    (silent, counter kept); same family temporary (converted, announced,
    counter kept at 3); overwriting seven family/permanence pairs (hail
    included) with the counter kept; abilities 0, 13, 77 and 33 emit nothing;
    Drizzle under a Cloud Nine foe is set and announced but has no effect.
  - Battle start: faster lead first, slower setter wins, either side; a
    paralysed 100 (→ 25) is slower than 30; two Drizzles announce once; a
    lone setter; nothing and no draw with no setter at a tie; the second
    call is refused.
  - D3: the helper returns player first; a tie runs player then foe with
    no draw (draw values of 1 are scripted, so a source-style draw would
    flip the result); a paralysis-made tie; replacing the helper alone flips
    the order.
  - The overworld stand-in: ids 3, 5, 8, 12, 13 refused; 0, 2, 6, 11 no-op.
  - Tyranitar Sand Stream vs a faster Kyogre Drizzle lead: Drizzle then
    Sand Stream; six turns of "rages" with 25 damage to Kyogre each, none to
    Tyranitar, the counter untouched, 0 draws. Reversed speeds: rain stays
    for six turns.
  - Cloud Nine/Air Lock leads: the setter still announces, the weather has
    no effect, the text continues, sandstorm deals no damage.
  - Voluntary switch: `turnStart, switch, weatherAbility, useMove, miss,
    weatherContinues` (1 draw); the foe's Rain Dance then fails; same family
    silent; Sand Stream overwrites a temporary sun (counter 3, not
    decremented); the foe's Sunny Day then replaces the permanent sandstorm
    (counter 5 → 4); a Cloud Nine incoming emits nothing.
  - Forced replacement: player and foe; the queue mirrors the returned
    events and drains; plain replacement; both sides queued in resolution
    order; `runTurn` clears an unpresented queue; through a real faint (3
    draws).
  - Controller: the three texts; battle start after the default and a
    trainer intro, fastest first, then ACTION; no setter leaves the intro
    unchanged with no draw; an engine past turn 0 is not restarted; an
    Oak-tutorial intro is unchanged; voluntary switch text order; the
    player's forced replacement (callback ignoring the return value) shows
    send-out then Drizzle; the foe's replacement through
    `TrainerBattleOrchestrator` and `onMessagesComplete` shows send-out then
    Sand Stream.
- Regressions: `early_rival_battle_test`, the forced/voluntary/two-sided
  controller tests and the wild controller tests pass unchanged.
- Mutation spot-checks (each restored from a backup copy, `cmp` clean):
  no permanent guard fails 5; any-bit guard fails 3; reversed start order
  fails 6; foe-first tie fails 4; resetting the counter fails 17; no
  voluntary hook fails 7; no forced hook fails 9; no `runTurn` queue clear
  fails 1; no foe-path drain errors; no player-path drain fails 2; drain
  before the send-out fails 1; a space instead of the line break fails 9.
- `bash scripts/test_all.sh` (185 files) and `lua5.1
  scripts/check_repository.lua` pass.

## Deviations

- Battle start is resolved by `BattleSceneController.new`, not by three
  new `main.lua` calls; forced-switch events reach the screen through the
  controller's engine queue, not by changing `main.lua:1621` and
  `TrainerBattleOrchestrator.lua:36`. The order is the one the design
  asks for (after the intro messages; after the send-out text). Reason: the
  task forbids `main.lua` and party code changes, and the controller sits on
  every one of those paths.
- `resolveBattleStart` takes the optional overworld weather id as the
  "no-op input that asserts" (design Known limits, review F7).

## Known limits

- D3 (deferred): the battle-start speed tie goes player first with no draw,
  through `BattleEngine:breakBattleStartSpeedTie`. Source draws
  `Random() & 1` (`src/battle_main.c:2864-2872`) in every tied-lead battle;
  that draw and `gRandomTurnNumber` (`:2926`) belong to the separate
  RNG-parity item, which changes only that helper. An order-sensitive pair
  (two different-family setters at tied speed) is practically unreachable
  in FRLG data.
- Not represented at battle start: badge boost, Macho Brace and Quick Claw
  in the order (as at turn start); Intimidate, Trace, switch-in items;
  Forecast/Castform; Safari's skip of `AbilityBattleEffects`.
- Overworld battle weather is unreachable at the pin; passing one of its
  ids to `resolveBattleStart` is an error.
- A forced replacement's ability runs when the caller resolves the switch,
  after the end of turn, as in source; the R2/D4 limit (no end-of-turn tick
  for the replacement) is unchanged.
- The AI's `RecordAbilityBattle` history for these abilities is not
  represented.
- Texts omit the "Wild"/"Foe" prefix, as every other controller text.
- ROM-backed or replay runs in which a Kyogre, Groudon or trainer Tyranitar
  enters battle now set weather; no current replay contains one.
