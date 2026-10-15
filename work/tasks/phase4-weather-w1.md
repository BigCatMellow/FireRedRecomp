# Task: weather slice W1 — weather state, the four weather moves, end-of-turn weather, damage terms

- Task ID: `P4-WEATHER-W1`
- Status: `DONE — independently reviewed PASS`
- Lane: full relay (new cross-turn battle state)
- Spec: [weather design proposal](../reports/phase4-weather-design-proposal.md)
  ("State (W1)", "Weather moves (W1)", "End of turn (W1)", "Damage block
  (W1)", "Freeze in sun (W1)", "AI (W1)", "Events and controller texts",
  the W1 slice row and the W1 verification matrix), with the
  [design review](../reviews/2026-10-14-weather-design-review.md)
  (PASS WITH CORRECTIONS) folded in: F4 (AI handler arity), D2 (Solar Beam
  halving and freeze-in-sun in W1), D4 (0-HP battlers skipped).
- Base: `b3dd0ba` on `claude/wizardly-faraday-o45q9z` (W0 merged).

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

- State: `gBattleWeather` one `u16` (`src/battle_main.c:199`), bits and
  family masks `include/constants/battle.h:206-218`; one shared
  `gWishFutureKnock.weatherDuration` (`include/battle.h:263`); both zeroed at
  battle start (`src/battle_main.c:2251-2255`). Every setter assigns the whole
  word.
- Moves: `data/battle_scripts_1.s:1585-1590` (Sandstorm), `:1740-1758`
  (Rain Dance, `BattleScript_MoveWeatherChange`, Sunny Day), `:2128-2133`
  (Hail): `attackcanceler`, `attackstring`, `ppreduce`, set command; no
  `accuracycheck`, no RNG. Commands `src/battle_script_commands.c:6399-6413`,
  `:7200-7214`, `:8381-8396`, `:8664-8678`: fail ("But it failed!",
  `B_MSG_WEATHER_FAILED`) on the own family mask including the permanent bit;
  otherwise `gBattleWeather = X_TEMPORARY`, duration 5. Records
  `src/data/battle_moves.h:2616`, `:3123`, `:3136`, `:3357`.
- End of turn: field cases `src/battle_util.c:451-463` (ENDTURN_ORDER,
  screens, Mist/Safeguard/Wish, then rain/sand/sun/hail) all precede the
  battler cases (`src/battle_main.c:2958-2963`). `ENDTURN_RAIN/SANDSTORM/SUN/
  HAIL` `src/battle_util.c:624-711`: non-permanent decrements, 0 clears and
  prints the end text; hail decrements unconditionally. Scripts
  `data/battle_scripts_1.s:3150-3198`: `BattleScript_DamagingWeatherLoop` in
  `gBattlerByTurnOrder`, 0 damage skips silently, text then `datahpupdate`,
  `tryfaintmon`, `checkteamslost`, a decided battle ends the loop.
  `Cmd_weatherdamage` `src/battle_script_commands.c:7216-7268`: no effect
  under Cloud Nine/Air Lock; sand exempts Rock/Steel/Ground (either type),
  Sand Veil, UNDERGROUND, UNDERWATER; hail exempts Ice, UNDERGROUND,
  UNDERWATER; ON_AIR is not exempt; `max(1, maxHP/16)`.
- Damage: `src/pokemon.c:2605-2637`, special branch only, after Light Screen,
  before Flash Fire and `+2`: rain (temporary bit) Fire `/2`, Water
  `*15/10`; rain/sand/hail and `gCurrentMove == MOVE_SOLAR_BEAM` `/2`; sun
  Fire `*15/10`, Water `/2`; each step truncates; no minimum-1 clamp.
- Freeze in sun: `src/battle_script_commands.c:2257-2265`, silent, after
  the chance draw.
- Cloud Nine (13) / Air Lock (77): `include/battle_util.h:49-50`;
  `WEATHER_HAS_EFFECT` HP-gated (`src/battle_util.c:2354-2362`),
  `WEATHER_HAS_EFFECT2` no HP test (`:2325-2352`), used only by the damage
  block.
- AI: `data/battle_ai_scripts.s:455-458`, `:495-503`, `:526-529`;
  `Cmd_get_weather` (`src/battle_ai_script_commands.c:1385-1397`) leaves
  `funcResult` stale with no weather bit; the last writer for these power-0
  moves is `AI_CheckBadMove_CheckSoundproof`'s `get_ability AI_TARGET`
  (`data/battle_ai_scripts.s:91-92`). `AI_WEATHER_*` SUN 0, RAIN 1,
  SANDSTORM 2, HAIL 3 (`include/constants/battle_ai.h:26-29`).
- Texts: `src/battle_message.c:156-157`, `:336`, `:339-352`, `:912-945`.

## Design (as implemented)

