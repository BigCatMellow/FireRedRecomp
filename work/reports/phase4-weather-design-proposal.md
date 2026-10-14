# Phase 4 proposal: battle weather (rain, sun, sandstorm, hail)

- Status: `PROPOSAL — awaiting design review`
- Date: 2026-10-14
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
- Builds on: status slices S1-S4 (`resolveStatusEndTurn`, `applySecondaryStatus`),
  the multi-turn slices M1-M3 (`CHARGE_MOVES`, `isLocked`, `cancelMultiTurnMoves`),
  restore-HP (`restoreHP` / `restoreHPFull`) and the screen timers
  (`decaySideTimers`).
- Lane: full relay. Weather adds new battle-wide state, new end-of-turn
  output, new damage terms and RNG-visible accuracy and turn-order changes.

Weather is unmodeled today (`BattleEngine.lua:268-271`,
`BattleFormulas.lua:100`). The [move-effect inventory](phase4-move-effect-inventory.md)
blocks or limits these rows on it:

- `B`: 115 Sandstorm, 136 Rain Dance, 137 Sunny Day, 164 Hail
  (`:221`, `:242`, `:243`, `:270`); 132/133/134 Morning Sun, Synthesis,
  Moonlight (`:238-240`); 203 Weather Ball (`:309`).
- `R` with a weather limit: 151 Solar Beam always charges (`:257`); 152
  Thunder rolls 70 in rain or sun (`:258`).
- The Fire/Water damage terms, Swift Swim, Chlorophyll, Rain Dish, Drizzle,
  Drought, Sand Stream, Sand Veil, Cloud Nine, Air Lock and Forecast, and
  the sandstorm/hail residual.

Source paths below are relative to the pin. `bsc.c` is
`src/battle_script_commands.c`, `bs1.s` is `data/battle_scripts_1.s`,
`bu.c` is `src/battle_util.c`, `bm.c` is `src/battle_main.c`,
`msg.c` is `src/battle_message.c`, `ai.s` is `data/battle_ai_scripts.s`.
Engine paths are `src/core/…` at the current working tree.

## Source facts

### 1. State

- `gBattleWeather` is one `u16` (`bm.c:199`). Its bits are
  (`include/constants/battle.h:206-218`):

  | Bit | Name | Family mask |
  | --- | --- | --- |
  | 0 | `RAIN_TEMPORARY` | `B_WEATHER_RAIN` = bits 0-2 |
  | 1 | `RAIN_DOWNPOUR` (never set in FRLG) | |
  | 2 | `RAIN_PERMANENT` | |
  | 3 | `SANDSTORM_TEMPORARY` | `B_WEATHER_SANDSTORM` = bits 3-4 |
  | 4 | `SANDSTORM_PERMANENT` | |
  | 5 | `SUN_TEMPORARY` | `B_WEATHER_SUN` = bits 5-6 |
  | 6 | `SUN_PERMANENT` | |
  | 7 | `HAIL_TEMPORARY` | `B_WEATHER_HAIL` = bit 7 only |

- The 5-turn counter is a single shared byte,
  `gWishFutureKnock.weatherDuration` (`include/battle.h:263`). It is not
  per family.
- Battle start zeroes both `gBattleWeather` and the whole
  `gWishFutureKnock` struct (`bm.c:2251-2255`). Nothing persists weather
  out of battle.
- Every setter assigns the **whole word**, so at most one family is ever
  active:
  - The moves write `X_TEMPORARY` and set the duration to 5.
  - Drizzle writes `RAIN_PERMANENT | RAIN_TEMPORARY`, Sand Stream writes
    `B_WEATHER_SANDSTORM`, and Drought writes `B_WEATHER_SUN`
    (`bu.c:1748-1774`). The abilities leave the duration alone.
  - There is no permanent hail.
- Permanent weather never decrements (see §3). It ends only when another
  setter overwrites it.

### 2. The four weather moves

- Records (`src/data/battle_moves.h`): Sandstorm 201 (`:2616`), Rain
  Dance 240 (`:3123`), Sunny Day 241 (`:3136`), Hail 258 (`:3357`). All
  are power 0, accuracy 0, `MOVE_TARGET_USER`, priority 0.
- Scripts: `attackcanceler`, `attackstring`, `ppreduce`, then
  `setsandstorm` / `setrain` / `setsunny` / `sethail`, then
  `BattleScript_MoveWeatherChange` (`bs1.s:1585-1590`, `:1740-1758`,
  `:2128-2133`).
  - There is **no `accuracycheck` and no RNG**.
  - `MoveWeatherChange` (`:1745-1751`) runs `attackanimation` (skipped on
    failure, because `MOVE_RESULT_MISSED` is part of
    `MOVE_RESULT_NO_EFFECT`, `bsc.c:1684`, `constants/battle.h:203`),
    `printfromtable gMoveWeatherChangeStringIds`, then
    `call BattleScript_WeatherFormChanges` (Castform) on both outcomes.
- Commands (`bsc.c:6399-6413`, `:7200-7214`, `:8381-8396`, `:8664-8678`):
  - **Fail** if `gBattleWeather & <own family mask>`, permanent bits
    included. The command sets `MOVE_RESULT_MISSED` and
    `B_MSG_WEATHER_FAILED`, and the text is "But it failed!"
    (`msg.c:916`, `:336`). PP is already spent.
  - Otherwise `gBattleWeather = X_TEMPORARY` and `weatherDuration = 5`.
    A different family is **overwritten**, including permanent ability
    weather. Example: Sunny Day under Drizzle succeeds and gives five
    turns of sun.
- Texts (`msg.c:912-920`, `:339-350`):
  - Rain Dance: "It started to rain!"
  - Sandstorm: "A sandstorm brewed!"
  - Sunny Day: "The sunlight got bright!"
  - Hail: "It started to hail!"

### 3. End of turn

**Order.** `BattleTurnPassed` (`bm.c:2953-2965`) runs
`DoFieldEndTurnEffects`, then `DoBattlerEndTurnEffects`, only while
`gBattleOutcome == 0`. It then runs `HandleFaintedMonActions`.

The field cases (`bu.c:451-463`) run in this order:

1. `ENDTURN_ORDER` (see below).
2. Reflect, Light Screen, Mist, Safeguard, Wish.
3. Rain, Sandstorm, Sun, Hail (`:624-711`).

Every field case finishes before any battler case (`bm.c:2958-2963`; `DoBattlerEndTurnEffects` at `bu.c:744`). So
weather text and weather damage for **both** battlers come before either
battler's Rain Dish (`ENDTURN_ABILITIES`, `:774-778`) and before poison
and burn (`:805-`).

**`ENDTURN_ORDER` (`bu.c:484-501`).** The end-of-turn order is
recomputed with `GetWhoStrikesFirst(i, j, FALSE)`:

