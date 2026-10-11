# Task: design the bounded effect-45 recoil-on-miss contract

- Task ID: `P4-F2-RECOIL-IF-MISS-DESIGN`
- Status: `READY_FOR_WORKER`
- Type: `DESIGN / NO IMPLEMENTATION`
- Parent capability gate: Phase 4 move-effect family chain.
- Assigned role: `WORKER`
- Independent reviewer: `REVIEWER`
- Prerequisites: accepted `P4-F1-RECOIL-IF-MISS-DISCOVERY` source lock and
  [independent PASS](../reviews/2026-10-10-recoil-if-miss-source-discovery-review.md)
  published at `c218da6`.
- Risk: `MEDIUM` — an imprecise miss-branch/event contract could misdirect a
  later implementation toward ordinary recoil or generic miss behavior.

## Goal

Specify the smallest represented-singles engine/controller design for only
`EFFECT_RECOIL_IF_MISS` (45): Jump Kick #26 and Hi Jump Kick #136. The design
must retain the existing successful-hit path and define only the literal
accuracy-miss crash branch before any separately authorized implementation.

## Source of truth

- [Accepted effect-45 source lock](phase4-recoil-if-miss-source-discovery.md)
  and its paired
  [report](../reports/phase4-recoil-if-miss-source-discovery.md).
- [Independent exact-report PASS](../reviews/2026-10-10-recoil-if-miss-source-discovery-review.md).
- Current published project seams identified in that source lock:
  `BattleEngine`, `BattleFormulas`, `BattlePartyBridge`, and
  `BattleSceneController`.
- Unknowns requiring a later implementation task: exact implementation edits,
  test fixtures, bridge route, runner/ROM evidence, and all unsupported source
  state.

## MAY CHANGE

1. `work/reports/phase4-recoil-if-miss-design.md`.
2. This task's design evidence and handoff only.

## MUST NOT CHANGE

Runtime, tests, move admission policy, formulas, event schemas, controller/UI,
save or party persistence, AI, workflows, bridge routes, requests/probes,
runner/ROM configuration, supported-ROM policy, canonical capability status,
or any other effect family.

Do not implement Jump Kick/Hi Jump Kick crash behavior, add generic recoil or
generic miss handling, reuse ordinary actual-hit recoil, add crash
presentation, create an implementation task, or claim current support. Do
not inspect a ROM, private runner state, media, or runtime behavior.

## Acceptance criteria

1. Define literal selection and admission expectations for effect 45 / move
   IDs 26 and 136 only, preserving the ordinary successful-hit path and
   distinguishing effect 45 from ordinary effects 48 and 198 recoil.
2. Specify the represented accuracy-miss sequence: shared ordinary
   accuracy/PP/miss result; the pre-existing no-effect guard; a distinct crash
   result; source-order base/type/normal-damage computation; integer half,
   minimum-one, and target-max-HP cap; attacker-only HP application; attacker
   faint check; and common action completion. State exact non-claims where the
   source requires state the project does not represent.
3. Define the smallest event/controller ownership and ordering contract without
   reusing ordinary hit recoil or turning a generic miss into a crash. Identify
   exact current owner seams and persistence consequences as design facts, not
   code changes.
4. State deterministic later test/implementation acceptance outlines for the
   literal miss branch, successful hits, no-effect guard, cap/rounding edges,
   attacker faint, PP, event order, and unchanged unrelated behavior. Do not
   write an implementation authority, route, probe, request, or test edit.
5. Preserve explicit exclusions: cancellation/interception, Protect,
   Substitute, abilities, items, Endure/Focus Band, status,
   semi-invulnerability, called/mirrored provenance, doubles/links, malformed
   battlers, animation/timing parity, and every other effect family. An
   independent exact-report PASS is required before any separately scoped
   route or implementation authority.

## Required evidence

- Baseline: verify the published source-lock task/report/review at `c218da6`
  and inspect the named current-project seams read-only.
- Focused verification: read-only consistency check against the source lock;
  no ROM or runtime execution is permitted.
- Full verification: N/A for this design-only package; `git diff --check` is
  required.
- Review evidence: an independent exact-revision review under `work/reviews/`
  returning `PASS`, `NEEDS_FIX`, or `BLOCK`.

## Stop / escalate when

The design needs a generic recoil/miss abstraction, an unrepresented source
state, source facts beyond the accepted lock, or any runtime/route/ROM action.
Record the unresolved requirement and stop; do not silently approximate it or
widen this task.

## Completion and handoff

- Worker records the exact revision, report path, read-only checks, and every
  retained exclusion.
- Reviewer decides `PASS | NEEDS_FIX | BLOCK` against this task only.
- Orchestrator may reconcile this design package after a PASS, but must not
  advance Phase 4 or authorize implementation without a new bounded task and
  its required independent review.
- Eligible successor: one separately compiled, fail-closed effect-45 route or
  implementation-authority decision; no successor is authorized by this task
  itself.
