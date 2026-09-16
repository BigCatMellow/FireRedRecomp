# Task: Phase 4 Endeavor effect

- Status: `ACTIVE — REVIEWED IMPLEMENTATION CONTRACT`
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
   damage/faint handling and bypasses ordinary critical/base/random damage.
4. Tests prove the exact Endeavor ROM record, viability boundary, PP and RNG
   order for viable hit/miss and immunity, HP/faint behavior, presentation
   clearing, absence of ordinary formula draws, and ordinary-move regression.
5. Focused/no-ROM/verified-ROM/replay evidence passes only through the
   reviewed, probed `phase4-endeavor-effects` route.

## MAY CHANGE

Only the seven paths in `local-worker-bridge-phase4-endeavor-route.md`.

## MUST NOT CHANGE

Protect, Substitute, Focus Band, Endure, their state/RNG paths (including
Focus Band RNG), generic current-HP formulas, other effects, item/ability/status
state, UI/controller/main, doubles/links, Phase 2's external-reference blocker,
or Phase 4 completion.

## Review

Independent implementation-scope review passed. Exactly one literal bounded
Worker patch request through the reviewed, probed route is now authorized.
