# Task: H1 friendship and IV snapshots at the party boundary

- Task ID: `P4-BATTLE-INPUT-H1`
- Status: `READY_FOR_REVIEWER — bounded local implementation; no self-acceptance`
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

## Worker receipt — 2026-10-31

Implemented from clean local `7b33214` on `work/battle-input-h1-20261030`.
Only the two bridge constructors, trainer factory return data, dedicated
`tests/battle_friendship_ivs_test.lua`, and this task changed. Parent owns
canonical coordination and separate independent review; this receipt does
not update inventory, phase status, or the accepted handoff's lifecycle.

Source checkout `/home/home/FireRedRecomp-reference/pokefirered` HEAD verified
as `c75f352304d529f6ba92d4f74b9cf8b5c3810788` (source only, no ROM access).
Player/opponent controllers `src/battle_controller_player.c:1540-1547` and
`src/battle_controller_opponent.c:475-482` copy friendship and all six IVs.
`src/pokemon.c:1815` initializes species friendship; default/custom trainer
paths `src/battle_main.c:1576-1577,1588-1589` scale IVs and call CreateMon
without overriding friendship. Party construction now supplies decrypted
substruct0 friendship and substruct3 IVs. Generated construction supplies
instance IVs. Both rely on reviewed V4a `makeBattler`'s validating six-scalar
copy; no input table is retained as the battler IV snapshot.

Producer ownership resolves friendship precedence: WildPokemonFactory
stores species friendship in `boxData.substructs[0]` and has no top-level
friendship; main's explicit temporary developer player uses that same
producer (`main.lua:1280-1281`). TrainerPokemonFactory has no boxData and now
exposes `info.friendship` directly. A present boxData owner therefore wins
over any stale top-level field, even when its own friendship is absent.
Without boxData the top-level value is used. Missing synthetic fields stay
nil; zero stays zero. No fallback species value, empty IV table, or boxData
is manufactured. Future producers with different ownership require a new
explicit decision; this implementation claims only these known shapes.

Evidence (all commands from this worktree, ROM/replay env variables unset):

- Baseline `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY PATH=toolchain:$PATH
  bash scripts/test_all.sh`: PASS **206 files**; preserved log
  `/tmp/firered-h1-baseline-20261030.log`.
- Final same command: PASS **207 files**, ROM checks skip cleanly; log
  `/tmp/firered-h1-final-20261031.log`.
- Focused `lua5.1 tests/battle_friendship_ivs_test.lua`: **87/0**;
  `tests/battle_party_bridge_test.lua`: **32/0**;
  `tests/trainer_pokemon_factory_test.lua`: **9/0**;
  `tests/battle_variable_power_v4a_test.lua`: **243/0**.
- `tests/phase4_variable_power_v4a_effect_rom_test.lua`: explicit no-ROM
  SKIP; F4 trainer merge gate remains unproven.
- `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY PATH=toolchain:$PATH
  lua5.1 scripts/check_repository.lua`: PASS **335 Lua / 398 Markdown /
  1321 local targets**, including the staged dedicated test.
  `git diff --cached --check`: PASS.
- H1 literal oracles cover six distinct IVs `{1,2,3,4,5,6}`, trainer fixed
  IV12 from byte100, base friendship35/0 and party/wild70, mutation both
  directions, independent temporary-player snapshots, stale cached metadata,
  fresh switch-in, no friendship/IV writeback despite battler mutation,
  valid checksum/encrypted SaveFileCodec roundtrip, and synthetic omissions.
  Scripted RNG witnesses retain wild5/starter4/trainer2 source draws; bridge
  construction and persistence take none. No RNG code changed.

Known constraints remain: source level-up friendship changes party data but
does not refresh active battler friendship (`battle_script_commands.c:3314-3329`).
Runtime rewards are post-battle today; future in-battle EXP must preserve
party authority when rebuilding a switch-in. League friendship raises before
battle setup (`battle_main.c:711-713`, `pokemon.c:5478-5487`) and faint-party
friendship updates are separate prerequisites, not implemented here.

No source blocker or implementation scope expansion identified. Fresh
`gh pr view 58 --json number,state,headRefOid,baseRefName` failed connecting
to api.github.com; no remote state is certified. The stack remains local
V4a `2139495` atop unmerged V3. Required external ROM/F4/runtime/base/publication
gates remain with the parent, as does the separate V4b inventory decision.
No ROM, guarded runner/request, push, or merge was used. Freeze the local
commit containing this receipt for independent Reviewer; no self-acceptance.
