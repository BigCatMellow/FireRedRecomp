# Phase 4 proposal: locked multi-turn moves (charge and recharge)

- Status: `PROPOSAL — independently reviewed PASS WITH CORRECTIONS (applied)`
- Review: [2026-10-14 design review](../reviews/2026-10-14-multiturn-design-review.md)
- Date: 2026-10-14
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
- Lane: full relay (new cross-turn battle state and action-selection change).

This proposes the shared "locked move" machinery and its first slice: the
recharge family (Hyper Beam) and the two-turn charge families that need no
semi-invulnerability or weather. Semi-invulnerable moves (Fly/Dig/Dive/
Bounce), Rampage, Uproar, Rollout, Bide and Fury Cutter are later slices.

## Source facts

### Locking

- `STATUS2_MULTIPLETURNS` (bit 12) and `STATUS2_RECHARGE` (bit 22)
  (`include/constants/battle.h:115,122`); `gLockedMoves[battler]`.
- Action selection (`src/battle_main.c:3125-3130`): a battler with either bit
  does not choose: its action is `B_ACTION_USE_MOVE` with no menu (and, for
  the foe, no AI script, so no AI RNG); run, items and switching are not
  offered.
- Move choice (`:3989-3992`): such a battler uses `gLockedMoves`.
- `CancelMultiTurnMoves` (`src/battle_util.c:203-214`) clears
  MULTIPLETURNS (and lock-confuse, uproar, bide, semi-invulnerable, rollout,
  fury cutter). Callers relevant here: sleep and freeze application
  (`SetMoveEffect`), the flinch canceller (`:1364`), the recharge canceller,
  the paralysis script (`data/battle_scripts_1.s:3717`), the confusion
  self-hit script (`:3742`), and end of turn for a sleeping battler
  (`src/battle_main.c:2941`). Faint clears status2.

### Recharge (EFFECT_RECHARGE 80: Hyper Beam, Blast Burn, Hydro Cannon, Frenzy Plant)

- Script (`data/battle_scripts_1.s:1107-1111`): accuracycheck first (a miss
  prints "used", spends PP and misses, no recharge), then
  `setmoveeffect RECHARGE | AFFECTS_USER | CERTAIN` and the ordinary hit.
- `seteffectwithchance` CERTAIN branch: applied when the move had an effect
  (no roll), including when the hit KOs the target (the effect battler is
  the attacker); a no-effect hit falls to the rolling branch (`Random()`
  drawn, nothing applied).
- `SetMoveEffect` (`src/battle_script_commands.c:2600-2605`): sets
  RECHARGE, `rechargeTimer = 2`, `gLockedMoves`.
- Next turn: no action choice; `rechargeTimer` decremented at the turn's
  action start (`src/battle_main.c:3641-3646`); `CANCELLER_RECHARGE`
  (`src/battle_util.c:1349-1358`, between Truant and Flinch, after
  sleep/freeze) clears it and prints "X must recharge!" (`:185` in
  `battle_message.c`), move not used, no PP.

### Two-turn charge (39 Razor Wind, 75 Sky Attack, 145 Skull Bash, 151 Solar Beam)

- Turn 1 (`BattleScriptFirstChargingTurn`, `data/battle_scripts_1.s
  :794-806`): attackcanceler, **no attackstring** (empty string), ppreduce,
  `MOVE_EFFECT_CHARGING` (sets MULTIPLETURNS, `gLockedMoves`), the turn-1
  text: Razor Wind "X whipped up a whirlwind!", Solar Beam "X took in
  sunlight!", Skull Bash "X lowered its head!", Sky Attack "X is glowing!"
  (`battle_message.c:135-138`). Skull Bash then raises the user's DEF +1
  (silent at +6, `:1812-1818`).
- Turn 2 (`BattleScript_TwoTurnMovesSecondTurn`, `:784-792`): attackcanceler,
  clear MULTIPLETURNS, **no PP**, then the ordinary hit from accuracycheck
  (attackstring "X used ..." printed now). Sky Attack adds a 30% flinch
  (its `secondaryEffectChance`) and one crit stage (`Cmd_critcalc
  :1184-1188`).
