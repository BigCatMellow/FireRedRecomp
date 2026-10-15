# Task: residual slice R1 — Leech Seed, Nightmare, Curse, Rapid Spin's seed arm, deferred team check

- Task ID: `P4-RESIDUAL-R1`
- Status: `DONE — independently reviewed PASS WITH CORRECTIONS (applied)`
- Lane: full relay (new battle-only volatile state, new end-of-turn output,
  a deferred team-loss check)
- Spec: [residual effects design proposal](../reports/phase4-residual-effects-design-proposal.md)
  (R1 parts), status `independently reviewed PASS WITH CORRECTIONS
  (applied)`, with the [design review](../reviews/2026-10-15-residual-effects-design-review.md)
  folded in: F1, F2 (deferred team check on `faintSequence`), F3 (Curse
  accuracy by attacker type), F5 (nil-guarded controller calls; R1 adds
  none), F7 (signed capped-stat `stages`), F8 where relevant, decisions D1
  (seed arm only; Ingrain is R2) and D2 (accepted).
- Base: `3e9d6f3` on `claude/wizardly-faraday-o45q9z` (origin/main plus the
  proposal and its review).

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

Abbreviations: `bsc.c` `src/battle_script_commands.c`, `bs1.s`
`data/battle_scripts_1.s`, `bu.c` `src/battle_util.c`, `bm.c`
`src/battle_main.c`, `msg.c` `src/battle_message.c`, `ai.s`
`data/battle_ai_scripts.s`, `moves.h` `src/data/battle_moves.h`.

- **Records** (`moves.h`): Leech Seed 73 `:952-963` (effect 84, power 0,
  Grass, acc 90, PP 10, SELECTED, flags 0x16); Nightmare 171 `:2226-2237`
  (107, 0, Ghost, 100, 15, SELECTED, 0x12); Curse 174 `:2265-2276` (109, 0,
  Mystery, 0, 10, SELECTED, 0); Rapid Spin 229 `:2980-2991` (129, 20,
  Normal, 100, 40, chance 0, SELECTED, 0x33). Liquid Ooze = ability 64.
- **Leech Seed** `bs1.s:1153-1166`: attackcanceler, attackstring, ppreduce,
  (Substitute), `accuracycheck BattleScript_DoLeechSeed, ACC_CURR_MOVE` —
  the miss pointer is the success label. A semi-invulnerable target misses
  with no draw (`bsc.c:958-1001`). `Cmd_setseeded` `bsc.c:6436-6456`:
  `MOVE_RESULT_NO_EFFECT` or already seeded → `B_MSG_LEECH_SEED_MISS`;
  Grass in either type → `B_MSG_LEECH_SEED_FAIL`; else OR the attacker slot
  and `STATUS3_LEECHSEED`. No typecalc. Texts `msg.c:159`, `:160`, `:70`
  via `gLeechSeedStringIds` `:964-971`.
- **Drain** `bu.c:789-804`: seeded, receiver slot `hp != 0`, own `hp != 0`;
  `max(1, maxHP/8)`. `BattleScript_LeechSeedTurnDrain` `bs1.s:3223-3243`:
  seeded HP update; `copyword gBattleMoveDamage, gHpDealt`; Liquid Ooze on
  the seeded battler → damage, else `manipulatedamage 0` → heal; receiver HP
  update; text (`msg.c:161` / `:290`); `tryfaintmon BS_ATTACKER` then
  `BS_TARGET`; **no `checkteamslost`**.
- **Team check**: `DoTurnDmg` `bs1.s:3676-3688` (`tryfaintmon`, then
  `checkteamslost` on every tick); `Cmd_checkteamslost` `bsc.c:3385-3420`
  (LOST/WON ORed, both = DREW); `BattleTurnPassed` `bm.c:2953-2965` (only a
  set outcome stops `DoBattlerEndTurnEffects`); `HandleFaintedMonActions`
  `bu.c:1143`, `bs1.s:2824-2826`.
