# Frozen Balance Package — Target Translation Manifest

Status: **implementation infrastructure started; balance values not yet fully translated**

Target binding:

- Repository: `BigCatMellow/FireRedRecomp`
- Base: `main`
- Work branch: `work/frozen-balance-package`
- ROM policy: FireRed US v1.0
- First slice: category + balance-overlay infrastructure

## Authority boundary

Imported ROM data remains canonical FireRed truth. Rebalance behavior must be represented as a project-owned derived overlay. Do not edit importer decoding to make the ROM appear to contain rebalance values.

## Runtime seam

`src/core/BalanceOverlay.lua` owns derived move/learnset records. A move may override only `power`, `accuracy`, `pp`, and an explicit `category` (`physical` or `special`). Level-up additions are applied to a copied learnset. With no override, vanilla records pass through unchanged.

`BattleFormulas.calculateBaseDamage` uses an explicit overlay category when present; otherwise it retains the exact FireRed type-based split. This means the vanilla path remains source-faithful while the balance package can opt individual moves into the hybrid-modern policy.

## Frozen research directions to translate next

These are translation inputs from the completed balance research, not permission to redesign them in this repository:

- Twineedle: 30 BP per hit.
- Selective Poison access: Arbok Poison Fang ~30; Golbat Poison Fang 35; Nidoqueen line Poison Fang 30; Nidoking line Poison Tail 30.
- Rock: Rock Tomb 60/90 and Rock Blast 25/90; selective natural access. Do not globally repeat Rock Slide.
- Giga Drain: 70 BP / 10 PP; preserve TM19 as a finite/single-copy resource and regression-test allocation pressure.
- Flying: Wing Attack 65; Air Cutter 65/95. Air Cutter 70 is not preferred.
- Omastar: no buff; role is bulky attacker / physical wall.
- Dodrio: Drill Peck stage mirroring at level 37, not level 35.
- Flareon: Flame Wheel 36 as identity repair under the modern-category branch.
- Gengar natural Shadow Ball progression is separate from TM30 policy.
- TM30 must not become repeatable Game Corner coverage; typed allocation is the relevant regression, not only neutral damage.
- Hybrid-modern category policy is the preferred research branch; physical Poison/progression exceptions remain deliberate policy points rather than importer changes.

## Acceptance criteria for this infrastructure slice

1. Vanilla move records with no category override retain Gen-III type-based physical/special behavior.
2. Explicit physical/special categories select the corresponding attacking/defending stats without changing move type, STAB, or effectiveness.
3. Applying an overlay does not mutate imported move or learnset records.
4. Unsupported override fields fail closed.
5. No ROM-derived data/assets are committed.

The next slice should encode the frozen move/category table and exact stage-mirrored learnset additions, then run the repository suite plus focused battle regressions before touching trainer balance.
