# Phase 4 proposal: residual and volatile end-of-turn effects (Leech Seed, Nightmare, Curse, Ingrain, Mean Look, trapping moves)

- Status: `PROPOSAL — awaiting design review`
- Date: 2026-10-15
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
- Builds on: status slices S1-S4 (`StatusConditions`, `resolveStatusEndTurn`),
  confusion/flinch C1-C2, the multi-turn slices M1-M3 (`semiInvulnerable`,
  `cancelMultiTurnMoves`, the rampage tick), weather W0-W3b (`endTurnOrder`,
  `resolveWeatherEndTurn`, Rain Dish) and the forced/voluntary switch work
  (`checkFaint`, `recordFaint`, `finalizeFaintSequence`, `resolveForcedSwitch`).
- Lane: full relay. These slices add battle-only volatile state, new
  end-of-turn output, a deferred team-loss check, new RNG draws (Wrap) and
  an action veto that reaches the controller and `main.lua`.

The [move-effect inventory](phase4-move-effect-inventory.md) marks every
family here `B`:

| Effect | Moves | Today | Inventory row |
| --- | --- | --- | --- |
| 84 `EFFECT_LEECH_SEED` | 73 | rejected | `:190` |
| 107 `EFFECT_NIGHTMARE` | 171 | rejected | `:213` |
| 109 `EFFECT_CURSE` | 174 | rejected | `:215` |
| 181 `EFFECT_INGRAIN` | 275 | rejected | `:287` |
| 106 `EFFECT_MEAN_LOOK` | 169 Spider Web, 212 Mean Look, 335 Block | rejected | `:212` |
| 42 `EFFECT_TRAP` | 20 Bind, 35 Wrap, 83 Fire Spin, 128 Clamp, 250 Whirlpool, 328 Sand Tomb | admitted as plain hits | `:148` |
| 129 `EFFECT_RAPID_SPIN` (cleanup of the above) | 229 | admitted as a plain hit | `:235` |

Source paths below are relative to the pin. `bsc.c` is
`src/battle_script_commands.c`, `bs1.s` is `data/battle_scripts_1.s`,
`bu.c` is `src/battle_util.c`, `bm.c` is `src/battle_main.c`,
`msg.c` is `src/battle_message.c`, `ai.s` is `data/battle_ai_scripts.s`,
`pm.c` is `src/party_menu.c`, `moves.h` is `src/data/battle_moves.h`,
`cb.h` is `include/constants/battle.h`. Engine paths are `src/core/…` at
the current working tree (2026-10-15, after W3b).

## Summary

- **R1** — Leech Seed (with Liquid Ooze), Nightmare, both forms of Curse,
  and Rapid Spin's Leech Seed cleanup. Extends the per-battler end-of-turn
  order. Adds a deferred team-loss check, because a Leech Seed knockout
  does not end the battle by itself.
- **R2** — the escape-prevention core, plus Ingrain and Mean Look / Spider
  Web / Block. Adds an engine query, `runTurn` asserts, a controller veto
  for RUN and for a voluntary switch, and one named `main.lua` guard.
- **R3** — the six trapping moves: the 3-6 turn timer and its draws,
  residual damage, the release text, clearing when the wrapper leaves,
  Whirlpool against a Dive user, and Rapid Spin's wrap arm. Needs R2.

This departs from the brief's example split in one place: **Ingrain moves
from R1 to R2**. `STATUS3_ROOTED` is one of the three escape-prevention
bits at every veto site (`bm.c:3047-3048`, `:3198`, `bsc.c:4543-4545`).
Shipping it without the veto would let a rooted player run or switch.

## Source facts

### 1. State (`cb.h`, `include/battle.h`)

| Effect | Bits | Owner / partner | Notes |
| --- | --- | --- | --- |
| Leech Seed | `STATUS3_LEECHSEED` (bit 2) + `STATUS3_LEECHSEED_BATTLER` (bits 0-1) on the **seeded** battler (`cb.h:134-135`) | The partner bits hold the seeder's **battler slot id** (`bsc.c:6450`), not a mon | `Cmd_setseeded` ORs `gBattlerAttacker` into the low bits. In singles this is always the opposing slot. |
| Ingrain | `STATUS3_ROOTED` (bit 10, `cb.h:143`) on the user | none | |
| Nightmare | `STATUS2_NIGHTMARE` (bit 27, `cb.h:127`) on the target | none | |
| Curse (Ghost) | `STATUS2_CURSED` (bit 28, `cb.h:128`) on the target | none | |
| Mean Look | `STATUS2_ESCAPE_PREVENTION` (bit 26, `cb.h:126`) on the target | `gDisableStructs[target].battlerPreventingEscape` = attacker slot (`bsc.c:2674-2675`) | |
| Trap | `STATUS2_WRAPPED` (bits 13-15, a 3-bit turn counter, `cb.h:116-117`) on the target | `gBattleStruct->wrappedBy[target]` = attacker slot; `wrappedMove[target]` = move id for texts (`bsc.c:2490-2494`; `include/battle.h:379`, `:385`) | |

### 2. Clearing

- **Switch-in of slot X** (`SwitchInClearSetData`, `bm.c:2329-2431`). Not
  Baton Pass:
  - X's own `status2` and `gStatuses3` are zeroed (`:2365-2368`).
  - Every battler whose `battlerPreventingEscape == X` loses
    `ESCAPE_PREVENTION` (`:2339-2343`).
  - Every battler whose `wrappedBy == X` loses `WRAPPED` (`:2371-2377`).
    This also runs on a Baton Pass.
  - **Nothing clears another battler's `LEECHSEED`.** The seed stays on
    the target and now heals whichever mon holds slot X.
- **Faint of slot X** (`Cmd_cleareffectsonfaint`, `bsc.c:2925-2938`, then
  `FaintClearSetData`, `bm.c:2433-2452`):
  - X's status1, status2 and status3 are zeroed (`:2441-2442`).
  - Others lose `ESCAPE_PREVENTION` and `WRAPPED` held by X (`:2444-2452`).
  - Again, nothing clears a seed whose receiver is X. While X is at 0 HP
    the drain is skipped (`bu.c:791`). After the replacement arrives, the
    replacement receives the heal.
- **Baton Pass** (not modeled; `bm.c:2350-2353`) would keep
  `ESCAPE_PREVENTION`, `CURSED`, `LEECHSEED` (with the slot bits) and
  `ROOTED` on the incoming mon. It would drop `NIGHTMARE` and `WRAPPED`.
- **Nightmare** also ends at:
  - the sleep canceller's wake-up, `bu.c:1300`, plus the Uproar wake at
    `:1272` (Uproar is not modeled);
  - the FRLG end-of-turn sleep re-check (§4);
  - Shed Skin, Insomnia and Vital Spirit cures, and Heal Bell / Aromatherapy
    (`bu.c:1849`, `:2117`; `bsc.c:8015-8078`). None of these is modeled.
- **Substitute** clears the user's `WRAPPED` (`bsc.c:7460`). Substitute is
  not modeled.

### 3. Move scripts and fail cases

**Leech Seed** (`bs1.s:1153-1166`; `moves.h:952`: power 0, Grass, acc 90,
SELECTED):

1. `attackcanceler`, `attackstring`, `ppreduce`.
2. If the target has a Substitute: `ButItFailed`. Not modeled, so never
   taken.
