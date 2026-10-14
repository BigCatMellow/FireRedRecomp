# Task: primary status conditions, slice S3 (primary status moves)

- Task ID: `P4-STATUS-S3`
- Status: `CLOSED — REVIEWED PASS` ([review](../reviews/2026-10-14-status-s3-review.md)); ROM fixture pending
- Lane: full relay. Owner delegation 2026-10-14; battle and AI files only,
  away from in-flight Codex work (main.lua, party/Dex, coordination). The AI
  edit is limited to the STATUS1 branches; the Memento AI gap is untouched.
- Builds on: [S1](phase4-status-s1-groundwork.md), [S2](phase4-status-s2-status-hit.md);
  design [proposal](../reports/phase4-status-conditions-design-proposal.md) §4.
- Families: 1 Sleep (6), 66 Poison (2), 67 Paralyze (3), 33 Toxic (1),
  167 Will-O-Wisp (1): 13 zero-power moves, newly admitted.

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

- Scripts `data/battle_scripts_1.s`: Sleep `:287-301`, Poison `:984-1003`,
  Paralyze `:1005-1024`, Toxic `:687-706`, Will-O-Wisp `:2170-2185`; failure
  scripts `:303-307,315-319,708-718,1025-1035,2054-2066,2187-2197`.
  attackstring/ppreduce precede every gate; gates are RNG-free; one
  accuracycheck; `seteffectprimary` (SetMoveEffect primary) applies, with
  the sleep duration draw.
- `src/battle_script_commands.c:6546-6566` `Cmd_jumpifcantmakeasleep`
  (Insomnia/Vital Spirit → stayed-awake text; Uproar unmodeled);
  `:1240-1272` `ModulateDmgByType` (power-0 moves only gain
  DOESNT_AFFECT_FOE, never effectiveness text); `:1930-2016`
  `Cmd_resultmessage` (DOESNT_AFFECT wins over FAILED → "It doesn't affect").
- AI `data/battle_ai_scripts.s:216-222,237-245,344-355,401-407,430-432,
  535-543,567-569`: the `if_status`/`if_not_status` STATUS1 branches.
- Texts `src/battle_message.c:83,85,91,97,107,174` and the S2 texts.
- Records `src/data/battle_moves.h` (13 members, in the ROM fixture).

## MAY CHANGE

- `src/core/BattleEngine.lua`: `PRIMARY_STATUS_MOVES`, admission,
  `resolvePrimaryStatusMove`, events `statusAlready`/`stayedAwake`.
- `src/core/BattleSceneController.lua`: already/stayed-awake texts, names.
- `src/core/AICheckBadMove.lua`: STATUS1 branches (Sleep, Poison/Toxic,
  Paralyze, Will-O-Wisp, Dream Eater, Nightmare, Snore/Sleep Talk, Refresh).
- Tests: status engine, controller, AI, inventory partition, new
  `tests/phase4_primary_status_effect_rom_test.lua`; the controller's
  "unsupported power-zero" boundary test now uses EFFECT_CONFUSE.
- `work/reports/phase4-move-effect-inventory.md`: five rows to R, totals.

## Acceptance

1. Each script's own gate order (see the inventory rows: Sleep already →
   ability → other; Poison/Paralyze ability → already/typecalc → other;
   Toxic other status before type; Will-O-Wisp already → Fire → Water
   Veil → other) with no RNG before accuracycheck; PP spent on every path.
2. Accuracy boundary; sleep 2-5 duration draw after accuracy.
3. Texts for applied/already/prevented/stayed-awake/doesn't affect/failed.
4. AI branches read status (STATUS1_ANY excludes the toxic counter).
5. A foe status move reaches the player and S1 end-of-turn damage.
6. Full no-ROM suite and repository checker pass.

## Follow-ups

- Substitute, Safeguard, Magic Coat, Uproar, Synchronize unmodeled.
- Accuracy modifiers Compound Eyes (×1.3) and Hustle (×0.8)
  (`src/battle_script_commands.c:1069-1074`) are missing for every move;
  S3 makes them visible (e.g. Butterfree's Sleep Powder). A small shared
  BattleFormulas task should add them (review F1).
- Remaining status families (Rest, Tri Attack, Yawn, Heal Bell, ...) per the
  design's "later" list; S4 (thaw-hit, Facade, Smelling Salt, Refresh).

## Evidence (Worker, 2026-10-14)

Status engine 148/0; controller 135/0; AI 38/0; full suite and repository
checker in the PR.
