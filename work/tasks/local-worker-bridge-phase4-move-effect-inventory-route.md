# Task: dedicated move-effect inventory verification route

- Task ID: `P4-02-ROUTE`
- Status: `BLOCKED` — private runner offline before probe publication
- Type: `INFRASTRUCTURE / BOUNDED ROUTE`
- Parent capability gate: Phase 4 move/effect matrix via [`phase4-move-effect-inventory.md`](phase4-move-effect-inventory.md).
- Assigned role: `WORKER`, after independent readiness review.
- Independent reviewer: separate `REVIEWER` helper.
- Prerequisites: Pain Split independent PASS; inventory contract and this literal route design independently reviewed before configuration.
- Risk: `MEDIUM` — private-runner execution/publishing boundary; preserve fail-closed validation.

## Goal and source of truth

Enable the read-only inventory test on the existing private runner with one
explicit selector and a three-file allowlist. The existing workflow and
[`../coordination/LOCAL_RUNNER_BRIDGE.md`](../coordination/LOCAL_RUNNER_BRIDGE.md)
own its security invariants. Constructor-only trainer routing establishes the
existing explicit no-replay pattern; no generic fallback is permitted.

## MAY CHANGE

- `.github/workflows/local-worker-bridge.yml`: add only selector `phase4-move-effect-inventory` at route selection, validation, focused execution, explicit no-replay case, and individual staging.
- `work/coordination/LOCAL_RUNNER_BRIDGE.md`: document this exact route and its no-replay reason.
- This task: configuration and evidence record.
- After configuration review PASS, one separate probe `work/local-runner/probes/phase4-move-effect-inventory-route-20260920.probe`.

The new route allows exactly:

1. `tests/phase4_move_effect_inventory_test.lua`
2. `work/tasks/phase4-move-effect-inventory.md`
3. `work/reports/phase4-move-effect-inventory.md`

## MUST NOT CHANGE

Other routes, global workflow permissions/triggers/concurrency, trusted-main
dispatch, one-request rule, ROM SHA gate, shared full suites, content policy,
runtime/gameplay, inventory implementation, or phase status. No arbitrary command
execution, broad/glob validation, route fallback, or extra staging paths.

## Acceptance criteria

1. Recognize only the new explicit request/probe prefix using existing conventions.
2. Validate exactly the three paths above and stage each literal path individually when present. Reject every other target before application.
3. Focused execution runs the selected Lua interpreter on `tests/phase4_move_effect_inventory_test.lua`; retain existing full no-ROM and SHA-verified-ROM suites.
4. Add an explicit no-runtime-replay branch stating that inventory changes no runtime behavior; do not silently skip or weaken other routes.
5. Independently review the exact configuration before publishing the separate probe. The probe verifies trusted checkout, selector, Lua and private-ROM SHA; skips patch/tests/publication. Probe PASS unlocks exactly the later inventory Worker request, not a behavior or phase claim.

## Required evidence

- Baseline no-ROM suite; workflow YAML/shell syntax and exact added-case inspection.
- Deterministic allowlist checks: all three valid paths accepted; representative unauthorized source path and unknown selector refused.
- Configuration review tied to exact commit; guarded probe run tied to separate probe commit.
- No gameplay replay is applicable to route maintenance.

## Stop / escalate when

Existing workflow behavior must change, any path/command scope needs widening,
the route cannot fail closed, configuration review fails, or the private runner
or ROM gate fails. Record exact blocker and preserve prior evidence.

## Completion and handoff

Worker returns configuration diff and checks. Independent Reviewer decides
PASS / NEEDS_FIX / BLOCK. After PASS, publish one probe and record its exact run.
Orchestrator then dispatches the inventory request from `P4-02`. Source-only
inventory preparation may occur in parallel in its separate output paths, but
cannot satisfy the ROM gate or authorize request publication before this route.

## Dispatch — 2026-09-20

Pain Split independent implementation PASS is recorded at `a739ddc`.
[Independent readiness review](../reviews/2026-09-20-move-effect-inventory-readiness-review.md)
passed this literal route design. Worker may now configure only the listed
route/documentation paths and return the exact commit for independent review.
The separate probe remains forbidden until that configuration review passes.
Existing full-suite evidence is 149 no-ROM and 149 verified-ROM files; local
toolchain is available for proportionate baseline and syntax/allowlist checks.

## Worker configuration evidence — 2026-09-20

Configured on local authorization base `82af910`; independent live recovery
returned `a739ddc88cb44a33d5e6025e619cf1df3fe6a1a8`. The workflow adds exactly
five cases: explicit request/probe selection, three literal allowed targets,
the selected-interpreter focused inventory command, an explicit no-runtime-replay
message, and individual staging of those same three paths. Removing these five
added cases reproduces the previous workflow byte-for-byte, preserving all
existing routes and shared security/test behavior. Route documentation records
the focused-ROM skip limitation and mandatory full SHA-ROM inventory execution.

Verification passed:

- Before and after configuration, `PATH=/home/home/.local/share/firered-toolchain/bin:$PATH env -u POKEPORT_ROM bash scripts/test_all.sh` passed all 149 test files.
- PyYAML parsed the workflow; `bash -n` accepted all 12 extracted run blocks.
- Executing the actual validation case accepted all three authorized targets;
  rejected seven unauthorized targets (source, workflow, coordination, suffix,
  traversal, nested-path, and wildcard examples); and rejected an unknown route.
- Executing the actual selector accepted the new request and probe names;
  rejected unknown request/probe prefixes and an unsupported extension.
- Focused-command and staging inspection confirmed exactly the selected Lua
  invocation and the three individual literal paths. Executing the actual replay
  case emitted the explicit read-only/no-runtime-behavior message.
- `git diff --check` passed.

The one-off local validation harness initially needed an indentation correction
in its extraction regex; the final complete check passed without any workflow
change. No inventory implementation, ROM execution, publication, or probe was
performed in this package. Independent configuration review must pass before
the separate probe; no capability or phase completion is claimed.

## Configuration acceptance and probe authorization

[Independent configuration review](../reviews/2026-09-20-move-effect-inventory-route-review.md)
passes exact `82af910..24f39c424347425be9836e16d529c7706641aa93`.
Orchestrator authorizes exactly the separately named one-file probe above.
Worker may commit/push that probe and inspect its guarded run; do not add a
request, change configuration, or claim inventory evidence. Trusted checkout,
route selection, Lua and SHA checks must pass; patch/test/publication steps
must be skipped. On success return exact commit/run for reconciliation and
inventory-request eligibility. On failure record the exact blocker.

## Probe preflight blocker — 2026-09-20

Worker's read-only runner query returned `firered-mint: offline, busy=false`.
No probe file, probe commit, request, or workflow was created. Configuration
PASS remains valid. Resume the same single authorized probe when the runner
returns online; do not manufacture a duplicate or bypass the private-ROM gate.
Source inventory preparation and independent no-ROM roadmap work may continue.
