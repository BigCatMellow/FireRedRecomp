# Task: Phase 4 always-hit move effects

- Status: `IMPLEMENTED — PENDING GUARDED RUN / INDEPENDENT REVIEW`
- Type: `PHASE 4 / BATTLE RULES / BOUNDED IMPLEMENTATION`

## Goal

Implement only FireRed `EFFECT_ALWAYS_HIT` (17) for its six verified
positive-power, accuracy-zero records: Swift #129, Faint Attack #185, Shadow
Punch #325, Aerial Ace #332, Magical Leaf #345, and Shock Wave #351.

## Acceptance

1. Effect 17 skips only the normal accuracy check and its RNG draw. It still
   uses existing attack cancellation, PP deduction, typecalc/immunity,
   critcalc, base-damage/random-damage, event, and HP-application paths.
2. Focused tests prove an effect-17 move cannot miss from an adversarial
   accuracy seed, consumes no accuracy RNG, still deducts PP, and preserves
   ordinary type immunity, critical, random-damage, and clamp behavior.
3. A verified-ROM fixture proves all six exact records (effect, positive power,
   zero accuracy) and drives one parsed record through the engine.
4. Focused/no-ROM/verified-ROM/runtime/review evidence passes.

## MUST NOT CHANGE

Vital Throw (effect 78), high-critical effects, False Swipe, all other
positive-power fallback effects, status/volatile state, UI, AI, trainer
layouts, held items, switching, doubles, main wiring, move-admission policy,
or bridge routing beyond this task's explicit prerequisite.

## Required bridge surface

The implementation route may authorize only `src/core/BattleEngine.lua`,
`tests/battle_engine_test.lua`, `tests/phase4_always_hit_effect_rom_test.lua`,
`scripts/runtime_phase4_always_hit_replay.sh`, this task, `STATE.json`, and
`HANDOFF.md`. It must remain fail-closed and receive a separate one-file probe
before any implementation patch is accepted.

## Worker evidence

The bounded implementation bypasses the accuracy roll only for effect 17 and
leaves its existing PP/type/crit/damage path intact. Focused coverage passed 168
no-ROM assertions; the verified-ROM fixture passed 3 assertions, confirming
all six selected records and a parsed Swift invocation with only crit/random
draws. This is not a Phase 4 completion claim pending guarded execution and
independent review.
