# Task: Low Kick bounded injected-weight engine slice

- Task ID: `P4-LOW-KICK`
- Status: `READY_FOR_REVIEWER — documentation-only draft candidate; bounded implementation independently PASS`
- Type: `IMPLEMENTATION — injected ordinary-species engine slice only`
- Parent: Phase 4 battle engine in [CAPABILITY_CHECKLIST](../roadmaps/CAPABILITY_CHECKLIST.md), effect196/move67. No native/full-family or phase acceptance.
- Worker: Sol high — selection/direct-resolution contexts, locks/Struggle, damage/RNG and controller preflight need cross-file care. Distinct Sol high Reviewer follows; parent rina integrates.
- Risk: MEDIUM/HIGH — wrong target/weight, stale locks or late refusal can silently damage or mutate turn/persistence. Native merge remains blocked.
- Authority: parent implementation-stage amendment after independent design PASS; no private/ROM/main action.

## Frozen source and inherited decisions

Follow the [approved engine contract](../reports/phase4-low-kick-engine-contract.md)
at `036665f6271f90c1e6c4e83af85bf6510c7b2dc7`, SHA-256
`be0df3a0044ba1d2ada00bf1dd90882f3d2c33f15573f46a66844e5bb622e682`.
Independent corrected design PASS SHA-256
`7072c98bc89503ef4a07f7d594e8595025c78213481690dcf47eb50266f8bad9`, canonical
input `/home/home/FireRedRecomp-integrated/work/reviews/2026-11-16-low-kick-engine-contract-correction-review.md`.
Original e6633f0 NEEDS_FIX F1/F2 stays historical. Earlier source48c25e0/reportb7604b4e
and pret `c75f352304d529f6ba92d4f74b9cf8b5c3810788` supply source certainty.

Exactly implement optional **opts.lowKickWeights** in unchanged new(opts),
immutable constructor-copied plain map, ordinary species1..251/277..411,
current defender lookup, pure u16 power formula, source move67/effect196 record,
mandatory selection/resolution planner contexts with exact recharge,
lockedThisTurn/passed-slot/Struggle rules. Do not equate isLocked with direct
resolution. Preserve existing modeled ability/item/global RNG limits.
Numeric retail address/provider remains UNKNOWN/unimplemented, never guessed.

## Outcome and isolation

One local source-exact code/test package supplies injected Low Kick behavior
and refusal boundaries; absent data refuses instead of ordinary power1 fallback.
No production delivery claim. New `/home/home/FireRedRecomp-low-kick`, branch
`work/low-kick-engine-20261116`, starts at design036665f plus this task only.
Preserve frozen design/published trees/refs. Product base is clean published
WG944df72; never copy organizer/control code or separately denied recoil/native
packages, or move intentionally stale local main. Read canonical organizer
AGENTS, actual WORKER role and full approved contract before editing.

## MAY CHANGE — Worker exactly eight paths

- `src/core/BattleEngine.lua`: optional validated immutable weights, pure formula/context planner, Low Kick admission/preflights and action-local power/secondary RNG only.
- `src/core/BattleSceneController.lua`: narrow selected-player Low Kick pre-chooser arm only, other moves/callers unchanged.
- NEW `tests/battle_low_kick_test.lua`: engine/controller/source-oracle/adversarial tests.
- NEW `tests/phase4_low_kick_effect_rom_test.lua`: SHA-first source move67 singleton/record fixture, local SKIP, no weight address guess.
- `tests/phase4_move_effect_inventory_test.lua`: singleton67 default admission/conditional metadata only, literal source partition.
- `work/reports/phase4-move-effect-inventory.md`: conditional injected support/input/native gates only; receipt rows117/119/156 byte-identical.
- This task progress/evidence only, no authority widening.
- Append-only `work/coordination/FRICTION_LOG.md`.

Optional scratch receipt `/tmp/firered-low-kick-implementation-20261116.md`;
canonical evidence stays in own task. Parent alone may add exact independent
receipt `work/reviews/2026-11-16-low-kick-implementation-review.md` after PASS,
without code/test changes. Local Worker stage authorizes no publication.

## MUST NOT CHANGE

