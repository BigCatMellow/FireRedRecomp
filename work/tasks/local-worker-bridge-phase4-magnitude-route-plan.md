# Task: plan a guarded route for bounded Magnitude

- Task ID: `P4-F3-MAGNITUDE-ROUTE-PLAN`
- Status: `CLOSED — REVIEWED PASS`
- Type: `ROUTE PLANNING / NO WORKFLOW CHANGE`
- Parent: [Magnitude design PASS](../reviews/2026-10-10-magnitude-design-review.md).
- Assigned role: `RESEARCHER`
- Independent reviewer: `REVIEWER`
- Risk: `MEDIUM` — an incorrect plan could broaden later runner authority.

## Goal

Specify the smallest fail-closed bridge route needed for one future bounded
Magnitude implementation request. The plan must name an exact selector,
literal later patch allowlist, focused no-ROM and SHA-ROM checks, replay policy,
and staging list by inspecting the existing bridge; it must not change the
workflow or authorize a request.

## MAY CHANGE

- `work/reports/phase4-magnitude-route-plan.md`
- this task's handoff section

## MUST NOT CHANGE

Workflow, requests/probes, runtime/tests, bridge configuration, runner/ROM,
save/UI/AI, existing route behavior, capability status, or Magnitude design.
No broad selector, wildcard target allowlist, inferred command, or fallback is
permitted.

## Acceptance

1. Derive every later literal route path and command from the accepted
   Magnitude design and existing bridge conventions.
2. Keep private-ROM SHA validation and trusted-main/fail-closed guards intact.
3. State whether a readiness probe is needed before implementation and why.
4. Exclude all unsupported Magnitude/source behaviors and every unrelated path.
5. Propose only a later route-configuration task; no workflow/code authority.

## Evidence and stop

Use current `.github/workflows/local-worker-bridge.yml`, accepted design/review,
and analogous reviewed Phase 4 route records. `git diff --check` and an
independent exact review are required. Stop if a needed path or test boundary
cannot be named literally; record `BLOCKED` rather than broadening scope.

## Handoff

Reviewer returns `PASS | NEEDS_FIX | BLOCK`. Only an independently accepted
route-configuration successor may modify the bridge; no Magnitude patch follows
from this task.

## Independent review — 2026-10-10

The independent [exact-draft review](../reviews/2026-10-10-magnitude-route-plan-review.md)
returned **PASS** for published revision `1347e5edab60bdb0ee1f263d3a0e1f04f529bb4c`.
It verified the literal selector, symmetric nine-path future surface, focused
and suite commands, required replay/probe decisions, and exclusions.  This
closes the plan only; it permits compilation of
`P4-F3-MAGNITUDE-ROUTE-CONFIG` but no bridge edit, probe, request, or Magnitude
implementation.

## Researcher handoff — 2026-10-10

Drafted `work/reports/phase4-magnitude-route-plan.md` from the accepted
Magnitude source/design chain, the current bridge workflow, and reviewed
Restore HP/P5 route records.  It proposes only the later explicit
`phase4-magnitude-effect` selector; equal nine-path validation/staging lists;
four focused Lua commands; preserved no-ROM and SHA-ROM suites; one required
headless Magnitude replay; and one required post-configuration substrate-only
probe.  No workflow, configuration, request/probe, runtime, test, ROM, runner,
implementation, status, or coordination file changed.  Await independent
exact-draft review before compiling any configuration successor.
