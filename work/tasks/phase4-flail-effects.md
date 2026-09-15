# Task: Phase 4 Flail/Reversal effects

- Status: `READY FOR WORKER`
- Type: `PHASE 4 / BATTLE RULES / BOUNDED IMPLEMENTATION`

## Goal

Implement only FireRed `EFFECT_FLAIL` (99) for Flail #175 and Reversal #179.
Before ordinary Hit processing, derive dynamic base power from attacker current/
max HP using the source-locked scaled-48 bands; retain ordinary Hit behavior.

## Acceptance

1. Effect 99 alone uses the dynamic path; both parsed ROM records are proven.
2. Scaling is exact: floor(hp*48/maxHP), positive underflow becomes 1, then
   <=1/4/9/16/32/48 maps to 200/150/100/80/40/20.
3. Ordinary cancellation, accuracy, PP, critical, type, random damage, HP and
   faint behavior remain shared; stored-power-1 moves outside effect 99 stay so.
4. Focused, no-ROM, verified-ROM and replay evidence pass through the reviewed,
   probed `phase4-flail-effects` route only.

## MAY CHANGE

Only the seven paths in `local-worker-bridge-phase4-flail-route.md`.

## MUST NOT CHANGE

Other dynamic formulas, Super Fang, generic admission, status/items/UI/main,
doubles/links, or Phase 4 completion status.
