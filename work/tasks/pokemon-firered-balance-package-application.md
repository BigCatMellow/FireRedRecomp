# Task: apply the frozen FireRed balance package as a mod

- Status: `CLOSED — REVIEWED PASS`
- AGI status: `AGI READY`
- Type: `IMPLEMENTATION / DATA PACKAGE`
- Owner: project maintainer
- Risk: `HIGH`
- Parent: [`pokemon-firered-balance-foundation.md`](pokemon-firered-balance-foundation.md)
- Human authority: explicit project-continuation authority, 2026-09-16
- Frozen package: `BigCatMellow/Pilot_Projects@81a079607cb79f58a5eaf02b424c08eccf4b14ad`, blob `ed4c75e54435f4b8e8889b47fd8e1c292a8a705f`

## Goal

Generate and install one `pokemon-firered-balance` gameplay mod, using only
the independently reviewed foundation seams and the frozen 23-row package.
The generated package must contain exactly 355 move categories, the eight
approved move-field overrides, and the 13 approved natural learnset additions.

## Source of truth

- The frozen CSV and target translation manifest.
- FireRed `c75f352304d529f6ba92d4f74b9cf8b5c3810788` constants and PokeAPI
  `moves.csv` from `4b82c204ddd19ecb8eda2ea044ccb59e222b721c`.
- [`../evidence/pokemon-firered-balance-translation-manifest.md`](../evidence/pokemon-firered-balance-translation-manifest.md).

## MAY CHANGE

- the generator and source-lock evidence for this package;
- `mods/pokemon-firered-balance/manifest.json` and generated `init.lua`;
- focused package validation tests; task, coordination, review, and evidence.

## MUST NOT CHANGE

- the frozen CSV, its values, or its policy decisions;
- ROM/imported base data, trainer parties, encounters, AI, economy, items,
  TM compatibility, held candidates, save layout, or Phase 3 implementation;
- generic foundation semantics except a separately reviewed defect correction;
- ROMs, BIOS, caches, extracted assets, or release artifacts.

## Acceptance criteria

1. The generator fails closed on source commits/hashes, incomplete categories,
   unknown identifiers, or a non-23-row frozen package.
2. The generated mod has exactly 355 explicit valid categories, with Sludge and
   Sludge Bomb physical exceptions; all other categories derive from pinned
   PokeAPI input.
3. It applies only the eight approved power/accuracy/PP fields and the 13
   approved `{species, level, move}` additions through mod namespaces.
4. A headless runtime test loads the actual package against a complete
   synthetic base, proves all values and negative scope, and unloads cleanly.
5. Focused tests, syntax validation, and the full no-ROM suite pass. Supported
   ROM runtime evidence is a subsequent separately reviewed task.
6. Independent Reviewer `PASS` is required before representative validation.

## Completion / handoff

After independent `PASS`, dispatch representative validation: deterministic
category/override regressions plus a bounded gameplay matrix using only an
explicitly configured supported ROM. Do not claim ROM execution without it.

## Independent review result

Independent Reviewer returned `PASS` on revision
`bb0476cedd9831e5a43d086e52bced1769982c3c`.

The reviewer exported the frozen CSV directly from its pinned Pilot Git blob,
reproduced byte-identical generation from the pinned FireRed/PokeAPI inputs,
and confirmed the generator derives every exception, override, and addition
from parsed frozen rows. The generator regression passed 5/0, the actual-mod
test passed 7/0, Lua syntax passed, and all 142 no-ROM test files passed.

Review record: [`../reviews/2026-09-17-pokemon-firered-balance-package-application-review.md`](../reviews/2026-09-17-pokemon-firered-balance-package-application-review.md).

## Worker result

Implemented revision pending commit.

- `scripts/generate_pokemon_firered_balance_mod.py` verifies the exact FireRed
  revision, PokeAPI and frozen-package SHA-256 values, 23-row package shape,
  identifier mappings, and complete 355-record category coverage before
  generating the mod entrypoint. It derives each category exception, move
  field override, and natural addition from parsed frozen CSV rows; it has no
  second editable value table.
- `mods/pokemon-firered-balance` is a gameplay-impacting package with a
  generated category table and only the eight approved deep patches and 13
  approved learnset registrations.
- Removed the obsolete tracked `mods/examples/.gitkeep` placeholder: LÖVE
  discovers every directory under `mods/`, so retaining a manifest-less
  placeholder would make package discovery reject the complete set before the
  balance mod could load.
- `tests/pokemon_firered_balance_mod_test.lua` loads the actual package into a
  complete synthetic host and verifies coverage, exact frozen values, negative
  preservation, and unload behavior.
- `tests/generate_pokemon_firered_balance_mod_test.py --package <frozen-csv>`
  proves package values are parsed from CSV and rejects changed override or
  natural-addition rows at the locked hash gate. Export `<frozen-csv>` only
  from the recorded Pilot Git blob; do not use a mutable source checkout.
- Independent review initially returned `NEEDS_FIX` because the generator
  duplicated those 21 non-category values in code. The correction removes the
  duplicate tables, derives all package content from parsed rows, and is now
  awaiting a fresh independent review.
- Focused package test passed 6/0; `luac5.1 -p` and Python compilation passed;
  `bash scripts/test_all.sh` passed 142 test files in no-ROM mode. That run's
  ROM-backed checks correctly skipped because no path was supplied to it.
- Independently of package correctness, the supported FireRed US v1.0 SHA-1
  was located locally and the full 142-file suite passed in ROM mode. See
  [`../evidence/2026-09-17-supported-firered-rom-baseline.md`](../evidence/2026-09-17-supported-firered-rom-baseline.md).
  This is runtime readiness only; it is not representative balance evidence.
