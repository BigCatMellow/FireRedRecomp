# Magnitude implementation authority — independent review

Verdict: **PASS** for the exact uncommitted
`P4-F3-MAGNITUDE-IMPLEMENTATION` authority draft and its coordination relay.
This PASS authorizes neither a bridge input nor Magnitude behavior.  It permits
only the subsequently described, single request after a fresh online/idle
`firered-local` observation.

## Independence and exact scope

I did not author or alter the authority or coordination draft.  I independently
read `AGENTS.md`, the accepted Magnitude source-lock and design reviews, the
reviewed route plan/configuration/probe-outcome chain, the current bridge route,
and the exact uncommitted diff.  At review time that diff contains only:

- `work/tasks/phase4-magnitude-implementation.md` (new); and
- coordination relay updates in `work/coordination/HANDOFF.md`,
  `work/coordination/STATE.json`, and `work/coordination/TASK_REGISTER.md`.

There is no matching `phase4-magnitude-effect*.patch` request.  `git diff
--check` passes.  No workflow, route, runner, ROM, replay, source, test, or
behavior artifact is changed by the reviewed draft.

## Authority findings

1. **Prerequisite chain and one-request gate are literal.** The task names the
   accepted source, design, route-configuration, and route-probe-outcome
   reviews.  It permits exactly one future
   `work/local-runner/requests/phase4-magnitude-effect-YYYYMMDD.patch` only
   after this independent PASS, requires an immediately preceding fresh
   online/idle runner observation, treats changed runner state as a stop, and
   forbids replacement, retry, widening, or a second request.  The relay
   correctly remains `READY_FOR_REVIEWER`; it does not claim that a request or
   behavior exists.
2. **The nine-path boundary matches the configured bridge exactly.** In the
   same order, the task names `BattleEngine`, `BattleSceneController`, their
   focused tests, the inventory test, Magnitude ROM fixture, Magnitude replay,
   this implementation task, and its report.  Those are exactly the current
   `phase4-magnitude-effect` validation and publication literals—no wildcard,
   tenth path, coordination target, workflow, `main.lua`, importer, or data
   model path is introduced.
3. **Behavior and proof contracts retain the accepted bounded design.** The
   authority preserves existing positive-power admission for Magnitude
   222/effect 126; after existing selection/support/zero-PP/`useMove` handling
   it requires one permanent-slot PP deduction, one `% 100` draw, the complete
   4–10/10–150 table, an ordered minimal level event, and the existing
   one-defender accuracy/hit path with a shallow local power copy.  It neither
   mutates shared catalog data nor creates a generic dynamic-power facility.
   It also retains ordinary hit/miss draw counts (four/two), the separately
   tested first-player `firstBattle` three-draw hit/bypassed-accuracy branch,
   non-126 ordering, no-effect ordering, and non-mutating controller
   presentation.
4. **Execution evidence is complete and guarded.** The authority requires the
   bridge-selected four focused commands in configured order, apply/diff
   checks, both full suites with the SHA-ROM fixture/inventory non-skipped, and
   the mandatory deterministic represented-state replay.  It requires a fresh
   independent outcome review of the exact published nine-path revision before
   reconciliation; it does not confuse a request or job success with that
   review.
5. **Exclusions remain fail-closed.** The task explicitly excludes route and
   runner changes, ROM/private content, admission/data changes, generic
   abstractions, other effect families, targeting/doubles/absent-battler
   behavior, Underground, abilities/items, status/cancellation expansion,
   Substitute/MoveEnd, visual/localization/link parity, and full seeded retail
   turn claims.  Its stop conditions require `BLOCKED` rather than a widened or
   retried input for every listed out-of-scope need or failed guard.

## Successor boundary

The Orchestrator may now make one fresh-runner-observation-gated, literal
`phase4-magnitude-effect` request.  This review does not execute that request,
authorize a retry, certify an implementation, or advance Phase 4.  Its guarded
result must receive a separate independent outcome review before any
reconciliation.