Approved design report bytes unchanged. No formulas/main/bridge/factory/importer/
AI/save/history, generic transaction/action framework, new mutable battle state,
global RNG/item/ability repair, workflow/requests/probes/replay, other effects,
shared coordination, original refs/PR, ROM/search/assets/private logs/jobs,
publication/main merge or capability status. No retail weight table/extracted
record bytes, defaults, undefined IDs or silent power1. Never promise to undo
prior chooser RNG, main switch writes or capture bag removal.

## Acceptance and evidence

1. Prove product/tests/import/main/scripts identity to944df72 before edits. Recover accepted no-ROM213/public run43930415514 test-job133520991434 baseline rather than repeat for docs-only ancestry. Record commands/proof; useful focused baseline allowed.
2. Implement all contract APIs/domains/copy/validation/context/refusal clauses and literal cases. Invalid supplied map fails before constructor isFirstTurn writes. Current/prospective target and locked/Struggle action match the actual context without planner mutation. Non-Low-Kick behavior unchanged.
3. Player refusal before chooser has no turn/PP/HP/RNG/AI call. Direct selected-foe/runTurn/resolve errors preserve engine state/events/RNG at exact entry boundaries. Retain prior chooser draws/main effects honestly, no automatic retry, fake battleEnd or new UI/save transaction.
4. Source literals cover thresholds±1/equality/u16/bad/NaN/metatable/key/missing inputs, constructor/table/move aliasing, two engines/both sides/current-species/forced/voluntary targets, timer1/timer2/live/saved locks/0PP, accuracy/crit/damage/secondary order, Ghost/WG/modeled interactions and unaffected routes. Expected values source-derived, never implementation readback. Ordinary itemless successful Low Kick has four draws; WG guardTail already supplies secondary, no double draw. Keep excluded interactions explicit.
5. Inventory remains class B, no represented flip. Only singleton67 default admission true→false: populated friendship/IV/no weights299/55/uncovered16; absent friendship/IV296/58. Separate valid injected weights restores300/54 or297/57. Verify source354 partition/scopes independently, not predicate-built expectations. Preserve all other families and V3/V2 ROM receipts.
6. Run new focused suite, controller/V4a/H1/V4b/WG/V2/V3 regressions and final foreground `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY bash scripts/test_all.sh`. New record fixture SKIPs locally and proves no provider. Stage new targets, repository/whitespace checks. Expected215 Lua files with two new tests; actual result authoritative. No ROM/replay outside authorized no-ROM tests.
7. Freeze clean head, exact8path diff, code/test/design identities, actual commands/results/limits and one next action in task/scratch receipt; task READY_FOR_REVIEWER. Distinct Reviewer verifies source conformance/assertions/contexts/engine boundaries/inventory and regressions with additional adversarial evidence, returning PASS / NEEDS_FIX / BLOCK. No Worker self-approval/publication.

## Native gate, failure and continuation

Native merge requires reviewed numeric provider/delivery and non-skipped ROM proof
covering admitted party/wild/default/custom/replacement targets, or independently
proven complete live-scope absence. Neither exists. AI prediction still sees
record power1. Engine-slice PASS closes no native/full-family/represented/ROM/F4/
full-relay/runtime/phase/CI/main gate.

Stop for source uncertainty, impossible contract, required unlisted fixture/path/
architecture or forbidden action; report smallest actual failure/needed amendment,
never weaken tests/oracles or edit unrelated paths. Append friction before report.
On interruption checkpoint exact tree/head/paths/checks and one next action.
Parent receipts/reviews and selects any later bounded draft publication under
actual authority. Prior recoil denial and all main/private operator gates remain;
parallel ROM planning grants nothing here. Seven AGI tests and ten criteria PASS
for this local stage; immutable configuration is not new mutable cross-turn state.


## Worker implementation receipt — 2026-11-16

Worker actor `/root/low_kick_engine_worker` implemented the injected slice on
`work/low-kick-engine-20261116`, isolated worktree
`/home/home/FireRedRecomp-low-kick`. Product/test freeze is
`85ec51741cd2e82e33e3d5e82c8b8c04b9606e71`; the final local descendant adds only
this task receipt. Parent records that exact clean handoff head after freeze.
This is **READY_FOR_REVIEWER**, not a Worker PASS or broader acceptance.

