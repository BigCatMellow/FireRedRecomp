# FireRedRecomp resume handoff — Magnitude route plan

- Created: 2026-10-10
- Repository: `BigCatMellow/FireRedRecomp`
- Published `main` at handoff: `7c1baa3` — `Plan Magnitude bridge route`
- Local worktree: `/tmp/firered-outcome-reconcile` (detached HEAD at the same commit; clean)
- Execution state: active, no private-ROM operation in progress

## Current truth

The active task is
[`P4-F3-MAGNITUDE-ROUTE-PLAN`](../tasks/local-worker-bridge-phase4-magnitude-route-plan.md),
status `READY_FOR_WORKER`.  It is documentation-only and exists because the
independently reviewed Magnitude design needs a new explicit guarded workflow
route before any future implementation request can be considered.

The accepted chain is:

1. Rerank PASS: `23d0b46` — selected Magnitude, effect 126 / move 222.
2. Source lock PASS: `5770a4d` / `21d8d43`.
3. Design: `6058b7c`; independent PASS review: `ff326c5`.
4. Reconciliation and this active route-plan task: `7c1baa3`.

The accepted design is at
[`phase4-magnitude-design.md`](../reports/phase4-magnitude-design.md).  Its
important rule is one `% 100` Magnitude draw after PP and before the current
single-target accuracy/hit path, with a local non-mutating power copy and an
ordered `{type="magnitude", side=, level=}` event.  The existing first-player
`firstBattle` accuracy bypass is deliberately retained: it makes that bounded
hit a three-draw path rather than the ordinary four-draw path.

## Immediate next action

Delegate the route-plan task to a fresh, high-effort researcher, then delegate
its exact draft to a separate high-effort reviewer.  The researcher may change
only:

- `work/reports/phase4-magnitude-route-plan.md`
- the task's handoff section

The plan must inspect the current bridge workflow and analogous reviewed
Phase 4 routes. It must specify a literal selector, literal later patch
allowlist, focused no-ROM and SHA-ROM checks, replay policy, staging list, and
whether a readiness probe is needed. It must not edit the workflow, create a
request/probe, run ROM work, or authorize implementation.

After independent PASS, commit/push the two-file plan and its review, then
reconcile the task/register/state before compiling the next route-configuration
task. Do not start Magnitude implementation directly.

## Operating boundaries

- Read `AGENTS.md`, then the active task, `STATE.json`, `TASK_REGISTER.md`,
  and this handoff before acting.
- Preserve the player-supplied-ROM model. Never commit or disclose ROMs,
  paths, extracted data, BIOS, screenshots, or secrets.
- The MediaCenter runner is already proven for checkout, route, Lua 5.1, and
  private-ROM SHA substrate. That does not authorize a new patch or revive an
  exhausted artifact.
- Use helpers for work that benefits from independent reasoning: source/route
  research and consequential review. Keep orchestration, evidence
  reconciliation, task boundaries, and GitHub publication with the primary
  agent.
- hcom is not required. It is installed but had a stale relay at handoff;
  do not start or transplant it merely to dispatch native helpers.

## Interrupted work

A high-effort researcher had been dispatched for this route plan but was
interrupted before it wrote any file. There are no uncommitted changes to
recover and no partial report to trust.

## Verification before resuming

```bash
git -C /tmp/firered-outcome-reconcile status --short --branch
git -C /tmp/firered-outcome-reconcile log --oneline -8
sed -n '1,220p' /tmp/firered-outcome-reconcile/work/tasks/local-worker-bridge-phase4-magnitude-route-plan.md
```

If `main` moved, recover current GitHub state first and compare the active task
and coordination records before dispatching a replacement researcher.
