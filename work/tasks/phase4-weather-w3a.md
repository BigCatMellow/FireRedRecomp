# Task: weather slice W3a — Swift Swim/Chlorophyll speed, Sand Veil accuracy, Rain Dish

- Task ID: `P4-WEATHER-W3A`
- Status: `DONE — independently reviewed PASS`
- Lane: full relay (weather design proposal, W3a slice)
- Spec: [weather design proposal](../reports/phase4-weather-design-proposal.md)
  ("Abilities (W3a: no new hook)", §3, §6, the RNG table, the W3a slice row,
  the W3a verification plan), with the
  [design review](../reviews/2026-10-14-weather-design-review.md) folded in
  (Sand Veil between Compound Eyes and Hustle; `effectiveSpeed` is called only
  from `getWhoStrikesFirst`).
- Base: `2eaeb4c` on `claude/wizardly-faraday-o45q9z` (W0, W1 and W2 merged).

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

- Swift Swim/Chlorophyll: `GetWhoStrikesFirst` (`src/battle_main.c:3400-3530`).
  Under `WEATHER_HAS_EFFECT`, Swift Swim (33) with `B_WEATHER_RAIN` or
  Chlorophyll (34) with `B_WEATHER_SUN` gives multiplier 2 (`:3409-3426`).
  `speed * mult * ratio[0] / ratio[1]` (`:3428-3430`): the raw stat is
  doubled **before** the stage ratio. Then badge boost and Macho Brace (not
  modeled), paralysis `/= 4`, Quick Claw (not modeled).
  - Every reader of this function picks it up: turn start
    (`bm.c:3613`), `ENDTURN_ORDER` (`src/battle_util.c:484-501`; it runs
    before the weather case, so this turn's new weather counts and a weather
    about to end still counts), battle-start switch-in order (`bm.c:2870`,
    W3b) and the AI's `if_user_goes_first`
    (`src/battle_ai_script_commands.c:1058-1066`; not used by any ported AI
    script).
  - Run odds read the raw `gBattleMons[].speed` (`bm.c:4261-4263`):
    unaffected.
- Sand Veil accuracy: `Cmd_accuracycheck`
  (`src/battle_script_commands.c:1066-1074`): stage ratio, Compound Eyes
  `* 130 / 100`, then `WEATHER_HAS_EFFECT && target ability == SAND_VEIL &&
  B_WEATHER_SANDSTORM` → `* 80 / 100`, then Hustle `* 80 / 100` (physical
  type); each step truncates. Still the single `Random()`.
- Rain Dish: `DoBattlerEndTurnEffects` (`src/battle_util.c:720-743` enum,
  `:744-`): per battler, `ENDTURN_INGRAIN`, `ENDTURN_ABILITIES` (`:774-778`),
  `ENDTURN_ITEMS1`, `ENDTURN_LEECH_SEED`, `ENDTURN_POISON`/`BAD_POISON`/`BURN`,
  …, `ENDTURN_THRASH`, …; all of one battler before the next, and every field
  case (weather texts and sandstorm/hail damage) before any battler case
  (`bm.c:2958-2963`). `AbilityBattleEffects(ABILITYEFFECT_ENDTURN)`
  (`:1817-1831`): `hp != 0`, `WEATHER_HAS_EFFECT && B_WEATHER_RAIN`,
  `maxHP > hp`; `gBattleMoveDamage = maxHP / 16`, 0 → 1, negated (heal).
  `BattleScript_RainDishActivates` (`data/battle_scripts_1.s:3938-3944`):
  `printstring STRINGID_PKMNSXRESTOREDHPALITTLE2`, then
  `healthbarupdate`/`datahpupdate` (which clamps at maxHP). Text
  `"{B_ATK_NAME_WITH_PREFIX}'s {B_ATK_ABILITY}\nrestored its HP a little!"`
  (`src/battle_message.c:283`). No RNG. At full HP nothing happens (no text).
