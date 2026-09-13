# Local Worker Bridge

- Record role: `FLOW SUPPORT`
- Primary information class: `PROCEDURE / EXECUTION SUBSTRATE`
- Status: `ACTIVE`
- Lifecycle: `ACTIVE`
- Authority: execution mechanism only; never widens the active task contract
- Workflow: `.github/workflows/local-worker-bridge.yml`
- Runner: repository-level self-hosted Linux runner labeled `firered-local`

## Purpose

The scheduled ChatGPT Worker may not have a writable repository checkout. For a task-bounded change that is unsafe to perform through whole-file GitHub replacement, Worker may publish a unified diff request under:

`work/local-runner/requests/<task-id>-<timestamp>.patch`

A trusted main-branch push then dispatches the guarded workflow to the private local runner.

The task identifier in the request/probe filename is an explicit route selector. The workflow maps only known identifiers to hard-coded target, focused-test, replay, and publish surfaces. Unknown identifiers fail closed before patch application.

## Explicit routes

Current supported request/probe prefixes are:

- `oak-parcel-dex-presentation-north...` — retained for the already-completed bounded Oak Parcel/Dex route;
- `phase3-title-oak-entry-proof...` — bounded Phase 3 title/new-game → Oak/identity → bedroom entry route;
- `runner-online...probe` — non-patch runner-readiness probe only.

Adding a new route requires a bounded task that authorizes bridge maintenance. Do not add a generic fallback route.

## Security boundary

- The workflow is `push` to `main` only. It does not run for `pull_request` or `pull_request_target`.
- It accepts exactly one changed bridge request/probe in the triggering commit.
- Every patch route has an explicit hard-coded target allowlist tied to its task identifier.
- Unknown task identifiers or unauthorized targets fail before `git apply`.
- `git apply --check` and `git diff --check` must pass before tests.
- The private ROM is never committed or uploaded.
- The runner locates the local ROM privately and verifies SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc` before ROM-backed execution.
- A ROM mismatch fails closed.
- Patch routes publish implementation changes only after the route-specific focused test, full no-ROM suite, full verified-ROM suite, and route-specific runtime replay pass.
- Publish staging is route-specific and explicit; unauthorized files are not staged by the bridge.
- A failing patch/test leaves the implementation unpublished; the patch request remains durable evidence for diagnosis.

## Worker procedure

When `STATE.json` is `READY_FOR_WORKER` and the task requires a large-file patch:

1. Recover live state and read the active task normally.
2. Inspect only the exact code regions needed to construct a minimal unified diff.
3. Confirm an explicit bridge route exists for the active task. If it does not, stop rather than using another task's route.
4. Ensure every patch target is inside both the active task MAY CHANGE boundary and that route's hard-coded allowlist.
5. Create one `.patch` request under `work/local-runner/requests/` on `main`, with the exact task route prefix in the filename.
6. Read the resulting `Local Worker Bridge` workflow run and job steps.
7. If the run fails, record the exact failed step/log evidence and stop rather than widening scope.
8. If the run succeeds, recover the implementation commit produced by the workflow, record exact test evidence and revision, set coordination state to `READY_FOR_REVIEWER`, and update `HANDOFF.md` last.

## Validation probes

A `.probe` uses the same explicit filename route selection without applying a patch. It verifies that the route is recognized and that the guarded self-hosted substrate, Lua toolchain, repository checkout, and exact private-ROM hash gate remain available.

A route probe does not authorize or prove gameplay behavior. It is execution-substrate evidence only.

## Current verified substrate

Probe commit `8c0ed45123c1cb3e34f8d9f7398308c0deec2985` produced Local Worker Bridge run `34543172371` on runner `firered-mint` with labels `self-hosted`, `linux`, `x64`, `firered-local`.

That original probe passed repository checkout, Lua toolchain, and private FireRed US v1.0 SHA-1 verification. No implementation patch was applied during the probe.
