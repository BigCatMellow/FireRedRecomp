# FireRedRecomp Agent Operating Contract

- Record role: `REFERENCE`
- Primary information class: `AUTHORITY / INVARIANT`
- Status: `ACTIVE`
- Lifecycle: `ACTIVE`
- Authority: repository-wide operating contract; subordinate to explicit human direction and narrower task/review contracts except where a newer explicit human authorization supersedes an older narrower publication gate
- Accountable owner: human project owner
- Canonical owner for repository-wide agent rules: this file

This is the entry contract for fresh agents working in `BigCatMellow/FireRedRecomp`.

## Source-of-truth order

Recover live GitHub state first. Then use, in order:

1. this file for repository-wide operating rules;
2. `work/roadmaps/CAPABILITY_CHECKLIST.md` for project-wide capability status and dispatch order;
3. the active file under `work/tasks/` for bounded implementation authority and acceptance;
4. current `work/coordination/STATE.json`, `work/coordination/HANDOFF.md`, and `work/coordination/TASK_REGISTER.md` for coordination state and task lifecycle;
5. `docs/roadmap.md` and `docs/handoffs/firered-recomp-checklist.md` for deeper roadmap/history.

Model routing, delegation, and process-improvement guidance is maintained in
[`work/coordination/MODEL_AND_DELEGATION_POLICY.md`](work/coordination/MODEL_AND_DELEGATION_POLICY.md).
It is subordinate to this contract and the active task, but every Orchestrator,
Worker, and Reviewer should apply it when selecting effort and handing off work.

Do not let README prose or an older handoff override newer direct evidence.

## Core rules

1. **Evidence gates status.** Roadmap prose, code existence, or a Worker claim does not make a phase `DONE`. Update `work/roadmaps/CAPABILITY_CHECKLIST.md` only when its exit gate is actually proven.
2. **Smallest bounded change.** Follow the active task's MAY CHANGE / MUST NOT CHANGE / stop conditions. Do not expand into adjacent phases because they are convenient.
3. **Test before and after.** Run the no-ROM suite before consequential implementation when possible and again after. Run ROM-backed/replay checks when the task requires them and a verified ROM environment is available.
4. **No ROM or extracted game content in git.** Never commit ROMs, BIOS files, generated caches, screenshots/assets extracted from the game, or other copyrighted game data. Preserve the player-supplied-ROM model.
5. **Verified ROM is evidence, not repository content.** FireRed US v1.0 SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc` is the currently supported target.
6. **Independent review for consequential completion.** Worker implements and reports evidence. Reviewer independently checks the exact change against the existing task criteria. Worker may not self-certify a phase gate.
7. **Capability is not authority.** Tools, local ROM access, test fixtures, model capability, or scheduler execution do not expand the active task boundary.
8. **No invented parity.** If source/ROM behavior is uncertain, record `UNKNOWN` and stop/escalate when the task requires source certainty.
9. **Preserve deterministic evidence.** Prefer tests/replays/source-lock fixtures over manual inspection. Manual evidence must be explicit and bounded.
10. **Do not redo passed work.** Recover current commits, task progress, reviews, and coordination handoff before implementing.
11. **Fresh-agent safe.** Durable state must be sufficient to continue without hidden chat context.
12. **No hype.** Report result → evidence → blocker/next action.

## Current dispatch

**User-adopted persistent goal, 2026-10-11:** the user explicitly activated
[`work/coordination/PROJECT_GOAL.md`](work/coordination/PROJECT_GOAL.md), including
bounded Worker delegation, separate independent Reviewers, and automatic
selection of the next eligible task. This supersedes the historical 2026-09-21
pause; future user pauses still apply. The goal preserves all task, evidence,
publication, and human-decision boundaries below.

Recover the current relay from `STATE.json`, the top of `HANDOFF.md`, and
`TASK_REGISTER.md`. Historical runner observations and completed task requests
are not current dispatch instructions. A role handoff is an action for the
Orchestrator to execute, not completion of the project goal.

Current intended sequence:

```text
ORCHESTRATOR shapes/dispatches one bounded package
→ WORKER implements + verifies + may publish task-bounded commits
→ REVIEWER independently verifies against existing criteria
→ ORCHESTRATOR reconciles status and either closes, routes smallest fix, or dispatches next bounded task
```

Role contracts live in `work/coordination/roles/`.

## Standing Worker publication authority — human authorized 2026-09-10

The human project owner explicitly authorized the following standing envelope:

> Worker may publish bounded changes that remain inside an active task contract, provided they undergo independent Reviewer verification before broader status/phase advancement.

This newer explicit human authorization supersedes older task clauses that require operator approval **only for publication/push of changes that stay entirely inside the currently active task contract**.

Therefore Worker may commit/push/publish implementation and test/documentation changes when all of the following are true:

- a live active task contract exists;
- every changed file and behavior remains within that task's explicit MAY CHANGE / output boundary;
- all MUST NOT CHANGE and stop/escalation conditions are respected;
- no ROM, BIOS, generated cache, extracted game asset/content, or other prohibited material is committed;
- Worker records exact tests/evidence and routes the exact revision to independent Reviewer;
- broader capability/phase status does **not** advance until independent Reviewer has verified the relevant evidence and Orchestrator reconciles it.

This standing envelope does **not** authorize Worker to create its own broader scope, ignore a task stop condition, alter supported-ROM policy, publish releases, distribute copyrighted content, merge unrelated refactors, self-review, or mark a phase complete. If a task requires a genuinely new human product/scope decision rather than merely an old publication gate, stop and escalate.

## Battle-effect fast lane — human authorized 2026-10-13

The human project owner explicitly approved this lane ("yes, add the fast
lane"). Reason: the full relay cost effect 45 seven task files, eight reviews
and about three days; roughly two hundred effects remain. This section
supersedes the per-effect discovery/design/route-plan/configuration/probe/
authority sequence for eligible families only.

Eligible: Phase 4 move-effect families whose behavior is fully determined by
the pinned pret source and testable with no-ROM engine/controller tests.

1. **Batch.** Up to five eligible families per package. One task file under
   `work/tasks/` holds the source lock (pinned-revision file/line citations),
   design, MAY CHANGE paths and acceptance. No separate discovery, design,
   route-plan, configuration, probe or authority documents or reviews.
2. **Implement.** Worker implements on a branch with source-derived test
   oracles (never values read back from the implementation) and opens a PR.
   Public no-ROM CI must pass.
3. **Review once.** One independent Reviewer checks source conformance,
   assertions and scope on the PR and records PASS/NEEDS_FIX in
   `work/reviews/`. On PASS the PR merges and the inventory marks those
   families `represented`.
4. **ROM evidence later.** New ROM fixture tests ride along and skip without a
   ROM. Their non-skipped result comes from the next guarded bridge run's full
   verified-ROM suite; until then the inventory notes `ROM fixture pending`.
   A failing fixture reopens that family.

Use the full relay instead when a family needs new persistent or cross-turn
battle state, touches `main.lua`, the save format or a runtime replay, or has
any `UNKNOWN` source behavior. All no-ROM/no-extracted-content rules,
independent review, the capability-checklist evidence gate and the
no-self-review rule still apply.
