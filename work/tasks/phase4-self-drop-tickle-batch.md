# Task: self-drop hits and Tickle batch (fast lane)

- Task ID: `P4-FL2-SELF-DROP-TICKLE`
- Status: `READY_FOR_REVIEWER`
- Lane: [battle-effect fast lane](../../AGENTS.md#battle-effect-fast-lane--human-authorized-2026-10-13)
- Parent: [Phase 4 move/effect matrix](../roadmaps/CAPABILITY_CHECKLIST.md)
- Families: 182 Superpower (276), 204 Overheat (315) / Psycho Boost (354), 205 Tickle (321)

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

- `data/battle_scripts_1.s:2383,2640`: Superpower/Overheat `setmoveeffect
  ATK_DEF_DOWN / SP_ATK_TWO_DOWN | AFFECTS_USER | CERTAIN` then EffectHit
  (effect applied by `seteffectwithchance` after damage, before
  `tryfaintmon BS_TARGET`).
- `src/battle_script_commands.c:2774-2805` `Cmd_seteffectwithchance`: CERTAIN
  and not NO_EFFECT → apply, no Random(); otherwise the else-if evaluates
  `Random() % 100` first, so a no-effect hit spends one draw and applies nothing.
- `src/battle_script_commands.c:2110-2141` `SetMoveEffect`: AFFECTS_USER makes
  the attacker the effect battler; skipped only if that battler has 0 HP.
  `:2707,2765` route to `BattleScript_AtkDefDown` / `BattleScript_SAtkDown2`.
- `data/battle_scripts_1.s:3568-3585,3638-3647`: ATK-1 then DEF-1 (SP.ATK-2),
  CERTAIN (Mist/Clear Body bypassed); `cMULTISTRING_CHOOSER == 2`
  (`B_MSG_STAT_WONT_DECREASE`) skips the message for a stat already at -6.
- `data/battle_scripts_1.s:2644-2677` Tickle: ppreduce → `jumpifstat TARGET
  ATK > MIN` → proceed, else `DEF == MIN` → `BattleScript_CantLowerMultipleStats`
  (`STRINGID_STATSWONTDECREASE2`) → `accuracycheck BattleScript_ButItFailed`
  (miss result) → ATK-1, DEF-1, each silently skipped at -6.
- `src/battle_message.c:309,310,312`: Attackers/DefendersStatFell,
  `sText_StatsWontDecrease2` "{DEF}'s stats won't\ngo any lower!".
- `src/data/battle_moves.h:3591,4098,4176,4605`: records used by the ROM fixture.

## Design and MAY CHANGE

- `src/core/BattleEngine.lua`: `SELF_DROP_HIT_MOVES` applied after damage
  (alongside the existing hit-variant step), effect roll spent on no-effect;
  `EFFECT_TICKLE` admitted with power 0 and selected target, both-minimum
  gate before accuracy, `statsWontFall` event.
- `src/core/BattleSceneController.lua`: `statsWontFall` message.
- Tests: `tests/battle_engine_test.lua`, `tests/battle_scene_controller_test.lua`,
  `tests/phase4_move_effect_inventory_test.lua`, new
  `tests/phase4_self_drop_tickle_effect_rom_test.lua`;
  `work/reports/phase4-move-effect-inventory.md` rows 182/204/205.

Excluded: Mist, Protect, Substitute, abilities (Clear Body/White Smoke/
Hyper Cutter/Serene Grace/Shield Dust), Magic Coat, Kings Rock, doubles,
animation, first-battle tutorial interplay (no starter learns these moves).

## Acceptance

1. Superpower/Overheat/Psycho Boost, both sides: drops after damage in
   source order, PP −1, exactly accuracy+crit+damage draws; stat at -6
   skipped silently; -2 clamps at -6 with "harshly" stages; immune hit spends
   one extra draw and drops nothing; miss drops nothing; drop precedes
   defender faint.
2. Tickle, both sides: target ATK then DEF −1 with one accuracy draw; one at
   -6 skipped; both at -6 → `statsWontFall`, PP spent, zero draws; miss lowers
   nothing; admission requires power 0 and selected target.
3. Controller: real engine events give "FOE's ATTACK\nfell!" before
   DEFENSE, the both-minimum text, and "PLAYER's SP. ATK\nharshly fell!".
4. Inventory: three families `represented`, totals updated; ROM fixture
   pending until the next guarded bridge run.
5. No-ROM `scripts/test_all.sh` and `scripts/check_repository.lua` pass.

## Evidence (Worker, 2026-10-13)

No-ROM: engine 438/0 (was 388), controller 92/0, inventory partition PASS,
new ROM fixture skips cleanly. Independent review pending; not self-reviewed.
