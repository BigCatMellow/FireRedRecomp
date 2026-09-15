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

This file is a derived routing index. It answers which proven gate is being closed, which bounded task advances it, what evidence closes that task, and what becomes eligible next. If it conflicts with direct code/test/source evidence, the capability checklist, or a newer task/review contract, the newer/direct evidence wins.

## Dispatch rule

```text
strategic phase
→ earliest unmet canonical gate
→ bounded task
→ prerequisites / blockers
→ Worker evidence
→ independent Reviewer verdict
→ Orchestrator reconciliation
→ next bounded gate
```

Default to one critical-path Worker package at a time.

## Current critical path

```text
Phase 1 importer/model [DONE]
        ↓
Phase 3 playable vertical slice [DONE]
        ↓
Phase 2 renderer/runtime [IN PROGRESS]  ← CURRENT DISPATCH FOCUS
        │
        ├─ outer window scaling: evidenced
        ├─ imported map/title/Oak rendering foundations: substantial evidence exists
        ├─ true 240×160 overworld camera viewport: REVIEWED PASS (`4c5456f3`)
        └─ Oak/reference screenshot discrepancy gate: remains after camera viewport PASS
                          ↓
Phase 4 battle generalization
        ↓
Phase 5/7/6 completion toward credits
        ↓
Phase 8 presentation parity
        ↓
Phase 9 postgame
        ↓
Phase 10 mod/release engineering
```

## Gate graph

