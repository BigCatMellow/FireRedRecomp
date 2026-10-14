# Task: status leftovers, slice L2 (Rest, Focus Energy)

- Task ID: `P4-STATUS-LEFTOVERS-L2`
- Status: `IMPLEMENTED — awaiting independent review`; ROM fixture pending
- Design: [proposal](../reports/phase4-status-leftovers-design-proposal.md)
  (L2 parts), independently reviewed
  [PASS WITH CORRECTIONS](../reviews/2026-10-14-status-leftovers-design-review.md);
  F3 (Lansat Berry / Dire Hit known limits) and the L2 half of F5 (comment
  touch list) applied here.
- Lane: full relay (two newly admitted zero-power families; one new
  battle-only volatile that changes crit odds).
- Builds on: [L1](phase4-status-leftovers-l1.md) (H1 `critStageFor`),
  status S1-S4, confusion/flinch C1-C2.
- Families (2 moves, newly admitted): 37 Rest (156), 47 Focus Energy (116).

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

`data/battle_scripts_1.s:735-759,884-894,2028-2042`;
`src/battle_script_commands.c:1170-1206,6480-6502,6546-6566,7383-7396`;
`src/battle_util.c:1266-1300`; `src/battle_main.c:2329,2433-2441`;
`include/constants/battle.h:120`; `data/battle_ai_scripts.s:131,386-388`;
records `src/data/battle_moves.h:1511-1522,2031-2042`; text
`src/battle_message.c:86,124,125,133,134,153,174,336,973-977,1058-1062`.

## MAY CHANGE

- `src/core/BattleEngine.lua`:
  - `EFFECT_REST = 37`, `EFFECT_FOCUS_ENERGY = 47`, `MOVE_REST = 156`.
  - `makeBattler`: `focusEnergy = false` (battle-only, never persisted);
    `recordFaint` clears it (FaintClearSetData). Switch-ins are fresh
    battlers.
  - `supportsMove`: effect 37 (move 156 only) and effect 47, both power 0
    and `MOVE_TARGET_USER`.
  - `resolveMoveCore` early branches after Refresh: Rest (already asleep →
    `statusAlready` sleep; Insomnia/Vital Spirit → `stayedAwake`; full HP →
    `restoreHPFull`; else `status = sleep 3`, `restSlept{statused}`,
    `restoreHP` to max) and Focus Energy (`moveFailed` if set, else set and
    `focusEnergy`). Both spend one PP and draw nothing.
  - `critStageFor`: `2 * (focusEnergy and 1 or 0) + base`.
  - Comments: header event list (`restSlept`, `focusEnergy`), the
    "not ported" note that named Rest/Focus Energy, the `critStageFor`
    comment.
- `src/core/BattleSceneController.lua`: `restSlept` (":133"/":134") and
  `focusEnergy` (":153") texts.
- `src/core/AICheckBadMove.lua`: row 47 only — `focusEnergy` handler
  (AI_CBM_FocusEnergy, −10 when `user.focusEnergy`) and its row comment.
- Tests: new `tests/battle_status_leftovers_l2_test.lua` and
  `tests/phase4_status_leftovers_l2_effect_rom_test.lua`; one L1 check label;
  inventory rows 37, 47 → `represented`; report rows and counts.

## MUST NOT CHANGE

Everything else in `AICheckBadMove.lua` (the Memento AI inspection and the
module header belong to another agent), `main.lua`, the party/Dex code, the
save and party bridges, coordination/roadmap files.

## Acceptance checks

- Rest draws no Random() and spends one PP on every path. Fail order:
  already asleep (defensive) → Insomnia/Vital Spirit on the user (also at
  full HP) → full HP (status kept). Success overwrites status1 with exactly
  sleep 3 (toxic counter cleared), prints "went to sleep!" or, with any of
  bits 3-7 (poison, burn, freeze, paralysis, toxic), "slept and became
  healthy!" (a counter-only word gives "went to sleep!"), then heals to max
  and prints "regained health!". Confusion is not cured. Through `runTurn`
  the user is fast asleep on the next two turns and wakes and acts on the
  third; no end-of-turn poison/burn tick on the Rest turn.
- Focus Energy draws no Random() and spends one PP; a second use prints
  "But it failed!". The crit stage is `2 * FE + base`: Tackle `%4`, Slash
  and Blaze Kick `%3`, at the ordinary hit, Explosion, multi-hit and Triple
  Kick sites. Cleared on faint; absent after a forced or voluntary switch.
- AI_CBM_FocusEnergy: −10 when the AI user's `focusEnergy` is set, else 0.
- Inventory: 285 admitted / 69 rejected; represented 110/251, blocked
  87/102.

## Known limits

- Rest: Uproar and Sleep Talk calling Rest are unreachable (the "already
  asleep" branch is defensive only); Early Bird is not represented (a Rest
  user sleeps two turns, not one).
- Focus Energy is not passed by Baton Pass (not represented).
- Focus Energy's other setters are not represented (review F3): the Lansat
  Berry (`HOLD_EFFECT_CRITICAL_UP`, `battle_util.c:2681-2688`) and the Dire
  Hit battle item (`pokemon.c:4090-4092`, `:4611`). A future held-item or
  in-battle bag slice must set `focusEnergy`.
- Battle Armor / Shell Armor before the crit draw, Scope Lens / Lucky Punch
  / Stick (existing gaps).
- AI_CheckViability (`AI_CV_Rest`, `AI_CV_HighCrit`) and AI_HPAware are out
  of scope.
- The `AICheckBadMove.lua` module header still says status2 is never set
  "beyond confusion and flinch"; it was left untouched because the header
  is outside this slice's AI scope (row 47 and its comment only).

## Evidence (Worker, 2026-10-14)

- `lua5.1 tests/battle_status_leftovers_l2_test.lua`: 93 passed, 0 failed
  (scripted RNG with exact draw counts: admission; Rest success, each
  status including toxic with counter 5/15, freeze via thaw and via a
  bypassed canceller, counter-only word, every fail case in order, the
  real fast-asleep path, confusion kept, the sleep length through
  `runTurn`, no end-of-turn poison, a foe Rest; Focus Energy set/fail, the
  stage table, Tackle/Slash/Blaze Kick/Explosion/Double Kick/Triple Kick
  with and without FE, FE then a crit through `runTurn`, faint clear,
  forced and voluntary switch; the AI term directly and through the engine;
  controller texts). Mutation-checked: dropping the FE crit term, the faint
  clear, keeping old status bits, dropping the freeze bit from `statused`
  and a 2-turn sleep each fail at least one check.
- `lua5.1 tests/battle_status_leftovers_test.lua` (L1): 101 passed.
- `tests/phase4_status_leftovers_l2_effect_rom_test.lua`: skips without a
  ROM.