3. `accuracycheck BattleScript_DoLeechSeed, ACC_CURR_MOVE`. **The miss
   pointer is the success label.** Both a miss and a hit reach `setseeded`.
   A semi-invulnerable target misses with no draw (`bsc.c:958-1001`).
   Otherwise there is one accuracy draw.
4. `Cmd_setseeded` (`bsc.c:6436-6456`) checks, in order:
   1. `MOVE_RESULT_NO_EFFECT` (a miss) **or already seeded** →
      `B_MSG_LEECH_SEED_MISS`: "X evaded\nthe attack!" (`msg.c:160`).
   2. A Grass target in either type slot → `B_MSG_LEECH_SEED_FAIL`: "It
      doesn't affect\nX…" (`msg.c:70`). The accuracy draw is already spent.
   3. Otherwise seed the target: "X was seeded!" (`msg.c:159`).
5. `attackanimation` (skipped on failure), then
   `printfromtable gLeechSeedStringIds` (`msg.c:964-971`).

There is no `typecalc`, so a Ghost target can be seeded.

**Nightmare** (`bs1.s:1455-1469`; `moves.h:2226`: Ghost, acc 100):

1. `attackcanceler`, `attackstring`, `ppreduce`.
2. Substitute → fail. Already `NIGHTMARE` → fail. Target not asleep →
   fail. Each fail prints "But it failed!" (`msg.c:336`).
3. On success: `setmoveeffect MOVE_EFFECT_NIGHTMARE` + `seteffectprimary`,
   which sets the bit (`bsc.c:2678-2681`). Then "X fell into\na NIGHTMARE!"
   (`msg.c:198`).

There is **no `accuracycheck`** and no `typecalc`. A Normal-type target
can be given a nightmare. There is no RNG.

**Curse** (`bs1.s:1478-1523`; `moves.h:2265`: type Mystery, acc 0,
SELECTED, flags 0):

- **The Ghost test runs before `attackcanceler`.** `jumpiftype2
  BS_ATTACKER, TYPE_GHOST` checks the attacker's type1 or type2
  (`bsc.c:3826-3834`).
- **Non-Ghost** path, after `attackcanceler`, `attackstring` and `ppreduce`:
  - It fails **only** if Speed is at −6 **and** Attack is at +6 **and**
    Defense is at +6 (the three `jumpifstat` lines, `:1483-1485`).
  - Otherwise: one attack animation, then three `statbuffchange
    AFFECTS_USER | STAT_CHANGE_ALLOW_PTR` calls in order: Speed −1, then
    Attack +1, then Defense +1.
  - With `ALLOW_PTR`, `ChangeStatBuffs` returns `WORKED` even at the limit.
    It prints "won't go lower/higher" from the table (`bsc.c:6772-6775`,
    `:6799-6810`). So, for example, Speed at −6 with Attack below +6 gives
    "X's SPEED won't go lower!", then "ATTACK rose!", then "DEFENSE rose!".
  - The Mist, Protect and Clear Body/White Smoke checks all exempt
    `gCurrentMove == MOVE_CURSE` (move id 174) (`bsc.c:6679-6680`,
    `:6697-6698`, `:6702-6704`).
  - There is no RNG.
- **Ghost** path (`BattleScript_GhostCurse`, `:1507-1523`):
  1. `attackcanceler`, `attackstring`, `ppreduce`.
  2. Substitute → fail.
  3. `accuracycheck … NO_ACC_CALC_CHECK_LOCK_ON`: no draw, but a
     semi-invulnerable target goes to `ButItFailed` (`bsc.c:1020-1028`).
  4. `cursetarget` (`bsc.c:8093-8108`): an already-cursed target fails.
     Otherwise it sets `CURSED`, and
     `gBattleMoveDamage = max(1, attacker.maxHP / 2)`.
  5. The attacker's HP update, clamped at 0. `gHpDealt` is the real loss
     (`bsc.c:1811-1820`).
  6. "X cut its own HP and\nlaid a CURSE on Y!" (`msg.c:200`).
  7. `tryfaintmon BS_ATTACKER`. The user can knock itself out.

**Ingrain** (`bs1.s:2372-2380`; `moves.h:3578`: USER):

- `attackcanceler`, `attackstring`, `ppreduce`, then `trysetroots`
  (`bsc.c:8933-8944`).
- Already rooted → "But it failed!". Otherwise set `ROOTED` and print "X
  planted its roots!" (`msg.c:234`).
- There is no accuracy check and no RNG.

**Mean Look / Spider Web / Block** (`bs1.s:1440-1453`; `moves.h:2759`,
`:2200`, `:4358`; acc 100, SELECTED):

1. `attackcanceler`, `attackstring`, `ppreduce`.
2. `accuracycheck BattleScript_ButItFailed, NO_ACC_CALC`: no draw, but a
   semi-invulnerable target fails.
3. Already `ESCAPE_PREVENTION` → fail. Substitute → fail.
4. `MOVE_EFFECT_PREVENT_ESCAPE` primary (`bsc.c:2673-2677`), then "X
   can't\nescape now!" (`msg.c:197`).

A target that is already wrapped is not escape-prevented, so Mean Look
still succeeds on it.

**Trap** (`bs1.s:829-835`; records `moves.h:263`, `:458`, `:1082`, `:1667`,
`:3253`, `:4267`). All six have chance 100. Power, type and accuracy:

| Move | Power | Type | Acc |
| --- | ---: | --- | ---: |
| Bind | 15 | Normal | 75 |
| Wrap | 15 | Normal | 85 |
| Fire Spin | 15 | Fire | 70 |
| Clamp | 35 | Water | 75 |
| Whirlpool | 15 | Water | 70 |
| Sand Tomb | 15 | Ground | 70 |

1. Whirlpool only, and only against an `UNDERWATER` target, before
   `attackcanceler`: `orword HITMARKER_IGNORE_UNDERWATER` and
   `setbyte sDMG_MULTIPLIER, 2`. Surf's twin in `BattleScript_EffectHit`
   (`bs1.s:239-243`) does not fire, because the move is not Surf.
2. `setmoveeffect MOVE_EFFECT_WRAP` (byte 13, `cb.h:234`), then
   `BattleScript_EffectHit`. That is the ordinary hit, then
   `seteffectwithchance`, then `tryfaintmon BS_TARGET` (`bs1.s:262-270`).
3. `Cmd_seteffectwithchance` (`bsc.c:2774-2805`): the byte is not
   `CERTAIN`, so it draws **`Random() % 100`** as the first `&&` operand.
   - This draw happens on a landed hit **and** on a no-effect hit, such as
     Bind/Wrap against a Ghost or Sand Tomb against a Flying type.
   - On a landed hit, `<= 100` always passes, so it calls
     `SetMoveEffect(FALSE, CERTAIN)`.
   - A miss jumps away earlier, with no draw.
4. `SetMoveEffect` guards (`bsc.c:2132-2146`):
   - Shield Dust covers only bytes ≤ 9, so it does not apply.
   - Safeguard covers only bytes ≤ 7, so it does not apply.
   - **A target at 0 HP returns silently with no further draw.**
   - Substitute returns (not modeled).
