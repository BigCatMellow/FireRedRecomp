# Task: enforce Lua syntax and local documentation targets in public CI

- Task ID: `P0-03-CHECKS`
- Status: `CLOSED — REVIEWED PASS`
- Type: `IMPLEMENTATION / REPRODUCIBILITY`
- Parent capability gate: Phase 0 reproducibility, MAPSL `P0-03`.
- Assigned role: `WORKER`; independent reviewer: separate `REVIEWER` helper.
- Prerequisites: independent PASS for `P0-03-DISCOVERY` at `b5b317b`.
- Risk: `LOW` — read-only development checks; false positives could block CI.

## Goal and source of truth

Add the two missing checks established by the
[CI discovery](../reports/phase0-ci-proof.md): parse all tracked Lua files and
validate local Markdown file targets under an explicit bounded policy.
The existing public workflow and no-ROM test runner remain the baseline.
This does not introduce new runtime, style, external-link or security policy.
Discovery `b5b317b` has
[independent PASS](../reviews/2026-09-20-ci-proof-discovery-review.md).
Worker authority is limited to this package; no phase closure is implied.

## MAY CHANGE

1. `.github/workflows/test.yml` — one named repository-check step after Lua installation and before the unchanged no-ROM suite.
2. `scripts/check_repository.lua` — read-only tracked Lua syntax and local Markdown destination checker, using existing Lua 5.1 and Git.
3. `tests/repository_checks_test.lua` — synthetic focused positive/negative coverage of the checker.
4. `README.md` — verification commands and precise checker policy/exclusions only.
5. This task — exact Worker evidence and handoff.

## MUST NOT CHANGE

Runtime, existing tests/test runner, private workflow/bridge, dependencies,
workflow triggers/permissions, ROM opt-in behavior, branch settings, phase
status, save/inventory artifacts or unrelated documentation. No new network
requests in the checker, external services, artifact uploads, broad cleanup,
ROM content or generated assets. Do not rewrite historical prose or silently
add files to fix discovered link defects outside this allowlist.

## Acceptance criteria

1. `lua5.1 scripts/check_repository.lua` parses every tracked `*.lua` without executing its chunks and exits nonzero with an actionable path on syntax failure. Enumerate the tracked tree dynamically, not a hardcoded baseline count. Failure to enumerate/read the required inputs must not produce a green result.
2. Check all tracked Markdown documents for inline link/image destinations and reference destinations outside code. Resolve local relative targets from the document directory, decode percent escapes, and remove query/fragment suffixes for file lookup. A target must be a tracked file or a repository directory with tracked descendants; an untracked local file cannot satisfy it.
3. State and test the bounded policy: exclude external schemes/protocol-relative URLs, fragment-only links, bare/code-formatted paths and raw HTML. No network fetches, heading-anchor validation, prose/style lint or claim of complete Markdown validation. If actual repository link forms cannot be covered by the stated policy, record the gap before widening it.
4. Synthetic focused tests prove valid/invalid Lua, parse without execution, valid/missing/untracked local targets, document-relative paths and directories, encoded paths/query/fragment handling, and the documented exclusions. Do not depend on user files or network access; temporary fixtures must be isolated.
5. The public workflow runs the new named check step and the unchanged no-ROM suite with existing read-only permission and no uploads. README gives both commands and their prerequisites/limits without unrelated edits.
6. Focused tests, repository checks and the full no-ROM suite pass. An exact published-revision clean-checkout public run must show both check steps passing; this is required evidence, not inferred from local success.
7. Independent review checks the exact diff, meaningful failure coverage, policy accuracy, public receipt and legal/scope boundaries before P0-03 reconciliation. No whole Phase 0 completion follows.

## Required evidence

- Baseline: 273 tracked Lua parses and existing 149-file public no-ROM suite at discovery source `ea0960e`; rerun the full current no-ROM suite before implementation. Current counts may grow through separate reviewed work.
- Focused: `lua5.1 tests/repository_checks_test.lua`.
- Repository: `lua5.1 scripts/check_repository.lua`.
- Full: `env -u POKEPORT_ROM bash scripts/test_all.sh`.
- Exact changed-path audit, public workflow run/job/checkout SHA, and independent review.
- No ROM or runtime replay required: development checks do not change runtime or imported-data behavior.

