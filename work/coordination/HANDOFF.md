# FireRedRecomp Coordination Handoff

- Record role: `HANDOFF`
- Primary information class: `TASK CONTEXT`
- Status: `READY_FOR_WORKER`
- Lifecycle: `ACTIVE`
- Authority: coordination state only; root `AGENTS.md` and the active task own authority
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Parent gameplay gate: [`../tasks/phase3-exit-proof.md`](../tasks/phase3-exit-proof.md)
- Active gameplay task: [`../tasks/phase3-title-oak-entry-proof.md`](../tasks/phase3-title-oak-entry-proof.md)
- Closed infrastructure prerequisite: [`../tasks/local-worker-bridge-task-routing.md`](../tasks/local-worker-bridge-task-routing.md)
- Infrastructure review: [`../reviews/2026-09-11-local-worker-bridge-task-routing-review.md`](../reviews/2026-09-11-local-worker-bridge-task-routing-review.md)
- Machine state: [`STATE.json`](STATE.json)

## Summary

Independent Reviewer returned `PASS` on the bounded Local Worker Bridge routing package at substantive revision:

`0f0dc2f028f204dce4fcaee4e0fff0d9d0afb61e`

The bridge prerequisite is now closed. The bridge safely recognizes the `phase3-title-oak-entry-proof` route while preserving trusted-main execution, explicit fail-closed target routing, exact FireRed v1.0 ROM verification, test-before-publish ordering, and the prohibition on public-PR self-hosted execution.

No gameplay/runtime change was reviewed in that infrastructure package. Phase 3 remains `IN PROGRESS`; the canonical capability checklist is unchanged.

## Orchestrator reconciliation

The bounded bridge package is `CLOSED — REVIEWED PASS`.

The previously characterized gameplay task is therefore restored as the single active critical-path package:

[`../tasks/phase3-title-oak-entry-proof.md`](../tasks/phase3-title-oak-entry-proof.md)

Known runtime characterization remains:

```text
title view exists
Oak intro view exists
Oak intro A input -> existing beginNewGameFlow()

missing seam:
normal title/new-game input -> existing Oak intro
```

The Worker previously stopped before gameplay modification because the execution bridge could not safely route this task. That blocker is now removed.

## Active Worker package

Worker should execute only `work/tasks/phase3-title-oak-entry-proof.md`.

Required approach:

1. recover live code and confirm the characterized title/Oak boundary still holds;
2. if current runtime already closes it, add evidence only;
3. otherwise wire only the narrow normal title/new-game input → existing Oak intro seam;
4. add/complete deterministic title/Oak entry test and runtime replay evidence;
5. prove normal boot → title/new game → Oak/identity → fresh Player's House 2F without directly constructing a post-Oak session fixture;
6. verify player identity/gender/name, rival name, initial location/coordinates, and initial party/bag/money/Dex-relevant boundary state;
7. run the route-specific focused test, no-ROM suite, verified-ROM suite, and runtime replay through the Local Worker Bridge;
8. publish only task-authorized files after required tests pass;
9. record the exact revision/evidence and route it to independent Reviewer.

## Allowed surface

Expected bounded surface:

- `tests/phase3_title_oak_entry_test.lua`;
- `scripts/runtime_title_oak_entry_replay.sh`;
- `main.lua` only for the already-characterized narrow title-to-Oak seam;
- existing title/new-game/Oak/fresh-session modules only if direct evidence shows a bounded integration defect;
- `work/tasks/phase3-title-oak-entry-proof.md`;
- `work/tasks/phase3-exit-proof.md`;
- coordination/review documentation.

## Do not widen into

- Phase 2 Oak Nidoran/platform/fade/shrink visual parity;
- true camera/reference screenshot parity;
- generic scene-stack architecture;
- general script-interpreter expansion;
- Phase 4 trainer battles or move/effect work;
- already-passed Mart/Parcel/Dex presenter behavior;
- save-layout/sector expansion;
- supported-ROM policy changes;
- ROM, BIOS, cache, screenshot, or extracted-content publication.

If the task requires any of those, record `BLOCKED` rather than expanding scope.

## Bridge evidence — do not redo

The Local Worker Bridge route prerequisite has independent PASS and should not be reimplemented absent new regression evidence.

Reviewer confirmed:

- explicit hard-coded `phase3-title-oak-entry-proof` routing;
- target validation before `git apply`;
- no generic fallback for unknown routes or targets;
- trusted `push` to `main` only;
- no `pull_request` / `pull_request_target` self-hosted execution;
- exact FireRed US v1.0 SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc` gate;
- route-specific focused test/replay/staging;
- test-before-publish ordering;
- successful non-gameplay probe run `34598648805` on `firered-mint`;
- repository Lua tests run `34598648798` passed on the same probe commit.

## Next role

`WORKER`

Execute only `work/tasks/phase3-title-oak-entry-proof.md`.

After implementation/evidence, route the exact revision to independent Reviewer. Do not declare the gameplay leaf, parent Phase 3 exit proof, or Phase 3 complete without that independent review.

## After independent PASS

Orchestrator must re-evaluate the full [`../tasks/phase3-exit-proof.md`](../tasks/phase3-exit-proof.md) acceptance against all accumulated deterministic evidence before changing canonical Phase 3 status.

Independent PASS on this title/Oak leaf alone does not automatically make Phase 3 `DONE`.

## Continuous-improvement check

The concrete process defect identified earlier was the stale task-specific Local Worker Bridge route. That defect has now been repaired and independently verified. No further coordination redesign is justified by current evidence.

```text
Phase 3 title/Oak entry proof
-> CHARACTERIZED: narrow title -> Oak seam missing
-> bridge prerequisite: REVIEWED PASS / CLOSED
-> READY_FOR_WORKER
-> WORKER implements/proves title -> Oak entry
-> REVIEWER
-> ORCHESTRATOR re-evaluates full Phase 3 exit proof
```
