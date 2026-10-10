# Bounded Magnitude implementation request

- Task: `P4-F3-MAGNITUDE-IMPLEMENTATION`.
- Scope: one route-allowlisted bridge input for Magnitude move 222/effect 126.
- Status: pending guarded Local Worker Bridge result; not implementation or
  capability acceptance evidence.

## Requested bounded projection

The request changes only the reviewed nine-path surface. In the existing
one-attacker/one-defender engine path, it retains positive-power admission for
the nominal-power-one Magnitude record, then after `useMove` deducts one PP,
uses exactly one `% 100` draw to select the approved 4–10/10–150 table,
emits `{ type = "magnitude", side = S, level = L }`, and passes a shallow
local power copy through the existing accuracy, critical, damage, type,
normal-random, no-effect, and post-hit path. The shared move/catalog record
is not mutated.

The controller expands only the supplied level event to one ordered message.
Focused tests cover table boundaries, PP/event/RNG order, both sides,
first-player `firstBattle`, no-effect behavior, non-126 preservation,
controller non-mutation, inventory classification, and the SHA-verified
Magnitude fixture. The replay runs those deterministic represented-state
checks; it makes no retail text, animation, multi-target, or full-turn claim.

## Exclusions and next evidence

No route, runner, ROM/private data, importer/catalog/data model, admission
rule, generic dynamic-power mechanism, targeting/doubles, Underground,
abilities/items, cancellation expansion, UI timing/localization, links, or
other effect family is part of this request. Only guarded `git apply`/diff,
focused/no-ROM/SHA-ROM/replay evidence at the bridge's published revision,
followed by a fresh independent outcome review, can establish this leaf.