- **Clearing**: switch-in zeroes the incoming slot's own bits
  (`bm.c:2365-2368`); faint zeroes the fainted battler's
  (`bm.c:2441-2442`); nothing clears another battler's seed whose receiver
  is that slot (`bm.c:2329-2452`).
- **Nightmare** `bs1.s:1455-1469`: no accuracycheck, no typecalc; already
  nightmared / not asleep → But it failed (`msg.c:336`); success
  `msg.c:198`. End of turn `bu.c:841-860`: asleep → text `msg.c:199`
  (`bs1.s:3791-3795`) then `max(1, maxHP/4)`; awake → silent clear. Wake-up
  in the canceller clears it (`bu.c:1300`).
- **Curse** `bs1.s:1478-1526`: `jumpiftype2 BS_ATTACKER, TYPE_GHOST`
  (`bsc.c:3826-3834`, type1 or type2) before attackcanceler. Non-Ghost: no
  accuracycheck; fails only at Speed −6, Attack +6, Defense +6
  (`:1483-1485`); three `statbuffchange AFFECTS_USER | ALLOW_PTR` (Speed −1,
  Attack +1, Defense +1), which return WORKED at a cap and print "won't go
  lower/higher" (`bsc.c:6772-6775`, `:6799-6810`); Mist/Protect/Clear Body
  exempt `MOVE_CURSE` (`:6679-6704`). Ghost: `NO_ACC_CALC_CHECK_LOCK_ON`
  (semi-invulnerable → But it failed, no draw, `bsc.c:1020-1025`);
  `Cmd_cursetarget` `bsc.c:8093-8108` (already cursed → fail; else cost
  `max(1, maxHP/2)`); HP update, text `msg.c:200`, `tryfaintmon
  BS_ATTACKER` (`bs1.s:1521-1525`). End of turn `bu.c:861-871`, text
  `msg.c:201` (`bs1.s:3797-3801`), `max(1, maxHP/4)`.
- **Rapid Spin** `bs1.s:1711-1713`: `MOVE_EFFECT_RAPIDSPIN | AFFECTS_USER |
  CERTAIN`; `Cmd_seteffectwithchance` `bsc.c:2774-2805` (CERTAIN and not
  NO_EFFECT → no draw; else `Random() % 100`); `Cmd_rapidspinfree`
  `bsc.c:8435-8469` else-if chain (WRAPPED, else LEECHSEED → `msg.c:212`,
  `bs1.s:3451-3454`, else Spikes); runs before `tryfaintmon BS_TARGET`.
- **Order** `bu.c:720-742`: Ingrain, Abilities (Rain Dish), Items1, Leech
  Seed, Poison, Toxic, Burn, Nightmare, Curse, Wrap, Uproar, Thrash; one
  battler's list before the next (`:749-757`, `:1051-1054`); field cases
  first (`bm.c:2958-2963`).
- **AI** `ai.s`: `AI_CBM_Nightmare` `:237-240` (nightmared −10, then awake
  −8); `AI_CBM_LeechSeed` `:414-420` (seeded −10, then Grass type1/type2
  −10); `AI_CBM_Curse` `:438-441` (Attack 12 −10, Defense 12 −8, no Ghost
  test).

## Design (as implemented)

- `BattleEngine` constants `EFFECT_LEECH_SEED`, `EFFECT_NIGHTMARE`,
  `EFFECT_CURSE`, `EFFECT_RAPID_SPIN`, `ABILITY_LIQUID_OOZE`, `TYPE_GHOST`,
  `TYPE_GRASS`. `makeBattler` fields `seeded`, `nightmare`, `cursed`
  (battle-only; the persist bridge writes HP/status1/PP only). The seed's
  receiver is the opposing **slot** (`otherSide(side)`), so it heals a
  voluntary or forced replacement.
