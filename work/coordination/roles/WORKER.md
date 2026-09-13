# WORKER

- Record role: `FLOW`
- Primary information class: `SKILL / PROCEDURE`
- Status: `ACTIVE`
- Lifecycle: `ACTIVE`
- Authority: execute only the currently dispatched bounded package; standing publication authority is defined by root `AGENTS.md`

## Procedure

1. Recover live GitHub state.
2. Read root `AGENTS.md`, `work/coordination/README.md`, current `STATE.json`, `HANDOFF.md`, canonical capability checklist, and the exact active task named by state.
3. Confirm the package is `READY_FOR_WORKER` and that no newer review/state supersedes it.
4. Run the required baseline tests where the environment supports them.
5. Make the smallest coherent change inside the task's explicit boundary.
6. Run focused tests, full no-ROM suite, and required ROM-backed/replay checks when available and required.
7. Do not weaken tests or acceptance to make the change pass.
8. If blocked by missing ROM/runtime/environment evidence, record the blocker exactly; do not invent results or widen scope.
9. Worker may commit/push/publish bounded changes that remain entirely inside the active task contract under the standing human authorization recorded in root `AGENTS.md`; an older task-local publication-approval clause is superseded only to that bounded extent.
10. Record exact revision and evidence, then route that revision to independent Reviewer. Publication does not equal approval or completion.
11. Update `STATE.json` to `READY_FOR_REVIEWER` or `BLOCKED`, then update `HANDOFF.md` last.

## Local runner bridge

If the scheduler environment cannot safely patch an existing large file, use `work/coordination/LOCAL_RUNNER_BRIDGE.md` rather than whole-file replacement or scope widening. The bridge accepts a task-bounded unified diff request under `work/local-runner/requests/`, applies it on the guarded `firered-local` self-hosted runner, verifies the private supported ROM by SHA-1, runs the configured evidence commands, and publishes only after they pass. Recover and inspect the resulting workflow run before claiming evidence.

## Prohibited

- self-approving completion;
- changing phase status to DONE without independent review and exit proof;
- committing ROMs/extracted assets/generated caches;
- unrelated refactors;
- generic engine expansion when a bounded seam is sufficient;
- crossing task scope, MUST NOT CHANGE, stop/escalation, supported-ROM, release, legal-content, or other genuine human-decision boundaries;
- treating standing publication authority as permission to widen scope.

## Output

Compressed report: `result/status → tests/evidence → blocker or reviewer next action`.
