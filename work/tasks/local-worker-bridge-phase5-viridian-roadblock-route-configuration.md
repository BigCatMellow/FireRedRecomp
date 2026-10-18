# Task: configure the guarded Viridian C0 roadblock bridge route

- Task ID: `P5-06-VIRIDIAN-ROADBLOCK-ROUTE-CONFIG`
- Status: `READY_FOR_WORKER` — adopted after design PASS and PR45 merge; execute from the published coordination authority.
- Type: `IMPLEMENTATION` (bridge configuration only; no gameplay behavior)
- Parent capability gate: [Phase 5/7 first-corridor progression](../roadmaps/CAPABILITY_CHECKLIST.md)
- Assigned role: `WORKER`
- Independent reviewer: separate `REVIEWER`, reviewing the exact configuration
  revision and its safe offline validation evidence
- Prerequisites: independent `PASS` for
  `P5-06-VIRIDIAN-ROADBLOCK-DESIGN` at `1199a74db8dbbeb1528b171159096bd7d90767c5` and merged
  design PR `6006ab6fbc7b9f1dd60a88dcbf6a8b0a08692947`. No probe, request, ROM, or
  guarded ROM/LÖVE replay authority is supplied by this contract; the required
  local no-ROM test suite and repository checker remain permitted.
- Risk: `MEDIUM` — an overly broad route could apply or publish an unauthorized
  patch on the private runner; a too-narrow route must fail closed.
- Adopted bridge/base revision: `6006ab6fbc7b9f1dd60a88dcbf6a8b0a08692947`.
  Execute from the subsequently published coordination authority containing
  this contract; stop to reconcile any intervening workflow/bridge changes.

## Goal

Add one fail-closed, configuration-only Local Worker Bridge route for the
already-designed C0 roadblock implementation package. The route must recognize
only `phase5-viridian-roadblock*.patch` and
`phase5-viridian-roadblock*.probe`. Patches may target only the supplied nine
paths; they need not modify every pre-existing artifact. All nine must exist
after application and before focused evidence, and be rechecked and staged
literally before publication. Wire the supplied six focused commands plus
the existing full suites and replay, and preserve every existing route and
guard.

## Source of truth

- Accepted-and-merged P5-06 C0 design report:
  `work/reports/phase5-viridian-roadblock-design.md` at
  `6006ab6fbc7b9f1dd60a88dcbf6a8b0a08692947`.
- `work/coordination/LOCAL_RUNNER_BRIDGE.md` and
  `.github/workflows/local-worker-bridge.yml` at the adopted base revision.
- This task is a direct compilation of the design report's exact route proposal;
  it does not authorize source, gameplay, ROM, guarded replay, or route-plan
  research. It does authorize the bounded local no-ROM verification named below.
- Unknowns requiring discovery: none. If current bridge structure cannot safely
  express this exact route using only the four allowed outputs, stop and report
  the smallest required additional path; do not improvise a fifth output.

## MAY CHANGE

Exactly these four outputs:

1. `.github/workflows/local-worker-bridge.yml`
2. `work/coordination/LOCAL_RUNNER_BRIDGE.md`
3. `work/tasks/local-worker-bridge-phase5-viridian-roadblock-route-configuration.md`
4. `work/reports/local-worker-bridge-phase5-viridian-roadblock-route-configuration.md`

## MUST NOT CHANGE

- Any runtime, gameplay, source, test, importer, renderer, save/session,
  replay-wrapper, request, probe, ROM, extracted content, or private-path file.
- Canonical coordination, including `STATE.json`, `HANDOFF.md`,
  `TASK_REGISTER.md`, roadmap/capability status, reviews, or active dispatch.
- Existing bridge selectors, target validation, toolchain/ROM hash gate,
  patch-application guards, focused routes, full-suite behavior, replay routes,
  staging/publish behavior, and public-CI behavior.
- Any generic/fallback selector, route reuse, broad glob target allowlist, or
  altered meaning of the projection/shared replay routes.
- A probe/request, runner job, private ROM lookup, guarded ROM/LÖVE runtime
  replay, workflow dispatch, or implementation patch. Configuration validation
  is offline only, except for the required local no-ROM suite and checker.

## Acceptance criteria

1. The workflow maps only
   `phase5-viridian-roadblock*.patch|phase5-viridian-roadblock*.probe` to
   `phase5-viridian-roadblock`; unknown names still fail before patch apply.
   The documentation states that the selector is configuration only until this
   task receives independent `PASS`.
2. For a patch route, target validation permits exactly, and no more than, these
   nine future implementation artifacts:

   1. `src/core/ViridianRoadblock.lua`
   2. `src/core/PlayerMovement.lua`
   3. `main.lua`
   4. `tests/phase5_viridian_roadblock_test.lua`
   5. `tests/phase5_viridian_roadblock_integration_test.lua`
   6. `tests/phase5_viridian_roadblock_rom_test.lua`
   7. `tests/player_movement_test.lua`
   8. `scripts/runtime_viridian_roadblock_replay.sh`
   9. `work/tasks/phase5-viridian-roadblock-implementation.md`

   Require all nine artifacts to exist after patch application and before
   executing the package's focused/full/replay evidence. The publish arm again
   requires all nine to exist as regular files before it stages
   any of them, then stages only those literal paths. Missing one artifact,
   unknown/forbidden patch target, empty/no target patch, failed `git apply
   --check`, or failed `git diff --check` must fail closed without publication.