- `ignoreChosenMoves = FALSE`, so the priorities of this turn's chosen
  moves count (`bm.c:3478-3503`). A non-move action counts as
  `MOVE_NONE`, priority 0.
- Speed is recomputed now. Paralysis, stage changes and Swift
  Swim/Chlorophyll applied *during* the turn all count.
- An exact tie draws `Random() & 1` (`bm.c:3510`, `:3523`).

See Risks R1: the engine does not do this today.

**Rain (`bu.c:624-652`).**

- If the rain is not permanent, it decrements. At 0 it clears the
  temporary/downpour bits and prints "The rain stopped."
- Otherwise it prints "Rain continues to fall." (`msg.c:341-343`,
  `:940-945`). The script is `BattleScript_RainContinuesOrEnds`
  (`bs1.s:3150-3156`).

**Sandstorm (`bu.c:654-673`).**

- If the sandstorm is not permanent and the decrement reaches 0, it
  clears the temporary bit and runs `BattleScript_SandStormHailEnds`:
  "The sandstorm subsided." (`bs1.s:3184-3187`, `msg.c:346`, `:934-938`).
  There is **no damage** on that turn.
- Otherwise it runs `BattleScript_DamagingWeatherContinues`
  (`bs1.s:3158-3182`), which prints "The sandstorm rages." (`msg.c:345`)
  and runs the damage loop.

**Sun (`bu.c:674-691`).** "The sunlight is strong." or, at 0, "The
sunlight faded." (`bs1.s:3189-3198`, `msg.c:348-349`).

**Hail (`bu.c:692-711`).** It decrements **unconditionally**: no
permanent check, because hail cannot be permanent. Texts are "Hail
continues to fall." and "The hail stopped." (`msg.c:351-352`).

**Counting.** A move sets 5 during turn T. Ends of turn T…T+3 print
"continues" (4, 3, 2, 1). The end of T+4 prints "stopped" or "faded".

- Sandstorm and hail therefore deal residual damage on **four**
  ends of turn.
- All weathers affect five turns of moves, counting the rest of turn T.

**Damage loop (`bs1.s:3162-3182`).** Each battler in turn order runs
these steps:

1. `weatherdamage`.
2. If the damage is 0, skip silently. Otherwise print the text.
3. `datahpupdate`, `tryfaintmon BS_ATTACKER`, `checkteamslost`.
4. If `gBattleOutcome != 0`, the loop ends at once, so later battlers
   are not damaged.

A faint that only queues a replacement continues the loop.

The texts are "X is buffeted\nby the sandstorm!" and "X is pelted\nby
HAIL!" (`msg.c:156-157`, `:928-932`).

**`Cmd_weatherdamage` (`bsc.c:7216-7268`).**

- If `WEATHER_HAS_EFFECT` is false, the damage is 0. **The timer and
  the "rages" text are not suppressed**, because `DoFieldEndTurnEffects`
  never checks the ability.
- Sandstorm deals `max(1, maxHP/16)` unless the battler has one of these
  exemptions:
  - its type1 or type2 is Rock, Steel or Ground;
  - its ability is Sand Veil;
  - it is `STATUS3_UNDERGROUND` (Dig) or `STATUS3_UNDERWATER` (Dive).
- Hail deals `max(1, maxHP/16)` unless the battler is Ice-type or is
  underground or underwater. There is no ability immunity in Gen 3.
- **On-air (Fly/Bounce) battlers are not exempt from either.**
- The opponent in a Ghost-without-Scope battle takes 0
  (`:7218-7223`).
- An absent battler takes 0 (`:7264-7265`).
- **There is no HP test.** A 0-HP but not-absent battler would compute
  nonzero damage. In source, that slot already holds the replacement
  (see Risks R2).

**Faint timing.** A battle decided mid-turn sets `gBattleOutcome`
before any end-of-turn work. `Cmd_end` sets `B_ACTION_TRY_FINISH`
(`bsc.c:3797-3802`). `HandleAction_TryFinish` (`bm.c:4433-4440`) then
runs `HandleFaintedMonActions` (`bu.c:1144-1222`), and its
`BattleScript_HandleFaintedMon` performs `checkteamslost`
(`bs1.s:2824-2826`). The engine's "a deciding faint skips end-of-turn"
rule matches this.

### 4. Damage modifiers (`CalculateBaseDamage`, `src/pokemon.c:2385-2648`)

The weather block sits **inside the special-type branch only**
(`:2602-2638`). Its order within that branch:

1. Light Screen halving (`:2592-2598`).
2. The doubles halving (not modeled).
3. Then, only if `WEATHER_HAS_EFFECT2`:
   1. If `B_WEATHER_RAIN_TEMPORARY`: Fire `/2`, Water `*15/10`.
   2. If rain (any bit), sandstorm or hail, and `gCurrentMove ==
      MOVE_SOLAR_BEAM` (the **move id 76**, not the effect): `/2`.
   3. If sun (either bit): Fire `*15/10`, Water `/2`.
4. Flash Fire (`:2641-2643`; not modeled).
5. `return damage + 2` (`:2647`).

Notes:

- Rain tests only the temporary bit. Drizzle also sets the temporary bit
  (`bu.c:1751`), so this is **not** a divergence.
- Each step truncates.
- There is no minimum-1 clamp in the special branch, so a rain-halved
  Fire hit can become 0 and then 2.
- Physical moves never see weather. This includes a Rock-type Weather
  Ball in sandstorm.

`Cmd_damagecalc` (`bsc.c:1209-1220`) then multiplies by `gCritMultiplier`
and `gBattleScripting.dmgMultiplier`. `TypeCalc` reads the dynamic type
for STAB and effectiveness (`bsc.c:1285`).

### 5. Weather-dependent moves

**Thunder (`bs1.s:1916-1919`; record `battle_moves.h:1134`, accuracy 70).**

- `AccuracyCalcHelper` (`bsc.c:958-1001`) checks, in order: Lock-On, the
  on-air check (Thunder ignores it), the underground check, the
  underwater check, then `WEATHER_HAS_EFFECT && rain && EFFECT_THUNDER`.
  The last one is a sure hit **with no `Random()`** (`:993-998`).
- A Dig or Dive target still makes Thunder miss in rain, with no RNG.
- In sun, `moveAcc = 50` replaces 70 before the stage ratio
  (`bsc.c:1062-1064`). The usual single draw follows.

**Solar Beam (`bs1.s:1899-1914`; record `:991`, power 120).**

- `jumpifabilitypresent CLOUD_NINE`, then `AIR_LOCK`, go to
  `SolarBeamDecideTurn`. These use `ABILITYEFFECT_CHECK_ON_FIELD`, which
  is HP-gated (`bsc.c:3836-3842`). Then `jumpifhalfword CMP_COMMON_BITS
  gBattleWeather, B_WEATHER_SUN` goes to `SolarBeamOnFirstTurn`.
