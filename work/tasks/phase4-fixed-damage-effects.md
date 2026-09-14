# Task: Phase 4 fixed-damage move effects

- Status: `BLOCKED ON BRIDGE ROUTE`
- Type: `PHASE 4 / BATTLE RULES / BOUNDED IMPLEMENTATION`

## Goal

Implement FireRed fixed-damage effects only: Dragon Rage (40 HP), level damage
(attacker level), and SonicBoom (20 HP). Reuse the existing accuracy, PP, type,
immunity, no-effect, and HP-application paths; do not generalize the dispatcher.

## Acceptance

1. Each effect performs accuracy/PP/typecalc; immunity blocks HP loss; super and
   not-very-effective display is suppressed; no critical/random damage roll is
   consumed; final damage clamps through normal HP application.
2. Unit tests cover miss, neutral values, immunity, display flags, no crit/RNG,
   and clamp behavior.
3. Verified-ROM fixture proves move/effect records and live-eligible trainer
   NIKOLAS #204's SonicBoom custom slots, then drives the engine path.
4. Focused/no-ROM/verified-ROM/runtime/review evidence passes.

## MUST NOT CHANGE

Status effects, Counter/Psywave/Super Fang/False Swipe, held items, trainer
layouts flags 2/3, admission-matrix policy, AI, doubles, UI, or main wiring.
