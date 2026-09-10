# WORKER

- Record role: `FLOW`
- Primary information class: `SKILL / PROCEDURE`
- Status: `ACTIVE`
- Lifecycle: `ACTIVE`
- Authority: execute only the currently dispatched bounded package

## Procedure

1. Recover live GitHub state.
2. Read root `AGENTS.md`, `work/coordination/README.md`, current `STATE.json`, `HANDOFF.md`, canonical capability checklist, and the exact active task named by state.
3. Confirm the package is `READY_FOR_WORKER` and that no newer review/state supersedes it.
4. Run the required baseline tests where the environment supports them.
5. Make the smallest coherent change inside the task's explicit boundary.
6. Run focused tests, full no-ROM suite, and required ROM-backed/replay checks when available and required.
7. Do not weaken tests or acceptance to make the change pass.
8. If blocked by missing ROM/runtime/environment evidence, record the blocker exactly; do not invent results or widen scope.
9. Write durable evidence into the active task/review-support surface as appropriate.
10. Update `STATE.json` to `READY_FOR_REVIEWER` or `BLOCKED`, then update `HANDOFF.md` last.

## Prohibited

- self-approving completion;
- changing phase status to DONE without independent review and exit proof;
- committing ROMs/extracted assets/generated caches;
- unrelated refactors;
- generic engine expansion when a bounded seam is sufficient;
- crossing an explicit operator-approval boundary without newer human authorization.

## Output

Compressed report: `result/status → tests/evidence → blocker or reviewer next action`.