- Without sun, `DecideTurn` is the ordinary two-turn shape that M1
  already implements.
- **In sun, `SolarBeamOnFirstTurn` runs before `attackcanceler`:**
  `orword HITMARKER_CHARGING`, `setmoveeffect CHARGING |
  AFFECTS_USER`, `seteffectprimary` (this sets `STATUS2_MULTIPLETURNS`
  and the locked move), and `ppreduce`. Then it goes to
  `BattleScript_TwoTurnMovesSecondTurn` (`bs1.s:784-792`): first
  `attackcanceler` (the move cancellers), then the lock is cleared,
  `NO_PPDEDUCT` is set, and the script continues to
  `BattleScript_HitFromAccCheck`.
- Consequences (Risks R4):
  - PP is spent **before** sleep, freeze, paralysis, confusion and flinch
    can cancel the move.
  - The lock outlives a canceller that does not cancel it. Freeze does
    not (`bs1.s:3695-3699`). Sleep does not either, but
    `HandleEndTurn_ContinueBattle` cancels it at end of turn
    (`bm.c:2941-2942`). Paralysis, flinch and confusion self-hit cancel
    (`bs1.s:3717`, `bu.c:1366`, `bs1.s:3742`).
  - A Solar Beam that charged without sun and is released after Sunny
    Day takes the sun path and **spends a second PP**. `ppreduce`
    deducts while `pp > 0` (`bsc.c:1146-1152`).
- In rain, sand or hail it still charges, and the release turn is halved
  (§4) if that weather is still active then.

**Weather Ball (`bs1.s:2636-2638`; record `:4046`, Normal, 50, accuracy
100).**

- `setweatherballtype` (`bsc.c:9345-9364`) runs before `attackcanceler`.
  Under `WEATHER_HAS_EFFECT` it does two things:
  - If any weather bit is set, `gBattleScripting.dmgMultiplier = 2`.
  - `dynamicMoveType` becomes Water, Rock, Fire, Ice or Normal (tested in
    that order: rain, sand, sun, hail).
- **The doubling is not a power change.** It multiplies
  `CalculateBaseDamage`'s result, including the `+2`, in `Cmd_damagecalc`.
- In rain or sun the 1.5 boost from §4 also applies, giving ×3 overall
  before STAB.
- The dynamic type feeds every `GET_MOVE_TYPE` and `typeOverride` reader:
  - the physical/special split (so Rock is physical);
  - Thick Fat on Fire/Ice;
  - Blaze/Torrent;
  - Hustle accuracy (`bsc.c:1038`);
  - STAB and effectiveness;
  - the move-end Fire defrost (`bsc.c:4080`).
- `dynamicMoveType` is cleared after each action
  (`HandleAction_ActionFinished`, `bm.c:4453-4470`), so nothing leaks to
  the other battler.
- AI damage and effectiveness checks reset it (`battle_ai_script_commands.c
  :981-982`, `:1205-1206`). The AI always sees a Normal 50-power move.

**Morning Sun 234 / Synthesis 235 / Moonlight 236 (`bs1.s:1726-1731`).**

- Script: `attackcanceler`, `attackstring`, `ppreduce`,
  `recoverbasedonsunlight`, then `BattleScript_PresentHealTarget`. No
  RNG. All three are `MOVE_TARGET_USER`, power 0.
- `Cmd_recoverbasedonsunlight` (`bsc.c:8478-8501`):
  - At full HP it goes to `BattleScript_AlreadyAtFullHp`: "X's\nHP is
    full!" (`bs1.s:2038-2042`).
  - With `gBattleWeather == 0` or `!WEATHER_HAS_EFFECT`: `maxHP/2`.
  - In sun: `20 * maxHP / 30`, which is floor(2/3).
  - In any other weather: `maxHP/4`.
  - The minimum is 1 in every case. `datahpupdate` clamps to maxHP, then
    "X regained\nhealth!" (`bs1.s:2028-2036`, `msg.c:124`).

**Freeze in sun.** `SetMoveEffect`'s freeze case (`bsc.c:2257-2271`)
silently refuses under `WEATHER_HAS_EFFECT && sun`. The
`seteffectwithchance` `% 100` draw has already happened. Tri Attack's
`% 3` has too when it picks freeze. This affects every freeze secondary
(effect 5 and Tri Attack).

### 6. Speed and turn order

`GetWhoStrikesFirst` (`bm.c:3400-3530`):

- Under `WEATHER_HAS_EFFECT`, Swift Swim (33) in rain or Chlorophyll (34)
  in sun gives a multiplier of 2 (`:3409-3426`).
- The multiplier is applied to the **raw stat before the stage ratio**:
  `speed * mult * ratio[0] / ratio[1]` (`:3428-3430`). This is not
  `2 × staged speed`, because the result truncates differently.
- Then come the badge boost, Macho Brace, paralysis `/4` and Quick Claw.
- Run odds use the raw stat and are unaffected (`bm.c:4229-4270`).

### 7. Cloud Nine (13) and Air Lock (77)

There are two macros (`include/battle_util.h:49-50`):

| Macro | Implementation | HP test | Used by |
| --- | --- | --- | --- |
| `WEATHER_HAS_EFFECT` | `ABILITYEFFECT_CHECK_ON_FIELD` (`bu.c:2354-2362`) | holder must have `hp != 0` | everything else in this document |
| `WEATHER_HAS_EFFECT2` | `ABILITYEFFECT_FIELD_SPORT` default arm (`bu.c:2325-2352`) | none | the `CalculateBaseDamage` weather block only |

The difference would show only with a 0-HP Cloud Nine holder on the
field during a damage calculation. The engine halts the turn at such a
faint, so this cannot be observed here.

The whole of `AbilityBattleEffects` is skipped in Safari battles
(`bu.c:1678`), where weather would always have effect.

Neither ability prints text on switch-in. Their `ON_SWITCHIN` case only
re-checks Castform (`bu.c:1798-1813`).

### 8. Switch-in weather abilities

`TryDoEventsBeforeFirstTurn` (`bm.c:2856-2927`) runs these steps:

1. Order battlers by speed, `ignoreChosenMoves = TRUE`. A tie draws
   `Random() & 1` (`:2862-2870`).
2. Overworld weather (`:2873-2878`).
3. `ON_SWITCHIN` abilities, fastest first (`:2880-2886`).
4. Intimidate, Trace, items.
5. `gRandomTurnNumber = Random()` (`:2926`).

`ON_SWITCHIN` (`bu.c:1704-1815`):

