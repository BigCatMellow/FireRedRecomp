PASS

# Review: P4-FL7-HEAL-MESSAGE-TEXT (heal-move source text)

- Branch `claude/wizardly-faraday-o45q9z`, head `cb3cea2d2bcea37f323e311315783ae50e9f99df`, base `origin/main`.
- Contract: `work/tasks/battle-heal-message-source-text.md`.
- Source: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.

## Scope

The diff touches 4 files, all listed under MAY CHANGE (plus the new task file):
`src/core/BattleSceneController.lua` (2 strings and comments),
`tests/battle_scene_controller_test.lua`, a supersession note in
`work/reports/phase4-restore-hp-design.md`, and the new task file. It does
not touch the engine, RNG, HP math, event shape or ordering. The HP entry
for `restoreHP` is unchanged and still comes before the text.

## Source table

| Item | Source | Port (head) | Match |
|---|---|---|---|
| Success text | `bm.c:124` `{B_DEF_NAME_WITH_PREFIX} regained\nhealth!` | `name(side) .. " regained\nhealth!"` (BSC.lua:227) | yes (newline after "regained") |
| Full-HP text | `bm.c:125` `{B_DEF_NAME_WITH_PREFIX}'s\nHP is full!` | `possessive(name(side)) .. "\nHP is full!"` (BSC.lua:230) | yes (`'s` then newline) |
| Restore HP order | `bs1.s:673-685`: tryhealhalfhealth BS_ATTACKER, then healthbarupdate/datahpupdate, then printstring REGAINEDHEALTH | HP entry, then text | yes |
| Softboiled order | `bs1.s:2023-2036`: same with BS_TARGET | same event path | yes |
| Full path | `bs1.s:2038-2042` AlreadyAtFullHp: pause, printstring HPFULL, with no HP update | text only, no HP entry | yes |
| DEF battler | `bsc.c:6332-6337`: BS_ATTACKER sets gBattlerTarget = attacker. BS_TARGET keeps gBattlerTarget, which for MOVE_TARGET_USER (Soft-Boiled/Milk Drink) is the user in singles | `event.side` (the user) | yes |

## Checks

1. Text, newline, possessive and battler all match (see table). The HP entry
   still comes first on success. The full-HP path has no HP entry.
2. Naming convention: source `HANDLE_NICKNAME_STRING_CASE` (`bm.c:1807`)
   adds "Wild "/"Foe " (`bm.c:413-414`) to opposing names. `name()` in this
   controller (BSC.lua:191) never adds a prefix, and no other message in the
   file does either (e.g. the existing "FOE's ATTACK\nharshly fell!"
   expectation). This gap predates the change and applies to the whole
   controller. The two new strings follow the controller's existing
   convention, so the change creates no inconsistency.
3. Dependents: the old strings appear only in historical
   `work/local-runner/requests/*.patch` files and in the superseded design
   note and earlier review. None of these is executed or used as a test
   oracle. No hits in main.lua, scripts/*replay*.sh, ROM tests or other tests.
4. Tests: synthetic `_eventMessages` cases cover Restore HP success
   (exact equality plus HP-entry order) and full HP (exact equality, no
   hpSide). A new real-engine test (BattleEngine + controller `_runTurn`)
   covers Soft-Boiled (effect 157) success and full HP, plus effect-32
   Recover full HP for the foe. Effect-32 success goes only through the
   synthetic event, which is acceptable because both effects emit the same
   event type.
5. Suite and checker: both pass (see below).
6. Scope matches MAY CHANGE. No engine or RNG change.

## Mutations (on `git archive` copies under /tmp/claude-0/review7/)

| # | Mutation | Result |
|---|---|---|
| m1 | success text changed back to "recovered HP!" | killed (2 fails) |
| m2 | full-HP text changed back to "is already at full HP!" | killed (2) |
| m3 | newline removed from the success text | killed (2) |
| m4 | newline removed from the full-HP text | killed (2) |
| m5 | success text names the other side | killed (2) |
| m6 | full-HP text names the other side | killed (1, synthetic test only) |
| m7 | success HP entry dropped | killed (1) |
| m8 | HP entry moved after the success text | killed (1) |
| m9 | HP entry added on the full path | killed (3) |

## Test results

- Unmodified head: `tests/battle_scene_controller_test.lua` 105 passed, 0 failed.
- `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY bash scripts/test_all.sh`:
  exit 0, "PASS: 161 test files (no-ROM mode ...)".
- `lua5.1 scripts/check_repository.lua`: "PASS: repository checks (287
  tracked Lua, 295 tracked Markdown, 976 local targets)".
- ROM tests were skipped because no ROM is available.

## Findings

1. Info. `tests/battle_scene_controller_test.lua:582-583`. In the real-engine
   full-HP test, both battlers are at full HP, and the test only checks that
   both "PLAYER's" and "FOE's" strings appear. If the side is swapped, both
   strings still appear, so this test passes under m6. The synthetic test at
   :226-227 catches m6, so coverage holds overall. Optional fix: at full HP,
   assert the order of the two strings, or give the foe a non-healing move.
2. Info. `work/reports/phase4-restore-hp-design.md:139-141`. The
   supersession note is placed mid-paragraph. The sentence after it, "These
   are explicit project presentation choices, not copied ROM text", now
   describes the superseded wording. A reader could still misread it.
   Optional fix: put the note after that sentence, or say "the above were".
3. Info, pre-existing and outside this change. `BattleSceneController.lua:191`.
   `name()` omits the source "Wild "/"Foe " prefix that NAME_WITH_PREFIX
   adds to every opposing name. This affects every message in the
   controller, and no project document records it as a deviation. If
   wanted, handle it as a separate task.

No blocking or must-fix findings.

-- independent reviewer subagent; did not construct the change
