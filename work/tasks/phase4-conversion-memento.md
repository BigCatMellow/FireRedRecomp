# Task: Conversion and Memento (fast lane)

- Task ID: `P4-FL6-CONVERSION-MEMENTO`
- Status: `READY_FOR_REVIEWER`
- Lane: [battle-effect fast lane](../../AGENTS.md#battle-effect-fast-lane--human-authorized-2026-10-13)
- Parent: [Phase 4 move/effect matrix](../roadmaps/CAPABILITY_CHECKLIST.md)
- Families: 30 Conversion (160), 168 Memento (262)

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

- `data/battle_scripts_1.s:658-667` Conversion: attackcanceler → attackstring
  → ppreduce → `tryconversiontypechange BattleScript_ButItFailed` →
  `STRINGID_PKMNCHANGEDTYPE`. No accuracycheck.
- `src/battle_script_commands.c:7003-7059` `Cmd_tryconversiontypechange`:
  count leading non-NONE move slots; a `TYPE_MYSTERY` move reads as GHOST if
  the user is Ghost-type, else NORMAL; fail if every slot's type is one of
  the user's; otherwise repeat `Random() & 3` until it names a valid slot,
  repeating the whole draw while that slot's type is the user's; set both
  user types to it.
- `data/battle_scripts_1.s:2199-2232` Memento: attackcanceler → (protected
  branch, not modeled) → attackstring → ppreduce → `trymemento ButItFailed`
  → `setatkhptozero` → (Substitute branch, not modeled) → target ATK −2 and
  SP.ATK −2, each message skipped when it cannot decrease → `tryfaintmon
  BS_ATTACKER`. No accuracycheck.
- `src/battle_script_commands.c:8681-8698` `Cmd_trymemento`: fail only when
  target ATK and SP.ATK are both at minimum (unprotected); otherwise the
  user's HP bar drops instantly. `:6294` `Cmd_setatkhptozero`.
- `src/battle_message.c:122` "{ATK} transformed\ninto the {BUFF1} type!";
  `src/battle_main.c:428` gTypeNames.
- `src/data/battle_moves.h:2083,3409`: records used by the ROM fixture.

## Design and MAY CHANGE

- `src/core/BattleEngine.lua`: constants, admission (power 0; Conversion user
  target, Memento selected target), excluded from accuracy, handlers emitting
  `conversion`/`moveFailed` and `mementoHP` → `statChange` → attacker faint.
  Memento mirrors the first-battle defender-stat-fell tutorial block.
- `src/core/BattleSceneController.lua`: gTypeNames table, Conversion text,
  Memento invisible HP entry before the stat messages.
- Tests: `tests/battle_engine_test.lua`, `tests/battle_scene_controller_test.lua`,
  `tests/phase4_move_effect_inventory_test.lua`, new
  `tests/phase4_conversion_memento_effect_rom_test.lua`;
  `work/reports/phase4-move-effect-inventory.md` rows and summary.

Excluded: Protect (Memento protected branch), Substitute ("But it had no
effect!" branch), Mist/Clear Body/Hyper Cutter on Memento's drops, Snatch,
Magic Coat, doubles, animation. Type change lasts until the battler leaves
(replacement builds a fresh battler).

## Acceptance

1. Conversion, both sides: rejection loop (draws 0,3,1 → FIRE, 3 draws), PP −1;
   all-own types fails with no RNG; Curse reads GHOST for a Ghost user and
   NORMAL otherwise.
2. Memento, both sides: user HP 0 before target ATK/SP.ATK −2 (stage 4),
   then user faint; defender HP untouched; no RNG; PP −1; both at minimum
   fails and user survives; ATK at minimum skipped, SP.ATK clamps at 0.
3. Admission rejects wrong target or nonzero power.
4. Controller: "PLAYER transformed\ninto the FIRE type!"; Memento displayed
   HP is 0 when the first stat message shows.
5. Inventory: both families `represented`, totals and report updated; ROM
   fixture pending. No-ROM `scripts/test_all.sh` and
   `scripts/check_repository.lua` pass.

## Evidence (Worker, 2026-10-13)

No-ROM: engine 560/0 (was 541), controller 102/0, inventory partition PASS,
new ROM fixture skips cleanly. Independent review NEEDS_FIX
([record](../reviews/2026-10-13-conversion-memento-review.md)); findings 1-5
addressed: dual-type Conversion tests (type2 for ??? and own-type checks),
Memento first-battle tip tests, all 18 type names asserted, comment order,
local `d` (engine 568/0, controller 103/0); report admission note updated.
Re-check pending.

## Follow-ups (pre-existing, outside this batch)

- Memento makes the engine's conservative "halt the turn when the first
  mover faints itself" policy the common case; verify against
  HandleFaintedMonActions/target re-selection (`battle_main.c:4110-4130`).
- `AICheckBadMove.lua:616` still errors on effect 168; real
  `AI_CBM_Memento` scoring is missing.