- Drizzle: if `!(weather & RAIN_PERMANENT)`, set `PERMANENT | TEMPORARY`
  and print "X's DRIZZLE\nmade it rain!" (`bs1.s:3918-3924`,
  `msg.c:263`). It **converts** a temporary rain too.
- Sand Stream: "X's SAND STREAM\nwhipped up a sandstorm!"
  (`bs1.s:3946-3952`, `msg.c:284`).
- Drought: "X's DROUGHT\nintensified the sun's rays!" (`bs1.s:4013-4019`,
  `msg.c:285`).
- If the same family's permanent bit is already set, the ability does
  nothing and prints nothing.
- The same `ON_SWITCHIN` runs from `Cmd_switchineffects`
  (`bsc.c:4961-5010`) for voluntary and forced switch-ins.
- At battle start, the slower setter wins, because it runs last.

**Overworld weather is unreachable in FRLG at this pin.**
`ABILITYEFFECT_SWITCH_IN_WEATHER` acts only for `WEATHER_RAIN`,
`_THUNDERSTORM`, `_DOWNPOUR`, `_SANDSTORM` and `_DROUGHT`
(`bu.c:1709-1746`). All 425 `data/maps/*/map.json` headers use NONE
(333), SUNNY (66), FOG_HORIZONTAL (19) or SHADE (7). The only
`setweather` in the 425 map `scripts.inc` files is `setweather 0`.
Shared `data/scripts/*` files were not scanned (Known limits).

**Reachability.** Cloud Nine holders (Psyduck, Golduck) are common:
Psyduck appears in 154 wild-slot entries and Golduck in 21
(`src/data/wild_encounters.json`). `trainer_parties.h` has three
Tyranitar entries with Sand Stream (`:10734`, `:10779`, `:10824`).
No Castform, Kyogre, Groudon, Rayquaza or Pelipper appears in wild or
trainer data. They can still arrive from a save through a trade.
Trainer custom movesets contain Rain Dance (7), Sunny Day (2),
Sandstorm (2), Hail (2), Solar Beam (4), Thunder (2), Synthesis (3) and
Moonlight (4).

### 9. RNG

| Path | Source draws |
| --- | --- |
| Weather moves, success or failure | none (no `accuracycheck`) |
| Field weather phase, texts and damage | none |
| `ENDTURN_ORDER` | `Random() & 1` on an exact speed tie at equal chosen priority (pre-existing; R1) |
| Thunder in rain | **no accuracy draw**, unless a Dig/Dive target misses first (also no draw) |
| Thunder in sun | one accuracy draw, threshold from 50 |
| Sand Veil | same single draw, threshold ×80/100 |
| Solar Beam in sun | the hit's accuracy, crit and random draws, on the selection turn |
| Weather Ball | the ordinary hit's draws; type and multiplier add none |
| Morning Sun / Synthesis / Moonlight | none |
| Freeze in sun | the `% 100` (and Tri Attack `% 3`) are still drawn; then a silent refusal |
| Swift Swim / Chlorophyll | change whether a tie (and its draw) happens |
| Switch-in order at battle start | `Random() & 1` on a tie (pre-existing; not modeled) |
| Rain Dish, Drizzle, Drought, Sand Stream, Forecast | none |

Wider context: the engine does not model `gRandomTurnNumber = Random()`
at battle start or at every `BattleTurnPassed` (`bm.c:2926`, `:2999`), or
the per-frame `Random()` in `VBlankCB_Battle` (`bm.c:1647-1650`). The
project's RNG parity is per-command draw order, not frame-exact. This
proposal does not change that model. The two tie draws above are flagged
because they are command-level draws.

### 10. AI (`ai.s`, `src/battle_ai_script_commands.c`)

- `AI_CheckBadMove` dispatch (`ai.s:168`, `:178-179`, `:191`):
  - `AI_CBM_Sandstorm` (`:455-458`): `get_weather`, then −8 if
    `AI_WEATHER_SANDSTORM`.
  - `AI_CBM_RainDance` (`:495-498`) and `AI_CBM_SunnyDay` (`:500-503`):
    the same pattern for rain and sun.
  - `AI_CBM_Hail` (`:526-529`): the same pattern for hail.
- **`Cmd_get_weather` leaves `funcResult` unchanged when no bit is set**
  (`battle_ai_script_commands.c:1385-1397`). The constants are SUN 0,
  RAIN 1, SANDSTORM 2, HAIL 3 (`include/constants/battle_ai.h:26-29`).
  - These moves have power 0, so `get_how_powerful_move_is` returns
    `MOVE_POWER_DISCOURAGED` and `AI_CheckBadMove_CheckSoundproof`'s
    `get_ability AI_TARGET` (`ai.s:55-56`, `:91-92`) is the last
    `funcResult` writer before `get_weather`. The `if_move` and
    `if_effect` tests do not write it.
  - So in clear weather the comparison is against the **target's
    (AI-perceived) ability id**. The ids are NONE 0, STENCH 1, DRIZZLE 2
    and SPEED_BOOST 3 (`include/constants/abilities.h:4-7`).
  - Results: Rain Dance gets −8 against a Stench target, Sandstorm
    against a Drizzle target, Hail against a Speed Boost target, and
    Sunny Day against ability 0.
- `get_weather` tests the bits only. It ignores Cloud Nine and Air Lock.
- The weather heals, Solar Beam, Thunder and Weather Ball have no
  `AI_CheckBadMove` entry (fall-through 0).
  - Solar Beam is in `sDiscouragedPowerfulMoveEffects`
    (`battle_ai_script_commands.c:253`), which the port already lists.
  - Weather Ball's Ghost check uses the static Normal type
    (`if_type_effectiveness` resets the dynamic type, `:1205`). In rain
    it is still −10 against a Ghost target.
- These are CheckViability terms, out of scope like the earlier
  proposals:
  - `AI_CV_HealWeather` (`ai.s:1385-1393`);
  - `AI_CV_RainDance` and `AI_CV_SunnyDay` (`:2159-2196`);
  - `AI_CV_Hail` (`:2387-2403`);
  - Solar Beam's `AI_CV_ChargeUpMove` (`:740`);
  - the documented swapped sandstorm/hail check in `AI_CV_SemiInvulnerable`
    (`:2329-2345`).

  `TrainerAI` refuses those flag sets.

### 11. Forecast (Castform), for completeness

`CastformDataTypeChange` (`bu.c:1611-1644`) rewrites `type1`/`type2` to
Normal, Fire, Water or Ice. It runs at these points:

- on switch-in;
- after each weather move or weather ability (`BattleScript_WeatherFormChanges`,
  `bs1.s:3960-3966`);
- on a Cloud Nine or Air Lock switch-in;
- every turn in `HandleFaintedMonActions` case 6 (`bu.c:1206-1214`),
  which is how expiry reverts it.