- Solar Beam (`:1899-1913`): without sun it always charges; in sun it fires
  on turn 1. Weather is unmodeled, so it always charges (limit).
- A canceller that stops turn 2 (flinch, full paralysis, confusion self-hit)
  cancels the lock; a sleeping battler's lock ends at end of turn; freeze
  keeps the lock (CANCELLER_FROZEN does not cancel).

## Design

- Battler state (battle-only, cleared on faint, fresh on switch-in):
  `lockedSlot` (move slot), `charging` (MULTIPLETURNS), `recharging` with
  `rechargeTimer`.
- `BattleEngine:isLocked(side)` for callers; `runTurn` ignores a locked
  side's chosen action and uses the locked slot. The controller skips the
  action menu for a locked player and skips `chooseFoeMove` for a locked foe
  (no AI RNG). main.lua is unchanged: it already calls the controller.
- Cancellers: recharge after freeze and before flinch; `cancelMultiTurn`
  helper called at the source points above.
- Charge turn emits `chargeTurn {side, move}` instead of `useMove`; turn 2
  emits `useMove` and skips PP. Recharge emits `mustRecharge`.
- AI: AI_CheckBadMove routes 39/80/145 to AI_CBM_HighRiskForDamage
  (`data/battle_ai_scripts.s:128,151,183`), already ported; AI_CheckViability
  terms out of scope; EarlyRivalAI rejects these effects loudly.

## Slices

| Slice | Content |
| --- | --- |
| M1 | lock state, controller skip, recharge family (80), charge families 39/75/145/151 |
| M2 | semi-invulnerable (155) with the hits-through and double-damage moves |
| M3 | Rampage (27) and later locked families |

## Risks

- Controller change: action selection must not prompt or draw AI RNG for a
  locked side; tests through the controller.
- Seeded replays: these families stop being one-turn plain hits.

## Corrections from the design review (applied)

- Recharge timer: source decrements in `TurnValuesCleanUp` at the end of
  every turn (`src/battle_main.c:2970`); the engine decrements at the next
  turn start and treats a timer of 1 as unlocked (`isLocked`), which is
  equivalent.
- The recharge canceller stops the chain (`effect = 1`): no confusion
  decrement or confusion/paralysis draw on a recharge turn; a wake/thaw that
  turn prints before "must recharge!"; staying asleep/frozen prints nothing
  and the recharge lapses by the timer.
- Cancel points: flinch canceller (`src/battle_util.c:1366`), paralysis via
  its script (`data/battle_scripts_1.s:3717`; the C call is commented out),
  confusion self-hit script (`:3742`), sleep and freeze application
  (`src/battle_script_commands.c:2269` for freeze), the sleeping battler at
  end of turn (`src/battle_main.c:2941-2942`); Protect on turn 2 also cancels
  (unmodeled). A frozen charger keeps its lock only when already frozen
  before charging; applying freeze cancels it. CancelMultiTurnMoves never
  clears recharge.
- Locked turns bypass the Struggle/noValidMoves and 0-PP checks
  (`src/battle_script_commands.c:838-839`); a locked side's action is the
  locked move in every runTurn branch (switch/capture/run never execute for
  a locked player; a locked foe still uses its move after a player switch).
- Controller entry points: auto-run at the end of `advanceMessage` and the
  empty-list path of `_setMessages`; no `chooseFoeMove` call for a locked foe.
- Turn 1 runs every canceller first (a stop spends no PP and sets no lock);
  the charge lock clears after the turn-2 cancellers; a charge lock survives
  the opponent's faint/switch; recharge applies before the faint checks.
- Solar Beam "always charges" is exact while no weather exists; a weather
  slice must note sun spends PP before the canceller.

## Slice M2 addendum: semi-invulnerable moves

- Review: [M2 design review](../reviews/2026-10-14-multiturn-m2-design-review.md)
  (PASS WITH CORRECTIONS, applied below and in the implementation).

