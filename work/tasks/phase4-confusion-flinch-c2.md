# Task: confusion and flinch, slice C2 (moves)

- Task ID: `P4-STATUS2-C2`
- Status: `IMPLEMENTED — awaiting independent review`; ROM fixture pending
- Lane: full relay. Owner delegation 2026-10-14 ("Keep going"); battle files.
- Builds on: [C1](phase4-confusion-flinch-c1.md); design
  [proposal](../reports/phase4-confusion-flinch-design-proposal.md) (reviewed,
  corrections applied: F3 flinch turn-order rule, F4 roll draws, F5 Swagger/
  Flatter shape, F10 Inner Focus silent).
- Families (24 moves): 76 Confuse Hit (6), 31 Flinch Hit (6), 150 Flinch/
  Minimize (4), 146 Twister (1), 92 Snore (1), 49 Confuse (3, newly
  admitted), 118 Swagger, 166 Flatter, 199 Teeter Dance (newly admitted).

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

- Scripts `data/battle_scripts_1.s`: 669-671, 902-923, 1068-1070,
  1253-1268, 1604-1625, 1822-1828, 1894-1897, 2147-2168, 2566-2618.
- `src/battle_script_commands.c`: 2132-2146 SetMoveEffect guards (Shield
  Dust `<= 9`, 0 HP); 2405-2439 confusion and flinch; 2774-2804
  seteffectwithchance; 8196-8203 jumpifconfusedandstatmaxed.
- Texts `src/battle_message.c:116,117,273` (plus C1's).
- Records `src/data/battle_moves.h` (24 members, in the ROM fixture).

## MAY CHANGE

- `src/core/BattleEngine.lua`: `STATUS2_HIT_MOVES`, admission, Confuse/Teeter
  Dance and Swagger/Flatter handlers, Snore awake failure, `applyConfusion`,
  `applySecondaryStatus2`, first-mover flinch flag in `runTurn`, events.
- `src/core/BattleSceneController.lua`: three texts, Own Tempo name.
- Tests: confusion/flinch, controller (boundary test now uses EFFECT_ROAR),
  inventory partition, new `tests/phase4_confusion_flinch_effect_rom_test.lua`;
  inventory report rows.

## Acceptance

Roll boundaries and draws (including no-effect, KO, Own Tempo, already
confused, Shield Dust, Dynamic Punch 100%); flinch only from the first mover
of a two-move turn, never after a hoisted action, Inner Focus/Shield Dust
silent, cleared next turn; Snore awake/woken failure and asleep flinch;
Supersonic/Confuse Ray/Teeter Dance gate order with no draws before
accuracy; Swagger/Flatter accuracy-first miss, the confused-and-maxed
failure, silent stat at +6, Own Tempo after the stat; texts; full no-ROM
suite and checker pass.

## Known limits

Substitute, Safeguard, Serene Grace, King's Rock, Fake Out, Rampage and the
Stomp/Twister doubles (Minimize and semi-invulnerability unmodeled).

## Evidence (Worker, 2026-10-14)

Confusion/flinch 72/0; controller 144/0; full suite and repository checker
in the PR.
