# Task: present north-facing Oak Parcel/Dex scene

- Status: `DONE`
- AGI status: `AGI READY`
- Type: `IMPLEMENTATION`
- Owner: `/root`
- Risk: `MEDIUM`
- Goal: At the canonical north-facing Oak interaction, visibly present the
  bounded Parcel return/Dex scene and commit its persistent state once.

## Inputs and source of truth

- Inputs: completed Mart presentation task, `main.lua`,
  `src/core/ViridianParcelStory.lua`, real Lab object templates, and runtime
  replay.
- Authoritative sources: verified FireRed ROM and
  `data/maps/PalletTown_ProfessorOaksLab/{scripts,events}.inc`, `map.json`.
- Evidence labels: `VERIFIED`: ReceiveDexScene `0x0816961E`, Oak local id 4,
  rival local id 8, Dex props 9/10, and the source text/motion order recorded
  in the descriptor-validation result.
- Preconditions: bounded strengthened guard (not literal retail guard): Lab
  4,3; player `(6,4)` facing north; Oak id 4; Mart scene 1; Lab scene 5;
  Parcel present; successful ball-capacity preflight. Retail enters the script
  for Mart scene >=1 without these additional malformed-save checks.

## Change boundary

- MAY CHANGE: new `src/core/OakParcelDexPresentation.lua`, `main.lua`, focused
  tests, runtime replay/script, and task/review documentation.
- MUST NOT CHANGE: generic script interpreter/map hook/addobject systems,
  Oak orientation variants, Mart presenter/UI, save codec, or battle rules.
- OPERATOR APPROVAL REQUIRED: publication/push. Superseded for task-bounded
  publication by the standing human authorization recorded in `AGENTS.md`.

## Verified north-facing descriptor

- ROM: FireRed US v1.0 SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`.
- Entry: `ReceiveDexScene=0x0816961E`; bounded guard is stated above.
- Text pointers in required presenter order:
  `E405`, `E4AF`, `E4CA`, `DE8D`, `DE99`, `E508`, `E536`, `E5C5`, `E5EA`,
  `E612`, `E6B3`, `E6D0`, `E784`, `DEC8`, `DEF3`, all at ROM base `0x08000000`.
- North choreography, in source order: messages `E405`, `E4AF`, `E4CA`, and
  `DE8D`; then spawn rival template local 8 at `(5,10)` and move it up six to
  `(5,4)` while the player faces down, waits five `delay16` plus `delay8`,
  then faces left; then message `DE99`; player faces up before message `E508`;
  after
  messages `E508`/`E536`, Oak moves `(6,3)->(6,2)->(5,2)`; after `E5C5`,
  Oak performs `walk_in_place_faster_up`, then remove prop 9, delay10, remove
  prop 10, delay25; Oak returns `(5,2)->(6,2)->(6,3)`;
  after the final rival text, player faces left, rival moves down six and is
  removed from the live list without changing its hide flag.
- Objects: Oak local 4 at `(6,3)`; rival template local 8; props 9/10 at
  `(4,1)/(5,1)`. Props are temporary runtime removal only.
- Bounded omissions: audio/fanfare/BGM, Fame Checker, and other orientations
  are explicitly deferred and must not be claimed.

## Acceptance criteria

- [x] Exact guard starts a ROM-text/movement bounded presenter; all other Oak
  interactions follow existing behavior.
- [x] Presenter locks input, uses source-derived north-facing motion/text,
  temporary rival lifecycle, and Dex prop removal without generic spawning.
- [x] It delegates all existing `ViridianParcelStory` durable writes exactly
  once after a successful preflight; no early mutation or duplicate reward.
- [x] Verified-ROM replay proves terminal presentation plus persistent result;
  focused tests, both suites, and independent review pass.

## Verification and evidence

- Reviewed implementation revision: `2d8c3221775044a54668683e500055307fe4d20b`.
- Independent review: `work/reviews/oak-parcel-dex-presentation-north-final-review.md` — `PASS`.
- Local Worker Bridge run `34547647645` verified FireRed US v1.0 SHA-1
  `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`.
- Focused presenter test: 24 passed, 0 failed.
- Full no-ROM suite: 121 test files passed.
- Full verified-ROM suite: 121 test files passed, including
  `phase3_exit_path_rom_test`: 12 passed, 0 failed.
- Verified-ROM natural-capture replay passed the Oak presentation and
  fresh-process persistence with Dex/Lab/Mart/Parcel/capture state intact.

## Stop / escalate

Stop if verified source contradicts reported descriptor data, support requires
generic script/addobject semantics, another player-facing orientation is needed,
or preflight cannot preserve the current bounded atomic failure behavior.

## AGI readiness

- Fresh-Agent Test: `PASS` — descriptor evidence and strengthened guard are
  recorded here.
- No-Guess Test: `PASS` — source order and explicit non-parity malformed-save
  behavior are documented.
- Scope Test: `PASS`
- Authority Test: `PASS`
- Completion Test: `PASS`
- Failure Test: `PASS`
- Continuation Test: `PASS`

## Completion / handoff

Independent Reviewer `PASS` closes this bounded leaf only. The north-facing
Oak Parcel/Dex presentation is wired, source-locked, regression-tested, and
verified in the ROM-backed runtime replay. The explicit omissions remain out
of scope and are not claims of parity.

Phase 3 remains `IN PROGRESS`. Orchestrator must return to
`work/tasks/phase3-exit-proof.md` and dispatch the smallest remaining unproven
parent acceptance item rather than widening this completed task.