Recovery: `git rev-parse HEAD` initially returned
`274cbad9749e069008ac5573992028cf81be1317`. Before edits,
`git diff --name-only 944df72 -- src tests scripts import main.lua` was empty.
Thus the accepted no-ROM213 baseline is recovered by complete product/test/
import/main/script identity rather than repeated. Connected GitHub
`fetch_workflow_run_jobs(repo_full_name=BigCatMellow/FireRedRecomp,
run_id=43930415514)` independently returned public `test` job133520991434,
completed/success, including repository and no-ROM test steps. Local gh network
failure and all fixture/regression friction are recorded append-only in the
existing friction log. No private job/log or ROM was accessed.

Implementation: validates/copies optional plain weights before either caller's
isFirstTurn write, retaining only a closure-private map; pure u16 thresholds;
current-defender ordinary internal-species lookup and complete singleton67
source-shape admission guard. One shared pure effective-record planner handles
mandatory selection/resolution contexts and supplies the existing downstream
core-lock checks. Selection projects timer1 expiry/new snapshot; resolution
retains live/saved locks and passed-slot fallback. Both suppress Struggle only
after the correct lock decision. Controller selected-player refusal precedes
chooser; runTurn and direct wrappers/core preflight before their own mutations.
Action-local power preserves the shared record and Fighting type. Ordinary
Low Kick success/noEffect gains exactly its source secondary draw; WG's existing
returning guardTail remains the sole draw on its blocked path.

Exactly eight package paths differ from dispatch274cbad: BattleEngine,
BattleSceneController, new battle_low_kick_test, new phase4_low_kick_effect_rom_test,
existing inventory test, inventory report, this task, append-only friction log.
No shared coordination owner or other product path changed. Design report stays
SHA-256 `be0df3a0044ba1d2ada00bf1dd90882f3d2c33f15573f46a66844e5bb622e682`;
reference `git rev-parse HEAD` remains exact pret
`c75f352304d529f6ba92d4f74b9cf8b5c3810788`. Corrected independent design receipt
hash7072c98b was rechecked from its canonical organizer path.

Actual verification (no ROM/replay environment):

- `lua5.1 tests/battle_low_kick_test.lua`: **400 passed,0 failed**. Literal
  thresholds/damage/RNG, map/key/species/record validation, constructor/map/move
  aliasing, both sides/current/replacement targets, selection/direct locks/
  timer1/timer2/saved snapshot/zeroPP/Struggle, complete immutable snapshots,
  exact engine refusal boundaries and pre-chooser/retained-chooser-draw cases.
- `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY bash -c 'set -e; for test in
  ...; do lua5.1 "$test"; done'` ran Low Kick plus controller144/0,
  V4a243/0,H1 friendship/IV87/0,V4b93/0,WG768/0,V2 80/0,V3 144/0. Corresponding
  V4a/V2/V3 ROM fixtures, new Low Kick fixture and inventory cleanly SKIP locally.
  Exact files: battle_scene_controller_test, battle_variable_power_v4a_test,
  battle_friendship_ivs_test, battle_variable_power_v4b_test,
  battle_wonder_guard_test, battle_variable_power_v2_test,
  battle_variable_power_v3_test, phase4_variable_power_v4a_effect_rom_test,
  phase4_variable_power_v2_effect_rom_test, phase4_variable_power_v3_effect_rom_test,
  phase4_low_kick_effect_rom_test, phase4_move_effect_inventory_test (all under
  tests/, with .lua suffix). Log `/tmp/firered-low-kick-focused-20261116.log`,
  SHA-256 `6372d8585ec4e2df599edc39d6cef64a4cccfa9c520505c2d4a9f87c1dc06879`.
- Read-only ephemeral `python3` parser joined pinned public source moves.h,
  battle_move_effects.h,battle.h,battle_moves.h against the literal inventory.
  Verified354 memberships/power classes,198 used effects and only singleton67
  default admission true→false, class B unchanged. In-memory Lua predicate
  probes checked source records against independent literal metadata in all
  four scopes: no weights299/55; absent friendship/IV296/58; injected weighted
  target300/54; weighted absent friendship/IV297/57. No expected value was
  constructed from predicate output. Source/report rows117/119/156 were
  byte-compared to944df72 and identical. No generated source table persisted.
  Aggregate log `/tmp/firered-low-kick-source-proof-20261116.log`, SHA-256
  `44b5776e4f8d09ec964152a24c49417be2cd0694575195efd74628382cd3d13a`.
