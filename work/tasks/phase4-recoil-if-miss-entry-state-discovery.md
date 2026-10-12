# Task: source-lock effect-45 miss entry state and HP gates

- Task ID: `P4-F1-RECOIL-IF-MISS-ENTRY-STATE`
- Status: `READY_FOR_WORKER`
- Type: `RESEARCH / READ-ONLY SOURCE SUPPLEMENT`
- Parent capability gate: [Phase 4 move/effect matrix](../roadmaps/CAPABILITY_CHECKLIST.md).
- Assigned role: `RESEARCHER`
- Independent reviewer: `REVIEWER`
- Prerequisites: accepted source lock `c218da6`; design stop at `f31ae69`
  independently assessed in the
  [design review](../reviews/2026-10-11-recoil-if-miss-design-review.md).
- Risk: `MEDIUM` — guessed entry values or HP result-flag handling would
  produce an incorrect crash formula or damage an immune-target miss.

## Goal

Resolve only the source facts preventing the represented-singles effect-45
design: ordinary action entry/reset values for the critical/damage calculation
and move-result flags, and the downstream attacker HP commands' response to
immunity computed inside the miss branch. This supplements the accepted lock;
it does not replace that review or authorize behavior.

## Source of truth

- Public `pret/pokefirered` revision
  `c75f352304d529f6ba92d4f74b9cf8b5c3810788` only.
- [Accepted source report](../reports/phase4-recoil-if-miss-source-discovery.md)
  and [review](../reviews/2026-10-10-recoil-if-miss-source-discovery-review.md).
- [Stopped design report](../reports/phase4-recoil-if-miss-design.md) at
  `f31ae69`, independently reviewed as incomplete.
- Current project code may be inspected read-only to identify represented
  seams; it is not proof of reference behavior.

## MAY CHANGE

1. `work/reports/phase4-recoil-if-miss-entry-state-discovery.md`.
2. This task's research evidence/handoff section only.

## MUST NOT CHANGE

Accepted source-lock artifacts, design task/report, runtime, tests, event
schemas, admission, formulas, controller/UI, save/AI, routes/workflows,
requests/probes, runner/ROM configuration, supported-ROM policy, canonical
phase status, or other effects. No ROM/private-runner/media/runtime access,
implementation authority, generic flag/multiplier abstraction, or source dump.
All effect-45 design exclusions remain intact.

## Acceptance criteria

1. Trace the pinned ordinary selected-move action into effect 45's accuracy-
   miss branch. Name the actual state consumed by damage calculation and the
   pre-existing no-effect guard, its exact reset/assignment owners and values,
   and why a prior critical action can or cannot carry those values forward.
   Separate ordinary reachable facts from excluded cancellation/interception,
   called/mirrored moves, items/abilities, status, and multi-battler paths.
2. Distinguish the earlier no-effect guard from immunity computed by the
   branch's later type calculation. Trace health-bar/data HP updates and
   attacker faint handling through their own flag checks. Record actual HP,
   result/event ordering and damage-adjustment draw consequences for ordinary
   nonimmune and immune targets, including any suppressed HP update.
3. Reconcile the literal half/minimum/target-maxHP cap and zero-after-cap
   arithmetic with those downstream gates without inventing a new oracle.
4. Record every finding with pinned symbol/line evidence and a short current-
   project comparison. State whether the missing facts are now resolved for
   the bounded design, which remain UNKNOWN, and every retained exclusion.
   No design API, code change, test fixture, or whole-turn parity claim.
5. Independent exact-report review must accept the supplement before it can
   become additional source authority for a separately resumed design.

## Required evidence

- Baseline: verify the source revision and exact existing source/design review
  records. Do not reopen accepted leaves merely to reproduce prior work.
- Focused: read-only symbol/assignment/control-flow trace; literal pinned
  references and exact report/task hashes for independent verification.
- Full suite: N/A for source-only research; `git diff --check` and repository
  documentation checks required. No ROM or runtime execution.
- Review: independent exact-revision verdict under `work/reviews/`.

## Stop / escalate when

The pin cannot be verified, reachable state remains ambiguous, required facts
would need ROM/runtime observation, or resolving them requires expanding the
ordinary selected-move boundary. Record UNKNOWN and the smallest unresolved
prerequisite rather than choosing a convenient default.

## Completion and handoff

Researcher supplies report, exact revision/hashes, source evidence and checks.
Reviewer returns PASS / NEEDS_FIX / BLOCK. Orchestrator reconciles only this
supplement and, after PASS, may amend the stopped design's source references
and reactivate that bounded design for its own independent review. No route,
implementation, request, probe, or Phase 4 closure follows from this task.

## Research evidence and handoff — 2026-10-11

Research complete, pending independent exact-artifact review. Report:
`work/reports/phase4-recoil-if-miss-entry-state-discovery.md`, SHA-256
`92b990bf18b91729a468eab599fdced128238a6712c76a5f29ea730db56e4484`.
Inspection base and freshly recovered public `main`:
`43cae5e1e54bc85a8bc3c10043454f5c6b5e197f`. The existing public-source
checkout is clean at the required pin; inspected blob identities and an
independent GitHub file fetch agree. Original source/design artifact hashes
and exact source symbol/line references are in the report.

Findings: ordinary move entry explicitly resets critical/damage multipliers
to 1/1 and result flags to zero. Ordinary accuracy failure then performs a
type-immunity scan before entering the effect-45 miss script. Thus an immune
ordinary miss presents no effect and exits before crash or damage RNG;
the report explicitly corrects the earlier incomplete guard description.
Both downstream HP commands honor the no-effect mask; attacker faint tests
presence/actual HP. Late-only immunity is conditional command semantics,
not reachable in the scoped ordinary unchanged-type/target path. Literal
half/minimum/target-maxHP cap and the zero-after-cap distinction remain.
No required ordinary source fact remains UNKNOWN; independent acceptance
and all design/runtime/integration evidence remain outstanding.

Checks: baseline/final tracked repository checker PASS (280 Lua / 255
Markdown / 808 local targets); checker with this untracked report explicitly
added to its read-only enumeration PASS (280 Lua / 256 Markdown / 816 local
targets). `git diff --check` passed; `git diff --no-index --check /dev/null`
for the new report emitted no whitespace diagnostics (exit 1 denotes the
new-file difference). Gameplay suite and ROM/runtime checks are N/A under
this task. Only this evidence section and the report were authored; unrelated
drafts were preserved. No staging, commit, push, accepted-artifact edit,
design/code/test/coordination/route/request/probe/runner action was performed.

Handoff: parent serializes the exact report/task pair for a separate Reviewer,
who reconstructs entry, immunity precheck, reachable/conditional outcomes and
HP gates independently. Final task SHA-256 is supplied in the Researcher
handoff after this evidence section is saved, avoiding a self-referential hash.
Only an independent PASS permits the Orchestrator to reactivate the stopped
design with this additional source authority; that design needs its own review.
