# Task: Phase 4 Explosion self-KO/faint-order design

- Status: `ACTIVE`
- Type: `PHASE 4 / BATTLE RULES / READ-ONLY DESIGN DISCOVERY`

## Goal

Design the smallest source-backed engine contract needed before implementing
FireRed `EFFECT_EXPLOSION` (7): attacker HP zeroing before accuracy, per-target
critical/damage/type/random ordering before accuracy, target-before-attacker
faint handling, and interaction with the existing forced-replacement gate. Do
not implement the effect or alter engine behavior.

## Required evidence

1. Trace the retail single-battle success and miss sequences through final
   `tryfaintmon` calls, including RNG consumption and HP timing.
2. Identify each current engine return/faint/forced-switch point that conflicts
   with that sequence.
3. Specify a minimal event/order contract preserving normal moves and
   recoil/drain attacker-first behavior.
4. State an explicit boundary for unrepresented Damp/ability state and the
   effect-7 defense-halving formula.
5. Update only task/STATE/HANDOFF/EXECUTION_MAP; do not create a route.

## MUST NOT CHANGE

No battle behavior, tests, bridge configuration, UI, AI, trainer layouts,
held items, move-admission policy, other effect family, or Phase-completion
status. This design discovery does not authorize implementation.