- `recordFaint` also clears the three fields.
- `supportsMove` admits 84, 107 and 109 at power 0, target SELECTED.
- Early branches beside Refresh (after the cancellers and `useMove`), each
  with its own accuracy step, so the shared accuracy predicates never see
  these effects (F3):
  - Leech Seed: PP, `accuracyRoll` (semi-invulnerable → miss, no draw),
    then `leechSeed{side, target, result="evaded"|"noEffect"|"seeded"}`.
  - Nightmare: PP; `moveFailed` when already nightmared or awake; else set
    and `nightmare{side, target}`.
  - Curse: PP; non-Ghost → the −6/+6/+6 fail, else three `statChange`
    events (prevented ones carry signed `stages`, F7); Ghost →
    `moveFailed` for a semi-invulnerable or cursed target, else set
    `cursed`, cost `min(hp, max(1, floor(maxHP/2)))`,
    `curseLaid{side, target, amount, hpRemaining}`, `checkFaint(attacker)`.
- The sleep canceller's wake-up clears `nightmare`.
- Rapid Spin: in the landed branch (Smelling Salt site) a living seeded user
  clears the seed and emits `leechSeedFreed{side}`; `EFFECT_RAPID_SPIN`
  joins the no-effect discarded-roll list.
- `resolveStatusEndTurn` per battler: Rain Dish, Leech Seed (with Liquid
  Ooze; one `leechSeedDrain{side, receiver, ooze, amount, hpRemaining,
  receiverAmount, receiverHpRemaining}`), poison/toxic/burn, Nightmare
  (`nightmareDamage` or silent clear), Curse (`curseDamage`), the rampage
  tick.
- Deferred team check (D2 with F1/F2), on the existing `faintSequence`, no
  separate list:
  - a Leech Seed KO opens the sequence lazily and records the seeded, then
    the receiver (no finalize);
  - after each damage tick, if the ticking battler is at 0 HP or a
    sequence is open: open if needed, `recordFaint(tickingSide)` only,
    `finalizeFaintSequence`; then `if isOver() then break end` (F1);
  - after the loop an open sequence is finalized (the loop only `break`s).
  With no seed KO this is exactly the previous per-tick `checkFaint`.
- Controller texts (names without the Wild/Foe prefix, as every controller
  text): "X was seeded!", "X evaded\nthe attack!", "It doesn't affect X..."
  (the existing generic noEffect form), drain = seeded HP, receiver HP, then
  "X's health is\nsapped by LEECH SEED!" or "It sucked up the\nLIQUID
  OOZE!"; "X shed\nLEECH SEED!"; "X fell into\na NIGHTMARE!"; "X is
  locked\nin a NIGHTMARE!" then HP; HP then "X cut its own HP and\nlaid a
  CURSE on Y!"; "X is afflicted\nby the CURSE!" then HP. R1 adds no new
  controller call into the engine, so F5 needs no guard here.
- `AICheckBadMove`: `leechSeed` gains the seeded −10 test before Grass;
  `nightmare` gains the nightmared −10 test before the sleep test. `curse`
  and every dispatch row are unchanged.
- Separate commit (F7 follow-up): the pure stat-move path's prevented event
  carries the signed delta, so a self-target UP move at +6 prints "won't go
  higher!".

## File ownership

- **MAY CHANGE:** `src/core/BattleEngine.lua`;
  `src/core/BattleSceneController.lua` (controller MAY CHANGE: texts);
  `src/core/AICheckBadMove.lua` (only the Leech Seed, Nightmare and Curse
  handlers/rows; the file is shared with the Memento owner);
  `tests/battle_residual_r1_test.lua` (new),
  `tests/phase4_residual_r1_effect_rom_test.lua` (new),
  `tests/phase4_move_effect_inventory_test.lua`,
  `tests/battle_engine_test.lua` (F7 follow-up only);
  `work/reports/phase4-move-effect-inventory.md`,
  `work/reports/phase4-residual-effects-design-proposal.md` (review fold),
  this task file.
- **MUST NOT CHANGE:** `main.lua` (main.lua MUST NOT CHANGE), party/Dex
  code, coordination and roadmap files, `BattleFormulas.lua`,
  `TrainerAI.lua`, any other `AICheckBadMove.lua` row or handler.

## Changed assertions