Families: 155 Semi-Invulnerable (Fly 19, Dig 91, Dive 291, Bounce 340), and
the moves that reach a semi-invulnerable target: 149 Gust, 152 Thunder,
147 Earthquake, 207 Sky Uppercut (newly represented), plus the already
represented Twister (146), Magnitude (126) and Surf (57, effect 0).

Source facts:

- `BattleScript_EffectSemiInvulnerable` (`data/battle_scripts_1.s
  :1969-2008`). Turn 1: `BattleScriptFirstChargingTurn` (no attackstring,
  ppreduce, lock, text "flew up high!" / "dug a hole!" / "hid underwater!" /
  "sprang up!", `battle_message.c:139-142`), then `setsemiinvulnerablebit`
  (`src/battle_script_commands.c:8618-8634`: Fly/Bounce ON_AIR, Dig
  UNDERGROUND, Dive UNDERWATER). Turn 2: attackcanceler, clear the lock,
  NO_PPDEDUCT, Bounce adds a 30% paralysis secondary, accuracycheck (a miss
  clears the bit and goes to PrintMoveMissed: "used" + missed), clear the
  bit, then the hit from attackstring.
- `AccuracyCalcHelper` (`:958-1001`) and the NO_ACC_CALC path (`:1020-1028`):
  every `accuracycheck` against an ON_AIR / UNDERGROUND / UNDERWATER target
  misses without RNG unless the move set the matching IGNORE hitmarker. It
  runs before the ALWAYS_HIT/Vital Throw short-circuit, so Swift and Vital
  Throw miss too. OHKO and Pain Split (NO_ACC_CALC_CHECK_LOCK_ON) jump to their
  failure label without MISSED (`:1022-1025`): "But it failed!", PP spent, no
  RNG.
  Scripts with no accuracycheck (self moves, Psych Up, Memento) are
  unaffected.
- Hit-through: Gust and Twister (ON_AIR: IGNORE + damage x2, `:1822-1828,
  1888-1891`), Thunder and Sky Uppercut (ON_AIR: IGNORE, no double,
  `:1916-1919, 2704-2706`; Thunder also a 30% paralysis secondary),
  Earthquake and Magnitude (UNDERGROUND: IGNORE + x2, `:1830-1858`), Surf
  (UNDERWATER: IGNORE + x2, `:239-243`). Whirlpool also ignores underwater
  but its trap family stays blocked.
- `CancelMultiTurnMoves` clears the semi-invulnerable bits; faint and
  switch-in clear them too.

Design: `semiInvulnerable` field ("air" / "underground" / "underwater"),
set on the semi-invulnerable charge turn and cleared at the turn-2 accuracy
check, by `cancelMultiTurnMoves`, and on faint. One engine helper decides a
semi-invulnerable miss before any accuracy roll at every site whose source
script has an `accuracycheck` (the main hit path including ALWAYS_HIT, Vital
Throw, OHKO and Pain Split, Explosion after its crit/damage draws, Triple
Kick per kick, the primary status / confuse / Swagger handlers); the
damage multiplier block gains the x2 cases.

Corrections from the M2 design and implementation reviews (applied):

- OHKO / Pain Split against a semi-invulnerable target: `moveFailed`, not a
  miss (above).
- Earthquake / Magnitude miss leaf (`data/battle_scripts_1.s:1867-1875`) runs
  typecalc: an immune target prints "It doesn't affect" (resultmessage,
  `src/battle_script_commands.c:1937`), no RNG. Explosion's miss after its
  typecalc does the same (this also corrects its ordinary-miss text).
- Jump Kick / Hi Jump Kick: the semi-invulnerable miss returns before
  `CheckWonderGuardAndLevitate`, so the immunity pre-scan is skipped: "missed"
  and the crash (1 HP against an immune target, random multiplier drawn).
- The semi-invulnerable check replaces the roll at each existing accuracy
  site, after that move's own gates (status/confuse/Teeter/Tickle gates,
  Endeavor's HP gate, Explosion's Damp and crit/damage draws, Magnitude's
  strength roll).
