# Task: source-locked modeled-singles Wonder Guard behavior

- Task ID: `P4-WONDER-GUARD`
- Status: `READY_FOR_REVIEWER — local implementation only; independent acceptance pending`
- Goal: add exact action-local Wonder Guard damage blocking/result semantics for the currently represented modeled-singles routes; do not claim whole ability/AI/RNG parity.
- Base: independently reviewed combined local tree `c7787a5`, full209 no-ROM PASS; [integration provenance PASS](../reviews/2026-10-31-local-integration-review.md).
- Authority: [corrected source/design](../reports/phase4-wonder-guard-design.md), source pret `c75f352304d529f6ba92d4f74b9cf8b5c3810788`; [final source review PASS](../reviews/2026-10-31-wonder-guard-design-final-review.md), SHA256 `f9718f67ad8a96d8095c683e00c7b286f2f1d741752d664f8949f2550835d1c9`. Prior NEEDS_FIX reviews remain history; corrected final governs.
- Risk: high: route-specific effectiveness/miss flags, script order and RNG. Lane: full relay with this bounded local source/design/implementation/review stage; no guarded authority or final runtime acceptance.

## Exact MAY CHANGE

`src/core/BattleEngine.lua`; `src/core/BattleFormulas.lua` (pure opt-in helpers only; existing typeCalc caller semantics unchanged); `src/core/BattleSceneController.lua` (narrow Wonder Guard result event/text only); new `tests/battle_wonder_guard_test.lua`; new `tests/phase4_wonder_guard_effect_rom_test.lua`; this task. Existing `tests/battle_scene_controller_test.lua` may receive focused new Wonder Guard assertions only if needed; prefer new focused file. Do not alter unrelated baseline assertions.

## MUST NOT CHANGE

No main, party/bridge/factory/save/importer, AI/TrainerAbilityHistory or producer-history wiring, other abilities (Rock Head/Ooze/etc), shared architecture/VM, generic unblocked RNG repair, unsupported effect implementations or admission expansion, move inventory/phase/coordination, workflows/runner/requests/probes, local ROM access/search, extracted content, push/merge/publication. No generic result-bit framework or persistent/cross-turn state addition; use bounded action-local flags/reasons/helpers.

## Required source behavior and acceptance

1. Follow every represented route in the final design. Preserve record power, dynamic/static type reader differences, charging/Struggle/power0 exclusions, ordinary typecalc net flags, random-miss full OR scan and typecalc2 ordered OR scan stopping at first zero. Do not collapse these predicates or type-immunity/WonderGuard-MISSED. Preserve exact text/result priority and current defender identity.
2. Implement/test normal direct hit, random miss vs early Protect/semi-invulnerability, Earthquake/Magnitude, Rollout/IceBall lock cancellation and early draws, FuryCutter counter reset/early draws, Present damage/heal/full branches (including blocked HP but retained heal text), fixed/level/SuperFang/Psywave/Endeavor, OHKO, multihit/TripleKick source count/reason oddities, Explosion self-faint/reason precedence, JumpKick crash and locked Rampage true-immunity vs WonderGuard-MISSED differences. Do not implement Counter/MirrorCoat/Bide: their existing B/fallback semantics remain explicitly unclaimed.
3. Parent pins RNG scope: source-correct tail draws on NEWLY WonderGuard-blocked represented routes, preserving existing unblocked generic-hit RNG gap. No global gap fix or replay parity claim. Psywave oracle is3+r where r counts rejected samples; sample11,15,10 yields5 total draws in the specified guarded trace. Exact source state/PP/HP/lock/draw tests distinguish paths and both sides.
4. Dynamic HiddenPower/WeatherBall type must affect relevant normal/miss guard queries without mutating shared records. Preserve HiddenPower fire no-defrost and existing formula/ability/STAB/weather behavior. Table-driven normal/super4x/resisted/dual-neutral/immune oracles include source chart-order exceptions from final review; negative controls lack ability25 and status/power0/Struggle.
5. Controller prints the distinct source defender ability message through a narrow event; never fake HP damage. Use known source text/native existing naming/line conventions, no new general presentation system. No source history writes or AI claim; ability-history helper remains unattached and unmodified.
6. Add SHA-first opt-in ROM fixture using existing import interfaces, validating relevant ability/species/move records without guessed offsets/private path/content output. It must skip honestly without ROM; non-skipped evidence remains an external acceptance gate. Do not change importer/schema/address tables if input is missing; stop and report.
7. Baseline then final complete no-ROM suite; focused exhaustive source-derived guard/RNG/state/controller assertions, V3/V4a/H1/V4b and battle/controller regressions; repository checker and whitespace. All oracle values must be independently source-derived. Do not repeat prior complete campaigns unless changed paths/failure justify it.
8. Freeze local exact commit with tests/source citations/remaining external gates. Independent Reviewer must reconstruct source conformance and exact scope. No self-approval, behavior/phase completion, runtime/ROM or public-CI claim.

