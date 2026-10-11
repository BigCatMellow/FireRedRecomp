# Integrated Player Ecosystem

This file owns the current player-facing package. Values are research candidates until a bounded implementation task adopts them.

## Why an integrated package matters

Individually "safe" buffs can interact badly when stacked. The package therefore needs to be evaluated as a whole:

- neutral damage;
- STAB identity;
- typed matchup coverage;
- role envelopes;
- scarce-TM allocation;
- stage/evolution continuity;
- setup/control value.

## Package

### Hybrid category model

Base rule: modern per-move Physical/Special split.

Explicit Poison exceptions:

- Sludge → Physical
- Sludge Bomb → Physical

Reason: preserve the actual Grimer→Muk physical-Poison progression and late ceiling rather than making the family depend on special offense or grind-heavy resources.

### Bug

- Twineedle: 30 BP per hit.
- Silver Wind: 10 PP, otherwise unchanged.

Why:

- Twineedle is Beedrill-specific enough to repair Beedrill without accidentally buffing Jolteon through Pin Missile.
- 30/hit improves early/mid identity without the much larger spike seen at 40/hit.
- Silver Wind's PP change supports sustainable special-Bug identity without raw power inflation.

### Rock

- Rock Tomb: 60 BP / 90% accuracy.
- Rock Blast: 25 BP / 90% accuracy.
- Onix: natural Rock Tomb around level 30.
- Kabutops: natural Rock Blast around level 46.
- Do not make Rock Slide globally repeatable.
- Aerodactyl natural Rock Slide remains on hold because high Speed converts the flinch chance into significant denial.

### Grass

- Giga Drain: **60 BP / 10 PP**.

The goal is sustain, not another power bump.

The 65 and 70 BP variants materially increased the number of families for whom single-copy TM19 became a strong typed coverage allocation. PP-only is cleaner.

### Flying

- Wing Attack: 65 BP.
- Air Cutter: 65 BP / 95% accuracy.

Air Cutter 70 was demoted after valuing its elevated critical-hit rate. At 65 it remains a distinct high-crit option without clearly dominating Wing Attack.

### Poison access

Preferred selective identity package:

- Arbok → Poison Fang ~30
- Golbat → Poison Fang ~35
- Nidorina + Nidoqueen → Poison Fang ~30
- Nidorino + Nidoking → Poison Tail ~30

The Nido moves must be mirrored across evolution stages to avoid Moon-Stone timing erasing the intended progression.

### Category-progression repairs

- Jynx → Aurora Beam ~25.
- Voltorb + Electrode → Shock Wave ~32.
- Magnemite + Magneton → Shock Wave ~32.
- Flareon → Flame Wheel ~36.
- Doduo + Dodrio → Drill Peck ~37.
- Gastly + Haunter + Gengar → Shadow Ball ~36.

These are intended as natural identity repairs so the modern split does not convert ordinary progression into TM dependence.

## Current system-level interpretation

When the package was stacked, the median ordinary-family neutral change remained near zero. Most material typed gains were intended STAB/identity gains rather than a second wave of generic coverage inflation.

The remaining cross-type coverage effects come mainly from coherent category changes such as:

- Hitmonchan's elemental punches using Attack;
- Bite/Crunch/Pursuit using Attack on physical/mixed users.

These require regression watching but are not equivalent to globally handing every species a new coverage move.

## Species watch list

- Gengar
- Hitmonchan
- Gyarados
- Jynx
- Muk
- Beedrill
- Onix
- Kabutops
- Aerodactyl
- Dewgong
- Omastar

Do not automatically nerf/buff these species from spreadsheet deltas; use their role, progression, control, and battle-regression evidence.
