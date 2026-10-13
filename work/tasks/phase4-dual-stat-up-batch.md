# Task: two-stat self UP batch (fast lane)

- Task ID: `P4-FL1-DUAL-STAT-UP`
- Status: `READY_FOR_REVIEWER`
- Lane: [battle-effect fast lane](../../AGENTS.md#battle-effect-fast-lane--human-authorized-2026-10-13)
- Parent: [Phase 4 move/effect matrix](../roadmaps/CAPABILITY_CHECKLIST.md)
- Families: effects 206 Cosmic Power (322), 208 Bulk Up (339), 211 Calm Mind (347), 212 Dragon Dance (349)

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

- `data/battle_scripts_1.s:2679-2788`: each script is attackcanceler →
  attackstring → ppreduce → `jumpifstat ATTACKER < MAX first` → anim, else
  `jumpifstat ATTACKER == MAX second` → `BattleScript_CantRaiseMultipleStats`
  (`:2758`, `STRINGID_STATSWONTINCREASE2`). Then `setstatchanger first,1` /
  `statbuffchange AFFECTS_USER|ALLOW_PTR`; message skipped when
  `B_MSG_STAT_WONT_INCREASE`; same for second stat. No accuracycheck, no Random.
- Stat order: Cosmic Power DEF→SPDEF; Bulk Up ATK→DEF; Calm Mind
  SPATK→SPDEF; Dragon Dance ATK→SPEED.
- `src/battle_script_commands.c:6655-6815` `ChangeStatBuffs`: a stat at +6
  stays +6, selects `B_MSG_STAT_WONT_INCREASE`, returns WORKED with ALLOW_PTR.
- `src/battle_message.c:306,311`: `sText_AttackersStatRose`,
  `sText_StatsWontIncrease2` = "{ATK}'s stats won't\ngo any higher!".
- `src/data/battle_moves.h:4189,4410,4514,4540`: power 0, accuracy 0, pp 20,
  target `MOVE_TARGET_USER`, priority 0, `FLAG_SNATCH_AFFECTED`; types
  Psychic(14)/Fighting(1)/Psychic(14)/Dragon(16).

## Design and MAY CHANGE

- `src/core/BattleEngine.lua`: `DUAL_STAT_UP_MOVES` table; admitted only with
  power 0 and user target; no accuracy check; both-at-+6 emits
  `statsWontRise`, else each stat below +6 gets a `statChange` +1 in order.
- `src/core/BattleSceneController.lua`: `statsWontRise` message.
- Tests: `tests/battle_engine_test.lua`, `tests/battle_scene_controller_test.lua`,
  `tests/phase4_move_effect_inventory_test.lua`, new
  `tests/phase4_dual_stat_up_effect_rom_test.lua`.

Excluded: Snatch, Substitute/abilities interplay, the `MOVE_RESULT_MISSED`
bit set for a skipped maxed stat (no represented consumer), animation,
doubles. AI scoring already existed (`AICheckBadMove`) and is unchanged.

## Acceptance

1. Each family, both sides: +1/+1 in source order, PP −1, zero RNG, defender
   untouched; one stat at +6 skipped silently; both at +6 → `statsWontRise`,
   PP still spent; admission rejects non-user target or nonzero power.
2. Controller: real engine events produce "X's ATTACK\nrose!" before
   "X's SPEED\nrose!", and the both-maxed text with no "rose!".
3. Inventory: four families `represented`, admitted; totals updated.
4. ROM fixture: exactly four members with the source-locked records.
   **ROM fixture pending** until the next guarded bridge run's verified-ROM suite.
5. No-ROM `scripts/test_all.sh` and `scripts/check_repository.lua` pass.

## Evidence (Worker, 2026-10-13)

No-ROM: engine 388/0 (was 332), controller 89/0, inventory partition PASS,
new ROM fixture skips cleanly; full suite and repository checker results in
the PR. Independent review pending; not self-reviewed.
