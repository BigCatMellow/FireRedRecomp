# Task: add Local Worker Bridge route for the complete Phase 3 replay

- Status: `ACTIVE`
- AGI status: `AGI READY`
- Type: `INFRASTRUCTURE / EXECUTION SUBSTRATE`
- Owner: project maintainer
- Risk: `MEDIUM`
- Parent dependency: `work/tasks/phase3-complete-runtime-exit-replay.md`

## Goal

Remove only the current execution-substrate blocker by adding an explicit, fail-closed Local Worker Bridge route for `phase3-complete-runtime-exit-replay`.

This task changes bridge routing only. It does not implement the complete replay, alter `main.lua`, or change gameplay.

## Source of truth

- Root `AGENTS.md`.
- `work/coordination/LOCAL_RUNNER_BRIDGE.md`.
- `.github/workflows/local-worker-bridge.yml`.
- `work/tasks/phase3-complete-runtime-exit-replay.md` for the blocked evidence task's authorized surfaces and required evidence.
- Current `work/coordination/STATE.json` / `HANDOFF.md`.
- Previously reviewed bridge-routing task `work/tasks/local-worker-bridge-task-routing.md`; preserve its security invariants and do not redesign the bridge generically.

## Established facts

- The complete-runtime evidence task is ready in design but Worker cannot safely publish the required bounded `main.lua` replay-driver patch through the guarded bridge.
- The live workflow recognizes only `phase3-title-oak-entry-proof`, `oak-parcel-dex-presentation-north`, and `runner-readiness`.
- Unknown routes correctly fail closed.
- The active evidence task authorizes `main.lua` replay-driver plumbing, `scripts/` runtime replay support, focused tests/assertions, and task/parent documentation, but not workflow changes.
- No gameplay defect has been discovered at this blocker.

## MAY CHANGE

Only:

- `.github/workflows/local-worker-bridge.yml`;
- `work/coordination/LOCAL_RUNNER_BRIDGE.md` if needed to keep documented procedure accurate;
- focused bridge validation/probe support only if required;
- this task and coordination/review documentation.

## MUST NOT CHANGE

- `main.lua` or any gameplay/runtime behavior;
- the actual complete-runtime replay/test implementation except names referenced by bridge routing logic;
- public-PR execution policy;
- supported-ROM policy or exact FireRed US v1.0 SHA-1 gate;
- save format/layout;
- ROM, BIOS, generated cache, screenshots/assets extracted from the game, or other prohibited content;
- repository permissions beyond the existing bridge needs;
- independent-review requirements.

## Required security invariants

The bridge must continue to:

1. run only on trusted `push` events to `main` for controlled request/probe paths;
2. never execute `pull_request` or `pull_request_target` code on the self-hosted runner;
3. require exactly one request/probe in a triggering commit;
4. select task routing explicitly and fail closed on unknown routes;
5. validate every patch target against a hard-coded task-bounded allowlist before `git apply`;
6. verify FireRed US v1.0 SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc` before ROM-backed execution;
7. run the route-specific focused test, full no-ROM suite, full verified-ROM suite, and route-specific runtime replay before publication;
8. stage/publish only files explicitly authorized by the complete-runtime evidence task;
9. keep ROM paths/content out of committed requests and artifacts.

## Acceptance criteria

1. A request/probe named for `phase3-complete-runtime-exit-replay` selects a dedicated explicit route; unknown routes still fail closed.
2. That route authorizes only the complete-runtime task's bounded implementation/evidence surface: expected `main.lua`, focused test, runtime replay script, and relevant task/parent documentation. Do not add a wildcard or generic fallback.
3. Patch execution for the route has an explicit focused-test command and explicit complete-runtime replay command, plus the existing no-ROM and verified-ROM suite gates.
4. Publish staging for the route is explicit and limited to authorized files.
5. Existing trusted-main-only, no-public-PR, exact-ROM-SHA, target-validation-before-apply, test-before-publish, and no-ROM-content invariants remain intact.
6. A non-gameplay probe or equivalent deterministic validation proves the new route is recognized without applying a gameplay patch.
7. Independent Reviewer returns `PASS` on the exact bridge-maintenance revision before `phase3-complete-runtime-exit-replay` is restored to Worker.

## Preferred design

Extend the already-reviewed explicit `case`-based routing pattern with one narrow route. Do not redesign the bridge or infer permissions from arbitrary task prose or patch contents.

## Deterministic evidence plan

1. Inspect the live workflow and prior reviewed bridge task.
2. Add only the complete-runtime route, target allowlist, focused-test command, runtime-replay command, and publish staging required by the blocked evidence task.
3. Validate workflow/routing syntax locally where possible.
4. Trigger a non-gameplay probe for `phase3-complete-runtime-exit-replay` and verify route selection, runner/toolchain readiness, and exact private-ROM hash gate without patch application.
5. Record exact revision and evidence.
6. Route the exact revision to independent Reviewer.

## Stop / escalate

Stop rather than weaken security if this would require public-PR self-hosted execution, arbitrary targets, a generic fallback route, dropping the exact ROM gate, publishing before tests, storing ROM information in git, broader permissions, gameplay changes, or redesigning the coordination architecture.

## Completion / handoff

Completion closes only this execution-substrate prerequisite. After independent `PASS`, Orchestrator restores `work/tasks/phase3-complete-runtime-exit-replay.md` as `READY_FOR_WORKER`. Phase 3 remains `IN PROGRESS` until the complete parent exit proof itself is independently verified.
