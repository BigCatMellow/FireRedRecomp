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

No task or phase completion is claimed. The exact revision is now awaiting independent Reviewer verification.

## What changed

The published gameplay change is confined to `main.lua`, which is within the active task MAY CHANGE boundary. It:

- wires the existing `OakParcelDexPresentation` FSM into runtime;
- starts it only through the existing task's strengthened north-facing guard and preflight;
- keeps ordinary player/NPC field input locked while the presenter owns the scene;
- uses the real Lab object-event template for the temporary rival rather than adding generic `addobject` semantics;
- drives the recorded rival/Oak movement groups using the existing forced-step primitive;
- removes temporary rival/Dex props from the live list without setting persistent hide flags;
- presents the existing source-derived ROM text pointers through the field message window;
- preserves the recorded rival wait/facing choreography and a bounded walk-in-place interval before Dex prop removal;
- delegates the durable Parcel/Dex/Poke Ball state change to the existing `ViridianParcelStory:completeLabParcelReturn(...)` callback only at the presenter's terminal commit;
- extends the existing natural-capture runtime replay so the Oak scene is advanced through ordinary input before progression continues.

The implementation did not alter generic script interpreter/map-hook/addobject systems, other Oak orientations, Mart UI, save codec, or battle rules.

## Evidence from guarded local runner

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

Bridge results:

- patch target validation: `PASS`
- patch application / `git diff --check`: `PASS`
- `tests/oak_parcel_dex_presentation_test.lua`: `PASS`
- full no-ROM `scripts/test_all.sh`: `PASS`
- full verified-ROM `scripts/test_all.sh`: `PASS`
- `scripts/runtime_natural_capture_replay.sh`: `PASS`
- bounded implementation publication: `PASS`

A separate pre-implementation no-ROM baseline also passed on request-only revision `6cfc6da77dae9c2fc17df1f375b993f50405bb7b` in workflow run `34547081873`; `main.lua` was still unchanged at that point.

## Failed request history — no code applied

Several earlier bridge requests were rejected before implementation and are retained as evidence that the bridge failed closed rather than applying uncertain patches:

- `6a7e472b0f45fcafbd927091672f0008d959809e` / run `34546586750`: malformed diff at line 18.
- `bc4d1519bcfbada02c97b9017273fbb9388e97a6` / run `34546852311`: malformed diff at line 208.
- `6cfc6da77dae9c2fc17df1f375b993f50405bb7b` / run `34547081926`: input-lock hunk did not match current `main.lua`.
- `a248b17f9c54369c945a85d34a2f2cf3942c59ae` / run `34547332162`: later replay bookkeeping hunk did not match.
- `60bf9c6dd14ebfc4cd71ca48d852b24d5c1f91a5` / run `34547517581`: insertion diff count was stale after the bounded walk-in-place interval was added.

All five stopped at patch validation. None applied or published gameplay code.

## Reviewer assignment

Independently verify exact implementation revision `2d8c3221775044a54668683e500055307fe4d20b` against the existing active task. In particular verify:

1. the exact strengthened north-facing guard and preflight;
2. all non-matching Oak interactions preserve their prior path;
3. source-derived text ordering and bounded movement choreography;
4. player/NPC input lock for the complete presentation;
5. real Lab rival template use and temporary rival/prop removal without persistent hide flags;
6. no early or duplicate durable mutation; `ViridianParcelStory` commits once at terminal completion;
7. bridge test evidence, including the verified-ROM suite and natural-capture replay;
8. changed-file/task-boundary compliance and regression risk.

Return only the existing review dispositions `PASS`, `NEEDS_FIX`, or `BLOCK`. Do not invent new requirements, implement a correction in the same review turn, or infer broader Phase 3 completion.

## Do not redo

- Do not restart source-order investigation for the presenter.
- Do not replace the existing task graph or roadmap.
- Do not widen into generic script/addobject behavior or other Oak orientations.
- Do not bypass the canonical Mart/Parcel/Dex path with synthetic state injection.
- Do not mark Phase 3 complete from this leaf task alone.
- Do not ask again for task-bounded publication authority; root `AGENTS.md` already grants it.
- Do not treat the earlier failed patch-request commits as gameplay revisions.

## Next role

`REVIEWER`

```text
REVIEWER independently verifies 2d8c3221775044a54668683e500055307fe4d20b
→ PASS: ORCHESTRATOR reconciles this leaf against the parent Phase 3 gate
→ NEEDS_FIX: route only the smallest correction
→ BLOCK: preserve the exact blocker without widening scope
```
