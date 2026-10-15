# Review: Phase 4 weather design proposal (W0-W3)

- Reviewed: `work/reports/phase4-weather-design-proposal.md` at `0e36786`
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
- Reviewer role: independent design review (full relay). Nothing else was edited; nothing committed.
- Source copies: `/tmp/claude-0/bsc.c`, `bs1.s`, `status/{battle_util.c,battle_main.c,pokemon.c}`, plus a sparse checkout of the pin made by `git fetch --depth 1` of the pinned commit (the scripts, `data/maps`, `src/*.c`, `src/data`, `include`). The local `bsc.c`, `bs1.s`, `battle_main.c`, `battle_util.c`, `pokemon.c`, `battle_ai_scripts.s`, `battle_ai_script_commands.c` and `battle_message.c` copies were byte-compared against the pinned raw files and are identical. (`/tmp/claude-0/bm.c` is a different, shorter file. The proposal's `bm.c:` line numbers match the pinned `src/battle_main.c`, which is what I checked.)

Abbreviations follow the proposal: `bsc.c`, `bs1.s`, `bu.c` (battle_util.c), `bm.c` (battle_main.c), `msg.c`, `ai.s`, `aisc.c` (battle_ai_script_commands.c).

## Verdict: **PASS WITH CORRECTIONS**

The source facts are accurate wherever I checked them, and that covers almost all of them. That includes every point in the focus areas: the field-before-battler order, the `ENDTURN_ORDER` recompute and its tie draws, the fail cases, the 5-turn counter with 4 damage ticks, damage placement, Thunder, the Solar Beam sun path, the heals, the immunities, Cloud Nine, the AI's stale result, and overworld weather being unreachable. The engine insertion points are correct, and the slices are well-bounded. None of the findings below is blocking. Two Moderate findings must be folded into the slice task files (W0 and W2) before implementation. The rest are spec clarifications and citation fixes.

## Source checks performed (all confirmed unless a finding says otherwise)

| Area | Checked | Result |
| --- | --- | --- |
| State | `bm.c:199`, `:2251-2255`; `include/constants/battle.h:206-218`; `include/battle.h:263` | Confirmed. One u16, one shared duration byte, both zeroed at battle start |
| Setters | All `gBattleWeather =` writers in `src/*.c`: `bm.c:2251`, `bsc.c:6408/7209/8390/8673`, `bu.c:1717/1726/1735/1751/1760/1769` | Confirmed. Every setter assigns the whole word, so at most one family is set |
| Moves | `bsc.c:6399-6413`, `:7200-7214`, `:8381-8396`, `:8664-8678`; `bs1.s:1585-1590`, `:1740-1758`, `:2128-2133`; `msg.c:912-920` | Confirmed. The fail test is the own-family mask including the permanent bit. PP is spent before it. There is no `accuracycheck` and no RNG. A cross-family overwrite gives 5 turns |
| End of turn order | `bm.c:2953-2965`; `bu.c:451-463`, `:484-501`, `:744-` | Confirmed. All field cases, weather included, finish before any battler case. The order recompute uses `GetWhoStrikesFirst(i, j, FALSE)` |
| Tie draws | `bm.c:3478-3503`, `:3510`, `:3523` | Confirmed. Chosen-move priority counts. A non-move action is `MOVE_NONE`. An exact tie at equal priority draws `Random() & 1` |
| Counter | `bu.c:624-711` | Confirmed. Set to 5 on turn T, then 4,3,2,1 "continues" and "stopped" at the end of T+4. Sand/hail deal **4** damage ticks. The expiry turn deals no damage. Hail always decrements |
| Damage loop | `bs1.s:3158-3187`; `bsc.c:3385-3460` (`checkteamslost`) | Confirmed. The loop runs in `gBattlerByTurnOrder`. A 0 result skips silently. A deciding faint ends the loop |
| `weatherdamage` | `bsc.c:7216-7268` | Confirmed. Rock/Steel/Ground, Sand Veil, `UNDERGROUND`/`UNDERWATER` exempt from sand. Ice and underground/underwater exempt from hail. **On-air is not exempt.** There is no HP test, only the absent test. The Ghost-without-Scope foe is exempt |
| Damage formula | `pokemon.c:2385-2648` | Confirmed. The block is inside the special branch only, after Light Screen and before Flash Fire and `+2`. Rain tests `RAIN_TEMPORARY`. The Solar Beam halving keys on `gCurrentMove == MOVE_SOLAR_BEAM` under rain/sand/hail. Each step truncates. There is no min-1 clamp |
| `damagecalc` | `bsc.c:1209-1220` | Confirmed. The result is `(base+2) * crit * dmgMultiplier`, with `typeOverride = dynamicMoveType` |
| Thunder | `bsc.c:958-1001`, `:1062-1064`; `bs1.s:1916-1919` | Confirmed. In rain it is a sure hit with no draw, after the Dig/Dive miss. In sun `moveAcc = 50` is set before the stage ratio. Sand Veil comes between Compound Eyes and Hustle (`:1069-1074`) |
| Solar Beam | `bs1.s:1899-1914`, `:784-792`; `bsc.c:838-839`, `:1146-1152`, `:2477-2482`, `:3836-3842` | Confirmed. In sun: lock and `ppreduce` happen **before** `attackcanceler`. `MULTIPLETURNS` bypasses the 0-PP check. A charged-then-sun release spends a second PP |
| Cancellers vs lock | `bu.c:1266-1525`; `bs1.s:3695-3742`; `bm.c:2941-2942` | Confirmed. Paralysis, flinch, confusion self-hit, recharge, Disable, Taunt and Imprison cancel. Freeze and sleep do not (sleep is cancelled at end of turn). Freezing a battler cancels its multi-turn move (`bsc.c:2270`) |
| Weather Ball | `bs1.s:2636-2638`; `bsc.c:9345-9364`; `include/battle.h:463-476` | Confirmed. `dmgMultiplier = 2` and the dynamic type are set before the cancellers, only under `WEATHER_HAS_EFFECT`. The type is checked in the order rain, sand, sun, hail |
| Heals | `bsc.c:8478-8501`; `bs1.s:1726-1731`, `:2028-2042` | Confirmed. 1/2 with no weather or no effect, `20*maxHP/30` in sun (= floor(2/3)), 1/4 otherwise, minimum 1, and the full-HP branch |
| Freeze in sun | `bsc.c:2257-2271` | Confirmed. A silent refusal after the chance draw |
| Speed | `bm.c:3409-3430` | Confirmed. ×2 is applied to the raw stat before the stage ratio. Run odds use the raw stat |
| Cloud Nine macros | `include/battle_util.h:49-50`; `bu.c:2325-2362`, `:1678` | Confirmed. The HP-free variant gates only the damage block (and the link transfer in `battle_controllers.c:757`, which does not matter here) |
| Switch-in | `bm.c:2856-2927`; `bu.c:1704-1815` | Confirmed. The order is computed once (`switchInAbilitiesCounter == 0`), with one tie draw. Drizzle converts temporary rain. The permanent-bit guards hold. Cloud Nine/Air Lock only run the Castform check |
| AI | `ai.s:52-104`, `:168/178/179/191`, `:455-529`; `aisc.c:966-1030`, `:1138-1185`, `:1385-1397`; `constants/abilities.h:4-7` | Confirmed. For power-0 moves the last `funcResult` writer before `get_weather` is `CheckSoundproof`'s `get_ability AI_TARGET`. `get_weather` leaves it untouched with no bits set. The resulting pairs are Rain Dance ↔ Stench (1), Sandstorm ↔ Drizzle (2), Hail ↔ Speed Boost (3), Sunny Day ↔ 0 |
| Texts | `msg.c:124-125`, `:156-157`, `:263`, `:283-285`, `:336-352`, `:912-945` | Confirmed |
| Data | `trainer_parties.h` (Tyranitar at `:10734`, `:10779`, `:10824`; move counts 7/2/2/2/4/2/3/4); `wild_encounters.json` (Psyduck 154, Golduck 21); `species_info.h` | Confirmed |
| Inventory counts | `tests/phase4_move_effect_inventory_test.lua:228-241` (285/69, 34 uncovered moves, 26 uncovered effects) | Confirmed. W1 gives 289/65. W2 gives 292/62, 33 moves and 25 effects |

### Focus 8: can weather start a FireRed battle? No.

This search goes further than the proposal's, which left shared scripts and battle setup unscanned:

- All 425 `data/maps/*/map.json` headers use NONE (333), SUNNY (66), FOG_HORIZONTAL (19) or SHADE (7). No map has a `"type": "weather"` coord event (0 hits), so `DoCoordEventWeather` (`src/field_control_avatar.c:1031`) has no FRLG trigger.
- Every `setweather` in `data/`:
  - `data/event_scripts.s:1308` sets `WEATHER_SHADE` (`EventScript_TryDarkenRuins`, Tanoby);
  - `data/maps/NavelRock_Summit/scripts.inc:46` sets weather 0.
  - Nothing in `data/scripts/*` sets weather.
- `TranslateWeatherNum` (`src/field_weather_util.c:68-91`) maps the header values one to one. The `ROUTE119`/`ROUTE123` cycles are unused. `include/constants/weather.h` marks RAIN, SANDSTORM, DROUGHT, DOWNPOUR and THUNDERSTORM as unused.
- `GetCurrentWeather` has only two battle readers, `bu.c:1710` and `bu.c:1744`. `src/battle_setup.c` neither touches `gBattleWeather` nor sets field weather. The only writers of `gBattleWeather` are the ones listed above.
- Conclusion: `ABILITYEFFECT_SWITCH_IN_WEATHER` is unreachable at this pin, short of a hacked save that stores a rain weather id. A battle can still **start** with weather through a lead's Drizzle, Drought or Sand Stream. The trainer Tyranitar entries make Sand Stream reachable, and a traded Kyogre or Groudon makes Drizzle or Drought reachable. W3b covers these. The proposal's Known-limits line "Shared `data/scripts/*` and special-battle setups were not scanned" can be closed with the citations above (F7).

## Findings

### F1. Moderate. W0 has no rule for a 0-HP battler that is waiting for its replacement

**Evidence.**
- Source runs `HandleFaintedMonActions` after every action (`bsc.c:3798-3803` → `bm.c:4433-4440` → `bu.c:1188-1200` → `bs1.s:2824-2884`, `switchineffects`). So at `ENDTURN_ORDER` (`bu.c:484-501`) the fainted slot already holds the **replacement**.
  - `GetWhoStrikesFirst` then compares the replacement's speed.
  - Its chosen move comes from the stale `chosenMovePositions` slot (`bm.c:3480-3485`).
- The engine runs `resolveEndTurn` while the fainted battler is still in the slot. This happens at the early exits `BattleEngine.lua:3348` and `:3354`, and also at the normal exit `:3364` when the second mover's hit causes the faint.
- Recomputing with the fainted battler's speed would draw `Random() & 1` on a tie with a battler the source no longer has. Source draws only on a tie with an unknown replacement.

**Correction.**
- W0 must state the rule for a side at 0 HP. I recommend **no recompute and no draw** when either battler is at 0 HP. Every per-battler phase skips that battler, so the order cannot be observed. Not drawing also matches the source whenever the replacement does not tie.
- File this as a W0 Known limit under R2, and pin it with a test.

### F2. Moderate. A test in the W2 Solar Beam freeze plan is wrong, and the reachable path should be stated

**Evidence.**
- Freezing a battler cancels its multi-turn moves (`bsc.c:2270`, `BattleEngine.lua:1381`). So a Solar Beam that is already charging cannot become "frozen and locked".
- The only reachable path:
  1. The battler is frozen **before** sun is set.
  2. It selects Solar Beam in sun.
  3. The sun path spends PP and sets the lock (`bs1.s:1909-1913`).
  4. `CANCELLER_FROZEN` (`bu.c:1310-1333`) does not cancel the lock.
- From then on the battler is locked every turn (`bm.c:3125-3130`).
  - While sun lasts, each turn spends a PP before the freeze check.
  - After sun ends, the battler takes `SolarBeamDecideTurn` → `MULTIPLETURNS` → `TwoTurnMovesSecondTurn`. Its `attackcanceler` still sees the freeze. No PP is spent, and the move stays locked.
  - The move fires only on the turn the battler **thaws**: the canceller's `Random() % 5 == 0` draw, or being hit by a Fire move.
- The plan's line "it freezes locked: PP is spent again next turn, and it fires once sun ends" is wrong. It does **not** fire when sun ends.

**Correction.** Restate the oracle:

> frozen first, then Solar Beam selected in sun: PP spent and lock kept; next turn locked, PP spent again while sun lasts; after sun ends no further PP, still locked; fires (no PP) on the thaw turn.

Also drop "recharge" from the list of cancellers that clear the sun-path lock (Design W2 step 3). A recharging battler is forced into its recharge slot and cannot select Solar Beam (`BattleEngine.lua:3176-3181`, `bm.c:3125-3130`), so that line is harmless but unreachable.

### F3. Minor. W0 does not enumerate its call sites or say which move each one uses

**Evidence.** `resolveEndTurn` has six callers:
- `BattleEngine.lua:3226` (switch), `:3271` (capture) and `:3301` (failed run);
- `:3348` and `:3354` (the early exits);
- `:3364` (the normal exit).

`playerMove`/`foeMove` are computed only in the move-vs-move path (`:3306-3307`). The three hoisted branches use none today.

**Correction.**
- W0 should change the signature to pass the two chosen move records, or `nil` for switch, capture or run (`MOVE_NONE`, priority 0, `bm.c:3486-3496`), and list all six sites.
- In the hoisted branches, the foe's record must come from `foeAction.moveSlot`, after the locked-slot substitution at `:3176-3181`. The player's battler must be the switched-in one, which `self.player` already is (`:3206`).
- Struggle (`noValidMoves`) counts as priority 0. That matches the existing record.

### F4. Minor. The AI handler arity needs to be stated

**Evidence.** `AICheckBadMove.score` calls `handler(user, target, move, typeChart, sideStatus)`, which is five arguments (`AICheckBadMove.lua:673`). The proposed `weatherMove` reads `weatherKind` as the sixth.

**Correction.** W1 must also forward `weatherKind` in that call, not only add it to `score`'s signature.

**Note.** For any real species, Sunny Day against stale result 0 cannot happen. The only `abilities = {ABILITY_NONE, …}` entry in `species_info.h` is the unused old-Unown placeholder macro (`:29`). The `(target.ability or 0)` fallback can still fire in fixtures that omit `ability`. Tests should set it explicitly, and the quirk comment should say that the Sunny Day case is fixture-only.

### F5. Minor. The R5 reader list is incomplete for future mechanics, but not for the engine today

**Evidence.**
- `GET_MOVE_TYPE` (that is, `dynamicMoveType`) also feeds these readers:
  - `AbilityBattleEffects`'s move type (`bu.c:1693`), which drives Water/Volt Absorb, Flash Fire and Color Change on a Weather Ball;
  - `datahpupdate`'s physical/special damage tracking for Counter and Mirror Coat (`bsc.c:1751-1756`).
- The engine models none of these. A grep finds no Counter/Mirror Coat tracking and no Absorb or Flash Fire abilities, so no current reader is missed.

**Correction.** Add the readers to R5 or Known limits, so the slice that adds those mechanics routes them through the Weather Ball copy.

### F6. Minor. Citation slips

- "Add an early branch beside Refresh (`:1797`)". `:1797` is inside the Confuse branch. Refresh is at `BattleEngine.lua:1854`.
- R2 cites `work/reviews/2026-10-14-conversion-memento-review.md:150`. The file is `2026-10-13-conversion-memento-review.md`, and the note is N1 at `:148`.
- §8 Reachability lists Pelipper. In Gen 3, Pelipper has Keen Eye, so it is not a weather setter (`species_info.h`). The only Drizzle/Drought/Air Lock holders are Kyogre, Groudon and Rayquaza (`:11049`, `:11078`, `:11107`). Drop Pelipper, or keep it with a note that it is irrelevant.
- `BattleSceneController.lua:94-102` should be `:93-97` (the intro defaults). This is trivial.

### F7. Minor. Close the overworld-weather Known limit, and note Trainer Tower data

**Evidence.** See "Focus 8" above. The shared scripts and battle setup are now scanned. Separately, `src/trainer_tower_sets.c` contains Rain Dance (7), Sunny Day (10), Sandstorm (3) and one Tyranitar. These are reachable weather sources outside `trainer_parties.h` if Trainer Tower is ever supported. Trainer Tower is not modeled today.

**Correction.**
- Replace the "not scanned" sentences in §8 and in Known limits with the citations.
- Keep W3b's no-op assertion.
- Mention the Trainer Tower data in §8 for completeness.

### F8. Info. The D1 rationale understates how much the current order already diverges

The current order already diverges in four ways:

1. **Ties.** Every tied, equal-priority turn already lacks the source's second `Random() & 1` at `ENDTURN_ORDER`. Every later draw in a seeded replay is shifted by one, and the end-of-turn order is a fresh coin flip that the engine replaces with the turn-start result.
2. **Speed changes.** Paralysis or a speed-stage change applied mid-turn can reorder the end of turn.
3. **Hoisted turns.** On switch, capture and failed-run turns, the source orders by speed and the foe's chosen priority. The engine always goes player first.
4. **Order-dependent draws.** Two things already depend on the order without weather: which side's lethal poison or burn decides the outcome in a double KO, and the order of the `ENDTURN_THRASH` fatigue-confusion draws (`bu.c:953-973`).

Priority alone never reorders a move-vs-move turn, because the turn-start order already reflects it. The W0 test "a priority move reorders the end of turn" therefore needs a hoisted-turn setup, for example a switch against a Quick Attack foe.

### F9. Info. Pre-existing screen-timer event order (outside weather)

Source decrements Reflect for side 0 and then side 1, and only then Light Screen for side 0 and then side 1 (`bu.c:503-555`). `decaySideTimers` loops per side (`BattleEngine.lua:2743-2761`). When a player screen and a foe screen of different types expire on the same turn, the "wore off" messages come out in a different order. This does not affect weather placement or RNG. Track it separately if wanted.

### F10. Info. W1-to-W2 window

After W1 alone, admitted rows 151, 152 and 203 are wrong in reachable weather. The inventory already flags 151 and 152 as weather-limited, and 203 as blocked-on-state, so this is honest. W2 should still land immediately after W1, as the proposal says.

## Decisions

- **D1. Accept: W0 first, as its own slice.**
  - The missing recompute is a pre-existing RNG and order divergence (F8), and weather damage makes it outcome-deciding.
  - Fold in F1 (the 0-HP rule) and F3 (the call sites and move records).
  - List every changed draw count, including `battle_status_engine_test.lua:193-219`.
  - Replace mutation M28's "player-first hoisted order" premise with source order. The earlier status review's correction "(b) battler order is the turn's action order" (`2026-10-14-status-conditions-design-review.md:86`) is superseded and should be annotated as such.
- **D2. Accept.** The Solar Beam halving is in the same `WEATHER_HAS_EFFECT2` block as the Fire/Water terms (`pokemon.c:2605-2637`). Freeze in sun becomes reachable the moment W1 makes sun reachable (`bsc.c:2257-2265`). Deferring either would open a known divergence for no saving.
- **D3. Accept the deferral.**
  - The battle-start tie draw (`bm.c:2862-2870`) is computed once per battle and shifts the RNG stream of every tied-lead battle, not only weather battles. That belongs to the RNG-parity item together with `gRandomTurnNumber` (`bm.c:2926`, `:2999`).
  - An order-sensitive pair, two different-family weather setters with tied speed, is practically unreachable in FRLG data.
  - Conditions:
    - W3b orders ties player first through one named helper, so the later item flips one place;
    - W3b pins the player-first rule with a test;
    - W3b records it in Known limits.
- **D4. Accept.**
  - `weatherdamage` has no HP test because, in source, a non-absent slot at end of turn always holds a living battler or its replacement (`bsc.c:7264-7265`, plus the R2 flow).
  - Skipping a 0-HP battler matches the engine's `resolveStatusEndTurn` convention (`BattleEngine.lua:3100`) and avoids a duplicate faint.
  - The cost is the replacement's missing weather tick on that turn. W1 should record it as an R2 symptom and pin it with a test.

## Engine fit (focus 9) summary

| Area | Assessment |
| --- | --- |
| Insertion points | Correct: `resolveEndTurn` between `decaySideTimers` and `resolveStatusEndTurn`; the damage block after Light Screen in `calculateBaseDamage`; Weather Ball at the Flail/Eruption copy (`:1624-1637`); the Solar Beam sun path before `resolveStatusCancellers` (`:1655`), using the existing `CHARGE_MOVES` second-turn arm (`:1690-1700`); freeze beside Magma Armor (`:1377`); heals in the RESTORE_HP branch (`:2187-2200`) with accuracy exclusions (`:1958-1972`) |
| Damage call sites | All six named (`:1469`, `:1750`, `:2054`, `:2421`, `:2886`, `:2977`), plus `EarlyRivalAI.lua:25`. Nothing else calls `calculateBaseDamage` |
| Accuracy and speed | `accuracyCheck` is called only from `accuracyRoll`. `effectiveSpeed` is called only from `getWhoStrikesFirst`, which is called only at `:3308` (plus the new W0 and W3b sites) |
| Freeze | Every freeze path goes through `applySecondaryStatus` (`:2611`, `:2627`, `:2951`) |
| Weather Ball copy | Flows correctly to `currentMove` (the defrost at `:1253`), `accuracyRoll` (Hustle), `abilityAdjustedStats` (Thick Fat), the pinch abilities and `typeCalc` |
| Sun path and existing checks | The sun path's pre-set `charging` correctly bypasses the post-canceller locked 0-PP check (`:1660-1666`). The existing selection-time check (`:1648`) cannot be hit because `pp > 0` at selection |
| State | Weather is battle-only. `BattlePartyBridge` persists only PP, HP and status |
| Lane | Full relay is correct under AGENTS.md: weather is cross-turn state, and W3b touches `main.lua` |
| Slices | Well-bounded |

On the slices, W3b is the largest because of caller presentation of `resolveForcedSwitch` events (`main.lua:1620`, `TrainerBattleOrchestrator.lua:36`). It is correctly isolated last.

## Required before slice task files are cut

1. Add the F1 rule and the F3 call-site list to the W0 task.
2. Use the corrected F2 oracle in the W2 task.
3. Note the F4 arity in the W1 task.
4. Fix the F5-F7 text in the proposal or in the task files.
