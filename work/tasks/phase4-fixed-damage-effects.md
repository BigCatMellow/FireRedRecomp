# Task: Phase 4 fixed-damage move effects

- Status: `IMPLEMENTED — PENDING GUARDED RUN / INDEPENDENT REVIEW`
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

## Worker evidence

The bounded implementation changes only the authorized seven surfaces. It
routes effects 41 (Dragon Rage), 87 (level damage), and 130 (SonicBoom) after
accuracy/PP and typecalc: immunity emits the existing noEffect event, while
nonzero type multipliers do not alter the fixed amount or presentation flags.
The branch consumes no crit or random-damage roll. Focused unit coverage passed
169 assertions in the verified-ROM run; the verified-ROM fixture passed 5 assertions against FireRed
US v1.0, including NIKOLAS #204's two custom SonicBoom slots and a parsed
SonicBoom engine invocation. This is not a Phase 4 completion claim pending
the guarded bridge run and independent review.
