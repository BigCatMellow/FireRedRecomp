# Task: configure the bounded effect-45 bridge route

- Task ID: `P4-F3-RECOIL-IF-MISS-ROUTE-CONFIG`
- Status: `READY_FOR_WORKER`
- Type: `IMPLEMENTATION / EXECUTION-SUBSTRATE CONFIGURATION`
- Parent capability gate: [Phase 4 move/effect matrix](../roadmaps/CAPABILITY_CHECKLIST.md).
- Assigned role: `WORKER`; independent reviewer: `REVIEWER`.
- Prerequisites: route plan `04636d1` and its independent PASS; accepted
  effect-45 design `b3280f9`. No effect-45 probe/request exists.
- Risk: `MEDIUM` — an overly broad route could publish unauthorized changes.

## Goal and source of truth

Encode only the reviewed `phase4-recoil-if-miss-effect` route from the
[exact plan](../reports/phase4-recoil-if-miss-route-plan.md) and
[independent PASS](../reviews/2026-10-12-recoil-if-miss-route-plan-review.md).
Current [workflow](../../.github/workflows/local-worker-bridge.yml) and
[bridge procedure](../coordination/LOCAL_RUNNER_BRIDGE.md) supply insertion
points, not authority to widen the accepted plan. No discovery remains;
stop if the plan cannot be encoded inside these boundaries.

## MAY CHANGE

1. `.github/workflows/local-worker-bridge.yml` — new route arms only.
2. `work/coordination/LOCAL_RUNNER_BRIDGE.md` — describe only the new route.
3. This task's evidence/handoff only.
4. `work/reports/local-worker-bridge-phase4-recoil-if-miss-route-configuration.md`.

## MUST NOT CHANGE

Runtime, tests, replay implementation, requests/probes, runner/credential/ROM
configuration, private SHA/privacy rules, shared guards, existing route
behavior, generic fallback, accepted design/plan, other coordination or
canonical capability state. No gameplay test suite, replay, private-runner,
ROM, probe or request execution. No eleventh target or optional evidence.

## Acceptance criteria

1. Add exactly the explicit selector patterns
   `phase4-recoil-if-miss-effect*.patch` and
   `phase4-recoil-if-miss-effect*.probe`; preserve unknown-route failure.
2. Add validation and publication staging arms with exactly the plan's ten
   literal paths, set-equal, using individual `git add -- "$path"` calls.
   Required artifacts must exist before publication; missing any must fail
   this new route instead of silently skipping it. Enforce this locally in
   the new route, without altering existing route arms/shared behavior.
3. Add the five focused `$LUA` commands in reviewed order: engine test,
   scene-controller test, party-bridge test, inventory test, and
   `tests/phase4_recoil_if_miss_effect_rom_test.lua`. Keep shared no-ROM and
   SHA-ROM suite commands/environment unchanged.
4. Add mandatory patch-only
   `bash scripts/runtime_phase4_recoil_if_miss_replay.sh` arm. No replay/test
   implementation or execution here; probe mode must still skip all patch
   validation/application/tests/replay/staging/publication steps.
5. Document the identical ten-path/five-command surface, required replay,
   missing-artifact failure and later separately authorized probe gate.
6. Preserve all existing route/shared-guard behavior and accepted exclusions.
   Independent exact configuration review must PASS before any probe task.

## Required evidence

- Baseline: inspect current selector/validation/focused/replay/staging arms
  and shared guards, matching the accepted plan's workflow hash.
- Focused: `git diff --check`, YAML parse, `bash -n` for every shell block;
  safe-stub static checks for selector positive/negative cases, all ten
  allowed targets and representative forbidden targets, exact five focused
  calls/replay/staging equality, unknown-route rejection, and failure when
  each required artifact is missing. Stub execution must not invoke real
  git publication, tests, replay, ROM lookup or runner actions.
- Full: N/A for configuration-only work; repository syntax/docs checker is
  permitted, but gameplay/full-suite/ROM/replay execution is not.
- Review: separate exact-revision `PASS | NEEDS_FIX | BLOCK` in `work/reviews/`.

## Stop / escalate when

A literal path/command or insertion point is unclear; existing/shared behavior
must change; safe verification would touch prohibited state; or a probe,
request or gameplay edit is needed. Record the precise gap, do not widen.

## Completion and handoff

Worker records exact changes, hashes and static evidence. Reviewer verifies
the exact configuration independently. Orchestrator reconciles only substrate
configuration and compiles one separately bounded readiness-probe task after
PASS. This task never authorizes a probe, request or effect-45 gameplay patch.