Stop for new source UNKNOWN, required unlisted file, generic architecture/new persistent state, source-result behavior needing broader UI, or conflicting prior task assumptions. Report smallest correction/blocker without expanding. Parent accepted coherent all-represented-route leaf; do not substitute partial guard/refusal approximations. Source-only and no-ROM PASS do not waive shared-main approval, unmerged V3/base, supported-ROM/F4, guarded-route or publication requirements.

## Worker implementation receipt — 2026-10-31

Implemented locally on `work/wonder-guard-20261031`, dispatched at `c1a3cc4`
above independently reviewed combined base `c7787a5`. Source checkout was
revalidated at `c75f352304d529f6ba92d4f74b9cf8b5c3810788`; the governing design
SHA256 remains `f9718f67ad8a96d8095c683e00c7b286f2f1d741752d664f8949f2550835d1c9`.
Parent dispatch governs over inherited historical coordination; those files
remain untouched. The exact local freeze revision is delivered to the parent
for separate independent review; this receipt is not a self-approval.

Changes are confined to six permitted paths: engine, formulas, controller,
this task, [focused tests](../../tests/battle_wonder_guard_test.lua), and
[opt-in fixture](../../tests/phase4_wonder_guard_effect_rom_test.lua). The
formulas helper is a pure opt-in full/ordered chart scan; existing `typeCalc`
semantics/callers stay unchanged. Engine action-local flags retain true type
immunity separately from the ability miss reason. Normal net flags, ordinary
random-miss OR flags, and static-type typecalc2 first-zero flags remain distinct.
No generic VM, result-bit framework, persistent state, AI/history wiring,
admission/inventory/main/save/import changes, or other ability implementation.

Represented-route evidence includes original record power and dynamic Hidden
Power/Weather Ball types, charge/Struggle/power0 exclusions, both defender
identities, early Protect/semi misses versus random failures, hit-all miss
labels, Rollout/Ice Ball lock cancellation, Fury Cutter reset before random,
Present damage/heal/full branches, fixed/level/current-HP/Endeavor/Psywave/OHKO,
multihit/Triple Kick count and reason, Explosion self-faint/result priority,
Jump Kick crash and Rampage actual-immunity versus MISSED cleanup. The narrow
controller event prints the source defender ability line without a damage/HP
entry. Present retains its existing heal event/text with unchanged HP/amount0
when MISSED prevents healing.

Additional explicit source detail within ordinary represented routes: Absorb's
bespoke script has no `seteffectwithchance` (`data/battle_scripts_1.s:325-365`),
so a newly Guard-blocked Absorb takes accuracy + crit + damage-random =3 draws,
with no drain or tail. Other ordinary blocked hit scripts consume their reached
source tail, including failed CERTAIN effects. Fury Cutter and early Rollout
skip that tail; Explosion has no such command. This is a route-specific detail,
not an expansion into Liquid Ooze or other ability work.

Literal accepted traces are independently asserted: Present heal/full2;
Rollout landed/miss1 or Protect0; Fury Cutter landed2/miss1; blocked first
neutral Triple Kick4 with displayed count1 and no ability text; Explosion3
or Protect2 while still self-fainting; fixed2; OHKO1; Psywave3 accepted or
5 for accuracy, rejected11, rejected15, accepted10, tail. True immunity and
ability result priorities are separately checked. The existing unblocked
generic3-draw hit and unblocked Triple Kick omitted-tail limitations are
preserved controls, not a global RNG/replay-parity claim. Counter/Mirror Coat/
Bide remain source-unclaimed B/fallback routes, explicitly excluded and tested.

Evidence (Lua5.1, `POKEPORT_ROM` and `POKEPORT_RUNTIME_REPLAY` unset):

