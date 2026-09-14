# Task: Phase 4 high-critical move effects

- Status: `IMPLEMENTED — PENDING GUARDED RUN / INDEPENDENT REVIEW`
- Type: `PHASE 4 / BATTLE RULES / BOUNDED IMPLEMENTATION`

## Goal

Implement only FireRed `EFFECT_HIGH_CRITICAL` (43). For its eight verified
positive-power move records, call the existing critical-roll helper at stage 1
(1/8) instead of ordinary stage 0 (1/16). Preserve exactly one critical RNG
draw, accuracy, PP, type/immunity, normal random damage, and HP application.

## Acceptance

1. Only effect 43 selects critical stage 1; ordinary moves remain stage 0.
2. Boundary RNG tests prove stage-1 1/8 behavior, unchanged draw count and
   existing critical damage/event path.
3. Verified-ROM fixture proves the exact eight effect-43 records and drives a
   parsed record through the engine.
4. Focused/no-ROM/verified-ROM/runtime/review evidence passes.

## MUST NOT CHANGE

Vital Throw, Sky Attack, Blaze Kick, Poison Tail, Focus Energy, held items,
abilities, multi-hit behavior, other move effects, admission policy, UI, AI,
trainer layouts, doubles, or main wiring.

## Required bridge surface

The implementation route may authorize only `src/core/BattleEngine.lua`,
`tests/battle_engine_test.lua`, `tests/phase4_high_critical_effect_rom_test.lua`,
`scripts/runtime_phase4_high_critical_replay.sh`, this task, `STATE.json`, and
`HANDOFF.md`. It must be fail-closed and receive a separate one-file probe
before any implementation patch is accepted.

## Worker evidence

Only effect 43 selects the existing stage-1 critical table entry. Focused
coverage proves the 1/8 boundary, ordinary stage-0 regression, PP, and the
unchanged three-draw hit path. The verified-ROM fixture proves the eight
records and parsed Slash behavior. This is not a Phase 4 completion claim
pending guarded execution and independent review.
