# Task: plan Local Worker Bridge route for Viridian Old Man projection

- Task ID: `P5-04-ROUTE`
- Status: `CLOSED — REVIEWED PASS`
- Type: `INFRASTRUCTURE / EXECUTION SUBSTRATE / PLAN`
- Authority: [P5-04 implementation contract](phase5-viridian-old-man-projection-implementation.md) and [P5-03 design PASS](../reviews/2026-10-02-viridian-old-man-projection-design-review.md).

## Goal

Define one fail-closed bridge route for the accepted Viridian City Old Man
pre-`ObjectEventState` projection. This plan changes no workflow, patch,
runtime behavior, test, probe, or runner state.

## Exact later Worker surface

Selector `phase5-viridian-old-man-projection` must recognize only
`phase5-viridian-old-man-projection*.patch` and
`phase5-viridian-old-man-projection*.probe` and allow/stage exactly these five
paths:

1. `src/core/ViridianOldManProjection.lua`
2. `main.lua`
3. `tests/phase5_viridian_old_man_projection_test.lua`
4. `work/tasks/phase5-viridian-old-man-projection-implementation.md`
5. `work/reports/phase5-viridian-old-man-projection-implementation.md`

The helper must be pure; `main.lua` is admitted solely for a map-specific,
pre-`ObjectEventState` call site. Focused execution must run only the new
projection test with the selected Lua interpreter. Retain the shared no-ROM
and verified-ROM suites. No route-specific runtime replay applies: this route
projects object state before spawn and explicitly excludes player traversal,
tutorial flow, rendered behavior, and generic script execution.

Publication must individually stage the same five literal paths. Require a
separate one-file probe named
`work/local-runner/probes/phase5-viridian-old-man-projection-route-YYYYMMDD.probe`
after independent configuration review. Its PASS may prove trusted checkout,
selector, Lua toolchain, and supported-ROM SHA only; all patch/tests/replay/
publication steps must skip. One later bounded request remains independently
reviewed.

## Exclusions

No generic route, fallback selector, wildcard allowlist, ROM content, code,
test, probe, or behavior change. Generic script callbacks/VM, other maps or
templates, tutorial movement/battle, parcel progression, map rendering policy,
save semantics, UI, ROM policy, and canonical phase status are excluded.

`work/coordination/LOCAL_RUNNER_BRIDGE.md` may describe the configured route
only during the Orchestrator's separately reviewed configuration change; it is
not a later Worker patch target. If implementation needs any sixth path, stop
for a new contract rather than widening this route.

## Handoff

Independent review must accept this exact plan before the Orchestrator
configures the workflow. Configuration then requires its own review and one
substrate-only probe before any Worker request.

## Review

The independent [route-plan review](../reviews/2026-10-03-viridian-old-man-projection-route-plan-review.md)
accepted exact `4678b4d50f13064e56d23214da20a30267d3da74`. It unlocks only the
separately reviewed configuration task; no request, probe, or implementation
is authorized by this plan review.
