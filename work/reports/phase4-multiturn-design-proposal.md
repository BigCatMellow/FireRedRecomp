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
