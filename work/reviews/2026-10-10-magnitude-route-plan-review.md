# Magnitude guarded bridge route plan — independent review

Verdict: **PASS** for the exact uncommitted
`P4-F3-MAGNITUDE-ROUTE-PLAN` draft. It is bounded and fail-closed as a plan
for one later route-configuration task only. This PASS grants no configuration,
probe, request, implementation, ROM, runner, replay, test, behavior, or
capability-status authority.

## Independence and exact scope

I did not author or alter the draft, task handoff, workflow, configuration,
request/probe, implementation, coordination, or any runtime/test artifact. I
independently read `AGENTS.md`, the active task, accepted Magnitude source
lock/design/design review, current bridge workflow, and the reviewed Restore
HP and P5 route-plan/configuration records.

The exact reviewed artifacts are:

- the new `work/reports/phase4-magnitude-route-plan.md` (SHA-256
  `a78b7c98d40bd493089d012c7ff4129462378db1ccc6f8f069032d74f280d68e`); and
- the 12-line researcher handoff appended to
  `work/tasks/local-worker-bridge-phase4-magnitude-route-plan.md` (SHA-256
  `1c00113fcf302fb1a1eaff1af30b7d7c3100dece6d2acfa07373cea111fd269a`).

The review-time diff contains only that report, the permitted task-handoff
addition, and this review artifact. No workflow, bridge configuration,
request/probe, runtime/test, ROM/runner, implementation, coordination, or
status file changed. `git diff --check` was run observationally and exited 0
with no diagnostics.

## Findings

1. **Selector and fail-closed route shape are correct.** The proposed sole
   route is `phase4-magnitude-effect`, with only
   `phase4-magnitude-effect*.patch` and
   `phase4-magnitude-effect*.probe` forms. That follows the current explicit
   selector model and preserves its unknown-route failure; it neither reuses a
   neighboring Phase 4 route nor adds a fallback.
2. **The planned patch surface is symmetric and justified.** Validation and
   staging each name the same nine literal paths: the two accepted owners,
   their two regression tests, the inventory test, a Magnitude ROM fixture,
   a Magnitude replay, and the future implementation task/report. This is the
   exact nine-path Restore HP pattern adapted to Magnitude's accepted
   engine/controller/event and ROM-record seams. It prohibits wildcards,
   directory expansion, an optional extra test, staging-only files, `main.lua`,
   importer/data-model, save, AI, UI-scene, workflow, coordination, and other
   effect-family paths. Requiring the existing per-path `git add -- "$path"`
   staging convention is correct.
3. **Focused tests are literal and sufficient for the proposed boundary.**
   In order, the four `$LUA` commands are engine, controller, inventory, and
   the new Magnitude ROM fixture. They match the current selected-interpreter
   convention and the Restore HP analogue. The plan correctly says a focused
   fixture's no-ROM skip is not acceptance and requires non-skipped inventory
   and Magnitude fixture coverage in the verified-ROM full suite.
4. **Suite commands are now exact.** The stated no-ROM command,
   `env -u POKEPORT_ROM bash scripts/test_all.sh`, exactly matches the bridge.
   The corrected SHA-ROM description also matches it: the verified-ROM suite
   sets step-level `POKEPORT_ROM: ${{ steps.rom.outputs.path }}` and runs
   exactly `bash scripts/test_all.sh`. Thus it preserves the current command
   and private-hash gate instead of substituting an inline environment
   assignment. The plan correctly requires the full SHA-ROM suite to execute
   the inventory aggregate and new Magnitude fixture non-skipped.
5. **Replay policy is correct.** The required
   `bash scripts/runtime_phase4_magnitude_replay.sh` branch is appropriate for
   the accepted single `% 100` draw, ordered level event, normal hit/miss draw
   counts, and retained `firstBattle` accuracy-bypass case. Its proposed
   headless represented-trace boundary correctly excludes LÖVE rendering,
   retail text/timing, doubles/target loops, and ROM capture.
6. **Probe gate is correct and constrained.** After a separately reviewed
   configuration only, the one named
   `work/local-runner/probes/phase4-magnitude-effect-route-YYYYMMDD.probe`
   may establish trusted checkout, selection, Lua, and the existing supported
   SHA gate. Patch validation/application, focused/full suites, replay,
   staging, commit, and publication must skip. That matches the reviewed
   Restore HP/P5 substrate-only pattern and cannot serve as behavior evidence.
7. **No scope breach is present.** The report preserves trusted-main,
   one-input, selected-toolchain, private SHA, apply/check, full-suite, and
   unknown-route guards. It retains all accepted Magnitude exclusions:
   target traversal/reselection, doubles/absent battlers, Underground,
   abilities/items, status/cancellation expansion, Substitute/MoveEnd,
   visual timing/animation/localization/links, retail-turn parity, and generic
   dynamic-power work. It grants only a later route-configuration successor;
   it does not modify or authorize a route, probe, request, runtime/test,
   ROM/runner, or implementation action.

## Exact next allowance

The Orchestrator may compile only a separate bounded route-configuration
successor encoding this plan, followed by its own independent review. This PASS
does **not** authorize the bridge edit itself, a readiness probe, a
patch/request, Magnitude implementation, ROM/runner execution, or
status/phase advancement. Only an independently accepted route-configuration
successor may modify the bridge; its later review/probe gates remain required
before one separately bounded implementation request.
