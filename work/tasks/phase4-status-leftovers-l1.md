# Task: status leftovers, slice L1 (Tri Attack, Twineedle, Blaze Kick, H1)

- Task ID: `P4-STATUS-LEFTOVERS-L1`
- Status: `IMPLEMENTED — awaiting independent review`; ROM fixture pending
- Design: [proposal](../reports/phase4-status-leftovers-design-proposal.md)
  (L1 parts), independently reviewed
  [PASS WITH CORRECTIONS](../reviews/2026-10-14-status-leftovers-design-review.md);
  F1-F8 applied in the proposal, F1/F2/F5/F6 also in the implementation.
- Lane: full relay (RNG-visible changes to three admitted families).
- Builds on: status S1-S4, confusion/flinch C1-C2, multi-turn M1-M3.
- Families (3 moves, already admitted as plain hits): 36 Tri Attack (161),
  77 Twineedle (41), 200 Blaze Kick (299).

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

`data/battle_scripts_1.s:224,239-268,364-366,613-655,731-733,1072-1080`;
`src/battle_script_commands.c:588,1170-1206,2110-2147,2176-2301,2466-2475,
2774-2805,3469-3478,4103-4116`; `include/constants/battle.h:223-230`;
records `src/data/battle_moves.h:536-547,2096-2107,3890-3901`; text
`src/battle_message.c:82,94,98,104`.

## MAY CHANGE

- `src/core/BattleEngine.lua`:
  - H1: `CRIT_STAGE_EFFECTS` and `critStageFor(attacker, move)`, used at
    the ordinary hit, Explosion, `resolveMultiHit` and `resolveTripleKick`
    (replacing the inline 43/209/75 test and the three literal 0 stages).
  - `STATUS_HIT_MOVES[200] = "burn"`.
  - `EFFECT_TRI_ATTACK`, `TRI_ATTACK_KINDS`, the Tri Attack tail after the
    status-hit block (outer guards Shield Dust, HP > 0, whole-word
    `status ~= 0`; then `% 3`; then `applySecondaryStatus(..., false)`),
    and effect 36 in the no-effect roll list.
  - `MULTI_HIT_MOVES[77] = { fixed = 2, statusKind = "poison" }` and the
    `statusKind` source tail in `resolveMultiHit` (break on KO, count of
    hits landed, one trailing roll, caller's faint; no-effect exit draws
    the roll).
  - Comments named by review F5 for L1 (header family notes,
    `resolveMultiHit` doc, `MULTI_HIT_MOVES` comment).
- `src/core/BattleSceneController.lua`: the `multiHit` comment only.
- Tests: new `tests/battle_status_leftovers_test.lua` and
  `tests/phase4_status_leftovers_effect_rom_test.lua`; inventory rows 36,
  77, 200 → `represented`; report rows and counts.

## MUST NOT CHANGE

Double Kick and the 2-5 multi-hit family (29/44) keep their in-loop faint
shape (review F1: separate follow-up). `AICheckBadMove.lua` (no CBM entry
for 36/77/200; the row-47 comment is L2), `main.lua`, the party/Dex code,
the save and party bridges, coordination/roadmap files.

## Acceptance checks

- Tri Attack draws accuracy, crit, random, `% 100`, then `% 3` only when
  the roll passed and the target is alive, has no Shield Dust and has a
  zero status1 word. `% 3` = 0/1/2 gives burn/freeze/paralysis. Fire/Water
  Veil, Ice/Magma Armor and Limber fail silently after the draw. A Ghost
  target draws `% 100`; a miss draws accuracy only. Freeze cancels the
  target's multi-turn lock.
- Twineedle draws accuracy, (crit, random) × hits, then exactly one
  `% 100`. A KO on hit 1 or 2 gives the hit count, the roll, then the
  faint (and then `forcedSwitchNeeded` with a replacement). Shield Dust,
  Immunity, Poison/Steel types and an existing status fail silently.
- Blaze Kick crits at stage 1 (`% 8`) where stage 0 is `% 16`; burns on
  `% 100 <= 10`; Fire type, Water Veil and Shield Dust silent; a frozen
  target is not burned and is thawed after the hit.
- H1 is called once per critcalc at each of the four sites and its stage
  reaches `critRoll`; every other effect stays at stage 0.

## Known limits

Focus Energy (L2), Battle Armor/Shell Armor before the crit draw, Scope
Lens/Lucky Punch/Stick, Serene Grace, Synchronize, Safeguard, Substitute,
sun blocking Tri Attack's freeze, Wonder Guard on Twineedle, contact
abilities and Flash Fire on Blaze Kick. The 29/44 multi-hit KO tail and
trailing draw (separate follow-up, see the proposal).

## Evidence (Worker, 2026-10-14)

- `lua5.1 tests/battle_status_leftovers_test.lua`: 101 passed, 0 failed
  (scripted RNG with exact draw counts: H1 table and a spy at all four
  sites; Blaze Kick `%8` vs Ember `%16`, burn, immunities, defrost, miss,
  KO; Tri Attack every `%3` value, roll boundary 20/21, statused,
  counter-only word, Shield Dust, KO via `runTurn`, the five silent inner
  immunities, freeze lock cancel, Ghost, miss, no defrost; Twineedle two
  hits and one roll, KO on hit 1 and hit 2 via `runTurn`, KO with a
  replacement, Shield Dust/Immunity/Poison/Steel/statused, miss, synthetic
  no-effect, end-of-turn poison; Double Kick unchanged; controller text
  order). Mutation-checked: `hasAny` for the status guard, dropping 36 from
  the no-effect list, the in-loop faint for 77, dropping 200 from H1, each
  outer Tri Attack guard, the no-effect roll and `hits` = rolled count each
  fail at least one check.
- `tests/phase4_status_leftovers_effect_rom_test.lua`: skips without a ROM.
- Inventory rows 36, 77, 200 → `represented`; partition counts 108/249
  represented, 89/104 blocked, 34 admitted uncovered positive.
