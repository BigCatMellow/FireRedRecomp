# Phase 4 proposal: status leftovers (Tri Attack, Twineedle, Blaze Kick, Rest, Focus Energy)

- Status: `PROPOSAL — independently reviewed PASS WITH CORRECTIONS (applied)`
- Review: [2026-10-14 design review](../reviews/2026-10-14-status-leftovers-design-review.md)
  (F1-F8 applied below; see "Review corrections applied").
- Date: 2026-10-14
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
- Builds on: the primary status slices S1-S4 (status1, `StatusConditions`),
  the confusion/flinch slices C1-C2 (status2 volatiles) and their reviews.
- Lane: full relay (RNG-visible changes to three admitted families; one new
  battle-only volatile).

All five families are `B` in the [move-effect inventory](phase4-move-effect-inventory.md)
(rows 36, 37, 47, 77, 200). Three are already admitted as plain hits by the
positive-power fallback (`yes / B`); Rest and Focus Energy are rejected
(`no / B`). This proposal keeps all five: none needs state the engine lacks
(see "Dropped families").

Source paths below are relative to the pin. `bsc.c` is
`src/battle_script_commands.c`, `bs1.s` is `data/battle_scripts_1.s`.

## Source facts

### Move records (`src/data/battle_moves.h`)

| Move | Effect | Power | Type | Acc | Chance | Target | Flags |
| --- | --- | ---: | --- | ---: | ---: | --- | --- |
| Twineedle (41) `:536-547` | 77 | 25 | Bug | 100 | 20 | SELECTED | no contact |
| Focus Energy (116) `:1511-1522` | 47 | 0 | Normal | 0 | 0 | USER | |
| Rest (156) `:2031-2042` | 37 | 0 | Psychic | 0 | 0 | USER | |
| Tri Attack (161) `:2096-2107` | 36 | 80 | Normal | 100 | 20 | SELECTED | no contact |
| Blaze Kick (299) `:3890-3901` | 200 | 85 | Fire | 90 | 10 | SELECTED | contact |

The secondary chance is tested as `Random() % 100 <= chance` (`bsc.c:2789`).
A 20% move therefore fires on 21 of 100 values, and a 10% move on 11. The
engine's `BattleFormulas.secondaryEffectRoll` already uses this test.

### Shared: `seteffectwithchance` and `SetMoveEffect`

- `Cmd_seteffectwithchance` (`bsc.c:2774-2805`) draws `Random() % 100` as
  the first `&&` operand. The draw happens on every reached path, including
  a no-effect hit and an effect byte of 0. It then clears the effect byte
  and `multihitMoveEffect`. None of these moves is `CERTAIN` or 100%.
- `SetMoveEffect` (`bsc.c:2110-2147`) common guards, in order:
  - Shield Dust blocks any non-primary byte `<= 9` (`:2132-2134`).
  - Safeguard blocks `<= 7` (`:2136-2138`; not represented).
  - A target at 0 HP returns (`:2140-2143`).
  - Substitute returns (`:2145-2146`; not represented).

  All of these exits are silent.
- Status1 bytes (`:2148-2392`) on a non-primary, non-certain call:
  - Burn: a Fire type, Water Veil or any existing status1 fails silently
    (`:2218-2256`).
  - Freeze: an Ice type, any existing status1, sun (weather not
    represented) or Magma Armor fails silently. Success calls
    `CancelMultiTurnMoves` (`:2257-2271`).
  - Paralysis: Limber or any existing status1 fails silently. Gen 3 has no
    Electric immunity (`:2272-2301`).
  - Poison: Immunity, a Poison or Steel type or any existing status1 fails
    silently (`:2176-2217`).
  - Success: sets the bit, emits status1 and runs the effect's text script
    (`:2351-2375`). Burn, poison and paralysis also arm Synchronize
    (`:2376-2386`; not represented).
- The engine's `BattleEngine:applySecondaryStatus` (`BattleEngine.lua:1306`)
  already implements exactly this for `certain = false`.

### Crit stage (`Cmd_critcalc`, `bsc.c:1170-1206`)

