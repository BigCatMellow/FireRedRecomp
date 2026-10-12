# Task: plan a guarded route for bounded effect-45 crash behavior

- Task ID: `P4-F3-RECOIL-IF-MISS-ROUTE-PLAN`
- Status: `READY_FOR_WORKER`
- Type: `DESIGN / ROUTE PLANNING / NO WORKFLOW CHANGE`
- Parent capability gate: Phase 4 full battle engine move/effect matrix in
  [CAPABILITY_CHECKLIST.md](../roadmaps/CAPABILITY_CHECKLIST.md).
- Assigned role: `RESEARCHER`
- Independent reviewer: `REVIEWER`
- Prerequisites: source lock `c218da6`, supplement `ba69269`, and revised
  design `b3280f9`, each independently accepted.
- Risk: `MEDIUM` — an imprecise route could widen later runner authority or
  omit required crash/faint/persistence evidence.

## Goal

Specify the smallest fail-closed bridge route for one future effect-45
implementation request, limited to Jump Kick 26 and Hi Jump Kick 136. Derive
literal target/staging paths and focused/full/replay commands from the
accepted design and current bridge. This task authorizes documentation only.

## Source of truth

- [Accepted design](../reports/phase4-recoil-if-miss-design.md) and its
  [independent PASS](../reviews/2026-10-12-recoil-if-miss-design-review.md).
- [Controlling source supplement](../reports/phase4-recoil-if-miss-entry-state-discovery.md)
  and [PASS](../reviews/2026-10-12-recoil-if-miss-entry-state-review.md).
- [Current bridge workflow](../../.github/workflows/local-worker-bridge.yml),
  [bridge procedure](../coordination/LOCAL_RUNNER_BRIDGE.md), and reviewed
  [Magnitude route pattern](../reports/phase4-magnitude-route-plan.md).
- Unknowns delegated here: minimum literal evidence surface for accepted
  attacker-faint, controller-ordering and HP/PP persistence requirements.
  If that surface cannot be bounded without new behavior authority, stop.

## MAY CHANGE

1. `work/reports/phase4-recoil-if-miss-route-plan.md`.
2. This task's evidence and handoff only.

## MUST NOT CHANGE

Workflow, bridge configuration/procedure, requests/probes, runtime/tests,
runner/ROM, save/UI/AI, admission, formulas, accepted design, coordination,
capability status, existing route behavior, or another effect family.
No runtime, test-suite, replay, ROM or private-runner execution/inspection.
No implementation task, generic fallback, wildcard target allowlist, inferred
unsupported command, or route widening.

## Acceptance criteria

1. Specify one unique explicit selector and its exact request/probe filename
   forms. Unknown routes must still fail closed; no other route is reusable.
2. Derive a minimal literal future patch allowlist, exactly set-equal to the
   staging list. Explain every path from design ownership/evidence. Inspect
   existing test/replay conventions read-only; do not blindly copy the prior
   route's path count. Keep runtime changes limited to the accepted engine/
   controller seams; broader persistence/runtime changes need new authority.
3. Specify exact ordered focused commands through the bridge-selected Lua,
   unchanged shared no-ROM and SHA-verified-ROM suites, and non-skipped
   inventory/record evidence. Preserve trusted-main, single-input, supported
   SHA, apply/diff guards, privacy and patch-only publication behavior.
4. Decide and justify deterministic replay and fresh readiness-probe needs.
   Map accepted ordinary immune/nonimmune branches, branch-local RNG/PP,
   message-before-HP order, attacker faint/forced continuation, firstBattle,
   and HP/PP persistence to the proposed evidence surface. Distinguish a pure
   bridge persistence assertion from actual lifecycle or save/reload proof;
   never promise evidence an allowlisted fixture cannot supply.
5. Retain literal IDs/effect, successful-hit preservation, ordinary recoil
   separation, conditional late-immunity exclusion, and every accepted source/
   design exclusion. No gameplay support or Phase 4 completion claim.
6. Propose only the separately bounded route-configuration successor. Plan
   PASS itself authorizes no configuration edit, probe or request; later
   configuration/probe/implementation authority each retain their own gates.

## Required evidence

- Baseline: accepted exact design/source chain and read-only current workflow,
  relevant engine/controller/party and test/replay surfaces.
- Focused verification: literal path/command/guard consistency and
  `git diff --check`; repository syntax/local-document checker permitted.
- Full verification: N/A for route planning; no gameplay, ROM or runner
  execution is permitted.
- Review evidence: exact task/report revision and separate independent review
  under `work/reviews/` returning `PASS | NEEDS_FIX | BLOCK`.

## Stop / escalate when

A needed path/command cannot be named literally, evidence requires a broader
runtime or lifecycle contract, accepted source/design is insufficient, or an
existing route/shared guard must change. Record the minimum missing decision;
do not substitute guessed coverage or widen the package.

## Completion and handoff

- Worker records base revision, exact artifacts, inspected seams, checks,
  exclusions and any unresolved requirement.
- Reviewer decides `PASS | NEEDS_FIX | BLOCK` against this exact plan.
- Orchestrator closes only independently proven planning scope and updates
  register/state/handoff; canonical Phase 4 remains open.
- Eligible successor: separately bounded route configuration only after PASS;
  no request, probe or implementation follows directly from this task.
