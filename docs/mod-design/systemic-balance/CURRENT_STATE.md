# Current State

## Summary

The quantitative work has moved beyond a generic "buff weak Pokémon" pass.

Current evidence supports a **hybrid-modern category branch plus targeted ecosystem repairs**, with a small set of move/access changes that improve identity without broadly flattening species differences.

This remains a **research preference, not a final mechanics freeze**.

## Preferred current package

### Category policy

- Use modern per-move Physical/Special categories as the base model.
- Keep **Sludge** Physical.
- Keep **Sludge Bomb** Physical.
- This exception exists because otherwise Grimer/Muk lose their practical Poison identity for a large portion of their real acquisition/progression window.
- Do not treat expensive Game Corner TMs as ordinary low-friction progression repairs.

### Move values / reliability

Current preferred research values:

| Move | Candidate |
|---|---|
| Twineedle | **30 BP per hit** |
| Silver Wind | **10 PP**, base power unchanged |
| Rock Tomb | **60 BP / 90% accuracy** |
| Rock Blast | **25 BP / 90% accuracy** |
| Giga Drain | **60 BP / 10 PP** |
| Wing Attack | **65 BP** |
| Air Cutter | **65 BP / 95% accuracy** |

Important correction: Giga Drain was previously tested at 70 and 65 BP. Both materially increased one-copy TM19 contention. The cleaner current answer is **leave power at vanilla 60 and increase PP to 10**, improving Grass sustain without increasing coverage power.

### Selective natural-access candidates

- Onix — Rock Tomb around level 30.
- Kabutops — Rock Blast around level 46.
- Arbok — Poison Fang around level 30.
- Golbat — Poison Fang around level 35.
- Nidorina/Nidoqueen family — Poison Fang around level 30, mirrored across stages so evolving does not erase the move.
- Nidorino/Nidoking family — Poison Tail around level 30, mirrored across stages.
- Jynx — Aurora Beam around level 25; do **not** force raw Ice damage parity yet because Lovely Kiss/Fake Tears give meaningful control/setup value.
- Voltorb/Electrode — Shock Wave around level 32 with stage continuity.
- Magnemite/Magneton — Shock Wave around level 32 with stage continuity.
- Flareon — Flame Wheel around level 36 as a physical Fire identity rung.
- Doduo/Dodrio — Drill Peck at the defensible vanilla-family timing around level 37 rather than tuning to an analysis cutoff.
- Gastly/Haunter/Gengar — Shadow Ball family continuity around level 36 so evolution is not a category-policy penalty.

### Role corrections / watch cases

- Omastar: **Bulky Attacker / Physical Wall** is a better role model than pure wall.
- Onix: remains a genuine structural stat-shape concern after move/access work.
- Dewgong vs Lapras: treat as a role-distinction problem before considering stats.
- Gengar: large category gain, but current modeled output remains inside the existing glass-cannon envelope.
- Hitmonchan: coverage watch under elemental punches becoming Physical.
- Gyarados: coverage watch under Bite/Crunch/Pursuit becoming Physical; neutral ceiling does not automatically rise.
- Jynx: battle-regression watch because raw damage models undercount sleep and SpDef-break utility.
- Muk: protected by the physical Sludge line; do not "repair" it through expensive TMs.

## Resource policy

### TM30 Shadow Ball

Under modern categories, repeatable Game Corner TM30 creates too much premium off-type coverage.

Current leading policy:

> **Treat TM30 as finite/single-copy for the mod branch, pending battle regression.**

The research screen found no major neutral-output winner at END from the single-copy version, but many typed matchup improvements. Scarcity is therefore part of the balancing mechanism.

### TM19 Giga Drain

TM19 is genuinely contested as a one-copy resource.

Increasing Giga Drain to 65 or 70 BP caused the number of material typed beneficiaries to jump. Therefore:

> **Preferred: 60 BP / 10 PP.**

This improves sustainability while preserving the existing damage/coverage footprint.

## Rejected / demoted directions

- Broad stat inflation.
- Globally repeatable Rock Slide.
- Global Pin Missile buff as the Beedrill solution.
- Giga Drain 70/10 as the preferred package value.
- Giga Drain 65/10 as a "safe middle"; it crossed the same contention threshold as 70.
- Air Cutter 70/95; crit-aware expected value made it too strong beside Wing Attack 65.
- Aerodactyl natural Rock Slide as an automatic preferred change; its speed turns the flinch chance into significant control value.
- Calling a category regression "repaired" simply because a 4,000–4,500 coin Game Corner TM can fix it.
- Dodrio Drill Peck at level 35 solely to satisfy an analysis-band cutoff.

## Next real gate

1. Preserve the integrated package with Giga Drain at 60/10.
2. Validate stage-mirroring/evolution continuity during implementation design.
3. Treat TM30 as single-copy in battle-regression scenarios.
4. Run representative trainer/Gym/League regression telemetry.
5. Specifically watch Gengar, Hitmonchan, Gyarados, Jynx, Muk, Beedrill, Onix, Kabutops, and the limited-TM allocation decisions.
6. Only after battle regression should the hybrid-modern category branch be considered for final freeze.

No ROM/recomp implementation is authorized merely by this document.