5. Wrap case (`bsc.c:2483-2506`):
   - If the target is already `WRAPPED`: nothing happens (no re-roll, no
     text).
   - Otherwise: **`(Random() & 3) + 3` turns** (3-6). Store `wrappedMove`
     and `wrappedBy`, then print `gWrappedStringIds[index of move in
     gTrappingMoves]` (`msg.c:1042-1050`, `:1263-1271`).

**Rapid Spin** (`bs1.s:1711-1713`; `moves.h:2980`: Normal 20, acc 100,
chance 0):

- Its byte is `MOVE_EFFECT_RAPIDSPIN | AFFECTS_USER | CERTAIN`.
- On a landed hit, the `CERTAIN` branch runs with no draw. The effect
  battler is the attacker; it passes the 0-HP guard and then
  `BattleScript_RapidSpinAway` → `Cmd_rapidspinfree` (`bsc.c:8435-8469`).
  This is an **else-if chain, so one cleanup per use**:
  1. If the user is `WRAPPED`: clear it and print "X got free of\nY's
     WRAP!" (`msg.c:211`; `bs1.s:3445-3449`).
  2. Else, if the user is seeded: clear it and print "X shed\nLEECH SEED!"
     (`msg.c:212`; `bs1.s:3451-3454`).
  3. Else, Spikes (not modeled, so never set).
- On a no-effect hit (Ghost target), `CERTAIN && !NO_EFFECT` fails. The
  else-if then draws `Random() % 100` with nothing applied. This is the
  same shape as the engine's Smelling Salt handling.
- It runs before `tryfaintmon BS_TARGET`, so it also frees the user on a
  KO.

### 4. End of turn (`DoBattlerEndTurnEffects`, `bu.c:720-1060`)

Field effects first (`bm.c:2958-2963`). Then, **per battler** in
`gBattlerByTurnOrder` (the W0 `ENDTURN_ORDER`), one battler's whole list
before the next battler (`bu.c:749-757`, `:1051-1054`). The cases
(`bu.c:720-742`), with what the engine does today:

| # | Case | Source | Engine today |
| --- | --- | --- | --- |
| 1 | `ENDTURN_INGRAIN` | `:760-773` | — (R2) |
| 2 | `ENDTURN_ABILITIES` (Rain Dish) | `:774-778` | `BattleEngine.lua:3586-3592` |
| 3 | `ENDTURN_ITEMS1` | `:779-783` | not modeled (no held items) |
| 4 | `ENDTURN_LEECH_SEED` | `:789-804` | — (R1) |
| 5-7 | `POISON`, `BAD_POISON`, `BURN` | `:805-840` | `:3593-3620` |
| 8 | `ENDTURN_NIGHTMARES` | `:841-860` | — (R1) |
| 9 | `ENDTURN_CURSE` | `:861-871` | — (R1) |
| 10 | `ENDTURN_WRAP` | `:872-903` | — (R3) |
| 11 | `ENDTURN_UPROAR` | `:904-952` | not modeled |
| 12 | `ENDTURN_THRASH` | `:953-973` | `:3621-3637` (rampage tick) |
| 13+ | Disable, Encore, Lock-On, Charge, Taunt, Yawn, `ITEMS2` | `:975-1050` | not modeled |

Case details:

- **Ingrain:** if `ROOTED`, `hp != maxHP` and `hp != 0`, heal
  `max(1, maxHP/16)`. `BattleScript_IngrainTurnHeal` (`bs1.s:3553-3560`)
  prints "X absorbed\nnutrients with its roots!" (`msg.c:235`) **before**
  the HP update, which clamps. There is no faint and no team check.
- **Leech Seed:** requires `LEECHSEED`, **seeder slot `hp != 0`** and own
  `hp != 0`.
  - The damage is `max(1, seeded.maxHP/8)`.
  - `BattleScript_LeechSeedTurnDrain` (`bs1.s:3223-3243`) runs:
    1. The seeded battler's HP update. `gHpDealt` is the actual loss,
       capped at its HP.
    2. `copyword gBattleMoveDamage, gHpDealt`.
    3. If the **seeded** battler has Liquid Ooze (64), the seeder takes
       `gHpDealt` as damage, with text "It sucked up the\nLIQUID OOZE!"
       (`msg.c:290`). Otherwise `manipulatedamage 0` negates it, and the
       seeder heals `gHpDealt` (clamped at maxHP), with text "X's health
       is\nsapped by LEECH SEED!" (`msg.c:161`). X is the seeded battler.
    4. The text comes **after both HP updates**.
    5. `tryfaintmon BS_ATTACKER` (seeded), then `tryfaintmon BS_TARGET`
       (seeder; reachable only through Liquid Ooze).
  - **There is no `checkteamslost`** (see §5).
  - The text still prints when the seeder is at full HP.
- **Nightmare:** if `NIGHTMARE` and `hp != 0`:
  - Asleep: `max(1, maxHP/4)`. `BattleScript_NightmareTurnDmg`
    (`bs1.s:3791-3795`): "X is locked\nin a NIGHTMARE!" (`msg.c:199`), then
    `DoTurnDmg`.
  - Not asleep: the bit is cleared silently. The FRLG source comment
    (`bu.c:844-845`) says R/S lacked this check.
- **Curse:** if `CURSED` and `hp != 0`: `max(1, maxHP/4)`, "X is
  afflicted\nby the CURSE!" (`msg.c:201`; `bs1.s:3797-3801`), then
  `DoTurnDmg`.
- **Wrap:** if `WRAPPED` and `hp != 0`, decrement the counter. The
  wrapper's HP is not tested, because its faint already cleared the bit.
  - Counter still nonzero: `max(1, maxHP/16)`, "X is hurt\nby WRAP!"
    (`msg.c:148`, `B_BUFF1` = `wrappedMove`; `bs1.s:3769-3773`), then
    `DoTurnDmg`.
  - Counter reached 0: "X was freed\nfrom WRAP!" (`msg.c:149`;
    `bs1.s:3775-3778`). No damage and no team check.
  - A 3-6 counter therefore gives **2-5 damage ticks** (the set turn
    included), then one release turn.
- **`DoTurnDmg`** (`bs1.s:3680-3688`): HP update, `tryfaintmon`, then
  **`checkteamslost` on every tick**, fatal or not.
- **No semi-invulnerability exemption.** None of these cases tests
  `STATUS3_SEMI_INVULNERABLE`, so a Fly, Dig or Dive user still ticks.
- **Absent battlers** are skipped (`bu.c:752-755`). Every case also tests
  the battler's own `hp != 0`.

### 5. Faints and the team check during end of turn

- `BattleTurnPassed` (`bm.c:2953-2965`) re-enters on every effect and
  re-tests `gBattleOutcome == 0` before `DoBattlerEndTurnEffects`. So
  only a `checkteamslost` that sets the outcome stops the rest of the
  phase. `Cmd_checkteamslost` (`bsc.c:3385-3412`) ORs `LOST` (2) and
  `WON` (1) independently from the whole parties' HP, so both together
  give `DREW` (3, `cb.h:76-78`).
- `tryfaintmon` alone (`bsc.c:2831-2905`) runs the faint script and
  `cleareffectsonfaint`. It does **not** set the outcome.