- `BattleEngine.new`: `weather = {kind = nil, permanent = false}`,
  `weatherDuration = 0`. Constants `WEATHER_MOVES = {[115]="sandstorm",
  [136]="rain", [137]="sun", [164]="hail"}`, `ABILITY_SAND_VEIL = 8`,
  `ABILITY_CLOUD_NINE = 13`, `ABILITY_AIR_LOCK = 77`, `MOVE_SOLAR_BEAM = 76`,
  `WEATHER_DURATION = 5`, `TYPE_GROUND/ROCK/STEEL/ICE`.
- Helpers: `weatherHasEffect()` (HP-gated), `weatherHasEffectIgnoringHP()`,
  `activeWeather()` (every gameplay check), `damageWeather()` (damage block
  only).
- `supportsMove` admits the four effects with power 0 and
  `MOVE_TARGET_USER`.
- `resolveMoveCore`: an early branch beside Refresh, after the cancellers and
  `useMove`: spend one PP; `moveFailed` when `weather.kind` is the move's own
  family (permanent included); otherwise `weather = {kind, permanent=false}`,
  `weatherDuration = 5`, `weatherSet{side, kind}`.
- `resolveEndTurn`: flinch clear, sleep cancel, `endTurnOrder` (W0),
  `decaySideTimers`, **`resolveWeatherEndTurn(events, sides)`**,
  `resolveStatusEndTurn`. `resolveWeatherEndTurn` follows the design's steps
  1-6: decrement unless permanent (hail always), `weatherEnded` at 0 with no
  damage, else `weatherContinues`; sandstorm/hail loop over `sides`, stop on
  `isOver()`, skip 0-HP battlers (D4), skip when `activeWeather()` is nil,
  apply the exemptions, `weatherDamage{side, kind, amount, hpRemaining}`,
  `checkFaint` at 0 HP. `applyDamage` is not used.
- `BattleFormulas.calculateBaseDamage(..., defenderScreens, weatherKind,
  moveId)`: the source block after Light Screen in the special branch. The
  engine passes `self:damageWeather()` and the move id at the ordinary hit,
  multi-hit, Triple Kick and Explosion sites (`resolveMultiHit` and
  `resolveTripleKick` gain a trailing `moveId` argument). Crash and the
  confusion self-hit stay physical/nil; `EarlyRivalAI` passes nothing.
- `applySecondaryStatus`: `freeze` refused silently when
  `activeWeather() == "sun"` (next to Magma Armor).
- AI: `AICheckBadMove.score(..., sideStatus, weatherKind)` forwards
  `weatherKind` to the handler as its sixth argument (F4). Rows 115/136/137/
  164 use `weatherMove(own)`: `-8` when `weatherKind` (or, with no weather,
  the stale `target.ability or 0`) equals the move's `AI_WEATHER_*` id.
  `TrainerAI` passes `engine.weather.kind` (bits only, no Cloud Nine gate).
- Controller: `weatherSet`, `weatherContinues`, `weatherEnded` texts and
  `weatherDamage` text followed by the HP entry.

## MAY CHANGE

- `src/core/BattleEngine.lua`, `src/core/BattleFormulas.lua`,
  `src/core/BattleSceneController.lua`, `src/core/TrainerAI.lua` (the one
  `score` call)
- `src/core/AICheckBadMove.lua`: **only** the four weather rows, their
  handler and the `weatherKind` plumbing (`score` signature, the handler
  call). The file is shared with the Memento inspection owner.
- `tests/battle_weather_test.lua` (new), `tests/phase4_weather_effect_rom_test.lua`
  (new), `tests/phase4_move_effect_inventory_test.lua` (four rows and counts)
- `work/reports/phase4-move-effect-inventory.md`, this task file

## MUST NOT CHANGE

`main.lua`, the party/Dex code, coordination and roadmap files, any other
`AICheckBadMove.lua` row or text, and W2/W3 behaviour (Thunder, the Solar
Beam sun path, Weather Ball, the sunlight heals, Swift Swim/Chlorophyll,
Sand Veil accuracy, Rain Dish, switch-in weather abilities).

## Changed assertions (intentional, source-cited)

1. `tests/phase4_move_effect_inventory_test.lua` rows 115, 136, 137, 164:
   `{"blocked_on_state", false, 0, …}` → `{"represented", true, 0, …}` with
   "ROM fixture pending (phase4_weather_effect_rom_test)". Reason: the four
   effects are now admitted and represented by this slice.
2. Same file, totals: `admitted = 285, rejected = 69` → `289, 65`;
   represented `110/251/181/70` → `114/255/181/74`; blocked_on_state
   `87/102/34/68` → `83/98/34/64`. `admitted_uncovered_positive` stays 34 (the
   four moves have power 0). This matches the design's expected 289/65.

No other existing assertion changed. W1 adds no RNG draw anywhere, so no
draw count in the existing suite moved.

## Acceptance

