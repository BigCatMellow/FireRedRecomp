# Implementation Notes

## Boundary

These notes describe a future **FireRedRecomp mod**, not recomp parity behavior.

Do not mix this package into core parity code unless a bounded task explicitly authorizes a mod integration point.

## Source model

The research used:

- supported FireRed US v1.0 ROM target;
- pinned `pret/pokefirered` source for vanilla mechanics/data;
- a pinned PokeAPI dataset only for later per-move damage categories.

FireRed remains authoritative for:

- move power;
- accuracy;
- PP;
- effects;
- learnsets;
- TM/HM compatibility;
- tutor compatibility;
- encounters/acquisition;
- trainer parties;
- vanilla mechanics.

Do not accidentally import later-generation move powers/effects while importing modern Physical/Special categories.

## Suggested implementation layering

Keep the mod data-driven where possible.

Possible layers:

1. **category overrides**
   - per-move Physical/Special exceptions;
2. **move-property overrides**
   - power / accuracy / PP;
3. **learnset additions/mirroring**
   - species + move + level;
4. **resource-policy overrides**
   - finite/repeatable acquisition behavior;
5. **remembered-move library**
   - later feature, independent of basic balance;
6. **team-synergy state system**
   - later experimental feature.

The balance package should be expressible as data rather than scattered special-case logic.

## Evolution-stage continuity

Implementation must verify that evolving a Pokémon does not erase an intended natural identity move.

Explicit continuity cases from the research:

- Nidorina ↔ Nidoqueen
- Nidorino ↔ Nidoking
- Gastly ↔ Haunter ↔ Gengar
- Voltorb ↔ Electrode
- Magnemite ↔ Magneton
- Doduo ↔ Dodrio

Flareon is different: Flame Wheel is intentionally an Eeveelution identity move and should not be placed on Eevee just to create a mirror.

## Resource handling

### TM30

If the hybrid-modern package is implemented, first prototype TM30 as **finite/single-copy** rather than repeatable Game Corner coverage.

The exact location/reward path is still a product-design decision. Do not invent a new placement during implementation unless the task authorizes it.

### TM19

Keep TM19's existing scarce identity. The current preferred move change is PP-only (60 BP / 10 PP), specifically to avoid increasing allocation pressure.

## Regression requirements

Any implementation should compare:

- vanilla package;
- hybrid package;
- hybrid + finite-resource assumptions.

Typed matchup regression is mandatory for coverage changes.

Neutral dummy damage alone is insufficient.

## Do not implement yet without a new task

- combined/dual techniques;
- persistent synergy tags;
- fifth utility slot;
- six active moves;
- permanent remembered-move library;
- quest-system redesign;
- broad trainer difficulty changes;
- global stat rebalance.

Those are separate features and need their own bounded design/implementation tasks.
