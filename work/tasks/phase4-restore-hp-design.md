# Task: design the bounded ordinary restore-HP contract

- Task ID: `P4-F2-RESTORE-HP-DESIGN`
- Status: `CLOSED — REVIEWED PASS`
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

Designer published `4863567`; the independent
[review](../reviews/2026-10-01-restore-hp-design-review.md) returned PASS.
Only a separately bounded implementation contract may follow; Phase 4 remains
open.

## Designer evidence and handoff — 2026-10-01

The [proposed design](../reports/phase4-restore-hp-design.md) is ready for
independent exact-revision review, not implementation. Inspection/public base:
`1a312f67751ccdd8fdb1b38ea9d85884cd6ed7d8`; accepted F1 source lock:
`1f89f0d53b1df3b22ea974eb99d9caed6f86c7f1`.

The contract defines ID-aware admission only for Recover 105 / Slack Off 303
with effect 32, ordinary PP-before-viability and own-half-max rounding/clamp,
separate success/full-HP events, ordered controller snapshot/feedback, and exact
existing owner seams. The parser has no ID field, so the proposed optional
admission ID is forwarded from existing slot keys; importer and non-32 behavior
remain unchanged. The later acceptance outline explicitly accounts for the
inventory's ID-less probe and historical rejection counts.

All source-lock exclusions remain hard boundaries, especially Snatch, shared
cancellation/MoveEnd, status/items/abilities, Substitute, persistence and retail
animation/timing. No generic healing API, cross-turn state, implementation task
or broader support claim is introduced. No runtime, tests, ROM/private runner,
routes, save, coordination or canonical Phase 4 state is changed. Parent owns
reconciliation; this handoff does not self-approve design or effect completion.

Read-only checks: recovered matching public/local base; verified source pin and
clean tracked reference state; confirmed six runtime/importer owners unchanged
from accepted `a739ddc`; inspected both runtime admission callers, event and
party-bridge seams, and inventory probe. The read-only repository checker over
the tracked list plus the pending new report passed: 276 Lua files, 162 Markdown
files, 449 local targets, zero errors; the design pair contains 12 local link
occurrences. Whitespace and exact two-path authored-scope checks passed. The
published revision is handed to the Orchestrator for separate review. Gameplay
tests/full suite are not new evidence for this design-only package.
