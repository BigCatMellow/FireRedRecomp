# Frozen Pokémon FireRed Balance Translation Manifest

- Record role: `EVIDENCE / TRANSLATION MANIFEST`
- Primary information class: `TASK CONTEXT + DERIVED DATA`
- Status: `BLOCKED — FOUNDATION SEAMS REQUIRED`
- Lifecycle: `ACTIVE`
- Authority: maps the frozen source package to FireRedRecomp only; neither changes package nor authorizes gameplay implementation
- Accountable owner: project maintainer
- Canonical owner for subject: this file for package-to-target row mapping at the pinned revisions
- Parent task: [`pokemon-firered-balance-translation-manifest.md`](../tasks/pokemon-firered-balance-translation-manifest.md)
- Source package: `BigCatMellow/Pilot_Projects@81a079607cb79f58a5eaf02b424c08eccf4b14ad`, [`integrated_player_package_v1.csv`](../../../../../../Pilot_Projects/pokemon-firered-balance/data/integrated_player_package_v1.csv), blob `ed4c75e54435f4b8e8889b47fd8e1c292a8a705f`
- Target: `BigCatMellow/FireRedRecomp` local `master` at `f2c240e7a94f7a2329771b0ef06d531eabab64e6`
- ROM invariant: FireRed US v1.0 SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`
- Row rule: each of the 23 data rows in the frozen CSV appears exactly once below; values remain canonical only in that CSV.

## Target representation

| Package concern | Exact target representation | Current disposition |
| --- | --- | --- |
| ROM move records | `import/BattleMove.lua:parseTable` → `main.lua:loadBattleSceneAssets` → deep `battleMoves` namespace | `IMPLEMENTABLE` as a gameplay mod patch after category foundation exists |
| Damage category | `src/core/BattleFormulas.lua:isPhysicalType` and `calculateBaseDamage`; `src/core/BattleEngine.lua` lines 2102 and 2829 | `BLOCKED`: target hard-codes Gen-3 type categories; needs a per-move resolver used by damage math and damage event bookkeeping |
| Level-up learnsets | `import/LevelUpLearnset.lua:resolve`, called at `main.lua` lines 1271, 1306, 1406, 1516, 2483, 2895, 4269, 4377, and 4507 | `BLOCKED`: no mod namespace or common overlay resolver exists |
| TM19/resource scope | decoded item id 307; no package row changes item data or TM compatibility | `NOT_APPLICABLE` to package application; must be negative-verified, not modified |

## Frozen-row mapping

`IMPLEMENTABLE` means the target has the data surface but this manifest does
not authorize application. `BLOCKED` means an explicit foundation task is
required. No row is `NOT_APPLICABLE` because all 23 frozen CSV rows are in the
supported FireRed target scope.

| CSV data row | Frozen selector → target numeric ID | Target path/symbol | Disposition | Required next seam |
| ---: | --- | --- | --- | --- |
| 1 | category `MOVE_SLUDGE` → move 124 | `battleMoves[124]`; `BattleFormulas.calculateBaseDamage` | `BLOCKED` | per-move category resolver; physical exception |
| 2 | category `MOVE_SLUDGE_BOMB` → move 188 | `battleMoves[188]`; `BattleFormulas.calculateBaseDamage` | `BLOCKED` | per-move category resolver; physical exception |
| 3 | override `MOVE_TWINEEDLE` → move 41 | `battleMoves[41]` | `IMPLEMENTABLE` | package mod patch, preserving all unspecified fields |
| 4 | override `MOVE_SILVER_WIND` → move 318 | `battleMoves[318]` | `IMPLEMENTABLE` | package mod patch, preserving all unspecified fields |
| 5 | override `MOVE_ROCK_TOMB` → move 317 | `battleMoves[317]` | `IMPLEMENTABLE` | package mod patch, preserving all unspecified fields |
| 6 | override `MOVE_ROCK_BLAST` → move 350 | `battleMoves[350]` | `IMPLEMENTABLE` | package mod patch, preserving all unspecified fields |
| 7 | override `MOVE_GIGA_DRAIN` → move 202 | `battleMoves[202]` | `IMPLEMENTABLE` | package mod patch, preserving all unspecified fields |
| 8 | override `MOVE_WING_ATTACK` → move 17 | `battleMoves[17]` | `IMPLEMENTABLE` | package mod patch, preserving all unspecified fields |
| 9 | override `MOVE_AIR_CUTTER` → move 314 | `battleMoves[314]` | `IMPLEMENTABLE` | package mod patch, preserving all unspecified fields |
| 10 | override `MOVE_AURORA_BEAM` → move 62 | `battleMoves[62]` | `IMPLEMENTABLE` | package mod patch, preserving all unspecified fields |
| 11 | natural `ONIX / ROCK_TOMB / 30` → species 95, move 317 | `LevelUpLearnset.resolve` consumer seam | `BLOCKED` | `battleLearnsets` overlay resolver |
| 12 | natural `KABUTOPS / ROCK_BLAST / 46` → species 141, move 350 | `LevelUpLearnset.resolve` consumer seam | `BLOCKED` | `battleLearnsets` overlay resolver |
| 13 | natural `ARBOK / POISON_FANG / 30` → species 24, move 305 | `LevelUpLearnset.resolve` consumer seam | `BLOCKED` | `battleLearnsets` overlay resolver |
| 14 | natural `GOLBAT / POISON_FANG / 35` → species 42, move 305 | `LevelUpLearnset.resolve` consumer seam | `BLOCKED` | `battleLearnsets` overlay resolver |
| 15 | natural `NIDOQUEEN / POISON_FANG / 30` → species 31, move 305 | `LevelUpLearnset.resolve` consumer seam | `BLOCKED` | `battleLearnsets` overlay resolver |
| 16 | natural `NIDOKING / POISON_TAIL / 30` → species 34, move 342 | `LevelUpLearnset.resolve` consumer seam | `BLOCKED` | `battleLearnsets` overlay resolver |
| 17 | natural `JYNX / AURORA_BEAM / 25` → species 124, move 62 | `LevelUpLearnset.resolve` consumer seam | `BLOCKED` | `battleLearnsets` overlay resolver |
| 18 | natural `ELECTRODE / SHOCK_WAVE / 32` → species 101, move 351 | `LevelUpLearnset.resolve` consumer seam | `BLOCKED` | `battleLearnsets` overlay resolver |
| 19 | natural `MAGNETON / SHOCK_WAVE / 32` → species 82, move 351 | `LevelUpLearnset.resolve` consumer seam | `BLOCKED` | `battleLearnsets` overlay resolver |
| 20 | natural `FLAREON / FLAME_WHEEL / 36` → species 136, move 172 | `LevelUpLearnset.resolve` consumer seam | `BLOCKED` | `battleLearnsets` overlay resolver |
| 21 | natural `DODRIO / DRILL_PECK / 37` → species 85, move 65 | `LevelUpLearnset.resolve` consumer seam | `BLOCKED` | `battleLearnsets` overlay resolver |
| 22 | natural `GENGAR / SHADOW_BALL / 36` → species 94, move 247 | `LevelUpLearnset.resolve` consumer seam | `BLOCKED` | `battleLearnsets` overlay resolver |
| 23 | natural `SEAKING / WATERFALL / 38` → species 119, move 127 | `LevelUpLearnset.resolve` consumer seam | `BLOCKED` | `battleLearnsets` overlay resolver |

## Category policy constraint

The frozen package is a later per-move category policy for all FireRed move
records, with only Sludge and Sludge Bomb selected as physical exceptions.
The package's frozen category metadata source is
`PokeAPI/pokeapi@4b82c204ddd19ecb8eda2ea044ccb59e222b721c`; FireRed ROM data
remains authoritative for every other move field.

The next foundation must not hand-maintain a partial type list. It must supply
a generated, versioned category map for every target move record, validate the
355-row coverage stated by the frozen category record, then use the resolved
move category (not type) at every damage and event-category call site. Status
and fixed-damage moves need an explicit non-damaging representation so they
never accidentally select a stat branch.

## Negative scope

The following are acceptance checks for every later implementation slice, not
editable package inputs:

- no trainer (`battleTrainers`), encounter, AI, economy, or species-stat data;
- no TM compatibility or item acquisition change; item 307 remains the one-copy
  TM19 resource and move 202 retains the frozen CSV values only;
- no held candidate promotion: Aerodactyl Rock Slide, Kingler Crabhammer 45,
  Dragonite Outrage 56, and Omastar AncientPower 49 stay absent from the
  package;
- no package CSV or source-pin change.

## Baseline and post-change evidence

Baseline: `bash scripts/test_all.sh` passed on the target revision in no-ROM
mode (140 test files; ROM-dependent checks skipped cleanly). The verified-ROM
suite and any gameplay replay are not evidence for this planning task.

Before implementation, snapshot hashes of decoded move records, resolved
learnsets, trainers, encounters, item 307, and compatibility data must be
recorded. Post-change checks must prove: 355 category-map entries; all 23
frozen rows resolved; only the eight specified move records differ in frozen
override fields; only the 13 specified learnsets gain one row; and all negative
scope snapshots are byte/semantic identical.

## Result

The exact package is translatable as a versioned gameplay mod overlay, but it
cannot be applied correctly yet. The smallest next task is the category and
learnset-overlay foundation; it must be independently reviewed before the
frozen package mod is written.
