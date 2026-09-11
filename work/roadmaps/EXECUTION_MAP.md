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
Phase 2 renderer/runtime [IN PROGRESS]
        ↓
Phase 3 playable vertical slice [IN PROGRESS]  ← CURRENT DISPATCH FOCUS
        │
        ├─ Route 1 battle/capture/save/reload: substantial evidence exists
        ├─ canonical Viridian Parcel/Dex/capture progression: evidenced
        ├─ visible north Oak Parcel/Dex presentation: REVIEWED PASS
        └─ title/new-game → Oak/identity → bedroom runtime entry: CHARACTERIZED
                 │
                 └─ temporary prerequisite: Local Worker Bridge retargeting [ACTIVE]
                          ↓ independent PASS
                    resume title/Oak entry task
                          ↓ independent PASS
                    reconcile full Phase 3 exit proof
                          ↓
Phase 2 camera/Oak-intro visual parity closure
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
| Phase 2 — camera + Oak/reference parity | `IN PROGRESS` | deferred by current dispatch order | true 240×160 camera parity + Oak/reference assertions | Phase 2 closure |
| Phase 3A — deterministic vertical-slice proof | `IN PROGRESS` | [`../tasks/phase3-exit-proof.md`](../tasks/phase3-exit-proof.md) | boot → new game → Oak intro → bedroom → Pallet → Route 1 → wild battle → catch/defeat → save → reload | Phase 3 exit eligibility |
| Phase 3B — canonical Viridian Parcel/Dex progression | evidenced | [`../tasks/viridian-parcel-dex-progression.md`](../tasks/viridian-parcel-dex-progression.md) | already evidenced; do not redo | supports Phase 3A |
| Phase 3C — north-facing Oak Parcel/Dex scene | `REVIEWED PASS` | [`../tasks/oak-parcel-dex-presentation-north.md`](../tasks/oak-parcel-dex-presentation-north.md) | PASS at `2d8c3221775044a54668683e500055307fe4d20b` | supports Phase 3A |
| Phase 3D — title/new-game through Oak/identity into bedroom | `BLOCKED ON EXECUTION SUBSTRATE` | [`../tasks/phase3-title-oak-entry-proof.md`](../tasks/phase3-title-oak-entry-proof.md) | normal runtime proof, required suites, independent review | re-evaluate Phase 3A |
| Phase 3D-pre — Local Worker Bridge retargeting | `ACTIVE` | **[`../tasks/local-worker-bridge-task-routing.md`](../tasks/local-worker-bridge-task-routing.md)** | explicit fail-closed title/Oak route support, preserved runner/ROM security invariants, deterministic validation, independent review | return same Phase 3D task to Worker |
| Phase 4 — full Gen 3 battle engine | `IN PROGRESS` | future | general trainer battles, switching, move/effect and stress matrices | reliable trainer/story progression |
| Phase 5 — overworld/field systems | `IN PROGRESS` | future | Pallet→Elite Four traversal without invalid paths | credits traversal |
| Phase 6 — menus/inventory/progression UI | `IN PROGRESS` | future | complete player UI, no dev-key fallbacks | normal completion |
| Phase 7 — story/scripts/cutscenes | `IN PROGRESS` | future | new game→credits without manual edits/skips | credits story parity |
| Phase 8 — audio/presentation | `IN PROGRESS` | future | no major missing AV system in reference playthrough | presentation closure |
| Phase 9 — postgame/secondary | `NOT STARTED` | future | offline single-player content complete | complete offline surface |
| Phase 10 — mod/release engineering | `NOT STARTED` | future | import/play/mod/update/diagnose without manual filesystem work | public extensible release |

## Current bounded chain

### Parent gate: Phase 3 exit proof

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

The parent remains open. Downstream battle/capture/save evidence and the Viridian Parcel/Dex chain are substantial. The smallest remaining explicit entry gap is the normal runtime transition from title/new-game through Oak/identity into the bedroom.

### Characterized gameplay leaf: title/Oak entry

Worker characterization found:

- title view exists;
- Oak intro view exists;
- Oak intro `A` input already transitions into `beginNewGameFlow()`;
- the title view has no normal runtime input transition into Oak intro;
- the existing replay starts after that missing seam and therefore cannot prove normal title-to-Oak reachability.

The smallest gameplay correction is a narrow title-to-Oak runtime seam plus deterministic entry replay/assertion evidence. No gameplay change was published during characterization.

### Active temporary prerequisite: Local Worker Bridge retargeting

The verified self-hosted bridge is still hard-coded to the completed Oak Parcel/Dex task's allowlist, focused test, replay, and publish staging. That prevents the already-authorized title/Oak patch from using the safe large-file execution substrate.

Active task: [`../tasks/local-worker-bridge-task-routing.md`](../tasks/local-worker-bridge-task-routing.md)

This infrastructure package may change the bridge workflow/procedure only. It must preserve:

- trusted pushes to `main` only;
- no `pull_request` / `pull_request_target` self-hosted execution;
- explicit task-bounded target validation;
- exact FireRed v1.0 ROM SHA-1 verification;
- required tests before publish;
- no ROM/cache/assets in GitHub;
- fail-closed behavior for unknown task routes.

After independent PASS, Orchestrator must reactivate the same `phase3-title-oak-entry-proof.md` task. This infrastructure leaf does not close any gameplay or capability gate.

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
