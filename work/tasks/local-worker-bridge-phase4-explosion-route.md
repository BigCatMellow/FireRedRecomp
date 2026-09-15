# Task: plan Local Worker Bridge route for Phase 4 Explosion

- Status: `ACTIVE`
- Type: `INFRASTRUCTURE / EXECUTION SUBSTRATE / PLAN`

## Goal

Define the exact fail-closed Worker route required before implementing only
FireRed `EFFECT_EXPLOSION` (7), now that ordered faint/replacement and draw
state is independently reviewed. The route must cover effect-specific
attacker-self-KO timing, defense-halving, Damp cancellation, accuracy/RNG order,
and sequence finalization without widening to other effects.

## Exact later-worker surface

The route selector is `phase4-explosion-effects`. Its literal patch allowlist,
focused test commands, replay, and publish staging list must be exactly:

1. `src/core/BattleEngine.lua`
2. `tests/battle_engine_test.lua`
3. `tests/phase4_explosion_effect_rom_test.lua`
4. `scripts/runtime_phase4_explosion_replay.sh`
5. `work/tasks/phase4-explosion-effects.md`
6. `work/coordination/STATE.json`
7. `work/coordination/HANDOFF.md`

Focused execution is, in order, `lua5.1 tests/battle_engine_test.lua` and
`lua5.1 tests/phase4_explosion_effect_rom_test.lua`; then the existing full
no-ROM suite, full verified-ROM suite, and
`bash scripts/runtime_phase4_explosion_replay.sh`. Publish staging is the same
seven literal paths, individually added only when present. The required separate
one-file non-gameplay probe is
`work/local-runner/probes/phase4-explosion-effects-route-YYYYMMDD.probe`.

## Route rationale

The published queue/state migration owns both-side terminal/replacement state,
so Explosion needs only the engine's effect-7 execution path and focused
evidence. Existing controller faint-event presentation, main settlement, and
party orchestration must be consumed unchanged; adding them to this allowlist
would make the route broader without a source-backed need. The effect-specific
task must source-lock and test: action cancellation/PP; all-battler Damp scan;
attacker HP zero before accuracy; effect-7 defense halving; accuracy/critical/
damage RNG order; target then attacker faint record order; and one finalization
after both records. The ROM fixture must prove Self-Destruct #120 and Explosion
#153 records and drive at least #153 through the parsed engine path.

## Required route-planning evidence

Preserve trusted-main-only dispatch, one-request selection, private-ROM SHA
gate, apply/diff validation, no wildcard target/staging, focused → no-ROM →
verified-ROM → replay ordering, and independent post-publication review. Exclude
all other self-KO, recoil, ability families beyond Damp cancellation, doubles,
links, held items, and move admission work.

## MUST NOT CHANGE

No workflow configuration, code, tests, bridge request, or gameplay behavior
in this planning task. No generic route.
