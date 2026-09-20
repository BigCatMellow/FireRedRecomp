# FireRedRecomp Task and Handoff Register

- Record role: `REGISTER`
- Primary information class: `TASK CONTEXT / FLOW`
- Status: `ACTIVE`
- Lifecycle: `ACTIVE`
- Authority: lifecycle index only; does not replace an active task contract,
  `STATE.json`, `HANDOFF.md`, independent review, or the capability checklist
- Accountable owner: `ORCHESTRATOR`
- Live state: [`STATE.json`](STATE.json)
- Narrative relay: [`HANDOFF.md`](HANDOFF.md)
- Task contract template: [`TASK_CONTRACT_TEMPLATE.md`](TASK_CONTRACT_TEMPLATE.md)

## Purpose

This register closes the handoff loop for **new work from 2026-09-19 onward**.
It gives a fresh agent one compact answer to: what is active, who owns the
next action, which exact revision/evidence is in play, and whether a handoff
was acknowledged, continued, closed, or superseded.

It is deliberately not a second roadmap or test-evidence database:

- `CAPABILITY_CHECKLIST.md` owns project-wide capability status.
- The file named in a row owns scope and acceptance.
- `STATE.json` owns the current machine-readable relay.
- `HANDOFF.md` owns the human-readable relay.
- A review file owns its verdict for its exact revision.

## Lifecycle vocabulary

| State | Meaning | Required next transition |
| --- | --- | --- |
| `OPEN` | Contract exists but is not yet dispatched | Orchestrator validates readiness and records `ACKNOWLEDGED` |
| `ACKNOWLEDGED` | Successor has read the task and accepted the relay | `READY_FOR_WORKER`, `BLOCKED`, or `SUPERSEDED` |
| `READY_FOR_WORKER` | Worker may act inside the exact task boundary | `READY_FOR_REVIEWER`, `BLOCKED`, or `SUPERSEDED` |
| `READY_FOR_REVIEWER` | Exact Worker revision/evidence awaits independent review | `REVIEWED_PASS`, `REVIEWED_NEEDS_FIX`, or `BLOCKED` |
| `REVIEWED_PASS` | Bounded task passed independent review | Orchestrator records `CLOSED` or a successor task |
| `REVIEWED_NEEDS_FIX` | Reviewer named the smallest allowed correction | Orchestrator dispatches a corrected successor or records `BLOCKED` |
| `BLOCKED` | Missing authority, evidence, environment, or external input | Record exact unblock condition; do not invent a successor |
| `CLOSED` | Result/evidence have been reconciled and no task work remains | Terminal |
| `SUPERSEDED` | Replaced by a linked successor before completion | Terminal for this task; successor is `OPEN`/`ACKNOWLEDGED` |
| `LEGACY` | Pre-register task; history exists but has not been backfilled | Leave untouched unless an Orchestrator performs evidence-based reconciliation |

## Active register

| Task ID | Lifecycle | Assigned next role | Contract / revision | Evidence or blocker | Successor / next action |
| --- | --- | --- | --- | --- | --- |
| `P4-PAIN-01` | `REVIEWED_NEEDS_FIX` | `REVIEWER` | [`phase4-pain-split-effect.md`](../tasks/phase4-pain-split-effect.md); no implementation revision was published | Guarded request `87d5e72` failed because its #220 fixture expected flags `51`; verified ROM data says `18`. Scope review at `b1cb1497` remains valid only for the literal nine-path route. | Independently approve or block the smallest fixture-only correction. If approved, Orchestrator creates `P4-PAIN-02` with the exact permitted edit/test/replay boundary. |
| `P2-REF-01` | `BLOCKED` | `USER` | [`phase2-oak-reference-comparison.md`](../tasks/phase2-oak-reference-comparison.md) | Trusted retail Oak/Pallet reference captures with provenance have not been supplied; media must remain outside git. | User supplies captures/provenance; Orchestrator validates intake and moves comparison to `OPEN`. |

## Legacy policy

Existing files under `work/tasks/`, `work/reviews/`, and completed handoffs are
`LEGACY` until a future Orchestrator needs to reopen or reconcile one. Do not
bulk assign lifecycle states from filenames, commit messages, or prose alone.
When a legacy task becomes relevant, add one row with links to its direct
evidence and state whether it is `CLOSED`, `BLOCKED`, or `SUPERSEDED`.

## Orchestrator update procedure

1. Create or reuse a task contract from the template.
2. Add one register row before dispatch; give it a stable ID.
3. Write the same task ID, role, and next action into `STATE.json` and
   `HANDOFF.md` last.
4. On every Worker or Reviewer result, update the row with the exact revision,
   evidence reference, verdict/blocker, and successor pointer.
5. Mark `CLOSED` only after status reconciliation. Mark `SUPERSEDED` only with
   a live successor link.
