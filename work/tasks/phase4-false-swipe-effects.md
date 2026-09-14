# Task: Phase 4 False Swipe effect

- Status: `CLOSED — REVIEWED PASS`
- Type: `PHASE 4 / BATTLE RULES / BOUNDED IMPLEMENTATION`

## Goal

Implement only FireRed `EFFECT_FALSE_SWIPE` (101). After accuracy, PP,
critical, type/no-effect, and random-damage, cap a lethal effect-101 hit to
`defender HP - 1` before shared HP application. Preserve all other hit behavior.

## Acceptance

1. Only effect 101 leaves a lethal affected target at 1 HP; nonlethal and
   non-effect-101 hits retain current behavior.
2. Tests cover HP=1, lethal/nonlethal hits, immunity, PP, and three-draw RNG.
3. Verified-ROM fixture proves False Swipe #206 and drives the parsed move.
4. Focused/no-ROM/verified-ROM/runtime/review evidence passes.

## MUST NOT CHANGE

Substitute, Endure, Focus Band, held items, multi-hit, Vital Throw, other move
effects, admission policy, UI, AI, trainer layouts, doubles, or main wiring.

## Required bridge surface

The implementation route may authorize only `src/core/BattleEngine.lua`,
`tests/battle_engine_test.lua`, `tests/phase4_false_swipe_effect_rom_test.lua`,
`scripts/runtime_phase4_false_swipe_replay.sh`, this task, `STATE.json`, and
`HANDOFF.md`. It must remain fail-closed and receive a separate one-file probe.

## Worker evidence

Only effect 101 caps lethal final damage at target HP minus one after immunity
handling and before shared application. Focused coverage proves HP=1, lethal,
nonlethal, immunity, PP, and three draws; verified-ROM coverage proves #206.
Guarded run `34830527499` applied and published the independently reviewed
patch at `a3e9d058`. This is not a Phase 4 completion claim.
