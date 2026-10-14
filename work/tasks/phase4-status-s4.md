# Task: primary status conditions, slice S4

- Task ID: `P4-STATUS-S4`
- Status: `IMPLEMENTED — awaiting independent review`; ROM fixture pending
- Lane: full relay. Owner delegation 2026-10-14; battle files only.
- Builds on: S1-S3 (status), design
  [proposal](../reports/phase4-status-conditions-design-proposal.md) S4 row
  (capture multiplier already moved to S2).
- Families: 125 Thaw Hit (Flame Wheel, Sacred Fire), 169 Facade, 171 Smelling
  Salt, 193 Refresh (newly admitted): 5 moves.

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

- `data/battle_scripts_1.s:1675-1677` Thaw Hit = setmoveeffect BURN + Hit;
  the user's thaw is the S1 canceller path (`src/battle_util.c:1310-1333,
  1513-1525`).
- `:2247-2253` Facade: `jumpifstatus BS_ATTACKER PSN|BRN|PAR|TOX` →
  `sDMG_MULTIPLIER 2`; `src/battle_script_commands.c:1215` damagecalc
  multiplies base damage (after the +2, with the crit multiplier, before
  typecalc). Burn halving stays inside the base damage.
- `:2263-2270` Smelling Salt: Substitute check (not represented); effect
  `REMOVE_PARALYSIS | CERTAIN`; multiplier 2 vs a paralyzed target.
  `:2774-2797` seteffectwithchance: CERTAIN with an effect calls
  SetMoveEffect without a roll; a no-effect hit falls to the rolling branch.
  `:2690-2705` clears paralysis and prints `STRINGID_PKMNHEALEDPARALYSIS`
  (`src/battle_message.c:108`); 0 HP returns early (`:2140`).
- `:2515-2525` Refresh; `src/battle_script_commands.c:8728-8742`
  `Cmd_cureifburnedparalysedorpoisoned` (status1 = 0, else ButItFailed);
  text `src/battle_message.c:222`.
- Records `src/data/battle_moves.h` (5 members, in the ROM fixture).

## MAY CHANGE

- `src/core/BattleEngine.lua`: thaw-hit burn entry, Facade/Smelling Salt
  multiplier, Smelling Salt cure and no-effect roll, Refresh admission and
  handler, events.
- `src/core/BattleSceneController.lua`: two texts.
- Tests: status engine, controller, inventory partition, new
  `tests/phase4_status_s4_effect_rom_test.lua`; inventory report rows.

## Acceptance

Burn chance boundaries for both thaw-hit moves; Facade ×2 per status (not
sleep), burn halving retained; Smelling Salt ×2 before STAB, cure without a
roll, roll on no effect, no cure on KO; Refresh cures each kind, fails
otherwise, spends PP, no RNG; texts; full no-ROM suite and checker pass.

## Known limits

- Facade shares the tracked plain-hit seteffectwithchance roll gap (a zero
  effect byte still draws in source); ROM replay verification pending.
  Smelling Salt's CERTAIN byte draws only on a no-effect hit, as modeled.
- Substitute not represented (Smelling Salt's first branch).

## Evidence (Worker, 2026-10-14)

Status engine 201/0; controller 137/0; full suite and repository checker in
the PR.
