# Task: configure Local Worker Bridge route for bounded Magnitude

- Task ID: `P4-F3-MAGNITUDE-ROUTE-CONFIG`
- Status: `CLOSED — REVIEWED PASS`
- Type: `INFRASTRUCTURE / EXECUTION SUBSTRATE / CONFIGURATION`
- Parent: [reviewed Magnitude route plan](local-worker-bridge-phase4-magnitude-route-plan.md).
- Assigned role: `WORKER`
- Independent reviewer: `REVIEWER`
- Prerequisites: route-plan PASS at `1347e5e` and accepted Magnitude design
  `6058b7c`; no Magnitude request/probe has been created.
- Risk: `MEDIUM` — a widened route could improperly authorize a later patch.

## Goal

Encode only the reviewed fail-closed `phase4-magnitude-effect` bridge route.
No readiness probe, request, or Magnitude behavior is authorized by this task.

## Source of truth

- [Reviewed route plan](../reports/phase4-magnitude-route-plan.md) and its
  [independent PASS](../reviews/2026-10-10-magnitude-route-plan-review.md).
- Current [Local Worker Bridge](../../.github/workflows/local-worker-bridge.yml)
  and `work/coordination/LOCAL_RUNNER_BRIDGE.md`.
- Unknowns requiring discovery: none; stop rather than infer a path or command.

## MAY CHANGE

1. `.github/workflows/local-worker-bridge.yml`
2. `work/coordination/LOCAL_RUNNER_BRIDGE.md`
3. this task file
4. `work/reports/local-worker-bridge-phase4-magnitude-route-configuration.md`

## Required configuration

Add only the five reviewed route arms for `phase4-magnitude-effect`:

1. selector accepting only `phase4-magnitude-effect*.patch` and
   `phase4-magnitude-effect*.probe`;
2. patch-target validation with exactly the reviewed nine literal paths;
3. focused commands, in order: `battle_engine_test.lua`,
   `battle_scene_controller_test.lua`, `phase4_move_effect_inventory_test.lua`,
   and `phase4_magnitude_effect_rom_test.lua`, all through the selected Lua
   interpreter;
4. mandatory `bash scripts/runtime_phase4_magnitude_replay.sh` replay arm; and
5. publication staging of exactly the same nine literal paths using individual
   `git add -- "$path"` calls.

Retain the unchanged shared no-ROM command (`env -u POKEPORT_ROM bash
scripts/test_all.sh`) and the unchanged verified-ROM step-level environment
mapping (`POKEPORT_ROM: ${{ steps.rom.outputs.path }}`) followed by `bash
scripts/test_all.sh`. Document the same nine-path scope, required replay, and
post-review probe gate in the bridge procedure.

## MUST NOT CHANGE

Code, tests, replay implementation, requests/probes, runner registration or
credentials, ROM lookup/hash/privacy policy, generic selector fallback, any
existing route behavior, capability status, or Magnitude behavior. Do not
create a route probe in this task. Do not add wildcards, a tenth target, a
staging-only path, or a no-replay fallback.

## Acceptance criteria

1. All five route arms name only `phase4-magnitude-effect` and preserve every
   existing shared fail-closed guard and neighboring route byte behavior.
2. Validation and staging are set-equal to the nine reviewed literal paths;
   focused commands, full-suite behavior, and replay arm exactly match the
   route plan.
3. Bridge procedure documents the identical scope and that configuration PASS
   permits only one later substrate-only probe.
4. Independent exact configuration review passes before any probe is created.

## Required evidence

- Baseline: inspect all existing selector, validation, focused-test, replay,
  and publication arms before editing.
- Focused verification: `git diff --check`; YAML parse/syntax and `bash -n`
  checks for every workflow shell block; static selector, target, command,
  replay, and staging positive/negative route checks using safe stubs only.
- Full verification: N/A — this task changes bridge configuration only; it
  must not run a request, probe, private ROM, test suite, replay, or runner.
- Review evidence: exact revision plus independent review under
  `work/reviews/`.

## Stop / escalate when

- A required literal path, command, or workflow insertion point cannot be
  named from the reviewed plan;
- any existing route or shared guard would need to change; or
- a probe/request, ROM action, or Magnitude implementation is proposed.

Record `BLOCKED` instead of widening the route.

## Completion and handoff

- Worker records the exact revision, five route arms, static checks, and
  changed paths; it does not create a probe, request, or implementation.
- Reviewer decides `PASS | NEEDS_FIX | BLOCK` for the exact configuration.
- Orchestrator reconciles task/register/state and, only after PASS, may compile
  one separately bounded substrate-only probe task.
- Eligible successor: a reviewed one-file
  `phase4-magnitude-effect-route-YYYYMMDD.probe` authority; no implementation
  task is eligible yet.

## Worker configuration handoff — 2026-10-10

The workflow adds only the five reviewed `phase4-magnitude-effect` arms:
explicit `.patch`/`.probe` selection, a nine-literal-path validation allowlist,
four selected-interpreter focused tests in reviewed order, the required
Magnitude replay, and individual staging of the same nine paths. The shared
no-ROM and SHA-verified-ROM suite commands and every neighboring route remain
unchanged. The bridge procedure records the same nine-path scope, required
replay, and post-review substrate-only probe gate. No probe, request, runner,
ROM, test suite, replay, implementation, coordination, or capability-status
action occurred. Static configuration evidence is recorded in
`work/reports/local-worker-bridge-phase4-magnitude-route-configuration.md`.
Independent exact configuration review remains required before any probe.

## Independent review — 2026-10-10

The independent [exact configuration review](../reviews/2026-10-10-magnitude-route-configuration-review.md)
returned **PASS** for published revision `57d6b053226452a4835c9ad829306e9beb367330`.
It closes configuration only and permits compilation of the one-file readiness
probe authority; it does not authorize a probe dispatch or Magnitude behavior.
