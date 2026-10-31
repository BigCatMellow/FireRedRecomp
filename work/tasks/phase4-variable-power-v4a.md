# Task: V4a friendship and IV-derived battle formulas

- Task ID: `P4-VARIABLE-POWER-V4A`
- Status: `READY_FOR_WORKER — local implementation only`
- Source of truth: [reviewed variable-power design](../reports/phase4-variable-power-design-proposal.md), V4a, section3, F1/F4 and D1/D2; pinned pret revision `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
- Base: PR58 exact `9d761f49488156619c3cf87a49bb1958437083c8` (stacked locally, unmerged). Prior bounded review is preserved; no V3 full-relay acceptance is inferred.
- Risk: medium; battler-aware admission and dynamic type consumers require careful regression coverage.
- Goal: implement the accepted engine-only V4a slice with synthetic battlers, without inventing default friendship/IVs or claiming live party support.

## MAY CHANGE

- `src/core/BattleEngine.lua`: optional validated friendship/IV snapshots, attacker-aware admission, exact Return/Frustration/Hidden Power formulas and dynamic type ordering/Hidden Power defrost exclusion.
- `src/core/BattleSceneController.lua`: only the narrow existing admission call if an explicit attacker parameter is necessary; preserve existing unsupported-player no-turn/no-RNG behavior. Prefer no controller edit if the engine API can safely preserve its existing player context.
- `tests/battle_variable_power_v4a_test.lua` (new), `tests/phase4_variable_power_v4a_effect_rom_test.lua` (new).
- `tests/phase4_move_effect_inventory_test.lua` and `work/reports/phase4-move-effect-inventory.md`: conditional V4a coverage/needs H1 only; no unconditional final represented flip (V4b owns it).
- This task: exact source citations, local evidence, limitations and reviewer handoff.

## MUST NOT CHANGE

No `main.lua`, party/bridge/factories, AI, save/schema/importer, H1/H2/V4b/V5, workflows/runner/requests/probes, generic battle architecture, V3 implementation or phase status. No ROM access/search locally, extracted content, private paths, merge, push or guarded execution. Parent adopts/tests/reviews the exact local package before any publication decision.

## Acceptance

1. Follow accepted formulas and source-derived independent oracles, including friendship 0/2/3/70/128/253/254/255, zero-power record fallback; Hidden Power IV bit ordering, Fighting30/all0 and Dark70/all31, Steel/Fire cases, dynamic type before accuracy, relevant STAB/effectiveness/split/weather/ability readers, and Fire Hidden Power never thawing a frozen target while Fire Weather Ball does.
2. Optional inputs must be immutable snapshots and domain-validated without inventing data. Missing required input makes the move unsupported for that attacker. Player refusal consumes no turn/PP/RNG; foe follows existing resolution refusal. Preserve unrelated supported-move callers and side-specific data isolation.
3. Retain conditional inventory semantics until H1/V4b. Add SHA-first ROM record/fixture assertions that skip cleanly without ROM. The design's F4 currently-playable-trainer custom-move check must be represented as a later merge gate; no skipped test proves it and no guessed playable scope.
4. Baseline then final complete no-ROM suite, focused source-derived tests and controller regression, repository checker, whitespace. Meaningful edge-case/RNG and aliasing checks; avoid implementation-derived expected values.
5. Record exact changed paths and commands, source certainty or UNKNOWN, pending H1 and trainer-ROM gate. Independent Reviewer must inspect exact frozen local commit; Worker cannot self-approve or mark fully accepted.

## Stop / completion

Stop for unknown source behavior, required unlisted path/state/architecture, unsupported input plumbing beyond the narrow admission call, or failed prerequisite. Record the smallest blocker; do not widen scope. Local construction can proceed on this stacked base while parent resolves V3 and publication prerequisites. Before any merge: applicable reviewed base, independent review/public CI, F4 non-skipped trainer fixture and applicable publication approval are mandatory. This task authorizes no such execution.
