# Task: plan Local Worker Bridge route for Phase 4 Pain Split

- Status: `PLAN COMPLETE — PENDING INDEPENDENT REVIEW`
- Type: `INFRASTRUCTURE / EXECUTION SUBSTRATE / PLAN`

## Goal

Define the fail-closed route for only FireRed `EFFECT_PAIN_SPLIT` (91), Pain
Split #220, in the existing one-opponent engine.

## Exact later-worker surface

Selector `phase4-pain-split-effect` must allow only:

1. `src/core/BattleEngine.lua`
2. `src/core/BattleSceneController.lua`
3. `tests/battle_engine_test.lua`
4. `tests/battle_scene_controller_test.lua`
5. `tests/phase4_pain_split_effect_rom_test.lua`
6. `scripts/runtime_phase4_pain_split_replay.sh`
7. `work/tasks/phase4-pain-split-effect.md`
8. `work/coordination/STATE.json`
9. `work/coordination/HANDOFF.md`

Focused execution is exactly `lua5.1 tests/battle_engine_test.lua`, then
`lua5.1 tests/battle_scene_controller_test.lua`, then
`lua5.1 tests/phase4_pain_split_effect_rom_test.lua`; full no-ROM is
`env -u POKEPORT_ROM bash scripts/test_all.sh`; verified-ROM is
`bash scripts/test_all.sh` with the SHA-verified `POKEPORT_ROM`; replay is
`bash scripts/runtime_phase4_pain_split_replay.sh`. Publication stages the same
nine literal paths individually when present. Require a separate one-file probe
`work/local-runner/probes/phase4-pain-split-effect-route-YYYYMMDD.probe`.

## Acceptance and exclusions

Effect 91 alone may receive a literal admission exception, but no generic
zero-power acceptance. It preserves cancellation, announcement, PP, and the
represented zero-RNG accuracy branch. From pre-mutation HP it computes the
floor average and signed deltas, then applies attacker first and target second,
independently clamping each to max HP and emitting actual ordered HP events
plus shared-pain presentation. Prove #220's ROM record, admission isolation,
zero RNG, lower/higher/odd/equal cases, asymmetric maxima on both sides,
actual event deltas/order, no faint, and ordinary regression. Exclude generic
healing/HP API, Protect, Substitute, Mirror Move, Lock-On/sure-hit,
semi-invulnerability, items, abilities, status, doubles/links, other effects,
UI redesign, and Phase 4 completion.

Preserve trusted-main-only dispatch, one request, SHA gate, literal validation
and staging, and independent publication review.

## MUST NOT CHANGE

No configuration, code, tests, bridge request, or behavior in this plan.

## Review

Independent route-plan review passed. Configure only the literal route next,
then independently review its configuration and run the separate one-file probe
before any Worker request.

## Configured route

The literal selector, allowlist, focused execution, replay, and individual
publication staging configuration independently passed review. Run the separate
one-file probe next; no Worker request or behavior is authorized until it
passes.

## Probe

Probe `7409ad54` passed guarded Local Worker Bridge run `35290005345`: trusted
checkout, explicit route selection, Lua toolchain, and private-ROM SHA
verification passed. Patch apply/tests/replay/publication were skipped as
required. One independently reviewed effect-91 implementation contract may now
be considered.