| Phase / gate | Current state | Active or canonical task | Evidence required to unlock | Next |
| --- | --- | --- | --- | --- |
| Phase 0 — charter/reproducibility | `IN PROGRESS` | no current dispatch | save-version contract + first CI verification | stronger release baseline |
| Phase 1 — ROM importer/canonical model | `DONE` | none | already met | downstream systems consume canonical data |
| Phase 2A-pre — Local Worker Bridge route for camera proof | `REVIEWED PASS` | [`../tasks/local-worker-bridge-phase2-camera-route.md`](../tasks/local-worker-bridge-phase2-camera-route.md) | PASS at `27867add`; trusted probe `34735602055` | Phase 2A Worker eligibility |
| Phase 2A-fix — camera bridge corrections | `REVIEWED PASS` | bridge correction tasks | exact test-route and optional-staging fixes independently passed | camera publication enabled |
| Phase 2A — true 240×160 overworld camera viewport | `REVIEWED PASS` | [`../tasks/phase2-gba-camera-viewport-proof.md`](../tasks/phase2-gba-camera-viewport-proof.md) | PASS at `4c5456f3`; guarded run `34753297372` passed validation, focused/full suites, replay, and publication | scope Phase 2B Oak/reference evidence |
| Phase 2B-pre — Local Worker Bridge route for Oak/reference evidence | `REVIEWED PASS` | [`../tasks/local-worker-bridge-phase2-oak-reference-evidence-route.md`](../tasks/local-worker-bridge-phase2-oak-reference-evidence-route.md) | PASS at `ff5ff890`; trusted probe `34753855210` | Phase 2B harness eligibility |
| Phase 2B — Oak/reference visual-evidence harness | `REVIEWED PASS` | [`../tasks/phase2-oak-reference-evidence-harness.md`](../tasks/phase2-oak-reference-evidence-harness.md) | PASS at `0017727c`; guarded run `34767029627` passed capture/publication | reference comparison task |
| Phase 2B — Oak/reference screenshot parity | `BLOCKED ON TRUSTED EXTERNAL REFERENCE` | **[`../tasks/phase2-oak-reference-comparison.md`](../tasks/phase2-oak-reference-comparison.md)** | user-owned retail captures + explicit discrepancy assertions; no copyrighted reference artifact in git | Phase 2 closure eligibility |
| Phase 3A — deterministic vertical-slice proof | `DONE` | [`../tasks/phase3-exit-proof.md`](../tasks/phase3-exit-proof.md) | continuous replay independently passed at `4f4f29ec` | Phase 3 complete |
| Phase 3C — north-facing Oak Parcel/Dex scene | `REVIEWED PASS` | [`../tasks/oak-parcel-dex-presentation-north.md`](../tasks/oak-parcel-dex-presentation-north.md) | PASS at `2d8c3221775044a54668683e500055307fe4d20b` | supports Phase 3A |
| Phase 3D — title/new-game through Oak/identity into bedroom | `REVIEWED PASS` | [`../tasks/phase3-title-oak-entry-proof.md`](../tasks/phase3-title-oak-entry-proof.md) | PASS at `8bdbda903fb0574cb169968976d4b40ce96d3563` | supports Phase 3A |
| Phase 3E — complete end-to-end runtime exit replay | `REVIEWED PASS` | [`../tasks/phase3-complete-runtime-exit-replay.md`](../tasks/phase3-complete-runtime-exit-replay.md) | PASS at `4f4f29ec` | Phase 3 complete |
| Phase 4 — full Gen 3 battle engine | `IN PROGRESS` | `BattleEngine`, trainer AI, capture, EXP, battle scene, and single-foe trainer path exist | general trainer battles, switching, move/effect and stress matrices | reliable trainer/story progression |
| Phase 4A-pre — bridge route for no-item trainer-party construction | `ACTIVE` | **[`../tasks/local-worker-bridge-phase4-trainer-party-no-item-route.md`](../tasks/local-worker-bridge-phase4-trainer-party-no-item-route.md)** | explicit route + probe + independent PASS | Phase 4A eligibility |
| Phase 4A — no-item trainer-party construction | `REVIEWED PASS` | [`../tasks/phase4-trainer-party-no-item-layouts.md`](../tasks/phase4-trainer-party-no-item-layouts.md) | PASS at `f40c4021`; guarded run `34776145784` | foe-only multi-mon orchestration |
| Phase 4B-pre — bridge route for foe-only multi-mon trainers | `REVIEWED PASS` | [`../tasks/local-worker-bridge-phase4-foe-only-multimon-route.md`](../tasks/local-worker-bridge-phase4-foe-only-multimon-route.md) | PASS at `2906627d`; trusted probe `34776399652` | Phase 4B eligibility |
| Phase 4B — foe-only multi-mon trainer orchestration | `REVIEWED PASS` | [`../tasks/phase4-foe-only-multimon-trainer-orchestration.md`](../tasks/phase4-foe-only-multimon-trainer-orchestration.md) | PASS at `8533cf6a`; guarded run `34777072801` | player replacement UI discovery |
| Phase 4C-pre — bridge route for player forced replacement | `REVIEWED PASS` | [`../tasks/local-worker-bridge-phase4-player-forced-replacement-route.md`](../tasks/local-worker-bridge-phase4-player-forced-replacement-route.md) | PASS at `02bc5bda`; trusted probe `34782885447` | Phase 4C eligibility |
| Phase 4C — player forced replacement UI | `REVIEWED PASS` | [`../tasks/phase4-player-forced-replacement-ui.md`](../tasks/phase4-player-forced-replacement-ui.md) | PASS at `8fd9a397`; guarded run `34783304717` | broader player switching |
| Phase 4D-pre — bridge route for voluntary player switch | `REVIEWED PASS` | [`../tasks/local-worker-bridge-phase4-player-voluntary-switch-route.md`](../tasks/local-worker-bridge-phase4-player-voluntary-switch-route.md) | PASS at `b6987ab`; trusted probe `34783807316` | Phase 4D eligibility |
| Phase 4D — trainer-only voluntary player switching | `REVIEWED PASS` | [`../tasks/phase4-player-voluntary-switch.md`](../tasks/phase4-player-voluntary-switch.md) | PASS at `3140e267`; guarded run `34797894161` | trainer held-item/effect matrix |
| Phase 4E-pre — bridge route for fixed-damage effects | `REVIEWED PASS` | [`../tasks/local-worker-bridge-phase4-fixed-damage-effects-route.md`](../tasks/local-worker-bridge-phase4-fixed-damage-effects-route.md) | PASS at `86fca12c`; trusted probe `34798514768` | Phase 4E eligibility |
| Phase 4E — fixed-damage effects | `REVIEWED PASS` | [`../tasks/phase4-fixed-damage-effects.md`](../tasks/phase4-fixed-damage-effects.md) | PASS at `c65cf838`; guarded run `34798961274` | admission-matrix discovery |
| Phase 4F — move admission-matrix discovery | `REVIEWED PASS` | [`../tasks/phase4-move-admission-matrix-discovery.md`](../tasks/phase4-move-admission-matrix-discovery.md) | 216 positive-power ROM records inventoried; 75 represented, one explicit reject, 140 broad-fallback records classified | effect-17 route only |
| Phase 4G-pre — bridge route for always-hit effects | `REVIEWED PASS` | [`../tasks/phase4-always-hit-effects.md`](../tasks/phase4-always-hit-effects.md) | PASS at `7571f61`; trusted probe run `34799768448` | Phase 4G eligibility |
| Phase 4G — always-hit effects | `REVIEWED PASS` | [`../tasks/phase4-always-hit-effects.md`](../tasks/phase4-always-hit-effects.md) | PASS at `89673e16`; guarded run `34828443860` | high-critical discovery |
| Phase 4H — high-critical effect discovery | `REVIEWED PASS` | [`../tasks/phase4-high-critical-effect-discovery.md`](../tasks/phase4-high-critical-effect-discovery.md) | PASS at `47f3748e`; eight records and stage-1 semantics source-locked | effect-43 route only |
| Phase 4I-pre — bridge route for high-critical effects | `REVIEWED PASS` | [`../tasks/phase4-high-critical-effects.md`](../tasks/phase4-high-critical-effects.md) | PASS at `19ca9eb9`; trusted probe `34829092960` | Phase 4I eligibility |
| Phase 4I — high-critical effects | `REVIEWED PASS` | [`../tasks/phase4-high-critical-effects.md`](../tasks/phase4-high-critical-effects.md) | PASS at `a4b02e35`; guarded run `34829358780` | False Swipe discovery |
| Phase 4J — False Swipe effect discovery | `REVIEWED PASS` | [`../tasks/phase4-false-swipe-effect-discovery.md`](../tasks/phase4-false-swipe-effect-discovery.md) | PASS at `f9874ecd`; #206 effect-101 HP-floor semantics source-locked | effect-101 route only |
| Phase 4K-pre — bridge route for False Swipe | `REVIEWED PASS` | [`../tasks/phase4-false-swipe-effects.md`](../tasks/phase4-false-swipe-effects.md) | PASS at `b5107709`; trusted probe `34830196033` | Phase 4K eligibility |
| Phase 4K — False Swipe effect | `REVIEWED PASS` | [`../tasks/phase4-false-swipe-effects.md`](../tasks/phase4-false-swipe-effects.md) | PASS at `a3e9d058`; guarded run `34830527499` | Vital Throw discovery |
| Phase 4L — Vital Throw effect discovery | `REVIEWED PASS` | [`../tasks/phase4-vital-throw-effect-discovery.md`](../tasks/phase4-vital-throw-effect-discovery.md) | PASS at `c872c16c`; effect-78 #233 ordinary-Hit/no-roll/priority semantics source-locked | effect-78 route only |
| Phase 4M-pre — bridge route for Vital Throw | `REVIEWED PASS` | [`../tasks/phase4-vital-throw-effects.md`](../tasks/phase4-vital-throw-effects.md) | PASS at `0af27341`; trusted probe `34902016950` | Phase 4M eligibility |
| Phase 4M — Vital Throw effect | `REVIEWED PASS` | [`../tasks/phase4-vital-throw-effects.md`](../tasks/phase4-vital-throw-effects.md) | PASS at `37f1f22e`; guarded run `34903062946` | Explosion discovery |
| Phase 4N — Explosion effect discovery | `REVIEWED PASS` | [`../tasks/phase4-explosion-effect-discovery.md`](../tasks/phase4-explosion-effect-discovery.md) | PASS at `61b2c60f`; effect-7 source semantics and ordering prerequisite locked | self-KO/faint-order design only |
| Phase 4O — Explosion self-KO/faint-order design | `REVIEWED PASS` | [`../tasks/phase4-explosion-self-ko-order-design.md`](../tasks/phase4-explosion-self-ko-order-design.md) | PASS at `ac15cba9`; effect-specific sequence and ordered-replacement prerequisite designed | ordered replacement-state design only |
| Phase 4P — ordered replacement-state design | `REVIEWED PASS` | [`../tasks/phase4-ordered-replacement-state-design.md`](../tasks/phase4-ordered-replacement-state-design.md) | PASS at `f407b775`; post-faint two-phase state contract identified | terminal outcome/policy discovery |
| Phase 4Q — terminal outcome/replacement-policy discovery | `REVIEWED PASS` | [`../tasks/phase4-terminal-outcome-replacement-policy-discovery.md`](../tasks/phase4-terminal-outcome-replacement-policy-discovery.md) | PASS at `e7f5d779`; source-locked `DREW`, local player→foe replacement ordering, and project API gap | two-sided state/API migration design |
| Phase 4R — two-sided replacement-state/API migration design | `REVIEWED PASS` | [`../tasks/phase4-two-sided-replacement-state-api-design.md`](../tasks/phase4-two-sided-replacement-state-api-design.md) | PASS at `6ac44924`; queue-compatible state contract, draw settlement, controller/persistence handoff, and test matrix | route plan |
| Phase 4S-pre — bridge route for two-sided replacement state | `REVIEWED PASS / PROBE PASS` | [`../tasks/local-worker-bridge-phase4-two-sided-replacement-state-api-route.md`](../tasks/local-worker-bridge-phase4-two-sided-replacement-state-api-route.md) | config PASS at `b6f63284`; probe `4630aad4`, guarded run `34906202097` | Phase 4S implementation |
| Phase 4S — two-sided replacement-state/API migration | `REVIEWED PASS` | [`../tasks/phase4-two-sided-replacement-state-api.md`](../tasks/phase4-two-sided-replacement-state-api.md) | PASS at `4a583b6a`; guarded run `34907113705` passed queue/state, draw settlement, focused/full/ROM/replay evidence | Explosion route plan |
| Phase 4T-pre — bridge route for Explosion | `REVIEWED PASS / PROBE PASS` | [`../tasks/local-worker-bridge-phase4-explosion-route.md`](../tasks/local-worker-bridge-phase4-explosion-route.md) | config PASS at `2355a194`; probe `8e5ed551`, guarded run `34952628535` | Phase 4T implementation |
| Phase 4T — Explosion effect | `REVIEWED PASS` | [`../tasks/phase4-explosion-effects.md`](../tasks/phase4-explosion-effects.md) | PASS at `507b5ac0`; guarded run `34953677822` and independent canonical-range review | select the next source-locked effect family separately |
| Phase 4U — Super Fang effect discovery | `REVIEWED PASS` | [`../tasks/phase4-super-fang-effect-discovery.md`](../tasks/phase4-super-fang-effect-discovery.md) | effect-40 current-HP-halving source lock independently passed | separate fail-closed route plan only |
| Phase 4V-pre — bridge route for Super Fang | `REVIEWED PASS / PROBE PASS` | [`../tasks/local-worker-bridge-phase4-super-fang-route.md`](../tasks/local-worker-bridge-phase4-super-fang-route.md) | config PASS `4b62344d`; probe `ce50565f`, guarded run `34954489129` | Phase 4V implementation |
| Phase 4V — Super Fang effect | `REVIEWED PASS` | [`../tasks/phase4-super-fang-effects.md`](../tasks/phase4-super-fang-effects.md) | PASS `2671c5de`; guarded run `34954873576` and independent canonical review | select next source-locked effect family separately |
| Phase 4W — Flail/Reversal effect discovery | `READY FOR INDEPENDENT REVIEW` | **[`../tasks/phase4-flail-effect-discovery.md`](../tasks/phase4-flail-effect-discovery.md)** | effect-99 dynamic-base-power source lock; no implementation authorized | independent discovery review |
| Phase 5 — overworld/field systems | `IN PROGRESS` | future | Pallet→Elite Four traversal without invalid paths | credits traversal |
| Phase 6 — menus/inventory/progression UI | `IN PROGRESS` | future | complete player UI, no dev-key fallbacks | normal completion |
| Phase 7 — story/scripts/cutscenes | `IN PROGRESS` | future | new game→credits without manual edits/skips | credits story parity |
| Phase 8 — audio/presentation | `IN PROGRESS` | future | no major missing AV system in reference playthrough | presentation closure |
| Phase 9 — postgame/secondary | `NOT STARTED` | future | offline single-player content complete | complete offline surface |
| Phase 10 — mod/release engineering | `NOT STARTED` | future | import/play/mod/update/diagnose without manual filesystem work | public extensible release |

