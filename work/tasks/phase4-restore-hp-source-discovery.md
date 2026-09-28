# Task: source-lock Recover's restore-HP effect

- Task ID: `P4-F1-RESTORE-HP-DISCOVERY`
- Status: `READY_FOR_WORKER`
- Type: `RESEARCH / SOURCE-LOCK DISCOVERY`
- Parent capability gate: Phase 4 move-effect family chain.
- Prerequisite: [P4-02 final PASS](../reviews/2026-09-27-move-effect-inventory-review.md), exact `c10bfa7`.
- Risk: `LOW` — research only; an incorrect source-lock could misdirect later design.

## Goal and source of truth

Lock the narrow Gen 3 behavior of `EFFECT_RESTORE_HP` for Recover (move ID 105)
and Milk Drink (ID 303), before any design or implementation. Use only pinned
`pret/pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788`, especially the
move records, `BattleScript_EffectRestoreHp`, `Cmd_tryhealhalfhealth`, its
cancellation/announcement/PP sequence, and the accepted engine baseline. The
inventory's selection and limits are evidence, not a substitute for this lock.

## MAY CHANGE

1. `work/reports/phase4-restore-hp-source-discovery.md`.
2. This task's research evidence and handoff.

## MUST NOT CHANGE

Runtime/engine/controller/UI code, admission policy, generic healing APIs,
tests, workflows, save state, AI, task routes, supported ROM policy, or
canonical Phase 4 status. Do not implement recovery, bundle Softboiled/Milk
Drink field behavior, Rest, Present, Wish, Swallow, Ingrain, weather healing,
or any other family. No ROM/media/data dump or private runner access.

## Acceptance criteria

1. Establish exact move IDs/effect/power/flags and reference source anchors.
2. Describe the successful and full-HP failure paths, including half-max
integer rounding/minimum-one rule, clamping owner, PP timing, RNG/accuracy
absence, cancellation/announcement ordering, and source-visible events.
3. Compare every required source action with current engine/controller seams;
explicitly mark missing or ambiguous event/presentation/admission contracts.
4. Record the smallest proposed future design boundary, without drafting an
implementation task or claiming the current engine supports the effect.
5. Use source/history/read-only checks only. Independent exact-report review
must PASS before any design task is created.

## Stop / escalate when

The source requires an unsupported cross-component state, source behavior is
ambiguous, or evidence would require ROM inspection. State the unresolved fact
and stop; do not guess, add a fallback, or widen into healing generally.

## Completion and handoff

Researcher writes the exact bounded report. A separate Reviewer evaluates the
exact revision. Only after PASS may the Orchestrator consider a dedicated
effect-32 design task; Phase 4 remains IN PROGRESS.
