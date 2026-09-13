# Task: retarget Local Worker Bridge for the active bounded task

- Status: `CLOSED — REVIEWED PASS`
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
- Current `work/coordination/STATE.json` / `HANDOFF.md` for coordination state.

## Established facts

Worker characterization established that:

- the normal title screen currently has no runtime input transition into the existing Oak intro;
- the Phase 3 task permits a narrow `main.lua` integration correction and focused replay/test support;
- the Local Worker Bridge was hard-coded to the completed Oak Parcel/Dex task's target allowlist, focused test, runtime replay, and publish staging;
- therefore a valid title-entry patch could not pass through the verified safe large-file edit substrate until this routing task was completed.

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

## Worker result — 2026-09-11

Substantive bridge-maintenance revision: `0f0dc2f028f204dce4fcaee4e0fff0d9d0afb61e`.

Implemented:

- request/probe filenames now select an explicit hard-coded route;
- `phase3-title-oak-entry-proof` has an exact bounded target allowlist for `main.lua`, its focused test/replay, and the two relevant task docs;
- focused test, runtime replay, and publish staging are selected by route rather than unconditionally using the completed Oak Parcel/Dex commands;
- unknown route identifiers fail before patch validation/application;
- unknown targets fail before `git apply`;
- the existing Oak Parcel/Dex route remains explicit rather than becoming a generic fallback;
- trusted `push` to `main` path triggering, self-hosted labels, `contents: write`, exact FireRed v1.0 SHA-1 verification, no-ROM-content rule, and test-before-publish sequencing remain in place.

Deterministic evidence:

- probe commit: `0f0dc2f028f204dce4fcaee4e0fff0d9d0afb61e`;
- Local Worker Bridge run: `34598648805` — `success`;
- runner: `firered-mint`;
- `Select explicit task route`: PASS, selected `phase3-title-oak-entry-proof`;
- Lua toolchain: PASS (`Lua 5.1.5`);
- exact private ROM SHA-1 gate: PASS for FireRed US v1.0;
- probe-complete step: PASS and explicitly reported the title/Oak route recognized;
- patch validation/application, focused tests, no-ROM/ROM suites, runtime replay, and publish steps were intentionally skipped because this was a non-gameplay probe;
- repository `Lua tests` workflow run `34598648798` on the same probe commit: `success`.

No gameplay/runtime file was modified by this infrastructure package.

## Independent review — 2026-09-11

Reviewer returned `PASS` on substantive revision `0f0dc2f028f204dce4fcaee4e0fff0d9d0afb61e` in `work/reviews/2026-09-11-local-worker-bridge-task-routing-review.md`.

The review independently confirmed explicit fail-closed title/Oak routing, target validation before patch application, trusted-main-only execution, no public-PR self-hosted trigger, exact FireRed v1.0 ROM verification, test-before-publish ordering, successful non-gameplay probe evidence, and preservation of the previously reviewed Oak revision.

This closes only the execution-substrate prerequisite. It does not close gameplay or change canonical Phase 3 status.

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

`CLOSED — REVIEWED PASS`.

The execution bridge now safely supports `work/tasks/phase3-title-oak-entry-proof.md`. Orchestrator may return that same gameplay task to Worker as `READY_FOR_WORKER` for the already-characterized narrow title-to-Oak seam and deterministic entry evidence.
