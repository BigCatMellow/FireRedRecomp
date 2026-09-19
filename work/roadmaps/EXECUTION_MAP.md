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
Frozen FireRed balance package [CURRENT HUMAN-PRIORITIZED DISPATCH]
        ↓
category + learnset foundation: ACTIVE
        ↓ independent PASS
frozen-package mod: REVIEWED PASS
        ↓
separate deterministic/representative validation: REVIEWED PASS
        ↓
resume Phase 3 bridge/replay chain

Phase 1 importer/model [DONE]
        ↓
Phase 2 renderer/runtime [IN PROGRESS]
        ↓
Phase 3 playable vertical slice [DONE]
        │
        ├─ Route 1 battle/capture/save/reload: substantial evidence exists
        ├─ canonical Viridian Parcel/Dex/capture progression: evidenced
        ├─ visible north Oak Parcel/Dex presentation: REVIEWED PASS
        ├─ title/new-game → Oak/identity → bedroom runtime entry: REVIEWED PASS
        └─ continuous runtime proof: REVIEWED PASS
                          ↓ independent PASS
          complete continuous boot→battle→save→reload runtime artifact: REVIEWED PASS
                          ↓
                    Phase 3 exit proof: CLOSED
                          ↓
Phase 2 camera/Oak-intro visual parity: NEXT GATE (task shaping)
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
| Phase 2 — camera + Oak/reference parity | `IN PROGRESS` | [`../tasks/phase2-camera-oak-reference-parity-spec.md`](../tasks/phase2-camera-oak-reference-parity-spec.md) | deterministic three-case reference/camera comparison harness, then measured parity corrections | Phase 2 closure |
| Phase 3A — deterministic vertical-slice proof | `DONE` | [`../tasks/phase3-exit-proof.md`](../tasks/phase3-exit-proof.md) | independently reviewed `333d048` complete runtime artifact, with 144-file no-ROM/ROM suites | Phase 2 camera/Oak parity gate |
| Phase 3B — canonical Viridian Parcel/Dex progression | evidenced | [`../tasks/viridian-parcel-dex-progression.md`](../tasks/viridian-parcel-dex-progression.md) | already evidenced; do not redo | supports Phase 3A |
| Phase 3C — north-facing Oak Parcel/Dex scene | `REVIEWED PASS` | [`../tasks/oak-parcel-dex-presentation-north.md`](../tasks/oak-parcel-dex-presentation-north.md) | PASS at `2d8c3221775044a54668683e500055307fe4d20b` | supports Phase 3A |
| Phase 3D — title/new-game through Oak/identity into bedroom | `REVIEWED PASS` | [`../tasks/phase3-title-oak-entry-proof.md`](../tasks/phase3-title-oak-entry-proof.md) | PASS at `8bdbda903fb0574cb169968976d4b40ce96d3563` | supports Phase 3A |
| Phase 3D-pre — Local Worker Bridge retargeting | `REVIEWED PASS` | [`../tasks/local-worker-bridge-task-routing.md`](../tasks/local-worker-bridge-task-routing.md) | PASS at `0f0dc2f028f204dce4fcaee4e0fff0d9d0afb61e`; do not redo | completed prerequisite |
| Frozen package — mod foundations | `REVIEWED PASS` | [`../tasks/pokemon-firered-balance-foundation.md`](../tasks/pokemon-firered-balance-foundation.md) | independently passed at `25e3d88e` | package application |
| Frozen package — mod application | `REVIEWED PASS` | [`../tasks/pokemon-firered-balance-package-application.md`](../tasks/pokemon-firered-balance-package-application.md) | independently passed at `bb0476ce` | representative validation |
| Frozen package — representative validation | `REVIEWED PASS` | [`../tasks/pokemon-firered-balance-representative-validation.md`](../tasks/pokemon-firered-balance-representative-validation.md) | PASS at `6db8d9c0`; see durable implementation evidence | resume Phase 3 bridge route |
| Phase 3E-pre — explicit bridge route | `REVIEWED PASS` | [`../tasks/local-worker-bridge-complete-runtime-route.md`](../tasks/local-worker-bridge-complete-runtime-route.md) | published parser-disambiguation review PASS | complete runtime replay |
| Phase 3E — complete end-to-end runtime exit replay | `REVIEWED PASS` | [`../tasks/phase3-complete-runtime-exit-replay.md`](../tasks/phase3-complete-runtime-exit-replay.md) | `333d048` artifact and independent PASS at `000f9847` | Phase 3 exit proof closed |
| Phase 4 — full Gen 3 battle engine | `IN PROGRESS` | future | general trainer battles, switching, move/effect and stress matrices | reliable trainer/story progression |
| Phase 5 — overworld/field systems | `IN PROGRESS` | future | Pallet→Elite Four traversal without invalid paths | credits traversal |
| Phase 6 — menus/inventory/progression UI | `IN PROGRESS` | future | complete player UI, no dev-key fallbacks | normal completion |
| Phase 7 — story/scripts/cutscenes | `IN PROGRESS` | future | new game→credits without manual edits/skips | credits story parity |
| Phase 8 — audio/presentation | `IN PROGRESS` | future | no major missing AV system in reference playthrough | presentation closure |
| Phase 9 — postgame/secondary | `NOT STARTED` | future | offline single-player content complete | complete offline surface |
| Phase 10 — mod/release engineering | `NOT STARTED` | future | import/play/mod/update/diagnose without manual filesystem work | public extensible release |

## Current bounded chain

### Closed parent gate: Phase 3 exit proof

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

All known functional seams on that path have deterministic evidence. The final
continuous runtime replay at `333d048` received independent `PASS` at
`000f9847`, so this parent and canonical Phase 3 status are closed. Do not
reopen it absent regression evidence.

### Closed leaf: title/Oak entry

[`../tasks/phase3-title-oak-entry-proof.md`](../tasks/phase3-title-oak-entry-proof.md) is `CLOSED — REVIEWED PASS` at exact implementation revision `8bdbda903fb0574cb169968976d4b40ce96d3563`.

Reviewer verified normal title `A`/`START` → existing Oak scene → existing identity flow → fresh Player's House 2F without post-Oak fixture injection, with focused, full no-ROM, full verified-ROM, Phase 3 ROM, and runtime replay evidence.

Do not redo this leaf unless direct evidence shows regression.

### Closed leaf: complete runtime exit replay

[`../tasks/phase3-complete-runtime-exit-replay.md`](../tasks/phase3-complete-runtime-exit-replay.md)
is `CLOSED — REVIEWED PASS`. Its independent review confirms normal boot through
title/Oak/identity, bedroom/Pallet, Route 1 wild defeat, normal save, and
fresh-process load, including persisted identity assertions and both 144-file
test-suite modes.

### Completed prerequisite: Local Worker Bridge retargeting

[`../tasks/local-worker-bridge-task-routing.md`](../tasks/local-worker-bridge-task-routing.md) is `CLOSED — REVIEWED PASS` at substantive revision `0f0dc2f028f204dce4fcaee4e0fff0d9d0afb61e`.

Do not redo this prerequisite unless new evidence shows regression.

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
