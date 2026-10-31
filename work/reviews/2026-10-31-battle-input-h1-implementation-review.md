# H1 independent local implementation review — 2026-10-31

**PASS** for the bounded local H1 criteria at exact frozen
`c50c097bd5d3db10151398723287cfb547e014a1`. No correction identified.
This verdict does not approve publication/merge, accept V3/V4a runtime gates,
mark V4b inventory represented, or close Phase 4.

## Identity and scope

- Detached exact-head review worktree: `/tmp/firered-h1-review-20261031`.
- Independent baseline worktree: `/tmp/firered-h1-review-baseline-20261031`,
  exact parent `7b33214a15f4c0cfc0cdd6adfd9873376b9577ee`.
- Verified V4a `2139495897c5def7e0bef8fdcad0fd8e359f4dfd` is an ancestor.
- Read AGENTS, REVIEWER, coordination flow/policy/current state, capability
  checklist, active H1 task, accepted H1 handoff and accepted V4a review.
  The H1 task is READY_FOR_REVIEWER for bounded local implementation. Shared
  canonical coordination describes a separate parent lane; it was preserved.
- Exactly four paths changed from dispatch base: the two allowed production
  files, dedicated H1 test, and H1 task. Bridge edits are limited to the two
  constructors; trainer edits only add return-data friendship. No engine,
  controller, persistence, main, save/schema/codec, factory RNG, workflow,
  runner/request, inventory or phase-status changes. All additions are text;
  no ROM/extracted assets/generated cache entered the change.
- No remote operation was performed under the parent's local-only dispatch.
  No fresh remote/base/CI status is certified. No Worker code was edited;
  exact-head review tree remains clean. This report is outside the repository.

## Independent findings

1. Source-only checkout HEAD independently equals pinned
   `c75f352304d529f6ba92d4f74b9cf8b5c3810788`. Controllers copy friendship
   and HP/Atk/Def/Speed/SpA/SpD IVs at switch-in
   (`src/battle_controller_player.c:1540-1547`,
   `src/battle_controller_opponent.c:475-482`). `pokemon.c:1815` initializes
   species base friendship. Default/custom no-item trainer paths
   (`battle_main.c:1576-1577,1588-1589`) scale fixed IVs and call CreateMon
   without overriding friendship. Imported `SpeciesInfo.friendship` reads
   species byte0x13; the trainer return passes that value without a default.
2. Party construction uses the freshly decrypted, checksum-validated record,
   not stale convenience `record.boxData` or `record.ivs`. Both constructors
   pass their authoritative IVs into the unchanged reviewed makeBattler,
   whose validation loop copies all six scalars into a new table. Friendship
   is a scalar snapshot. Neither input table is retained.
3. Known producer ownership establishes generated friendship precedence:
   WildPokemonFactory owns friendship in boxData.substructs[0] and has no
   top-level friendship; main's explicit temporary player uses that factory.
   TrainerPokemonFactory owns its new top-level friendship and has no boxData.
   A present boxData therefore wins over stale top-level metadata, including
   when boxed friendship is absent. Synthetic missing fields remain nil,
   zero remains zero, and no species fallback, empty IVs or boxData is made.
4. Literal input oracles cover distinct six-IV values, wild/temporary-player
   snapshots, encrypted starter-party provenance despite stale metadata,
   trainer default/custom layouts and base friendship35/0, mutations in
   both directions, independent snapshots, fresh switch-in values, and
   absent/partial synthetic inputs. Expected values come from known inputs
   and source arithmetic, not bridge readback.
5. Unchanged persistPartyBattler decodes authoritative party data and changes
   HP/PP/status only. Mutating battler friendship/IVs cannot overwrite party
   values. Tests verify all six preserved IVs, friendship, encrypted-record
   checksum and SaveFileCodec roundtrip. Constructor changes add no RNG calls;
   scripted witnesses retain wild5/starter4/trainer2 draws, with bridge and
   persistence taking none.
6. Snapshot lifetime matches source: level-up changes party friendship but
   refreshes active battler level/HP/stats only
   (`battle_script_commands.c:3314-3329`). This runtime applies rewards
   post-battle. Future in-battle EXP must retain authoritative party values
   for rebuilt switch-ins. League setup raises
   (`battle_main.c:711-713`, `pokemon.c:5478-5487`) and faint-party friendship
   updates remain separate prerequisites; H1 neither implements nor claims them.

## Independently reproduced evidence

All Lua commands used `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY
PATH=toolchain:$PATH`; no ROM was accessed.

- Baseline `bash scripts/test_all.sh`: PASS206 files, expected ROM skips.
  Log `/tmp/firered-h1-review-baseline-20261031.log`.
- Exact-head same full suite: PASS207 files, expected ROM skips.
  Log `/tmp/firered-h1-review-final-20261031.log`.
- Separate focused reruns: H1 87/0; bridge32/0; trainer9/0;
  wild29/0 with ROM fixture skip; starter test explicitly SKIP without ROM;
  BoxPokemonCodec32/0; SaveFileCodec93/0; V4a243/0.
- `tests/phase4_variable_power_v4a_effect_rom_test.lua`: explicit no-ROM
  SKIP, stating F4 trainer merge gate unproven.
- `lua5.1 scripts/check_repository.lua`: PASS335 tracked Lua,
  398 tracked Markdown,1321 local targets.
- `git diff --check 7b33214 c50c097`, `git diff --check`, and clean
  exact-head `git status --short`: PASS.

## Next allowance and remaining gates

Parent may adopt this exact bounded H1 PASS and independently decide the
separate V4b inventory step. This report supplies no ROM/runtime evidence,
no guarded request/retry allowance, and no remote publication authority.
V3 remains an unmerged dependency; V4a local PASS remains bounded. Required
non-skipped verified-ROM/F4 trainer-scan evidence, runtime/full-relay evidence,
fresh base applicability/remote/public-CI checks, independent required outcome
review and publication/merge gates stay open with the parent. H2/V5, league
friendship setup, in-battle EXP and broader battle/phase closure stay separate.
No cross-boundary concern requiring escalation was found.