The text is "X transformed!" (`msg.c:291`). The type is restored on
faint (`bm.c:2515-2516`).

## Engine today (fit points)

- **State.** `BattleEngine.new` (`BattleEngine.lua:1037-1084`) has
  `sideStatus`, but nothing battle-wide besides `turn` and `runTries`.
  `makeBattler` (`:968-1035`) carries `ability`. Battlers are replaced on
  switch.
- **End of turn.** `resolveEndTurn` (`:3072-3085`) runs these steps:
  1. the flinch clear;
  2. the sleeping multi-turn cancel;
  3. `decaySideTimers` (`:2743-2761`);
  4. `resolveStatusEndTurn(events, sides)` (`:3094-3150`), which skips
     0-HP battlers, calls `checkFaint` per tick, and stops once
     `isOver()`.

  `sides` is the turn's action order: `sidesOf(order)` or the fixed
  player-first `HOISTED_ORDER` (`:3067-3070`). Every non-deciding exit of
  `runTurn` (`:3152-3371`) calls it.
- **Damage.** `BattleFormulas.calculateBaseDamage(attacker, defender,
  move, isCrit, defenderScreens)` (`BattleFormulas.lua:274-388`). The
  special branch ends at Light Screen (`:378-383`), then `damage + 2`
  (`:387`). There are six call sites:
  - the ordinary hit (`BattleEngine.lua:2421`);
  - multi-hit (`:2886`);
  - Triple Kick (`:2977`);
  - Explosion (`:1750`);
  - the crash leaf (`:2054`, physical);
  - the confusion self-hit (`:1469`, Pound).

  `EarlyRivalAI.lua:25` calls it too. The dmgMultiplier slot is the
  `elseif` chain at `BattleEngine.lua:2428-2444`.
- **Dynamic move data.** Flail and Eruption build a local copy of the
  record before the cancellers (`:1624-1637`). This is the pattern for
  Weather Ball.
- **Cancellers then charge.** `resolveStatusCancellers` (`:1655`) runs
  before the `CHARGE_MOVES` block (`:1669-1702`). `CHARGE_MOVES[151]` is
  commented "weather unmodeled: always charges" (`:820`).
