# Task: add mod-safe category and learnset foundations

- Status: `READY_FOR_REVIEWER`
- AGI status: `AGI READY`
- Type: `IMPLEMENTATION / FOUNDATION`
- Owner: project maintainer
- Risk: `HIGH`
- Parent: [`pokemon-firered-balance-translation-manifest.md`](pokemon-firered-balance-translation-manifest.md)
- Human authority: explicit project-continuation authority, 2026-09-15
- Frozen package boundary: blob `ed4c75e54435f4b8e8889b47fd8e1c292a8a705f` is input to a later task only

## Goal

Add two generic, mod-safe data seams required to express the frozen package:

1. resolve a damaging move's category from an optional per-move `category`
   field while preserving exact Gen-3 type-based behavior when it is absent;
2. resolve opt-in level-up learnset additions from a dedicated mod namespace
   without mutating decoded ROM data or hand-copying a base learnset.

This task creates capability only. It must not create a balance mod, category
map, move override, or natural learnset addition from the frozen package.

## Source of truth

- Root `AGENTS.md`, current coordination state, and the reviewed parent manifest.
- `src/core/BattleFormulas.lua`, `src/core/BattleEngine.lua`, `main.lua`,
  `import/LevelUpLearnset.lua`, `src/core/ModRuntime.lua`, and
  `src/core/ModRegistry.lua`.
- Existing focused test patterns in `tests/battle_formulas_test.lua`,
  `tests/mod_runtime_test.lua`, and `tests/wild_pokemon_factory_test.lua`.

## MAY CHANGE

- `src/core/BattleFormulas.lua` and `src/core/BattleEngine.lua` only for the
  category resolver's calculation/event seams;
- `import/LevelUpLearnset.lua` only for a pure, validated additions merge;
- `main.lua` only to register/resolve `battleLearnsetAdditions` and route its
  existing nine learnset consumers through one common resolver;
- focused tests for category and learnset-overlay behavior;
- this task, coordination, review, and evidence documentation.

## MUST NOT CHANGE

- any frozen-package values, generated category map, mod package, or `mods/`
  content;
- move power/accuracy/PP/effect/type/priority/flags; species, trainer, party,
  encounter, AI, economy, item, TM compatibility, or save layout data;
- supported ROM policy, ROM/imported base data, bridge/replay work, or
  unrelated Phase 3 behavior;
- ROM/BIOS/cache/extracted content or release/distribution artifacts.

## Required design

### Category resolver

Expose one `BattleFormulas.damageCategory(move)` that accepts only
`physical`, `special`, or `status` when a `move.category` field exists. When
the field is absent it must reproduce the current Gen-3 type split exactly.
`calculateBaseDamage` and both BattleEngine damage-category event sites must
use this resolver. Fire/Water weather modifiers must remain type-based even
when a later category makes a Fire/Water move physical. Existing unmodded
golden calculations must not change.

### Learnset additions

Register a `battleLearnsetAdditions` record namespace with empty ROM-independent
base data. A mod may register one species key whose value is an explicit array
of `{level=<1..100>, move=<valid move id>}` additions. Extend
`LevelUpLearnset` with a pure merge that preserves decoded entries, rejects
malformed/duplicate additions, and returns a deterministic level-ordered
learnset. Route all nine current `main.lua` direct resolver consumers through
one common resolver that applies this namespace. No base learnset is copied
into a mod.

## Acceptance criteria

1. Unmodded BattleFormulas and BattleEngine tests retain current Gen-3 results.
2. Synthetic per-move physical/special fields select attack/defense or
   special-attack/special-defense respectively; invalid categories fail closed.
3. A physical-category Fire/Water move still receives its existing type-based
   weather modifier; a status category never selects a damage-stat branch.
4. A headless mod-runtime fixture can register a learnset addition; every
   common main resolver consumer receives the same effective merged learnset.
5. The merge preserves all decoded entries, adds only declared rows, is stable
   by level, and rejects duplicate/malformed additions.
6. Focused tests and `bash scripts/test_all.sh` pass. A verified-ROM suite may
   be run only when the supported ROM is locally configured; absence must be
   recorded, not inferred.
7. Diff proves no package values or prohibited surfaces changed. Independent
   Reviewer `PASS` is required before package data is dispatched.

## Stop / escalate

Stop if the common resolver would require a generic importer rewrite, category
semantics conflict with an existing engine effect, a base learnset must be
duplicated into mod content, or a caller occurs before the mod runtime is
available. Report the first exact seam; do not apply balance data as a workaround.

## Completion / handoff

After independent `PASS`, dispatch a separate frozen-package mod task that
uses only these seams and proves all 355 category records, eight move overrides,
13 natural additions, and negative scope against the frozen CSV.

## Worker result

Implemented revision: `1939d3b62f29a2ad9e75e1d0f1b0d1abb1c7ce70`.

- `BattleFormulas.damageCategory` accepts explicit physical/special/status
  values and retains the Gen-3 type fallback when absent.
- Dynamic damage transformations and multi-hit bookkeeping retain the source
  move's explicit category; Fire/Water weather remains type-based.
- `battleLearnsetAdditions` is an empty-base record namespace; all nine live
  `main.lua` consumers route through `Battle.resolveLearnset` and the pure
  `LevelUpLearnset.mergeAdditions` validator.
- Focused results: BattleFormulas 46/0, learnset overlay 7/0, BattleEngine
  392/0; `luac5.1 -p main.lua` passed.
- Full no-ROM suite: 141 test files passed; ROM-dependent checks skipped
  cleanly because no supported-ROM path was configured.
