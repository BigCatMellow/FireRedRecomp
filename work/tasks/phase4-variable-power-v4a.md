# Task: V4a friendship and IV-derived battle formulas

- Task ID: `P4-VARIABLE-POWER-V4A`
- Status: `LOCALLY_REVIEWED_PASS — formulas; external merge gates pending`
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

## Worker source lock and local package — 2026-10-30

Source checkout `/home/home/FireRedRecomp-reference/pokefirered` verified by
`git rev-parse HEAD` as exact `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
No ROM was read or searched. Independently inspected source:

- `src/battle_script_commands.c:8228-8236`: integer friendship formulas;
  `src/pokemon.c:2398-2406`: zero override uses record power and nonzero type
  override masks its flags. Return/Frustration records have power1.
- `src/battle_script_commands.c:8503-8530`: six IV fields in
  HP/Attack/Defense/Speed/SpAttack/SpDefense order, bit0 for type, bit1 for
  power; skip Normal and Mystery, set both dynamic-type flags.
  `data/battle_scripts_1.s:1735-1738`: Hidden Power calculation before accuracy.
- Dynamic readers: `src/battle_script_commands.c:1038,1073,1285`;
  `include/battle.h:469-475`; `src/pokemon.c:2383-2630` for the damage split,
  ability/weather terms. Existing local move-copy path reaches these engine
  readers without mutating ROM move records or AI estimates.
- `src/battle_script_commands.c:1751-1756,1823-1843,4103-4109,8527`:
  Hidden Power's damage record is physical Normal, so even Fire never thaws.
  Weather Ball sets only the other flag (`:9352-9360`) and still thaws.
  Future Counter/Mirror Coat history semantics remain outside this slice.
- `src/data/battle_moves.h:2811-2822,2837-2848,3084-3095`: three exact records,
  singleton effect families, all Normal/power1/accuracy100; Return and
  Frustration PP20/contact flags0x33, Hidden Power PP15/noncontact flags0x32.
- Snapshot source remains `src/battle_controller_player.c:1540-1547` and
  `src/battle_controller_opponent.c:475-482`; no default values invented.

Only six allowlisted paths change: `src/core/BattleEngine.lua`, the new
`tests/battle_variable_power_v4a_test.lua` and
`tests/phase4_variable_power_v4a_effect_rom_test.lua`,
`tests/phase4_move_effect_inventory_test.lua`,
`work/reports/phase4-move-effect-inventory.md`, and this task. No controller
edit was needed: the existing two-argument admission defaults to `self.player`,
while resolution explicitly supplies its attacker. Optional friendship is
validated; all six optional IVs are validated and copied. Formula helpers
are pure, move overrides are action-local, and effect135 is excluded from
the move-end defrost. Inventory classes stay unchanged (`B` for these three);
absent-input admission totals become 297/57, uncovered positive admissions17.

### F4 trainer gate: exact stronger scope, still unproven against ROM

Pinned-source command
`rg -n 'MOVE_(RETURN|FRUSTRATION|HIDDEN_POWER)' src/data/trainer_parties.h`
returned no matches (exit1). This is source-only absence, not a ROM result.
The fixture scans **every trainer with custom moves** (partyFlags bit0),
including held-item/no-item layouts, all party sizes, AI tiers and maps.
It asserts that no custom move is 216/218/237 and that the scan is nonempty.

This all-record superset avoids a guessed playable trainer roster. Production
`main.lua:1501-1531` ordinary battle entry accepts only partyFlags0/1,
sizes1/2 and selected AI tiers in singles; every custom party it can accept
is included by the stronger fixture. Oak-lab rivals are flags0
(`main.lua:1389-1394`) and have no custom moves. Parent approved this stronger
all-custom-trainer scope. **A non-skipped SHA-verified fixture pass remains
mandatory before merge.** A failure blocks V4a pending H1; a no-ROM skip
does not discharge F4. No current-area reachability claim is inferred.

### Evidence and independent-review handoff

Worktree `/home/home/FireRedRecomp-v4a`, branch
`work/variable-power-v4a-20261030`, base `71a2678` stacked on PR58 head
`9d761f49488156619c3cf87a49bb1958437083c8`. Live `gh pr view 58` could not
connect to api.github.com in the restricted environment; parent owns fresh
remote/base recovery before publication. Shared coordination files continue
to track the parent's other task and were not changed outside this allowlist.

Actual local commands/results:

- Baseline `env -u POKEPORT_ROM bash scripts/test_all.sh`: PASS204 files;
  ROM-dependent checks skipped. No consequential edits preceded baseline.
- `env -u POKEPORT_ROM lua5.1 tests/battle_variable_power_v4a_test.lua`:
  **243 passed, 0 failed**. Independent literal friendship and damage
  oracles, all64 type bit patterns, isolated power bits, input domain and
  aliasing checks, split/STAB/effectiveness/weather/Thick Fat/Blaze/Hustle,
  screens, crit/random, dynamic-copy leakage, freeze control, side isolation,
  player no-turn/PP/RNG/AI refusal and foe refusal/resolution assertions.
- `env -u POKEPORT_ROM lua5.1 tests/battle_scene_controller_test.lua`:
  **144 passed, 0 failed**.
- `env -u POKEPORT_ROM lua5.1 tests/phase4_move_effect_inventory_test.lua`:
  expected partition PASS, ROM admission SKIP.
- `env -u POKEPORT_ROM lua5.1 tests/phase4_variable_power_v4a_effect_rom_test.lua`:
  clean SKIP, explicitly reports F4 unproven.

- Final `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY bash scripts/test_all.sh`:
  **PASS206 files**, ROM checks cleanly skipped. Includes the final243/0 V4a
  focused suite and unchanged controller regression.
- `lua5.1 scripts/check_repository.lua` after staging new tests:
  **PASS334 tracked Lua, 396 tracked Markdown, 1318 local targets**.
- `git diff --check` and `git diff --cached --check`: PASS, no whitespace errors.

Independent Reviewer must inspect the exact local commit returned with this
receipt; Worker does not approve its own work. Pending: reviewed applicable
base, independent V4a review/public CI, non-skipped SHA-ROM three-record/F4
fixture, and parent publication authority. H1 still owns all live input
plumbing; V4b owns bridge evidence/final inventory flip. No push, merge,
runner/request, guarded execution, party/AI/main or phase-status change.

## Orchestrator local adoption — 2026-10-31

Adopted [independent bounded PASS](../reviews/2026-10-30-variable-power-v4a-implementation-review.md) for exact `2139495`. This task status records local review only; no missing ROM/F4/base/public-CI/publication or runtime/phase gate is waived. Implementation code remains byte-identical to its reviewed revision.
