# FireRedRecomp Execution Map

- Record role: `MAP`
- Primary information class: `DERIVED EXECUTION INDEX`
- Status: `ACTIVE`
- Lifecycle: `ACTIVE`
- Authority: navigation/dispatch aid only; does not replace roadmap, capability checklist, active task contracts, source/ROM evidence, or independent review
- Accountable owner: Orchestrator
- Strategic roadmap: [`../../docs/roadmap.md`](../../docs/roadmap.md)
- Canonical capability status: [`CAPABILITY_CHECKLIST.md`](CAPABILITY_CHECKLIST.md)
- Detailed implementation checklist/history: [`../../docs/handoffs/firered-recomp-checklist.md`](../../docs/handoffs/firered-recomp-checklist.md)
- Current coordination state: [`../coordination/STATE.json`](../coordination/STATE.json)

## Purpose

Make the existing plan mechanically legible to fresh agents without creating a second roadmap.

This file answers:

> **Which proven gate are we trying to close, which bounded task currently advances it, what evidence closes that task, and what becomes eligible next?**

It is intentionally a routing layer. If this map disagrees with direct code/test/source evidence, the canonical capability checklist, or a newer active task/review contract, the newer/direct evidence wins and this map must be repaired.

## Dispatch rule

Orchestrator selects work using this order:

```text
strategic phase
→ earliest unmet canonical gate on the critical path
→ already-defined active bounded task, if one exists
→ its prerequisites and stop conditions
→ Worker implementation/evidence
→ independent Reviewer verdict
→ reconcile capability status
→ unlock the next bounded gate
```

Do not select work merely because a later phase is `IN PROGRESS`. Parallel implementation may exist, but the default autonomous dispatch follows the critical path and current checklist dispatch order.

## Current critical path

```text
Phase 1 importer/model [DONE]
        ↓
Phase 2 renderer/runtime [IN PROGRESS]
        ↓
Phase 3 playable vertical slice [IN PROGRESS]  ← CURRENT DISPATCH FOCUS
        │
        ├─ Route 1 battle/capture/save/reload: substantial evidence exists
        ├─ canonical Viridian Parcel/Dex/capture progression: evidenced
        ├─ visible north Oak Parcel/Dex presentation: REVIEWED PASS
        └─ title/new-game → Oak/identity → bedroom runtime entry: ACTIVE TASK
                 ↓
          reconcile full Phase 3 exit proof
                 ↓
Phase 2 camera/Oak-intro visual parity closure
                 ↓
Phase 4 battle generalization
                 ↓
Phase 5 complete overworld + Phase 7 story/scripts + Phase 6 menus
                 ↓
credits-path parity
                 ↓
Phase 8 presentation parity
                 ↓
Phase 9 postgame/offline secondary content
                 ↓
Phase 10 mod API + release engineering
```

The ordering above follows the current `CAPABILITY_CHECKLIST.md` dispatch policy. It does **not** imply that all later-phase implementation must wait; it defines what Orchestrator should preferentially close before widening autonomous work.

## Gate graph

