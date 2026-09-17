# Task: Phase 4 Endeavor effect

- Status: `CLOSED — REVIEWED PASS`
- Type: `PHASE 4 / BATTLE RULES / BOUNDED IMPLEMENTATION`

## Goal

Implement only FireRed `EFFECT_ENDEAVOR` (189), Endeavor #283, in the existing
one-opponent engine. After cancellation, announcement, and PP reduction, fail
with no accuracy draw when target current HP is less than or equal to attacker
current HP. When viable, preserve ordinary accuracy and type/no-effect order,
then set damage to target current HP minus attacker current HP without ordinary
critical, base-damage, or normal random-damage operations.

## Acceptance

1. Effect 189 alone preserves cancellation, announcement, and PP reduction;
   target HP <= attacker HP fails before accuracy with no accuracy RNG draw.
2. A viable attempt retains ordinary accuracy; type immunity occurs after that
   accuracy roll and produces no HP loss. Nonzero type effectiveness
   presentation is cleared without changing the stored HP delta.
3. The exact target-current-HP minus attacker-current-HP amount uses shared
   damage handling and bypasses ordinary critical/base/random damage. A valid
   living attacker leaves the target at that positive attacker HP and emits no
   `faint` event.
4. Tests prove the exact Endeavor ROM record, viability boundary, PP and RNG
   order for viable hit/miss and immunity, positive-HP landing/no-faint behavior, presentation
   clearing, absence of ordinary formula draws, and ordinary-move regression.
5. Focused/no-ROM/verified-ROM/replay evidence passes only through the
   reviewed, probed `phase4-endeavor-effects` route.

## MAY CHANGE

Only the nine paths in `local-worker-bridge-phase4-endeavor-route.md`.

## MUST NOT CHANGE

Protect, Substitute, Focus Band, Endure, their state/RNG paths (including
Focus Band RNG), generic current-HP formulas, other effects, item/ability/status
state, unrelated UI/controller/main behavior, doubles/links, Phase 2's
external-reference blocker, or Phase 4 completion. Only the minimal generic
move-failure event, its existing-scene “But it failed!” presentation, and its
focused controller test are permitted in the two added route paths.

## Review

Independent candidate review found that Endeavor's `BattleScript_ButItFailed`
outcome must use a dedicated generic move-failure event, not the screen-only
`screenFailed` event. The minimal scene/controller-test route amendment is
passed amendment review, configuration review, and fresh probe `14c164e9` /
guarded run `35206557769`. The corrected contract independently passed fresh
scope review; no request is authorized until corrected artifact review passes.

## Corrected review

Independent corrected implementation-scope and candidate-artifact reviews
passed. The reviewed artifact
`phase4-endeavor-effects-20260917-v3.patch` is the only literal Worker request
authorized through the reviewed, probed nine-path route.

## Closure evidence

The guarded Worker applied and published the reviewed request as `3a489b94`
after successful run `35207142939`. Independent canonical-range review passed
the actual range `50537277..3a489b94`: it changed only six permitted paths,
preserved source order and exclusions, documents/uses generic `moveFailed`
distinct from `screenFailed`, presents “But it failed!”, and proves positive-HP
landing with no faint. The guarded run passed target validation, apply,
focused/no-ROM/verified-ROM suites, replay, and publication. This closes only
effect 189 in the existing one-opponent engine; it does not authorize broader
state, formula, UI/controller, doubles/link, or Phase 4 completion work.