- AI_CheckBadMove has no branch for 147/149/152/155/207 (returns 0); weather
  is unmodeled, so Thunder always rolls 70. Gust, Sky Uppercut, Surf and the
  Fly/Dig/Dive turn-2 hit share the tracked plain-hit roll gap.

## Slice M3 addendum: Rampage

- Status: `PROPOSAL — independently reviewed PASS WITH CORRECTIONS (applied)`
- Task: [P4-MULTITURN-M3](../tasks/phase4-multiturn-m3.md)
- Review: [M3 design review](../reviews/2026-10-14-multiturn-m3-design-review.md)
  (PASS WITH CORRECTIONS; F1-F4 applied below and in the implementation).

Family: 27 Rampage: Thrash (37, Normal 90), Petal Dance (80, Grass 70),
Outrage (200, Dragon 90). All three have accuracy 100,
`secondaryEffectChance` 100 and `MOVE_TARGET_RANDOM`
(`src/data/battle_moves.h:484-495, 1043-1054, 2603-2614`). Today they are
admitted as plain hits (the inventory row is `blocked_on_state`), so M3
changes the behaviour of moves that can already be used.

Source facts:

- Script (`data/battle_scripts_1.s:585-593`): attackcanceler,
  **accuracycheck**, attackstring, `jumpifstatus2 MULTIPLETURNS` (skips
  ppreduce), `confuseifrepeatingattackends`, then
  `BattleScript_HitFromCritCalc` (`:251-270`: critcalc, damagecalc, typecalc,
  adjustnormaldamage, the hit, resultmessage, **seteffectwithchance**,
  tryfaintmon). On a miss the script goes to `BattleScript_PrintMoveMissed`
  (`:276-285`), which runs attackstring and then `ppreduce`.
- `Cmd_confuseifrepeatingattackends` (`src/battle_script_commands.c
  :6849-6855`): when LOCK_CONFUSE is clear, it sets the effect byte
  `MOVE_EFFECT_THRASH | AFFECTS_USER` (not CERTAIN). Otherwise it does
  nothing.
- `Cmd_seteffectwithchance` (`:2774-2803`): `Random() % 100 <= 100` is
  always drawn, on every turn and including a no-effect hit, because it is
  the first operand (`:2789`). The effect is applied only when the byte is
  set and the move result is not `NO_EFFECT`; at 100% this goes through
  `SetMoveEffect(FALSE, CERTAIN)`. Byte 53 (`include/constants/battle.h:274`)
  is above the Shield Dust (`<= 9`) and Safeguard (`<= 7`) guards, and the
  attacker is alive, so a KO of the target on turn 1 still sets the lock.
- `MOVE_EFFECT_THRASH` (`:2719-2730`) sets `STATUS2_MULTIPLETURNS` and
  `gLockedMoves`, then `LOCK_CONFUSE_TURN((Random() & 1) + 2)` (2-3; bits
  10-11, `include/constants/battle.h:113-115`). This is the lock: the
  battler chooses no action (no menu, no AI, no switch, run or item;
  `src/battle_main.c:3125-3130`) and uses `gLockedMoves` (`:3989-3992`).
  The 0-PP check in attackcanceler is bypassed (`bsc.c:838-839`).
- PP: turn 1 spends it through ppreduce (`:1122-1167`). On a locked hit
  the jumpifstatus2 skips ppreduce. **A locked-turn miss spends PP**:
  PrintMoveMissed's ppreduce runs, and nothing sets `HITMARKER_NO_PPDEDUCT`
  for a locked move (`:1147`; it costs nothing at 0 PP).