- `tests/battle_engine_test.lua` (F7 follow-up commit): the Swords Dance
  at +6 prevented event now has `stages == 2` (was `0`) and the Sand
  Attack at −6 prevented event `stages == -1` (was `0`). Reason: source
  prints "won't go higher!" for an UP move at the cap
  (`bsc.c:6799-6810`); the controller needs the sign. Both checks also pin
  the unchanged stage.
- `tests/phase4_move_effect_inventory_test.lua`: rows 84, 107, 109 →
  `represented`, admitted; row 129 → `represented`; totals admitted
  292 → 295, rejected 62 → 59, admitted uncovered positive 33 → 32;
  represented 118/259/182/77 → 122/263/183/80; blocked 79/94/33/61 →
  75/90/32/58. Reason: the R1 admissions and coverage.
- No other existing assertion changed.

## Acceptance

- `tests/battle_residual_r1_test.lua`: 103 checks, exact `scriptedRng` draw
  counts:
  - Admission, defaults.
  - Leech Seed: hit (1 draw, PP, text); miss → "evaded" (1 draw, no
    generic miss); already seeded → "evaded" after the hitting draw; Grass
    (type2) → noEffect with the draw spent; a miss vs Grass → "evaded";
    semi-invulnerable air/underground/underwater → "evaded", 0 draws; Ghost
    target seeded.
  - Drain: same-turn drain (10/10, 1 draw total), presentation order;
    minimum 1; full-HP receiver (0 heal, text kept); clamp at the seeded
    HP (heal = actual loss); seed KO with a foe replacement →
    `forcedSwitchNeeded` after the phase; the seeded battler switching out
    loses it; **seeder-slot semantics**: the voluntary replacement gets the
    heal; a pending forced replacement (receiver slot at 0 HP) skips the
    drain and keeps the seed, and the forced replacement gets the next heal.
  - Liquid Ooze: receiver damage and text; ooze double KO: seeded faints
    first, then the receiver, then `playerDrew` from the post-phase check.
  - Deferred team check: seed KO, then the player's non-fatal poison →
    `playerWon` with exactly one `faint`; fatal poison → `playerDrew`, one
    faint per side; **F1**: Curse and rampage pending on the player do not
    run after `battleEnd` (no draw, counter untouched); no later tick →
    the player's Rain Dish and rampage tick run, then `battleEnd`; **F2**:
    mid-turn foe faint then the player's poison tick → one foe faint, one
    forced switch, "fainted!" once; seed KO with a replacement → the tick
    finalizes once and the player's Curse still runs; the foe's seed KOs the
    player and the foe's burn decides `playerLost`.
  - Nightmare: awake fail (0 draws); sleeping Normal target works (0
    draws); repeat fail; tick `maxHP/4` with text before HP; minimum 1;
    silent clear when awake; **lifecycle**: the canceller wake-up clears it
    (no tick that turn); still asleep → `fastAsleep` then the tick; faint
    clears all three fields.
  - Curse non-Ghost: Speed −1/Attack +1/Defense +1, 0 draws; −6/+6/+6
    fails; **caps**: −6/+6/+5 gives signed prevented events and the texts
    "won't go lower!", "won't go higher!", "rose!"; four other cap
    combinations play; **vs a semi-invulnerable target** (air, underground)
    it plays (F3).
  - Curse Ghost: cost at odd maxHP (41 → 20) with HP-then-text; Ghost in
    type2; cursed target fails with no cost; **semi-invulnerable target**
    (all three states) fails with 0 draws and no cost; 1-HP user self-KO →
    `playerLost`, the foe never moves; maxHP 1 costs 1; tick `maxHP/4` and
    text order; a fatal tick ends the battle.
  - Order: sandstorm (field) < Leech Seed < poison < Curse < rampage on one
    battler with exact HP; Rain Dish < Leech Seed < Nightmare < Curse;
    one whole list per battler; a Dig user still ticks.
  - Rapid Spin: landed hit frees the seed with 3 draws (no 4th); on a KO
    the shed precedes the faint; unseeded plain hit; **vs a Ghost** the
    discarded `% 100` makes 4 draws and the seed stays; a miss draws 1.
  - AI rows: Leech Seed 0 / seeded −10 / Grass type2 −10; Nightmare asleep
    0, awake −8, nightmared −10 (asleep or awake); Curse 0, Defense 12 −8,
    Attack 12 −10 for a Ghost user; the live engine battler feeds the AI.
  - Controller through the real engine: the Leech Seed turn's texts in
    order and the HP bars after the drain.