- **Accuracy.** `accuracyRoll` (`:1550-1554`) runs `semiInvulnerableMiss`,
  then `BattleFormulas.accuracyCheck` (`BattleFormulas.lua:507-525`,
  with Compound Eyes then Hustle; its comment says "Sand Veil needs
  weather").
- **Turn order.** `runTurn` calls `BattleFormulas.getWhoStrikesFirst`
  (`BattleEngine.lua:3308`), which uses `effectiveSpeed`
  (`BattleFormulas.lua:584-590`: stage, then paralysis).
- **Heals.** The RESTORE_HP/Softboiled branch (`BattleEngine.lua:2187-2200`)
  sits inside `move.power == 0`. Accuracy exclusions are at `:1958-1972`.
- **Freeze secondary.** `applySecondaryStatus` (`:1362-1384`); the Magma
  Armor test is at `:1377`.
- **Battle starts** (`main.lua`):
  - The wild start at `:1314` uses a fixed `foeMoveSlot`, the first
    damaging move. A wild foe therefore never picks a status weather move.
  - The Oak/rival tutorial start at `:1389` has `firstBattle = true`; its
    level-5 starters have no weather move or ability.
  - The trainer start at `:1537` uses `TrainerAI` and `hasReplacement`.

  The controller's intro messages are fixed
  (`BattleSceneController.lua:94-102`). **No switch-in ability hook
  exists**: no Intimidate, no Trace, nothing runs on send-out. The
  `resolveForcedSwitch` return value (`BattleEngine.lua:3047-3062`) is
  ignored by both callers (`main.lua:1620`,
  `TrainerBattleOrchestrator.lua:36`).
- **AI.** `AICheckBadMove.lua:577`, `:585`, `:586` and `:597` are
  `alwaysNoPenalty` "weather unmodeled". `score(user, target, move,
  moveId, typeChart, sideStatus)` (`:645`) has no weather input. It is
  called from `TrainerAI.lua:112`.

## Design

### State (W1)

In `BattleEngine.new`:

```lua
-- gBattleWeather reduced to its reachable shape: one family at a time
-- (every setter assigns the whole word), plus the permanent bit.
weather = { kind = nil, permanent = false }, -- "rain"|"sun"|"sandstorm"|"hail"
weatherDuration = 0,                          -- gWishFutureKnock.weatherDuration
```

- Battle-only. It is never persisted and never cleared by a faint or a
  switch. Downpour is not represented (it is unreachable in FRLG).
- Add `BattleEngine.ABILITY_CLOUD_NINE = 13` and `ABILITY_AIR_LOCK = 77`.
- Helpers:
  - `BattleEngine:weatherHasEffect()` is `WEATHER_HAS_EFFECT`: neither
    active battler has `hp > 0` and ability 13 or 77.
  - `BattleEngine:weatherHasEffectIgnoringHP()` is `WEATHER_HAS_EFFECT2`.
  - `BattleEngine:activeWeather()` returns `self.weather.kind` when
    `weatherHasEffect()`, else `nil`. Every gameplay check except the
    damage block reads this.
  - `BattleEngine:damageWeather()` is the same, gated by the HP-free macro.

### Weather moves (W1)

- `BattleEngine.WEATHER_MOVES = { [115]="sandstorm", [136]="rain",
  [137]="sun", [164]="hail" }`.
- `supportsMove` admits them with power 0 and `MOVE_TARGET_USER`.
- Add an early branch beside Refresh (`:1797`), after `useMove`:
  1. Spend one PP. There is no accuracy check and no RNG.
  2. If `self.weather.kind == kind` (permanent included), emit
     `moveFailed`.
  3. Otherwise set `weather = {kind, permanent=false}`,
     `weatherDuration = 5`, and emit `weatherSet{side, kind}`.

### End of turn (W1)

`resolveEndTurn` becomes: the flinch clear, the sleep cancel,
`decaySideTimers`, **`resolveWeatherEndTurn(events, sides)`**, then
`resolveStatusEndTurn` (which already returns once `isOver()`).
Mist, Safeguard and Wish are not represented and sit between the
screens and weather in source.

`resolveWeatherEndTurn`:

1. If there is no weather, return.
2. If `kind ~= "hail"` and `permanent`, it continues.
3. Otherwise decrement `weatherDuration`. At 0, clear the weather, emit
   `weatherEnded{kind}` and return. There is no damage on this turn.
4. Emit `weatherContinues{kind}`.
5. For sandstorm and hail only, for each side in `sides`:
   1. Stop if `isOver()`.
   2. Skip a battler at `hp == 0` (see R2).
   3. Skip everything if `activeWeather()` is nil (Cloud Nine). The text
      above still printed.
   4. Apply the exemptions:
      - sandstorm: types 4 Ground, 5 Rock or 8 Steel in either slot,
        ability 8 Sand Veil, or `semiInvulnerable` "underground" or
        "underwater";
      - hail: type 15 Ice, or underground or underwater.
   5. Otherwise `amount = min(hp, max(1, floor(maxHP/16)))`. Subtract it
      and emit `weatherDamage{side, kind, amount, hpRemaining}`.
   6. At 0 HP call `checkFaint`.

Do not use `applyDamage`, which targets a defender and advances Oak's
tip; this follows the crash precedent.

### Damage block (W1)

- `calculateBaseDamage(..., defenderScreens, weatherKind, moveId)`: two
  new optional trailing arguments.
- After the Light Screen halving and before `return damage + 2`, inside
  the special branch only:

  ```lua
  if weatherKind == "rain" then
    if moveType == FIRE then damage = idiv(damage, 2)
    elseif moveType == WATER then damage = idiv(15 * damage, 10) end
  end
  if (weatherKind == "rain" or weatherKind == "sandstorm" or weatherKind == "hail")
      and moveId == 76 then -- MOVE_SOLAR_BEAM
    damage = idiv(damage, 2)
  end
  if weatherKind == "sun" then
    if moveType == FIRE then damage = idiv(15 * damage, 10)
    elseif moveType == WATER then damage = idiv(damage, 2) end
  end
  ```

- The engine passes `self:damageWeather()` and the move id at the
  ordinary, multi-hit, Triple Kick and Explosion sites. Crash and the
  confusion self-hit are physical, so passing nil is exact.
  `EarlyRivalAI` passes nil, because Oak's battle cannot have weather.
- The Solar Beam halving lands in W1 because it is in the same source
  block. Leaving it to W2 would open a temporary divergence for no
  saving.

### Freeze in sun (W1)

In `applySecondaryStatus`, next to Magma Armor, add
`if kind == "freeze" and self:activeWeather() == "sun" then return false end`.
The refusal is silent and adds no draw. This is in W1 because W1 makes
sun reachable.

### AI (W1)

- `AICheckBadMove.score` gains a trailing `weatherKind`
  (`engine.weather.kind`: bits only, no Cloud Nine gate, as
  `get_weather` does). `TrainerAI.lua:112` passes it.
- Rows 115, 136, 137 and 164 become:

  ```lua
  local AI_WEATHER = { sun = 0, rain = 1, sandstorm = 2, hail = 3 }
  local function weatherMove(own) return function(_, target, _, _, _, weatherKind)
    -- get_weather leaves funcResult stale when no bit is set; the last
    -- writer is CheckSoundproof's get_ability AI_TARGET.
    local result = weatherKind and AI_WEATHER[weatherKind] or (target.ability or 0)
    return result == AI_WEATHER[own] and -8 or 0
  end end
  ```

  `target.ability` follows the module's existing documented "known
  ability" simplification.

### Weather-dependent moves (W2)

- **Thunder.** In `accuracyRoll`, after `semiInvulnerableMiss`:
  - If `move.effect == 152` and `activeWeather() == "rain"`, return
    true with no draw.
  - Otherwise pass `accuracy = 50` when Thunder is used in sun.

  This keeps the Dig/Dive miss first.
- **Solar Beam sun path.**
  1. Before `resolveStatusCancellers` (`:1655`), compute
     `solarSun = move.effect == 151 and activeWeather() == "sun"`.
  2. If `solarSun`: `if slot and slot.pp > 0 then slot.pp = slot.pp - 1
     end`, `attacker.charging = true`, `attacker.lockedSlot = moveSlot`.
  3. The existing cancellers then cancel the lock or keep it, matching
     source:
     - paralysis, flinch, confusion self-hit and recharge clear it;
     - freeze keeps it;
     - sleep keeps it until `resolveEndTurn`'s existing cancel.
  4. Because `charging` is now true, the existing `CHARGE_MOVES` block
     takes its second-turn arm: clear the lock, set `noPPDeduct`, then
     the ordinary hit.
  5. Also take the sun branch when `charging` was already true, which
     gives the second PP. Its locked-turn 0-PP check is bypassed, as
     `MULTIPLETURNS` bypasses it in source (`bsc.c:838-839`).

  No `chargeTurn` event is emitted.
- **Weather Ball.** At the Flail/Eruption site:
  - If `move.effect == 203` and `w = activeWeather()`, copy the record
    and set `type` to Water, Rock, Fire or Ice (for rain, sand, sun or
    hail) plus `weatherBallDoubled = true`.
  - Add the first `elseif` arm in the dmgMultiplier chain (`:2428`):
    `damage = damage * 2`.
  - The copy feeds `currentMove` (defrost), accuracy (Hustle),
    `calculateBaseDamage` and `typeCalc`.
  - `self.moves[311]` is never mutated, so the AI keeps the static Normal
    record.
- **Morning Sun / Synthesis / Moonlight.**
  - Admit effects 132-134 (power 0, USER) and add them to the accuracy
    exclusions (`:1958-1972`).
  - Extend the RESTORE_HP branch. The full-HP case emits `restoreHPFull`.
    Otherwise use `w = activeWeather()`:
    - `requested = floor(maxHP/2)` with no weather or no effect;
    - `floor(20*maxHP/30)` in sun;
    - `floor(maxHP/4)` otherwise;

    then `max(1, …)`, clamp, and emit `restoreHP`.

### Abilities (W3a: no new hook)

- **Swift Swim / Chlorophyll.**
  `BattleFormulas.effectiveSpeed(battler, weatherKind)` multiplies the
  raw `battler.speed` by 2 before `applyStatMod` when (33 and rain) or
  (34 and sun). `getWhoStrikesFirst(..., rng, weatherKind)` threads it
  through. `runTurn` passes `activeWeather()`, and so does the W0
  end-of-turn order.
- **Sand Veil accuracy.** `accuracyCheck(..., defenderSandVeil)` applies
  `calc * 80 / 100` between Compound Eyes and Hustle. The flag is
  `defender.ability == 8 and activeWeather() == "sandstorm"`.
- **Rain Dish.** In `resolveStatusEndTurn`, per battler and before its
  status damage (`ENDTURN_ABILITIES` precedes `ENDTURN_POISON`):
  - Condition: `hp > 0`, ability 44, `activeWeather() == "rain"` and
    `hp < maxHP`.
  - Effect: heal `max(1, floor(maxHP/16))`, clamped, and emit
    `rainDish{side, amount, hpRemaining}`.

### Abilities (W3b: switch-in hook)

- New `BattleEngine:resolveSwitchInAbility(side, events)` for Drizzle,
  Sand Stream and Drought, with the permanent-bit guards from §8.
  - It emits `weatherAbility{side, ability, kind}`.
  - It sets `{kind, permanent = true}` and leaves `weatherDuration`
    alone.
  - Cloud Nine and Air Lock emit nothing.
- New `BattleEngine:resolveBattleStart()` returns events. It orders the
  two battlers by `getWhoStrikesFirst(player, foe, nil, nil, rng)`, so a
  tie draws, and calls the hook fastest first. Decision D3 covers whether
  that draw is taken.
- Call sites:
  - `runTurn`'s switch branch, after the `switch` event and before the
    foe's move (`BattleScript_ActionSwitch` reaches `switchineffects`
    first);
  - `resolveForcedSwitch`, appended to its returned events;
  - the three `main.lua` starts, after the intro messages.

  Callers must start presenting `resolveForcedSwitch`'s events.

