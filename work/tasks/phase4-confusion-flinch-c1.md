# Task: confusion and flinch, slice C1 (groundwork)

- Task ID: `P4-STATUS2-C1`
- Status: `IMPLEMENTED — awaiting independent review`
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

## Evidence (Worker, 2026-10-14)

Confusion/flinch 27/0; AI 43/0; controller 141/0; full suite and
repository checker in the PR.
