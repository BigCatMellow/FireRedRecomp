# Task: confusion and flinch, slice C1 (groundwork)

- Task ID: `P4-STATUS2-C1`
- Status: `CLOSED — REVIEWED PASS` ([review](../reviews/2026-10-14-confusion-flinch-c1-review.md))
- Lane: full relay. Owner delegation 2026-10-14 ("Keep going"); battle and
  AI files only, away from in-flight Codex work.
- Design: [confusion/flinch proposal](../reports/phase4-confusion-flinch-design-proposal.md).

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

- `include/constants/battle.h:105-107` status2 confusion turns and flinch.
- `src/battle_util.c:1233-1250` canceller order; `:1361-1371` flinch;
  `:1407-1435` confusion (decrement first, `Random() & 1`, self-hit via
  `CalculateBaseDamage(attacker, attacker, MOVE_POUND, 0, 40, 0, ...)`).
- `src/battle_script_commands.c:1620-1660` `Cmd_adjustnormaldamage2`
  (random multiplier); `data/battle_scripts_1.s:3720-3762` texts/order.
- `src/battle_main.c:2917,2940` flinch cleared between turns;
  `src/battle_script_commands.c:2930-2940` faint clears status2.
- `data/battle_ai_scripts.s:390-395` AI_CBM_Confuse.
- Texts `src/battle_message.c:114,115,123,337`.

## MAY CHANGE

- `src/core/BattleEngine.lua`: battler `confusionTurns`/`flinched`, flinch
  and confusion cancellers, `resolveConfusionSelfHit`, flinch clearing at
  turn start and end-of-turn, faint clearing, events.
- `src/core/AICheckBadMove.lua`: AI_CBM_Confuse status2 branch, header.
- `src/core/BattleSceneController.lua`: four texts.
- Tests: new `tests/battle_confusion_flinch_test.lua`; AI and controller
  additions.

No move applies confusion or flinch yet (slice C2). No main.lua, save or
admission change.

## Design review carry-over (applied to C1)

- F2: Snore's "fast asleep" moved after the flinch/confusion cancellers,
  with flinched / confused / self-hit tests.
- F7: self-hit KO outcomes tested (no replacement ends the battle; with a
  replacement the turn halts and end-of-turn still runs).
- F8: interplay tests (no confusion tick while asleep or frozen; waking and
  thawing continue into flinch/confusion; paralysis after both proceed
  paths).
- F1: flinch-clear citation corrected.

## Evidence (Worker, 2026-10-14)

Confusion/flinch 37/0; AI 43/0; controller 141/0; full suite and
repository checker in the PR.