- **Consequence for Leech Seed.** A drain that knocks out a side's last
  mon (or a Liquid Ooze knockout of the seeder) leaves `gBattleOutcome`
  at 0. The phase continues: the knocked-out battler's remaining cases
  skip on `hp == 0`, and the **other battler's whole list still runs**.
  The outcome is decided by the next `checkteamslost`:
  - any later `DoTurnDmg` tick (poison, toxic, burn, nightmare, curse,
    wrap damage), **even a non-fatal one**; or
  - `HandleFaintedMonActions`'s `BattleScript_HandleFaintedMon`
    (`bu.c:1144`; `bs1.s:2824-2826`).

  If the other battler's own poison then knocks out its last mon, the
  result is a **draw**, not a win.

### 6. Escape prevention

**RUN (selection time).** `HandleTurnActionSelectionState`
(`bm.c:3239-3253`) checks, in order:

1. A trainer battle → `BattleScript_PrintCantRunFromTrainer`.
2. Otherwise `IsRunningFromBattleImpossible() != SUCCESS` →
   `BattleScript_PrintCantEscapeFromBattle` (`bs1.s:3038-3040`). This is a
   **selection script**: "Can't escape!" (`msg.c:333`,
   `gNoEscapeStringIds[0]`, `msg.c:903-910`), then back to
   `STATE_BEFORE_ACTION_CHOSEN`.
   - No turn passes, `runTries` is not incremented, and there is no RNG.

`IsRunningFromBattleImpossible` (`bm.c:3002-3058`) checks, in order:

1. Smoke Ball, a link battle, or **Run Away (50)** → SUCCESS
   (`:3013-3016`).
2. Shadow Tag, Arena Trap and Magnet Pull → FAILURE with "X prevents
   escape with Y!" (not modeled).
3. `ESCAPE_PREVENTION | WRAPPED` or `ROOTED` → FORBIDDEN
   (`:3047-3052`).
4. A first battle → FORBIDDEN.

`TryRunFromBattle` (`bm.c:4229-4280`) does not re-test trapping. The foe
side's run in `HandleAction_Run` (`:4314-4324`) does, but the engine has
no foe run.

**Switch.** `B_ACTION_SWITCH` selection (`bm.c:3196-3200`): if `WRAPPED
| ESCAPE_PREVENTION` or `ROOTED`, the party menu still opens, with
`PARTY_ACTION_CANT_SWITCH`.

- In `TrySwitchInPokemon` (`pm.c:5916-5968`), choosing a mon that passes
  the earlier checks (fainted "has no energy", "already in battle", Egg)
  prints "{active} can't be switched\nout!" (`src/strings.c:256`;
  `pm.c:5960-5966`). The player stays in the menu.
- No Run Away bypass applies to switching.
- The script-level `jumpifcantswitch` (`bsc.c:4536-4545`) tests the same
  three bits. It is used by Baton Pass and Roar, neither of which is
  modeled.

**A forced replacement after a faint is never blocked.** The fainted
battler's bits are already zero.

### 7. Reachability

- **Leech Seed.**
  - Bulbasaur, the player's starter, learns it at level 7.
  - Hoppip learns it at 20 and Exeggcute at 13.
  - It appears in 3 trainer movesets (`trainer_parties.h`).
  - The wild foe never uses status moves (`main.lua:1300-1308` picks the
    first damaging slot), so for wild battles this is a player-side move.
- **Liquid Ooze.** Tentacool and Tentacruel (common surfing encounters)
  have it, so the player's seed against a wild Tentacool is ordinary
  play.
- **Curse (Ghost).** Gastly learns it at 13 (Pokémon Tower Channelers use
  TrainerAI). It is in 1 trainer moveset. Non-Ghost users: 15 learnsets.
- **Wrap / Bind.**
  - **Wild Ekans (FireRed) and Dratini list Wrap first**, and Onix gets
    Bind at 8. A wild Ekans's first damaging move is Wrap, so **today a
    wild Ekans traps nothing but already desynchronises the RNG**: every
    landed Wrap is missing its `% 100` and `& 3` draws (§3, Risks R4).
  - Trap moves appear in 24 trainer movesets.
- **Whirlpool and Dive.** Dive appears in 2 trainer movesets and in no
  FRLG learnset. Whirlpool is in no trainer moveset.
- **Ingrain:** Tangela at level 1, 4 trainer movesets. **Mean Look:**
  Gastly line and others, 1 trainer moveset. **Nightmare:** 1 trainer
  moveset.
- **Rapid Spin:** Staryu learns it at 10. It appears in 7 trainer movesets.

The counts are `grep` counts over the pinned `level_up_learnsets.h` (all
species) and `trainer_parties.h`.

### 8. AI (`ai.s`, `AI_CheckBadMove` only)

| Effect | Script | Rule | Engine today (`AICheckBadMove.lua`) |
| --- | --- | --- | --- |
| 84 | `AI_CBM_LeechSeed` `:414-420` | target `LEECHSEED` → −10; then Grass type1/type2 → −10 | `:363-366`: Grass only (the seed test is a documented no-op) |
| 107 | `AI_CBM_Nightmare` `:237-240` | target `NIGHTMARE` → −10; then not asleep → −8 | `:294-297`: sleep only |
| 109 | `AI_CBM_Curse` `:438-441` | user Attack 12 → −10; Defense 12 → −8. **No Ghost test** | `:385-387`: already exact |
| 106 | `AI_CBM_CantEscape` `:434-436` | target `ESCAPE_PREVENTION` → −10. It does not test `WRAPPED` or `ROOTED` | `:596`: `alwaysNoPenalty` |
| 181 | `AI_CBM_Ingrain` `:554-556` | user `ROOTED` → −10 | `:630`: `alwaysNoPenalty` |
| 42, 129 | none in `AI_CheckBadMove` | fall through to 0 | unchanged |

`if_status2` and `if_status3` read the live battler words
(`battle_ai_script_commands.c:631`, `:667-680`). The CheckViability terms
are out of scope, as in earlier proposals: `AI_CV_Trap` `:685`, `:723`;
`AI_CV_Toxic` for Leech Seed `:711`; `AI_CV_Curse` `:725`; the Nightmare
sleep encouragement `:780`. `TrainerAI` refuses those flag sets.

## Engine today (fit points)

- **Battler state.** `makeBattler` (`BattleEngine.lua:1042-1094`) has
  `confusionTurns`, `flinched`, `focusEnergy`, the lock fields and
  `semiInvulnerable`. Nothing exists for status3, the escape bits, or the
  partner slot.
  - A switch-in is a fresh battler (`runTurn` switch branch `:3711-3738`;
    `resolveForcedSwitch` `:3307-3330`), so the incoming battler's own
    bits clear for free.
  - Bits held on the **other** battler (wrap, escape prevention) are not
    touched today.
- **Faint.** `recordFaint` (`:1240-1261`) clears status1, confusion,
  flinch, Focus Energy, locks and the rampage. `finalizeFaintSequence`
  (`:1263-1311`) decides the outcome (draw included) or queues
  replacements. `checkFaint` (`:3286-3292`) = begin + record + finalize,
  so **every engine faint is an immediate team check**.
- **End of turn.** `resolveEndTurn` (`:3477-3495`) runs the flinch clear,
  the sleep cancel, `endTurnOrder` (W0, `:3443-3457`), `decaySideTimers`,
  `resolveWeatherEndTurn` (`:3519-3559`), then `resolveStatusEndTurn`
  (`:3581-3639`).
  - Per side, `resolveStatusEndTurn` runs Rain Dish, then
    poison/toxic/burn with `checkFaint`, then the rampage tick.
  - It returns at the top of each side when `isOver()`.
  - 0-HP battlers are skipped.
