# Task: weather slice W2 — Thunder, the Solar Beam sun path, Weather Ball, the sunlight heals

- Task ID: `P4-WEATHER-W2`
- Status: `IMPLEMENTED — awaiting independent review`
- Lane: full relay (weather design proposal, W2 slice)
- Spec: [weather design proposal](../reports/phase4-weather-design-proposal.md)
  ("Weather-dependent moves (W2)", §5, §9, §10, the W2 slice row, the W2
  verification plan, R4, R5), with the
  [design review](../reviews/2026-10-14-weather-design-review.md) folded in:
  F2 (the corrected Solar Beam freeze oracle; recharge dropped as a lock
  canceller, being unreachable) and F5 (unmodeled dynamic-type readers).
- Base: `285d8c3` on `claude/wizardly-faraday-o45q9z` (W0 and W1 merged).

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

- Thunder: `data/battle_scripts_1.s:1916-1919` (record
  `src/data/battle_moves.h:1134`, accuracy 70). `AccuracyCalcHelper`
  (`src/battle_script_commands.c:958-1001`): the on-air check is ignored, the
  underground/underwater miss comes first (no RNG), then
  `WEATHER_HAS_EFFECT && rain && EFFECT_THUNDER` is a sure hit with no
  `Random()` (`:993-998`). `Cmd_accuracycheck`: in sun `moveAcc = 50` before
  the stage ratio (`:1062-1064`), then the single draw.
- Solar Beam: `data/battle_scripts_1.s:1899-1914`. Cloud Nine/Air Lock
  (`jumpifabilitypresent`, HP-gated `ABILITYEFFECT_CHECK_ON_FIELD`,
  `src/battle_script_commands.c:3836-3842`) go to the ordinary
  `SolarBeamDecideTurn`; sun goes to `SolarBeamOnFirstTurn`:
  `MOVE_EFFECT_CHARGING` (MULTIPLETURNS and the locked move) and `ppreduce`
  **before** `attackcanceler`, then `BattleScript_TwoTurnMovesSecondTurn`
  (`:784-792`: `attackcanceler`, clear the lock, `NO_PPDEDUCT`, hit).
  `Cmd_ppreduce` deducts only while `pp > 0` (`:1146-1152`); the
  `attackcanceler` 0-PP check is bypassed by MULTIPLETURNS (`:838-839`).
  Paralysis, flinch and the confusion self-hit cancel multi-turn moves
  (`data/battle_scripts_1.s:3717`, `src/battle_util.c:1366`,
  `data/battle_scripts_1.s:3742`); freeze does not (`:3695-3699`); sleep is
  cancelled at end of turn (`src/battle_main.c:2941-2942`). Freezing a
  battler cancels its multi-turn move (`src/battle_script_commands.c:2270`),
  so the only reachable freeze case is frozen-first-then-select (F2).
- Weather Ball: `data/battle_scripts_1.s:2636-2638` (record
  `src/data/battle_moves.h:4046`, Normal 50/100). `Cmd_setweatherballtype`
  (`src/battle_script_commands.c:9345-9364`) runs before `attackcanceler`:
  under `WEATHER_HAS_EFFECT`, any weather bit sets `dmgMultiplier = 2`, and the
  dynamic type is Water/Rock/Fire/Ice (rain, sand, sun, hail order).
  `Cmd_damagecalc` (`:1209-1220`): `CalculateBaseDamage(...) * crit *
  dmgMultiplier`, so ×2 applies to the result **including** `+2`; the rain/sun
  1.5 is inside `CalculateBaseDamage` (`src/pokemon.c:2605-2637`). The AI
  resets the dynamic type (`src/battle_ai_script_commands.c:981-982`,
  `:1205-1206`).
- Morning Sun / Synthesis / Moonlight: `data/battle_scripts_1.s:1726-1733`
  (records `src/data/battle_moves.h:3045`, `:3058`, `:3071`):
  `attackcanceler`, `attackstring`, `ppreduce`, `recoverbasedonsunlight
  BattleScript_AlreadyAtFullHp`, `BattleScript_PresentHealTarget`.
  `Cmd_recoverbasedonsunlight` (`src/battle_script_commands.c:8478-8501`):
  full HP jumps to `BattleScript_AlreadyAtFullHp` (`:2038-2042`,
  `STRINGID_PKMNHPFULL` "X's\nHP is full!", `src/battle_message.c:125`);
  otherwise `maxHP/2` when `gBattleWeather == 0 || !WEATHER_HAS_EFFECT`,
  `20*maxHP/30` in sun, `maxHP/4` otherwise, 0 → 1; "X regained\nhealth!"
  (`:124`). No RNG.
