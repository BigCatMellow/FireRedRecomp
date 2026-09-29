# Task: design the bounded ordinary restore-HP contract

- Task ID: `P4-F2-RESTORE-HP-DESIGN`
- Status: `READY_FOR_WORKER`
- Type: `DESIGN / NO IMPLEMENTATION`
- Parent chain: effect-32 source lock accepted at `1f89f0d`.
- Risk: `MEDIUM` — design determines any later battle/controller contract.

## Goal and source of truth

Specify the smallest explicit engine/controller/admission contract for the
ordinary, non-intercepted Restore HP path used by Recover (105) and Slack Off
(303). The [accepted source-lock review](../reviews/2026-09-29-restore-hp-source-discovery-review.md), its report, exact `BattleEngine` baseline,
and existing bounded singles conventions are the only sources of authority.

## MAY CHANGE

1. `work/reports/phase4-restore-hp-design.md`.
2. This task's evidence/handoff section.

## MUST NOT CHANGE

Runtime, tests, controller/UI, admission policy, save state, workflows, task
routes or canonical Phase 4 state. Do not implement a generic healing API,
Softboiled/Milk Drink, Rest, Wish, weather healing, Snatch, items/abilities,
status interactions, doubles, links, animation/timing parity, or a whole-turn
emulator. No ROM/private-runner access.

## Acceptance criteria

1. Define literal admission behavior for effect 32, limited to the two source
locked moves, and distinguish it from current rejection/fallback behavior.
2. Specify success and full-HP failure result/event ordering, PP consumption,
half-max floor/minimum-one computation, own-max clamp, and all RNG/accuracy
non-claims. Name exact owner seams for engine/controller/party bridge.
3. State a minimal event/result representation compatible with current bounded
controller conventions, including what presentation is not claimed.
4. Identify every unresolved source interaction as an explicit exclusion:
Snatch, shared cancellation, MoveEnd/status/item/ability behavior, persistence,
and any ordinary-turn machinery not represented today.
5. Propose only a later test/implementation acceptance outline; do not write a
task authorizing implementation. Independent design review is required.

## Stop / escalate when

The proposed contract needs a generic healing abstraction, cross-turn state,
or an excluded interaction. Record that the ordinary-path design is insufficient
and stop; do not silently broaden the feature.

## Completion and handoff

Designer publishes the report only. A separate Reviewer returns PASS / NEEDS_FIX
/ BLOCK. Only a reviewed PASS may permit a narrowly scoped implementation
contract; Phase 4 remains open.
