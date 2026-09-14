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