- `tests/battle_weather_test.lua`: 220 checks, all with exact `scriptedRng`
  draw counts where draws matter:
  - each move succeeds (after `useMove`, one PP, duration 5, no draw), fails
    in its own temporary and permanent family (PP spent, timer kept, no
    draw); cross-family overwrite resets to 5 and overwrites a permanent
    family; two setters in one turn (second wins, zero draws);
  - counter: `CCCCE-` over six turns for all four kinds, exactly 4 damage
    ticks for sandstorm and hail (40 HP at maxHP 160); the last turn deals no
    damage; permanent rain/sun/sand never decrement, hail always does;
  - amounts: `max(1, maxHP/16)` at 15 and 33, clamp to remaining HP and
    faint;
  - exemptions: Rock/Steel/Ground in either slot and Sand Veil (sand only),
    Ice in either slot (hail only), Dig/Dive exempt and Fly/Bounce not exempt
    in both weathers through the real charge turn (zero draws);
  - order: weather text, both weather ticks, then both poison ticks; faster
    foe first; a tie's end-of-turn draw (0/1) orders the loop with exactly
    one extra draw (W0); a Reflect expiry prints before the weather text;
  - faints: a deciding tick stops the loop (both directions) and skips the
    status phase; a replacement-pending faint continues; a 0-HP battler
    awaiting replacement takes no tick (D4) with no order draw;
  - Cloud Nine and Air Lock on either side: text and timer continue, no
    damage, no damage term; a fainted holder no longer suppresses; R3 pins
    `activeWeather` (HP-gated) vs `damageWeather` (HP-free);
  - damage terms at the formula level (truncation, 0 → 2, after Light Screen,
    physical untouched) and through each engine call site (ordinary,
    multi-hit, Triple Kick, Explosion; the last three with synthetic Water
    records because no real Water move uses those paths);
  - Solar Beam halved on the release turn in rain, sandstorm and hail, not in
    sun, keyed on the move id;
  - freeze in sun: Ice Beam's passing roll freezes nothing with the draw
    count unchanged; Tri Attack's freeze pick fails after both draws; rain
    and Cloud Nine still freeze;
  - AI: the 4×4 matrix, the stale-ability rows (Stench 1, Drizzle 2, Speed
    Boost 3, ability 0 fixture-only), active weather overriding the stale
    value, and through `TrainerAI` (including Cloud Nine ignored);
  - controller: all twelve weather texts, both damage texts with the HP
    entry, and engine → controller order for a real Sandstorm turn and its
    failure text.
- Mutation spot-checks (each reverted): ON_AIR exempt fails 4; hail not
  decrementing under the permanent flag fails 1; player-first loop order fails
  3; no Cloud Nine HP gate fails 2; no freeze-in-sun fails 2; multi-hit site
  passing nil fails 1; no `isOver` stop fails 2; no 0-HP skip fails 1; the AI
  handler without `weatherKind` fails 9; Solar Beam keyed on the effect fails
  1. Against `b3dd0ba` the new test errors at the first weather move
  (unsupported effect).
- `tests/phase4_weather_effect_rom_test.lua`: records 201, 240, 241, 258 and
  76 and exact family membership; skips without a ROM (ROM fixture pending).
- `bash scripts/test_all.sh` and `lua5.1 scripts/check_repository.lua` pass.

## Deviations from the design

- `AICheckBadMove.lua:84-90` (the module header's "confirmed no-op class"
  prose, which still lists weather) is on the design's comment touch list,
  but the file-ownership limit allows only the weather rows, their handler
  and the `weatherKind` plumbing. The header was left as is; the new handler's
  comment states that the four rows left the no-op class. A follow-up owner
  of that file can drop "weather" from the header.
- `resolveMultiHit` and `resolveTripleKick` gain a trailing `moveId`
  argument so those sites can pass the move id the design asks for.

## Known limits

- R2 / D4: a battler at 0 HP awaiting its replacement takes no weather tick;
  in source the replacement would take it that turn.
- After W1 alone (F10): Thunder still rolls in rain/sun, Solar Beam still
  charges in sun (and does not spend the sun path's second PP), Weather Ball
  stays Normal ×1, and the sunlight heals stay rejected; W2 should follow.
- Not represented: Mist/Safeguard/Wish between screens and weather, Forecast,
  Downpour, the Ghost-without-Scope exemption, Safari's always-effective
  weather, the AI's random ability guess and CheckViability weather terms.
- Replays: no existing replay can contain the four moves (they were
  rejected), so none diverges; a battle using them changes HP totals and
  Fire/Water/Solar Beam damage from that point on. W1 adds no RNG draw.

## Review (2026-10-15)

[Implementation review](../reviews/2026-10-15-weather-w1-implementation-review.md):
PASS (45/47 mutants killed; the two survivors swap the HP-free and HP-gated
weather helpers at the ordinary and Explosion sites, unobservable with FRLG
data). F1 applied (Cloud Nine helper comment now names the Explosion case);
F2 optional test gap and F3 stale AICheckBadMove header (file-ownership
limit) left as recorded.
