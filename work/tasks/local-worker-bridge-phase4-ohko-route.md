# Task: plan Local Worker Bridge route for Phase 4 OHKO

- Status: `PENDING INDEPENDENT REVIEW`
- Type: `INFRASTRUCTURE / EXECUTION SUBSTRATE / PLAN`

## Goal

Define the fail-closed route for only FireRed `EFFECT_OHKO` (38): Guillotine,
Horn Drill, Fissure, and Sheer Cold in the existing one-opponent engine.

## Exact later-worker surface

Selector `phase4-ohko-effects` must allow only:

1. `src/core/BattleEngine.lua`
2. `tests/battle_engine_test.lua`
3. `tests/phase4_ohko_effect_rom_test.lua`
4. `scripts/runtime_phase4_ohko_replay.sh`
5. `work/tasks/phase4-ohko-effects.md`
6. `work/coordination/STATE.json`
7. `work/coordination/HANDOFF.md`

Focused execution is exactly `lua5.1 tests/battle_engine_test.lua`, then
`lua5.1 tests/phase4_ohko_effect_rom_test.lua`; full no-ROM is
`env -u POKEPORT_ROM bash scripts/test_all.sh`; verified-ROM is
`bash scripts/test_all.sh` with the SHA-verified `POKEPORT_ROM`; replay is
`bash scripts/runtime_phase4_ohko_replay.sh`. Publication stages the same seven
literal paths individually when present. Require a separate one-file probe
`work/local-runner/probes/phase4-ohko-effects-route-YYYYMMDD.probe`.

## Acceptance and exclusions

Effect 38 alone must preserve cancellation/announcement/PP/type/no-effect and
shared target-HP KO/faint handling. The represented-state path uses exactly one
KO roll, even for lower-level failure: success only when attacker level is at
least defender level and `Random()%100+1 < 30+attackerLevel-defenderLevel`.
Type immunity must branch before this roll. Do not run ordinary accuracy,
critical/base/random damage, or add Lock-On, Protect, invulnerability, Sturdy,
Focus Band, Endure, Destiny Bond, ability/item, doubles/link, or generic
admission support. Tests must prove four ROM records, strict boundary, level
cases/RNG counts, immunity, PP, KO/faint, and ordinary regression.

Preserve trusted-main-only dispatch, one request, SHA gate, literal validation
and staging, and independent publication review.

## MUST NOT CHANGE

No configuration, code, tests, bridge request, or behavior in this plan.