### Deferred (W4 or later)

- Forecast/Castform. It needs a type mutation with restore points and
  form-change presentation, and it has five trigger points. No Castform
  appears in wild or trainer data.

### Events and controller texts

| Event | Text | Source |
| --- | --- | --- |
| `weatherSet{side, kind}` | "It started to rain!" / "A sandstorm brewed!" / "The sunlight got bright!" / "It started to hail!" | `msg.c:339`, `:344`, `:347`, `:350` |
| `moveFailed` (reused) | "But it failed!" | `msg.c:336`, `:916` |
| `weatherContinues{kind}` | "Rain continues to fall." / "The sandstorm rages." / "The sunlight is strong." / "Hail continues to fall." | `msg.c:341`, `:345`, `:348`, `:351` |
| `weatherEnded{kind}` | "The rain stopped." / "The sandstorm subsided." / "The sunlight faded." / "The hail stopped." | `msg.c:343`, `:346`, `:349`, `:352` |
| `weatherDamage{side, kind, amount, hpRemaining}` | "X is buffeted\nby the sandstorm!" / "X is pelted\nby HAIL!", then the HP entry | `msg.c:156-157`; text before `datahpupdate` (`bs1.s:3167-3173`) |
| `restoreHP` / `restoreHPFull` (reused) | "X regained\nhealth!" / "X's\nHP is full!" | `msg.c:124-125` |
| `rainDish{side, amount, hpRemaining}` (W3a) | "X's RAIN DISH\nrestored its HP a little!", then the HP entry | `msg.c:283`, `bs1.s:3938-3944` |
| `weatherAbility{side, ability, kind}` (W3b) | "X's DRIZZLE\nmade it rain!" / "X's SAND STREAM\nwhipped up a sandstorm!" / "X's DROUGHT\nintensified the sun's rays!" | `msg.c:263`, `:284-285` |

Also update the header event list (`BattleEngine.lua:21-92`) and the
"no … weather" header notes (`:268-271`, `BattleFormulas.lua:90`, `:100`,
`:223`, `:504`).

## Slices

| Slice | Content | Unlocks |
| --- | --- | --- |
| W0 (decision D1) | Recompute the end-of-turn order with `getWhoStrikesFirst(player, foe, chosenMoveOrNil, chosenMoveOrNil, rng)` at the start of `resolveEndTurn`, including the tie draw; replace `HOISTED_ORDER` and `sidesOf` for end of turn | Source end-of-turn order for status and, later, weather |
| W1 | State and helpers (including Cloud Nine/Air Lock); the four weather moves; `resolveWeatherEndTurn` (texts, timer, sandstorm/hail damage with type, Sand Veil and Dig/Dive exemptions); the rain/sun Fire/Water terms and Solar Beam halving; freeze-in-sun; AI rows 115/136/137/164 with the stale-result rule; texts; inventory rows 115/136/137/164 → R | 4 moves admitted (expected 289/65) |
| W2 | Thunder rain (no draw) and sun (50); the Solar Beam sun path (PP and lock before the cancellers); Weather Ball type and ×2; Morning Sun/Synthesis/Moonlight; inventory rows 132-134 and 203 → R, and the 151/152 limit notes updated | 3 moves admitted (expected 292/62); 203 leaves the "admitted, semantically uncovered" list (26 → 25 effects, 34 → 33 records) |
| W3a | Swift Swim/Chlorophyll speed; Sand Veil accuracy; Rain Dish | Ability coverage only |
| W3b | Switch-in hook, battle-start ordering, Drizzle/Sand Stream/Drought, caller presentation of switch-in events | Permanent weather |

- W2 should follow W1 closely. After W1 alone, Thunder in rain still
  rolls, Solar Beam in sun still charges, Weather Ball stays Normal ×1,
  and the heals are still rejected.
- W1's comment touch list:
  - `CHARGE_MOVES[151]` (`:820`), whose sun path lands in W2;
  - `HITS_AIR[152]` (`:812`), a context-only comment;
  - `AICheckBadMove.lua:84-90` (the no-op class list) and its four rows;
  - `BattleFormulas.lua:100` (the weather gap list).
- The inventory test (`tests/phase4_move_effect_inventory_test.lua`) is
  authoritative for the counts above.

## Verification plan

- **W0.**
  - A tie turn draws once more at end of turn.
  - A switch turn against a faster foe orders foe-first.
  - A priority move reorders the end of turn.
  - A paralysis applied mid-turn reorders the end of turn.
  - Existing `battle_status_engine_test.lua:193-219` draw counts change
    on purpose, and the slice must list each change.
- **W1 matrix.**
  - Each move succeeds; each fails in its own family (temporary, and
    permanent once W3b lands).
  - Cross-family overwrite resets the duration to 5.
  - Count the texts across turns T…T+4: 4 × "continues" then "stopped",
    and 4 damage ticks for sandstorm and hail.
  - Exemptions: each type, Sand Veil, Dig/Dive; Fly is **not** exempt.
  - The minimum 1 at maxHP < 16.
  - Cloud Nine on either side: texts and timer continue, no damage, and
    no modifiers. A fainted holder no longer suppresses the
    `activeWeather` checks.
  - A deciding faint in the loop stops before the second battler. A
    replacement-pending faint continues.
  - Weather damage precedes poison and burn for both battlers.
  - Rain/sun Fire/Water values at the exact truncation points, including
    a rain-halved special hit reaching 0 → 2. Physical moves are
    unaffected.
  - Solar Beam halving on the release turn in rain, sand and hail.
  - An Ice Beam freeze roll passes in sun and freezes nothing, with the
    draw count unchanged.
  - AI −8 with the matching weather, and with the stale ability in clear
    weather.
