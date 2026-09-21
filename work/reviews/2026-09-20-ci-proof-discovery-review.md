# P0-03-DISCOVERY independent review

- Disposition: `PASS` — exact public-CI discovery and bounded successor proposal.
- Research revision: `b5b317bc9098214cd08b8b22205fff600fef5a84`.
- Parent: `2686e44ecc682098606eb64715f38ac1a0afcc21`.
- Report source/evidence cutoff: `ea0960efdb5e790b995067af587b2726d09097a4`, 2026-09-21.
- Resumed review relay: `3a6443f2d0a1a9406464d28a3ddbca4c17c332e6`; parallel discovery remained `READY_FOR_REVIEWER` for the exact research revision.
- Final review completed 2026-09-21; the report path retains the assigned date for continuity.
- Scope: the two task/report text artifacts only. Concurrent uncommitted save-contract work was not treated as the pinned CI baseline or changed by this review.

## Findings against existing requirements

The proposed gaps come directly from MAPSL `P0-03`: clean-checkout no-ROM
tests, Lua syntax/static checks, and a documentation link/check policy, with ROM
checks opt-in and no ROM uploads. The report does not invent a general lint,
formatting, branch-protection, external-link, or security-hardening program.

At the pinned cutoff, the public workflow contains checkout, Lua 5.1
installation, and `bash scripts/test_all.sh` on a hosted Ubuntu runner. It
triggers on push/pull request with `contents: read`; it supplies no ROM/replay
environment and has no artifact-upload step. The shell runner executes each
test file with failure propagation. Its observed no-ROM PASS counts test files,
including clean opt-in skips, not executed ROM assertions. The report correctly
limits fresh hosted-checkout evidence and does not substitute it for all of
P0-04's documented clean-clone/invalid-ROM acceptance.

No separate all-tracked-Lua parse gate or executable documentation-target policy
is present in the inspected workflow/scripts and relevant entry/roadmap
documents. Executing tests cannot establish parsing of every tracked Lua file.
The proposed parse-only gate and bounded local-target checker therefore address
the evidenced missing requirements. No existing lint configuration establishes
an additional style/static-analysis requirement for this package.

## Independently recovered public receipts

The run/job APIs and actual job logs independently confirmed:

| Receipt | Checkout and observed evidence |
| --- | --- |
| [Run 32798335573](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/32798335573), job `97654137947` | Workflow run number 1, push at `e511f08f52778b7eda8a9e9886245ca397e07f54`, created `2026-08-25T01:38:33Z`; every job step succeeded. Direct job logs show an empty repository initialization, exact checkout SHA, ROM skips, and 117-file no-ROM PASS at `01:38:55.5425173Z`. |
| [Run 35549967862](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/35549967862), job `106182752633` | Current at the report cutoff, workflow number 291, push at exact `ea0960e`, created `2026-09-21T01:09:31Z`; every job step succeeded. Hosted Ubuntu 24.04 logs show an empty repository initialization, exact checkout SHA, ROM skips, and 149-file no-ROM PASS at `01:09:54.1293917Z`. |
| [Run 35511166788](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/35511166788), job `106079214901` | Exact `03535722f848bb44470f98b41d0fe5bcef34be80`; successful metadata and checkout log; 149-file no-ROM PASS at `2026-09-20T12:38:12.7617774Z`. |
| [Run 35534429981](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/35534429981), job `106140775061` | Exact `d7f12003c7930193720fca5fa3dcaa276b60da57`; successful metadata and checkout log; 149-file no-ROM PASS at `2026-09-20T20:06:06.2745964Z`. |

History independently shows that `e511f08f` introduced the public workflow,
which was absent in its parent and unchanged through `ea0960e`. Together with
run number 1 and retained logs, this supports the report's earliest-available
first-run receipt for this workflow. It does not establish the history of
deleted or differently named workflows. Later main revisions do not invalidate
the explicitly pinned current-at-cutoff receipt.

## Independent pinned-source characterization

Checks read the tracked tree and file contents from `ea0960e` Git objects,
avoiding concurrent working-tree edits:

- All 273 tracked Lua files passed Lua 5.1 parse-only compilation without
  executing their chunks.
- An independently implemented bounded Markdown extraction reproduced 135
  tracked Markdown files, 128 local destinations, eight excluded external
  destinations, and zero fragment-only destinations.
- Every extracted local destination resolved to a pinned tracked file or a
  directory containing pinned tracked descendants; none was missing from the
  checkout. An untracked file could not satisfy this check.
- The exact research diff contains only its two authorized text paths and
  passes `git diff --check`.

This confirms the stated characterization, not a complete Markdown parser or
external/heading/prose audit. The report accurately states that a clean local
snapshot does not supply an executable policy or ongoing CI enforcement.
No new local full-suite result is claimed or needed for this report-only
review; the public suite receipts above were independently recovered.

## Exact next allowance

Orchestrator may accept these specific first/current CI facts and compile one
`P0-03-CHECKS` successor using the proposed four-file boundary: the public
workflow, `scripts/check_repository.lua`, `tests/repository_checks_test.lua`,
and the README verification section. The proposed commands, tracked-tree scope,
read-only parsing, local-target rules/exclusions, negative synthetic fixtures,
and exact-revision public-run acceptance are concrete and consistent with the
existing requirement. No current syntax/link defect justifies extra cleanup.

The successor must preserve the existing no-ROM suite, ROM opt-in/no-upload
boundary, and workflow permissions. It must not fetch links or execute parsed
Lua chunks. A real defect or unsupported syntax outside that four-file surface
requires a narrowed task correction rather than unrelated historical edits.
Counts are observations, not values to hardcode as future coverage targets.

This PASS accepts discovery only: it does not claim the proposed checks already
exist, close P0-03/P0-04 or Phase 0, alter save policy, or clear the private-runner
blocker. Those gates still require their own exact implementation and evidence.
Reviewer wrote only this review; no workflow was dispatched/rerun and no
implementation, coordination, commit, push, private-ROM access, or upload occurred.
