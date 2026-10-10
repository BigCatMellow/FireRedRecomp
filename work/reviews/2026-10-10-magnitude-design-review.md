# Magnitude bounded-singles design — independent review

Verdict: **PASS** for the design-only `P4-F2-MAGNITUDE-DESIGN` package at
exact revision `6058b7c` (`6058b7ca46c8434621b66e7487ea256c253cebaf` as
resolved locally).

## Independence and scope

I reviewed the committed report and task handoff independently against the
accepted source discovery/report review, the pinned
`pret/pokefirered` revision `c75f352304d529f6ba92d4f74b9cf8b5c3810788`, and
the current engine/controller seams.  I did not author, amend, commit, or
publish the reviewed package.  The reviewed commit changes only:

- `work/reports/phase4-magnitude-design.md`; and
- `work/tasks/phase4-magnitude-design.md`.

It grants no implementation, admission, test, route, runner, ROM, replay, or
capability-status authority.

## Source and project-seam verification

The report retains the exact source table from
`Cmd_magnitudedamagecalculation`: residues
`0-4/5-14/15-34/35-64/65-84/85-94/95-99` map respectively to levels
`4/5/6/7/8/9/10` and transient powers
`10/30/50/70/90/110/150`.  It correctly projects the pinned script's
cancellation/announcement/PP/target-selection/Magnitude-draw/message order
onto the bounded engine as `useMove`, one PP deduction, one Magnitude draw and
event, then the single-defender hit path.

`BattleEngine:resolveMove` supplies the required existing seams: positive-power
admission, a selected permanent PP slot, ordinary accuracy/critical/normal
damage draws, and local Flail/Eruption move copies.  The design properly keeps
effect-126 admission unchanged, requires a local non-mutating power copy, and
does not turn that precedent into a generic dynamic-power facility.

The proposed `{ type = "magnitude", side = S, level = L }` event is minimal:
it does not duplicate local power or invent a target, and it is ordered after
`useMove` and before the existing miss/hit result events.
`BattleSceneController:_eventMessages` is the appropriate later presentation
owner because it already derives queued presentation from ordered engine
events; the design correctly prohibits it from changing model state, RNG, or
retail UI timing semantics.

## First-battle correction

The prior review concern is resolved.  The design now explicitly distinguishes
the ordinary four-draw hit / two-draw miss path from the existing first-player
`firstBattle` accuracy suppression in `BattleEngine:resolveMove`.  That
suppression bypasses `accuracyCheck`, so the design correctly requires a
three-draw tutorial hit (Magnitude, critical, damage) and no ordinary
accuracy-miss branch.  Its later proof outline requires this exception to be
tested separately.

## Boundaries and evidence

The design retains the accepted exclusions: multi-target traversal/doubles,
absent battlers, Underground, abilities/items, cancellation expansion,
Substitute/MoveEnd behavior, visual/animation/localization parity, generic
dynamic-power infrastructure, replay, ROM, and full retail-turn parity.  It
leaves surrounding full seeded parity explicitly `UNKNOWN`.

No runtime, test-suite, replay, private-ROM, runner, or bridge execution is
claimed or needed for this design review.  The task's required `git diff
--check` condition was observed clean before review.  A separate reviewed
route/implementation successor is still required before any code work.
