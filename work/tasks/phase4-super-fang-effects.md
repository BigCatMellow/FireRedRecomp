# Task: Phase 4 Super Fang effect

- Status: `READY FOR WORKER`
- Type: `PHASE 4 / BATTLE RULES / BOUNDED IMPLEMENTATION`

## Goal

Implement only FireRed `EFFECT_SUPER_FANG` (40), the single Super Fang #162
record. Preserve stock cancellation, accuracy, PP, type and shared faint paths;
after a non-immune hit use `floor(target current HP / 2)`, minimum one, and
clear only nonzero effectiveness presentation. Do not use the ordinary
critical/base/random-damage path.

## Acceptance

1. Effect 40 alone receives the path; #162 remains parsed from verified ROM.
2. Misses preserve ordinary accuracy/PP behavior and do not run formula RNG.
3. Immunity is no-effect; nonzero effectiveness does not alter amount or show
   effectiveness flags.
4. Even, odd, and one-HP target cases use the stock half-current-HP/minimum-one
   formula and shared HP/faint settlement.
5. Focused, no-ROM, verified-ROM and replay evidence pass only through the
   reviewed/probed `phase4-super-fang-effects` route.

## MAY CHANGE

Only the seven paths listed by `local-worker-bridge-phase4-super-fang-route.md`.

## MUST NOT CHANGE

Effects 7/41/87/130 or any other formula; generic move admission; status,
ability, item, UI/controller/main wiring; doubles/links; or Phase 4 status.
