# Task: add Local Worker Bridge route for the Phase 2 camera viewport proof

- Status: `ACTIVE`
- AGI status: `AGI READY`
- Type: `INFRASTRUCTURE / EXECUTION SUBSTRATE`
- Owner: project maintainer
- Risk: `MEDIUM`
- Parent dependency: `work/tasks/phase2-gba-camera-viewport-proof.md`

## Goal

Remove only the execution-substrate blocker for `phase2-gba-camera-viewport-proof` by extending the guarded Local Worker Bridge with one explicit fail-closed route for that task.

This prerequisite changes bridge routing only. It does not implement camera behavior, edit the normal overworld renderer, or change gameplay.

## Source of truth

- Root `AGENTS.md`.
- `work/coordination/LOCAL_RUNNER_BRIDGE.md`.
- `.github/workflows/local-worker-bridge.yml`.
- `work/tasks/phase2-gba-camera-viewport-proof.md` for the blocked task's exact authorized implementation/evidence surface.
- Current `work/coordination/STATE.json` / `HANDOFF.md`.
- Previously reviewed explicit bridge-route tasks; preserve their security model rather than making routing generic.

## MAY CHANGE

Only:

- `.github/workflows/local-worker-bridge.yml`;
- `work/coordination/LOCAL_RUNNER_BRIDGE.md` if needed for accuracy;
- focused bridge probe/validation support if required;
- this task and coordination/review documentation.

## MUST NOT CHANGE

- `main.lua` or any camera/gameplay/runtime behavior;
- `src/core/` camera implementation;
- Phase 2 focused tests/replay implementation except route names/commands referenced by bridge configuration;
- public-PR execution policy;
- supported-ROM policy or exact FireRed US v1.0 SHA-1 gate;
- ROM, BIOS, generated cache, reference screenshots, extracted game assets, or other prohibited content;
- repository permissions beyond the existing bridge needs;
- independent-review requirements.

## Required security invariants

The bridge must continue to:

1. run self-hosted work only from trusted `push` events to `main`;
2. never execute `pull_request` or `pull_request_target` code on the self-hosted runner;
3. require exactly one recognized request/probe in the triggering commit;
4. route explicitly and fail closed on unknown tasks;
5. validate every patch target against a hard-coded task-bounded allowlist before applying it;
6. verify FireRed US v1.0 SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc` before ROM-backed execution;
7. run route-specific focused evidence, the full no-ROM suite, the full verified-ROM suite, and any required camera runtime probe before publication;
8. stage/publish only files explicitly authorized by `phase2-gba-camera-viewport-proof.md`;
9. keep ROM paths/content and ROM-derived screenshots/assets out of committed requests/artifacts.

## Acceptance criteria

1. `phase2-gba-camera-viewport-proof` selects one dedicated explicit route; unknown routes still fail closed.
2. The route authorizes only the camera task's bounded surface: expected camera module under `src/core/`, `main.lua` camera integration, focused camera test(s), optional camera runtime probe script, and relevant task/coordination/review documentation.
3. There is no wildcard target, inferred permission, or generic fallback.
4. The route has explicit focused-test and, if the task uses it, runtime-probe commands plus the existing no-ROM and verified-ROM suite gates.
5. Publish staging is explicit and limited to the task-authorized files.
6. Existing trusted-main-only, no-public-PR, exact-ROM-SHA, validation-before-apply, test-before-publish, and no-ROM-content invariants remain unchanged.
7. A non-gameplay probe or equivalent deterministic validation proves the new route is recognized without applying camera implementation.
8. Independent Reviewer returns `PASS` on the exact bridge-maintenance revision before the camera viewport task is restored to Worker.

## Preferred design

Extend the existing explicit route-selection pattern with one narrow task route. Do not redesign the bridge and do not parse arbitrary task prose to derive permissions.

## Stop / escalate

Return `BLOCKED` rather than weakening the guardrails if this requires public-PR self-hosted execution, arbitrary targets, a generic fallback, dropping the exact ROM gate, publishing before tests, broader repository permissions, or camera/gameplay implementation inside this prerequisite.

## Completion / handoff

Completion means the route is deterministically recognized, all bridge invariants remain intact, and an independent Reviewer returns `PASS`. Orchestrator must then restore `work/tasks/phase2-gba-camera-viewport-proof.md` as the sole `READY_FOR_WORKER` package.