```
critChance = 2 * (status2 & STATUS2_FOCUS_ENERGY != 0)
           + (effect == EFFECT_HIGH_CRITICAL) + (effect == EFFECT_SKY_ATTACK)
           + (effect == EFFECT_BLAZE_KICK) + (effect == EFFECT_POISON_TAIL)
           + Scope Lens + 2*(Lucky Punch Chansey) + 2*(Stick Farfetch'd)
```

- The stage is clamped to 4. The odds come from
  `sCriticalHitChance = {16, 8, 4, 3, 2}` (`bsc.c:588`).
- Focus Energy is worth +2 stages: 1/4 alone, 1/3 with a +1 move.
- `gCurrentMove` is read at every `critcalc` site. These are the ordinary
  hit, Explosion's pre-accuracy calc, each multi-hit iteration and each
  Triple Kick kick.
- The Battle Armor / Shell Armor check comes before the `Random()` term in
  the `&&` chain (`:1196-1199`). This is a pre-existing, tracked RNG gap
  (S2 review F5); the engine has no such check.

### 36 Tri Attack

- Script (`bs1.s:731-733`): `setmoveeffect MOVE_EFFECT_TRI_ATTACK`, then
  the ordinary `BattleScript_EffectHit` (`:239-268`).
- `MOVE_EFFECT_TRI_ATTACK = 9` (`include/constants/battle.h:230`). It goes
  through the common guards: Shield Dust (9 `<= 9`) blocks it before any
  draw. Safeguard (9 `> 7`) does not block the outer call, but it would
  block the inner one. A KO'd target returns before any draw.
- `sStatusFlagsForMoveEffects[9]` is 0 (`bsc.c:590-607`), so the status2
  test at `:2396` passes. The switch then reaches the TRI_ATTACK case
  (`bsc.c:2466-2475`):
  - If the target has any status1, it skips silently. **No draw.**
  - Otherwise the effect byte becomes `Random() % 3 + 3`: 3 burn,
    4 freeze, 5 paralysis (`battle.h:223-225`). The function then recurses
    with `SetMoveEffect(FALSE, 0)`.
- The recursive call re-runs the common guards (all pass), then the chosen
  status1 case with `certain = 0`:
  - Ice types and Magma Armor resist freeze silently.
  - Fire types and Water Veil resist burn silently.
  - Limber resists paralysis silently.

  Each of these failures has already spent the `% 3` draw. No ability text
  is ever printed, and the sleep draw is never reached (the byte is never 1).
- Texts are the existing ones: was burned (`battle_message.c:94`), was
  frozen solid (`:98`), is paralyzed / may be unable to move (`:104`).
- A freeze calls `CancelMultiTurnMoves` on the target.
- Tri Attack is Normal, so it never triggers the Fire defrost at move end.
- RNG for a landed hit: accuracy, crit, damage random, `% 100`, then
  `% 3` only if the roll passed, the target is alive, it has no Shield Dust
  and it has no status1.
- A Ghost target (no effect): accuracy, crit, random, `% 100` (discarded).
- A miss: accuracy only (`BattleScript_PrintMoveMissed`).

### 77 Twineedle

- Script (`bs1.s:1072-1080`): `attackcanceler`, `accuracycheck` (a miss
  goes to `PrintMoveMissed`: "used", PP spent, missed, no effect roll),
  `setbyte sMULTIHIT_EFFECT, MOVE_EFFECT_POISON`, `attackstring`,
  `ppreduce`, `setmultihitcounter 2` (no RNG), `initmultihitstring`, then
  `BattleScript_MultiHitLoop`.
- The loop runs at `bs1.s:613-641`. Each iteration does:
  1. Check `jumpifhasnohp` for the attacker (to End) and the target (to
     PrintStrings).
  2. Run `movevaluescleanup`. This clears the effect byte
     (`bsc.c:3469-3478`).
  3. Run `copybyte cEFFECT_CHOOSER, sMULTIHIT_EFFECT`.
     `cEFFECT_CHOOSER` is `gBattleCommunication + MOVE_EFFECT_BYTE`
     (`include/constants/battle_script_commands.h:43`), so this puts POISON
     back.
  4. Run `critcalc`, `damagecalc`, `typecalc`, then
     `jumpifmovehadnoeffect`, then `adjustnormaldamage`.
  5. HP update, crit message, `moveendto MOVEEND_NEXT_TARGET`,
     `decrementmultihit`.
