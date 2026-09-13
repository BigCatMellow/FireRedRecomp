# Task: Phase 4 foe-only multi-Pokémon trainer orchestration

- Status: `IMPLEMENTED — PENDING INDEPENDENT REVIEW`
- Type: `PHASE 4 / BATTLE ORCHESTRATION / BOUNDED INTEGRATION`
- Parent dependency: `phase4-trainer-party-no-item-layouts.md` (`PASS`)

## Goal

Make one ordinary no-item, two-Pokémon trainer battle proceed through ordered foe
replacement and final reward/flag completion. Scope is foe-only: player party
selection, held items, doubles, and broader AI remain separate.

## Acceptance

1. Build an ordered foe roster from supported flags `0`/`1`; choose a source
   fixture ordinary trainer with `aiFlags == 0x1` and two Pokémon.
2. After a foe faints, use existing forced-switch primitives to replace it only
   after its faint/message sequence; preserve player battle state.
3. Apply trainer EXP/EV/reward progression once per defeated foe, set trainer
   defeat flag only after final victory, and keep loss behavior unchanged.
4. Add deterministic controller/integration and verified-ROM evidence for the
   two-foe sequence; no live player replacement UI, item, double, or new AI work.
5. Focused/no-ROM/verified-ROM evidence and independent review pass.

## MUST NOT CHANGE

Player party selection UI, held-item mechanics, unsupported trainer layouts,
doubles, general move effects, or unrelated story flow.

## Worker evidence

- Ordered foe-only orchestration is implemented through the existing
  `BattleEngine:resolveForcedSwitch` boundary; no engine changes were made.
- Focused controller and verified-ROM fixture tests accompany the implementation.
- Independent review remains required before roadmap advancement.
