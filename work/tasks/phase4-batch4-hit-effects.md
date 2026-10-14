# Task: batch 4 hit effects (fast lane)

- Task ID: `P4-FL4-HIT-EFFECTS`
- Status: `CLOSED — REVIEWED PASS` after re-check ([review](../reviews/2026-10-13-batch4-hit-effects-review.md)); ROM fixture pending
- Lane: [battle-effect fast lane](../../AGENTS.md#battle-effect-fast-lane--human-authorized-2026-10-13)
- Parent: [Phase 4 move/effect matrix](../roadmaps/CAPABILITY_CHECKLIST.md)
- Families: 140 All Stats Up Hit (246 Ancient Power, 318 Silver Wind), 186 Brick Break (280)

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

- `data/battle_scripts_1.s:1768-1770`: `setmoveeffect MOVE_EFFECT_ALL_STATS_UP |
  AFFECTS_USER` then EffectHit; `seteffectwithchance` (not CERTAIN) spends one
  `Random() % 100 <= chance` roll on a landed or no-effect hit
  (`src/battle_script_commands.c:2774-2805`), applying only when the hit had an effect.
- `src/battle_script_commands.c:2682` → `BattleScript_AllStatsUp`
  (`data/battle_scripts_1.s:3405-3439`): skip all if ATK, DEF, SPEED, SP.ATK
  are at +6 and SP.DEF is at +6; otherwise each of the five runs
  `statbuffchange AFFECTS_USER|ALLOW_PTR` then `printfromtable gStatUpStringIds`
  with no skip, so a maxed stat prints `STRINGID_STATSWONTINCREASE`
  (`ChangeStatBuffs` `:6796-6815` returns WORKED with ALLOW_PTR).
- `data/battle_scripts_1.s:2413-2444` Brick Break: accuracycheck → ppreduce →
  `removelightscreenreflect` (`src/battle_script_commands.c:9441`, clears both
  screens and timers on the target side, `animTurn = 1`) → critcalc →
  damagecalc → typecalc → adjustnormaldamage; with a wall removed the
  MISSED/DOESNT_AFFECT bits are cleared, `attackanimation` (`:1662`, always
  increments animTurn in both animation modes) runs, and animTurn ≥ 2 prints
  `STRINGID_THEWALLSHATTERED`; `typecalc2` (`:4346`) re-derives the result
  flags, so an immune target still takes no damage. Miss path removes nothing.
- `src/battle_message.c:256` "The wall shattered!".
- `src/data/battle_moves.h:3201,3643,4137`: records used by the ROM fixture.

## Design and MAY CHANGE

- `src/core/BattleEngine.lua`: `EFFECT_ALL_STATS_UP_HIT` handled after damage
  beside the hit-variant step (roll also spent on no-effect);
  `EFFECT_BRICK_BREAK` clears the defender side's screens after ppreduce and
  before critcalc, emitting `wallShattered`.
- `src/core/BattleSceneController.lua`: `wallShattered` message.
- `src/core/BattleFormulas.lua`: stale Brick Break header comment only.
- Tests: `tests/battle_engine_test.lua`, `tests/battle_scene_controller_test.lua`,
  `tests/phase4_move_effect_inventory_test.lua`, new
  `tests/phase4_batch4_hit_effect_rom_test.lua`;
  `work/reports/phase4-move-effect-inventory.md` rows, summary and uncovered list.

Excluded: Serene Grace, Shield Dust, abilities, Substitute, doubles,
animation timing, and the pre-existing plain-hit seteffectwithchance RNG gap
(tracked in [batch 2 follow-ups](phase4-self-drop-tickle-batch.md)).

## Acceptance

1. Brick Break, both sides: target Reflect/Light Screen cleared with timers
   before damage (17 not 9 at Lv20 40/40), `wallShattered` precedes damage;
   attacker's own wall untouched; immune target still shatters, no damage;
   miss keeps the wall; 3 draws (accuracy, crit, damage), matching the
   tracked plain-hit seteffectwithchance gap (source spends 4).
2. Ancient Power/Silver Wind, both sides: roll 10 raises all five in order
   (4 draws incl. effect roll); roll 11 nothing; a maxed stat gets a
   prevented entry while the rest rise; all maxed silent; immune spends the
   roll and raises nothing.
3. Controller: "The wall shattered!" and ATTACK rose → SPEED won't go
   higher → SP. DEF rose order.
4. Inventory: two families `represented`, totals and report updated; ROM
   fixture pending.
5. No-ROM `scripts/test_all.sh` and `scripts/check_repository.lua` pass.

## Evidence (Worker, 2026-10-13)

No-ROM: engine 513/0 (was 485), controller 98/0, inventory partition PASS,
new ROM fixture skips cleanly. Independent review NEEDS_FIX
([record](../reviews/2026-10-13-batch4-hit-effects-review.md)); findings 1-7
addressed: SP.DEF gate clause and KO-then-boost tests (engine 521/0), RNG
gap wording, stale Brick Break comments/rows, MISSED-flag limit noted, controller
order assert, timer/flag comment. Finding 8 (coordination docs) left for the
orchestrator. Re-check PASS.
