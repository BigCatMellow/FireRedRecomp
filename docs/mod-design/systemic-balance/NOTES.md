# Working Notes

## Where we left off

The systemic player package is mature enough to move into **battle regression**, but the mechanics are not frozen.

Current preferred branch:

- modern per-move Physical/Special categories;
- Sludge + Sludge Bomb remain Physical;
- Twineedle 30 BP/hit;
- Silver Wind 10 PP;
- Rock Tomb 60/90;
- Rock Blast 25/90;
- Giga Drain **60/10**;
- Wing Attack 65;
- Air Cutter 65/95;
- selective Poison/Rock/category-progression learnset repairs;
- TM30 treated as a **finite/single-copy** resource for regression testing.

## Most recent important correction

Giga Drain 70/10 looked good as a Grass quality-of-life buff, but typed scarce-resource screening showed that both 65 and 70 BP materially increase contention for the one-copy TM19.

The cleaner design is:

> keep Giga Drain at 60 BP and raise PP to 10.

That improves Grass sustain without expanding the move's coverage power.

## Battle-regression intent

Use actual pinned FireRed trainer parties.

Regression is meant to detect:

- role compression;
- unintended coverage;
- setup/control abuse;
- scarce-resource pressure;
- progression holes;
- already-strong Pokémon gaining too much.

It is **not** meant to tune every Gym/Elite Four fight to a preferred turn count.

## Priority watch list

1. Gengar
2. Hitmonchan
3. Gyarados
4. Jynx
5. Muk
6. Beedrill
7. Onix
8. Kabutops
9. Aerodactyl
10. TM19/TM30 allocation pressure

## Later systems intentionally parked

Do not mix these into the first balance implementation:

- remembered-move library;
- 4+1 utility slot;
- six active moves;
- persistent team-synergy states;
- named Dual Techniques / combined attacks;
- quest-system redesign;
- broader trainer difficulty overhaul.

Those ideas are preserved in [TEAM_SYNERGY.md](./TEAM_SYNERGY.md) and [FEATURE_CONCEPTS.md](./FEATURE_CONCEPTS.md).
