# Task: bind the frozen FireRed balance package to FireRedRecomp

- Status: `CLOSED — REVIEWED PASS`
- AGI status: `AGI READY`
- Type: `PLANNING / TARGET TRANSLATION`
- Owner: project maintainer
- Risk: `MEDIUM`
- Human authority: explicit project-continuation authority, 2026-09-15
- Target: `BigCatMellow/FireRedRecomp`, local branch `master`, revision `f2c240e7a94f7a2329771b0ef06d531eabab64e6`
- Source package: `BigCatMellow/Pilot_Projects@81a079607cb79f58a5eaf02b424c08eccf4b14ad`, `pokemon-firered-balance/data/integrated_player_package_v1.csv`, blob `ed4c75e54435f4b8e8889b47fd8e1c292a8a705f`
- Reviewed revision: `6da2c4b1fec866e60b04c84a534a29f570bb03e6`
- Independent review: `work/reviews/2026-09-16-pokemon-firered-balance-translation-manifest-review.md`

## Goal

Produce one checked translation manifest for the frozen package against this exact target revision. It must establish the smallest valid implementation shape and fail closed on unsupported representation, rather than changing gameplay or recreating the package by hand.

## Source of truth

- Root `AGENTS.md` and current coordination state.
- Frozen package and implementation-validation plan at the pinned Pilot_Projects revision above.
- `src/core/BattleFormulas.lua`, `src/core/BattleEngine.lua`, `main.lua`, `src/core/ModRuntime.lua`, `src/core/ModRegistry.lua`, `import/BattleMove.lua`, and `import/LevelUpLearnset.lua` at the pinned target.
- FireRed US v1.0 SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc` remains the supported ROM.

## Established target facts

1. `main.lua` decodes ROM battle moves, then exposes them through the deep `battleMoves` mod namespace. A mod can patch frozen power, accuracy, PP, and a newly supported per-move category field without mutating ROM data.
2. `BattleFormulas.isPhysicalType` and two BattleEngine call sites currently hard-code the Gen-3 type split. A frozen later-generation category policy therefore requires a narrow category resolver and tests.
3. Level-up learnsets are decoded directly by `import/LevelUpLearnset.lua` at each consumer. No `battleLearnsets` namespace exists. Natural additions require a small, explicit learnset-overlay seam before package data can be applied.
4. TM compatibility and item acquisition are not an authorized package surface. TM19 must remain the decoded one-copy item with its frozen move values; this task must not infer a new item or compatibility capability.

## MAY CHANGE

- this task;
- `work/coordination/STATE.json` and `HANDOFF.md`;
- one translation manifest under `work/evidence/`;
- focused manifest-validation test/documentation only, if needed to prove the target mapping mechanically.

## MUST NOT CHANGE

- `main.lua`, battle formulas/engine, importers, runtime behavior, or mod API;
- any ROM/source/gameplay data, trainer party, encounter, AI, economy, TM compatibility, or supported-ROM policy;
- the frozen package or its source repository;
- ROMs, BIOS, caches, extracted content, releases, or unrelated Phase 3 work.

## Acceptance criteria

1. The manifest names the exact source-package blob and target revision.
2. Every frozen package row resolves exactly once as `IMPLEMENTABLE`, `BLOCKED`, or `NOT_APPLICABLE`; a row cannot silently disappear.
3. The category, move-override, natural-move, and negative-scope mapping each name exact target files/symbols and the required later task seam.
4. The manifest identifies the two concrete foundation gaps above and does not label them implementation-complete.
5. It defines deterministic baseline and post-change checks, including a negative diff/snapshot for trainers, encounters, TM compatibility, and held/non-promoted candidates.
6. An independent Reviewer verifies the manifest against both pinned trees.

## Deterministic evidence plan

1. Hash the frozen CSV and confirm the recorded blob.
2. Resolve all named move/species symbols to FireRed numeric IDs from the verified target/importer data or source lock.
3. Inspect each package row against the exact target representation.
4. Record only the target mappings and explicit missing seams in the manifest; never copy package values into a second editable specification.
5. Run the manifest's row-count/duplicate and source-path checks.

## Stop / escalate

Stop with `BLOCKED` if the frozen source package cannot be recovered at its pinned blob, an identifier has no exact FireRed mapping, target state changes under the task, or the target cannot support a mod overlay without modifying the ROM. Do not solve a blocked mapping by changing the frozen package.

## Completion / handoff

Independent Reviewer returned `PASS` at `6da2c4b1fec866e60b04c84a534a29f570bb03e6`: package blob/row coverage, exact target mappings, negative scope, manifest validation command, and the 140-file no-ROM suite were independently verified.

The next bounded task is `work/tasks/pokemon-firered-balance-foundation.md`. It may add only the category resolver and composable learnset-addition overlay; frozen package values remain separate.
