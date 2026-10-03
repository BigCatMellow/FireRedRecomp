# Viridian Old Man projection bridge configuration — independent review

Verdict: **PASS** — bounded configuration only.

- Reviewed revision: `7a45118319a9458b2c762e34a652fb26c35c91bf`.
- Task: [P5-04 route configuration](../tasks/local-worker-bridge-phase5-viridian-old-man-projection-configuration.md).
- Authority: accepted [route plan](2026-10-03-viridian-old-man-projection-route-plan-review.md), exact `4678b4d50f13064e56d23214da20a30267d3da74`.

## Independence and scope

I reviewed the exact configuration commit independently of its author and
authored only this review file. The exact diff changes only the permitted
workflow, bridge procedure, configuration task, and configuration evidence
report. It contains no implementation helper, `main.lua` change, test,
request/probe, ROM, runner/credential, canonical-status, or other behavior
change. `git diff --check` passes.

## Exact route arms

The workflow adds exactly five route-specific arms, all for
`phase5-viridian-old-man-projection`:

1. selector accepting only matching `.patch` and `.probe` names;
2. patch validation accepting exactly the five reviewed paths;
3. focused execution of only `tests/phase5_viridian_old_man_projection_test.lua`;
4. explicit no-replay message for the pre-spawn, non-traversal route; and
5. individual publication staging of the same five literal paths.

The validation and staging lists are equal and contain precisely:

- `src/core/ViridianOldManProjection.lua`;
- `main.lua`;
- `tests/phase5_viridian_old_man_projection_test.lua`;
- `work/tasks/phase5-viridian-old-man-projection-implementation.md`; and
- `work/reports/phase5-viridian-old-man-projection-implementation.md`.

No wildcard, fallback, bridge-documentation staging, coordination path, or
sixth target is introduced. Existing unknown-route/unauthorized-target failure
branches remain in place. The configuration preserves the shared no-ROM and
SHA-verified-ROM suite commands, private ROM gate, trusted-main trigger,
single-request rule, pre-apply checks, and publication guard.

## Preserved routes and static evidence

Comparison to the parent shows 18 workflow insertions only; removing those
five new arms recovers the prior workflow text. No existing selector,
validation, focused-test, replay, staging, global permission, runner,
concurrency, or shared-suite branch changed. The bridge documentation matches
the same five-path scope and explicitly records the no-replay rationale.

I parsed both the parent and configured workflow as YAML and ran `bash -n` on
the configured extracted shell blocks; both checks passed. The configuration
report accurately limits this evidence to static route/configuration validation,
not a probe, implementation, game test, ROM execution, or publication receipt.

## Probe gate

This PASS authorizes only the route plan's one substrate-only probe after
Orchestrator reconciliation. The probe must be the single changed bridge input
and may establish only trusted checkout, selector, Lua toolchain, and supported
ROM SHA readiness. Patch validation/application, focused/full suites, replay,
and publication must skip. A successful independently reviewed probe is still
required before one bounded Worker request; it is not implementation or Phase
5 completion evidence.

Only this review file was authored. No workflow, task, register, code, request,
state, or commit was changed by the Reviewer.