- No per-hit command applies the effect byte: moveend states 0-15 do not
  read it (`bsc.c:4056-4330`).
- After the loop (`:642-655`):
  1. `resultmessage`.
  2. `jumpifmovehadnoeffect` to End. Otherwise "Hit {n} time(s)!"
     (`battle_message.c:82`).
  3. At `BattleScript_MultiHitEnd`: **one** `seteffectwithchance`, then
     `tryfaintmon BS_TARGET`.
- **Correction to the brief: the poison chance is rolled once per use,
  after both hits, not once per hit.** That one roll still runs when the
  first hit KOs the target. The loop exits at `jumpifhasnohp BS_TARGET`,
  "Hit 1 time(s)!" is printed, the roll is drawn, and `SetMoveEffect`
  returns on the 0-HP guard. The faint text follows, from `tryfaintmon`
  after the roll.
- Shield Dust (byte 2 `<= 9`) blocks the poison silently after the roll.
  Immunity, Poison or Steel types and an existing status1 also fail
  silently.
- Bug has no 0x matchup in the Gen 3 chart, so the no-effect branch is
  unreachable. Wonder Guard is not represented. If the branch were reached,
  it would skip the count text and still draw the roll.
- Twineedle has no contact flag, so contact abilities never trigger.
- RNG for a landed use: accuracy, then (crit, random) × hits, then
  `% 100`. Both hits always land unless the target faints.

### 200 Blaze Kick

- Dispatch: `bs1.s:224` points effect 200 at `BattleScript_EffectBurnHit`
  (`:364-366`: `setmoveeffect MOVE_EFFECT_BURN`, then EffectHit). This is
  the same script as Ember and the other burn-hit moves.
- The only difference is in `Cmd_critcalc`: `+1` stage for
  `EFFECT_BLAZE_KICK` (`bsc.c:1187`).
- The burn guards are the burn rules above. Fire types and Water Veil
  resist silently; Shield Dust blocks.
- Blaze Kick is a Fire move, so `MOVEEND_DEFROST` (`bsc.c:4103-4116`)
  thaws a frozen target that is still alive after the hit. The burn roll
  cannot burn a frozen target, because it already has a status. The thaw
  comes after the roll.
- Blaze Kick makes contact. Static, Flame Body and the other contact
  abilities are not represented; this is an existing S2 limit.
- RNG for a landed hit: accuracy, crit (stage 1), random, `% 100`. Same
  for a no-effect hit. This assumes the target has no Flash Fire (see
  Known limits, review F4).

### 37 Rest

- Script (`bs1.s:735-759`): `attackcanceler`, `attackstring`, `ppreduce`.
  There is no accuracycheck and no RNG. Then:
  1. `jumpifstatus BS_ATTACKER, STATUS1_SLEEP` goes to
     `BattleScript_RestIsAlreadyAsleep`: "X is already asleep!"
     (`STRINGID_PKMNALREADYASLEEP2`, `battle_message.c:86`, attacker name).
  2. `jumpifcantmakeasleep` goes to `BattleScript_RestCantSleep`
     (`bsc.c:6546-6566`). First comes `UproarWakeUpCheck`. Then, if
     `gBattlerTarget` has Insomnia or Vital Spirit, the script prints
     `gUproarAwakeStringIds[B_MSG_STAYED_AWAKE_USING]`: "X stayed awake
     using its {ability}!" (`battle_message.c:174`, `:1003-1007`).
     `gBattlerTarget` is the user here: for a `MOVE_TARGET_USER` move every
     singles controller sends the user as the target
     (`src/battle_controller_player.c:460-461`;
     `src/battle_controller_opponent.c:1370-1371`, `:1393-1394`), and
     `HandleAction_UseMove` copies it (`src/battle_main.c:4114-4116`).
  3. `trysetrest BattleScript_AlreadyAtFullHp` (`bsc.c:6480-6502`):
     - At `hp == maxHP` it jumps to "X's HP is full!"
       (`bs1.s:2038-2042`, `battle_message.c:125`).
     - Otherwise it chooses the text from `status1 & (u8)~STATUS1_SLEEP`,
       i.e. bits 3-7 (poison, burn, freeze, paralysis, toxic): nonzero
       gives "X slept and became healthy!" (`B_MSG_REST_STATUSED`, `:134`),
       zero gives "X went to sleep!" (`B_MSG_REST`, `:133`;
       table `:973-977`).
     - It then **overwrites** `status1 = STATUS1_SLEEP_TURN(3)`. This
       clears every other status bit and the toxic counter (bits 8-11), and
       emits status1. `trysetrest` does not call `CancelMultiTurnMoves`.
  4. `BattleScript_PresentHealTarget` (`bs1.s:2028-2036`):
     `gBattleMoveDamage = -maxHP`. `datahpupdate` raises HP and clamps it
     to maxHP (`bsc.c:1789-1794`). It then prints "X regained health!"
     (`battle_message.c:124`).
