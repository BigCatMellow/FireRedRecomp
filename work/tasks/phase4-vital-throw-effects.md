# Task: Phase 4 Vital Throw effect

- Status: `BLOCKED ON EXPLICIT BRIDGE ROUTE`
- Type: `PHASE 4 / BATTLE RULES / BOUNDED IMPLEMENTATION`

## Goal

Implement only FireRed `EFFECT_VITAL_THROW` (78). Keep its existing imported
priority -1 order and ordinary Hit path, while bypassing the normal
accuracy/evasion calculation and its RNG draw exactly as FireRed's shared
accuracy command does. Preserve every other hit behavior.

## Acceptance

1. Only effect 78 bypasses ordinary accuracy/evasion and consumes no accuracy
   RNG draw; effect 17 remains unchanged and ordinary moves still roll.
2. Effect 78 retains PP, critical, type/no-effect, random-damage, and HP paths.
3. Tests prove modified accuracy/evasion stages, subsequent critical/damage
   draws, priority -1 versus priority 0, and ordinary-effect regression.
4. Verified-ROM fixture proves Vital Throw #233 is the sole positive-power
   effect-78 record and drives the parsed move.
5. Focused/no-ROM/verified-ROM/runtime/review evidence passes.

## MUST NOT CHANGE

Effect 17 behavior, other move effects, move-admission policy, formulas,
stateful accuracy rules, UI, AI, trainer layouts, held items, switching,
doubles, or main wiring.

## Required bridge surface

The implementation route may authorize only `src/core/BattleEngine.lua`,
`tests/battle_engine_test.lua`, `tests/phase4_vital_throw_effect_rom_test.lua`,
`scripts/runtime_phase4_vital_throw_replay.sh`, this task, `STATE.json`, and
`HANDOFF.md`. It must remain fail-closed and receive a separate one-file probe.