- Final foreground `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY bash
  scripts/test_all.sh`: **PASS215 test files**, clean ROM skips, no replay.
  Log `/tmp/firered-low-kick-full-20261116.log`, SHA-256
  `fec13252ddf0483ac1d56223c1c14ae86d23c244edde99e23890f0e694f9e13b`.
- New targets staged before `lua5.1 scripts/check_repository.lua`: PASS344
  tracked Lua/432 Markdown/1385 local targets. `git diff --cached --check`
  and `git diff --check` passed. Rechecked after this task-only receipt; same
  counts/PASS. Repository log SHA-256
  `29d117d39e1615f07426eb3d4cfa10324ae6aa167d7e00db0e5c3eb04d7887b2`.

Product/test SHA-256 freeze:

| Path | SHA-256 |
| --- | --- |
| src/core/BattleEngine.lua | 09f76f4ca266fb346cc8bd74e1f2d313dde9eb2e56fb44b51cad50607369322a |
| src/core/BattleSceneController.lua | 5dbe993524dd0e9161935617a93947457749230000e880c5de17d59b4c164e1e |
| tests/battle_low_kick_test.lua | 2095a42a160507f6f79ab4d5ce36bcad62e7572f89275e527a004dec55e65bfa |
| tests/phase4_low_kick_effect_rom_test.lua | f87c77d96946c0fd97057b74af438cc8964895708ea6dbc204963858e88c1129 |
| tests/phase4_move_effect_inventory_test.lua | 26ed242428432bb300e522c0767c94c577472cf00e96f3cc0706652f03b47c67 |
| work/reports/phase4-move-effect-inventory.md | af6aa21b8912c44e57b0e11904805464caad7f4b48b309d703ce7da695cd16d4 |

Limits unchanged: injected engine slice only; numeric provider/address/delivery
UNKNOWN/unimplemented, native merge blocked, no represented flip or whole-family/
ROM/F4/AI/runtime/phase acceptance. Four-draw promise is ordinary itemless modeled
successful/noEffect Low Kick only, with documented inherited ability/item and
additional producer exclusions. Refusals preserve each engine-entry boundary;
prior chooser RNG/main switch writes/capture bag removal are not undone. A
source-unreachable Low Kick-in-Rollout-lock test makes only effective-record/
damage/RNG assertions; parent explicitly removed its extra unjustified PP
preservation assertion. Real V3 zeroPP and all required pure-planner witnesses
remain. No global PP/RNG repair, native/prototype/provider/ROM/replay/main action,
publication or remote/ref modification occurred.

One next action: parent rina freezes/receipts the exact clean local head and
routes it to the distinct Sol high implementation Reviewer against this contract.
Parent alone reconciles canonical state after freeze; review is still required.


## F1 correction receipt — 2026-11-17

Parent correction dispatchf99397f and independent NEEDS_FIX review
SHA-256 `145d6be17bde215204a0f179d98490680af775316c6f9ff67bb38ccad5b87199`
are adopted for this same eight-path package. Sole F1: pinned script2550–2556
orders attackcanceler, attackstring, PP reduction, weight calculation, accuracy.
Worker `/root/low_kick_engine_worker` preserved all other approved semantics and
all original400 assertions. Prior445f3c4 receipt above remains historical.

Corrected product/test freeze `9fae63734f981320a65081e0a7c1090352a5459e`;
its final review descendant adds only this task receipt. Exact final clean head
is returned to parent rina for the same distinct Reviewer's delta verification.
READY_FOR_REVIEWER is a handoff, not Worker approval or native acceptance.

Only Low Kick now reduces PP in its post-canceller/noPP-check prefix, after
useMove and before its action-local weight calculation and accuracy. Its late
generic deduction is skipped. Existing non-Low-Kick PP, immutable planner,
refusal, ordinary/WG tail and source-unreachable lock limits are preserved.
The injected map/domain/API and approved source/design report are unchanged.
Both-side read-only RNG observers assert literal PP19 at each of four successful
draws and PP19 at the sole lowered-accuracy miss draw; each spends exactly one
PP. Existing protect/Fly/Dig/status/refusal oracles remain unchanged.

