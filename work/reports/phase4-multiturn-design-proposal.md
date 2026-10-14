# Phase 4 proposal: locked multi-turn moves (charge and recharge)

- Status: `PROPOSAL — awaiting independent design review; no implementation authority`
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
- AI: the AI_CBM scripts have no entries for these effects; AI_CV terms out
  of scope.

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