- **W2.**
  - Thunder in rain draws zero for accuracy; against Dig it still misses
    with zero draws. Thunder in sun gives a threshold of 50.
  - Solar Beam in sun:
    - it hits on turn 1;
    - PP is spent before a full paralysis (lock cleared);
    - it freezes locked: PP is spent again next turn, and it fires once
      sun ends;
    - sleep is cancelled at end of turn;
    - charged-then-sun spends two PP;
    - Cloud Nine forces the charge.
  - Weather Ball in each weather:
    - type, STAB and effectiveness;
    - Rock is physical, with burn and Reflect;
    - the ×2 applies after `+2`;
    - Fire in sun thaws a frozen target;
    - Normal under Cloud Nine;
    - the AI sees Normal.
  - Heals in each weather at odd maxHP (2/3 floor), at full HP, and the
    minimum 1.
- **W3a.** The multiplier applies before the stage (a truncation
  witness), can create or remove a tie draw, and has no effect under
  Cloud Nine. Sand Veil's threshold and its order against Compound Eyes
  and Hustle. Rain Dish text, clamp and order before poison.
- **W3b.**
  - Battle-start order (the slower setter wins).
  - Drizzle converts a temporary rain, and is a no-op on permanent rain.
  - A voluntary switch-in triggers before the foe moves.
  - A forced switch-in triggers, and the callers render it.
- **All slices.** Controller text order through the real engine, ROM
  record fixtures for moves 76, 87, 201, 234-236, 240, 241, 258 and 311,
  the no-ROM suite, the repository checker, and an independent review.

## Decisions for review

- **D1 (W0).** Should end-of-turn order be fixed before W1?
  - Recommendation: yes, as its own slice.
  - The earlier status design and review accepted "the turn's action
    order" (`work/reviews/2026-10-14-status-conditions-design-review.md:86`),
    and mutation M28 locks in a player-first hoisted order
    (`work/reviews/2026-10-14-status-s1-review.md:245`). Source
    recomputes at `bu.c:484-501` instead.
  - With weather damage the order decides a double-KO: the first battler
    to faint can end the battle before the other is hit.
  - If D1 is declined, W1 uses `sides` unchanged, and R1 becomes a Known
    limit.
- **D2.** The Solar Beam halving and freeze-in-sun belong in W1 (see
  Design). Confirm.
- **D3 (W3b).** Should `resolveBattleStart` take the battle-start tie
  draw (`bm.c:2862-2870`)?
  - It applies to **every** battle with tied speeds, not only to weather
    abilities.
  - Recommendation: record it as a pre-existing, untracked gap, and
    decide it with `gRandomTurnNumber` in a separate RNG-parity item. W3b
    then orders ties player-first and states this.
- **D4.** The engine skips 0-HP battlers in the weather loop (R2).
  Confirm this as the engine's stand-in for "the slot holds the
  replacement".

## RNG notes

- **W1** adds no draws. It changes damage values (Fire/Water, Solar
  Beam) and HP totals, and therefore later KO timing. Replays that
  contain the four moves diverge from their first use. Today no replay
  can contain them, because they are rejected.
- **W0** adds one `Random() & 1` per tied end of turn.
- **W2** removes one accuracy draw per Thunder in rain. It moves Solar
  Beam's hit draws from the release turn to the selection turn in sun.
  Weather Ball and the heals add none.
- **W3a** can add or remove the turn-start tie draw, and with W0 the
  end-of-turn one.
- **W3b** adds none unless D3 is accepted.
- Pre-existing and unchanged:
  - the plain-hit `seteffectwithchance` `% 100` gap, which now also
    covers Weather Ball;
  - the battle-start tie draw;
  - `gRandomTurnNumber`;
  - the AI's `Random() % 2` ability guess
    (`battle_ai_script_commands.c:1171-1175`; the port reads the true
    ability).

## Risks

- **R1. End-of-turn order (pre-existing).** See D1. Two cases already
  diverge without weather: a tied end of turn (a missing draw), and a
  switch, item or run turn against a faster or priority foe (wrong
  order). Weather makes the order decide outcomes.
- **R2. Mid-turn replacement timing (pre-existing).**
  - Source runs `HandleFaintedMonActions` after **each** action
    (`bsc.c:3797-3802`, `bm.c:4433-4440`). A non-deciding mid-turn faint
    is therefore replaced before end of turn, and the replacement takes
    the sandstorm or hail and any Drizzle switch-in at that point.
  - The engine keeps the fainted battler until after the turn. W1 skips
    it, so the replacement's weather damage is missing on that turn.
  - This is the tracked follow-up in
    `work/reviews/2026-10-14-conversion-memento-review.md:150`. Weather
    adds another visible symptom of it and does not fix it.
- **R3. The two Cloud Nine macros.** Damage uses the HP-free variant and
  everything else the HP-gated one. The engine cannot currently be in
  the state that distinguishes them. A test should still pin each call
  site to the right helper, so that a future mid-turn-replacement change
  does not silently swap them.
- **R4. The Solar Beam sun path reorders PP and lock before the
  cancellers.** It interacts with M1-M3's `lockedThisTurn`, the locked
  0-PP check and the sleep end-of-turn cancel. Frozen-in-sun leaves
  Solar Beam locked and burning PP every turn until it thaws or the sun
  ends. That is source behaviour, but it looks like a bug and must be
  tested explicitly.
- **R5. Weather Ball's dynamic copy.** Every reader must take the copy,
  not `self.moves[moveId]`: accuracy, damage, typecalc and the defrost
  check through `currentMove`. A missed reader would give a Normal
  Weather Ball in one step only.
- **R6. AI stale result.** It reproduces a source quirk exactly, which
  reviewers may read as a bug. It depends on the port's true-ability
  simplification. In source, a dual-ability target's guess is random.
- **R7. Admission.** W1 and W2 let trainer AI and the player select seven
  new moves. Wild foes still use their first damaging move
  (`main.lua:1300-1306`). That can be Weather Ball, Solar Beam or Thunder.

## Known limits

- Forecast/Castform (deferred), Downpour (unused), and Ghost-without-Scope
  weather immunity (no Ghost battle type is modeled).
- Safari's always-effective weather, doubles, Pressure on the Solar Beam
  sun `ppreduce`, Flash Fire, Water/Mud Sport, and Wonder Guard's
  `AttacksThisTurn` sun test (`bsc.c:7846-7851`, which has no Cloud Nine
  gate) are not represented.
- The AI CheckViability and HP-aware weather terms are out of the
  `TrainerAI` scope. The AI's `RecordAbilityBattle` history for weather
  abilities is not represented.
- Overworld battle weather: no map header or map script reaches it at
  this pin. Shared `data/scripts/*` and special-battle setups were not
  scanned. W3b should add a no-op input that asserts this.
- Mid-turn replacement (R2), and the battle-start and `gRandomTurnNumber`
  draws (D3) are pre-existing.