## Current bounded chain

### Completed parent gate: Phase 3 exit proof

The normal boot → title/Oak/identity → bedroom/Pallet → Route 1 battle → save → fresh-process reload path has an independently reviewed continuous replay at `4f4f29ec`. `CAPABILITY_CHECKLIST.md` therefore owns Phase 3 as `DONE`. Do not redo Phase 3 absent direct regression evidence.

### Current parent gate: Phase 2 camera + Oak/reference parity

The roadmap requires a native 240×160 GBA presentation and representative screenshot comparison. The detailed checklist identifies the earliest still-open mechanical prerequisite as the true 240×160 camera-clipped overworld viewport. Phase 3 has now supplied the player position/movement that older Phase 2 notes said was required before this work became meaningful.

#### Scoped implementation leaf: true GBA camera viewport

[`../tasks/phase2-gba-camera-viewport-proof.md`](../tasks/phase2-gba-camera-viewport-proof.md) is the bounded implementation/evidence task. It may add/reuse focused camera geometry, integrate that transform into the normal overworld draw path, and prove live 240×160 clipping without changing gameplay.

It is Worker-eligible. The guarded Local Worker Bridge route received independent
PASS at `27867add` and its trusted route probe passed as run `34735602055`.

#### Completed prerequisite: guarded bridge route