## Stop / escalate when

The existing tracked tree has a real defect outside the literal allowlist,
implementation needs a new dependency/permission/network access, or policy
coverage cannot be stated accurately. Record the smallest correction; do not
weaken failure checks or silently expand into historical cleanup.

## Completion and handoff

Worker commits only these five paths and reports exact local evidence. Parent
Orchestrator coordinates publication and retrieves the normal push-triggered
public run; no manual workflow rerun/dispatch is needed. Reviewer returns
PASS / NEEDS_FIX / BLOCK. Orchestrator then reconciles only the P0-03 gate and
selects the remaining clean-clone proof or other evidenced Phase 0 leaf.
Parallel save work is disjoint; allow its in-flight files to be committed
before interpreting a shared-tree checker result as an exact-revision receipt.

## Worker handoff — 2026-09-21

Implemented only the five literal allowed paths. Dispatch/base recovery was
`6181171a9ce13bd2a4075198f25b41a56645863c`; parent-only coordination commits
advanced the shared checkout to `12c5d8ee3d5107f42118de5f7fc7acbd285c0755`
before this package was staged. No runtime, existing test, test-runner, private
workflow, dependency, trigger, permission, upload or ROM-policy changes belong
to this package.

The new checker uses NUL-delimited Git tracked-file enumeration, with an
explicit success trailer because Lua 5.1 pipe close does not reliably convey
the child's exit status. Enumeration/read failures cannot yield an empty PASS.
Lua chunks are compiled, never invoked. Markdown file-target checks implement
the documented bounded policy; existing-but-untracked targets fail. Focused
fixtures are entirely in memory and make no shell/network/user-file requests.

Evidence (toolchain `PATH=/home/home/.local/share/firered-toolchain/bin:$PATH`):

- Pre-implementation baseline at `6181171`: 149-file no-ROM suite PASS.
- `lua5.1 tests/repository_checks_test.lua`: **47 passed, 0 failed**. Coverage
  includes syntax errors, non-execution, Git/read failures, missing/untracked
  targets, relative directories, percent/query/fragment handling and exclusions.
  Four added assertions first failed the draft and then passed: linked-image
  destinations, missing linked images, reference titles and quoted HTML angles.
- `lua5.1 scripts/check_repository.lua`, with the new files tracked:
  **275 tracked Lua, 144 tracked Markdown, 166 local targets — PASS**. Counts
  are observations, not hardcoded acceptance values.
- An actual command invocation outside a Git repository returned exit 1 with
  `Git tracked-file enumeration failed`; no empty success was accepted.
- `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY bash scripts/test_all.sh`:
  **150 test files PASS** in an isolated snapshot of the exact staged tree.
  The snapshot was populated with `git checkout-index`, indexed in its own
  temporary Git repository, and its tree hash matched the source index.
- `git diff --cached --check` and the exact five-path staged audit pass.

The first full-suite attempt in the shared working tree encountered five
expected red-phase rollover assertions in the parallel Worker's unstaged save
tests (88 passed, 5 failed at the codec file). Those files were neither altered
nor staged by this Worker. The clean index snapshot excludes those unfinished
changes and preserves the last committed save implementation; it is the local
full-suite receipt for this package. This is not a claim that parallel rollover
work passed or was incorporated here.

Parent Orchestrator must publish this exact bounded commit and attach the normal
push-triggered clean-checkout public run/job/SHA showing both the named
repository check and no-ROM suite passing. That public receipt and independent
exact-revision review are still pending; local PASS does not close P0-03,
P0-04, Phase 0, or any private-ROM gate. No workflow was manually dispatched or
rerun, and no push was performed by this Worker.

## Orchestrator reconciliation — 2026-09-23

Exact implementation `3478822` independently
[passed review](../reviews/2026-09-21-ci-repository-checks-review.md). Public
run `35624624210` / job `106415819660` verified the named repository check and
unchanged no-ROM suite from a clean checkout. Close only this P0-03 enforcement
package; clean-clone proof, ledger audit, save rollover review and Phase 0
remain separate.
