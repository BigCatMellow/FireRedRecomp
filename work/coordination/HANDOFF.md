# FireRedRecomp Coordination Handoff

- Record role: `HANDOFF`
- Primary information class: `TASK CONTEXT`
- Status: `READY_FOR_WORKER`
- Lifecycle: `ACTIVE`
- Authority: coordination state only; root `AGENTS.md` and active task contracts own authority
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Parent gameplay gate: [`../tasks/phase3-exit-proof.md`](../tasks/phase3-exit-proof.md)
- Closed reviewed leaf: [`../tasks/phase3-title-oak-entry-proof.md`](../tasks/phase3-title-oak-entry-proof.md)
- Active task: [`../tasks/phase3-complete-runtime-exit-replay.md`](../tasks/phase3-complete-runtime-exit-replay.md)
- Latest review: [`../reviews/2026-09-11-phase3-title-oak-entry-review.md`](../reviews/2026-09-11-phase3-title-oak-entry-review.md)
- Machine state: [`STATE.json`](STATE.json)

## Summary

Independent Reviewer returned **PASS** for the title/new-game → Oak/identity → fresh-bedroom leaf at exact implementation revision:

`8bdbda903fb0574cb169968976d4b40ce96d3563`

That closes the former functional entry gap. Normal title `A`/`START` now reaches the existing Oak scene, Oak continues into the existing identity flow, and the deterministic replay reaches a fresh Player's House 2F session without constructing a post-Oak fixture.

Phase 3 remains `IN PROGRESS`.

## Why Phase 3 is not marked DONE yet

The parent task `work/tasks/phase3-exit-proof.md` has a stricter acceptance shape than the individual leaf tasks. Its first criterion requires a ROM-backed automated test to drive the complete stated path when no remaining boundary is untestable.

The repository now has strong overlapping evidence for every known seam:

- title/Oak/identity → fresh bedroom: independently passed;
- bedroom → 1F → Pallet runtime movement/warps: evidenced;
- Route 1 encounter and wild battle win/loss: evidenced;
- capture path and persistent Dex/party state: evidenced;
- normal K-save → sandbox save file → fresh-process L-load: evidenced;
- Viridian Parcel/Dex/capture progression and visible Oak presentation: independently reviewed/evidenced.

But those proofs are split across multiple artifacts. With the former title/Oak boundary now closed, there is no longer an identified untestable seam that justifies leaving the parent proof fragmented.

Therefore the smallest remaining parent acceptance item is **one complete deterministic runtime replay**, not another gameplay feature.

## Active Worker package

Execute only:

[`../tasks/phase3-complete-runtime-exit-replay.md`](../tasks/phase3-complete-runtime-exit-replay.md)

Required observable run:

```text
normal boot
→ title / new game
→ Oak intro / identity
→ Player's House 2F
→ Pallet Town
→ Route 1
→ first wild battle
→ catch or defeat
→ normal save
→ fresh-process reload
```

Prefer the existing defeat + save/restart branch if it is the smallest way to make the path continuous. Reuse existing runtime input/event seams and deterministic RNG/input timing.

## Critical authority boundary

This is an **evidence-integration task**, not a gameplay implementation task.

Worker MAY change only the smallest replay/test support surface, including `main.lua` replay-driver plumbing if needed to connect already-existing runtime stages without changing normal gameplay behavior.

Worker MUST NOT change normal gameplay behavior merely to make the replay pass.

If continuous execution reveals a genuine gameplay defect, stop and return `BLOCKED` with the first exact failing seam. Do not fix that defect under this task; Orchestrator must scope it separately.

Also remain outside:

- Phase 2 camera/Oak visual parity;
- generic scene-stack/script architecture;
- Phase 4 trainer-battle/move-effect work;
- already-passed Mart/Parcel/Dex behavior;
- save format/layout expansion;
- supported-ROM policy;
- ROM/cache/BIOS/extracted content.

## Evidence required

Before routing to Reviewer, Worker must provide:

1. one unambiguous complete-runtime PASS artifact/marker;
2. continuity assertions covering identity, map/location progression, battle outcome state, and post-reload persistence;
3. an isolated temporary XDG/save sandbox for save/restart;
4. focused evidence PASS;
5. `bash scripts/test_all.sh` PASS;
6. verified-ROM `POKEPORT_ROM=/path/to/pokefirered.gba bash scripts/test_all.sh` PASS;
7. exact published revision and evidence references.

## Next role

`WORKER`

On successful evidence publication, set the relay to `READY_FOR_REVIEWER` for independent verification of the exact revision.

On Reviewer `PASS`, Orchestrator must re-evaluate the complete parent exit proof and only then decide whether `work/roadmaps/CAPABILITY_CHECKLIST.md` Phase 3 can advance from `IN PROGRESS` to `DONE`.

```text
Phase 3 title/Oak entry
→ REVIEWED PASS
→ parent still lacks one continuous complete-path artifact
→ ACTIVE NOW: phase3-complete-runtime-exit-replay
→ WORKER
→ REVIEWER
→ ORCHESTRATOR parent/canonical reconciliation
```

## Continuous-improvement check

No coordination-process change is justified. The current flow correctly prevented an independent leaf PASS from being silently promoted into parent/phase completion when the parent acceptance language is stricter.
