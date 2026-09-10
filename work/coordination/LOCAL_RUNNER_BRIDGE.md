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

`work/local-runner/requests/<timestamp-or-task>.patch`

A trusted main-branch push then dispatches the guarded workflow to the private local runner.

## Security boundary

- The workflow is `push` to `main` only. It does not run for `pull_request`.
- It accepts exactly one changed bridge request/probe in the triggering commit.
- Patch targets are explicitly allowlisted for the currently active Oak Parcel/Dex task.
- `git apply --check` and `git diff --check` must pass before tests.
- The private ROM is never committed or uploaded.
- The runner locates the local ROM privately and verifies SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc` before ROM-backed execution.
- A ROM mismatch fails closed.
- The workflow publishes implementation changes only after focused, no-ROM, verified-ROM, and runtime-replay commands pass.
- A failing patch/test leaves the implementation unpublished; the patch request remains durable evidence for diagnosis.

## Worker procedure

When `STATE.json` is `READY_FOR_WORKER` and the task requires a large-file patch:

1. Recover live state and read the active task normally.
2. Inspect only the exact code regions needed to construct a minimal unified diff.
3. Ensure every patch target is inside the active task MAY CHANGE boundary and the bridge allowlist.
4. Create one `.patch` request under `work/local-runner/requests/` on `main`.
5. Read the resulting `Local Worker Bridge` workflow run and job steps.
6. If the run fails, record the exact failed step/log evidence and stop rather than widening scope.
7. If the run succeeds, recover the implementation commit produced by the workflow, record exact test evidence and revision, set coordination state to `READY_FOR_REVIEWER`, and update `HANDOFF.md` last.

## Current verified substrate

Probe commit `8c0ed45123c1cb3e34f8d9f7398308c0deec2985` produced Local Worker Bridge run `34543172371` on runner `firered-mint` with labels `self-hosted`, `linux`, `x64`, `firered-local`.

The probe passed repository checkout, Lua toolchain, and private FireRed US v1.0 SHA-1 verification. No implementation patch was applied during the probe.