| Phase / gate | Current state | Prerequisite / established evidence | Active or canonical task | Evidence required to unlock | Unlocks / next eligible work |
| --- | --- | --- | --- | --- | --- |
| Phase 0 — charter/reproducibility | `IN PROGRESS` | parity contract, behavior ledger, test script, CI workflow exist | no current dispatch | save-version contract + first CI verification; keep ledger current | stronger release/reproducibility baseline; does not supersede current Phase 3 dispatch |
| Phase 1 — ROM importer/canonical model | `DONE` | importer, schemas, data viewer, full-sweep validation | none | already met; do not redo | renderer/runtime, battle, script, map, save work can consume canonical data |
| Phase 2 — 240×160 camera + Oak/reference parity | `IN PROGRESS` | renderer, sprite/title/palette/viewport tests | deferred until Phase 3 exit path per dispatch order | true 240×160 camera parity + Oak-intro/reference screenshot assertions | closes Phase 2 presentation/runtime gate |
| Phase 3A — deterministic vertical-slice proof | `IN PROGRESS` | new game, movement, Route 1 battle, capture, save/load and replay evidence | [`../tasks/phase3-exit-proof.md`](../tasks/phase3-exit-proof.md) | complete boot → new game → Oak intro → bedroom → Pallet → Route 1 → wild battle → catch/defeat → save → reload with required persisted outcomes | Phase 3 exit eligibility |
| Phase 3B — canonical Viridian Parcel/Dex progression | bounded progression evidenced | visible Parcel progression, Lab/Dex transition, post-Dex shop, capture and persistence replay | [`../tasks/viridian-parcel-dex-progression.md`](../tasks/viridian-parcel-dex-progression.md) | evidence already exists for this supporting chain; do not redo | supports Phase 3A capture/progression evidence |
| Phase 3C — visible north-facing Oak Parcel/Dex scene | `REVIEWED PASS` | source-locked presenter, bounded runtime wiring, focused/no-ROM/verified-ROM suites and runtime replay | [`../tasks/oak-parcel-dex-presentation-north.md`](../tasks/oak-parcel-dex-presentation-north.md) | independently passed at revision `2d8c3221775044a54668683e500055307fe4d20b` | closes this leaf only; supports Phase 3A |
| Phase 3D — title/new-game through Oak/identity into bedroom | `ACTIVE` | title rendering, static Oak scene, naming flow, fresh-session bootstrap, downstream bedroom→Pallet replay already exist | **[`../tasks/phase3-title-oak-entry-proof.md`](../tasks/phase3-title-oak-entry-proof.md)** | deterministic normal-runtime proof from boot/title/new game through Oak/identity to Player's House 2F, required suites, independent review | re-evaluate full Phase 3A exit criterion |
| Phase 4 — full Gen 3 battle engine | `IN PROGRESS` | `BattleEngine`, trainer AI, capture, EXP, battle-scene tests | future task(s) after current dispatch gates | general trainer battles, switching, full move/effect matrix, deterministic stress tests | reliable story/trainer progression at scale |
| Phase 5 — complete overworld/field systems | `IN PROGRESS` | maps, warps, objects, movement, script tests | future bounded traversal/script tasks | scripted Pallet→Elite Four traversal with no missing/invalid path | credits-path world traversal |
| Phase 6 — menus/inventory/progression UI | `IN PROGRESS` | bag, party, Mart, PC, menu tests | future UI task graph | complete player-facing UI with no developer fallbacks | normal player completion without dev controls |
| Phase 7 — story/scripts/cutscenes | `IN PROGRESS` | early-story/script support | future checkpoint/script-command task graph | clean new game → credits with no manual state edits/skips | credits-path story parity |
| Phase 8 — audio/presentation parity | `IN PROGRESS` | song/audio/title/graphics tests | after core credits path is reliable | reference playthrough with no major missing AV system | polished faithful base-game presentation |
| Phase 9 — postgame/secondary modes | `NOT STARTED` | requires stable base credits path | future | all offline FireRed single-player content completable normally | complete offline content surface |
| Phase 10 — mod API/release engineering | `NOT STARTED` | architecture keeps modding cheap, but API intentionally deferred | future | import/play/mod/update/diagnose/save-preservation flow without manual filesystem work | public extensible release |

## Current bounded chain in detail

### Parent gate: Phase 3 exit proof

Canonical parent: [`../tasks/phase3-exit-proof.md`](../tasks/phase3-exit-proof.md)

Required observable path:

```text
boot
→ new game
→ Oak intro
→ bedroom
→ Pallet Town
→ Route 1
→ wild battle
→ catch or defeat
→ save
→ fresh-process reload
```

The parent task remains open. Downstream battle/capture/save evidence and the canonical Viridian Parcel/Dex chain are now substantial enough that the smallest remaining explicit entry gap is the normal runtime transition from title/new-game through Oak/identity into the bedroom.

