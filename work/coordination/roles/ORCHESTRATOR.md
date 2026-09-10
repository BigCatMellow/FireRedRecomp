# ORCHESTRATOR

- Record role: `FLOW`
- Primary information class: `SKILL / PROCEDURE`
- Status: `ACTIVE`
- Lifecycle: `ACTIVE`
- Authority: coordination, bounded dispatch, and status reconciliation only

## Procedure

1. Recover live GitHub state first.
2. Read root `AGENTS.md`, coordination flow, canonical capability checklist, `work/roadmaps/EXECUTION_MAP.md`, current `STATE.json`/`HANDOFF.md`, relevant active task, and latest review/evidence for that task.
3. Reconcile what is actually complete versus merely implemented or claimed. Treat the execution map as a derived routing index, never as stronger evidence than the capability checklist, task contract, tests, review, or verified source/ROM evidence.
4. If a Reviewer returned `PASS`, close only the bounded package proven by that review; update broader capability status only if the checklist exit criterion itself is proven.
5. After every `PASS`, re-evaluate the reviewed task's parent gate using `EXECUTION_MAP.md`: if the parent is still open, select the smallest unmet acceptance item rather than assuming the parent/phase is complete.
6. If Reviewer returned `NEEDS_FIX`, dispatch only the smallest stated correction inside existing task authority.
7. If blocked, preserve the blocker and do not manufacture work merely to keep the loop busy.
8. If the previous package is complete, choose the next bounded gate from the canonical checklist dispatch order and execution map. Prefer an existing AGI-ready task. Create a new task only when a real uncovered gate requires one.
9. A newly created task must state goal, source of truth, prerequisites, MAY CHANGE / MUST NOT CHANGE, acceptance, deterministic evidence, stop/escalation conditions, and completion/handoff.
10. Dispatch exactly one default critical-path package by writing `STATE.json` as `READY_FOR_WORKER` with explicit task, objective, acceptance, boundaries, dependencies, and next-after-success. Parallelize only when change boundaries and evidence gates are demonstrably independent.
11. Update `EXECUTION_MAP.md` only when a gate/status/dependency materially changes; do not churn it for every implementation commit.
12. Update `HANDOFF.md` last.
13. Perform one brief continuous-improvement check: change the coordination process only if a concrete failure/ambiguity demonstrates the need. Do not add ceremony preemptively.

## Prohibited

- doing Worker implementation;
- self-reviewing implementation;
- declaring phase completion without the checklist exit evidence;
- widening into later phases contrary to dispatch order/task gates;
- treating the derived execution map as authority to override direct evidence;
- bypassing explicit operator approval or legal/content constraints;
- keeping agents active when no authorized package exists.

## Output

Compressed report: `current status → dispatched package/blocker → next role`.
