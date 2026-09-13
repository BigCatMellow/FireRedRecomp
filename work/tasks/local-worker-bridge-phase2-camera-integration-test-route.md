# Task: correct the Phase 2 camera bridge integration-test route

- Status: `ACTIVE`
- AGI status: `AGI READY`
- Type: `INFRASTRUCTURE / EXECUTION SUBSTRATE`
- Owner: project maintainer
- Risk: `LOW`
- Parent dependency: `work/tasks/phase2-gba-camera-viewport-proof.md`

## Goal

Add exactly the already-reviewed camera package's focused integration test,
`tests/phase2_camera_viewport_integration_test.lua`, to the existing explicit
camera bridge route's validation, focused-test execution, and publish staging.

The route currently permits the primary geometry test but rejects this second
task-authorized focused test. Correct that mismatch without weakening any existing
bridge invariant or changing camera/gameplay behavior.

## MAY CHANGE

- `.github/workflows/local-worker-bridge.yml`;
- `work/coordination/LOCAL_RUNNER_BRIDGE.md` only if route prose needs accuracy;
- this task and coordination/review documentation.

## MUST NOT CHANGE

- `main.lua`, `src/core/`, camera behavior, tests themselves, runtime replay,
  gameplay, save format, ROM policy, or repository permissions;
- trusted-main-only/no-public-PR execution policy, exact ROM SHA gate, fail-closed
  routing, existing target allowlists, or independent-review requirement;
- ROMs, BIOS, screenshots, extracted assets, or generated content.

## Acceptance criteria

1. Only `tests/phase2_camera_viewport_integration_test.lua` is added to the
   hard-coded Phase 2 camera patch-target allowlist and explicit publish staging.
2. The route runs both `tests/camera_viewport_test.lua` and the integration test as
   explicit focused evidence before existing full-suite/runtime gates.
3. No wildcard, generic fallback, policy, permission, ROM, or unrelated route
   change is introduced.
4. A deterministic non-gameplay static check and `bash -n` succeed; the no-ROM
   suite passes.
5. Independent Reviewer returns `PASS` on the exact correction revision before
   the camera patch request is published.

## Stop / escalate

Stop rather than remove the integration test or broaden the route if adding the
single exact path requires any other camera/gameplay change or bridge-policy change.

## Completion / handoff

After independent `PASS`, return immediately to the unchanged camera implementation
revision `ab8bdc718c097092caad92dedc92b377c18c1ef6`, create its bounded bridge
patch request, and require the guarded runner's focused/full/runtime evidence before
claiming publication.
