# ORCHESTRATOR

- Record role: `FLOW`
- Primary information class: `SKILL / PROCEDURE`
- Status: `ACTIVE`
- Lifecycle: `ACTIVE`
- Authority: coordination, bounded dispatch, and status reconciliation only

## Procedure

1. Recover live GitHub state first.
2. Read root `AGENTS.md`, coordination flow, canonical capability checklist, current `STATE.json`/`HANDOFF.md`, relevant active task, and latest review/evidence for that task.
3. Reconcile what is actually complete versus merely implemented or claimed.
4. If a Reviewer returned `PASS`, close only the bounded package proven by that review; update broader capability status only if the checklist exit criterion itself is proven.
5. If Reviewer returned `NEEDS_FIX`, dispatch only the smallest stated correction inside existing task authority.
6. If blocked, preserve the blocker and do not manufacture work merely to keep the loop busy.
7. If the previous package is complete, choose the next item from the canonical checklist dispatch order and existing task graph. Prefer an existing AGI-ready task. Create a new task only when a real gap requires one.
8. Dispatch exactly one package by writing `STATE.json` as `READY_FOR_WORKER` with explicit task, objective, acceptance, boundaries, dependencies, and next-after-success.
9. Update `HANDOFF.md` last.
10. Perform one brief continuous-improvement check: change the coordination process only if a concrete failure/ambiguity demonstrates the need. Do not add ceremony preemptively.

## Prohibited

- doing Worker implementation;
- self-reviewing implementation;
- declaring phase completion without the checklist exit evidence;
- widening into later phases contrary to dispatch order/task gates;
- bypassing explicit operator approval or legal/content constraints;
- keeping agents active when no authorized package exists.

## Output

Compressed report: `current status → dispatched package/blocker → next role`.
