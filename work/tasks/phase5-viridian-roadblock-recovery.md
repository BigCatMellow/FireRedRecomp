# Task: recover one Viridian C0 roadblock guarded request

- Task ID: `P5-06-VIRIDIAN-ROADBLOCK-RECOVERY`
- Status: `READY_FOR_REVIEWER` — needs independent authority review. This file
  and the adopted [guarded outcome review](../reviews/2026-11-15-viridian-roadblock-guarded-outcome-review.md)
  both await independent review; no artifact is authorized yet.
- Type: `RECONCILIATION / GUARDED ROUTE RECOVERY`
- Parent capability gate: P5-06 bounded C0 roadblock implementation; no
  behavior acceptance, capability-status, or Phase 5/7 change
- Assigned role: `ORCHESTRATOR`
- Independent reviewer: `REVIEWER` — fresh context, no shared editing of this
  task, the original request, or the nine-path package
- Prerequisites: [P5-06 implementation authority](phase5-viridian-roadblock-implementation.md)
  adopted; its sole request PR #57 `f5582ff`, merged as
  `2450e158095a531f81abe834c93c008e5232cc57`, failed in run `41273209685` /
  job `124750051396` at step 14 (`love is required`, exit 127); independent
  [outcome review](../reviews/2026-11-15-viridian-roadblock-guarded-outcome-review.md)
  is **BLOCK** with root cause runner environment, package not implicated;
  operator environment fix and operator authorization recorded below.
- Risk: `HIGH` — inherits the original authority's risk; a false recovery
  claim could publish an unreviewed package or mask a package defect.

## Goal

Authorize exactly one new guarded request carrying the byte-identical,
already-reviewed nine-path package, so that the guarded job can run to
completion now that LÖVE is installed on the runner. This is a new bounded
request, not a retry or amendment of `f5582ff` or run `41273209685`. It adds
no behavior, path, route, or evidence requirement.

## Source of truth

- [P5-06 implementation authority](phase5-viridian-roadblock-implementation.md):
  the nine paths, behavior items 1–12, evidence, exclusions, and item 13.
- [Guarded outcome review](../reviews/2026-11-15-viridian-roadblock-guarded-outcome-review.md):
  BLOCK verdict, root cause, and recovery prerequisites 1–5.
- `work/local-runner/requests/phase5-viridian-roadblock-20261018.patch`
  (blob `69c270346c7cdbdc204f40d61fb2e18899343ab4`): canonical request,
  SHA-256 `c16e2c2439abdc7aebf4f1f46a260fb44c769b6c3f2c7867469a7c1fa5b33197`,
  computed with
  `git show origin/main:work/local-runner/requests/phase5-viridian-roadblock-20261018.patch | sha256sum`.
  It stays untouched.
- `.github/workflows/local-worker-bridge.yml` at `2450e15` (blob
  `87a4a6bb6bc68197cbb2920829256c45969c1763`): selector
  `phase5-viridian-roadblock*.patch` → route `phase5-viridian-roadblock`
  (lines 140–141), nine-path allowlist (line 274), replay case (lines 570–571).

### Operator environment fix (2026-11-15, path-free receipt)

The operator installed LÖVE 11.5 on runner `MediaCenter`, matching
`conf.lua` `t.version = "11.5"`. This resolves prerequisite 1's version
question: the accepted LÖVE version is 11.5. Operator-reported verification:

- `love` resolves to `/usr/bin/love` under the runner's actions-runner PATH
  file.
- A headless `timeout 30 xvfb-run -a love .` smoke test exited 0.
- `xvfb-run`, `timeout` and `mktemp` are present.

The bridge cannot self-verify these tools (outcome review, prerequisite 1).
These receipts are operator attestation, not guarded evidence.

### Operator authorization (verbatim, 2026-11-15)

> go for it, i authorize it

Given in response to: "the roadblock retry now needs your recovery
authorization". It authorizes this one recovery request only. It does not
waive this contract's independent authority review, pre-dispatch checks, or
outcome review.

Unknown: whether the C0 replay passes against the real ROM under LÖVE; it has
never executed.

## MAY CHANGE

Only after this contract receives an independent `PASS` and the fresh
pre-dispatch checks below all pass, create and publish exactly:

- `work/local-runner/requests/phase5-viridian-roadblock-recovery-20261115.patch`

