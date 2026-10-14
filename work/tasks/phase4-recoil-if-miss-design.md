# Task: design the bounded effect-45 recoil-on-miss contract

- Task ID: `P4-F2-RECOIL-IF-MISS-DESIGN`
- Status: `READY_FOR_WORKER`
- Type: `DESIGN / NO IMPLEMENTATION`
- Parent capability gate: Phase 4 move-effect family chain.
- Assigned role: `WORKER`
- Independent reviewer: `REVIEWER`
- Prerequisites: accepted `P4-F1-RECOIL-IF-MISS-DISCOVERY` source lock and
  [independent PASS](../reviews/2026-10-10-recoil-if-miss-source-discovery-review.md)
  published at `c218da6`; entry-state supplement `ba69269` and its
  [independent PASS](../reviews/2026-10-12-recoil-if-miss-entry-state-review.md).
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
- [Accepted entry-state supplement](../reports/phase4-recoil-if-miss-entry-state-discovery.md)
  and [independent PASS](../reviews/2026-10-12-recoil-if-miss-entry-state-review.md)
  at `ba69269`. This supplement controls the explicit 1/1 reset values,
  ordinary immunity precheck, no-effect presentation/early exit, and downstream
  HP gates where the original source wording was incomplete.
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
2. Specify the represented accuracy-failure branches: shared ordinary
   accuracy and PP; ordinary immunity precheck producing a no-effect result
   and early exit without crash; otherwise a miss followed by a distinct crash
   result; explicit neutral 1/1 entry multipliers, source-order
   base/type/normal-damage computation; integer half,
   minimum-one, and target-max-HP cap; attacker-only HP application; attacker
   faint check; and common action completion. State exact non-claims where the
   source requires state the project does not represent. Separate conditional
   downstream immunity semantics from reachable ordinary outcomes; do not
   invent source flags or a reachable late-only immunity branch.
3. Define the smallest event/controller ownership and ordering contract without
   reusing ordinary hit recoil or turning a generic miss into a crash. Identify
   exact current owner seams and persistence consequences as design facts, not
   code changes.
4. State deterministic later test/implementation acceptance outlines for the
   literal miss branch, successful hits, no-effect guard, cap/rounding edges,
   attacker faint, PP, branch-local RNG, message/HP event order, first-battle
   accuracy-bypass preservation, and unchanged unrelated behavior. Do not
   write an implementation authority, route, probe, request, or test edit.
5. Preserve explicit exclusions: cancellation/interception, Protect,
   Substitute, abilities, items, Endure/Focus Band, status,
   semi-invulnerability, called/mirrored provenance, doubles/links, malformed
   battlers, animation/timing parity, and every other effect family. An
   independent exact-report PASS is required before any separately scoped
   route or implementation authority.

## Required evidence

- Baseline: verify the published source-lock task/report/review at `c218da6`
  and supplement task/report at `ba69269` plus its independent PASS; inspect
  the named current-project seams read-only.
- Focused verification: read-only consistency check against that source chain;
  no ROM or runtime execution is permitted.
- Full verification: N/A for this design-only package; `git diff --check` is
  required.
- Review evidence: an independent exact-revision review under `work/reviews/`
  returning `PASS`, `NEEDS_FIX`, or `BLOCK`.

## Stop / escalate when

The design needs a generic recoil/miss abstraction, an unrepresented source
state, source facts beyond the accepted source chain, or any runtime/route/ROM action.
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

### Historical Worker evidence and stop handoff — 2026-10-11

The [design/stop report](../reports/phase4-recoil-if-miss-design.md) records
the locked sequence, current engine/controller/party seams, and conditional
later acceptance outline at published `a2d6779` / local `a6a055e` (identical
inspected code). Source-lock task/report hashes match the accepted review at
`c218da6`. No runtime, test, route, runner/ROM, or implementation action ran.

Worker stopped under this task's existing source-certainty rule: the accepted
lock does not establish incoming critical/damage multiplier reset values on
the miss edge; the project has no corresponding incoming state. The report
also identifies the unrepresented pre-existing no-effect guard and the
unlocked downstream HP command's handling of newly computed immunity. No
defaults, source flags, or generic abstraction were invented.

Independent exact-report review is pending. This is not a completed design
or an implementation/route handoff. The Reviewer should assess the exact
stop and minimum source supplement; the Orchestrator owns any separately
bounded follow-up. All acceptance criteria and exclusions above remain
unchanged.

### Orchestrator reactivation — 2026-10-12

The prior stop received independent BLOCK at `f31ae69`; it was not design
completion. Source supplement `ba69269` now independently passes and resolves
the named source gaps, including an explicit correction to ordinary immune
accuracy-failure presentation. The source authority and acceptance above
incorporate only those accepted facts. Worker must revise the existing report
and append fresh evidence/handoff; the old report is not an accepted design.
This design-only reactivation still requires its own exact independent review
before any separately authorized route or implementation task.

### Resumed Worker evidence and review handoff — 2026-10-12

The revised [design report](../reports/phase4-recoil-if-miss-design.md) is
ready for independent exact-artifact review at inspection base
`4dd22e1d80ea40e485ee134e59499183e31847f3`, freshly verified as public main.
Its historical stopped version remains identified by exact `f31ae69`
task/report hashes and the separate BLOCK review; the current report
explicitly supersedes the incomplete ordinary-immunity outline.

The accepted source task/report identities at `c218da6` and `ba69269` were
reproduced. Four current engine/formula/controller/party files remain
unchanged from `c218da6`; the report records their hashes and current anchors.
The revised design covers literal selection, immune no-effect early exit,
nonimmune miss/crash, neutral 1/1 multipliers, source-order half/minimum/cap,
branch-local RNG/PP, distinct message-before-HP presentation, firstBattle
preservation, attacker faint/continuation, and existing persistence ownership.
Conditional late-only immunity is explicitly not an ordinary reachable oracle.
All exclusions remain; no new source gap was found within this boundary.

Read-only source/seam consistency and baseline/final whitespace checks passed.
`lua5.1 scripts/check_repository.lua` passed after the revised report:
280 tracked Lua, 269 tracked Markdown, 846 local targets. The final pair's
check receipt and exact hashes accompany Worker delivery to the Orchestrator.
Full gameplay, test-suite, runtime, replay, ROM, and private-runner checks
are N/A and were not executed under this design-only contract.

Only the report and this appended evidence/handoff were changed. Acceptance
criteria were preserved. No code, event schema, tests, admission, formulas,
save, route, request, probe, runner, coordination, or capability status was
changed; no stage/commit/push was performed. The Orchestrator owns publication
and independent review of the exact pair. This Worker readiness claim is not
a PASS and authorizes no successor by itself.