- `tests/phase4_residual_r1_effect_rom_test.lua`: exact 4-member records;
  skips without a ROM (ROM fixture pending).
- `tests/battle_engine_test.lua`: the F7 follow-up check of the controller
  text "won't go higher!" for Swords Dance at +6.
- Mutation spot-checks (each restored from a backup copy, `cmp` clean):
  no `break` after the status tick (F1) fails 1; no post-loop finalize
  fails 3; the tick ignoring an open sequence fails 2; an immediate
  `checkFaint` at the seed KO (D2 off) fails 9; no Rapid Spin no-effect
  roll fails 1; no Ghost Curse semi-invulnerable check fails 3; no
  canceller Nightmare clear fails 1; already-seeded not evaded fails 1; no
  silent Nightmare clear fails 1.
- `bash scripts/test_all.sh` (187 files) and `lua5.1
  scripts/check_repository.lua` pass.

## Deviations from the design

- `clearHeldBy` is not added: R1 has no field held on the **other**
  battler (the seed stays on the seeded battler and is never cleared by
  the seeder's switch or faint). The helper lands with R2's
  `escapePrevented` (and R3's wrap fields). The fainted battler's own
  fields are cleared in `recordFaint`.
- Leech Seed, Nightmare and Curse are early branches with their own
  accuracy step, not entries in the shared predicates and the `:2239`
  branch. This is the shape the folded design (F3) recommends.
- The Grass `noEffect` text uses the controller's existing generic form
  "It doesn't affect X..." rather than source's line break and ellipsis
  glyph, for consistency with the other immune texts.
- Leech Seed does not take the Oak first-battle accuracy skip; no first
  battle can contain it (Bulbasaur learns it at 7).

## Known limits and follow-ups

- Not represented: Substitute (every check is "false"), Magic Coat, Baton
  Pass carry-over, Lock-On, Protect, the Shed Skin/Heal Bell/Uproar/berry
  Nightmare clears, Spikes, Liquid Ooze on Absorb-family drains (D5).
- Risk R2 (mid-turn replacement timing) is unchanged: a seeder that
  fainted mid-turn gives no drain that turn; source's replacement, already
  in the slot, would receive it. Tests pin the skip.
- Follow-up (out of scope): a secondary UP stat effect at +6 (e.g. Metal
  Claw, `HIT_VARIANT_STAT_MOVES`) emits a prevented event with
  `stages = 0` ("won't go lower!"); source's `SetMoveEffect` calls
  `ChangeStatBuffs` without `ALLOW_PTR`, which returns
  `STAT_CHANGE_DIDNT_WORK` at +6, so the effect is silent
  (`bsc.c:2516-2536`, `:6812-6813`).
- Follow-up (out of scope, shared file): `AICheckBadMove.lua`'s header
  "CONFIRMED NO-OP CLASS" paragraph still says no code path sets status2
  beyond confusion/flinch or status3; that is no longer true for
  Nightmare and Leech Seed. Only the rows/handlers R1 needs were changed,
  as the task requires.
- ROM fixture pending for the four records.

## Review (2026-10-15)

[Implementation review](../reviews/2026-10-15-residual-r1-implementation-review.md):
PASS WITH CORRECTIONS. F1 applied: two new checks pin the F1 stop after a
deciding Nightmare tick (no Curse tick follows) and after a deciding Curse tick
(no rampage tick follows); the reviewer's surviving mutants M19/M20 now each
fail one check. `tests/battle_residual_r1_test.lua`: 105 passed. F2 (stale
AICheckBadMove no-op comments, shared file), F3 (proposal leftovers:
`clearHeldBy` now belongs to R2), F4 (secondary +6 raise text, separate
ticket) and F5 recorded.
