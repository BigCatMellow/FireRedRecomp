# Task: Phase 4 OHKO effects

- Status: `CLOSED — REVIEWED PASS`
- Type: `PHASE 4 / BATTLE RULES / BOUNDED IMPLEMENTATION`

## Goal

Implement only FireRed `EFFECT_OHKO` (38) for Guillotine #12, Horn Drill #32,
Fissure #90, and Sheer Cold #329 in the existing one-opponent engine.

## Acceptance

1. Effect 38 alone retains cancellation/announcement/PP/type/no-effect and
   uses defender current HP only on a successful represented-state KO roll.
2. Ordinary path consumes one KO roll even on lower-level failure: success
   requires attacker level >= defender level and
   `Random()%100+1 < 30+attackerLevel-defenderLevel`; immunity consumes none.
3. Ordinary accuracy, critical/base/random damage, and ordinary-move behavior
   remain unchanged; shared faint handling remains used.
4. No Lock-On, Protect, invulnerability, Sturdy, Focus Band, Endure, Destiny
   Bond, ability/item, doubles/link, or generic-admission support is added.
5. Focused/no-ROM/verified-ROM/replay evidence passes only through the
   reviewed, probed `phase4-ohko-effects` route.

## MAY CHANGE

Only the seven paths in `local-worker-bridge-phase4-ohko-route.md`.

## MUST NOT CHANGE

Other formulas, generic admission, status/items/abilities/UI/main,
doubles/links, Phase 2's external-reference blocker, or Phase 4 completion.

## Closure evidence

The guarded Worker applied and published the independently reviewed request at
`3afcd988` after successful run `35080163638`. The actual canonical range
`49ea4b93..3afcd988` independently passed review. Evidence: focused/no-ROM
suite `225 passed, 0 failed`; full no-ROM suite `147 files PASS`; SHA-verified
retail-ROM suite `232 passed, 0 failed`; and the exact four-record ROM fixture
plus required runtime replay passed. This closes only the represented-state
effect-38 subset; it does not authorize Lock-On, Protect, invulnerability,
Sturdy, Focus Band, Endure, Destiny Bond, abilities/items, doubles/links, or
Phase 4 completion.
