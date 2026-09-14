# Task: Phase 4 terminal-outcome and replacement-policy discovery

- Status: `ACTIVE`
- Type: `PHASE 4 / BATTLE RULES / READ-ONLY SOURCE-LOCK DISCOVERY`

## Goal

Close the last policy prerequisite for the ordered replacement-state design:
source-lock local single-battle terminal outcomes after an ordered multi-faint
sequence and identify the exact retail ordering of replacement handling. Map
that evidence to the project's single-battler party/controller boundary. Do
not implement ordered state or Explosion.

## Required evidence

1. Establish the local `Cmd_checkteamslost` result for player-only, foe-only,
   and simultaneous whole-team exhaustion, including the exact `DREW` value.
2. Trace `HandleFaintedMonActions` battler traversal and
   `BattleScript_HandleFaintedMon`'s outcome gate through party selection in a
   non-link single trainer battle.
3. Map the result to `BattleEngine.checkFaint`, `awaitingForcedSwitch`,
   `BattleSceneController`, and `TrainerBattleOrchestrator`; distinguish
   source-locked behavior from product policy that the current one-side APIs
   cannot yet express.
4. State the smallest safe implementation boundary, test matrix, and whether
   an Explosion route becomes eligible. Update only task/STATE/HANDOFF/
   EXECUTION_MAP.

## MUST NOT CHANGE

No battle behavior, tests, bridge configuration, UI, AI, trainer layouts,
held items, move-admission policy, or Phase-completion status. Do not create a
Local Worker route or implement Explosion from this task.

## Source evidence and conclusion

For non-link battles, `Cmd_checkteamslost` totals every non-egg party member's
current HP. It ORs `B_OUTCOME_LOST` when the player total is zero, then ORs
`B_OUTCOME_WON` when the enemy total is zero
(`pokefirered-master/src/battle_script_commands.c:3385-3414`). The constants
define WON as `1`, LOST as `2`, and DREW as `3`
(`include/constants/battle.h:76-78`), so simultaneous whole-team exhaustion is
source-locked to `B_OUTCOME_DREW`, not to the first fainted battler's side.
The local battle setup classifies `DREW` as player-defeated
(`src/battle_setup.c:690-706`); the product must therefore represent a
distinct draw/whiteout terminal result rather than silently selecting
`playerWon` or `playerLost`.

After scripts return, `HandleFaintedMonActions` traverses battler IDs from zero
upward in state 4, executing `BattleScript_HandleFaintedMon` once for each
zero-HP non-absent battler before moving to the next ID
(`src/battle_util.c:1140-1214`). In a normal single battle IDs are player `0`
then opponent `1` (`include/constants/battle.h:20-23`). Each invocation starts
with `checkteamslost`; a nonzero outcome immediately ends the faint handler
before any party screen. With outcome still zero it calls `openpartyscreen
BS_FAINTED`, then `switchhandleorder BS_FAINTED, 2`, and sends out the selected
replacement (`data/battle_scripts_1.s:2824-2891`). Thus retail resolves
replacement work in player-then-foe battler order only after the entire action
script/faint sequence; it never requests a replacement from a team that the
whole-party check has already ended.

The current engine cannot faithfully model this yet: `checkFaint` immediately
calls a one-side `hasReplacement(side)` predicate, writes scalar
`awaitingForcedSwitch`, and chooses only `playerWon`/`playerLost`
(`src/core/BattleEngine.lua:1298-1313`). `BattleSceneController` only enters
PARTY for that scalar player side, while `TrainerBattleOrchestrator` supplies a
foe-only replacement. A safe implementation therefore needs the already
designed record-faints/finalize-sequence split plus (a) a team-survival callback
that can evaluate both sides before any pending request, (b) a `playerDrew`
terminal outcome treated as defeat by the story/world finish path, and (c) an
ordered pending-request collection processed player then foe. The existing
single-side scalar interface must remain a compatibility view until every
controller/orchestrator consumer is migrated.

This source-lock removes the terminal-result ambiguity, but it does **not** yet
authorize an Explosion route: the current party/controller APIs lack the
two-sided queued replacement integration and draw completion contract. The
next bounded work, if independently reviewed PASS, is an implementation design
for that state/API migration and its tests—not Explosion itself.
