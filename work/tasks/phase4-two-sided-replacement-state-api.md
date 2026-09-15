# Task: Phase 4 two-sided replacement-state/API migration

- Status: `CLOSED — REVIEWED PASS at 4a583b6a`
- Type: `PHASE 4 / BATTLE RULES / BOUNDED IMPLEMENTATION`

## Goal

Implement the reviewed ordered post-faint state migration for normal local
single battles: preserve existing one-side forced replacements while allowing a
completed action sequence to evaluate both teams once, emit `playerDrew` for a
simultaneous whole-team loss, and require player then foe replacement when both
teams still have legal benches. This task does not implement Explosion; it only
creates the state/API required before that future effect can be routed.

## Acceptance

1. `BattleEngine` has an authoritative ordered pending-replacement collection
   with `awaitingForcedSwitch` retained as the current-head compatibility view.
2. A completed multi-faint sequence records every faint before terminal or
   replacement state; it produces one terminal result or ordered requests.
3. When neither team is exhausted, replacement order is player then foe; the
   controller never reaches ACTION between them and existing persistence and
   exactly-once foe reward behavior remain intact.
4. `playerDrew` follows local loss/whiteout settlement for trainer and wild
   battles and cannot crash the Oak-lab rival completion seam.
5. Focused, full no-ROM, verified-ROM, and replay evidence all pass through
   the guarded bridge, with existing single-faint coverage retained.

## MAY CHANGE

Only the 12 route-authorized paths listed in
`local-worker-bridge-phase4-two-sided-replacement-state-api-route.md`.

## MUST NOT CHANGE

Explosion or any other move effect; move admission/formulas/RNG; doubles or
links; held-item survival; AI; trainer layout parsing; voluntary-switch
semantics; unrelated UI; or phase-completion status.

## Required implementation shape

Follow reviewed design `6ac44924`: explicit begin/record/finalize faint
sequence boundary; whole-team terminal evaluation before a request;
player→foe queue; queue-head-only resolution; scalar compatibility; message
loop handoff; loss-equivalent draw settlement; and focused coverage. Retain a
narrow one-faint wrapper for existing producers. A future Explosion task, not
this one, may first use the multi-faint boundary.

## Worker evidence

The exact fail-closed route passed review at `b6f63284`; probe `4630aad4`
passed guarded run `34906202097`. Worker must submit one unified patch request
using the `phase4-two-sided-replacement-state-api` filename prefix. Publication
requires the route's focused, no-ROM, verified-ROM, and replay gates.

## Worker and review closure

Request `66a37d10` passed guarded Local Worker Bridge run `34907113705` on
`firered-mint`: target validation, apply, focused tests, full no-ROM suite,
verified-ROM suite, runtime replay, and publication all passed. The resulting
canonical implementation `4a583b6a` independently passed post-publication
review. It adds ordered queue-head-compatible replacement state, explicit draw
outcome, and tested local settlement seams only. Explosion remains separate.