- Baseline `bash scripts/test_all.sh`: PASS209 files; log `/tmp/wg-baseline.log`.
- `lua5.1 tests/battle_wonder_guard_test.lua`:569 passed,0 failed. Source-derived
  literal state/PP/HP/result/draw/controller assertions; no implementation-derived
  expected values.
- Final `bash scripts/test_all.sh`: PASS211 files; log `/tmp/wg-final-no-rom.log`.
- Focused unchanged regressions: V3 144/0, V4a243/0, H1 friendship/IV snapshots87/0,
  V4b93/0, battle engine570/0, controller144/0, Rampage49/0,
  multihit tail83/0, status leftovers102/0 and L2 93/0. Logs
  `/tmp/wg-regressions.log` and `/tmp/wg-regressions-rest.log`.
- Opt-in fixture: honest no-ROM SKIP. SHA verification precedes record access;
  existing parsers validate ability25 name, Shedinja303 and18 relevant static
  move records when an explicitly supplied supported ROM is available.
- `lua5.1 scripts/check_repository.lua`: PASS340 tracked Lua,418 tracked Markdown,
  1349 local targets. `git diff --cached --check`: PASS.

No local ROM access/search, runner request, guarded run, runtime replay,
public CI, push, merge or publication was performed. Non-skipped verified-ROM
fixture evidence and independent exact-revision review remain external gates;
all existing shared-main/base/V3/V4a/F4/guarded-route gates remain unchanged.
No source UNKNOWN or required unlisted path was encountered. The parent must
route the frozen commit to a separate Reviewer before any acceptance/status
advancement; capability and coordination files remain unchanged.

## Independent exact implementation review — correction dispatch

[Review of exact47d88a6](../reviews/2026-10-31-wonder-guard-implementation-review.md) returned NEEDS_FIX. Passing211/focused569/checker does not satisfy source conformance; independent probes failed12 cases across both sides. Parent routes only these corrections within the original code/test/task envelope:

- R1: source hit-all Earthquake/Magnitude has no seteffectwithchance tail. Newly blocked landed Earthquake must use3 draws and Magnitude4; remove only their mistaken tail, preserve Absorb3 and ordinary blocked4.
- R2: hit-all missed-label normal typecalc enters with preexisting MISSED, suppressing global super/resist updates. Super Ground vs Fire+WonderGuard protected/random/semi-miss must use the source WonderGuard reason; preserve the distinct miss-helper/typecalc2 scans and no extra draws.
- R3: BrickBreak after actual screen removal clears MISSED/DOESNT_AFFECT and repeats ordered typecalc2. Fighting vs WonderGuard Ghost/Dark with a screen produces immunity text/noEffect, whereas no-screen control retains earlier WonderGuard reason; total4 draws unchanged.

These concrete pinned-source findings supersede contradictory earlier literal oracles. Correct engine/helper as needed, focused expectations and task receipt, both sides and source cited controls; no broader cleanup or baseline rewrites. Freeze corrected exact revision for independent delta re-review of R1–R3 plus regression/scope. No publication, ROM, runner or acceptance action authorized.

## Worker R1–R3 correction receipt — 2026-11-01

Resumed the same branch/worktree at parent metadata-only `08df0f1` above
original implementation `47d88a6`. The [independent exact47 review](../reviews/2026-10-31-wonder-guard-implementation-review.md)
remains **NEEDS_FIX** for that old revision. Its concrete pinned-source
findings supersede the contradictory original literal oracles; original
569/211 green evidence did not establish source conformance. No previous
review receipt was edited, and no baseline or broad source research was
repeated. The service interruption preserved the existing correction edits;
no ongoing service blocker was encountered on resume.

Only engine, focused tests and this task changed in this correction delta:

- **R1:** newly blocked landed Earthquake takes accuracy + crit + random =3
  draws; Magnitude adds its earlier strength draw =4. The hit-all scripts
  have no secondary-tail command (`data/battle_scripts_1.s:1830-1875`,
  Magnitude enters at `:1679-1688`). Both-side literal oracles now cover
  these counts. Absorb3 and ordinary blocked4 remain passing controls.
- **R2:** the hit-all missed-label query retains true type immunity but
  suppresses super/resist because preexisting MISSED is a NO_EFFECT bit
  (`battle_script_commands.c:1254-1271`, scripts `:1836-1847,1867-1875`).
  Ground against Fire+WG now selects the ability reason for protected,
  random-miss and semi-miss paths, without extra RNG. Both effects/sides
  have HP/PP/draw/reason assertions, with ordinary random-miss and ordered
  typecalc2 super-effective controls remaining distinct. Existing shared
  `typeCalc` and opt-in scan semantics were not changed.
