# Restore HP route configuration — independent review

Verdict: **PASS** for the bounded configuration only.

- Exact revision: `4350aa16edf6e1c7064a5d566f1da63342183ecd`.
- Compared base / parent: `0b01c969d5b9b618bf54de7b9314ed8599de58aa`.
- Task: [P4-F3-ROUTE](../tasks/local-worker-bridge-phase4-restore-hp-route.md).
- Accepted prerequisite: [independent route-plan PASS](2026-10-01-restore-hp-route-plan-review.md).
- Workflow: [Local Worker Bridge](../../.github/workflows/local-worker-bridge.yml).

## Scope and preserved behavior

Independently recovered public main at the exact configuration revision. Read
the route plan, its review, implementation boundary, bridge procedure and
actual workflow. The explicit exact-review dispatch and route task's pending
configuration-review status govern this review; older coordination queue prose
does not grant implementation authority.

The four-path commit contains the workflow, bridge documentation, route task
status/handoff and publication of the preceding independent plan review. There
is no implementation, test, replay script, probe, request, ROM or generated
content. The task's literal surface and requirements are unchanged.
`git diff --check` passes.

The workflow adds exactly five case arms: selector, target allowlist, focused
tests, replay and staging. Independently removing those five arms reproduces
the previous workflow **byte-for-byte**. Existing routes, push/main-only trigger,
runner labels, permissions, concurrency, single-request selection, private SHA
gate, patch checks/application, suite environments, failure behavior and
publication tail are unchanged. Pain Split and inventory are not repurposed.

## Configuration findings

- The selector accepts the reviewed `phase4-restore-hp-effect*.patch` and
  `phase4-restore-hp-effect*.probe` cases only for this new route. Unknown names
  retain the explicit failure branch.
- Validation and staging contain exactly the same nine unique literal paths
  in the reviewed plan: engine, controller, their two focused tests, inventory
  test, Restore HP ROM test, Restore HP replay script, implementation task and
  implementation report. No wildcard path or `main.lua`, importer, save, AI,
  UI-scene, workflow or coordination target is introduced. Existing-file
  staging uses individual `git add -- "$path"` calls.
- The four focused commands use the selected Lua interpreter and run engine,
  controller, inventory and Restore HP ROM tests. The shared no-ROM suite
  explicitly unsets `POKEPORT_ROM`; the later verified-ROM suite receives the
  SHA-verified path. A focused ROM-dependent skip without inherited ROM is not
  acceptance: the later full ROM suite must execute the new fixture and
  inventory without skipping.
- Replay selects `bash scripts/runtime_phase4_restore_hp_replay.sh`; it is not
  an optional/no-replay branch. Its eventual deterministic engine/controller
  trace remains distinct from visible LÖVE or retail presentation evidence.
- All seven implementation steps retain the exact `mode == 'patch'` guard.
  A probe can only exercise checkout, selection, Lua and supported-ROM SHA
  readiness; it cannot apply, test, replay or publish an implementation.

## Independent local validation

Read-only checks used the exact workflow Git object. YAML structure loaded
successfully and **all 12 shell blocks passed `bash -n`**.

The actual selector script accepted four intended patch/probe names, rejected
five unknown/near-prefix/wrong-suffix names, and preserved two neighboring
Pain Split/inventory controls. The actual extracted target-validation loop
accepted each of the nine allowed paths and their combined set, rejected
twelve forbidden or nonliteral paths, and rejected an unknown route. Negative
paths included main, importer, save, AI, UI scene, coordination, workflow,
another effect's replay, the historical inventory report, traversal spelling,
leading `./` and an allowed-name suffix.

Command-stub execution independently confirmed the four focused invocations
and the mandatory replay invocation. Unknown focused, replay and publication
routes failed. Staging-list equality and all seven patch-only guards were
checked separately. These checks exercised route selection/control flow only:
no game tests, patch application, Git staging/publication, runner, ROM or
replay ran. They do not claim a broader audit of the unchanged patch parser or
substitute for its future `git apply --check` and real guarded-run receipt.

## Exact next allowance

After Orchestrator reconciliation, this configuration PASS permits only the
separate planned one-file substrate probe. That probe must pass and receive its
required review before a Worker patch/request may proceed under the separately
bounded implementation contract. No probe receipt, effect support, gameplay
evidence or Phase 4 completion is established here. All ordinary-path
exclusions from the accepted design and implementation contract remain.

Only this review file was authored. No workflow/task/coordination edit, probe,
request, commit, push or dispatch was performed by the Reviewer.
