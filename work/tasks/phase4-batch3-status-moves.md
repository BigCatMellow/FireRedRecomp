# Task: batch 3 status moves (fast lane)

- Task ID: `P4-FL3-STATUS-MOVES`
- Status: `READY_FOR_REVIEWER`
- Lane: [battle-effect fast lane](../../AGENTS.md#battle-effect-fast-lane--human-authorized-2026-10-13)
- Parent: [Phase 4 move/effect matrix](../roadmaps/CAPABILITY_CHECKLIST.md)
- Families: 25 Haze (114), 85 Splash (150), 142 Belly Drum (187), 143 Psych Up (244), 157 Softboiled (135 Soft-Boiled, 208 Milk Drink)

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

- `data/battle_scripts_1.s`: none of these scripts has `accuracycheck` or a
  Random() command; each runs attackcanceler → attackstring → ppreduce.
  - Haze `:564-573`: `normalisebuffs`, `STRINGID_STATCHANGESGONE`.
  - Splash `:1168-1177`: `STRINGID_BUTNOTHINGHAPPENED` (game stat ignored).
  - Belly Drum `:1772-1784`: `maxattackhalvehp BattleScript_ButItFailed`,
    attacker HP update, then `STRINGID_PKMNCUTHPMAXEDATTACK`.
  - Psych Up `:1786-1795`: `copyfoestats`, `STRINGID_PKMNCOPIEDSTATCHANGES`.
  - Softboiled `:2023-2042`: `tryhealhalfhealth BattleScript_AlreadyAtFullHp,
    BS_TARGET` (target is the user for these MOVE_TARGET_USER moves); same
    outcome as the accepted Restore HP path.
- `src/battle_script_commands.c`: `Cmd_normalisebuffs` `:6826` (all battlers,
  all stages → default); `Cmd_maxattackhalvehp` `:8399` (half = maxHP/2 or 1;
  succeed only if ATK < MAX and HP > half; ATK = MAX; damage = half);
  `Cmd_copyfoestats` `:8423` (copy all stages; unused fail pointer).
- `src/battle_message.c:124,125,209,210,335,356`: message texts.
- `src/data/battle_moves.h:1485,1758,1953,2434,2707,3175`: records.

## Design and MAY CHANGE

- `src/core/BattleEngine.lua`: five effect constants; admission (power 0;
  user target, Psych Up selected target, Softboiled literal IDs 135/208);
  excluded from accuracy; handlers emitting `splash`, `haze`, `psychUp`,
  `bellyDrum`/`moveFailed`; Softboiled reuses the Restore HP events.
- `src/core/BattleSceneController.lua`: four messages; Belly Drum HP entry
  precedes its message.
- Tests: `tests/battle_engine_test.lua`, `tests/battle_scene_controller_test.lua`,
  `tests/phase4_move_effect_inventory_test.lua`, new
  `tests/phase4_batch3_status_effect_rom_test.lua`;
  `work/reports/phase4-move-effect-inventory.md` rows and summary.

Excluded: Substitute (Belly Drum ignore-substitute marker), Snatch, Protect
on Haze/Milk Drink, game stat counter, animation, doubles. Restore HP's
existing project wording is reused for Softboiled.

## Acceptance

1. Both sides, zero RNG, PP −1 each: Splash event only; Haze resets all
   seven stages of both battlers; Psych Up copies all seven target stages;
   Belly Drum success (ATK +6, HP −50 at maxHP 101), boundary HP 51 succeeds,
   HP 50 fails, ATK +6 fails, maxHP 1 fails; Soft-Boiled/Milk Drink heal 50,
   clamp at max, fail at full.
2. Admission rejects wrong target, and Softboiled outside IDs 135/208.
3. Controller texts for Splash, Haze, Psych Up, Belly Drum; Belly Drum
   displayed HP changes before its message.
4. Inventory: five families `represented`, totals updated; ROM fixture pending.
5. No-ROM `scripts/test_all.sh` and `scripts/check_repository.lua` pass.

## Evidence (Worker, 2026-10-13)

No-ROM: engine 483/0 (was 440), controller 96/0, inventory partition PASS,
new ROM fixture skips cleanly. Independent review pending; not self-reviewed.
