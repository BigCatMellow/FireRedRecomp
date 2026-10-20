# FireRedRecomp model, delegation, and process-improvement policy

- Status: ACTIVE
- Authority: user-approved project operating guidance, subordinate to the
  repository task contracts, evidence gates, legal/content boundaries, and
  newer explicit human direction
- Scope: model selection, reasoning effort, role assignment, delegation
  quality, and continuous improvement for the FireRedRecomp goal
- Last reviewed: 2026-10-17

## Purpose

Use the strongest reasoning where it changes project outcomes, and use lighter
models for bounded or repetitive work. Model choice must improve successful
task completion, evidence quality, continuity, and throughput; it is not a
status signal and does not expand task authority.

OpenAI's current guidance describes Astra as the highest-capability option,
GPT-5.6 Sol as a lower-cost option for complex technical work, Terra as a
balance of intelligence and cost, and Luna as the efficient option for scoped
or high-volume work. See the [official model-selection guidance](https://developers.openai.com/api/docs/guides/model-selection),
[reasoning guidance](https://developers.openai.com/api/docs/guides/reasoning),
and [current model guidance](https://developers.openai.com/api/docs/guides/deployment-checklist).
These references guide routing; repository evidence decides whether routing is
working.

## Default routing

| Role or work shape | Default model | Default effort | Raise effort/model when |
| --- | --- | --- | --- |
| Orchestrator: conflicting source evidence, milestone reconciliation, next-gate selection, high-risk scope decisions | Astra | medium | Use Astra high for unresolved source/runtime ambiguity, evidence conflicts, or a consequential reconciliation. Reserve xhigh/max for a documented failure at a lower setting. |
| Worker: bounded implementation, debugging, production wiring, source-backed design | GPT-5.6 Sol | medium | Use Sol high for difficult implementation or cross-file debugging; use Astra when the task combines unusually ambiguous source behavior with broad reasoning. |
| Reviewer: independent code/source/evidence review | GPT-5.6 Sol | medium/high | Use Astra medium/high for a difficult review involving multiple competing source interpretations or a high-risk persistence/runtime change. |
| Bounded research, task contracts, handoffs, test interpretation, coordination updates | GPT-5.6 Terra | medium | Use Sol when the work requires substantial technical synthesis; use Luna when it is mechanical. |
| Search, inventory, polling, receipts, formatting, simple documentation edits | GPT-5.6 Luna | low/medium | Raise to Terra only when the task stops being mechanical or ambiguity appears. |

These are defaults, not automatic substitutions. Preserve the active task's
role and acceptance criteria when changing models. Lower effort is preferred
when it produces the same accepted result. Do not use `xhigh` or `max` merely
because the task is important; use them only when a representative failure
shows that a lower setting cannot meet the evidence bar.

## Orchestrator responsibilities

The Orchestrator owns the project-level decision, not every piece of work.
At each resume it must:

1. Recover live GitHub state, local changes, jobs, and the durable checkpoint.
2. Identify the smallest unmet gate using the capability checklist, active task,
   exact reviews, and current evidence.
3. Choose the least expensive model/effort that can safely perform the current
   role, recording an escalation reason when using Astra high or above.
4. Compile one bounded package with explicit paths, exclusions, evidence and
   stop conditions.
5. Delegate implementation or research to a Worker and independent verification
   to a separate Reviewer. Never let a Worker self-review its own change.
6. Reconcile only what the Reviewer and required evidence prove. A green test,
   a Worker claim, a model's confidence, or a merged code path alone is not a
   phase or roadmap exit.
7. Select the next package automatically after closure. Do not ask the user to
   choose routine next steps or repeatedly transfer a handoff.

The Orchestrator should spend its expensive reasoning budget on choices that
can change scope, evidence, or project direction. It should not spend Astra
effort re-reading accepted work, rewriting receipts, or performing mechanical
status checks.

## Worker responsibilities

The Worker executes only the active contract. It must:

- recover the exact authority and worktree before editing;
- run the required baseline before consequential changes when possible;
- make the smallest coherent change inside the allowlist;
- record actual commands and results separately from proposed evidence;
- preserve UNKNOWN when source/runtime behavior is unresolved;
- publish only task-bounded work under the standing publication authority;
- route the exact revision and evidence to the independent Reviewer; and
- never mark its own work accepted or widen the task because a stronger model
  suggested an adjacent improvement.

If a Worker reaches a model or environment limit, it must leave a durable
checkpoint containing the exact worktree, revision, changed paths, completed
checks, unfinished checks, blocker, and one next action. It must not create a
replacement task or duplicate research merely to continue producing output.

## Reviewer responsibilities

The Reviewer starts from the exact published revision and reconstructs the
acceptance independently. It must inspect source, changed paths, assertions,
scope, and claimed evidence; rerun deterministic checks when practical; and
return exactly PASS, NEEDS_FIX, or BLOCK. It must not add requirements after
the fact, implement its own correction, or convert missing ROM/replay evidence
into an implied pass.

For a difficult review, spend more reasoning on failure modes and evidence
provenance rather than restating the Worker report. A useful review identifies
the smallest correction or the precise missing prerequisite.

## Delegation rules

Use parallel work only when the packages have independent changed paths,
dependencies, and evidence gates. Keep one behavior-changing critical-path
package active by default. Reviews may run in parallel with unrelated research,
but never review a moving or unpublished implementation head.

Before delegating, the Orchestrator records:

- role and model/effort selection;
- exact task and allowed paths;
- prerequisite revision and evidence;
- stop conditions and external blockers;
- expected deliverable and review handoff; and
- the reason a lighter model was insufficient, if escalating.

Do not split a task merely to create more agent activity. Do split when the
source lock, implementation, or review has a genuinely independent boundary.
Do not assign the same source investigation to multiple agents unless the
purpose is explicitly independent verification.

## Continuation and pause behavior

`/goal resume` must continue from the durable checkpoint, not from memory of
the last chat turn. A pause preserves the active task, worktree, exact revision,
and pending evidence. On resume:

1. verify remote and local state;
2. recover the active role and exact next action;
3. inspect whether a job, review, or usage limit changed the state;
4. continue the existing worktree when it is clean and authorized; and
5. only create a new worktree when the old one is unavailable or the task
   contract explicitly requires a new isolation boundary.

Usage limits are operational interruptions, not evidence of task failure. Record
them, preserve work, and avoid repeating completed research after recovery.

## Process-improvement record

After each material package closure or interruption, perform one brief review of
the process. Record only concrete observations in the active handoff or a
future entry below; do not create ceremony without a demonstrated problem.

Track these measures when available:

- first-review PASS versus NEEDS_FIX/BLOCK;
- number of correction or re-tracing cycles;
- tool turns and usage-limit interruptions;
- baseline, focused, full-suite, and guarded-evidence time;
- whether the chosen model/effort was escalated and why; and
- whether the package produced a durable next action without user selection.

Interpret results as follows:

- repeated first-review PASS with unnecessary latency or interruptions means
  lower the default model or effort for that work shape;
- repeated scope errors, missed source distinctions, or review corrections mean
  raise effort or route the package to Sol/Astra and improve the task contract;
- repeated duplicate research means improve checkpointing or source-of-truth
  routing before changing models;
- repeated Worker/Reviewer disagreement means clarify acceptance and evidence
  or strengthen the independent review boundary; and
- a model change is justified by comparable package results, not anecdotal
  preference or a single unusually easy/hard task.

Current qualitative observation: Astra has produced high-quality orchestration,
source reconciliation, and independently accepted FireRed changes, but the
project has also experienced repeated usage-limit interruptions and spent Astra
effort on mechanical coordination. The current hypothesis is to retain Astra
for difficult orchestration/reconciliation and route routine research,
implementation, review, and receipts to Sol/Terra/Luna according to the table
above. This hypothesis should be revisited after approximately ten comparable
packages using the measures above. No exact token/cost conclusion is claimed
because this repository does not contain complete model telemetry.

## Boundaries

This policy does not override AGENTS.md, a narrower task contract, a review
verdict, the capability checklist, supported-ROM policy, legal/content rules,
or a human-only decision. Model capability never authorizes broader scope,
private ROM access, release publication, credentials, purchases, or phase
completion.