- Cloud Nine/Air Lock: `WEATHER_HAS_EFFECT` (`include/battle_util.h:49-50`),
  HP-gated, re-evaluated at each check.

## Design (as implemented)

- `BattleFormulas.effectiveSpeed(battler, weatherKind)`: raw `speed * 2` for
  (Swift Swim and `"rain"`) or (Chlorophyll and `"sun"`), then
  `applyStatMod`, then paralysis `/ 4`. `getWhoStrikesFirst(..., rng,
  weatherKind)` threads it to both battlers. New constants
  `ABILITY_SWIFT_SWIM = 33`, `ABILITY_CHLOROPHYLL = 34`.
- `runTurn` (turn start) and `endTurnOrder` (W0 `ENDTURN_ORDER`) pass
  `self:activeWeather()`. `endTurnOrder` runs before
  `resolveWeatherEndTurn`, so the weather it reads is the pre-decrement one.
  The run path (`tryRunFromBattle`) still uses the raw stat.
- `BattleFormulas.accuracyCheck(..., defenderSandVeil)`: `calc * 80 / 100`
  between Compound Eyes and Hustle. `accuracyRoll` passes
  `activeWeather() == "sandstorm" and defender.ability == ABILITY_SAND_VEIL`.
  Thunder's rain/sun handling (W2) is unchanged and precedes it.
- Rain Dish: `BattleEngine.ABILITY_RAIN_DISH = 44`. In
  `resolveStatusEndTurn`, per battler in `ENDTURN_ORDER` order, before that
  battler's status damage and rampage tick: if `hp > 0`, ability 44,
  `activeWeather() == "rain"` and `hp < maxHP`, heal `max(1, floor(maxHP/16))`
  clamped to the missing HP and emit `rainDish{side, amount, hpRemaining}`.
  `activeWeather()` is evaluated per battler, so a Cloud Nine holder that
  fainted earlier in the phase no longer suppresses (as in source).
- `BattleSceneController`: `rainDish` → `"X's RAIN DISH\nrestored its HP a
  little!"`, then the HP entry.
- Header notes updated in `BattleEngine.lua` (event list, ability list,
  slice list) and `BattleFormulas.lua` (sections 6, 7c, the not-ported list,
  `accuracyCheck`, `effectiveSpeed`, `getWhoStrikesFirst`).
- `AICheckBadMove.lua`: **no change** (the design requires none; the ported AI
  has no speed comparison, and no W3a ability is read by an AI row).

## MAY CHANGE

- `src/core/BattleEngine.lua`, `src/core/BattleFormulas.lua`,
  `src/core/BattleSceneController.lua`
- `tests/battle_weather_w3a_test.lua` (new)
- `work/reports/phase4-move-effect-inventory.md` (notes only), this task file

## MUST NOT CHANGE

`main.lua`, party/Dex code, coordination and roadmap files,
`AICheckBadMove.lua`, W3b behaviour (switch-in hook, Drizzle/Drought/Sand
Stream, battle-start ordering), Forecast.

## Changed assertions

None. No existing assertion changed; every existing test passes unchanged
(no existing test gives a battler ability 33, 34 or 44, or a Sand Veil
defender with an accuracy roll in a sandstorm). The inventory's rows and
totals are unchanged (abilities change no move-effect row); only the notes
of rows 115, 136, 137 and 164 and the boundary line now point to W3a.

## Acceptance

