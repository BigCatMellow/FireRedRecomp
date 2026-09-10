# FireRedRecomp Coordination Handoff

- Record role: `HANDOFF`
- Primary information class: `TASK CONTEXT`
- Status: `READY_FOR_WORKER`
- Lifecycle: `ACTIVE`
- Authority: coordination state only; publication authority is owned by root `AGENTS.md`; this handoff does not widen the active task
- Accountable owner: human project owner
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Active task: [`../tasks/oak-parcel-dex-presentation-north.md`](../tasks/oak-parcel-dex-presentation-north.md)
- Machine state: [`STATE.json`](STATE.json)
- Flow: [`README.md`](README.md)

## Compressed state

Phase 3 remains `IN PROGRESS`. The next bounded implementation is already defined: wire the existing north-facing Oak Parcel/Pokedex presenter into `main.lua`, verify source-lock/runtime behavior, run required suites/replay, then send the exact revision to independent review.

The former publication blocker is resolved. On 2026-09-10 the human project owner explicitly authorized Worker to publish bounded changes that remain inside an active task contract, provided they undergo independent Reviewer verification before broader status/phase advancement. Root `AGENTS.md` is the durable owner of that standing authority.

## Fresh-agent entry

1. Recover live GitHub state first.
2. Read root [`../../AGENTS.md`](../../AGENTS.md).
3. Read [`README.md`](README.md) and your role contract under `roles/`.
4. Read current [`STATE.json`](STATE.json).
5. Read the canonical [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md).
6. Read the active task [`../tasks/oak-parcel-dex-presentation-north.md`](../tasks/oak-parcel-dex-presentation-north.md).
7. Do not rely on this handoff if newer task/review/state evidence supersedes it.

## What is already established

- Phase 1 importer/data model is `DONE`; Phase 3 is `IN PROGRESS`.
- The larger Phase 3 proof is `work/tasks/phase3-exit-proof.md`.
- Current progression work has already proven bounded Mart/Parcel/Dex state flow and added presenter pieces.
- The active north-facing Oak task records source-derived text/movement ordering, exact guard, allowed files, stop conditions, and acceptance.
- Its completion section says the isolated presenter and focused test already exist; remaining work is runtime wiring, source-lock integration evidence, both suites, replay, and final independent review.
- Worker now has standing authority to publish task-bounded implementation/test/documentation commits without returning to the human merely for push approval.
- Publication does not equal approval: independent Reviewer verification is mandatory before broader status/phase advancement.

## Exact next package

WORKER:

- recover live state;
- confirm the active task remains current;
- baseline-test where available;
- apply only the recorded bounded `main.lua` wiring plan and any task-permitted focused support required for correctness;
- do not generalize the script interpreter, addobject/map hooks, Oak orientations, Mart UI, save codec, or battle rules;
- run focused tests and no-ROM suite;
- run required verified-ROM/source-lock/runtime replay evidence only in an environment that already has a legally obtained verified FireRed US v1.0 ROM;
- commit no ROM-derived assets/caches/screenshots;
- publish only changes inside the active task contract;
- update coordination state to `READY_FOR_REVIEWER` with exact revision and evidence, or `BLOCKED` with exact missing evidence.

REVIEWER then independently judges only the existing task criteria and returns `PASS`, `NEEDS_FIX`, or `BLOCK`.

ORCHESTRATOR then reconciles that result. A PASS closes only this bounded task unless broader Phase 3 exit evidence is also complete.

## Stop conditions

Stop rather than improvise if:

- verified source contradicts the recorded descriptor;
- completion requires generic script/addobject semantics;
- another player-facing Oak orientation is required;
- preflight cannot preserve current atomic failure behavior;
- a required ROM-backed result cannot actually be run;
- the change would require ROM/extracted game content in git;
- work would leave the active task contract or require a genuinely new human product/scope decision.

## Do not redo

- Do not restart importer/schema work; Phase 1 is already DONE.
- Do not replace the current Phase 3 task graph with a new roadmap.
- Do not bypass the real Mart/Parcel/Dex path using synthetic inventory/state injection.
- Do not mark Phase 3 complete merely because this Oak presenter passes.
- Do not ask the human again merely for publication/push approval when the proposed change stays entirely inside an active task contract; the standing authorization in root `AGENTS.md` already covers that case.
- Do not add a heavier Pilot/MAPS coordination stack unless this minimal three-role loop demonstrates a concrete need.