The basename matches the workflow selector `phase5-viridian-roadblock*.patch`
and therefore the existing `phase5-viridian-roadblock` route. Its bytes and
SHA-256 must exactly equal the canonical request digest above. It must be the
triggering commit's sole changed request/probe and sole changed file. Record
run/job identifiers, named step outcomes, and terminal result.

The package keeps the same nine literal paths, the same workflow, and the same
route. Items 1–13 of the implementation authority apply unchanged, including
the focused/no-ROM/verified-ROM commands, the non-skipped SHA-verified ROM
fixture, and the exact `RUNTIME_REPLAY viridian_roadblock PASS` marker.
Diagnostic receipts from run `41273209685` cannot substitute for this run's
own complete evidence.

## MUST NOT CHANGE

- Do not modify, rename, or delete
  `work/local-runner/requests/phase5-viridian-roadblock-20261018.patch`; do not
  amend `f5582ff` or rerun `41273209685`.
- Do not create any request or probe other than the one literal recovery
  filename above, and do not change its bytes. If the canonical patch no longer
  applies to current `main`, stop: any rebased or changed bytes need a new,
  separately reviewed authority.
- Do not change the nine-path allowlist, package content, workflow, bridge,
  route configuration, runner service, private configuration, credentials, ROM
  files, canonical coordination, or capability status.
- Do not add behavior or evidence requirements, or relax any of items 1–13.
- Do not read a ROM or run LÖVE outside the hash-gated guarded job.
- Do not record a private path, ROM name, ROM bytes, private hash output,
  credential, log body, or derived ROM asset.

## Acceptance criteria

1. Independent authority review returns `PASS` for this exact contract revision
   before the request file exists.
2. Immediately before publication, the parent Orchestrator serializes the
   action and freshly confirms:
   - runner `24` / `MediaCenter`, label `firered-local`, is online and idle;
   - no bridge job is queued or running;
   - the workflow blob and the `phase5-viridian-roadblock*.patch` route are
     unchanged from `87a4a6bb6bc68197cbb2920829256c45969c1763`;
   - `git apply --check` of the canonical patch succeeds against current
     `main`;
   - prerequisite revisions and verdicts listed above are unchanged;
   - the operator confirms `love` still resolves on `MediaCenter` for the
     runner service user.
   Any change or failure stops dispatch.
3. The request is byte-identical to the canonical request (SHA-256 above),
   passes `git diff --check`, and is the triggering commit's sole changed file.
4. The guarded job succeeds through steps 2–15: checkout, request
   identification, explicit `phase5-viridian-roadblock` route, toolchain, ROM
   SHA verification, bounded patch validation/application, nine-artifact check,
   focused tests, no-ROM suite, verified-ROM suite with non-skipped ROM fixture,
   runtime replay with the exact marker, and literal nine-path publication.
   Otherwise record the exact failing step and stop.
5. A separate independent outcome review (item 13) accepts the exact job
   evidence before any C0 behavior acceptance or reconciliation.

## Required evidence

- Baseline: canonical SHA-256 match, workflow blob, and fresh runner metadata.
- Focused verification: request digest, `git diff --check`, `git apply --check`
  against current `main`, and exact route selection in the guarded job.
- Full verification: the complete guarded job per items 10–12.
- Review evidence: this authority review, then a separate item-13 outcome
  review of the executed request.

## Stop / escalate when

Runner state changes, `love` no longer resolves, GitHub refuses dispatch, the
digest differs, the patch does not apply to current `main`, the route or
workflow changes, any prerequisite revision or verdict changes, any guard,
test, replay, or publication step fails, or a tenth path, byte change, or
second request is needed. Record the exact state; do not repair, substitute,
or retry.

If this recovery run fails for any reason, there is no further retry. Any later
attempt requires new operator authority and a new, separately compiled,
independently reviewed recovery contract.

## Completion and handoff

- Worker records: request revision/digest, GitHub run/job identifiers, step
  outcomes, and terminal result without private details.
- Reviewer decides: `PASS | NEEDS_FIX | BLOCK` for this authority and,
  separately, for the exact guarded outcome.
- Orchestrator reconciles only after outcome review and preserves the original
  request's failure and exhaustion history.
- No Phase 5/7 completion, northbound traversal, or fresh-save claim follows
  from a successful run.