### Completed supporting leaf: north-facing Oak Parcel/Dex presentation

Canonical task: [`../tasks/oak-parcel-dex-presentation-north.md`](../tasks/oak-parcel-dex-presentation-north.md)

Independent review returned `PASS` for implementation revision
`2d8c3221775044a54668683e500055307fe4d20b` after focused, no-ROM,
verified-ROM, Phase 3 ROM test, and runtime replay evidence. This closes only
that leaf; it does not close Phase 3.

### Active leaf: title/new-game through Oak/identity into bedroom

Canonical task: [`../tasks/phase3-title-oak-entry-proof.md`](../tasks/phase3-title-oak-entry-proof.md)

**Current Worker package:** characterize the live normal boot/title/new-game
path first. Prefer an evidence-only deterministic replay if current runtime
already connects the existing title, Oak/new-game identity, fresh-session, and
bedroom pieces. Make a gameplay change only if the replay exposes a concrete
bounded integration defect inside the task contract.

Do not expand into Phase 2 Oak visual-animation parity, a general scene stack,
generic script work, Phase 4 battle work, or save-layout expansion.

**Reviewer gate:** exact evidence/implementation revision must receive
independent `PASS` before Orchestrator treats this leaf as closed.

**After PASS:** Orchestrator must re-read the full Phase 3 parent proof and
canonical checklist. If every parent acceptance item is genuinely evidenced,
Phase 3 becomes eligible for canonical status reconciliation; otherwise choose
the smallest remaining unproven item.

## How Orchestrator chooses the next task

After every Reviewer `PASS`:

1. Mark only the reviewed bounded task as satisfied where evidence supports it.
2. Re-evaluate its parent gate.
3. If parent acceptance is not fully met, select the smallest unmet acceptance item.
4. Reuse an existing task contract when one already covers that item.
5. If no suitable task exists, create one bounded task containing:
   - goal;
   - source of truth;
   - prerequisites;
   - MAY CHANGE / MUST NOT CHANGE;
   - acceptance criteria;
   - deterministic evidence plan;
   - stop/escalation conditions;
   - explicit completion/handoff.
6. Dispatch exactly one default critical-path package to Worker.
7. Parallelize only when packages have independent acceptance/evidence surfaces and cannot invalidate each other's source-of-truth state.

## Status transition rules

```text
Task code exists                  ≠ task PASS
Task tests pass                   ≠ independent PASS
Independent task PASS             ≠ parent gate complete
Parent gate complete              ≠ phase DONE
Phase exit criterion + evidence
+ independent review              = eligible for canonical status advance
```

Only `work/roadmaps/CAPABILITY_CHECKLIST.md` owns project-wide capability status.

## Evidence hierarchy

Prefer, in order:

1. verified ROM/source-locked deterministic evidence where retail behavior matters;
2. focused deterministic unit/FSM tests;
3. full no-ROM regression suite;
4. verified-ROM full suite/runtime replay when required;
5. bounded manual observation only when automation cannot yet prove the behavior and the task explicitly permits it.

Never convert `UNKNOWN` into `PASS` because a fresh agent believes the intended behavior is obvious.

## Parallel-work policy

The strategic roadmap identifies workstreams that can technically proceed in parallel after Phase 1. Autonomous dispatch should be more conservative:

- default: one critical-path Worker package at a time;
- allow parallel work only after Orchestrator records non-overlapping change boundaries and independent evidence gates;
- do not parallelize two tasks that both modify central runtime wiring such as `main.lua` unless their integration order is explicit;
- never let parallel work advance canonical phase status independently.

This keeps the system hands-off without creating merge/review ambiguity.

## Maintenance trigger

Update this map when any of the following occurs:

- a canonical capability changes status;
- a current critical-path task receives independent PASS/BLOCK;
- Orchestrator changes the active parent gate;
- a new prerequisite is discovered;
- direct source/ROM evidence invalidates a dependency assumption.

Do **not** update it merely for every implementation commit. The task contract and coordination state own fine-grained execution state.
