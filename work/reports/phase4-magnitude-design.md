# Bounded Magnitude singles design

- Task: [P4-F2-MAGNITUDE-DESIGN](../tasks/phase4-magnitude-design.md).
- Status: proposed contract; independent exact-revision review required.
- Inspection base: FireRedRecomp `21d8d433d857145386b7fd92a5d0504acaa4ee2d`.
- Authority: accepted [Magnitude source lock](phase4-magnitude-source-discovery.md)
  at `5770a4d`, with its [independent PASS](../reviews/2026-10-10-magnitude-source-discovery-review.md).
- Reference pin: `pret/pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788`.

This is a design for one observable, two-battler Magnitude path.  It does not
implement effect 126, admit new moves, alter tests or routes, or claim retail
parity outside the explicit domain below.

## Domain and retained admission

The only intended move is Magnitude, move ID 222 / effect 126, used by either
living battler against the one existing opposing battler.  Its ROM record has
nominal power 1.  That nominal value is only an admission/data property:
the selected Magnitude result supplies the damage calculation's transient
power.

`BattleEngine:supportsMove` already reaches this positive-power record through
its existing fallback.  This design deliberately proposes **no admission
change**, no ID-based family allowance, and no inventory-count change.  The
later implementation must be selected only by effect 126 after the existing
effective move/slot/no-PP handling.  A different effect-126 record or modified
catalog record is not newly certified; the later ROM fixture is the evidence
that the supported record remains Magnitude 222.

The design assumes the current engine's fixed opposing battler is the selected
target.  It does not add source `selectfirstvalidtarget` traversal: there is
no absent-battler, ally, or target-loop state in this bounded model.

## Literal action and RNG contract

After the existing slot selection, support check, zero-PP return, and
`useMove` event, the effect-126 path must use this order:

1. Deduct one PP from the selected permanent slot, exactly once.
2. Draw exactly once with `rng:next16() % 100`.  Map its residue to a
   Magnitude level and a **local**, transient base power using this table.
3. Append the Magnitude-level event defined below.
4. Run the existing one-defender accuracy check.  A miss ends the action with
   the existing `miss` event; its PP, level event, and Magnitude draw remain
   observable.
5. For a hit, run the existing critical, base-damage, type, normal-random
   multiplier, no-effect, critical-event, damage, and existing post-hit paths,
   using a shallow local move copy whose `power` is the selected transient
   power.  Shared catalog move data must never be changed.

| `rng:next16() % 100` | Level | Local base power |
| --- | ---: | ---: |
| 0–4 | 4 | 10 |
| 5–14 | 5 | 30 |
| 15–34 | 6 | 50 |
| 35–64 | 7 | 70 |
| 65–84 | 8 | 90 |
| 85–94 | 9 | 110 |
| 95–99 | 10 | 150 |

The table is total and disjoint over 0–99.  The selected base power exists
only for this call, as already established by the local Flail/Eruption copies;
this is not authority for a shared dynamic-power helper.

Outside the existing `firstBattle` tutorial-accuracy suppression, a normal
Magnitude hit consumes four explicit gameplay RNG draws in this sequence:
Magnitude, accuracy, critical, damage.  A miss consumes two: Magnitude,
accuracy.  The existing first player damaging action in `firstBattle` bypasses
accuracy and therefore consumes three on a hit: Magnitude, critical, damage;
that tutorial branch cannot produce an ordinary accuracy miss.  This design
does not alter that pre-existing tutorial rule.  These statements cover only
`resolveMove`; turn-order ties, the other battler's action, cancellation
machinery, and unsupported state can consume draws elsewhere.

The source script performs cancellation, announcement, PP reduction and
single-target selection before its Magnitude draw and strength message, then
enters the shared hit loop.  Current project cancellation is an unmodeled
boundary; `useMove` remains its existing announcement representation.  Within
the represented path, placing PP and the one level draw before accuracy is the
required source-sensitive difference from the ordinary hit family.

## Minimal result and presentation contract

The new ordered engine event is:

```lua
{ type = "magnitude", side = S, level = L }
```

`S` is the existing acting-side value; `L` is the integer 4 through 10.  The
event carries neither transient power nor a target: power is a rules-local
input and the current model has one implied defender.  It is appended after
the existing `useMove` event and before any `miss`, `critical`, `noEffect`, or
`damage` event for this action.  It does not mutate HP, PP, turn state, or
the shared move record.

`BattleSceneController:_eventMessages` is the sole later presentation owner.
It should expand the event to one bounded level announcement based on `level`,
after the existing move-use announcement and before the ordinary hit result
messages.  It must not recalculate power or RNG, mutate model state, add a
new animation/wait protocol, or manufacture a retail text-buffer/UI claim.
The engine resolves model state before controller playback; event order and
event snapshots, not final model state, define the visible sequence.

## Owner seams and exclusions

- `src/core/BattleEngine.lua` owns the effect branch, PP mutation, one draw,
  local power copy, and ordered `magnitude` event.
- `src/core/BattleFormulas.lua` remains the owner of existing accuracy,
  critical, base-damage, type, and damage-random rules; no formula changes are
  part of this leaf.
- `src/core/BattleSceneController.lua` owns only presentation of the new event.
- `main.lua`, save/party bridging, importer data, AI, move selection, workflow
  routing, and replay tooling remain unchanged.

Hard exclusions remain: foes-and-ally targeting, doubles, target reselection,
absent battlers, Underground's double-damage/ignore marker, abilities, items,
status/cancellation expansion, Substitute/MoveEnd behavior, visual timing,
animation, localization, links, and generic dynamic-power infrastructure.
The source's exact text buffer, pause, message printer, and all-target loop
are not represented by this event contract.  Full seeded retail-turn parity
is still `UNKNOWN` because those surrounding systems are outside this engine.

## Later implementation proof outline — not implementation authority

A separately reviewed implementation task would be limited to
`BattleEngine`, `BattleSceneController`, focused Magnitude tests, the existing
ROM metadata/effect inventory fixture only as needed to establish ID 222, and
their explicitly listed route paths.  It would need to prove:

1. Every residue boundary maps to the literal level/power table, exactly one
   initial Magnitude draw occurs, and shared ROM data retains nominal power 1.
2. Ordinary hit and miss paths consume the stated four/two draws, deduct PP
   once, and order `useMove`, `magnitude`, then existing result events.  The
   existing first-player `firstBattle` accuracy bypass is separately proved as
   a three-draw hit and no ordinary accuracy-miss branch.  Existing non-126
   move paths retain their current ordering and draws.
3. Both acting sides use the same singleton contract; no-effect behavior still
   consumes the normal post-accuracy critical/damage draws after the level
   draw, exactly as the existing ordinary path does.
4. Controller playback renders exactly one level announcement at the ordered
   point without mutating engine state or inferring a power/target; existing
   message queue transitions remain intact.
5. Focused no-ROM tests and the full no-ROM suite pass before any separately
   authorized private-ROM evidence.  No ROM, replay, route, or runner action
   is evidence for this design itself.

## Evidence and handoff

Inspected the accepted F1 source report/review and the current
`BattleEngine:resolveMove` selection, `useMove`, ordinary PP/accuracy and
Flail/Eruption local-copy seams, plus `BattleSceneController:_eventMessages`.
The report author changed only this document and the permitted task handoff.
No runtime or ROM execution occurred.  `git diff --check` and independent
exact-revision review remain required before any implementation successor is
compiled.
