# Task: locked multi-turn moves, slice M3 (Rampage)

- Task ID: `P4-MULTITURN-M3`
- Status: `DONE — independently reviewed PASS WITH CORRECTIONS (applied)`; ROM fixture pending
- Reviews: [design](../reviews/2026-10-14-multiturn-m3-design-review.md),
  [implementation](../reviews/2026-10-14-multiturn-m3-implementation-review.md)
- Design review: [PASS WITH CORRECTIONS](../reviews/2026-10-14-multiturn-m3-design-review.md);
  F1-F4 applied in the addendum and the implementation.
- Lane: full relay (cross-turn lock state, end-of-turn confusion, RNG
  order of moves that are already admitted).
- Builds on: [M1](phase4-multiturn-m1.md), [M2](phase4-multiturn-m2.md),
  and confusion C1/C2. Design:
  [proposal, M3 addendum](../reports/phase4-multiturn-design-proposal.md).
- Family (3 moves): 27 Rampage: Thrash 37, Petal Dance 80, Outrage 200.
  These are currently admitted as plain hits.

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

See the M3 addendum: `data/battle_scripts_1.s:251-285,585-593,3717,
3730-3742`; `src/battle_script_commands.c:838-839,1102,1122-1167,1340,
1937,2405-2418,2719-2730,2774-2803,6849-6855`; `src/battle_util.c:203-230,
721-751,953-973`; `src/battle_main.c:2941-2963,3125-3130,3989-3992`; text
`src/battle_message.c:177`; AI `data/battle_ai_scripts.s:52-214`,
`src/battle_ai_script_commands.c:245-259`.

## MAY CHANGE

- `src/core/BattleEngine.lua`:
  - `rampageTurns` and the per-turn `targetNotAffected` state.
  - `isLocked`, `cancelMultiTurnMoves`, faint clear and switch-in.
  - Turn-1 PP and the lock roll after the seteffectwithchance draw.
  - Locked-turn PP only on a miss.
  - The no-effect miss text and flag for Rampage.
  - The `ENDTURN_THRASH` tick in `resolveStatusEndTurn`, with the
    `fatigueConfusion` event.
  - The sleeping-battler cancel and the 0-PP exemption.
  - Review F3 sites: the split ppreduce (a locked hit skips it, a miss
    spends PP only when `pp > 0`), `EFFECT_RAMPAGE` in the no-effect
    roll whitelist, the Rampage immunity query on the generic miss branch
    (gated on `not semiMiss`, F1), and `lockedSlot = nil` at the natural
    lock end.
  - `applyConfusion` gains an optional event-type parameter.
- `src/core/BattleSceneController.lua`: one text.
- Tests: multi-turn additions, inventory row 27 → `represented`, new
  `tests/phase4_rampage_effect_rom_test.lua`; report rows.

## MUST NOT CHANGE

`AICheckBadMove.lua` (effect 27 already falls through to 0), main.lua and
the save and party bridges (status2 is never persisted).

## Acceptance checks

- Turn 1 draws accuracy, crit, damage, seteffect, then `&1`. The roll
  gives 2 or 3 attacking turns, with no menu and no AI draw while locked.
- A miss or no-effect hit on turn 1 spends PP and sets no lock.
- A locked miss spends PP and keeps the lock. A locked hit spends none.
- The last turn ends with "became confused due to fatigue!" (2-5 turns).
  This is silent with Own Tempo or when the user is already confused,
  with no `%4` draw.
- Flinch, full paralysis, a confusion self-hit, or sleep or freeze
  applied ends the lock with no confusion.
- A no-effect locked turn (Thrash into a Ghost) ends the lock at end of
  turn with no confusion, also on the last turn.
- A locked miss against a semi-invulnerable target (a Ghost using Dig)
  draws nothing, prints "missed", spends PP and keeps the lock (F1).
- A target faint or switch keeps the lock against the replacement.

## Known limits

Protect, Disable, Taunt, Imprison, Encore, Torment, Truant, Attract, Yawn,
Wonder Guard, Pressure, Substitute, King's Rock, Persim and Lum Berries,
Roar and Whirlwind, doubles (random target). The inherited mid-turn faint
halt: a rampager that does not act still ticks. The general miss against
an immune target text outside Rampage and Jump Kick.

## Evidence (Worker, 2026-10-14)

- Engine: `src/core/BattleEngine.lua` (`EFFECT_RAMPAGE`, `rampageTurns`,
  `targetNotAffected`, `isLocked`, `cancelMultiTurnMoves`, `recordFaint`,
  `resolveMoveCore` locked/0-PP/ppreduce/miss/no-effect/lock-roll sites,
  `resolveEndTurn` sleep cancel, `resolveStatusEndTurn` ENDTURN_THRASH
  tick, `runTurn` per-turn flag reset). Controller: `fatigueConfusion` →
  "X became\nconfused due to fatigue!" (`battle_message.c:177`).
- `lua5.1 tests/battle_rampage_test.lua`: 44 passed, 0 failed (scripted
  RNG with exact draw counts: turn 1 5 draws, locked hit 4, miss 1, end
  `%4`; 2- and 3-turn locks for all three moves; PP on turn 1, locked
  miss, 0-PP locked hit and miss; Own Tempo and already-confused; turn-1
  and locked no-effect hits; immune miss; semi-invulnerable miss;
  paralysis, flinch, confusion self-hit, sleep applied and end-of-turn
  sleep cancels; turn-1 KO and the replacement; faint clear; controller
  menu/AI skip for both sides; text). Each F1/F3 site was mutation-checked
  against these tests.
- `tests/battle_multiturn_test.lua`: 83 passed, 0 failed (unchanged).
- `tests/phase4_rampage_effect_rom_test.lua`: skips without a ROM.
- Inventory row 27 → `represented`; partition counts 105/246 represented,
  92/107 blocked, 37 admitted uncovered positive.
- `bash scripts/test_all.sh`: 173 test files PASS (no-ROM mode);
  `lua5.1 scripts/check_repository.lua`: PASS.

## Review corrections (2026-10-14)

The implementation review's F1/F2 test gaps are closed in
`tests/battle_rampage_test.lua` (49 passed, 0 failed): poison damage before
the fatigue text, poison KO on the last turn (no `%4`), a thawed rampager
starting a fresh rampage, and snapping out of confusion on the last locked
turn still confusing. Moving the tick before status damage now fails two
checks.
