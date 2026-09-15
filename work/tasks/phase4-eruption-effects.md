# Task: Phase 4 Eruption/Water Spout effects

- Status: `READY FOR WORKER`
- Type: `PHASE 4 / BATTLE RULES / BOUNDED IMPLEMENTATION`

## Goal

Implement only FireRed `EFFECT_ERUPTION` (190): Eruption #284 and Water Spout
#323, in the existing singles engine. Derive transient power as
floor(attacker HP * stored power / maxHP), minimum one, before ordinary Hit.

## Acceptance

1. Effect 190 alone uses dynamic power; both ROM records remain parsed.
2. Full/partial/positive-underflow HP uses stock integer/minimum semantics.
3. Ordinary cancellation, accuracy, PP, crit, type, random, HP/faint paths are
   preserved; data and other 150-power moves do not change.
4. Existing one-opponent targeting remains bounded; no doubles/multi-target or
   pre-seeded dynamic-power state is introduced.
5. Focused/no-ROM/verified-ROM/replay evidence passes only through the reviewed,
   probed `phase4-eruption-effects` route.

## MAY CHANGE

Only the seven paths in `local-worker-bridge-phase4-eruption-route.md`.

## MUST NOT CHANGE

Other formulas, generic admission, status/items/UI/main, doubles/links, or
Phase 4 completion status.