- The checks run in that order. A full-HP user with Insomnia therefore
  prints "stayed awake", and a statused user at full HP prints "HP is full!"
  and keeps its status.
- Confusion (status2) is not cured.
- Sleep length: the sleep canceller decrements before testing
  (`src/battle_util.c:1266-1300`). With 3 turns, the next two attempts are
  "fast asleep" and the third wakes and acts. With Early Bird (not
  represented) the user sleeps one turn.
- Reachability:
  - The "already asleep" branch is unreachable in this engine. A sleeping
    user is cancelled by `CANCELLER_ASLEEP` before the script runs, unless
    the move is Snore or Sleep Talk. Sleep Talk calling Rest is not
    represented (effect 97 is blocked).
  - The Uproar branch is unreachable: Uproar state is not represented
    (effect 159 runs as a plain hit, so `UproarWakeUpCheck` never fires;
    review F7).

### 47 Focus Energy

- Script (`bs1.s:884-894`): `attackcanceler`, `attackstring`, `ppreduce`.
  There is no accuracycheck and no RNG. Then:
  1. `jumpifstatus2 BS_ATTACKER, STATUS2_FOCUS_ENERGY` goes to
     `BattleScript_ButItFailed` ("But it failed!", `battle_message.c:336`).
  2. `setfocusenergy` (`bsc.c:7383-7396`) sets the bit and selects
     `B_MSG_GETTING_PUMPED`. Its own fail branch cannot be reached after
     the script's check.
  3. "X is getting pumped!" (`gBattleText_GetPumped`,
     `battle_message.c:153`; table `:1058-1062`).
- Lifecycle: `STATUS2_FOCUS_ENERGY` is bit 20 (`battle.h:120`).
  - It is cleared on faint, because `FaintClearSetData` zeroes status2
    (`src/battle_main.c:2433-2441`).
  - It is cleared on switch-in except after Baton Pass, through
    `SwitchInClearSetData` (`:2329`; Baton Pass is not represented).
  - It is never persisted. It does not expire and no move removes it.
- Effect: +2 crit stages at every `critcalc` (see above).

### AI (`data/battle_ai_scripts.s`)

- `AI_CheckBadMove` dispatches EFFECT_FOCUS_ENERGY to `AI_CBM_FocusEnergy`
  (`:131`, `:386-388`): `if_status2 AI_USER, STATUS2_FOCUS_ENERGY` gives −10.
  The port now has `alwaysNoPenalty` with the note "status2 unmodeled"
  (`src/core/AICheckBadMove.lua:532`).
- AI_CheckBadMove has no entry for effects 36, 37, 77 or 200. They fall to
  the trailing `end` (zero penalty), which is already the port's default.
- No discouraged-power entry applies to these effects
  (`src/battle_ai_script_commands.c:245-260`).
- `AI_CV_Rest` (`:681`, `:1476-`) and `AI_CV_HighCrit` for Blaze Kick
  (`:766`, `:1535-1547`) are CheckViability terms. These are out of scope:
  `TrainerAI` refuses those flag sets, and `EarlyRivalAI` is bounded to its
  own moves.