[`../tasks/local-worker-bridge-phase2-camera-route.md`](../tasks/local-worker-bridge-phase2-camera-route.md)
is `CLOSED — REVIEWED PASS`. Worker must now execute only
[`../tasks/phase2-gba-camera-viewport-proof.md`](../tasks/phase2-gba-camera-viewport-proof.md).

### Remaining Phase 2 leaf after camera PASS

Oak-intro/reference screenshot parity remains open. Existing pixel-diff tooling is evidence infrastructure, not parity proof by itself. Orchestrator must scope that leaf only after the camera prerequisite is independently passed, using trustworthy reference behavior and without committing ROM-derived screenshots/assets.

## Status transition rules

```text
Task code exists                  ≠ task PASS
Task tests pass                   ≠ independent PASS
Independent task PASS             ≠ parent gate complete
Parent gate complete              ≠ phase DONE
Phase exit criterion + evidence
+ independent review              = eligible for canonical status advance
```

Only `CAPABILITY_CHECKLIST.md` owns project-wide capability status.

## Evidence hierarchy

Prefer:

1. verified ROM/source-locked deterministic evidence where retail behavior matters;
2. focused deterministic tests;
3. no-ROM regression suite;
4. verified-ROM full suite/runtime replay when required;
5. bounded manual observation only when explicitly permitted.

Never convert `UNKNOWN` into `PASS` by assumption.

## Maintenance trigger

Update this map when a canonical capability changes status, a current critical-path task receives independent PASS/BLOCK, the active parent gate changes, a new prerequisite is discovered, or direct source/ROM evidence invalidates a dependency assumption. Do not churn it for ordinary implementation commits.
