# FireRedRecomp Coordination Handoff

- Record role: `HANDOFF`
- Primary information class: `TASK CONTEXT`
- Status: `READY_FOR_REVIEWER`
- Lifecycle: `ACTIVE`
- Authority: coordination state only; root `AGENTS.md` and the active task own authority
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Parent gameplay gate: [`../tasks/phase3-exit-proof.md`](../tasks/phase3-exit-proof.md)
- Blocked gameplay task: [`../tasks/phase3-title-oak-entry-proof.md`](../tasks/phase3-title-oak-entry-proof.md)
- Active task: [`../tasks/local-worker-bridge-task-routing.md`](../tasks/local-worker-bridge-task-routing.md)
- Machine state: [`STATE.json`](STATE.json)

## Summary

Worker completed the bounded Local Worker Bridge routing package and routed it to independent review.

The bridge no longer applies the completed Oak Parcel/Dex target/test/replay/staging configuration unconditionally. Request/probe filenames now select an explicit hard-coded task route. Unknown routes fail closed, and each patch route has an exact target allowlist plus route-specific focused test, runtime replay, and publish staging.

No gameplay/runtime file was changed by this infrastructure package. Phase 3 remains `IN PROGRESS`.

## Exact Worker revision

Substantive bridge-maintenance revision:

`0f0dc2f028f204dce4fcaee4e0fff0d9d0afb61e`

This revision includes, through its ancestry:

- `.github/workflows/local-worker-bridge.yml` explicit route selection and per-route enforcement;
- `work/coordination/LOCAL_RUNNER_BRIDGE.md` procedure update;
- `work/local-runner/probes/phase3-title-oak-entry-proof-route.probe` non-gameplay validation probe.

Task evidence was then recorded in `work/tasks/local-worker-bridge-task-routing.md` at `858bc97b7fac07caa80979e917101f2faf564cc3`.

## What changed

The workflow now recognizes explicit routes from the request/probe filename:

- `phase3-title-oak-entry-proof...`
- `oak-parcel-dex-presentation-north...`
- `runner-online...probe`

For `phase3-title-oak-entry-proof`, the bridge permits only the exact bounded gameplay/evidence surface expected by that task:

- `main.lua`
- `tests/phase3_title_oak_entry_test.lua`
- `scripts/runtime_title_oak_entry_replay.sh`
- `work/tasks/phase3-title-oak-entry-proof.md`
- `work/tasks/phase3-exit-proof.md`

The route uses its own focused test, runtime replay, and explicit staging list. Unknown task identifiers or unauthorized target paths fail before patch application.

The existing Oak Parcel/Dex route remains explicit; there is no generic permissive fallback.

## Preserved security boundaries

Worker did not alter these invariants:

- workflow trigger remains trusted `push` to `main` on controlled request/probe paths only;
- there is no `pull_request` or `pull_request_target` self-hosted trigger;
- exactly one request/probe must be present in the triggering commit;
- target paths are validated before `git apply`;
- the exact supported FireRed US v1.0 SHA-1 remains required before ROM-backed execution;
- focused + no-ROM + verified-ROM + route-specific runtime replay must pass before implementation publication;
- publish staging remains explicit by route;
- no ROM/cache/assets are placed in GitHub.

## Deterministic evidence

Probe commit:

`0f0dc2f028f204dce4fcaee4e0fff0d9d0afb61e`

Local Worker Bridge run:

`34598648805` — `success`

Verified on runner `firered-mint`:

1. trusted-main checkout — PASS;
2. exactly one bridge probe identified — PASS;
3. explicit task route selection — PASS;
4. selected route was exactly `phase3-title-oak-entry-proof` — PASS;
5. Lua toolchain — PASS (`Lua 5.1.5`);
6. exact private FireRed US v1.0 ROM SHA gate — PASS;
7. probe completion — PASS and explicitly reported the title/Oak route recognized.

Patch validation/application, focused tests, full suites, runtime replay, and publication were intentionally skipped because this was a non-gameplay probe. The probe therefore changed no gameplay/runtime files.

The repository's ordinary `Lua tests` workflow also ran on the same probe commit:

`34598648798` — `success`

## Reviewer task

Next role: `REVIEWER`.

Review only the existing bridge-maintenance acceptance criteria. Independently inspect the exact substantive revision and probe evidence.

Verify especially:

1. `phase3-title-oak-entry-proof` is explicitly supported with only its bounded target/test/replay/staging surface;
2. the old Oak Parcel/Dex configuration is not an unconditional fallback;
3. unknown task routes fail closed before patch application;
4. unauthorized targets fail closed before `git apply`;
5. trusted-main-only/no-public-PR self-hosted execution remains intact;
6. exact ROM SHA verification remains intact;
7. task-focused + no-ROM + verified-ROM + runtime replay ordering still gates publication;
8. probe run `34598648805` actually proves route recognition without gameplay modification.

Return only `PASS`, `NEEDS_FIX`, or `BLOCK` under the Reviewer contract. Do not implement the gameplay seam during review and do not advance Phase 3.

## After Reviewer PASS

Orchestrator must restore:

`work/tasks/phase3-title-oak-entry-proof.md`

as the active `READY_FOR_WORKER` package.

The already-characterized smallest gameplay work remains:

```text
wire normal title/new-game input -> existing Oak intro
+ deterministic runtime entry replay/assertions
+ required focused/no-ROM/verified-ROM evidence
+ independent review
```

Do not substitute Phase 2 Oak visual parity, Phase 4 battles, generic scene architecture, script-interpreter work, or save-layout expansion.

## Current relay

```text
Phase 3 title/Oak entry proof
-> CHARACTERIZED: narrow title -> Oak seam missing
-> execution substrate mismatch isolated
-> Local Worker Bridge routing maintenance IMPLEMENTED + PROBED
-> READY_FOR_REVIEWER
-> REVIEWER
-> ORCHESTRATOR restores same title/Oak gameplay task after PASS
```
