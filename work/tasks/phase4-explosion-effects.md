# Task: Phase 4 Explosion effects

- Status: `READY FOR WORKER`
- Type: `PHASE 4 / BATTLE RULES / BOUNDED IMPLEMENTATION`

## Goal

Implement only FireRed `EFFECT_EXPLOSION` (7), covering Self-Destruct #120 and
Explosion #153. Preserve the stock sequence: cancellation/PP, all-battler Damp
cancellation, attacker HP to zero before accuracy, effect-7 defense halving,
ordinary accuracy/critical/type/random-damage order, target then attacker faint
records, then one post-sequence terminal/replacement finalization.

## Acceptance

1. Effect 7 alone uses this path; its power, type, PP, priority, accuracy, and
ordinary no-effect behavior remain parsed from ROM data.
2. Damp cancels before self-KO, accuracy, or damage RNG; no Damp state leaks to
other effects.
3. The attacker is at zero before the accuracy check. A miss leaves it fainted,
consumes the ordinary accuracy/critical/random stream as source requires, and
does not damage the target.
4. The effect halves only the defender's defense for damage calculation, then
records target faint before attacker faint and finalizes the whole sequence once.
5. Focused, no-ROM, verified-ROM, and replay evidence pass through the guarded
route. This does not claim broader self-KO/ability/double/link support.

## MAY CHANGE

Only the seven paths in `local-worker-bridge-phase4-explosion-route.md`.

## MUST NOT CHANGE

Any effect other than 7; generic ability framework; doubles/links; held items;
recoil/drain; move admission; trainer/UI/main wiring; or phase-completion status.

## Worker evidence

Route config passed at `2355a194`; probe `8e5ed551` passed guarded run
`34952628535`. Submit exactly one `phase4-explosion-effects` request after
independent patch review.
