# Task: reverify documented first-run on a fresh checkout

- Task ID: `P0-04-REVERIFY`
- Status: `READY_FOR_WORKER`
- Type: `VERIFICATION / CLEAN CHECKOUT`
- Prerequisites: P0-04 evidence block and [P0-04-DOCS PASS](../reviews/2026-10-02-first-run-documentation-repair-review.md), exact `d4f7fe8`.

## Goal

On a new disposable clone of current public main, follow `README.md` and
`docs/FIRST_RUN.md` exactly under the documented conditional already-provisioned
Linux profile. Verify no-ROM CLI checks and synthetic missing/invalid-ROM
refusals, and attempt the explicitly separate desktop observation only when a
usable clean display is available.

## MAY CHANGE

1. `work/reports/phase0-clean-clone-reverification.md`.
2. This task's evidence/handoff section.

## MUST NOT CHANGE

Repository/runtime/docs/tests/workflows, dependencies, tools, desktop/session,
ROM policy, user settings or canonical status. Do not install, repair, copy a
ROM, reveal private paths, inject a display, or treat process launch as visible
desktop proof.

## Acceptance

Record exact clone/revision/profile, README/FIRST_RUN command outcomes, clean
no-ROM checker/suite, safe missing/invalid refusal results, and desktop outcome
with its evidence limitation. A desktop-unavailable result is an explicit BLOCK,
not a workaround. Independently review the exact report before reconciling P0.

## Handoff

This retry may close only the documentation/tool-discovery portion of P0-04.
Phase 0 remains open unless all canonical clean-target and save-safety gates are
independently evidenced.
