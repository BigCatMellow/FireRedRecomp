# V4b independent local implementation review — 2026-10-31

**PASS** for the bounded local evidence/metadata criteria at exact
`cbc8a17f4ab346d86b0cc4d9a24f340c19ec86bf`. No implementation correction
identified. This is not merge/publication approval, verified-ROM/F4 acceptance,
full-runtime evidence, or Phase 4 closure.

## Identity and authority

- Detached review tree `/tmp/firered-v4b-review-20261031` at the exact head.
- Detached independent baseline `/tmp/firered-v4b-review-baseline-20261031`
  at contract/adoption base `d7eee4ed1e4bdc1b00866bd5e661f9c6f60ab16a`.
- Accepted H1 `c50c097bd5d3db10151398723287cfb547e014a1` is an ancestor;
  its independent constructor/source review is reused without reopening it.
- Read exact V4b task, accepted V4b design and source constraints, AGENTS and
  REVIEWER; inherited coordination/capability context remains unchanged from
  the H1 review. Exact parent dispatch supplies reviewer routing. The task's
  header still says READY_FOR_WORKER while its new receipt says independent
  review pending; parent should reconcile that routing metadata on adoption.
  This does not change the explicit review dispatch or bounded acceptance.
- Exactly four allowlisted paths changed: new V4b integration test, inventory
  test, inventory report and V4b task. No production code changed. No ROM,
  generated cache or extracted content entered the package. Worker code was
  not edited; review worktree remains clean. Canonical coordination was left
  with the parent. No remote, ROM, runner, guarded, push or merge action occurred.

## Findings

1. The integration uses actual Starter/Wild/Trainer factories, actual encrypted
   BoxPokemon and SaveFileCodec roundtrip, and actual Bridge constructors.
   Saved authoritative friendship255 and six IVs win over stale caches;
   wild boxed friendship70 wins over stale top-level255. Default/custom
   no-item trainers supply base friendship35/0 and fixed IV12. Snapshot
   mutation and fresh construction are checked. These are known synthetic
   source-consistent inputs, not claimed retail species records.
2. Every origin runs all three actual move identities216/218/237 through
   admission and resolveMove, with damage, PP and RNG assertions. Literal
   expected damage comes from source arithmetic, not implementation helpers.
   Pinned friendship and Hidden Power commands were independently inspected
   at battle_script_commands.c:8228-8236 and8503-8530; native move-record
   effect/power/type/PP/flags agree with src/data/battle_moves.h.
   Fire IV bit0=34 gives Fire; bit1=63 gives power70, producing damage18
   with the saved SpA100/targetSpD50. Wild bits21/38 give Bug54 and damage8
   with Atk20/Def20. All12 trainer IVs give Fighting30 and damage10 after
   Normal's weakness. Return/Frustration literal damage pairs are saved14/3,
   wild5/10, trainer friendship35:3/13, friendship0:3/14. Zero friendship
   and friendship255 exercise source record-power fallback boundaries.
3. A native saved-party Return goes through controller selection/resolution:
   turn advances once, target loses14HP, PP decreases once, three RNG draws
   and one AI call occur. Each missing-input synthetic move separately
   refuses through the controller before turn/PP/RNG/AI. The shared three
   move records retain power1 and Hidden Power's Normal record type.
4. Independent parsing/comparison of baseline and final inventory rows
   proves exactly effects121/123/135 changed B->R and false->true; each
   retains its one positive-power member216/218/237. Every unrelated row,
   membership, power class and admission flag remains identical. Summation
   independently yields represented134families/283moves/198positive/85zero,
   blocked63/70/17/53. Populated admission is300/54; explicitly removing
   the same three conditional singleton admissions yields297/57.
5. Inventory expectations remain literal reviewed metadata, independent of
   BattleEngine predicates. Source-partition integrity runs before ROM
   lookup. The optional supported-SHA ROM section checks actual records and
   both populated/absent attacker admission scopes, preserving the separate
   missing-input negatives. Report labels make those scopes explicit and
   retain ROM fixture/F4, native snapshot, AI/runtime and phase limits.

## Independent checks

All Lua commands used `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY
PATH=toolchain:$PATH`; no ROM was accessed.

- Baseline `bash scripts/test_all.sh`: PASS207 files, expected ROM skips.
  Log `/tmp/firered-v4b-review-baseline-20261031.log`.
- Exact-head full suite: PASS208 files, expected ROM skips.
  Log `/tmp/firered-v4b-review-full-20261031.log`.
- Separate focused reruns: V4b93/0, H187/0, V4a243/0, bridge32/0,
  trainer9/0, controller144/0.
- Inventory test: complete expected source partition PASS; actual SHA-ROM
  admission/record portion explicitly SKIP. V4a ROM fixture explicitly SKIP,
  reporting F4 trainer merge gate unproven.
- Checker: PASS336 tracked Lua,400 tracked Markdown,1325 local targets.
- Base-to-head and working-tree whitespace checks PASS; exact review tree clean.
- Independent Python inventory comparison/count calculation PASS as described
  above; it reads literal test rows and never engine admission predicates.

## Next allowance and open gates

Parent may adopt this exact bounded local V4b PASS and reconcile its task
status/conditional inventory coverage. H1 league-setup friendship raises,
faint-party updates and future in-battle EXP remain separate constraints.
Unmerged V3/V4a/base applicability, non-skipped supported-SHA ROM/F4 trainer
fixture, applicable runtime/full-relay evidence, fresh remote/public CI and
publication/merge approval remain open. No fresh remote state is certified.
No source uncertainty or production correction requiring escalation was found.
