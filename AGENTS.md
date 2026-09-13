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
4. current `work/coordination/STATE.json` and `work/coordination/HANDOFF.md` for coordination state;
5. `docs/roadmap.md` and `docs/handoffs/firered-recomp-checklist.md` for deeper roadmap/history.

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

The canonical checklist currently prioritizes Phase 3 exit evidence. The active bounded continuation is `work/tasks/oak-parcel-dex-presentation-north.md` unless newer live task/review state supersedes it.

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
