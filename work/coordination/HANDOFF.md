# FireRedRecomp Coordination Handoff

- Record role: `HANDOFF`
- Primary information class: `TASK CONTEXT`
- Status: `READY_FOR_REVIEWER`
- Lifecycle: `ACTIVE`
- Authority: coordination state only; root `AGENTS.md` owns publication authority
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Active task: [`../tasks/oak-parcel-dex-presentation-north.md`](../tasks/oak-parcel-dex-presentation-north.md)
- Machine state: [`STATE.json`](STATE.json)
- Local execution bridge: [`LOCAL_RUNNER_BRIDGE.md`](LOCAL_RUNNER_BRIDGE.md)

## Current state

Phase 3 remains `IN PROGRESS`. Worker completed the bounded runtime integration for the north-facing Oak Parcel/Dex presentation and published exact implementation revision:

`2d8c3221775044a54668683e500055307fe4d20b`

Orchestrator recovered live state after that publication and found **no independent Reviewer verdict yet**. Therefore no task, parent gate, execution-map gate, or canonical phase status is closed or advanced. The same exact implementation remains queued for independent Reviewer verification.

## Orchestrator reconciliation

Result: `AWAITING_INDEPENDENT_REVIEW`

- implementation revision: `2d8c3221775044a54668683e500055307fe4d20b`
- reviewed revision: none yet
- task status change: `NONE`
- canonical status change: `NONE`
- dispatch change: `NONE`
- blocker: none

The correct next action is review, not another Worker package. `CAPABILITY_CHECKLIST.md` still owns Phase 3 status and continues to report the phase `IN PROGRESS` until its full exit criterion is proven and independently reviewed.

## What Worker changed

The published gameplay change is confined to `main.lua`, which is within the active task MAY CHANGE boundary. Worker reports that it:

- wires the existing `OakParcelDexPresentation` FSM into runtime;
- starts it only through the task's strengthened north-facing guard and preflight;
- locks ordinary field input while the presenter owns the scene;
- uses the real Lab rival object template rather than generic `addobject` semantics;
- drives the recorded rival/Oak movement choreography through existing movement primitives;
- removes temporary rival/Dex props from the live list without persistent hide flags;
- presents the existing source-derived ROM text pointers through the field message window;
- delegates durable Parcel/Dex/Poké Ball mutation to `ViridianParcelStory:completeLabParcelReturn(...)` only at terminal commit;
- advances the existing natural-capture runtime replay through the Oak scene using ordinary input.

These are Worker claims plus bridge evidence until independently checked. Reviewer must reconstruct rather than inherit Worker confidence.

## Recorded Worker evidence

Request file:
`work/local-runner/requests/2026-09-10-oak-parcel-dex-runtime-v6.patch`

Request revision:
`56f954e56cc632d993ecbc6c25f934d8fbfb4726`

Local Worker Bridge run:
`34547647645`

Runner:
`firered-mint`

Verified ROM SHA-1:
`41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`

Recorded bridge results:

- patch target validation: `PASS`
- patch application / `git diff --check`: `PASS`
- `tests/oak_parcel_dex_presentation_test.lua`: `PASS`
- full no-ROM `scripts/test_all.sh`: `PASS`
- full verified-ROM `scripts/test_all.sh`: `PASS`
- `scripts/runtime_natural_capture_replay.sh`: `PASS`
- bounded implementation publication: `PASS`

A separate pre-implementation no-ROM baseline passed on request-only revision `6cfc6da77dae9c2fc17df1f375b993f50405bb7b` in workflow run `34547081873` while gameplay `main.lua` remained unchanged.

## Failed request history — no code applied

Earlier bridge requests were rejected before gameplay implementation:

- `6a7e472b0f45fcafbd927091672f0008d959809e` / run `34546586750`: malformed diff at line 18.
- `bc4d1519bcfbada02c97b9017273fbb9388e97a6` / run `34546852311`: malformed diff at line 208.
- `6cfc6da77dae9c2fc17df1f375b993f50405bb7b` / run `34547081926`: input-lock hunk did not match current `main.lua`.
- `a248b17f9c54369c945a85d34a2f2cf3942c59ae` / run `34547332162`: later replay bookkeeping hunk did not match.
- `60bf9c6dd14ebfc4cd71ca48d852b24d5c1f91a5` / run `34547517581`: insertion diff count stale after the bounded walk-in-place interval addition.

These are not gameplay revisions and must not be reviewed as the implementation.

## Reviewer assignment

Independently verify exact implementation revision `2d8c3221775044a54668683e500055307fe4d20b` against `work/tasks/oak-parcel-dex-presentation-north.md`.

Verify, without adding new requirements:

1. the strengthened north-facing guard and preflight;
2. all non-matching Oak interactions preserve their prior path;
3. source-derived text ordering and bounded movement choreography;
4. player/NPC input lock throughout the presentation;
5. real Lab rival template use and temporary rival/prop removal without persistent hide flags;
6. no early or duplicate durable mutation; `ViridianParcelStory` commits exactly once at terminal completion;
7. recorded bridge evidence, including the verified-ROM suite and natural-capture replay;
8. changed-file/task-boundary compliance and regression risk.

Return exactly one existing disposition: `PASS`, `NEEDS_FIX`, or `BLOCK`.

- `PASS` → Orchestrator closes only this bounded leaf where supported, then re-evaluates the parent Phase 3 gate and dispatches the smallest still-unproven acceptance item.
- `NEEDS_FIX` → Orchestrator routes only the smallest stated correction within existing task authority.
- `BLOCK` → Orchestrator preserves the exact blocker and does not widen scope.

## Do not redo

- Do not restart source-order investigation for the presenter.
- Do not replace the existing task graph or roadmap.
- Do not widen into generic script/addobject behavior or other Oak orientations.
- Do not bypass the canonical Mart/Parcel/Dex path with synthetic state injection.
- Do not mark Phase 3 complete from this leaf task alone.
- Do not ask again for task-bounded publication authority; root `AGENTS.md` already grants it.
- Do not treat the earlier failed patch-request commits as gameplay revisions.
- Do not dispatch another Worker package while this exact implementation is awaiting independent review.

## Next role

`REVIEWER`

```text
REVIEWER independently verifies 2d8c3221775044a54668683e500055307fe4d20b
→ PASS: ORCHESTRATOR reconciles this leaf against the parent Phase 3 gate
→ NEEDS_FIX: route only the smallest correction
→ BLOCK: preserve the exact blocker without widening scope
```