- Rest's `AI_HPAware` listing (`:3001`) is likewise out of scope.

## Design

### Crit stage helper (H1)

- Add one helper, `BattleEngine:critStageFor(attacker, move)`. It returns
  `2 * (attacker.focusEnergy and 1 or 0)`, plus 1 for effect 43, 75, 200 or
  209. `BattleFormulas.critRoll` already clamps the result to 4.
- Use the helper at all four `critcalc` sites:
  - the ordinary hit (`BattleEngine.lua:2300-2303`, replacing the inline
    43/209/75 test);
  - Explosion (`:1690`);
  - `resolveMultiHit` (`:2724`);
  - `resolveTripleKick` (`:2783`).
- Without Focus Energy, every existing site gives the same stage as today.
  Blaze Kick changes from 0 to 1.

### Tri Attack (36)

- The admitted plain hit gains the trailing secondary.
- After the landed hit, at the same point as `STATUS_HIT_MOVES`
  (`:2494-2502`):
  1. Draw `secondaryEffectRoll(rng, 20)`.
  2. If it passes, run the outer guards: Shield Dust, then target HP > 0,
     then status1 == 0. Any failure is silent and draws nothing more.
     The status1 guard tests the whole word, `(defender.status or 0) ~= 0`
     skips, mirroring `if (status1)` (`bsc.c:2467`) and
     `StatusConditions.canApply`. It must not use `StatusConditions.hasAny`,
     which masks the toxic counter, so a counter-only word also skips the
     `% 3` (review F2).
  3. Otherwise `kind = ({"burn","freeze","paralysis"})[rng % 3 + 1]`.
  4. Then call `applySecondaryStatus(defenderSide, kind, false, events)`.
     It repeats the Shield Dust and HP checks, as the source recursion
     does. It also handles the ability, type and Magma Armor failures
     silently and runs `CancelMultiTurnMoves` on freeze.
- Add 36 to the no-effect roll list (`:2366-2378`) so a Ghost target still
  draws `% 100`.

### Twineedle (77)

- Add `[77] = { fixed = 2, statusKind = "poison" }` to `MULTI_HIT_MOVES`
  (`:889`). This ends the current single-hit fallback.
- In `resolveMultiHit`, an entry with `statusKind` follows the source tail.
  This is the same shape as `resolveTripleKick`:
  1. A target at 0 HP **breaks** the loop instead of calling `checkFaint`.
  2. The `multiHit` event (hits landed) comes next.
  3. Then one `secondaryEffectRoll(rng, 20)`. If it passes, call
     `applySecondaryStatus(defenderSide, "poison", false, events)`. This
     handles Shield Dust, 0 HP, Immunity, the Poison/Steel types and an
     existing status, all silently.
  4. The method then returns. The caller's ordinary defender faint check
     emits `faint` after `multiHit` and after any poison text.
- The no-effect branch also draws the roll before it returns. This branch
  is unreachable for Bug.
- Entries without `statusKind` (29, 44) are unchanged; see Risks.

### Blaze Kick (200)

- Add `[200] = "burn"` to `STATUS_HIT_MOVES`. This covers the roll, the
  burn guards, the no-effect draw through the existing list, and the
  existing move-end Fire defrost.
- The +1 crit stage comes from H1.

### Rest (37)

- `supportsMove`: admit effect 37 with power 0 and target `MOVE_TARGET_USER`
  (move 156 only, matching the RESTORE_HP admission style).
- Add an early branch in `resolveMoveCore` beside Refresh (`:1797`). It runs
  after `useMove`, has no accuracy check and spends one PP. In order:
  1. If `StatusConditions.isAsleep(attacker.status)`, emit
     `statusAlready{side=attacker, kind="sleep"}` and stop. This is
     defensive; see Source facts.
  2. If the ability is Insomnia or Vital Spirit, emit
     `stayedAwake{side=attacker, ability}` and stop.
  3. If `hp == maxHP`, emit `restoreHPFull{side=attacker}` and stop.
  4. Set `statused` from bits 3-7, using the existing `StatusConditions`
     predicates (`isPoisoned`, `isBurned`, `isFrozen`, `isParalyzed`,
     `isBadlyPoisoned`), so no `bit` library is needed. Then set
     `attacker.status = StatusConditions.withSleepTurns(0, 3)`. Emit
     `restSlept{side, statused}`.
  5. Set `hp = maxHP` and emit
     `restoreHP{side, beforeHP, hpRemaining, amount}`.