- AI: `AI_CheckBadMove` (`data/battle_ai_scripts.s:160-214`) has no
  `if_effect` for 132-134, 151, 152 or 203, so they fall through to 0 after
  the power gate/type checks. Solar Beam is in
  `sDiscouragedPowerfulMoveEffects` (`src/battle_ai_script_commands.c:253`).

## Design (as implemented)

- Constants `EFFECT_MORNING_SUN/SYNTHESIS/MOONLIGHT` (132-134),
  `SUNLIGHT_HEAL_MOVES`, `EFFECT_SOLAR_BEAM` 151, `EFFECT_THUNDER` 152,
  `EFFECT_WEATHER_BALL` 203, `WEATHER_BALL_TYPES`.
- `supportsMove` admits 132-134 (power 0, `MOVE_TARGET_USER`).
- `accuracyRoll`: after `semiInvulnerableMiss`, Thunder returns true with no
  draw when `activeWeather() == "rain"`; uses accuracy 50 when `"sun"`.
- Weather Ball: at the Flail/Eruption site, when `activeWeather()` is set,
  a local copy of the record gets the dynamic type and `weatherBallDoubled`;
  the first `elseif` arm of the dmgMultiplier chain doubles the damage after
  the crit multiply (equal to source's `base * crit * dmgMultiplier`). The
  copy feeds `currentMove` (defrost), `accuracyRoll` (Hustle),
  `calculateBaseDamage` (split, Thick Fat, pinch abilities, weather term) and
  `typeCalc` (STAB, effectiveness). `self.moves[311]` is never mutated.
- Solar Beam sun path: immediately before `resolveStatusCancellers`, when
  `move.effect == 151 and activeWeather() == "sun"`: spend one PP if
  `pp > 0`, set `charging` and `lockedSlot`. The existing cancellers then keep
  or clear the lock; the existing `CHARGE_MOVES` block takes its second-turn
  arm (lock cleared, `noPPDeduct`). It also runs on a locked turn, giving the
  second PP. No `chargeTurn` event.
- Heals: added to the accuracy exclusions; a branch beside RESTORE_HP in the
  power-0 block: `restoreHPFull` at full HP, else the weather-dependent amount
  (`activeWeather()`), minimum 1, clamped, `restoreHP`.
- No controller change: `useMove`, `restoreHP` and `restoreHPFull` texts
  already exist.
- `AICheckBadMove.lua`: **no change** (all six effects already fall through
  to 0, and the AI reads the static Weather Ball record).

## MAY CHANGE

- `src/core/BattleEngine.lua`, `src/core/BattleFormulas.lua` (header comment)
- `src/core/AICheckBadMove.lua`: only W2 rows/handlers if needed (none were)
- `tests/battle_weather_w2_test.lua` (new),
  `tests/phase4_weather_w2_effect_rom_test.lua` (new),
  `tests/phase4_move_effect_inventory_test.lua` (four rows and totals),
  `tests/battle_weather_test.lua` (one comment)
- `work/reports/phase4-move-effect-inventory.md`, this task file

## MUST NOT CHANGE

`main.lua`, party/Dex code, coordination and roadmap files, any other
`AICheckBadMove.lua` row or text, W3 behaviour (Swift Swim/Chlorophyll, Sand
Veil accuracy, Rain Dish, switch-in weather abilities).

## Changed assertions (intentional, source-cited)

1. `tests/phase4_move_effect_inventory_test.lua` rows 132, 133, 134:
   `{"blocked_on_state", false, 0, …}` → `{"represented", true, 0, …}`;
   row 203: `{"blocked_on_state", true, 1, …}` → `{"represented", true, 1, …}`
   ("ROM fixture pending (phase4_weather_w2_effect_rom_test)"). Reason: the
   heals are now admitted and represented; Weather Ball's weather semantics are
   now represented.
2. Same file, totals: `admitted = 289, rejected = 65` → `292, 62`;
   `admitted_uncovered_positive` 34 → 33; represented `114/255/181/74` →
   `118/259/182/77`; blocked_on_state `83/98/34/64` → `79/94/33/61`. This
   matches the design's expected 292/62 and the 34 → 33 / 26 → 25 change.
   Without a ROM the test checks only the partition; the 292/62 admission was
   cross-checked by running `supportsMove` over all 354 source records parsed
   from the pinned `src/data/battle_moves.h` (292/62 now, 289/65 before).

No other existing assertion changed. Existing tests' draw counts are
unchanged: the only behaviour change visible to them is W1's "Solar Beam
release in sun" case, which now spends a second PP (that test asserts damage
and draws only, both unchanged; its comment was updated).

## Acceptance