3. The route-specific focused arm uses the selected existing `$LUA` and runs
   exactly these six commands, in this order:

   ```bash
   "$LUA" tests/phase5_viridian_roadblock_test.lua
   "$LUA" tests/phase5_viridian_roadblock_integration_test.lua
   "$LUA" tests/player_movement_test.lua
   "$LUA" tests/phase5_player_elevation_input_test.lua
   "$LUA" tests/early_story_test.lua
   "$LUA" tests/phase5_viridian_roadblock_rom_test.lua
   ```

   The existing shared suites remain mandatory and unchanged, using exactly
   `env -u POKEPORT_ROM bash scripts/test_all.sh` followed by
   `bash scripts/test_all.sh` in the workflow's already-gated verified-ROM
   environment. This route must not make their ROM fixture or any existing
   suite conditional/optional. Its runtime-replay arm runs only
   `bash scripts/runtime_viridian_roadblock_replay.sh` after those suites.
4. Probe mode recognizes this route but remains readiness-only: it performs no
   target validation/application, focused test, full suite, replay, staging, or
   publication. Documentation says a later **distinct, fresh** readiness probe
   and separate implementation authority are required after configuration PASS;
   a probe proves no gameplay and consumes no implementation authority.
5. Safe offline stub validation proves, without dispatching GitHub Actions,
   touching a private runner, locating/requesting a ROM, or running a guarded
   ROM/LÖVE replay: positive patch/probe selection; unknown selector rejection; all nine
   allowed targets; at least one forbidden target rejection; and failure for
   each of the nine missing-artifact cases before evidence execution and staging. It also verifies the
   exact six-command and replay-arm wiring by static/offline stubs. Record
   commands, complete reproducible temporary-harness source, temporary fixture
   location policy (outside the repository), exit status, and results in the
   report; do not retain a harness as a new repo artifact.
6. The task/report record the design `PASS` and merge revisions, exact changed
   paths, offline evidence, explicit exclusions, and handoff to an independent
   Reviewer. Neither document claims runner readiness, gameplay evidence,
   implementation success, or Phase 5/7 completion.

## Required evidence

- Baseline: before consequential edits, run
  `env -u POKEPORT_ROM bash scripts/test_all.sh`,
  `lua5.1 scripts/check_repository.lua`, and `git diff --check` (the project
  toolchain is available). Record actual commands/results, not proposed ones.
- Focused verification: the safe offline stub/static validation in acceptance
  5, plus syntax/structural validation appropriate to the edited YAML and
  Markdown. No workflow dispatch.
- Final verification: rerun `env -u POKEPORT_ROM bash scripts/test_all.sh`,
  `lua5.1 scripts/check_repository.lua`, and `git diff --check` after edits;
  public no-ROM CI must also pass for this configuration PR. No private runner,
  ROM, verified-ROM suite, guarded runtime replay, probe, request, or workflow
  dispatch is authorized in this task.
- Review evidence: exact published configuration revision and an independent
  review at `work/reviews/<reviewer-chosen-route-config-review-path>.md`; the
  Worker does not create that review.

## Stop / escalate when

- The independent design verdict is not `PASS`, its PR is not merged, or the
  exact adopted revisions cannot be verified from live evidence.
- A change outside the literal four outputs or a tenth future implementation
  artifact is required.
- Exact six-command/full-suite/replay ordering cannot be represented without
  changing existing-route behavior or weakening a guard.
- Validation would require a probe/request, workflow dispatch, ROM/private-runner
  access, or guarded ROM/LÖVE replay.
- The supplied design changes materially after review/merge. Stop for
  Orchestrator reconciliation instead of preserving a stale route plan.

## Completion and handoff

- Worker records: adopted design PASS/merge revisions, configuration revision,
  changed paths, baseline/final no-ROM suite and checker commands/results, the
  complete reproducible temporary-harness command/source and offline results,
  and an explicit statement that no probe/request/ROM/guarded replay occurred.
- Reviewer decides: `PASS | NEEDS_FIX | BLOCK` independently, checking exact
  selector, both literal nine-path allowlists, all-artifact-before-staging
  behavior, six commands, both suites, replay arm, preserved existing routes,
  and offline evidence.
- Orchestrator reconciles: only after reviewer `PASS`, mark this configuration
  leaf accepted according to then-current canonical coordination. It must still
  issue a distinct fresh readiness-probe task/authority, review that receipt,
  and issue separately reviewed implementation authority before any
  `phase5-viridian-roadblock` request. Do not treat this as a second active
  behavior package or advance Phase 5/7.
- Eligible successor: a distinct fresh route-readiness probe task, only after
  configuration PASS and live-state reconciliation; implementation remains a
  separate later authority.