Verification and recovery:

- Before the fix, the added observers reproduced four failures (both sides,
  hit/miss);412 assertions passed. Log
  `/tmp/firered-low-kick-f1-before-20261117.log`, SHA-256
  `718a9676d3e018e0dcd3047497ac42810e78719b55639e2aa3f33e7f18e13715`.
- `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY lua5.1
  tests/battle_low_kick_test.lua`: **416 passed,0 failed**.
  Required same focused file loop listed in the Nov16 receipt reran with
  controller144/0,V4a243/0,H1 87/0,V4b93/0,WG768/0,V2 80/0,V3 144/0;
  associated ROM fixtures/inventory cleanly SKIP. The independent read-only
  `pp_order.lua` from the review scratch directory was then run with the same
  unset ROM/replay environment: both sides observe literal19,19,19,19 and exit0.
  Combined log `/tmp/firered-low-kick-f1-focused-20261117.log`, SHA-256
  `e14b54315eb45c6f1d6d7e7cc8c8dbe433cb26b816fce0d7af20fd8e404c392b`.
- Final foreground `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY bash
  scripts/test_all.sh`: **PASS215 test files**, clean ROM skips/no replay.
  Log `/tmp/firered-low-kick-f1-full-20261117.log`, SHA-256
  `24be9379ef674c8a999d44174d985d4f60a8e3afa8af0d2d276bfd72539899e1`.
- `lua5.1 scripts/check_repository.lua` PASS344Lua/432Markdown/1385targets;
  `git diff --cached --check` and `git diff --check` PASS. Final task-only
  descendant rechecked. Canonical read-only authority check
  `python3 scripts/check_handoff_state.py --revision f99397f --task
  work/tasks/phase4-low-kick.md` PASS; no state written. Parent reconciles the
  new exact frozen target and performs the review-stage handoff check.
- Recovered rather than repeated: accepted baseline213/product identity,
  prior215 log `fec13252…99e13b`, source354/four scopes/receipt-byte proof
  `44b5776e…cd3d13a` and independent372 scenarios/996 non-Low-Kick transitions
  plus28 Low Kick source cases, as recorded by review145d6be1. Unchanged
  inventory files/source partition and source pin c75f352 were rechecked;
  no fresh broad source/differential campaign was needed.

Corrected SHA-256: BattleEngine
`e4958bef6e3ed43fee7ce5e1e6b394b0b59ceb6fdbf15f45a7efd885fbef2876`;
battle_low_kick_test
`94f6b4d3edc71d8bd692a2178919ba5838c3e3da739b561e7bc88416a29a1f45`.
Other four product/test/report hashes in the Nov16 receipt remain identical.
The full package remains exactly the authorized eight paths from274cbad;
this correction changes only Engine/new focused test/own task/append-only
friction relative to445f3c4. The source/design report remains exactly
`be0df3a0044ba1d2ada00bf1dd90882f3d2c33f15573f46a66844e5bb622e682`.

Limits: numeric retail provider/address/delivery remains UNKNOWN/unimplemented,
native merge blocked; no represented/family/ROM/F4/AI/runtime/phase/CI/publication/
main gate accepted. No generic PP repair, other effect change, original ref,
ROM/private job/replay/remote/publication/main action. Prior chooser RNG/main
switch writes/capture removal remain outside engine-entry rollback promises.
Next action: parent receipts the exact clean correction head and sends it to
the same distinct Reviewer for F1-only delta verification.

## Parent local acceptance — 2026-11-17

Corrected codeaa18ab1 independentlyPASS [correction review](../reviews/2026-11-17-low-kick-implementation-correction-review.md) SHAaba441c200b9ecfc99c21b9aa96feee02e0d263576d2998e0b6f449b9b49f821. F1sourcePPorder fixed;416focused/215noROM,428independentLowKicksourceassertions, prior996nonLKtransitionproof preserved. Native/provider/ROM/AI/phase/main gates remain. Candidate staysisolated; parentimportsreceiptsonly, notwholeEngineintoownnative/private stack. No publication bythisreceipt.


