# Task: add Local Worker Bridge route for Phase 4 fixed-damage effects

- Status: `ACTIVE`
- Type: `INFRASTRUCTURE / EXECUTION SUBSTRATE`

Add one exact fail-closed route for `phase4-fixed-damage-effects` before
implementation. Literal later surface: `src/core/BattleEngine.lua`,
`tests/battle_engine_test.lua`, `tests/phase4_fixed_damage_effect_rom_test.lua`,
`scripts/runtime_phase4_fixed_damage_replay.sh`, and task/coordination records.
Preserve trusted-main, ROM SHA, validation/full-suite/replay, no-wildcard,
individual staging, publication, and independent-review gates; add a separate
one-file non-gameplay probe.
