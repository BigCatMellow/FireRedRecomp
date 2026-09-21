# Phase 0 public CI proof discovery

- Task: `P0-03-DISCOVERY`.
- Status: `RESEARCH COMPLETE — READY FOR INDEPENDENT REVIEW`.
- Evidence cutoff: 2026-09-21, with live main and local source recovered at
  `ea0960efdb5e790b995067af587b2726d09097a4`.
- Scope: read-only source/public-run audit; only this report and its task change.
  No workflow dispatch, rerun, implementation, ROM access, or phase advancement.

## Result

The first run of the existing public workflow and a current clean-checkout
no-ROM run are independently verified. First-run evidence is no longer an
unknown for the Orchestrator to reconcile after review. Two explicit MAPSL
`P0-03` requirements are still absent from CI: an all-tracked-Lua syntax check
and a documented, executable local-documentation link/check policy. Propose
one small package containing those checks, not a test/runtime refactor.

Local characterization found no Lua syntax failures and no missing destinations
among the currently extracted local Markdown links. There is no evidenced
historical-document cleanup to dispatch. This does not complete P0-03, P0-04,
the save contract, behavior-ledger work, or whole Phase 0.

## Existing requirement → actual evidence

Requirements come from [MAPSL P0-03](../roadmaps/MAPSL_EXECUTION_PLAN.md), not a
new CI standard. The [capability checklist](../roadmaps/CAPABILITY_CHECKLIST.md)
still owns phase status. Exact implementation inspected:
[public workflow at ea0960e](https://github.com/BigCatMellow/FireRedRecomp/blob/ea0960efdb5e790b995067af587b2726d09097a4/.github/workflows/test.yml)
and [test runner at ea0960e](https://github.com/BigCatMellow/FireRedRecomp/blob/ea0960efdb5e790b995067af587b2726d09097a4/scripts/test_all.sh).

| Existing requirement | Actual command / policy | Evidence and remaining boundary |
| --- | --- | --- |
| Clean-checkout public no-ROM tests | `actions/checkout@v4`; `sudo apt-get update && sudo apt-get install -y lua5.1`; `bash scripts/test_all.sh` on `ubuntu-latest` | Run `35549967862`, job `106182752633`, checked out exact `ea0960e`; all steps successful and 149 test files PASS. Hosted-job log initializes an empty repository. This is CI checkout proof, not the separate documented fresh-clone/invalid-ROM acceptance in P0-04. |
| No-ROM-compatible suite | Shell loop executes each `tests/*_test.lua` with `lua5.1`; `set -euo pipefail` stops on failure | Current log explicitly reports no-ROM mode and clean ROM-dependent skips. The 149 count is files invoked, not 149 non-skipped ROM tests or all assertion paths. |
| Lua syntax/static checks | No dedicated command in workflow or scripts | Running test files parses those files and modules actually loaded. It does not establish a gate over every tracked Lua file. Local parse-only characterization passes all 273 tracked Lua files; this is not yet a CI check. No existing lint configuration was found to justify adding style/static-analysis rules beyond syntax. |
| Documentation link/check policy | No checker command, policy, or configuration found in the inspected workflow/scripts and project entry/roadmap documents | Read-only characterization below finds 128 local destinations in 135 tracked Markdown files, with zero missing/untracked targets. These observations do not supply a durable policy or CI gate. |
| ROM checks opt-in; never upload ROM data | Suite selects ROM mode only when `POKEPORT_ROM` is nonempty; replay requires `POKEPORT_RUNTIME_REPLAY=1` | Public workflow supplies neither variable nor a ROM, has only checkout/install/test steps, and has no artifact upload/publish step. Its observed run was no-ROM. No private-runner result, retail-byte parity, or replay is inferred. |
| Green public run / first verified CI evidence | Exact run, job, checkout SHA and terminal result recovered below | Earliest available run is workflow run number 1 at its introduction commit; current run number 291 also passes. Orchestrator may record these specific facts after independent review without declaring Phase 0 complete. |

The public workflow triggers on push and pull request, with `contents: read`.
It has been unchanged since introduction commit
`e511f08f52778b7eda8a9e9886245ca397e07f54`. The separate guarded private-worker
bridge is not a substitute for missing public syntax/docs checks and was not
dispatched or modified in this audit.

## Exact public-run receipts

| Receipt | Exact revision | Job and result |
| --- | --- | --- |
| Earliest available run, workflow number **1**: [32798335573](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/32798335573), created `2026-08-25T01:38:33Z` | `e511f08f52778b7eda8a9e9886245ca397e07f54` | [Job 97654137947](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/32798335573/job/97654137947), `test`, completed `01:38:57Z`, all steps success. Exact SHA appears in checkout log; `01:38:55.5425173Z` reports **117 test files PASS, no-ROM mode**. |
| Earlier handoff receipt, independently reconfirmed: [35511166788](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/35511166788), created `2026-09-20T12:37:52Z` | `03535722f848bb44470f98b41d0fe5bcef34be80` | [Job 106079214901](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/35511166788/job/106079214901), `test`, success. Exact SHA appears in checkout log; `12:38:12.7617774Z` reports **149 test files PASS, no-ROM mode**. |
| Intermediate live-main receipt: [35534429981](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/35534429981), created `2026-09-20T20:05:46Z` | `d7f12003c7930193720fca5fa3dcaa276b60da57` | [Job 106140775061](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/35534429981/job/106140775061), `test`, success. Log reports **149 test files PASS, no-ROM mode**. |
| Current-at-cutoff main receipt, workflow number **291**: [35549967862](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/35549967862), created `2026-09-21T01:09:31Z` | `ea0960efdb5e790b995067af587b2726d09097a4` | [Job 106182752633](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/35549967862/job/106182752633), `test`, completed `01:09:55Z`, all steps success. Log records hosted Ubuntu 24.04, an empty Git repository, and exact checkout SHA; `01:09:54.1293917Z` reports **149 test files PASS, no-ROM mode**. |

The historical workflow file is identical to the current one, and the earliest
run's commit introduces that file. This establishes the first run of this
workflow; it makes no claim about deleted or differently named workflows.
Paginated run metadata reached run number 1. Although `gh run view --log`
returned no text for that old run, the direct job-log API returned 340 lines,
including checkout, explicit ROM skips, and its 117-file terminal PASS. Thus
historical evidence is available; an empty CLI rendering was not treated as a
missing-log blocker or as proof of a pass.

Read-only commands used for metadata/history and actual logs:

```sh
gh api repos/BigCatMellow/FireRedRecomp/commits/main --jq .sha
gh api --paginate 'repos/BigCatMellow/FireRedRecomp/actions/workflows/test.yml/runs?per_page=100' \
  --jq '.workflow_runs[] | [.id,.run_number,.head_sha,.created_at,.conclusion,.status] | @tsv'
gh run view 35549967862 --repo BigCatMellow/FireRedRecomp \
  --json databaseId,headSha,createdAt,conclusion,url,jobs
gh run view 32798335573 --repo BigCatMellow/FireRedRecomp \
  --json databaseId,headSha,createdAt,conclusion,url,jobs
gh api repos/BigCatMellow/FireRedRecomp/actions/jobs/106182752633/logs
gh api repos/BigCatMellow/FireRedRecomp/actions/jobs/97654137947/logs
gh api repos/BigCatMellow/FireRedRecomp/actions/jobs/106079214901/logs
git log --format='%H %aI %s' -- .github/workflows/test.yml
git diff e511f08f52778b7eda8a9e9886245ca397e07f54..ea0960efdb5e790b995067af587b2726d09097a4 \
  -- .github/workflows/test.yml
```

## Read-only local characterization

No runtime/test/workflow file changed relative to the pinned source during
these checks. Full suite results above are actual public CI evidence; this
report does not claim an additional local full-suite run.

### Lua parse coverage

Using the provisioned Lua 5.1 toolchain, the following diagnostic enumerated
tracked Lua files, compiled each without executing it, and returned exit 0:

```sh
PATH=/home/home/.local/share/firered-toolchain/bin:$PATH lua5.1 - <<'LUA'
local p = assert(io.popen("git ls-files -z -- '*.lua'"))
local files = p:read('*a')
p:close()
local count, failed = 0, 0
for path in files:gmatch('[^%z]+') do
  count = count + 1
  local chunk, err = loadfile(path)
  if not chunk then failed = failed + 1; print(path .. ': ' .. tostring(err)) end
end
print(('READ_ONLY_LUA_SYNTAX tracked=%d failed=%d'):format(count, failed))
os.exit(failed == 0 and 0 or 1)
LUA
```

Result: `READ_ONLY_LUA_SYNTAX tracked=273 failed=0`. No missing syntax fix is
known. The missing item is continuous enumeration/enforcement, not a claim
that the currently untested files are broken.

### Documentation baseline and policy gap

A read-only Node diagnostic took the NUL-delimited tracked path list from
`git ls-tree -rz --name-only ea0960efdb5e790b995067af587b2726d09097a4`, selected
the 135 Markdown files, and inspected their unchanged working-tree text.
It skipped fenced blocks, extracted same-line inline link/image destinations
and reference definitions, ignored URI schemes/protocol-relative URLs and
fragment-only links, decoded percent escapes, stripped query/fragment suffixes,
and resolved remaining destinations from the document's directory. Each
resolved file/directory also had to appear in the pinned tracked path set or
contain tracked descendants; an untracked local file could not satisfy it.

| Characterization count | Result |
| --- | ---: |
| Tracked Markdown files | 135 |
| Extracted local destinations | 128 |
| External destinations excluded | 8 |
| Fragment-only destinations excluded | 0 |
| Missing filesystem targets | 0 |
| Targets absent from pinned tracked tree | 0 |

This diagnostic is candidate extraction, not a full Markdown parser, external
link audit, heading-anchor validation, prose-truth check, or durable repository
test. No multiline target/reference-definition/HTML-link forms were found by
the supplemental source search. Existing backticked file names and illustrative
shell paths are not Markdown links and were not treated as broken links.
Source search for checker/linter/syntax policy in `.github`, `scripts`, root
entry documents and the inspected roadmaps found only MAPSL's requirement.
Therefore a policy is missing even though the characterized links resolve.

## One proposed successor: public syntax and local-doc checks

This is a proposal for Orchestrator dispatch **after independent discovery
review**, not implementation authority granted by this report. Suggested task
ID: `P0-03-CHECKS`. Reuse installed Lua 5.1 and Git; no dependency installation,
new service, permission change, branch rule, or private runner is needed.

Exact implementation surface (four files):

1. `.github/workflows/test.yml`: add a named read-only repository-check step
   after Lua installation and before the unchanged no-ROM suite.
2. `scripts/check_repository.lua`: parse every tracked `*.lua` with Lua 5.1
   without executing chunks, and check tracked Markdown local destinations
   under the explicit policy below. Fail nonzero with the offending path/link.
3. `tests/repository_checks_test.lua`: synthetic focused checks for valid and
   invalid Lua, parse-without-execution, valid/missing/untracked local targets,
   document-relative resolution, and the documented excluded link forms.
   The existing suite glob automatically runs this file.
4. `README.md`: document the two commands, check scope and exclusions in the
   verification section. No unrelated status/formatting/history rewrite.

Proposed documentation policy is a deliberately bounded file-target check:
all tracked Markdown files; inline Markdown links/images and reference
destinations outside code; local relative targets resolved from their document;
percent escapes decoded and query/fragment suffixes removed for file lookup;
target must be a tracked file or a repository directory containing tracked
files. Exclude external schemes/protocol-relative URLs, fragment-only links,
bare/code-formatted paths and raw HTML. Do not fetch the network, validate
heading anchors, or introduce stylistic/prose lint rules. Document these limits
instead of describing the checker as complete Markdown validation.

Exact public commands after implementation:

```sh
lua5.1 scripts/check_repository.lua
bash scripts/test_all.sh
```

Focused local command: `lua5.1 tests/repository_checks_test.lua`.
Acceptance is a successful clean-checkout public run at the exact successor
revision showing the new named syntax/docs step and the unchanged no-ROM suite;
deterministic synthetic tests must also demonstrate that malformed Lua and
missing/untracked local targets fail and that documented exclusions do not
perform network access or execute Lua chunks. Coverage counts must come from
the tracked tree, not hardcoded 273/135 baselines. Preserve ROM opt-in behavior,
read-only workflow permission, no-upload boundary, and existing runtime/tests.
Independent review then checks the exact revision before P0-03 reconciliation.

Known failures requiring edits today: **none** among 273 Lua parses and the
128 characterized local link targets. Known missing enforcement: the two checks
above. If implementation discovers unsupported Markdown syntax or a real
tracked-link defect beyond these four files, report it and obtain a narrowed
allowlist correction rather than silently expanding into historical cleanup.
The private ROM runner being offline does not block this proposed package.

## Handoff and limitations

Reviewer should independently recover the pinned source, earliest/current job
logs and local syntax/docs characterization, then judge only this discovery's
criteria. Orchestrator owns commits/publication during parallel work and all
coordination/capability updates. No first-run receipt should be misreported as
already containing the newly proposed syntax/docs gates. Phase 0 remains
`IN PROGRESS`; P0-04 and its other prerequisites remain separate.