## Parent draft-publication preparation — 2026-11-17

Outcome: prepare a reviewable DRAFT PR candidate for the independently accepted
injected engine slice. This is the same P4-LOW-KICK family task, not new product
implementation. Parent rina owns reconciliation and any later publication.
Standing AGENTS publication authority permits a bounded draft after exact-head
verification; this stage alone allows local preparation only. Native merge,
provider/address/delivery, non-skipped ROM, AI, full-family and phase gates stay open.

Worker: Terra medium for mechanical documentation and source-identity proof;
independent existing implementation Reviewer verifies the documentation-only
candidate before publication. Input clean frozen
`aa18ab1c4b5decd3db2195465b4c3cbfdcfea2c9`, accepted correction review
`aba441c200b9ecfc99c21b9aa96feee02e0d263576d2998e0b6f449b9b49f821`.
New worktree `/home/home/FireRedRecomp-low-kick-draft`, branch
`work/review-ready-low-kick-20261117`. Preserve frozen implementation/design
and organizer trees. Never copy organizer runtime, native/private/denied recoil
code. Base publication branch is `work/review-ready-wonder-guard-20261101`
at `944df72c9742fbf3b192d3908f1627b6004aabf3`; do not target main.

This preparation MAY CHANGE only this task and add byte-exact copies of
`work/reviews/2026-11-16-low-kick-implementation-review.md` and
`work/reviews/2026-11-17-low-kick-implementation-correction-review.md` from the
canonical organizer receipts. Source/testing/design/inventory/friction bytes
must remain exactly frozen aa18ab1. Append failures only to scratch
`/tmp/firered-low-kick-draft-FRICTION_LOG.md`; parent promotes them if needed.

Prove full product/tests/scripts/import/main identity to aa18ab1; approved
design hash be0df3a0 unchanged; exact delta from WG944 is the original nine
paths plus the two review receipts, no extras. Freeze clean local commit,
record exact paths/digests and repo/whitespace checks. Recover 416 focused,
215 no-ROM and independent 428/996 evidence; do not repeat unchanged product
suites for documentation-only ancestry. Draft body scratch
`/tmp/firered-low-kick-draft-body-20261117.md` must explain injected optional
input/refusal, PP/source correction, tests, class B unchanged and numeric
provider/native/ROM/AI/merge limits. Stop on source drift, unexpected path,
missing receipt or contradictory scope; no code correction, remote/ref/PR
mutation, ROM/search/private log/job/replay/main action. Parent verifies fresh
remote base/no duplicate/new ref and final head before any separate push.
Deliver READY_FOR_REVIEWER with exact frozen head and one next action.


## Draft preparation Worker receipt — 2026-11-17

The clean candidate is a documentation-only descendant of accepted correction
`aa18ab1c4b5decd3db2195465b4c3cbfdcfea2c9`; its exact head is supplied by the
commit containing this receipt. `git diff --name-only aa18ab1 -- src tests
scripts import main.lua` and the same check for the design, inventory and
friction paths returned empty. Approved design SHA-256 remains
`be0df3a0044ba1d2ada00bf1dd90882f3d2c33f15573f46a66844e5bb622e682`.
The original and correction implementation reviews are exact organizer copies,
SHA-256 `145d6be17bde215204a0f179d98490680af775316c6f9ff67bb38ccad5b87199`
and `aba441c200b9ecfc99c21b9aa96feee02e0d263576d2998e0b6f449b9b49f821`.

Recovered unchanged evidence: 416 focused assertions passed, 215 no-ROM test
files passed, independent 428 Low Kick source assertions and 996 non-Low-Kick
transitions. Product suites were not repeated for this documentation-only
change. After staging, repository and whitespace checks passed. The candidate
delta from `944df72c9742fbf3b192d3908f1627b6004aabf3` is the original nine
paths listed by `git diff --name-only 944df72` plus these two review receipts.
Numeric provider, native merge, ROM, AI, whole-family and phase gates remain
open; class B remains unchanged. Next action: the distinct existing code
Reviewer independently verifies this exact documentation-only candidate.
