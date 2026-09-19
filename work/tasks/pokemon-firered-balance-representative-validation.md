# Task: validate the FireRed balance mod in representative battles

- Status: `IN PROGRESS`
- AGI status: `AGI READY`
- Type: `VALIDATION / REPRESENTATIVE RUNTIME`
- Owner: project maintainer
- Risk: `HIGH`
- Parent: [`pokemon-firered-balance-package-application.md`](pokemon-firered-balance-package-application.md)
- Human authority: explicit project-continuation authority, 2026-09-16
- Frozen package: Pilot blob `ed4c75e54435f4b8e8889b47fd8e1c292a8a705f`; no reopening is authorized by this task
- Required ROM: FireRed US v1.0 SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`

## Goal

Produce reproducible evidence that the approved mod is loaded by the actual
runtime and behaves as intended in deterministic and representative battle
lanes. This is validation, not a tuning pass: package values, trainers, and
all prohibited game surfaces remain frozen.

## Required evidence

1. Prove the actual LÖVE runtime has loaded `pokemon-firered-balance` and its
   gameplay save profile, not merely a synthetic registry fixture.
2. Exercise category-sensitive battle calculations for a representative
   physical Fire, physical Water, Special Ghost, Special Flying, and the
   Sludge/Sludge Bomb physical exceptions; retain explicit Gen-3 fallback
   control cases without the mod.
3. Exercise every one of the eight changed move fields and all 13 additions in
   effective runtime data. Confirm no trainer, encounter, AI, item/TM,
   economy, held-candidate, save-layout, or Phase 3 record changes.
4. Run a bounded representative matrix grounded in the frozen protocol:
   category-sensitive watches (Gengar, Jynx, Hitmonchan, Gyarados,
   Rhydon/Kabutops, Seaking); fixed one-copy TM19/TM30 allocation controls;
   and held decisions remain controls, not promotions. Record outcomes by
   mechanism, not a boss win-rate target.
5. Re-run deterministic/no-ROM and supported-ROM suites. A failure may reopen
   the package only with a durable, mechanism-specific finding; do not alter
   values in this task.

## MAY CHANGE

- deterministic validation harnesses, runtime observation plumbing, and
  focused tests/evidence; this task, coordination, reviews, and roadmap index.

## MUST NOT CHANGE

- frozen package values or source lock; generic balance foundations; mod
  manifest identity; ROM/imported data; trainers, encounters, AI, item/TM,
  economy, held candidates, save format, Phase 3 behavior, or release assets;
- ROM/BIOS/cache/extracted content.

## Completion / handoff

Independent Reviewer must confirm the actual-runtime load proof, matrix
coverage, bounded interpretation, and negative scope. A `PASS` permits durable
PR #14 implementation evidence and a final implementation-completion audit;
it does not merge PR #14 or release the game.

## Worker evidence in progress

- `scripts/runtime_balance_mod_validation.sh` completed with the supported ROM:
  the actual LÖVE process reported `RUNTIME_BALANCE_MOD PASS` for the
  gameplay-impacting package and then passed the Route 1 wild-battle replay.
- `tests/pokemon_firered_balance_rom_matrix_test.lua` passed 13/0 against the
  verified ROM. It overlays the actual package on decoded move data, proves
  the eight frozen move fields, six representative category records,
  physical-branch weather behavior, all 13 natural additions, clean unload,
  and named Gengar/Jynx/Hitmonchan/Gyarados/Rhydon/Kabutops/Seaking watch
  controls. It also proves finite one-copy TM19/TM30 allocation semantics and
  no natural promotion of Kingler45, Dragonite56, Omastar49, or Aerodactyl
  Rock Slide. This is mechanism evidence, not a trainer-win-rate target.
- The supported ROM used for this run was the locally built FireRed US v1.0
  image, SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`; the alternate Rev 1
  image was not used.
- `bash scripts/test_all.sh` passed all 143 files in no-ROM mode. Re-running
  it with the supported ROM passed all 143 files in ROM mode. The focused
  matrix and the actual-runtime probe were then re-run against that same ROM
  and passed (`13/0` and `RUNTIME_BALANCE_MOD PASS`, respectively).
- The matrix now enumerates both eligible-recipient arms for its TM19 and
  TM30 one-copy controls, instead of using a tautological recipient helper;
  it remains validation-only and does not change frozen package data.

Independent review remains required before this task can be closed or its
implementation evidence can be treated as complete.
