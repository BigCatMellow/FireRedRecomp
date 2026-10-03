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

Execution resumed on 2026-09-23. Rollover `aec377a` and CI `3478822` each
await independent review despite successful exact public runs. The private
runner was offline at the resume check; no probe/request has been submitted.
Read HANDOFF first.

| Task ID | Lifecycle | Assigned next role | Contract / revision | Evidence or blocker | Successor / next action |
| --- | --- | --- | --- | --- | --- |
| `P4-PAIN-01` | `CLOSED` | `ORCHESTRATOR` | Base `d793981`; [independent correction review](../reviews/2026-09-19-pain-split-fixture-correction-review.md) | PASS for exactly two fixture substitutions, `51` → `18`; no behavior or route changes. | Reconciled into `P4-PAIN-02`. |
| `P4-PAIN-02` | `CLOSED` | `ORCHESTRATOR` | [Corrected request authorization](../tasks/phase4-pain-split-effect.md) | User chose existing private runner; reviewed corrected digest and original nine-path boundary preserved. Local no-ROM baseline: 148 files PASS. | Dispatch `P4-PAIN-03`. |
| `P4-PAIN-03` | `CLOSED` | `ORCHESTRATOR` | Request `bf36d94`, implementation `a739ddc88cb44a33d5e6025e619cf1df3fe6a1a8` | Guarded run `35493728001` PASS; both 149-file full suites, focused checks, deterministic replay; accepted by `P4-PAIN-04`. | Reconciled; successor `P4-02`. |
| `P4-PAIN-04` | `CLOSED` | `ORCHESTRATOR` | [Independent exact implementation review](../reviews/2026-09-20-pain-split-implementation-review.md), `bf36d94..a739ddc` | PASS against existing criteria; local suite and additional 12,168 living-HP cases passed. | Close only Pain Split; dispatch `P4-02` and route prerequisite. |
| `P4-02-ROUTE` | `CLOSED` | `ORCHESTRATOR` | Configuration `24f39c4`; [independent probe PASS](../reviews/2026-09-27-move-effect-inventory-probe-review.md), `97dcae0` | Guarded run `36335570606` verified selector/toolchain/SHA; patch-only steps skipped. | Unlock only one P4-02 request. |
| `P4-02` | `CLOSED` | `ORCHESTRATOR` | [Exact final PASS](../reviews/2026-09-27-move-effect-inventory-review.md), implementation `c10bfa7`, run `36336096049` | Guarded SHA-ROM evidence: focused permitted skip; both 151-file suites, non-skipped inventory aggregate and no-replay branch verified. | Dispatch only `P4-F1-RESTORE-HP-DISCOVERY`. |
| `P4-F1-RESTORE-HP-DISCOVERY` | `CLOSED` | `ORCHESTRATOR` | [Exact independent PASS](../reviews/2026-09-29-restore-hp-source-discovery-review.md), `1f89f0d` | Recover/Slack Off ordinary path locked; Milk Drink effect 157 and Snatch/cancellation/MoveEnd exclusions retained. | Dispatch only `P4-F2-RESTORE-HP-DESIGN`. |
| `P4-F2-RESTORE-HP-DESIGN` | `CLOSED` | `ORCHESTRATOR` | [Exact independent PASS](../reviews/2026-10-01-restore-hp-design-review.md), `4863567` | Literal admission/events/inventory delta and exclusions accepted as design only. | `P4-F3-RESTORE-HP-IMPLEMENTATION` preparation; route required. |
| `P4-F3-RESTORE-HP-IMPLEMENTATION` | `READY_FOR_WORKER` | `WORKER` | [Guarded implementation task](../tasks/phase4-restore-hp-implementation.md); [probe PASS](../reviews/2026-10-02-restore-hp-route-probe-review.md) | Ordinary Recover/Slack Off only; exactly one reviewed nine-path request authorized. | Guarded evidence, then independent exact implementation review. |
| `P4-F3-ROUTE` | `CLOSED — REVIEWED PASS` | `ORCHESTRATOR` | [Configuration PASS](../reviews/2026-10-02-restore-hp-route-configuration-review.md), probe [PASS](../reviews/2026-10-02-restore-hp-route-probe-review.md) `3c03876` / run `36981539166` | Readiness-only evidence passed; patch/test/replay/publication skipped. | Unlocks one P4-F3 request only. |
| `P0-02-DISCOVERY` | `CLOSED` | `ORCHESTRATOR` | [Independent discovery PASS](../reviews/2026-09-20-save-version-discovery-review.md), exact `b53c387` | Historical matrix, 45/0 codec, 13/0 roundtrip, 24/24 characterization and edge cases independently reproduced. | Dispatch only `P0-02-CONTRACT`; behavior fixes remain separate. |
| `P0-02-CONTRACT` | `CLOSED` | `ORCHESTRATOR` | [Independent contract PASS](../reviews/2026-09-21-save-version-contract-review.md), exact `63592c3` | Codec 63/0, roundtrip 13/0, 149-file suite and historical/mutation witnesses independently reproduced. | Explicit compatibility gate closed; separate rollover correction dispatched. |
| `P0-SAVE-ROLLOVER` | `CLOSED` | `ORCHESTRATOR` | [Independent PASS](../reviews/2026-09-23-save-counter-rollover-review.md), exact `aec377a` | Public run `35665565029`, codec 93/0, roundtrip 16/0, 150-file suite and old-code/literal boundary witnesses independently reproduced. | Broader save safety remains separate; active local gate is P0-01 ledger discovery. |
| `P0-03-DISCOVERY` | `CLOSED` | `ORCHESTRATOR` | [Independent discovery PASS](../reviews/2026-09-20-ci-proof-discovery-review.md), exact `b5b317b` | First/current public receipts and pinned syntax/docs characterization independently reproduced. | Dispatch only `P0-03-CHECKS`; first CI receipt does not prove new checks exist. |
| `P0-03-CHECKS` | `CLOSED` | `ORCHESTRATOR` | [Independent PASS](../reviews/2026-09-21-ci-repository-checks-review.md), exact `3478822` | Public run `35624624210` / job `106415819660`, isolated 47/0, dynamic syntax/docs check and 150-file suite independently reproduced. | P0-03 enforcement complete; retain P0-04 and other Phase 0 gates. |
| `P0-01-DISCOVERY` | `CLOSED` | `ORCHESTRATOR` | [Independent audit PASS](../reviews/2026-09-27-behavior-ledger-audit-review.md), exact `61f1a77`, pinned `eac7d69` | All nine rows mapped without promoting missing proof; stale PC-overflow negative bounded. | Dispatch only `P0-01-CORRECTION`; Phase 0 remains open. |
| `P0-01-CORRECTION` | `CLOSED` | `ORCHESTRATOR` | [Exact independent PASS](../reviews/2026-09-29-behavior-ledger-correction-review.md), `fc43daf` | Ten bounded ledger rows; source/runtime/assertion/receipt distinctions, PC UNKNOWN and rollover wording preserved. | P0-04 may verify reproducibility; Phase 0 remains open. |
| `P0-04` | `BLOCKED — REVIEWED EVIDENCE` | `ORCHESTRATOR` | [Exact review](../reviews/2026-10-01-clean-clone-verification-review.md), report `d0e0bad` | Fresh clone CLI checker/no-ROM/refusal path passes, but absent FIRST_RUN/default PATH and unverified isolated desktop prevent clean first-run proof. | No repair implied; a separately bounded resolution is required before retry. |
| `P0-04-DISCOVERY` | `READY_FOR_WORKER` | `RESEARCHER` | [Read-only first-run discovery](../tasks/phase0-first-run-reproducibility-discovery.md) | Define smallest supported repair/re-verification boundary for the exact P0-04 blockers. | Independent review before any repair contract. |
| `P0-04-DISCOVERY` | `CLOSED` | `ORCHESTRATOR` | [Exact independent PASS](../reviews/2026-10-02-first-run-reproducibility-discovery-review.md), `8c92f67` | One conditional docs-only repair/reverification boundary; desktop remains unverified. | Dispatch only `P0-04-DOCS`. |
| `P0-04-DOCS` | `CLOSED` | `ORCHESTRATOR` | [Exact independent PASS](../reviews/2026-10-02-first-run-documentation-repair-review.md), `d4f7fe8` | Conditional profile and safe guidance documented; no desktop proof claimed. | Dispatch only P0-04-REVERIFY. |
| `P0-04-REVERIFY` | `BLOCKED — REVIEWED EVIDENCE` | `ORCHESTRATOR` | [Exact independent review](../reviews/2026-10-02-clean-clone-reverification-review.md), `93c4654` | Fresh target lacks lua5.1/LÖVE; dependent checks correctly NOT RUN with no workaround. | Separate supported-target preparation decision before retry. |
| `P5-01` | `CLOSED` | `ORCHESTRATOR` | [Exact independent PASS](../reviews/2026-10-02-world-coverage-inventory-review.md), `7712d63` | First corridor inventory verified; exactly one live old-man scene/template projection candidate. | Dispatch only P5-02-OLD-MAN-DISCOVERY. |
| `P5-02-OLD-MAN-DISCOVERY` | `CLOSED` | `ORCHESTRATOR` | [Exact independent PASS](../reviews/2026-10-02-viridian-old-man-projection-discovery-review.md), `4fbd0d6` | Three source scene/template projections locked; live projection gap named. | Dispatch only P5-03-OLD-MAN-DESIGN. |
| `P5-03-OLD-MAN-DESIGN` | `READY_FOR_WORKER` | `RESEARCHER` | [Bounded projection design](../tasks/phase5-viridian-old-man-projection-design.md) | Contract only; no generic callback or progression behavior. | Independent design review before implementation. |
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
