# Task: H1 friendship and IV snapshots at the party boundary

- Task ID: `P4-BATTLE-INPUT-H1`
- Status: `READY_FOR_WORKER — V4a bounded local review PASS adopted`
- Goal: supply authoritative battle-time friendship and IV snapshots to the reviewed V4a battler inputs without changing saves or writing snapshots back.
- Source: [accepted H1 handoff](../handoffs/2026-10-21-battle-friendship-ivs-handoff.md), [reviewed variable-power design](../reports/phase4-variable-power-design-proposal.md) H1, F4/F12/F13 and D1/D2. Source pin `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
- Base: local V4a `2139495897c5def7e0bef8fdcad0fd8e359f4dfd`, stacked on unmerged V3. No remote publication, runtime acceptance or full-relay closure follows.
- Assigned Worker owns the party boundary for this package. Risk: medium, authoritative save data and snapshot lifetime.

## MAY CHANGE

`src/core/BattlePartyBridge.lua` (two battler constructors only, no persistence changes); `src/core/TrainerPokemonFactory.lua` (species base friendship in return data); `tests/battle_party_bridge_test.lua`, `tests/trainer_pokemon_factory_test.lua`, optional dedicated `tests/battle_friendship_ivs_test.lua`; this task.

## MUST NOT CHANGE

No engine/controller/formulas, main, wild/starter factories, save/schema/codec/import, AI, workflows/runner/requests/probes, other moves/behaviors, inventory/phase status or canonical coordination. No H2/V5/weight importer, no league-friendship battle setup or in-battle EXP implementation. No local ROM access/search, generated content, push, merge or guarded action.

## Acceptance

1. Party constructor passes decoded substruct0 friendship and a copy of all six substruct3 IVs. Generated constructor passes instance IVs and authoritative instance friendship (trainer) or wild boxData.substruct0 friendship, never an invented default. Trainer constructor exposes imported species base friendship exactly as source CreateBoxMon initializes it.
2. Preserve compatibility for explicit synthetic generated fixtures that lack optional inputs: leave absent values absent; do not invent friendship/IVs or manufacture boxData. Valid real constructors must carry the authoritative fields. Establish precedence if both top-level and boxData exist based on known producer ownership, refusing source uncertainty.
3. Battler snapshots and record/generated data do not alias. Test both mutation directions for IVs and friendship snapshot lifetime. `persistPartyBattler` leaves authoritative record friendship and IVs unchanged; record checksum/encryption remain valid. No persistence code edits needed.
4. Cover party, wild, temporary generated, trainer default/custom construction and replacement/fresh snapshot. Do not introduce or change RNG consumption. Source: controller copies at switch-in; party level-up friendship stays post-battle in this runtime. League-battle raises are a known separate setup prerequisite, not modeled here.
5. Run baseline then final complete no-ROM suite, focused bridge/factory/data tests, applicable V4a focused regressions, repository checker and diff whitespace. Oracles from source/known input, no implementation-derived expected values.
6. Keep V4b inventory flip separate until this exact package independently passes. Record exact source lock, commands, limitations, unmerged dependencies and required external gates. Freeze local commit for independent Reviewer; no self-acceptance.

Stop for source uncertainty, required unlisted path, save or RNG behavior change, failed baseline or needing engine API changes. Return smallest blocker rather than widening. Completion is local implementation plus independent review; no ROM/publication/phase claim.

## Dispatch receipt

Parent adopted [independent V4a local PASS](../reviews/2026-10-30-variable-power-v4a-implementation-review.md) for exact `2139495`. H1 local implementation may proceed under the above allowlist. External V4a F4/ROM/base/publication gates are unchanged.
