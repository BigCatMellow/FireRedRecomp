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
| `P4-PAIN-01` | `CLOSED` | `ORCHESTRATOR` | Base `d793981`; [independent correction review](../reviews/2026-09-19-pain-split-fixture-correction-review.md) | PASS for exactly two fixture substitutions, `51` → `18`; no behavior or route changes. | Reconciled into `P4-PAIN-02`. |
| `P4-PAIN-02` | `CLOSED` | `ORCHESTRATOR` | [Corrected request authorization](../tasks/phase4-pain-split-effect.md) | User chose existing private runner; reviewed corrected digest and original nine-path boundary preserved. Local no-ROM baseline: 148 files PASS. | Dispatch `P4-PAIN-03`. |
| `P4-PAIN-03` | `CLOSED` | `ORCHESTRATOR` | Request `bf36d94`, implementation `a739ddc88cb44a33d5e6025e619cf1df3fe6a1a8` | Guarded run `35493728001` PASS; both 149-file full suites, focused checks, deterministic replay; accepted by `P4-PAIN-04`. | Reconciled; successor `P4-02`. |
| `P4-PAIN-04` | `CLOSED` | `ORCHESTRATOR` | [Independent exact implementation review](../reviews/2026-09-20-pain-split-implementation-review.md), `bf36d94..a739ddc` | PASS against existing criteria; local suite and additional 12,168 living-HP cases passed. | Close only Pain Split; dispatch `P4-02` and route prerequisite. |
| `P4-02-ROUTE` | `BLOCKED` | `ORCHESTRATOR` | Configuration `24f39c4`; [independent configuration PASS](../reviews/2026-09-20-move-effect-inventory-route-review.md) | Private runner `firered-mint` offline/busy=false at probe preflight; nothing submitted. | When online, resume same single authorized probe; do not bypass ROM gate. |
| `P4-02` | `BLOCKED` | `ORCHESTRATOR` | Preparation `688433a` on GitHub branch `work/move-effect-inventory`; [source/test preflight PASS](../reviews/2026-09-20-move-effect-inventory-preflight-review.md) | Independent exhaustive source join, 150-file no-ROM suite, nine rejected mutations PASS; required probe/private-ROM execution absent. | Resume probe when online, transport exact test/report only, then final independent ROM-backed review. |
| `P0-02-DISCOVERY` | `CLOSED` | `ORCHESTRATOR` | [Independent discovery PASS](../reviews/2026-09-20-save-version-discovery-review.md), exact `b53c387` | Historical matrix, 45/0 codec, 13/0 roundtrip, 24/24 characterization and edge cases independently reproduced. | Dispatch only `P0-02-CONTRACT`; behavior fixes remain separate. |
| `P0-02-CONTRACT` | `READY_FOR_REVIEWER` | `REVIEWER` | [Save contract/fixture task](../tasks/phase0-save-version-contract.md), exact `63592c3` | Seven allowed files; Worker codec 63/0, roundtrip 13/0 and 149-file no-ROM suite PASS; runtime unchanged. | Independent exact-revision review before compatibility gate reconciliation. |
| `P0-03-DISCOVERY` | `CLOSED` | `ORCHESTRATOR` | [Independent discovery PASS](../reviews/2026-09-20-ci-proof-discovery-review.md), exact `b5b317b` | First/current public receipts and pinned syntax/docs characterization independently reproduced. | Dispatch only `P0-03-CHECKS`; first CI receipt does not prove new checks exist. |
| `P0-03-CHECKS` | `READY_FOR_WORKER` | `WORKER` | [Public repository-check task](../tasks/phase0-ci-repository-checks.md) | Disjoint syntax/docs checker, focused tests, public workflow step and README policy; no runtime changes. | Local checks, exact published public run, independent review. |
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