- **Run / switch.** `runTurn` (`:3653-3878`) hoists the switch, capture
  and run actions.
  - The run branch (`:3788-3815`) calls `BattleFormulas.tryRunFromBattle`
    (`BattleFormulas.lua:694-702`). There is no Run Away bypass, a
    pre-existing gap.
  - The controller blocks a trainer run with `runDisabledMessage`
    (`BattleSceneController.lua:585-588`) before calling the engine. The
    wild RUN calls `_runTurn({action="run"})` directly (`:672`).
  - A voluntary switch exists only for trainer battles:
    `_openVoluntarySwitch` (`:630-651`), then the PARTY A-press (`:714-725`)
    calls `main.lua`'s `onVoluntarySwitchChoice` (`main.lua:1653-1697`).
  - **That callback persists the outgoing battler, advances
    `activePartySlot` and rebuilds sprites (`:1675-1689`) before
    `controller:_runTurn({action="switch"})` (`:1690`).**
- **Accuracy.** `needsAccuracyCheck` / `scriptHasAccuracyCheck`
  (`BattleEngine.lua:2175-2208`).
  - Effects not in the exclusion list get the ordinary roll.
  - The semi-invulnerable fail branch with "But it failed!" exists for
    OHKO and Pain Split (`:2239`).
  - `semiInvulnerableMiss` (`:1683-1689`) treats underwater as "Surf
    only".
  - The dmgMultiplier chain (`:2685-2700`) has the Surf/underwater arm.
- **Secondary rolls.**
  - In the no-effect branch (`:2723-2750`), the families listed draw the
    discarded roll. `EFFECT_TRAP` and `EFFECT_RAPID_SPIN` are absent.
  - In the landed branch (`:2814-2957`), effects 42 and 129 draw nothing
    and apply nothing.
- **Sleep wake.** `resolveStatusCancellers` emits `wokeUp` at `:1429`.
- **Persistence.** `BattlePartyBridge.persistPartyBattler`
  (`BattlePartyBridge.lua:179-198`) writes HP, status1 (with toxic counter
  0) and PP only, so the new volatiles are battle-only by construction.

## Design

### State (all slices)

Added to `makeBattler`, all battle-only and never persisted:

```lua
seeded = false,          -- STATUS3_LEECHSEED (R1); receiver = the opposing slot
nightmare = false,       -- STATUS2_NIGHTMARE (R1)
cursed = false,          -- STATUS2_CURSED (R1)
rooted = false,          -- STATUS3_ROOTED (R2)
escapePrevented = false, -- STATUS2_ESCAPE_PREVENTION (R2); preventer = the opposing slot
wrapTurns = 0,           -- STATUS2_WRAPPED counter 0..6 (R3); wrapper = the opposing slot
wrapMove = nil,          -- gBattleStruct->wrappedMove (R3), for texts
```

**Singles reduction.** `STATUS3_LEECHSEED_BATTLER`, `battlerPreventingEscape`
and `wrappedBy` can only ever name the opposing slot in singles. Every
setter writes `gBattlerAttacker` and every target is the foe. So the
partner is implicit: `otherSide(side)`. The partner is a **slot**, not a
battler object. That is what makes the seed survive the seeder's switch
or faint and heal the replacement, as in source.

**Clearing** (new helper `BattleEngine:clearHeldBy(side)`, from both
sites below):

| Site | Own fields | Opponent fields |
| --- | --- | --- |
| `recordFaint(side)` | all seven | `wrapTurns`/`wrapMove`, `escapePrevented` (`bm.c:2444-2452`) |
| `runTurn` voluntary switch (player) | fresh battler | `wrapTurns`/`wrapMove`, `escapePrevented` (`bm.c:2339-2343`, `:2371-2377`), **not** `seeded` |
| `resolveForcedSwitch` | fresh battler | nothing new (the faint already cleared it) |

### R1: Leech Seed, Nightmare, Curse, Rapid Spin's seed arm

**Admission.** `supportsMove` admits effects 84, 107 and 109 with power 0
and target `SELECTED` (0). Accuracy exclusions:

- Nightmare and both Curse forms skip the roll.
- Ghost Curse keeps the semi-invulnerable fail: add it to the `:2239`
  "But it failed!" branch.
- Leech Seed keeps the ordinary roll and semi-invulnerable miss, but takes
  its own result branch (below).

**Leech Seed** (early branch beside Refresh, after the cancellers):

1. Spend PP.
2. Accuracy: semi-invulnerable → miss (no draw); otherwise
   `accuracyRoll` (one draw).
3. On a miss, or if `defender.seeded`: emit
   `leechSeed{side, target, result="evaded"}`.
4. Else, on a Grass target: emit `result="noEffect"`.
5. Else: set `defender.seeded = true` and emit `result="seeded"`.

The engine's generic miss event is **not** used. Source prints "X evaded
the attack!" for both a miss and an already-seeded target.

**Nightmare:** spend PP. If `defender.nightmare` or the defender is not
asleep, emit `moveFailed`. Otherwise set the flag and emit
`nightmare{side, target}`. No accuracy, no RNG.

**Curse:** pick the path from the attacker's types before the cancellers
are consulted. The cancellers still run first on both paths, which is
equivalent.

