# Task: establish Viridian C0 roadblock bridge readiness only

- Task ID: `P5-06-VIRIDIAN-ROADBLOCK-ROUTE-PROBE`
- Status: `CLOSED — REVIEWED PASS`; sole allowance consumed by PR50 merge `8c6e4fa`.
- Type: `GUARDED READINESS PROBE`
- Parent capability gate: [Phase 5/7 first-corridor progression](../roadmaps/CAPABILITY_CHECKLIST.md)
- Assigned role: `WORKER`; independent reviewer: separate `REVIEWER`.
- Prerequisites: the C0 route-configuration task, adopted at `933ef72` and
  recovered at `72a18e9`, is merged at `2eb8fddac1cbb410097c8bcc9e44885e3c395cad` and
  has independent `PASS` at `work/reviews/2026-10-18-viridian-roadblock-route-configuration-review.md, dbf2b3896e2993f86da8a0c2bbe251eb0b07db1c`;
  the final merged workflow must select `phase5-viridian-roadblock` for the
  literal probe filename. Immediately before the one publication, the
  Orchestrator must freshly verify an online, idle `firered-local` runner and
  no active or queued bridge jobs.
- Risk: `MEDIUM` — this verifies only guarded execution substrate; it cannot
  establish gameplay or authorize an implementation patch.

## Goal and source of truth

Create exactly one readiness-only probe at
`work/local-runner/probes/phase5-viridian-roadblock-route-20261018.probe`.
Use the merged, independently reviewed C0 route configuration, its accepted
design, and the then-current workflow/bridge documentation. The single probe
may establish only trusted checkout, exact route recognition, Lua toolchain,
and existing supported-ROM SHA readiness.

The previously observed read-only runner inventory says `MediaCenter` was
online and idle. It is historical inventory only, not fresh readiness evidence;
it cannot satisfy the prerequisite above.

If the calendar date is no longer 2026-10-18 when this task is adopted, the
Orchestrator must flag the proposed filename as stale, select one new
date-stamped literal filename before dispatch, record it in the adopted
contract, and never reuse that filename or allowance.

## MAY CHANGE / MUST NOT CHANGE

Only the literal probe file above may change in the Worker package. It must be
the triggering commit's sole changed file and sole bridge input. Its content
must identify this task and limit the requested outcome to trusted checkout,
exact route recognition, Lua toolchain, and existing supported-ROM SHA
readiness.

Do not change or create a patch/request, workflow, code, test, replay, runner,
credential, ROM configuration, coordination record, capability status, or
gameplay behavior. Do not inspect a ROM or submit/dispatch a probe while
compiling this contract. Do not expose private paths, ROM data/content, secrets,
or environment-bearing logs in the probe, commit, report, review, or public
receipt. Do not run gameplay tests or a replay directly. One allowance is
consumed by one publication; no retry, replacement input, or second probe is
authorized.

## Acceptance and required evidence

1. The exact merged configuration and independent `PASS` review identified
   above remain the authority prerequisites. The Orchestrator, not the Worker,
   performs the final
   fresh route/configuration, online-idle `firered-local`, and no-active-or-
   queued-bridge-jobs checks immediately before publication.
2. The Worker creates exactly the literal one-file probe commit. That commit
   selects only `phase5-viridian-roadblock`; it contains no patch/request and
   no other changed file or bridge input. `git diff --check` passes.
3. The guarded job passes only safe substrate outcomes: trusted checkout, input
   identification, explicit C0 route selection, Lua toolchain, supported-ROM
   SHA gate, and `Probe complete`. Record only safe commit/run/job identifiers
   and named step statuses; do not copy logs, runner paths, ROM paths, hashes
   beyond the existing supported target, or ROM content.
4. All eight patch-only steps skip: bounded target validation, patch
   application, the mandatory pre-evidence artifact gate, route-focused tests, shared no-ROM suite, shared verified-ROM
   suite, route runtime replay, and staging/publication.
5. This probe is readiness evidence only. It does not exercise the nine-path
   allowlist, six focused commands, either full suite, replay, gameplay, or
   implementation behavior.
6. An independent exact outcome review returns `PASS | NEEDS_FIX | BLOCK`
   before an implementation authority may be compiled. A `PASS` does not itself
   authorize a request or implementation; the Orchestrator must separately
   reconcile it and issue a reviewed implementation contract.

## Stop and handoff

Stop without publication if the configuration is not exactly merged and
independently passed, the selector differs, the runner is not freshly online
and idle, any bridge job is active/queued, the one-file condition fails, or the
date-stamped filename has already been consumed. Any failed prerequisite,
guard, or job is terminal for this task's sole allowance: record only the safe
failure step/status and required unblock input; do not retry, substitute an
input, or widen scope.

Worker creates the exact artifact only. The Orchestrator performs the final
fresh prerequisites and publication/monitoring under the adopted task.
Independent Reviewer records the outcome verdict. Only the Orchestrator
reconciles the receipt and, after independent `PASS`, may compile a distinct
implementation authority. No Phase 5/7 completion or gameplay acceptance is
claimed here.

## Executed outcome

Artifact `9472aec6`, SHA256
`edafcd7332caafeac7d4b4b270ae055e3a4fbc697069b1db6400c18895398bef`,
was submitted exactly once through PR50 merge `8c6e4fa90fa4fa49a9fbb17c64e16f37bd1e964b`.
Run `39165635888` / job `117787881344` passed all readiness gates and skipped
all eight patch-only steps. Fresh pre-submit main/workflow/runner/job checks
passed. [Independent outcome PASS](../reviews/2026-10-18-viridian-roadblock-route-probe-outcome-review.md)
at `da0352d` was adopted unchanged in `2c11211`. No retry or further probe.
Next is [separate implementation-authority review](phase5-viridian-roadblock-implementation.md),
not a request or gameplay acceptance.
