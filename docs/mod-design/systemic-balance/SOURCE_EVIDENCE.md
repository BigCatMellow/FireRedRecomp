# Source and Evidence

## Canonical research location

The quantitative research originated in:

- https://github.com/BigCatMellow/Pilot_Projects
- PR #14: https://github.com/BigCatMellow/Pilot_Projects/pull/14

The FireRedRecomp files in this folder are the durable mod-design handoff. They summarize conclusions; they do not replace the research scripts/reports.

## Vanilla source pin

`pret/pokefirered@c75f352304d529f6ba92d4f74b9cf8b5c3810788`

Used to verify/extract:

- species stats;
- learnsets;
- TM/HM/tutor compatibility;
- wild/species acquisition;
- trainer parties;
- damage/category behavior;
- badge boosts;
- critical-hit behavior;
- move effects and resource sources.

## Modern move-category metadata

A pinned PokeAPI source was used only to map later per-move damage classes for the modern-split branch.

It must **not** be treated as authority for FireRed move power, accuracy, PP, effects, learnsets, or resource availability.

## Important quantitative conclusions preserved here

- ordinary Kanto final forms cluster around a standard power budget rather than the legendary/pseudo extremes;
- many "weak Pokémon" failures are move/access/category problems rather than stat problems;
- single-copy resources cannot be treated as universal repairs;
- Game Corner repeatability is high-friction and should not be counted like ordinary low-friction access;
- Bug/Rock/Poison/Flying/Grass had meaningful move-ecosystem thinness under stricter sustainable/cycle-aware screening;
- typed matchup regression is necessary because neutral damage can hide coverage homogenization;
- modern categories fix many stat/move mismatches but create some natural-progression/resource problems;
- a hybrid-modern branch with targeted repairs currently performs better than either unmodified extreme;
- stage/evolution timing matters to whether a "natural" repair actually works in play;
- battles should validate the package after systemic analysis, not define the package.

## Research tooling concepts worth preserving

The Pilot Projects work built/referenced analyzers for:

- baseline extraction;
- family-aware natural STAB;
- tutor/TM/HM acquisition;
- species acquisition normalization;
- resource dependence;
- type move ecosystems;
- realized offense;
- utility/control access;
- mixed-attacker physical/special axes;
- same-role comparison;
- candidate move overlays;
- typed matchup blast radius;
- category-policy A/B;
- scarce-resource allocation;
- trainer baseline extraction and battle-regression manifests.

If future work needs exact numbers, go back to the research scripts/artifacts rather than reconstructing them from prose.

## Current handoff rule

When a design conclusion changes materially:

1. update the research/evidence first;
2. update `CURRENT_STATE.md`;
3. update the owning design file here;
4. do not silently change implemented mod behavior from a notes-only decision.
