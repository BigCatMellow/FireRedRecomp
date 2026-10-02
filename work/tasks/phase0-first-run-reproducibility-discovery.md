# Task: discover the minimum first-run reproducibility repair

- Task ID: `P0-04-DISCOVERY`
- Status: `READY_FOR_WORKER`
- Type: `RESEARCH / READ-ONLY REPRODUCIBILITY DISCOVERY`
- Parent gate: Phase 0 clean-clone evidence block at `d0e0bad`.
- Risk: `LOW` — report only; it must not silently repair or broaden support.

## Goal and source of truth

Identify the smallest supported contract that could resolve the independently
reviewed clean-clone block: absent first-run guide, default-PATH tool discovery,
and unverified isolated desktop/refusal evidence. Use the current README,
scripts, workflows, package/tool declarations, clean-clone report/review and
existing test entry points. Describe observations, not a new platform promise.

## MAY CHANGE

1. `work/reports/phase0-first-run-reproducibility-discovery.md`.
2. This task's evidence/handoff section.

## MUST NOT CHANGE

Runtime, tests, workflows, README/docs, dependency manifests, user settings,
packages, toolchains, desktop session, runner configuration, ROM policy or
canonical phase status. Do not install tools, download dependencies, copy a
ROM, use a private ROM path, patch documentation, or retry the clean-clone
claim as if a repair had occurred.

## Acceptance criteria

1. Map each P0-04 blocker to exact current documentation, command, tool and
desktop evidence, distinguishing missing evidence from a demonstrated defect.
2. Propose one smallest later repair surface and supported-host assumption;
separate required documentation, tool-discovery/bootstrap and desktop-proof
work. Do not assume universal OS/package-manager support.
3. Define a clean re-verification matrix for no-ROM CLI, missing/invalid ROM
refusal and desktop first-run, with aggregate-only evidence and no private data.
4. State whether the existing public CI can cover each check and what must stay
clean-target/local. Preserve the user-owned/private-ROM boundary.
5. Recommend at most one bounded follow-up contract; independent review must
PASS before any repair task is created.

## Stop / escalate when

The smallest repair requires a product support decision, credentials, a valid
ROM, destructive host change, or undocumented package source. Record the
decision/blocker; do not select a platform or modify the environment.

## Completion and handoff

Researcher publishes only this task/report. A separate Reviewer returns PASS /
NEEDS_FIX / BLOCK. Only reviewed PASS may permit one narrow repair and then a
fresh P0-04 verification; Phase 0 remains open.

## Research evidence and handoff — 2026-10-02

Discovery complete at public/inspection pin
`1a7c9958ab4ba42a8efac1fab42a8913e97acf36`; independent exact-review required.
The [report](../reports/phase0-first-run-reproducibility-discovery.md) maps all
three accepted P0-04 blockers and proposes only one documentation-only successor
(`README.md` and `docs/FIRST_RUN.md`), conditional on a declared already
provisioned target rather than a new platform/bootstrap promise.

Read-only inspection confirmed that the relevant README/runtime/importer/test
runner/replay/public-CI owners are unchanged since observed clone `7a2e7ad`.
Default PATH still lacks Lua/LÖVE; the suite already fails clearly for absent
`lua5.1`. Standalone invalid-input verification also needs `sha1sum`. The
built-in screenshot hook does not cover normal no-ROM/status-only first-run,
and the existing runtime replay requires a valid ROM. A present DISPLAY
variable is not display proof; no GUI retry or root-cause claim was made.

The report separates required documentation, prerequisite/tool discovery,
conditional host-support decisions and later desktop observation, with a fresh
CLI/refusal/desktop/isolation matrix and explicit current-CI limits. Existing
151-file evidence is preserved, not rerun or relabeled as repair acceptance.
No installs/downloads, persistent environment/session changes, ROM access,
runtime/tests/workflow/docs repairs or phase advancement occurred. Only this
handoff and report may be published; parent owns review and later task creation.

Authored-package validation, using the pre-existing Lua interpreter by explicit
path without changing PATH, passed: 276 Lua / 171 Markdown / 484 local targets;
zero checker errors and clean whitespace. This checks the text package, not
clean-target or desktop behavior.
