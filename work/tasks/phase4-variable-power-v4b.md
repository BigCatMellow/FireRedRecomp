# Task: V4b native-input integration and final conditional inventory coverage

- Task ID: `P4-VARIABLE-POWER-V4B`
- Status: `READY_FOR_WORKER — H1 bounded local PASS adopted`
- Base: H1 `c50c097bd5d3db10151398723287cfb547e014a1`, stacked V4a `2139495` and unmerged V3 `9d761f4`.
- Source: [reviewed variable-power design](../reports/phase4-variable-power-design-proposal.md) V4b/H1/F4/D1/D2 and [H1 handoff](../handoffs/2026-10-21-battle-friendship-ivs-handoff.md), pin `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
- Goal: prove authoritative native party/wild/trainer inputs reach Return/Frustration/Hidden Power, then mark their bounded coverage represented without implying ROM/runtime/phase acceptance.
- Risk: medium, metadata must preserve the distinction between valid native inputs and missing-input refusal.

## MAY CHANGE

`tests/battle_variable_power_v4b_test.lua` (new); `tests/phase4_move_effect_inventory_test.lua` (effects121/123/135, explicit populated-versus-absent input admission scope/counts); `work/reports/phase4-move-effect-inventory.md` (those rows and related counts/notes); this task (source/evidence only).

## MUST NOT CHANGE

No production code of any kind, H1 constructor behavior, V4a formulas, saves/schema/importers, main/AI/engine/controller/factories, generic tests beyond literal allowlist, capability/phase/coordination, workflows/runner/requests/probes, ROM search/access, push/merge or guarded execution. Existing V4a all-custom-trainer F4/SHA fixture remains pending and is not waived by H1.

## Acceptance

1. Integration tests drive actual Bridge/factory constructors with known synthetic source-consistent inputs. A saved party record's friendship and all six IVs, wild boxData/IVs and trainer species-base friendship/fixed IVs must reach battlers and actual move computation. Check all three move identities, boundary/type/alias/snapshot cases as needed to prove wiring, rather than duplicating exhaustive V4a formula tests. At least one controller selection/resolution witness demonstrates production-facing valid-input admission after H1; absent data still refuses with no turn/PP/RNG.
2. Inventory effects121/123/135 become represented with stated source/no-ROM limits, H1/V4b evidence and ROM fixture pending. Expected coverage: represented134families/283moves/198positive/85zero; blocked63/70/17/53. Compute/verify these literal expectations from source partition delta, never derive expected values from implementation predicates.
3. Make admission scope explicit: native populated friendship/IV inputs permit all three records (live-input aggregate300admitted/54rejected), while explicit missing-input API remains297/57. Do not silently replace missing inputs or hide absent-data checks. Source-derived partition labels and metadata remain separate from SHA-ROM execution. The ROM inventory probe may use an explicitly populated attacker for the native-input aggregate plus separate negative missing-input assertions for these three.
4. Retain source membership and all unrelated rows/assertions. No broad baseline update. `represented` is bounded native-input coverage, not whole battle RNG/trainer AI/parity or verified ROM output.
5. Baseline/final no-ROM full suite, new integration focused tests, V4a/H1/controller regressions, inventory source partition and checker/whitespace. With no ROM, inventory/fixture ROM portions must explicitly skip; no fake non-skipped receipt.
6. Freeze a local commit and exact tests/limits for independent Reviewer. External unmerged V3/base, F4 non-skipped SHA-ROM, public CI and applicable publication approval remain before merge; this task authorizes none of them. League friendship raise/in-battle EXP remain separate H1 constraints.

Stop for required production-code correction, missing data/source uncertainty, unexpected source counts or unlisted file: route smallest fix separately, never widen this evidence-only package. Parent authorizes parallel standalone helper work only because it changes independent new paths with no production entry point or V4b dependency.

## Dispatch receipt

Parent adopted [independent H1 local PASS](../reviews/2026-10-31-battle-input-h1-implementation-review.md) for exact `c50c097`. V4b evidence-only local work may proceed. H1 full207/focused87, bridge32/trainer9/V4a243 and checker PASS; external gates unchanged.

## Worker local evidence — 2026-10-31 (independent review pending)

Evidence-only implementation on `work/variable-power-v4b-20261031`, base
`d7eee4e`. Exactly the four allowlisted paths changed; no production correction
was needed. New integration covers saved encrypted party data after an actual
save-codec roundtrip (including stale-cache rejection), wild boxed friendship
and six IVs, default/custom trainers' species friendship and fixed IVs, isolated
snapshots, all three actual move computations per origin, a native controller
Return turn, and missing-input refusal for all three moves. Literal oracles are
source arithmetic, with Fire70 special, Bug54 physical and Fighting30 physical
witnesses; the exhaustive V4a formula assertions remain separate.

The source partition delta is precisely effects121/123/135 (moves216/218/237):
represented134/283/198/85, blocked63/70/17/53. Populated-native-input admission
is300/54; explicit missing-input admission is297/57. Both are literal independent
expectations in the inventory test, with separate SHA-ROM checks that skip
without a ROM. No ROM was searched, accessed or executed.

Commands run with `POKEPORT_ROM` and `POKEPORT_RUNTIME_REPLAY` unset:

- Baseline `bash scripts/test_all.sh`: PASS207 files.
- Final `bash scripts/test_all.sh`: PASS208 files; ROM portions explicitly skip.
- `lua5.1 tests/battle_variable_power_v4b_test.lua`: PASS93 assertions.
- `lua5.1 tests/battle_friendship_ivs_test.lua`: PASS87.
- `lua5.1 tests/battle_variable_power_v4a_test.lua`: PASS243.
- `lua5.1 tests/battle_party_bridge_test.lua`: PASS32.
- `lua5.1 tests/trainer_pokemon_factory_test.lua`: PASS9.
- `lua5.1 tests/battle_scene_controller_test.lua`: PASS144.
- `lua5.1 tests/phase4_move_effect_inventory_test.lua`: source partition PASS;
  SHA-ROM portion SKIP.
- `lua5.1 tests/phase4_variable_power_v4a_effect_rom_test.lua`: SKIP; F4 unproven.
- `lua5.1 scripts/check_repository.lua` and `git diff --check`: final receipt
  recorded with the frozen local commit. Initial checker invocation before
  staging correctly rejected the untracked new integration-test link.

`gh pr view 58 --json number,state,headRefOid,baseRefName` could not connect to
api.github.com; parent-provided exact-base receipts remain the dispatch input.
No push, merge, runner, coordination or phase changes. Independent Reviewer must
verify the frozen revision. Unmerged V3/base, F4 non-skipped supported-SHA ROM,
public CI and applicable publication approval remain pending and unchanged.