- End of turn: `ENDTURN_THRASH` (`src/battle_util.c:953-973`). It runs per
  battler in turn order, after that battler's poison, burn and wrap ticks
  (`:721-741`, `:751`). LOCK_CONFUSE is decremented first. Then:
  - If `WasUnableToUseMove` (`:216-230`), the lock is cancelled silently.
  - Otherwise, when the counter has reached 0, MULTIPLETURNS is cleared.
    If the battler is not confused, it runs
    `SetMoveEffect(TRUE, MOVE_EFFECT_CONFUSION | AFFECTS_USER)` (primary,
    so Shield Dust and Safeguard do not apply). Own Tempo stops it
    silently with no draw (`bsc.c:2405-2418`). Otherwise the confusion
    lasts `Random() % 4 + 2` (2-5) turns (`:2413`) and
    `BattleScript_ThrashConfuses` (`data/battle_scripts_1.s:3730-3734`)
    prints only "X became confused due to fatigue!"
    (`src/battle_message.c:177`). SetMoveEffect's own "became confused!"
    script is pushed but then overwritten by `BattleScriptExecute`.
  - An already confused battler loses the lock silently, with no draw.
  - The protect structs that WasUnableToUseMove reads are cleared only
    after the end-of-turn effects (`src/battle_main.c:2948-2963`, the
    `TurnValuesCleanUp(FALSE)` call that follows them), so that turn's
    flags are still visible.
  - Turn count: the counter ticks on turn 1 too, so a roll of 2 means 2
    attacking turns and a roll of 3 means 3. Confusion is applied at the
    end of the last turn.
- Ending and interactions:
  - Cancellers clear LOCK_CONFUSE through `CancelMultiTurnMoves`
    (`src/battle_util.c:203-214`), so the lock ends with **no fatigue
    confusion**. The cancel points are: sleep or freeze applied
    (`bsc.c:2173, 2269`), flinch (`battle_util.c:1366`), full paralysis
    (`data/battle_scripts_1.s:3717`), confusion self-hit (`:3742`), and a
    sleeping battler at end of turn (`src/battle_main.c:2941-2942`).
    Unmodeled cancel points are Protect (`bsc.c:900`), Truant, Disable,
    Taunt, Imprison, Attract, Torment and Yawn.
  - The user already confused: the confusion canceller runs every locked
    turn. A self-hit ends the lock, while "is confused!" without a
    self-hit, or snapping out, lets the move proceed.
  - Target faints or switches: nothing cancels the lock. The rampage
    continues into the replacement, and the counter keeps ticking.
  - No-effect hit (Thrash into a Ghost): typecalc sets `targetNotAffected`
    (`bsc.c:1340`). On turn 1 seteffectwithchance draws but sets no lock,
    and PP is spent. On a locked turn, WasUnableToUseMove cancels the lock
    at end of turn, with **no confusion even on the last turn**.
  - Missed roll against an immune target: `CheckWonderGuardAndLevitate`
    (`:1102`) sets `targetNotAffected` and the text is "It doesn't affect"
    (`:1937`). This has the same end-of-turn cancel. **Not** against a
    semi-invulnerable target (review F1): `AccuracyCalcHelper` returns
    before the roll and before that scan (`bsc.c:958-1001`), so the miss
    draws nothing, prints "missed", sets no flag, and the lock continues
    (a last turn still confuses).
  - Ordinary miss: the lock continues and the counter ticks. A miss on
    the last turn still confuses.
  - Faint clears status2. A freshly frozen battler that thaws later in the
    same turn reaches the script with the lock already cleared. It then
    starts a new rampage: PP spent and a new 2-3 roll.
- AI: effect 27 is not in AI_CheckBadMove's `if_effect` chain
  (`data/battle_ai_scripts.s:104-214`), and it is not in
  `sDiscouragedPowerfulMoveEffects` (`src/battle_ai_script_commands.c
  :245-259`). Only the shared prefix applies (`:52-90`: a Thrash into a
  Ghost scores −10); otherwise the score is 0. The ported
  `AICheckBadMove` already returns this; no change. A locked foe draws no
  AI RNG.

Design:

- State: `rampageTurns` (LOCK_CONFUSE, 0-3) on the battler. Source keeps
  MULTIPLETURNS and LOCK_CONFUSE equal for this family, so one field is
  enough, and it is exclusive with `charging`. It reuses `lockedSlot`.
  Faint, switch-in and `cancelMultiTurnMoves` clear it.
  `isLocked` = `charging or rampageTurns > 0 or (recharging and
  rechargeTimer > 1)` (F4: the recharge term is unchanged). A per-turn
  `targetNotAffected` flag on the battler is reset at `runTurn` start and
  set by a no-effect hit or by a missed roll against an immune target.
