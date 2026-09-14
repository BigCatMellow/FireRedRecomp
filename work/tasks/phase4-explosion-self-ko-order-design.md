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

## Evidence and design conclusion

Retail success is cancellation → PP → Damp check → attacker HP set to zero
(not yet faint-resolved) → critical → defense-halved base damage → type →
random damage → accuracy → target HP/result → target `tryfaintmon` → attacker
`tryfaintmon`. A miss takes that same critical/random/accuracy path before its
final attacker faint. `BattleScript_EffectExplosion` shows this sequence
(`data/battle_scripts_1.s:376-412`); `Cmd_tryexplosion` and
`Cmd_setatkhptozero` establish HP timing (`src/battle_script_commands.c:6255-
6321`); and `Cmd_tryfaintmon` emits a selected battler's faint script only at
zero HP (`2831-2915`). Damp remains an explicit unrepresented ability boundary.

Current `resolveMove` is accuracy-first and returns immediately on a miss;
`runTurn` then calls only `checkFaint(otherSide(side))`. That helper immediately
sets its one `awaitingForcedSwitch` field and returns when a replacement exists
(`src/core/BattleEngine.lua:1298-1313`). Thus target-first processing can block
the required attacker faint. Existing recoil deliberately resolves attacker
before target, so must remain separate.

The minimal contract is an effect-specific resolver: record attacker-at-zero;
consume PP and execute effect-7 crit/damage/type/random-before-accuracy with
explicit defense halving; apply target HP on a landed non-immune hit; then
resolve the ordered faint sequence `[target if zero, attacker]` completely
before replacement/outcome state. This requires an ordered collection of
pending faint sides rather than the present one-slot forced-switch state. The
necessary both-sides replacement policy is not yet designed, so this task does
not authorize an Explosion route; its successor is ordered replacement-state
design or another independent leaf.
