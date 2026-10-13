# Task: Triple Kick (fast lane)

- Task ID: `P4-FL5-TRIPLE-KICK`
- Status: `CLOSED — REVIEWED PASS` after re-check ([review](../reviews/2026-10-13-triple-kick-review.md)); ROM fixture pending
- Lane: [battle-effect fast lane](../../AGENTS.md#battle-effect-fast-lane--human-authorized-2026-10-13)
- Parent: [Phase 4 move/effect matrix](../roadmaps/CAPABILITY_CHECKLIST.md)
- Family: 104 Triple Kick (167)

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

- `data/battle_scripts_1.s:1380-1430`: attackcanceler → attackstring →
  ppreduce (no outer accuracycheck) → power 0, setmultihit 3 → loop:
  `jumpifhasnohp ATTACKER` (end), `jumpifhasnohp TARGET` (NoMoreHits), sleep
  check, `accuracycheck BattleScript_TripleKickNoMoreHits, ACC_CURR_MOVE`,
  `movevaluescleanup`, power += 10, hit counter += 1 (`addbyte
  sMULTIHIT_STRING + 4`, after accuracy but before damage; an immune first
  kick counts 1 but DOESNT_AFFECT suppresses the hit-count text, so the
  engine's landed-kick count is equivalent), `copyhword gDynamicBasePower`,
  critcalc, damagecalc, typecalc, adjustnormaldamage,
  `jumpifmovehadnoeffect NoMoreHits`, HP update, `decrementmultihit`.
  NoMoreHits: with a nonzero count, `bicbyte MISSED`; PrintStrings:
  resultmessage, and with a nonzero count and no DOESNT_AFFECT,
  `STRINGID_HITXTIMES`; then `seteffectwithchance`, `tryfaintmon BS_TARGET`.
- `src/battle_script_commands.c:3469` MoveValuesCleanUp; `Cmd_damagecalc`
  (`:1209-1222`) passes gDynamicBasePower to CalculateBaseDamage; the script
  rewrites it every kick (resets elsewhere: `battle_main.c:3695,4471`).
- `src/battle_message.c:82` "Hit {B_BUFF1} time(s)!".
- `src/data/battle_moves.h:2174`: record used by the ROM fixture.

## Design and MAY CHANGE

- `src/core/BattleEngine.lua`: `EFFECT_TRIPLE_KICK` excluded from the outer
  accuracy check; `resolveTripleKick` loop emitting per-kick
  `critical`/`damage`, then `multiHit` (or `miss`/`noEffect` with no landed
  kick). A kick that faints the defender ends the loop; the count prints and
  the caller's faint check follows (source order).
- Tests: `tests/battle_engine_test.lua`, `tests/battle_scene_controller_test.lua`,
  `tests/phase4_move_effect_inventory_test.lua`, new
  `tests/phase4_triple_kick_effect_rom_test.lua`;
  `work/reports/phase4-move-effect-inventory.md` row, summary, uncovered list.

Excluded: sleep/Sleep Talk, Endure/Focus Band (FOE_ENDURED), Substitute,
abilities, first-battle per-kick tutorial accuracy (unreachable), per-kick
vs end-of-move effectiveness message timing (existing multi-hit convention),
and the trailing seteffectwithchance roll (tracked plain-hit gap).

## Acceptance

1. Draw counts below match the tracked seteffectwithchance gap (source
   10/5/2/4: the trailing roll is also spent on a miss).
   Both sides: three kicks 4/6/8 at Lv20 40/40, `multiHit` 3, PP −1, 9 draws;
   second kick miss → one damage + `multiHit` 1, no miss event, 4 draws;
   first kick miss → `miss`, 1 draw, PP spent; immune → `noEffect` after 3
   draws; per-kick crit doubles that kick only; KO on kick 2 stops the loop
   with `multiHit` 2 before faint (also with a replacement pending); per-kick
   evasion/accuracy stages (threshold 67 at evasion +1); Reflect 3/4/5.
2. Controller: later miss shows "Hit 2 time(s)!" without miss text; first
   miss shows miss text without a hit count.
3. Inventory: family `represented`, totals and report updated; ROM fixture pending.
4. No-ROM `scripts/test_all.sh` and `scripts/check_repository.lua` pass.

## Evidence (Worker, 2026-10-13)

No-ROM: engine 533/0 (was 521), controller 100/0, inventory partition PASS,
new ROM fixture skips cleanly. Independent review NEEDS_FIX
([record](../reviews/2026-10-13-triple-kick-review.md)); findings 1-7 addressed:
per-kick accuracy/evasion stage, Reflect and replacement tests (engine 541/0),
gap draw-count notes, source citation, row 104 limits. Re-check PASS.

## Follow-ups

- Plain-hit seteffectwithchance gap also covers Triple Kick, where the
  source spends the roll on every path including a first-kick miss.
