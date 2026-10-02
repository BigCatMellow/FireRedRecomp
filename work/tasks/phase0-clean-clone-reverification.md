# Task: reverify documented first-run on a fresh checkout

- Task ID: `P0-04-REVERIFY`
- Status: `BLOCKED — REVIEWED EVIDENCE`
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

## Worker evidence and handoff — 2026-10-02

Result: **BLOCK — missing documented prerequisites**, not CLI/refusal/desktop
PASS. The [aggregate report](../reports/phase0-clean-clone-reverification.md)
records a new public HTTPS clone detached at exact
`6dcb2e609a702d0d02b2547dc133b594800b87b6`, with unchanged reviewed README and
FIRST_RUN documentation and clean tracked/untracked/ignored final state.

The guide's exact CLI preflight exits 127 with `Missing prerequisite: lua5.1`;
the separate `love --version` command also exits 127 because LÖVE is absent.
Git 2.43.0, Bash 5.2.21 and `sha1sum` 9.4 are available on Linux Mint
22.2/x86_64. No isolated wrapper or alternate tool path was injected.

Repository checker, full suite, missing/invalid-input refusals and every
desktop observation are explicitly **NOT RUN** after the prerequisite stop.
No valid ROM, synthetic fixture, application launch, display injection,
installation, environment repair or phase change occurred. Historical CLI
results are retained at their original pin, not relabeled as new evidence.

Publish only this handoff and report for independent exact review. Parent owns
blocker reconciliation and any separately authorized target/preparation choice;
this retry does not supply clean-target or Phase 0 completion evidence.

## Review

Exact `93c4654` passed [independent review](../reviews/2026-10-02-clean-clone-reverification-review.md)
as an accurate BLOCK. The fresh target lacked both `lua5.1` and LÖVE; no wrapper,
PATH change, installation or dependent check occurred. A separate preparation
decision is required before another retry.
