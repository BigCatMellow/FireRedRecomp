# Viridian Old Man projection bridge-route plan — independent review

Verdict: **PASS** — plan only; no configuration or implementation authority.

- Reviewed revision: `4678b4d50f13064e56d23214da20a30267d3da74`.
- Reviewed plan: [P5-04 route](../tasks/local-worker-bridge-phase5-viridian-old-man-projection-route.md).
- Authority: [P5-04 implementation contract](../tasks/phase5-viridian-old-man-projection-implementation.md) and accepted [P5-03 design review](2026-10-02-viridian-old-man-projection-design-review.md).

## Independence and exact scope

This review was performed independently of the plan author. I inspected the
exact commit, its task/register diff, the accepted P5-03 design and P5-04
implementation boundary, plus the current bridge workflow and bridge
procedure. I authored only this review file. The reviewed commit adds the
route-plan task and its derived register row; it changes no workflow, route
configuration, request/probe, runtime, test, ROM, or implementation file.
`git diff --check` passes.

## Selector and literal allowlist

The plan requires one new explicit selector,
`phase5-viridian-old-man-projection`, accepting only the matching `.patch` and
`.probe` filename forms. That is consistent with the workflow's existing
explicit selector/fail-closed default model and cannot reuse a Phase 4 route.

Its five later Worker targets are a minimal subset of the accepted design:

1. pure `src/core/ViridianOldManProjection.lua` helper;
2. `main.lua` only for the Viridian-specific pre-`ObjectEventState` call;
3. one focused projection test;
4. the implementation task; and
5. the implementation evidence report.

The plan requires target validation and publication staging to enumerate those
same five literal paths individually. It excludes the bridge documentation
from later Worker requests and rejects a sixth path, generic fallback,
wildcard, decoder/script-VM, renderer, save, tutorial, traversal, and other
map/template scope. This is consistent with P5-03's one-helper/one-integration/
one-test boundary and preserves the dynamic-ID fail-closed policy rather than
admitting generic graphics resolution.

## Focused, suites, and replay

The proposed focused command is exactly the new no-ROM projection test using
the selected Lua interpreter. The plan correctly retains the shared full
no-ROM and SHA-verified-ROM suites, so bridge publication remains subject to
the existing trusted-checkout, SHA gate, apply/check, and full-suite controls.

An explicit no-runtime-replay branch is appropriate here: the accepted design
is a map-specific, pre-spawn data projection and expressly excludes rendered
behavior, player traversal, tutorial flow, and generic script execution. The
focused test is still required to exercise the three scene values, refusal
controls, local-ID isolation, and unchanged ordinary templates under the later
implementation contract. This no-replay decision must be encoded explicitly
in the configuration, not omitted silently.

## Configuration and probe gates

The plan correctly requires a separate reviewed configuration change to add
the selector, five-target validation, focused command, explicit no-replay arm,
and individual staging to the workflow and to document the route in
`LOCAL_RUNNER_BRIDGE.md`. No Worker patch is authorized by this PASS.

Only after configuration review may one file named
`work/local-runner/probes/phase5-viridian-old-man-projection-route-YYYYMMDD.probe`
be published. The probe must be its commit's sole bridge input and may verify
only trusted checkout, selector recognition, Lua toolchain, and the supported
ROM SHA gate; validation/application, focused/full suites, replay, and
publication must be skipped. A separately reviewed successful probe unlocks
only one bounded Worker request, followed by guarded evidence and independent
implementation review.

Only this review file was authored. No configuration, task, register, code,
request, state, or commit was changed by the Reviewer.
