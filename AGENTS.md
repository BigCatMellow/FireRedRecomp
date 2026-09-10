# FireRedRecomp Agent Operating Contract

- Record role: `REFERENCE`
- Primary information class: `AUTHORITY / INVARIANT`
- Status: `ACTIVE`
- Lifecycle: `ACTIVE`
- Authority: repository-wide operating contract; subordinate to explicit human direction and narrower task/review contracts
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
→ WORKER implements + verifies
→ REVIEWER independently verifies against existing criteria
→ ORCHESTRATOR reconciles status and either closes, routes smallest fix, or dispatches next bounded task
```

Role contracts live in `work/coordination/roles/`.

## Publication / write authority

Repository agents may create commits needed to execute an explicitly active task or coordination package when the narrower task permits publication. If the active task explicitly requires operator approval for publication/push and no newer explicit human authorization supersedes that clause, implementation may be prepared and reviewed but must stop before publication requiring that approval.

This operating contract itself does not grant permission to widen game scope, alter supported-ROM policy, ship releases, distribute copyrighted content, or declare phase completion without evidence.
