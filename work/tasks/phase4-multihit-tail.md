# Task: multi-hit KO tail for 29/44 (and Twineedle's effectiveness text)

- Task ID: `P4-MULTIHIT-TAIL`
- Status: `IMPLEMENTED — awaiting independent review`
- Spec: [proposal follow-up](../reports/phase4-status-leftovers-design-proposal.md)
  ("Follow-up: multi-hit KO tail for 29/44"), from
  [design review](../reviews/2026-10-14-status-leftovers-design-review.md) F1
  and [L1 implementation review](../reviews/2026-10-14-status-leftovers-l1-implementation-review.md)
  F1/F2.
- Families: 29 `EFFECT_MULTI_HIT` (12 moves), 44 `EFFECT_DOUBLE_HIT`
  (Double Kick, Bonemerang); 77 `EFFECT_TWINEEDLE` for the text change only.

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

- `data/battle_scripts_1.s:605-655` (EffectMultiHit, MultiHitLoop,
  MultiHitNoMoreHits, MultiHitPrintStrings, MultiHitEnd), `:838-846`
  (EffectDoubleHit), `:1072-1080` (EffectTwineedle).
- `src/battle_script_commands.c:1930-2010` (resultmessage), `:2774-2805`
  (seteffectwithchance), `:3480-3498` (movevaluescleanup,
  decrementmultihit), `:6857-6880` (setmultihitcounter,
  initmultihitstring).
- `src/data/battle_moves.h`: every 29/44 record has
  `secondaryEffectChance = 0`; Twineedle 20.

## Source behaviour verified

- A KO on any hit leaves the loop for `MultiHitPrintStrings` (via
  `jumpifhasnohp BS_TARGET`, `:615`, or `decrementmultihit` reaching 0 and
  `goto`, `:640-641`). It prints `resultmessage` (`:644`), then "Hit N
  time(s)!" with N = hits landed (`:646-649`), then `seteffectwithchance`
  (`:651`), then `tryfaintmon BS_TARGET` (`:653`).
- Trailing roll: 29/44 run `setbyte sMULTIHIT_EFFECT, 0` (`:612`, `:845`),
  so the effect byte is 0 and `MOVE_EFFECT_CERTAIN` is clear. The `else if`
  then evaluates `Random() % 100 <= percentChance` first (`bsc.c:2789`), so
  the draw happens whatever the byte and the chance (0) are, and nothing is
  applied. It is reached on landed paths and on the no-effect path
  (`:624` -> `:642-647` -> `:651`). Only a miss (`PrintMoveMissed`) skips
  it.
- Effectiveness: the loop body has `critmessage` but no `resultmessage`;
  the single `resultmessage` reports the last landed hit's flags
  (`movevaluescleanup` resets them per hit). On the no-effect path it is
  "It doesn't affect..." and no count follows.

## Changes

- `src/core/BattleEngine.lua`:
  - `MULTI_HIT_MOVES[29/44/77]` gain `sourceTail = true`; `resolveMultiHit`
    selects the source tail with `entry.sourceTail` instead of
    `entry.statusKind` (L1 review F2). The non-source branch is retained
    for an entry without the flag; no current entry uses it.
  - Source tail: per-hit `damage` events carry `superEffective = false`,
    `notVeryEffective = false`; the `multiHit` event carries the last hit's
    flags. The trailing roll is drawn for every source-tail entry and only
    an entry with `statusKind` applies a status.
  - Header family note, `MULTI_HIT_MOVES` comment and `resolveMultiHit`
    doc updated.
- `src/core/BattleSceneController.lua`: the `multiHit` handler prints the
  effectiveness line before "Hit N time(s)!".

## Event changes

- Engine, 29/44 KO on any hit: `resolveMultiHit` no longer emits
  `faint`/`battleEnd`/`forcedSwitchNeeded` itself; it emits
  `multiHit{hits=N}` and the caller's faint check (runTurn) emits `faint`,
  then `battleEnd` or `forcedSwitchNeeded`.
- Engine, 29/44: one more RNG draw on landed and no-effect paths.
- Engine, 29/44/77: `damage` events from the multi-hit loop have both
  effectiveness flags false; `multiHit` has `superEffective` and
  `notVeryEffective`.
- Controller: "Hit N time(s)!" now precedes "X fainted!" for 29/44; the
  effectiveness line appears once, immediately before the count, instead
  of after each hit (29/44/77).

## Tests

- New: `tests/battle_multihit_tail_test.lua` (Double Kick and Fury Attack:
  KO on hit 1, the middle hit and the last hit, with and without a
  replacement; landed no-KO; no-effect vs Ghost; effectiveness once;
  controller order; Twineedle and Triple Kick unchanged).
- Intentionally updated, with source citations in comments:
  - `tests/battle_engine_test.lua`: Double Kick 5 -> 6 draws; Double Slap
    8 -> 9; Fury Attack 13 -> 14 and 7 -> 8; the type-immune multi-hit
    3 -> 4; the mid-sequence KO block now asserts `multiHit hits=1` from
    `resolveMove`, no in-loop faint, 5 draws, and the faint from the
    caller's `checkFaint` (it asserted faint/battleEnd inside the move and
    no `multiHit`).
  - `tests/battle_status_leftovers_test.lua`: "Double Kick KO keeps the
    older shape" now asserts the source tail (4 draws, `multiHit`, no
    in-loop faint); new controller check for Twineedle vs Grass printing
    "It's super effective!" once, before "Hit 2 time(s)!".

## Not changed

- Triple Kick (104): its own loop, still per-kick effectiveness text and no
  trailing roll (inventory row 104).
- Endure / Focus Band (`MOVE_RESULT_FOE_ENDURED` break, `:639`), Serene
  Grace, Synchronize and per-hit MOVEEND reactions are not represented.
