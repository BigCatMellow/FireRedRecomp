# Task: locked multi-turn moves, slice M1 (charge and recharge)

- Task ID: `P4-MULTITURN-M1`
- Status: `CLOSED — REVIEWED PASS` after re-review ([review](../reviews/2026-10-14-multiturn-m1-review.md)); ROM fixture pending
- Lane: full relay (cross-turn state, action-selection change). Owner
  delegation 2026-10-14 ("Keep going"); battle files and the battle scene
  controller only (no main.lua).
- Design: [multi-turn proposal](../reports/phase4-multiturn-design-proposal.md).
- Families (8 moves): 80 Recharge (Hyper Beam, Blast Burn, Hydro Cannon,
  Frenzy Plant), 39 Razor Wind, 75 Sky Attack, 145 Skull Bash, 151 Solar Beam.

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

See the design proposal: `src/battle_main.c:3125-3130,3641-3646,3983-3992,
2941`; `src/battle_util.c:203-214,1349-1358`; `src/battle_script_commands.c
:2477-2482,2600-2605`; `data/battle_scripts_1.s:777-806,1061-1066,
1107-1116,1807-1820,1899-1913`; texts `src/battle_message.c:135-138,185`.

## MAY CHANGE

- `src/core/BattleEngine.lua`: lock state, `isLocked`, `cancelMultiTurnMoves`,
  recharge canceller, charge turn/second turn, recharge application,
  cancel points (flinch, paralysis, confusion self-hit, sleep/freeze
  application, sleeping charger at end of turn), runTurn action override and
  recharge timer, faint clearing, Sky Attack crit/flinch.
- `src/core/BattleSceneController.lua`: no menu for a locked player, no AI
  call for a locked foe, charge/recharge texts.
- Tests: new `tests/battle_multiturn_test.lua`, inventory partition, new
  `tests/phase4_multiturn_effect_rom_test.lua`; inventory report rows.

## Known limits

Weather (Solar Beam in sun), semi-invulnerable moves (M2), Rampage and the
other locked families (M3), Truant, Disable/Taunt/Imprison.

## Evidence (Worker, 2026-10-14)

Multi-turn 45/0 after implementation review round 1; full suite and repository checker in the PR.
