# Task: Phase 4 ordered replacement-state design

- Status: `ACTIVE`
- Type: `PHASE 4 / BATTLE RULES / READ-ONLY DESIGN DISCOVERY`

## Goal

Design the minimal ordered replacement/outcome state needed for the already
source-locked Explosion faint sequence: retain all ordered faint events before
replacement handling, support both sides becoming pending in a single battle
resolution, and preserve existing ordinary single-faint behavior. Do not
implement state changes or Explosion.

## Required evidence

1. Trace retail control transfer after target and attacker faint scripts return.
2. Map current one-slot `awaitingForcedSwitch`, `checkFaint`, and controller
   assumptions that prevent ordered multi-side pending state.
3. Define pending-side ordering, resolution policy, terminal-outcome timing,
   and compatibility requirements for ordinary/recoil/forced-switch paths.
4. Update only task/STATE/HANDOFF/EXECUTION_MAP; no route or code changes.

## MUST NOT CHANGE

No battle behavior, tests, bridge configuration, UI, AI, trainer layouts,
held items, move-admission policy, or Phase-completion status. This task does
not authorize an Explosion implementation.

## Evidence and design conclusion

`Cmd_tryfaintmon` pushes `BattleScript_FaintTarget` or
`BattleScript_FaintAttacker` only for a zero-HP selected battler
(`src/battle_script_commands.c:2831-2915`). Those scripts complete their own
faint animation/message and return (`data/battle_scripts_1.s:2801-2817`). The
retail turn/action dispatcher reaches `HandleFaintedMonActions` only after the
action script returns (`src/battle_main.c:4433-4439`), and the resulting
`BattleScript_HandleFaintedMon` first runs `checkteamslost` before it chooses a
party screen or send-out path (`data/battle_scripts_1.s:2824-2888`). Therefore
Explosion's ordered target→attacker faint sequence must be fully emitted before
any replacement/outcome decision; selection is not interleaved after the first
faint.

The current engine combines these distinct phases in `checkFaint`: it appends a
faint event and immediately either sets one `awaitingForcedSwitch` string or
sets a player-won/player-lost outcome (`src/core/BattleEngine.lua:1298-1313`).
It has no collection for two sides, no post-sequence team-loss pass, and no
source-locked simultaneous-team-loss outcome. Replacing the scalar with a queue
alone would be unsafe: the terminal outcome must be determined once, after the
ordered faint sequence, before any replacement request; ordinary single-faint
and recoil/drain callers must retain their current event ordering and blocking.

The minimal state contract is consequently a two-phase API, not a scalar-to-list
rename: (1) record ordered faint sides/events without outcomes or switches;
(2) finalize the completed sequence by evaluating team survival for all fainted
sides, assigning one terminal outcome if any team is exhausted, otherwise
creating ordered replacement requests. The exact simultaneous-team-loss result
and both-sides local replacement policy are not yet source-locked in this
project's party/controller model. This design task therefore identifies a
further terminal-outcome/replacement-policy discovery prerequisite; it does not
authorize code, a bridge route, or Explosion implementation.
