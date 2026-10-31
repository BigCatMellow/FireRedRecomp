# V4a independent local implementation review — 2026-10-30

**PASS** for the bounded local V4a implementation criteria at exact frozen
`2139495897c5def7e0bef8fdcad0fd8e359f4dfd`. No implementation correction
identified. This is not merge approval, V3 acceptance, a full-runtime result,
or Phase 4 completion.

## Identity and boundary

- Reviewed detached worktree: `/tmp/firered-v4a-review-20261030`.
- Contract base: `71a2678`; stacked PR58 base head:
  `9d761f49488156619c3cf87a49bb1958437083c8` (unmerged prerequisite).
- Independently verified reference HEAD:
  `c75f352304d529f6ba92d4f74b9cf8b5c3810788` at the supplied source checkout.
- Read AGENTS, REVIEWER, coordination flow/policy/current state, capability
  checklist, active V4a task, accepted design, and F1/F4/D1/D2 review.
  The active task says READY_FOR_REVIEWER for local implementation only;
  shared coordination continues to describe the parent's separate task.
- Fresh `gh pr view 58 --json number,state,headRefOid,baseRefName,mergeCommit`
  failed connecting to api.github.com. Fresh remote/base/public-CI recovery
  remains the parent's prerequisite; no remote state is certified here.
- Only the six task-allowlisted paths differ from `71a2678`: BattleEngine,
  the two V4a tests, inventory test/report, and V4a task. No controller,
  main/party/AI/factory/bridge/save/workflow/request/runner/phase-status edits.
  The diff contains text implementation/tests/documentation, no ROM or
  extracted content. Worker checkout was not edited. No push or merge.

## Independent findings

1. Friendship uses source integer arithmetic and zero-override record-power
   fallback (`battle_script_commands.c:8228-8236`, `pokemon.c:2398-2406`).
   Tests contain literal source-derived friendship/power/damage oracles,
   including all requested boundaries, rather than engine-readback values.
2. Hidden Power uses the six fields in HP/Atk/Def/Speed/SpA/SpD order, bit0
   for type and bit1 for power, with Normal/Mystery excluded
   (`battle_script_commands.c:8503-8530`). All0 Fighting30 and all31 Dark70,
   Steel/Fire split cases, and full 64-pattern type table agree with source.
3. Action-local move copies are constructed before accuracy and every
   represented dynamic-type reader. Independently traced Hustle accuracy,
   physical/special damage, Thick Fat/pinch ability terms, screens, weather,
   STAB/effectiveness, and currentMove. The shared move records remain the
   AI's Normal/power1 records. No formula RNG was introduced. Source runs
   hiddenpowercalc after attackcanceler and before accuracy
   (`battle_scripts_1.s:1735-1738`); the earlier pure local calculation has
   no differing represented canceller consumer or state effect.
4. The F1 exclusion is present at move-end defrost. Fire Hidden Power keeps
   its target frozen; Fire Weather Ball still thaws. This matches the
   special dynamic flag/datahpupdate distinction at source lines1751-1756,
   1823-1843,4103-4109,8527. Future Counter/Mirror Coat damage-history
   semantics remain outside this slice.
5. Optional data is range/integer validated, including all six IV fields,
   with no invented absent values. Construction copies IV scalars into a
   separate table and copies friendship's scalar value. Caller mutation
   and other-side construction cannot change the snapshot. Admission's
   compatible two-argument call uses the player; resolution explicitly
   supplies its actual attacker. Missing player data is refused by the
   existing controller before AI/turn/PP/RNG; missing foe data follows the
   existing unsupported-effect error before PP/RNG. Populated opposite-side
   data cannot admit an absent attacker. Unrelated callers retain behavior.
6. Inventory classes remain B; 297/57 admission counts describe absent
   inputs, while populated snapshots admit the three families conditionally.
   H1 and V4b remain explicit prerequisites for live input/final inventory.
7. The fixture verifies the supported SHA before parsing, asserts exact
   three records/singleton effect families, then scans every trainer record
   with custom-move bit0, all party sizes and both held/no-held-item layouts,
   all four moves per mon. The nonempty scan has no guessed map/AI roster.
   This stronger F4 superset is correctly encoded. Pinned trainer source
   has no target move references (independent rg exit1). Neither source
   absence nor synthetic probes discharge the real-ROM F4 gate.

## Reproduced evidence

- Independently ran baseline at detached `71a2678`:
  `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY bash scripts/test_all.sh`:
  PASS204 files, ROM skips. Log:
  `/tmp/firered-v4a-review-baseline-20261030.log`.
- Exact-head same complete command: PASS206 files, ROM skips. Log:
  `/tmp/firered-v4a-review-full-20261030.log`.
- `env -u POKEPORT_ROM lua5.1 tests/battle_variable_power_v4a_test.lua`:
  243 passed /0 failed.
- `env -u POKEPORT_ROM lua5.1 tests/battle_scene_controller_test.lua`:
  144 passed /0 failed.
- Inventory: expected partition checked, SHA-ROM portion SKIP.
  V4a fixture: clean SKIP explicitly preserving unproven F4.
- `lua5.1 scripts/check_repository.lua`: PASS334 tracked Lua,
  396 tracked Markdown,1318 local targets.
- `git diff 71a2678 2139495 --check`, `git diff --check`, clean review-tree
  status: PASS.
- Independent `/tmp/firered-v4a-review-adversarial-20261030.lua`: PASS4608
  exhaustive formula cases (both formulas over all256 friendship values
  with non1 fallback, all4096 type/power bit-pairs with upper bits set).
- The same script independently executed the checked-in ROM fixture with
  synthetic bytes/record stubs and actual TrainerParty decoding: PASS147
  cases. Verified both custom layouts, all6 party positions, all4 move
  positions, and all3 target moves at final trainer index742 trigger the
  F4 refusal; clean controls pass. A failed verification prevents parser
  and fixture file-open access. No real ROM was supplied or accessed;
  these cases prove fixture control flow, not F4's real-ROM result.

## Exact next allowance

Parent may adopt this bounded local review without an implementation fix.
Before merge, retain the applicable reviewed/accepted base, independent
public-CI gate, publication authority, and **non-skipped SHA-verified
three-record/F4 all-custom-trainer fixture**. A forbidden trainer move
blocks V4a pending H1. PR58/V3's unmerged base and full-relay uncertainty
remain unresolved here. H1 owns live friendship/IV plumbing; V4b owns its
bridge evidence/final inventory change. No full-runtime or phase claim.

Exact minimal correction: **none**. No correction implemented. Shared
coordination files were intentionally left to parent reconciliation under
the narrower six-path/local-only task and this /tmp-artifact handoff.