- Do not call `cancelMultiTurnMoves`. No lock can be active: a locked user
  cannot select Rest.
- The status persists through `BattlePartyBridge` as sleep with 3 turns.
  The toxic counter is gone; persistence masks it anyway.
- The existing cancellers, Snore and the end-of-turn phase then apply
  unchanged. A Rest user takes no poison or burn damage at that turn's end,
  because the status was overwritten.

### Focus Energy (47)

- Battler state: add `focusEnergy = false` to `makeBattler` (`:924-960`),
  next to `confusionTurns` and `flinched`.
  - Battle-only and never persisted.
  - Cleared in `recordFaint` (`:1061-1081`), which mirrors
    `FaintClearSetData`.
  - Switch-ins are fresh objects, so they start clear.
- `supportsMove`: admit effect 47 with power 0 and target USER.
- Early branch in `resolveMoveCore`: spend one PP. If `focusEnergy` is
  already set, emit `moveFailed`; otherwise set it and emit
  `focusEnergy{side}`.
- AI: `AICheckBadMove` row 47 changes to `user.focusEnergy and -10 or 0`
  (AI_CBM_FocusEnergy).

### Presentation (`BattleSceneController`)

- New `restSlept`: "X went\nto sleep!" (`:133`), or "X slept and\nbecame
  healthy!" (`:134`) when `statused`.
- New `focusEnergy`: "X is getting\npumped!" (`:153`).
- Reused: `restoreHP` (`:124`), `restoreHPFull` (`:125`), `stayedAwake`
  (`:174`), `statusAlready` sleep (`:85`/`:86` render identically for the
  user), `moveFailed` (`:336`), `statusApplied` burn/freeze/paralysis/poison,
  and `multiHit` (`:82`).

## Slices

| Slice | Content | Unlocks |
| --- | --- | --- |
| L1 | H1 crit-stage helper (no Focus Energy term yet); Tri Attack secondary with the `% 3` choice; Twineedle 2 hits plus the single trailing poison roll and the KO tail; Blaze Kick in `STATUS_HIT_MOVES`; no-effect roll list; inventory rows 36, 77, 200 → R | 3 moves (already admitted) |
| L2 | `focusEnergy` volatile with its faint clear; the H1 Focus Energy term at all four crit sites; Focus Energy and Rest scripts; `supportsMove`; AI_CBM_FocusEnergy; the two new events and texts; inventory rows 37, 47 → R | 2 moves (newly admitted) |

Comment touch lists (review F5). These comments go stale and are updated
with the behaviour:

- L1:
  - the `BattleEngine.lua` header family notes for the status-hit
    families (`:252`) and the multi-hit family (`:363`, `:389`);
  - `resolveMultiHit`'s doc comment (`:2668-2708`): Twineedle has no
    in-loop `checkFaint`, a trailing roll, and `hits` = hits landed;
  - the `MULTI_HIT_MOVES` comment (`:875-888`), which documents only
    29/44;
  - `BattleSceneController.lua:335-341`, whose `multiHit` comment says the
    event is emitted only on completion (false for Twineedle and Triple
    Kick).
- L2:
  - the `BattleEngine.lua` header event list (`:60-80`): `restSlept` and
    `focusEnergy`;
  - the `AICheckBadMove.lua:532` comment "status2 unmodeled".

Expected inventory movement (relative to the current 283/71; the inventory
test is authoritative):

- L1 moves three positive-power records from blocked to represented, with
  no admission change.
- L2 admits two zero-power records. The result is 285 admitted and 69
  rejected.
- The "admitted, semantically uncovered" list loses 36, 77 and 200.

## Verification plan