- Move path: `useMove` every turn, then accuracy.
  - Miss: PP (when `pp > 0`, also on locked turns). On a no-effect miss
    that is not a semi-invulnerable miss (F1: `not semiMiss`, as for Jump
    Kick), the `noEffect` text and the flag, with no RNG (a pure
    `typeCalc` query). Otherwise `miss`.
  - Hit: PP only when `rampageTurns == 0`. The ordinary crit, damage,
    typecalc and random multiplier. The seteffectwithchance draw always
    happens, also in the no-effect branch. On turn 1, a hit with an
    effect, including a KO, draws `Random() & 1` and sets
    `rampageTurns = 2|3` and `lockedSlot`.
  - The 0-PP check after the cancellers exempts a live rampage. A
    rampage lock cancelled earlier this turn is fresh again, as in source.
- End of turn: in `resolveStatusEndTurn`, after each living side's status
  damage, decrement `rampageTurns`. If `targetNotAffected` is set,
  `cancelMultiTurnMoves`. At 0, clear the lock, and if the battler is not
  confused, call `applyConfusion`. Own Tempo is silent; otherwise it
  draws `% 4` and emits `fatigueConfusion {side}` instead of
  `confusionApplied`. The sleeping-battler cancel in `resolveEndTurn`
  also covers `rampageTurns`.
- Engine sites (review F3):
  1. ppreduce: split. A hit skips it while `rampageTurns > 0`; a miss
     decrements only when `pp > 0` (the M2 `noPPDeduct` flag is not
     reused, since it also suppresses the miss deduction).
  2. The no-effect seteffect-roll whitelist gains `EFFECT_RAMPAGE`.
  3. The generic miss branch gets the Rampage `typeCalc` query (F1 gate)
     before its plain `miss`.
  4. The natural lock end in the end-of-turn tick also sets
     `lockedSlot = nil`, as `cancelMultiTurnMoves` does.
  Plus the post-canceller 0-PP check, which exempts a live rampage.
- Controller: one text, `fatigueConfusion` → "X became\nconfused due to
  fatigue!" (`battle_message.c:177`). The menu skip and the foe AI skip
  already follow `isLocked`.
- Inventory: 27 becomes `represented`.

RNG per turn (singles: no random-target draw, since that draw is
doubles-only, `src/battle_main.c:4093-4111`):

| Turn | Draws (in order) |
| --- | --- |
| 1, hit with effect | [cancellers] accuracy, crit, damage multiplier, seteffect `%100`, `&1` (lock length) |
| 1, no-effect hit | [cancellers] accuracy, crit, damage multiplier, seteffect `%100` (no lock; PP spent) |
| 1 or locked, miss | [cancellers] accuracy only (no draw against a semi-invulnerable target) |
| locked, hit or no-effect hit | [cancellers] accuracy, crit, damage multiplier, seteffect `%100` |
| end of last turn | `%4` confusion length, unless already confused, Own Tempo, or unable |

`[cancellers]` (review F2) means, on every turn including locked ones: a
battler frozen (also earlier this turn) draws `%5`; a confused battler
draws `&1`, plus the self-hit damage multiplier on a self-hit (which ends
the turn and the lock); a paralyzed battler draws `%4` (0 ends the turn
and the lock).

Known limits: Protect, Disable, Taunt, Imprison, Encore, Torment, Truant,
Attract and Yawn, with their cancel and unable flags. Wonder Guard (sets
MISSED without `targetNotAffected`, so the rampage would continue).
Pressure (an extra PP). Substitute, King's Rock, Persim and Lum Berries,
Roar and Whirlwind, and doubles (the random target draw). The mid-turn
faint halt policy is inherited: a rampager whose opponent fainted earlier
in the turn does not act, but its counter still ticks at end of turn. The
general miss-against-an-immune-target text ("missed" instead of "It
doesn't affect") stays a gap outside this family and Jump Kick.
