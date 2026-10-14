# Task: heal-move battle messages use source text

- Task ID: `P4-FL7-HEAL-MESSAGE-TEXT`
- Status: `CLOSED — REVIEWED PASS` ([review](../reviews/2026-10-14-heal-message-text-review.md))
- Lane: [battle-effect fast lane](../../AGENTS.md#battle-effect-fast-lane--human-authorized-2026-10-13) (presentation-only follow-up)
- Owner request: 2026-10-14, "Fix battle message wording" (supersedes the
  project-wording choice in [restore HP design](../reports/phase4-restore-hp-design.md)).
- Follow-up from: [batch 3 review finding 5](../reviews/2026-10-13-batch3-status-moves-review.md).

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

- `data/battle_scripts_1.s:673-685` Restore HP and `:2023-2036` Softboiled:
  success prints `STRINGID_PKMNREGAINEDHEALTH`; `tryhealhalfhealth` failure
  goes to `BattleScript_AlreadyAtFullHp` (`:2038-2042`), `STRINGID_PKMNHPFULL`.
- `src/battle_message.c:124` `sText_PkmnRegainedHealth` =
  "{B_DEF_NAME_WITH_PREFIX} regained\nhealth!"; `:125` `sText_PkmnHPFull` =
  "{B_DEF_NAME_WITH_PREFIX}'s\nHP is full!".
- `src/battle_script_commands.c:6332-6337` `Cmd_tryhealhalfhealth`: with
  BS_ATTACKER (Restore HP) the target is set to the attacker; Softboiled's
  BS_TARGET is the user for its MOVE_TARGET_USER moves (batch 3 review), so
  B_DEF_NAME names the acting battler in both cases.

## MAY CHANGE

- `src/core/BattleSceneController.lua`: `restoreHP` / `restoreHPFull` texts only.
- `tests/battle_scene_controller_test.lua`: updated expectations; Soft-Boiled
  through the real engine.
- `work/reports/phase4-restore-hp-design.md`: one supersession note.

No engine, RNG, HP, event-shape or ordering change.

## Acceptance

1. "X regained\nhealth!" after the invisible HP entry; "X's\nHP is full!"
   with no HP entry, for Recover/Slack Off and Soft-Boiled/Milk Drink.
2. No other text changes; no-ROM `scripts/test_all.sh` and
   `scripts/check_repository.lua` pass.

## Evidence (Worker, 2026-10-14)

Controller 105/0 (was 103); full no-ROM suite and repository checker results
in the PR. Independent review PASS; Info findings 1-2 applied (order assert, note placement).