- `tests/battle_weather_w3a_test.lua`: 141 checks, exact `scriptedRng` draw
  counts in every engine case:
  - `effectiveSpeed`: ×2 only for the matching ability/weather pair;
    truncation witnesses (13 at −1 → 17, not 16; 7 at +1 → 21, not 20);
    paralysis after the doubling (31 → 15, not 14); priority still beats
    doubled speed; a doubled tie draws once; Cloud Nine/Air Lock suppress and
    a 0-HP holder does not.
  - Turn order through `runTurn` for both abilities: doubled holder moves
    and ticks first (2 draws); not doubled in clear or the other three
    weathers; doubling **creates** a tie (turn-start draw and W0 end-of-turn
    draw each decide their own order, 4 draws) and **removes** one (2 draws
    vs 4 in clear); Cloud Nine/Air Lock on the foe (no doubling, ties
    restored); a foe holder; the −1 truncation witness through `runTurn`.
  - W0 reads the weather live: the faster foe's Rain Dance (and the player's
    own Sunny Day) creates an end-of-turn tie that turn start did not have;
    on rain's last turn the end-of-turn order still doubles, then the rain
    stops and the next turn has no draws.
  - Paralysis: a paralyzed doubled 31 ties 15 (turn start, `% 4`, two misses,
    end of turn = 5 draws); 7 vs 15 in clear (3 draws); a mid-turn Thunder
    Wave on a doubled 20 creates an end-of-turn tie (3 draws vs 2 in clear).
  - Run odds ignore Swift Swim (escape roll drawn).
  - Sand Veil: 95 → 76 boundary; Compound Eyes then Sand Veil at 75 → 97 →
    77 (Sand Veil first would give 78); Hustle physical 48, special 60;
    after a +1 stage 79; through the engine both directions, other weathers,
    Cloud Nine/Air Lock, the holder's own accuracy, Thunder 56, Thunder Wave
    80.
  - Rain Dish: 25 at 300/400 after the weather text, full HP (no event),
    clamp, minimum 1, floor at maxHP 47, foe holder, not in sun/sand/hail/
    clear, not when the rain stops this turn, yes when Rain Dance set it this
    turn; Cloud Nine/Air Lock suppress (timer and text continue); a Cloud
    Nine holder that fainted earlier in the phase no longer suppresses, one
    that faints later does; per-battler order (player faster: Rain Dish,
    player poison, foe poison; foe faster: foe poison, Rain Dish, player
    poison); burn at full HP then heal-before-burn; both holders ordered by
    the W0 draw; a foe Swift Swim ordering; a decided battle stops before
    it; a 0-HP holder is skipped; Rain Dish, then poison, then the Thrash
    fatigue confusion on the same end of turn.
  - Controller text and its HP entry, directly and through the engine.
- Mutation spot-checks (each reverted, against this test file): ×2 after the
  stage fails 3; ×2 after paralysis fails 3; end-of-turn order without
  weather fails 21; turn start ignoring Cloud Nine fails 8; no Sand Veil
  fails 9; Sand Veil before Compound Eyes fails 1; Sand Veil ignoring Cloud
  Nine fails 2; Rain Dish ignoring Cloud Nine fails 3; no full-HP check fails
  2; no minimum 1 fails 1; no clamp fails 1; player-first end-of-turn order
  fails 32.
- `bash scripts/test_all.sh` (184 files) and `lua5.1
  scripts/check_repository.lua` pass.

## Deviations

- None from the design.

## Known limits

- Not represented: Quick Claw, Macho Brace and the Badge 3 speed boost in
  `GetWhoStrikesFirst`; Bright Powder/Lax Incense after Sand Veil
  (the hold-effect step after Hustle); the `% 3` Shed Skin and Speed Boost/Truant cases of
  `ENDTURN_ABILITIES` (not admitted abilities in this engine); Forecast.
- R2/D4 (pre-existing): a 0-HP battler awaiting its replacement is skipped
  at end of turn. Where source's slot would already hold a replacement Rain
  Dish holder, the engine gives it no heal, as it gives no weather tick.
- Replays: a Swift Swim/Chlorophyll holder in its weather can add or remove
  the turn-start and the end-of-turn tie draws. Rain Dish and Sand Veil add
  no draws.

## Review (2026-10-15)

[Implementation review](../reviews/2026-10-15-weather-w3a-implementation-review.md):
PASS. Every changed line checked by hand: no leftover mutation from the
implementer's failed restore. 30/30 mutations caught (Thunder's rain sure-hit
by the W2 test). Findings are nits/info only.