- **R3:** an action-local indication retains actual Brick Break screen
  removal. After the first typecalc/random, removal clears the modeled
  MISSED/DOESNT_AFFECT; ordered static-type typecalc2 then runs
  (`scripts:2413-2444`, `battle_script_commands.c:9441-9461`). Fighting
  versus Ghost/Dark finds Dark-super before Ghost-zero: screen removal
  leaves immunity/noEffect, while no-screen retains the prior WG reason.
  Both-side tests cover both defender type orders, Reflect/Light Screen/
  both/no screens, preserved4 draws, HP/PP and screen cleanup. Ghost mono
  and neutral controls reassert WG after the second scan; a super-effective
  unblocked control preserves the existing generic3-draw gap.

Completed evidence with `POKEPORT_ROM` and `POKEPORT_RUNTIME_REPLAY` unset:

- `lua5.1 tests/battle_wonder_guard_test.lua`: **768 passed,0 failed**.
- Reviewer-owned unchanged `/tmp/firered-wonder-guard-review-probes-20261031.lua`:
  **30 passed,0 failed**, previously18/12 on old47. Worker rerun log
  `/tmp/wg-r1-r3-reviewer-probes-20261101.log`; this is verification of the
  correction, not independent acceptance of the new head.
- `bash scripts/test_all.sh`: **PASS211 files**, honest ROM skips. Log
  `/tmp/wg-r1-r3-full-no-rom-20261101.log`.
- Focused unchanged regressions: V3 144/0, V4a243/0, H1 87/0, V4b93/0,
  engine570/0, controller144/0, Rampage49/0, multihit tail83/0,
  leftovers102/0 and L2 93/0. Log `/tmp/wg-r1-r3-regressions-20261101.log`.
- `lua5.1 scripts/check_repository.lua`: **PASS340 tracked Lua,419 tracked
  Markdown,1351 local targets**. `git diff --check`: PASS.
- Opt-in WG ROM fixture: honest SKIP; no ROM was supplied/accessed/searched.

The exact corrected local commit is delivered to the parent for independent
R1–R3 delta re-review plus scope/regressions. No Worker acceptance, source-wide
parity, ability history/AI, global RNG fix, phase advancement, ROM/runtime/
public-CI evidence, runner, publication, push or merge is claimed. All original
external gates remain. Parent review/coordination artifacts are untouched by
this delta, and no unlisted path or new source UNKNOWN was needed.

## Parent corrected-head local adoption — 2026-11-01

[Independent correction PASS](../reviews/2026-11-01-wonder-guard-correction-review.md) accepted exact `aec82136113bd3a73fde1fbc004cbeeb706e5791`, including unchanged independent probes30/0, focused768/0, controller144/0, full211 and checker/whitespace. Earlier47d88a6 remains NEEDS_FIX history. R1–R3 source findings and corrected oracles supersede conflicting original literal design assumptions. Parent adopts bounded local source/no-ROM behavior only; no missing supported-ROM/F4/base/public-CI/merge/runtime/phase gate is waived.

## Local draft-stack publication base — 2026-11-01

For preparation of a possible separate draft PR only, the exact corrected
implementation snapshot `aec82136113bd3a73fde1fbc004cbeeb706e5791` has been
materialized on `work/review-ready-wonder-guard-20261101` above published V4b
head `4b23e7f45a8e86fbdbb762731461df80a0e724c5` (PR61). The five explicitly
allowlisted engine/formula/controller and WG test/fixture blobs are copied
byte-for-byte from that independently reviewed corrected head; this is not a
semantic edit or a cherry-pick of incomplete predecessor history. Every other
source/test path remains identical to the V4b base. The source-conformance PASS
and 211-file local no-ROM evidence remain exactly the bounded evidence recorded
above, not a fresh publication-head acceptance. Public no-ROM CI would follow
only separately authorized draft publication. Non-skipped supported-ROM/F4,
applicable base/V3/full-relay/runtime evidence, and explicit merge approval
remain open before any merge; this note grants no publication, merge, ROM,
runner, runtime, or phase authority. Independent exact candidate-head review
is pending.
