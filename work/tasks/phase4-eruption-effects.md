# Task: Phase 4 Eruption/Water Spout effects

- Status: `CLOSED — REVIEWED PASS`
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

## Closure evidence

The guarded Worker applied and published the independently reviewed request at
`89cf1dae` after successful run `34997543211`. The actual canonical range
`53d78236..89cf1dae` independently passed review. Evidence: focused/no-ROM
suite `213 passed, 0 failed`; SHA-verified retail-ROM suite `220 passed, 0
failed`; and `phase4_eruption_effect_rom_test` plus the required runtime replay
passed. This closes only effect 190 in the existing one-opponent engine; it
does not authorize broader dynamic-power formulas, abilities, doubles/links,
held items, or Phase 4 completion.
