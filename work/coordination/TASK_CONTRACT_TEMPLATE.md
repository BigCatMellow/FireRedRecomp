# FireRedRecomp Bounded Task Contract Template

- Record role: `TEMPLATE`
- Primary information class: `SKILL / PROCEDURE`
- Status: `ACTIVE`
- Lifecycle: `ACTIVE`
- Authority: task-compilation template; a completed instance becomes task
  context but does not override root `AGENTS.md` or human direction
- Accountable owner: `ORCHESTRATOR`
- Register: [`TASK_REGISTER.md`](TASK_REGISTER.md)

## Use

Copy this file into `work/tasks/<stable-task-id>.md`. Complete every required
field before dispatch. If a field cannot be filled from evidence, dispatch a
research/discovery task instead of guessing in an implementation task.

```markdown
# Task: <short outcome name>

- Task ID: `<PHASE-AREA-NN>`
- Status: `OPEN | ACKNOWLEDGED | READY_FOR_WORKER | READY_FOR_REVIEWER |
  REVIEWED_PASS | REVIEWED_NEEDS_FIX | BLOCKED | CLOSED | SUPERSEDED`
- Type: `RESEARCH | DESIGN | IMPLEMENTATION | REVIEW | RECONCILIATION`
- Parent capability gate: `<exact row/link in CAPABILITY_CHECKLIST.md>`
- Assigned role: `ORCHESTRATOR | RESEARCHER | WORKER | REVIEWER | USER`
- Independent reviewer: `<role/identity or N/A for non-consequential research>`
- Prerequisites: `<exact passed task/revision, environment, or user input>`
- Risk: `LOW | MEDIUM | HIGH` — `<one-sentence downside/reversibility>`

## Goal

<One observable outcome. No bundled adjacent features.>

## Source of truth

- `<source/ROM file, canonical task, design, or evidence link>`
- Unknowns requiring discovery: `<none, or list>`

## MAY CHANGE

- `<literal files/behavior boundaries>`

## MUST NOT CHANGE

- `<literal exclusions, phase boundaries, legal-content boundary>`

## Acceptance criteria

1. `<observable behavior/artifact>`
2. `<boundary/regression condition>`
3. `<required evidence>`

## Required evidence

- Baseline: `<command/result or explicit N/A>`
- Focused verification: `<command/fixture/replay>`
- Full verification: `<no-ROM / verified-ROM / runtime command, or justified N/A>`
- Review evidence: `<exact revision and independent review path>`

## Stop / escalate when

- `<missing authority, source uncertainty, required state not represented,
  external input, scope expansion, or prohibited content>`

## Completion and handoff

- Worker records: `<revision, changed paths, exact commands/results>`
- Reviewer decides: `PASS | NEEDS_FIX | BLOCK`
- Orchestrator reconciles: `<register/state/handoff/capability update rule>`
- Eligible successor: `<task ID or explicit none>`
```

## Fresh-worker readiness gate

An Orchestrator marks a task `READY_FOR_WORKER` only when all answers below
are yes:

1. Is the parent capability row and smallest unmet gate named?
2. Is the requested outcome observable and bounded to one coherent leaf?
3. Are source/ROM facts either supplied or explicitly delegated to discovery?
4. Are MAY CHANGE and MUST NOT CHANGE concrete enough to detect widening?
5. Can a Worker run the required evidence without inventing commands or
   acceptance criteria?
6. Is an independent reviewer and exact handoff condition named?
7. Are external authority/ROM/reference-media needs called out as blocks?

If any answer is no, keep the task `OPEN` and compile the missing research or
design prerequisite first.
