# Task: retarget Local Worker Bridge for the active bounded task

- Status: `ACTIVE`
- AGI status: `AGI READY`
- Type: `INFRASTRUCTURE / EXECUTION SUBSTRATE`
- Owner: project maintainer
- Risk: `MEDIUM`
- Parent dependency: `work/tasks/phase3-title-oak-entry-proof.md`

## Goal

Remove the stale execution-substrate blocker by making the Local Worker Bridge safely support the currently authorized Phase 3 title/Oak entry task without weakening the public-repository/self-hosted-runner security boundary.

This task changes execution routing only. It does **not** implement the title-to-Oak gameplay seam itself and does not expand the Phase 3 gameplay task.

## Source of truth

- Root `AGENTS.md`.
- `work/coordination/LOCAL_RUNNER_BRIDGE.md` for bridge invariants and operating procedure.
- `.github/workflows/local-worker-bridge.yml` for live bridge behavior.
- `work/tasks/phase3-title-oak-entry-proof.md` for the currently blocked gameplay task's authorized file categories and required evidence.
- Current `work/coordination/STATE.json` / `HANDOFF.md` for the observed blocker.

## Established facts

Worker characterization established that:

- the normal title screen currently has no runtime input transition into the existing Oak intro;
- the active Phase 3 task permits a narrow `main.lua` integration correction and focused replay/test support;
- the Local Worker Bridge still hard-codes the completed Oak Parcel/Dex task's target allowlist, focused test, runtime replay, and publish staging;
- therefore a valid title-entry patch cannot currently pass through the only verified safe large-file edit substrate.

## MAY CHANGE

Only the smallest bridge-maintenance surface needed to remove that mismatch:

- `.github/workflows/local-worker-bridge.yml`;
- `work/coordination/LOCAL_RUNNER_BRIDGE.md` if the procedure must be clarified to match the corrected workflow;
- focused bridge validation/test support under `.github/` or `scripts/` only if required to deterministically prove the routing/security behavior;
- this task and coordination/review documentation.

## MUST NOT CHANGE

- `main.lua` or any gameplay/runtime code;
- the implementation/test/replay files for `phase3-title-oak-entry-proof.md` except as names referenced by bridge routing logic;
- public-PR execution policy;
- supported-ROM policy or the verified FireRed US v1.0 SHA-1 gate;
- ROM, BIOS, generated cache, screenshots, or extracted game content;
- permissions broader than needed for the existing push-to-main commit/push mechanism;
- the standing requirement that Worker evidence still undergo independent Reviewer verification before broader status advancement.

## Required security invariants

The corrected bridge must continue to:

1. trigger only from trusted `push` events to `main` on controlled request/probe paths;
2. never execute `pull_request` or `pull_request_target` code on the self-hosted runner;
3. accept exactly one triggering request/probe per triggering commit;
4. validate every patch target against an explicit task-bounded allowlist before `git apply`;
5. verify the private ROM SHA-1 before ROM-backed execution;
6. publish only after the task-appropriate focused test plus no-ROM and verified-ROM suites pass;
7. stage/publish only explicitly authorized task files;
8. keep ROM paths/content out of committed request files and GitHub artifacts;
9. fail closed on unknown task/routing metadata rather than falling back to a broad allowlist.

## Acceptance criteria

1. The bridge can safely accept a patch request for `work/tasks/phase3-title-oak-entry-proof.md` whose targets are limited to the active task's expected bounded implementation/evidence surface, including `main.lua` and focused Phase 3 title/Oak entry replay/test files.
2. The stale Oak Parcel/Dex-only allowlist, focused-test command, replay command, and staging list are no longer unconditionally applied to every patch request.
3. Task selection/routing remains explicit and fail-closed; an unknown or unauthorized target/task is rejected before patch application.
4. The existing trusted-main-only, no-public-PR, exact-ROM-SHA, test-before-publish, and no-ROM-content security invariants remain intact.
5. A deterministic validation/probe demonstrates that the bridge recognizes the title/Oak task route without applying a gameplay patch, or equivalent focused evidence proves the route configuration before gameplay work resumes.
6. Independent Reviewer returns `PASS` on the exact bridge-maintenance revision before the blocked gameplay task is returned to Worker execution.

## Preferred design

Prefer the smallest explicit task-routing mechanism over a generic permissive bridge. Acceptable examples include a narrow task identifier carried by the request convention and mapped to hard-coded per-task target/test/staging definitions, or another equally fail-closed design.

Do not make the bridge infer broad permissions from arbitrary patch contents or from mutable task prose at runtime.

## Deterministic evidence plan

Worker should:

1. baseline-inspect the current workflow and bridge documentation;
2. make the smallest routing correction;
3. validate workflow syntax and target-routing logic locally where possible;
4. use a non-gameplay probe/validation path if needed to prove the title/Oak route is recognized while preserving the ROM/toolchain gates;
5. record exact evidence and revision;
6. route the exact revision to independent Reviewer.

A validation probe must not modify gameplay files.

## Stop / escalate

Stop rather than weaken security if the change would require:

- enabling self-hosted execution for public PR/fork code;
- accepting arbitrary target paths;
- dropping the exact ROM SHA gate;
- publishing before required tests pass;
- storing the private ROM path/content in GitHub;
- granting broader repository permissions than the current bridge needs;
- redesigning the full autonomous coordination architecture.

## Completion / handoff

Completion means the execution bridge safely supports the active `phase3-title-oak-entry-proof.md` package and has independent `PASS`.

After PASS, Orchestrator must reactivate **the same** `work/tasks/phase3-title-oak-entry-proof.md` task as `READY_FOR_WORKER`; this infrastructure leaf does not close any gameplay or Phase 3 capability gate by itself.
