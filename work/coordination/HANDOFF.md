# FireRedRecomp Coordination Handoff

- Record role: `HANDOFF`
- Primary information class: `TASK CONTEXT`
- Status: `BLOCKED_WORKER_ENVIRONMENT`
- Lifecycle: `ACTIVE`
- Authority: coordination state only; publication authority is owned by root `AGENTS.md`; this handoff does not widen the active task
- Accountable owner: human project owner
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Active task: [`../tasks/oak-parcel-dex-presentation-north.md`](../tasks/oak-parcel-dex-presentation-north.md)
- Machine state: [`STATE.json`](STATE.json)
- Flow: [`README.md`](README.md)

## Compressed state

Phase 3 remains `IN PROGRESS`. The current Worker recovered the exact active Oak Parcel/Pokedex task and inspected the live implementation, but **published no gameplay change** because this scheduler runtime does not currently provide a safe way to patch the repository's large `main.lua`.

The task itself is not conceptually blocked: the exact insertion point is known, the pure presenter exists, and the focused presenter test exists. The blocker is execution infrastructure.

## Fresh-agent entry

1. Recover live GitHub state first.
2. Read root [`../../AGENTS.md`](../../AGENTS.md).
3. Read [`README.md`](README.md) and your role contract under `roles/`.
4. Read current [`STATE.json`](STATE.json).
5. Read the canonical [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md).
6. Read [`../roadmaps/EXECUTION_MAP.md`](../roadmaps/EXECUTION_MAP.md).
7. Read the active task [`../tasks/oak-parcel-dex-presentation-north.md`](../tasks/oak-parcel-dex-presentation-north.md).
8. Do not rely on this handoff if newer task/review/state evidence supersedes it.

## What Worker verified this run

- `STATE.json` was `READY_FOR_WORKER`; the bounded package was authorized.
- Current `main.lua` blob: `8221ba50e337f9f8eb30758d3dccb6b566a756ae`.
- Current presenter blob: `6e240039cc2fd6d2441e1619988173210db78b5d`.
- Current focused test blob: `52a02b78ec0468412dee01add130641bb80d904a`.
- The current Oak interaction in `tryStartInteraction()` still directly calls `ViridianParcelStory:completeLabParcelReturn(...)` and reports an abbreviated cutscene. Therefore the active presenter is genuinely not wired into runtime yet.
- The bounded presenter already carries the exact north guard, source-derived 15-text sequence, rival/Dex-prop movement descriptors, non-mutating preflight callback, and terminal-only commit callback.
- The existing `ViridianParcelStory` boundary already provides the correct atomic durable operation for the presenter's final commit.

## Exact runtime wiring that remains

When a safe checkout/patch execution path exists, stay inside the existing active task and:

- require/wire `OakParcelDexPresentation` in `main.lua` only;
- intercept only the exact Oak interaction guard: Lab `(4,3)`, player `(6,4)` facing north/up, Oak local id 4, Mart scene 1, Lab scene 5, Parcel present, successful five-Poke-Ball capacity preflight;
- preserve all non-matching Oak interactions exactly as they behave now;
- use the existing real Lab object templates for the temporary rival rather than adding generic `addobject` semantics;
- schedule the presenter's source-derived movement/text sequence using existing bounded movement/text machinery;
- remove the temporary rival and Dex props from the live object list without setting persistent hide flags;
- keep player/NPC field input locked while the presenter owns the scene;
- call `ViridianParcelStory:completeLabParcelReturn(...)` only from the presenter's terminal commit callback;
- update the existing natural-capture replay to advance this presenter through normal input and verify the persistent result;
- run the focused test, no-ROM suite, required verified-ROM/source-lock/runtime replay, then route the exact revision to independent Reviewer.

Do **not** generalize script/addobject/map-hook behavior, add other Oak orientations, alter Mart UI, save codec, or battle rules.

## Blocker observed

The scheduler's container could not obtain a repository checkout: `git clone` failed with `Could not resolve host: github.com`.

The connected GitHub write operation available here replaces an entire UTF-8 file rather than applying a bounded patch. `main.lua` is approximately 224 KB. Reconstructing and replacing that entire file from partial connector retrievals would risk silently dropping unrelated code, violating the smallest-safe-change rule. Worker therefore failed closed and published no implementation.

Tests were **not run** in this environment. No no-ROM, ROM-backed, replay, or source-lock execution result is claimed.

## Required unblock

Provide the scheduled Worker with either:

1. a writable repository checkout, or
2. a safe partial-file/patch editing capability for existing GitHub files.

Separately, final acceptance still requires a private/local environment with a legally obtained verified FireRed US v1.0 ROM for ROM-backed replay evidence. The ROM must never be committed or uploaded to GitHub.

## Next role

ORCHESTRATOR should preserve this active task and exact blocker. It should not manufacture unrelated work merely to keep the loop active. Once the execution substrate is repaired, the same task can resume without redoing the presenter/source investigation.

## Do not redo

- Do not restart importer/schema work; Phase 1 is already DONE.
- Do not replace the current Phase 3 task graph with a new roadmap.
- Do not redo the presenter's source-order investigation or focused pure-test design.
- Do not bypass the real Mart/Parcel/Dex path using synthetic inventory/state injection.
- Do not mark Phase 3 complete merely because this Oak presenter eventually passes.
- Do not ask the human again merely for task-bounded publication authority; root `AGENTS.md` already grants it.
- Do not interpret this environment blocker as permission to widen scope.

## Latest Worker result

At `2026-09-10T15:21:00Z`, Worker completed live-state recovery and bounded code inspection but made no implementation commit. Durable state is now `BLOCKED_WORKER_ENVIRONMENT`. The execution substrate, not the task definition, must be fixed before safe continuation.