- `tests/battle_weather_w2_test.lua`: 204 checks with exact `scriptedRng`
  draw counts:
  - Thunder: rain sure hit with no accuracy draw (a first value of 99 that
    would miss is consumed as the crit roll), paralysis roll still drawn;
    rain vs Dig misses with zero draws; rain vs Fly is a sure hit; sun 50
    boundary (50 hits, 51 misses), 50 through the +1 stage ratio (66/67);
    sandstorm/hail 70; Cloud Nine and Air Lock on either side restore 70 in
    rain and sun; a 0-HP Cloud Nine holder no longer suppresses; W1: rain set
    by a faster foe this turn, and the roll returning after rain stops.
  - Solar Beam: sun fires on turn 1 with one PP and hit draws on that turn; sun
    set earlier in the turn; full paralysis (PP spent, lock cleared; clear
    weather contrast spends none); flinch; confusion self-hit; sleep (PP
    spent, lock cancelled at end of turn) and waking; **F2**: frozen, then
    selected in sun → PP and lock, PP again while sun lasts, no PP and still
    locked after sun ends, fires with no PP on the thaw turn (each turn's draw
    count pinned); thaw while sun lasts; frozen then Sunny Day by the faster
    foe; charged before the sun → second PP; charged at 0 PP → fires, PP 0;
    Cloud Nine/Air Lock force the charge; rain/sand/hail charge.
  - Weather Ball: each weather's damage (22/22/16/28, worked in comments; the
    ×2-before-+2 and missing-rain-boost witnesses differ); Normal 14 in clear
    and under Cloud Nine/Air Lock for all four weathers; record not mutated;
    Rock physical with burn and Reflect, Light Screen ignored; Light Screen
    order for Water; STAB and effectiveness per type; Ghost hit in rain vs no
    effect under Cloud Nine; Thick Fat, Torrent, Hustle accuracy, crit;
    Fire defrost and its Cloud Nine contrast; W1 same-turn Sandstorm and a
    cross-family overwrite.
  - Heals: all three moves in all five states at maxHP 79 (39/52/19/19/19;
    52 is floor not round), clamp, minimum 1, sun at maxHP 2, full HP (PP
    spent, `restoreHPFull`), no accuracy check vs a Fly user, Cloud Nine/Air
    Lock 1/2, W1 same-turn Sunny Day and the sandstorm tick after the heal.
  - AI: all six effects score 0 in every weather and against the stale ability
    ids; Weather Ball is −10 vs Ghost and 0 vs Water Absorb in rain (static
    Normal); Thunder −10 vs Ground; TrainerAI selects Synthesis.
  - Controller texts for the heal, full HP, and Solar Beam in sun (no charge text).
- Mutation spot-checks (each reverted): Thunder rain rolling fails 6; sun at
  70 fails 2; Thunder ignoring Cloud Nine fails 8; no second Solar Beam PP
  fails 5; sun path without PP fails 14; Solar Beam ignoring Cloud Nine fails
  4; Weather Ball without ×2 fails 22; ×2 on power instead fails 22; Weather
  Ball ignoring Cloud Nine fails 10; heals ignoring Cloud Nine fail 8; sun
  heal rounded fails 4; no minimum 1 fails 1; 1/2 in other weather fails 10.
  Against `285d8c3` the new test fails 53 checks and then errors at the first
  heal (unsupported effect).
- `tests/phase4_weather_w2_effect_rom_test.lua`: records 87, 234, 235, 236,
  311 and exact membership of effects 132-134, 152, 203; skips without a ROM.
- `bash scripts/test_all.sh` and `lua5.1 scripts/check_repository.lua` pass.

## Deviations

- None from the design. The dispatch brief said "At full HP: But it failed!";
  the source (`recoverbasedonsunlight BattleScript_AlreadyAtFullHp`,
  `data/battle_scripts_1.s:1732`, `:2038-2042`) and the design both print
  "X's\nHP is full!", so the engine emits `restoreHPFull`.
- The ×2 is applied after the crit ×2 in the engine's dmgMultiplier chain
  rather than in one product; integer multiplication commutes, so the result
  is identical.

## Known limits

- Not represented: Pressure on the sun-path `ppreduce`, Lock-On, Protect,
  Snatch on the heals, AI CheckViability (`AI_CV_HealWeather`,
  `AI_CV_ChargeUpMove`), Forecast.
- Weather Ball inherits the tracked plain-hit gap: source draws
  `seteffectwithchance`'s `Random() % 100` on every plain hit; the engine does
  not (pre-existing, unchanged).
- F5 readers not modeled anywhere: Water/Volt Absorb, Flash Fire and Color
  Change on the dynamic type (`src/battle_util.c:1693`), and Counter/Mirror
  Coat damage tracking (`src/battle_script_commands.c:1751-1756`). The slice
  that adds any of them must read the Weather Ball copy.
- R2: a 0-HP battler awaiting its replacement is still on the field during
  the turn (pre-existing).
- Replays: Thunder in rain draws one fewer value; Solar Beam in sun draws its
  hit values on the selection turn. No existing replay can contain the heals
  (previously rejected).