- Source-derived RNG oracles per family:
  - Tri Attack: landed with each of the three `% 3` values; roll failed;
    statused target (no `% 3`); Shield Dust (no `% 3`); KO (no `% 3`);
    Ghost target (`% 100` drawn).
  - Twineedle: two hits plus the roll; a KO on hit 1 gives count 1, the
    roll, then the faint, in that order; Shield Dust, Immunity and a
    Poison-type target each fail silently. The KO oracle must drive
    `runTurn` (or call `checkFaint` explicitly), because the faint is
    emitted by the caller, not inside `resolveMultiHit`; a direct
    `resolveMove` call sees no `faint` at all (review F6).
  - Blaze Kick: the crit at stage 1 (`% 8`); with Focus Energy, stage 3
    (`% 3`).
- Rest branch matrix:
  - asleep (defensive);
  - Insomnia and Vital Spirit, including at full HP;
  - full HP while statused (status kept);
  - statused and not full: "healthy" text, toxic counter cleared;
  - the 3-turn sleep: two "fast asleep" turns, then wakes and acts;
  - a party round trip of sleep 3.
- Focus Energy:
  - the second use fails;
  - the volatile is cleared on faint and absent after a switch;
  - the stage is applied at the Explosion, multi-hit and Triple Kick
    sites;
  - the AI −10.
- Controller text order through the real engine, ROM record fixtures for
  moves 41, 116, 156, 161 and 299, the no-ROM suite, the repository
  checker, and an independent review.

## Risks

- **RNG**
  - Tri Attack, Twineedle and Blaze Kick each gain the `% 100` draw on
    every landed or no-effect hit. This closes the tracked plain-hit gap
    for these families. Tri Attack also adds `% 3` when its roll succeeds.
  - Seeded traces with these moves diverge after their first hit. No
    committed replay is known to contain them; L1 must confirm this, as C2
    did.
- **Twineedle behaviour change.** Today it resolves as a single 25-power
  hit, and L1 makes it two hits. Damage totals in any existing fixture
  that uses it will change.
- **Pre-existing multi-hit divergence (review F1).**
  - `resolveMultiHit` calls `checkFaint` after every landed hit. On **any
    KO during the sequence (including the final hit)** it therefore emits
    `faint` and omits the hit-count event, and
    `tests/battle_engine_test.lua:1014-1015` asserts this. A Double Kick
    whose second hit KOs, or a Fury Attack whose rolled final hit KOs, also
    loses "Hit N time(s)!".
  - Source prints "Hit N time(s)!" before the faint (`bs1.s:613-655`): the
    loop exits through `decrementmultihit`, then `goto
    BattleScript_MultiHitPrintStrings` (`:640-641`), which prints the count
    (`:649`) before `tryfaintmon` (`:653`).
  - The old comments (`BattleEngine.lua:2696-2707`,
    `BattleSceneController.lua:335-341`) justified the omission because the
    faint "already ends the battle". That is false when `hasReplacement`
    returns true: the faint leaves a forced switch pending instead.
  - Families 29/44 also skip the trailing `seteffectwithchance` `% 100`
    draw (byte 0, but still drawn) on both the landed-hit and the
    no-effect paths (`bs1.s:624` to `:651-652`). The 7-draw assertion at
    `tests/battle_engine_test.lua:993-994` locks in the landed-hit
    omission. This is the tracked plain-hit gap.
  - L1 fixes the order for Twineedle only, so Twineedle and Double Kick
    differ in event order until the follow-up below changes those tests
    on purpose. It does not ride along in L1.
- **Crit probability changes.** Blaze Kick crits about twice as often, and
  Focus Energy changes every later crit for that battler.
- **The admission change** lets AI and wild foes select Rest and Focus
  Energy. Today `resolveMoveCore` would raise on them.

## Follow-up: multi-hit KO tail for 29/44 (separate, not L1)

Recorded from review F1 as a separate fast-lane correction. It must cover:

- a KO on the last hit (Double Kick's second hit, a 2-5 move's rolled
  final hit) as well as an earlier KO: "Hit N time(s)!" before the faint;
