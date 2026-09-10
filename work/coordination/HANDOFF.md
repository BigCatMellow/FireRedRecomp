# FireRedRecomp Coordination Handoff

- Record role: `HANDOFF`
- Primary information class: `TASK CONTEXT`
- Status: `READY_FOR_WORKER`
- Lifecycle: `ACTIVE`
- Authority: coordination state only; root `AGENTS.md` owns publication authority
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Active task: [`../tasks/oak-parcel-dex-presentation-north.md`](../tasks/oak-parcel-dex-presentation-north.md)
- Machine state: [`STATE.json`](STATE.json)
- Local execution bridge: [`LOCAL_RUNNER_BRIDGE.md`](LOCAL_RUNNER_BRIDGE.md)

## Current state

Phase 3 remains `IN PROGRESS`. The north-facing Oak Parcel/Dex presentation remains the smallest current critical-path task. No Reviewer result exists and no gameplay implementation has been published since the prior blocker.

The prior Worker environment blocker is now cleared. A guarded local-runner bridge exists at `.github/workflows/local-worker-bridge.yml` and is documented in `LOCAL_RUNNER_BRIDGE.md`.

Probe commit `8c0ed45123c1cb3e34f8d9f7398308c0deec2985` produced Local Worker Bridge run `34543172371` on self-hosted runner `firered-mint` with labels `self-hosted`, `linux`, `x64`, `firered-local`.

The probe passed:

- trusted `main` checkout;
- local Lua toolchain detection;
- private ROM discovery;
- exact FireRed US v1.0 SHA-1 gate `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`.

The probe did not apply gameplay changes and does not count as task acceptance evidence.

## Exact next Worker package

Resume the existing Oak task without redoing source investigation.

If the scheduler still cannot safely edit the large existing `main.lua` directly:

1. inspect the exact current code regions needed for the already-scoped wiring;
2. construct one minimal unified diff request under `work/local-runner/requests/<task-or-timestamp>.patch`;
3. keep every patch target within both the task MAY CHANGE boundary and the current bridge allowlist;
4. let the Local Worker Bridge apply the patch on `firered-mint`;
5. recover the bridge run and exact published implementation revision;
6. claim only evidence actually reported by the run;
7. on success, set `READY_FOR_REVIEWER` and update this handoff last;
8. on failure, record the exact failed step/log evidence and stop rather than widening scope.

The runtime wiring remains bounded to the recorded plan: require/wire `OakParcelDexPresentation`, intercept only the exact north-facing canonical guard, preserve all non-matching Oak interactions, use existing Lab object templates and movement/text machinery, keep input locked while the presenter owns the scene, and delegate durable state exactly once through the existing `ViridianParcelStory` terminal commit path.

## Bridge security boundary

The repository is public. The local workflow therefore runs only for trusted `push` events to `main` under the dedicated bridge request/probe paths; it does not run for `pull_request`. Patch targets are allowlisted. The ROM remains local and is hash-verified before ROM-backed execution. Never commit or upload the ROM, generated cache, extracted assets, or other prohibited content.

## Do not redo

- Do not restart source-order investigation for the presenter.
- Do not replace the existing task graph or roadmap.
- Do not widen into generic script/addobject behavior or other Oak orientations.
- Do not bypass the canonical Mart/Parcel/Dex path with synthetic state injection.
- Do not mark Phase 3 complete from this leaf task alone.
- Do not ask again for task-bounded publication authority; root `AGENTS.md` already grants it.
- Do not treat the successful runner probe as gameplay acceptance evidence.

## Next role

`WORKER`

Result chain after a successful bridge run:

```text
WORKER publishes bounded tested implementation
→ REVIEWER independently verifies exact revision
→ ORCHESTRATOR reconciles parent Phase 3 gate
```
