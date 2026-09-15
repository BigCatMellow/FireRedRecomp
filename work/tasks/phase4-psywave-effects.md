# Task: Phase 4 Psywave effect

- Status: `CLOSED — REVIEWED PASS`
- Type: `PHASE 4 / BATTLE RULES / BOUNDED IMPLEMENTATION`

## Goal

Implement only FireRed `EFFECT_PSYWAVE` (88), Psywave #149, in the existing
one-opponent engine. After shared accuracy/PP and type calculation, rejection
sample `Random() % 16` to 0..10 and set damage to
floor(attacker level × (50 + 10r) / 100), without ordinary crit/base/random
damage.

## Acceptance

1. Effect 88 alone uses the source-locked sampled level formula; #149 remains
   imported with its verified ROM record.
2. Accepted low/high values, retry draw count, and integer floor semantics are
   exact; a type-immune target still consumes its full post-typecalc sample.
3. Ordinary cancellation, accuracy, PP, type/no-effect, shared HP/faint, and
   ordinary-move behavior are preserved; nonzero effectiveness presentation is
   cleared.
4. No ordinary critical, base-damage, or normal random-damage operation runs
   for effect 88, and no generic random-formula, item/endure, ability,
   doubles/link, or state support is introduced.
5. Focused/no-ROM/verified-ROM/replay evidence passes only through the
   reviewed, probed `phase4-psywave-effects` route.

## MAY CHANGE

Only the seven paths in `local-worker-bridge-phase4-psywave-route.md`.

## MUST NOT CHANGE

Other formulas, generic admission, item/endure/ability/status/UI/main,
doubles/links, Phase 2's external-reference blocker, or Phase 4 completion
status.

## Closure evidence

The guarded Worker applied and published the independently reviewed request at
`40cfdffe` after successful run `35026622346`. The actual canonical range
`79c31598..40cfdffe` independently passed review. Evidence: focused/no-ROM
suite `219 passed, 0 failed`; SHA-verified retail-ROM suite `226 passed, 0
failed`; and `phase4_psywave_effect_rom_test` plus the required runtime replay
passed. This closes only effect 88 in the existing one-opponent engine; it does
not authorize broader random formulas, held-item/endure state, abilities,
doubles/links, or Phase 4 completion.
