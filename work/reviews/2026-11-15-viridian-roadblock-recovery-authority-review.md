# Viridian C0 roadblock recovery authority — independent review

Verdict: **PASS**. This is a bounded authority for one byte-identical recovery
request, with no current request, code or bridge-artifact authorization.

- Reviewed revision: `938a1ff116c413fb552df24d73c4c45d0d9bc2d7`.
- Contract: [P5-06-VIRIDIAN-ROADBLOCK-RECOVERY](../tasks/phase5-viridian-roadblock-recovery.md).
- Adopted record: [guarded outcome review](2026-11-15-viridian-roadblock-guarded-outcome-review.md) (BLOCK).

I reviewed this contract from independent context and authored only this review
file. I did not write the contract, the outcome review, the package or either
request. I did not read a ROM, run LÖVE, merge or comment. Git use was
read-only apart from committing this file.

## Request identity and route

- The sole permitted artifact is
  `work/local-runner/requests/phase5-viridian-roadblock-recovery-20261115.patch`
  (contract line 79). Its basename matches the `phase5-viridian-roadblock*.patch`
  selector (workflow lines 140–141), so it gets the existing route.
- The canonical request on `main`
  (`2450e158095a531f81abe834c93c008e5232cc57`) is blob `69c27034…` with SHA-256
  `c16e2c2439abdc7aebf4f1f46a260fb44c769b6c3f2c7867469a7c1fa5b33197`. I
  recomputed this, and it matches contract line 39.
- The workflow blob is `87a4a6bb6bc68197cbb2920829256c45969c1763` at `main`,
  `2450e15` and the reviewed revision. The PR does not touch the workflow or
  the canonical request.
- The canonical patch's nine `+++ b/` targets equal the nine contract paths and
  the route allowlist (workflow line 274). The replay case is at lines 570–571.
- `git apply --check` of the canonical patch succeeds against current `main`.
- `git diff --check origin/main 938a1ff` is clean.

## Inheritance and prerequisites

- Items 1–13, the nine paths, the workflow and the route are inherited with no
  change (contract lines 87–92 and 103–106). Diagnostic receipts from run
  `41273209685` are excluded as substitutes (lines 90–92).
- The outcome review's recovery prerequisites 1–5 are each addressed:
  1. The operator environment fix and an accepted version are recorded:
     LÖVE 11.5, which matches `conf.lua` `t.version = "11.5"` (lines 48–60).
  2. The contract is a new bounded request, not a retry. It cites the BLOCK and
     run/job `41273209685`/`124750051396` (lines 13–19 and 25–29).
  3. It names a new literal filename, pins its digest, and states the rebase
     rule: stop if the patch no longer applies (lines 99–102).
  4. The fresh pre-dispatch checks cover runner online/idle, no queued or
     running job, unchanged workflow blob and route, `git apply --check`,
     unchanged prerequisites, and fresh `love` resolution. Any failure stops
     dispatch (lines 115–126).
  5. A complete steps 2–15 job and a separate item-13 outcome review are
     required (lines 129–136).
- The stop conditions are complete, and there is no further retry: any later
  attempt needs new operator authority and a new reviewed contract
  (lines 147–158).
- Operator authorization is quoted verbatim and scoped to this one request. It
  does not waive review or checks (lines 62–69).

## Adopted outcome review

- The adopted outcome review is byte-identical to the orchestrator-supplied
  original (SHA-256 `f58e4d0a…cc2c6b`).
- It contains no private user path, ROM filename, ROM bytes, credential or log
  body. It cites only the public ROM SHA-1 and a game/version label, both
  already present in workflow and contract text.

## Independent environment check (informational)

On host `MediaCenter`, as the runner service user, I checked:

- `love --version` reports `LOVE 11.5`.
- Under the actions-runner PATH file, `love`, `xvfb-run`, `timeout` and
  `mktemp` all resolve to system paths.
- The runner service is active.

This corroborates the operator attestation. It does not replace the fresh
pre-dispatch confirmation.

## Advisories (non-blocking)

1. Prerequisite 1 asked for literal `command -v` output per tool and literal
   `love --version` output. Contract lines 52–57 summarize these instead. My
   check above covers the gap. The pre-dispatch confirmation may record the
   literals.
2. "Steps 2–15" (line 129) includes step 7, `Probe complete`, which is skipped
   by design in patch mode. The enumerated list correctly omits it. The outcome
   reviewer should read "succeed" as "succeed or skip by mode" for step 7 only.
3. Package path 9 (`work/tasks/phase5-viridian-roadblock-implementation.md`)
   is a patch target. Any coordination edit to it on `main` before dispatch
   will break `git apply --check` and trigger the stop rule. Keep it unchanged
   until the run.

No request, probe or patch is authorized until this PASS is adopted and the
fresh pre-dispatch checks pass immediately before publication.