- **Non-Ghost:** spend PP.
  - If Speed == 0 **and** Attack == 12 **and** Defense == 12, emit
    `moveFailed`.
  - Otherwise emit, in order, Speed −1, Attack +1, Defense +1 as
    `statChange` events. Use `prevented=true` at a limit ("won't go
    lower/higher"); the stage stays clamped.
  - No Mist, Clear Body or Protect gate.
- **Ghost:** spend PP.
  - Semi-invulnerable target → `moveFailed`.
  - `defender.cursed` → `moveFailed`.
  - Otherwise set `defender.cursed`, take
    `cost = min(attacker.hp, max(1, floor(attacker.maxHP/2)))`, and emit
    `curseLaid{side, target, amount, hpRemaining}`.
  - Then call `checkFaint(attackerSide)`. The user can knock itself out
    and lose the battle.

**Nightmare clear on wake.** Set `attacker.nightmare = false` where
`wokeUp` is emitted (`:1429`, `bu.c:1300`).

**Rapid Spin, seed arm.** In the landed branch, at the Smelling Salt site:

- If `move.effect == 129` and `attacker.hp > 0` and `attacker.seeded`:
  clear it and emit `leechSeedFreed{side}`.
- R3 inserts the wrap arm **before** this one (the else-if chain).

Also add `EFFECT_RAPID_SPIN` to the no-effect discarded-roll list
(`:2723-2750`), which closes its current RNG gap.

**End of turn.** `resolveStatusEndTurn` becomes, per side in `sides`:

1. *(R2) Ingrain.*
2. Rain Dish (unchanged).
3. **Leech Seed**, if all of these hold: `battler.hp > 0`,
   `battler.seeded`, and receiver `self:battler(otherSide(side)).hp > 0`.
   1. `amount = min(hp, max(1, floor(maxHP/8)))`, subtracted.
   2. If `battler.ability == 64` (Liquid Ooze), the receiver loses
      `min(receiver.hp, amount)`. Otherwise it gains
      `min(maxHP - hp, amount)`.
   3. Emit **one** event, `leechSeedDrain{side, receiver, amount,
      hpRemaining, receiverAmount, receiverHpRemaining, ooze}`. The text
      follows both HP changes.
   4. Then call `recordFaintDeferred(side)` and, for an ooze knockout,
      `recordFaintDeferred(receiver)` in that order (§3, `tryfaintmon`
      attacker then target).
4. Poison / toxic / burn (unchanged amounts), then
   `endTurnTeamCheck(events)`.
5. **Nightmare:** if `hp > 0` and `nightmare`:
   - asleep: `amount = min(hp, max(1, floor(maxHP/4)))`, emit
     `nightmareDamage{side, amount, hpRemaining}`, then `endTurnTeamCheck`;
   - otherwise clear the flag silently.
6. **Curse:** if `hp > 0` and `cursed`: `max(1, floor(maxHP/4))`, emit
   `curseDamage`, then `endTurnTeamCheck`.
7. *(R3) Wrap.*
8. Rampage tick (unchanged).

After the loop, call `endTurnTeamCheck(events)` once more. This stands in
for `HandleFaintedMonActions`.

**Deferred team check (decision D2).** It replaces the immediate
`checkFaint` inside the per-battler phase:

- `recordFaintDeferred(side, events)` runs the existing `recordFaint`
  clearing and emits `faint`, but appends the side to
  `self.deferredFaints` without finalizing. The battle is not over, so
  the loop continues.
- `endTurnTeamCheck(events)` opens a faint sequence, records the
  deferred sides plus any battler this tick left at 0 HP, and calls
  `finalizeFaintSequence`. A combined player and foe faint yields
  `playerDrew`, exactly as `checkteamslost`'s OR does. If no faint is
  pending, it does nothing.
- It is called after **every** `DoTurnDmg`-shaped tick (poison, toxic,
  burn, nightmare, curse and, in R3, wrap damage), **fatal or not**,
  because `checkteamslost` runs on every tick. It is not called after
  Ingrain, Rain Dish, Leech Seed or the wrap release.
- Effect: a Leech Seed knockout of the foe's last mon lets the player's
  own list still run until its next damage tick.

### R2: escape-prevention core, Ingrain, Mean Look

**Engine queries** (one place for the later trap abilities):

```lua
-- IsRunningFromBattleImpossible's trap clause (src/battle_main.c:3013-3016,
-- :3047-3052). Run Away returns early; the abilities in between are not modeled.
function BattleEngine:runBlocked(side)
  local b = self:battler(side)
  if b.ability == BattleEngine.ABILITY_RUN_AWAY then return false end
  return b.escapePrevented or b.rooted or (b.wrapTurns or 0) > 0
end
-- The B_ACTION_SWITCH selection test (src/battle_main.c:3198): no Run Away bypass.
function BattleEngine:switchBlocked(side)
  local b = self:battler(side)
  return b.escapePrevented or b.rooted or (b.wrapTurns or 0) > 0
end
```

- `runTurn` asserts `not self:runBlocked(PLAYER)` at the top of the run
  branch, and `not self:switchBlocked(PLAYER)` at the top of the switch
  branch. Source never produces those actions, because the veto is at
  selection.
- Before R3, `wrapTurns` is always 0. The term lands in R2 so that R3
  only sets the field.

**Controller changes** (`BattleSceneController.lua`, owned by the
controller agent):

1. In `_runTurn`, after the `runDisabledMessage` test (the trainer check
   precedes in source, `bm.c:3239-3245`): if `playerAction.action ==
   "run"` and `engine:runBlocked("player")`, set messages
   `{ "Can't escape!" }` and return to ACTION. There is no `runTurn`, no
   RNG and no `runTries` change.
2. In the PARTY A-press, voluntary mode only, before calling
   `onVoluntarySwitchChoice`: if `engine:switchBlocked("player")`, show
   `"<playerName> can't be switched\nout!"` and **stay in PARTY**
   (`pm.c:5960-5966`). A forced replacement is never blocked.
   - The existing "There are no other POKEMON!" path stays as it is. It
     is already a bounded stand-in: in source the menu would open anyway.

**`main.lua` change (explicit, one guard).** In `onVoluntarySwitchChoice`
(`main.lua:1653`), add `if engine:switchBlocked("player") then return nil
end` beside the existing `awaitingForcedSwitch` guard. It must come
**before** `persistPartyBattler` and the `activePartySlot` update
(`:1675-1689`). Without it, any caller that bypasses the controller veto
(the trainer test seam) would mutate party state and then trip the
engine's assert.

- No `main.lua` change is needed for RUN: the controller has the engine.
- The `runBattle()` replay driver (`main.lua:3882-3901`) would make no
  progress against a trapped player. Its current route encounters have no
  trapping move, so nothing changes now (Risks R5).

**Ingrain:** admit effect 181 (power 0, `MOVE_TARGET_USER`), with no
accuracy check. Spend PP. If `attacker.rooted`, emit `moveFailed`.
Otherwise set the flag and emit `rootsPlanted{side}`.

- At end of turn (step 1): if `hp > 0`, `rooted` and `hp < maxHP`, heal
  `min(maxHP - hp, max(1, floor(maxHP/16)))` and emit
  `ingrainHeal{side, amount, hpRemaining}`. The text comes before the HP
  change.
- For the foe this is only a heal: no foe switching or running is
  modeled.

**Mean Look / Spider Web / Block:** admit effect 106 (power 0, target 0).
Spend PP. Fail with `moveFailed` if the target is semi-invulnerable (the
`:2239` branch) or already `escapePrevented`. Otherwise set
`defender.escapePrevented` and emit `escapePrevented{side, target}`.

- Only the player's escape is observable. The foe's flag is set and
  cleared but gates nothing.

**AI rows:** 106 → `escapePrevented` −10; 181 → user `rooted` −10.

### R3: trapping moves

- **Hit tail.** In the landed branch:
  1. Draw `BattleFormulas.secondaryEffectRoll(rng, 100)`, which always
     passes.
  2. Then, if `defender.hp > 0` and `wrapTurns == 0`, set
     `wrapTurns = (rng:next16() % 4) + 3` and `wrapMove = moveId`, and
     emit `wrapped{side=defenderSide, by=attackerSide, move=moveId}`.
  - Add `EFFECT_TRAP` to the no-effect discarded-roll list. A miss draws
    nothing.
  - The tail runs before the caller's defender faint check (the "wrapped"
    text precedes "fainted", but a KO'd target sets nothing).
- **Whirlpool and Dive.** `semiInvulnerableMiss` underwater returns false
  for move 250 as well as Surf. Add a dmgMultiplier arm:
  `defender.semiInvulnerable == "underwater" and moveId == 250 → ×2`.
- **End of turn** (step 7): if `hp > 0` and `wrapTurns > 0`, decrement.
  - Still > 0: `amount = min(hp, max(1, floor(maxHP/16)))`, emit
    `wrapDamage{side, move, amount, hpRemaining}`, then `endTurnTeamCheck`.
  - Reached 0: emit `wrapEnded{side, move}` and clear `wrapMove`.
- **Rapid Spin wrap arm**, before the seed arm: if `attacker.wrapTurns >
  0`, clear it and emit `wrapFreed{side, by=otherSide, move}`. Do not also
  clear the seed.
- **Clearing** comes from `clearHeldBy` (State).

### Deferred and dropped

| Item | Reason |
| --- | --- |
| Substitute checks (Leech Seed, Nightmare, Curse, Mean Look, trap `SetMoveEffect`; Substitute clearing `WRAPPED`) | Substitute is not modeled. No battler can hold one, so every check is exactly "false". |
| Baton Pass carry-over (`bm.c:2350-2353`) | Not modeled. Recorded so a future Baton Pass knows which bits survive. |
| Shadow Tag, Arena Trap, Magnet Pull | Not modeled: a pre-existing gap. Diglett's Cave Arena Trap is the reachable case. `runBlocked`/`switchBlocked` are the single place to add them. |
| Run Away in `TryRunFromBattle` (no draw, always escape) | A pre-existing gap. R2 adds only the veto bypass. Decision D4. |
| Liquid Ooze for Absorb/Mega Drain/Giga Drain (`bs1.s:347`) | The same ability and text, but a different family. Proposed as a follow-up (D5). |
| Roar/Whirlwind anchor ("X anchored itself with its roots!", `msg.c:236`) | Roar and Whirlwind are blocked in the inventory. |
| Uproar, Shed Skin, Insomnia/Vital Spirit and Heal Bell Nightmare clears | Those mechanics are not modeled. The FRLG end-of-turn sleep re-check covers any leftover flag. |
| Ghost-without-Scope battles | Not modeled anywhere. |
| Snatch (Ingrain), Magic Coat (Leech Seed, Mean Look) | Not modeled. |
| Spikes arm of `rapidspinfree` | Spikes is not modeled, so never set. |
| Foe-side run/switch veto | The engine has no foe run or foe switch. |

## Events and controller texts

The controller is owned by another agent; this table is its work list.

| Event | Text (source) | Order |
| --- | --- | --- |
| `leechSeed{result="seeded"}` / `"evaded"` / `"noEffect"` | "X was seeded!" / "X evaded\nthe attack!" / "It doesn't affect\nX…" (`msg.c:159`, `:160`, `:70`) | target name |
| `leechSeedDrain{side, receiver, ooze=false}` | "X's health is\nsapped by LEECH SEED!" (`msg.c:161`) | after both HP entries (`bs1.s:3225-3240`) |
| `leechSeedDrain{ooze=true}` | "It sucked up the\nLIQUID OOZE!" (`msg.c:290`) | after both HP entries |
| `nightmare` | "X fell into\na NIGHTMARE!" (`msg.c:198`) | |
| `nightmareDamage` | "X is locked\nin a NIGHTMARE!" (`msg.c:199`) | text, then HP |
| `curseLaid` | "X cut its own HP and\nlaid a CURSE on Y!" (`msg.c:200`) | HP, then text (`bs1.s:1521-1523`) |
| `curseDamage` | "X is afflicted\nby the CURSE!" (`msg.c:201`) | text, then HP |
| `statChange` (reused) | the existing stat texts, including "won't go lower/higher" | Speed, Attack, Defense |
| `leechSeedFreed` | "X shed\nLEECH SEED!" (`msg.c:212`) | before the target's faint |
| `rootsPlanted` (R2) | "X planted its roots!" (`msg.c:234`) | |
| `ingrainHeal` (R2) | "X absorbed\nnutrients with its roots!" (`msg.c:235`) | text, then HP |
| `escapePrevented` (R2) | "X can't\nescape now!" (`msg.c:197`) | target name |
| controller veto (R2) | "Can't escape!" (`msg.c:333`); "X can't be switched\nout!" (`strings.c:256`) | no engine event |
| `wrapped` (R3) | Bind "X was squeezed by\nY's BIND!"; Wrap "X was WRAPPED by\nY!"; Fire Spin / Whirlpool "X was trapped\nin the vortex!"; Clamp "Y CLAMPED\nX!"; Sand Tomb "X was trapped\nby SAND TOMB!" (`msg.c:143-147`, table `:1042-1050`) | after the effectiveness text, before the faint |
| `wrapDamage` (R3) | "X is hurt\nby MOVE!" (`msg.c:148`) | text, then HP |
| `wrapEnded` (R3) | "X was freed\nfrom MOVE!" (`msg.c:149`) | |
| `wrapFreed` (R3) | "X got free of\nY's MOVE!" (`msg.c:211`) | |
| `moveFailed` (reused) | "But it failed!" (`msg.c:336`) | |

Also update the header event list (`BattleEngine.lua:21-100`) and the
"no trapping" header note (`:285`).

## Slices

| Slice | Content | Unlocks (inventory test authoritative) |
| --- | --- | --- |
| R1 | Fields `seeded`/`nightmare`/`cursed`; `clearHeldBy`; Leech Seed (miss/seeded = "evaded", Grass), Nightmare, Curse (both paths, Ghost self-KO); wake clears Nightmare; Rapid Spin seed arm and no-effect roll; end-of-turn Leech Seed (Liquid Ooze), Nightmare (with the silent clear), Curse; `recordFaintDeferred` / `endTurnTeamCheck`; AI rows 84 and 107 gain their first −10 test; texts | 3 records admitted (expected 295/59); 129 leaves the uncovered list (25 → 24 effects, 33 → 32 records); rows 84/107/109/129 → R |
| R2 | Fields `rooted`/`escapePrevented`; `runBlocked`/`switchBlocked` (with the `wrapTurns` term) and the `runTurn` asserts; the controller RUN and PARTY vetoes; the `main.lua:1653` guard; Ingrain (with the end-of-turn heal) and Mean Look/Spider Web/Block; AI rows 106/181; texts | 4 records admitted (expected 299/55); rows 106/181 → R |
| R3 | Fields `wrapTurns`/`wrapMove`; the trap hit tail (`% 100` + `& 3`); no-effect roll; Whirlpool vs Dive; end-of-turn wrap damage/release; wrapper switch/faint clears; Rapid Spin wrap arm; texts | 42 leaves the uncovered list (24 → 23 effects, 32 → 26 records); rows 42/129 notes updated |

R3 depends on R2: a wrapped player must not be able to run. R1 and R2
are independent, but R1 first is recommended, because it carries the
deferred team check that R2's Ingrain and R3's wrap tick slot into.

## Verification plan

- **R1.**
  - Leech Seed:
    - seeds;
    - draws exactly one accuracy roll, and none against Dig;
    - a miss and an already-seeded target both emit "evaded";
    - a Grass target emits `noEffect` after the draw;
    - a Ghost target is seeded.
  - Drain:
    - `maxHP/8`, minimum 1, capped at the seeded battler's HP;
    - the heal is clamped at the receiver's maxHP, and the text still
      prints at full HP;
    - no drain while the receiver is at 0 HP (a pending replacement);
    - after a voluntary player switch, the seed on the foe heals the new
      player battler;
    - after the seeded battler switches, the seed is gone.
  - Liquid Ooze: the receiver takes the damage; seeded first, then
    receiver faint order.
  - **The deferred team check:**
    - the foe's last mon is KO'd by the seed, foe first in order, and the
      poisoned player then takes its poison tick before `battleEnd` (win);
    - the same, but the poison KOs the player → `playerDrew`;
    - a non-fatal tick still ends the phase, so a later Curse tick on the
      player does not run;
    - Ingrain (R2) and Rain Dish do not trigger the check.
  - Nightmare: all three fail paths; the end-of-turn tick at `maxHP/4`;
    cleared on `wokeUp`; silently cleared at end of turn when not asleep;
    cleared on faint and on switch.
  - Curse, non-Ghost: the fail matrix (exactly −6/+6/+6 fails; −6/+6/+5
    succeeds with two "won't" texts); no draws.
  - Curse, Ghost: the semi-invulnerable fail with no draw; the
    already-cursed fail with no HP cost; the HP cost at odd maxHP and at
    1 HP; a self-KO loses the battle; the `maxHP/4` tick.
  - Order on one battler: Rain Dish < Leech Seed < poison < Nightmare <
    Curse < rampage tick.
  - Rapid Spin: frees the seed (including on a KO); no draw on a landed
    hit; one draw against a Ghost.
  - AI −10 rows.
- **R2.**
  - The engine asserts.
  - The controller: RUN while rooted or escape-prevented → "Can't
    escape!", no turn, no RNG, `runTries` unchanged; a trainer battle
    still shows `runDisabledMessage` first; Run Away bypasses the veto.
  - PARTY: a voluntary pick while trapped → "can't be switched out!",
    stays in PARTY, party state unchanged (the `main.lua` guard); a forced
    replacement is unaffected.
  - Mean Look: the escape lock is cleared when the preventer switches or
    faints; semi-invulnerable and repeat fails.
  - Ingrain: the heal order before Rain Dish, the full-HP skip, the
    repeat fail.
- **R3.**
  - The turn draw is exact: 3-6, with damage ticks of count−1, then the
    release.
  - `% 100` on a landed and on a no-effect hit; no `& 3` on a KO or an
    already-wrapped target; no draws on a miss.
  - The texts per move (table index).
  - A wrapped player cannot run or switch.
  - The wrap clears when the wrapper switches or faints.
  - Whirlpool hits Dive for ×2; other trap moves miss Dive.
  - Wrap damage triggers `endTurnTeamCheck`; the release does not.
  - Rapid Spin frees the wrap only, even when also seeded.
- **All slices.**
  - Controller text order through the real engine.
  - ROM record fixtures for moves 20, 35, 73, 83, 128, 169, 171, 174, 212,
    229, 250, 275, 328 and 335.
  - The no-ROM suite, the repository checker, and an independent review.

## Decisions for review

- **D1 (split).** Should Ingrain move to R2, and Rapid Spin's cleanup be
  split across R1 and R3?
  - Recommendation: yes. Rooting is an escape lock (§6).
  - Rapid Spin is already admitted, so leaving it untouched once seeds
    and wraps exist would add new divergences.
- **D2 (deferred team check).** Should R1 model the Leech Seed drain's
  missing `checkteamslost` (§5)?
  - Recommendation: yes. It is cheap given `faintSequence`, and it decides
    win versus draw and which texts print.
  - If declined, Leech Seed calls `checkFaint`, and this becomes a Known
    limit.
- **D3 (veto placement).** Put the queries on the engine, assert in
  `runTurn`, put the user-facing veto in the controller, and add one
  `main.lua` guard before party mutation. Confirm with the controller
  owner.
- **D4 (Run Away).** R2 adds the veto bypass, which is needed so that a
  trapped Run Away holder is not wrongly vetoed.
  - Should R2 also give `tryRunFromBattle` the source's always-escape, no-
    draw Run Away branch (`bm.c:4246-4251`)? That is a pre-existing gap,
    and the player's Rattata or Ponyta reaches it.
  - Recommendation: yes, as a separate commit in R2, with its flee text
    sourced first.
- **D5 (Liquid Ooze on drains).** Follow up separately with the Absorb
  family (`bs1.s:347`).
- **D6 (Whirlpool vs Dive).** Keep it in R3: it is a two-line change, and
  Dive is reachable from trainers.

## RNG notes

- **R1:** Leech Seed adds one accuracy draw per use (none against a
  semi-invulnerable target). Rapid Spin against a Ghost adds the missing
  discarded `% 100`. Curse, Nightmare and every end-of-turn case add
  none.
- **R2:** none. The veto prevents a run attempt's draw from happening at
  all, as in source.
- **R3:** every trap hit that lands or has no effect adds `% 100`; a
  landed hit that wraps adds `& 3`. These moves are admitted today, so
  **replays that contain a trap move diverge from its first use** (R4).
- Pre-existing and unchanged: the tracked plain-hit zero-byte roll gap,
  `gRandomTurnNumber`, and the battle-start tie draw (weather D3).

## Risks

- **R1. End-of-turn order** is the W0 order (weather proposal R1, fixed).
  The new cases slot into the per-battler list at their source positions.
  The double-KO cases (Leech Seed, Curse, wrap) depend on it.
- **R2. Mid-turn replacement timing** (weather proposal R2; tracked
  follow-up N1, `work/reviews/2026-10-13-conversion-memento-review.md:148`).
  New symptoms, because in source the replacement is already in the slot
  at end of turn:
  - The replacement of a mid-turn-fainted seeder would receive that
    turn's drain; the engine skips it (receiver at 0 HP).
  - The replacement of a fainted wrapper or seeded battler is unaffected
    (correct).
  - The replacement of a fainted escape preventer: no difference.

  Tests should pin the skip.
- **R3. The deferred team check** changes `faint` / `battleEnd` event
  spacing within one turn. Controller tests that assume `battleEnd`
  directly follows `faint` need checking.
- **R4. Trap-move RNG today.** Effect 42 is admitted as a plain hit and
  takes neither draw. Any seeded replay with a landed Wrap (a wild Ekans
  or Dratini, or a trainer's Bind) is already off by two draws per hit.
  R3 fixes this but will shift such replays.
- **R5. Ownership.** The controller and `main.lua` belong to another
  agent. R2 cannot land without the controller veto: the engine assert
  would otherwise surface as a crash on RUN while rooted. The R2 task
  needs a coordinated controller change, or an interim controller-side
  guard.
- **R6. A Leech Seed "receiver" is a slot.** A future doubles or
  Baton Pass port must keep it a slot id, not a battler reference.

## Surprising source behaviour (summary)

1. A Leech Seed knockout does **not** end the battle at once. There is no
   `checkteamslost` in `BattleScript_LeechSeedTurnDrain`, so the other
   battler's end-of-turn list keeps running, and a draw is possible.
2. The seed **outlives the seeder**. It is keyed to the seeder's slot, so
   a switched-in or replacement mon receives the heal.
3. A Leech Seed miss and an already-seeded target both print "X evaded
   the attack!". Leech Seed's miss pointer is its success label.
4. Rapid Spin removes **one** thing per use: the wrap if present,
   otherwise the seed.
5. Non-Ghost Curse fails only at −6 Speed **and** +6 Attack **and** +6
   Defense. Otherwise it plays and prints "won't go lower/higher" for the
   capped stats. It is exempt from Mist and Clear Body by move id.
6. Nightmare has no accuracy check and no type check, and in FRLG (unlike
   R/S) it silently ends at end of turn when the target is awake.
7. Run Away bypasses the trap veto for running but not for switching.
8. The trap draw `% 100` happens even on an immune target. A KO'd target
   costs no turn-count draw.