- a KO with a replacement available (`hasReplacement` true): count, then
  faint, then `forcedSwitchNeeded`;
- the trailing `% 100` draw for 29/44 on landed and no-effect paths;
- intentional updates to `tests/battle_engine_test.lua:993-994` and
  `:1014-1015`, and any controller text test that depends on the old
  shape.

## Known limits

- Not represented:
  - Battle Armor / Shell Armor skipping the crit draw (an existing gap,
    S2 F5);
  - Scope Lens, Lucky Punch and Stick (no held items);
  - Serene Grace doubling;
  - Synchronize;
  - contact abilities on Blaze Kick;
  - Flash Fire absorbing Blaze Kick (and every Fire move) in
    `attackcanceler` (`bsc.c:925`; `battle_util.c:1918-1924`) before
    accuracy, so source draws none of accuracy, crit, random, `% 100`
    against it (an existing gap, review F4);
  - Safeguard and Substitute;
  - sun blocking Tri Attack's freeze;
  - Wonder Guard on Twineedle.
- Rest:
  - Uproar and Sleep Talk calling Rest are unreachable. The "already
    asleep" branch is defensive only.
  - Early Bird is not represented, so a Rest user sleeps two turns instead
    of one.
- Focus Energy is not passed by Baton Pass, which is not represented.
- Focus Energy's other setters are not represented (review F3): the Lansat
  Berry (`HOLD_EFFECT_CRITICAL_UP`, `battle_util.c:2681-2688`) and the Dire
  Hit battle item (`pokemon.c:4090-4092`, `:4611`). A future held-item or
  in-battle bag slice must set `focusEnergy`.
- AI_CheckViability (`AI_CV_Rest`, `AI_CV_HighCrit`) and AI_HPAware are out
  of scope.

## Dropped families

None. Each family's state already exists or is one bool:

- Tri Attack, Twineedle and Blaze Kick use status1, `applySecondaryStatus`
  and the multi-hit loop.
- Rest uses status1 sleep, the sleep canceller and the ability field.
- Focus Energy needs one battle-only status2 bit. It is modelled exactly
  like `flinched`, with the existing construction and faint-clear hooks,
  and has no timer, persistence or cross-battler link.

A family would have been dropped if it needed Uproar, Baton Pass or
held-item state. None of these five does in its reachable paths.

## Review corrections applied

[2026-10-14 design review](../reviews/2026-10-14-status-leftovers-design-review.md),
PASS WITH CORRECTIONS:

- F1 (Medium): the Risks bullet now reads "any KO during the sequence
  (including the final hit)", corrects the "ends the battle" rationale and
  names the 29/44 trailing draw; the fix is recorded as the separate
  follow-up above. L1 changes only Twineedle's order.
- F2 (Low): the Tri Attack status1 guard is the whole word,
  `(defender.status or 0) ~= 0`, not `hasAny`.
- F3, F4 (Low): Lansat Berry / Dire Hit and Flash Fire added to Known
  limits.
- F5 (Low): comment touch lists added under Slices.
- F6 (Info): the Twineedle KO oracle drives `runTurn`.
- F7, F8 (Info): Uproar wording; `bsc.c:1187` and `BattleEngine.lua:1797`.

## L1 implementation notes

Implemented by [task L1](../tasks/phase4-status-leftovers-l1.md).

- H1 is `BattleEngine:critStageFor(attacker, move)`, backed by the table
  `BattleEngine.CRIT_STAGE_EFFECTS` (43, 75, 200, 209 → 1). `attacker` is
  unused until L2 adds the Focus Energy term.
- Twineedle is `MULTI_HIT_MOVES[77] = { fixed = 2, statusKind = "poison" }`.
  `resolveMultiHit` selects the source tail on `statusKind`; `multiHit`
  carries hits landed. On the (unreachable for Bug) no-effect exit the
  trailing roll is drawn, as designed.
- Tri Attack's block sits directly after the `STATUS_HIT_MOVES` block, and
  effect 36 is in the no-effect roll list.
- No committed replay uses moves 41, 161 or 299 (the runtime replays are
  the house exit and Route 1 wild battles).
