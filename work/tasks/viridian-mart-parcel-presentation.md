# Task: present the first Viridian Mart Parcel scene

- Status: `DONE`
- AGI status: `AGI READY`
- Type: `IMPLEMENTATION`
- Owner: `/root`
- Risk: `MEDIUM`
- Goal: On the first Mart entry at the verified doorway, visibly present the
  source-derived Parcel scene and only then atomically commit the bounded
  controller's persistent state.

## Inputs and source of truth

- Inputs: `main.lua`, `src/core/ViridianParcelStory.lua`,
  `src/core/TextPrinterState.lua`, `src/core/PlayerMovement.lua`, and the
  completed bounded-state task/review.
- Authoritative sources: verified ROM plus local FireRed
  `data/maps/ViridianCity_Mart/{scripts,text}.inc` and `map.json`.
- Evidence labels: `VERIFIED` against ROM SHA-1
  `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`: map 5,3; inbound doorway
  `(4,7)`; clerk local id 1 at `(2,3)`; on-frame descriptor `0x0816A1FB`;
  scene `0x0816A205`; movement `0x0816A25C`; and text pointers
  `0x0819021A`, `0x0819023A`, `0x08190289`.
- Dependencies / preconditions: the committed bounded persistent controller
  (`c615c10a`) and verified ROM runtime are available.

## Change boundary

- MAY CHANGE: `src/core/ViridianMartParcelPresentation.lua` (new), `main.lua`,
  `src/core/ViridianParcelStory.lua`, focused presentation tests, the existing
  natural-capture replay and marker if needed, and directly affected task/review
  documentation.
- MAY CHANGE IF NECESSARY: `src/core/PlayerMovement.lua` and its test only for
  a documented forced one-tile scripted-step primitive.
- MUST NOT CHANGE: generic ScriptBytecode/ScriptInterpreter/DialogueRunner
  semantics, generic map-hook scheduling, the Oak/Dex presentation, Mart UI,
  battle behavior, or save codec.
- OPERATOR APPROVAL REQUIRED: publication/push.

## Decision authority

- Owner may decide: finite-state presenter mechanics, ROM-backed text
  descriptor plumbing, diagnostics, and tests within the stated boundary.
- Owner must escalate: generic script engine scope, a presentation change to
  any other story scene, non-doorway entry behavior, or save-format change.

## Acceptance criteria

- [ ] On map entry at Mart `(4,7)` only, scene 0 locks field input, visibly shows all three
  ROM-backed messages with ordinary A/reveal progression, moves the player to
  `(4,3)` facing left, and ends unlocked.
- [ ] Parcel 349, Mart scene 1, and Lab scene 5 commit exactly once only after
  the request/receipt presentation; failed preconditions leave scene 0 and the
  bag unchanged. On a full Key Items pocket this deliberately retains the
  existing bounded controller's atomic no-commit behavior, rather than retail's
  malformed-inventory script-order side effect; do not claim parity for it.
- [ ] Scene 1 clerk remains non-shop; the existing scene 2 shop remains real.
- [ ] A verified-ROM replay proves presentation `DONE` and then proceeds into
  the already-proven Parcel -> Dex -> Mart-unlock capture/save/restart path.
- [ ] Focused tests, both 119-file suites, and independent review pass.

## Verification and evidence

- Verification: pure FSM test; ROM text/script fixture; no-ROM and verified-ROM
  `scripts/test_all.sh`; verified-ROM `runtime_natural_capture_replay.sh`.
- Evidence to preserve: runtime marker with `presentation=true` and
  `martScenePresented=1` (the presenter object is correctly nil after later
  map loads), receipt commit timing, source-lock assertions, and independent
  review record.
- Review required: `INDEPENDENT_REVIEW`

## Conditional execution rules

- Environment / target: LÖVE 11.5/Xvfb and the verified local FireRed ROM.
- Ordered procedure: verify descriptor data; implement/test pure FSM; wire map
  entry + rendering/input lock; update live replay; run evidence; review.
- Failure branches: if player is not `(4,7)`, clerk local id 1 is absent, map
  is not 5,3, or capacity fails, do not move/mutate and leave scene 0; if a
  required primitive forces generic script scope, stop and reshape.
- Rollback / recovery: do not commit a failing replay; all work stays on this
  task's paths until evidence passes.
- Security / privacy controls: N/A; local user-provided ROM only.
- External side effects: none in-task.
- Effort limit: reshape after three failed focused FSM/runtime attempts.
- Approved reference: FireRed Mart Parcel script/text and real doorway layout.

## Stop / escalate

Stop rather than guess if ROM fixtures contradict the reported pointers, a
non-doorway path must be supported, or cutscene completion requires generic
script functionality. Escalate changed product scope to the operator.

## AGI readiness

- Fresh-Agent Test: `PASS` — ROM-verified descriptor data and all paths are
  recorded here.
- No-Guess Test: `PASS` — descriptor and intentional full-bag divergence are
  explicit; no generic behavior may be inferred.
- Scope Test: `PASS` — write paths and non-goals are explicit.
- Authority Test: `PASS` — publication and broad engine work are excluded.
- Completion Test: `PASS` — tests/replay markers are pass/fail.
- Failure Test: `PASS` — guards and reshape boundary are explicit.
- Continuation Test: `PASS` — durable next action and evidence are recorded.

## Completion / handoff

- Completed: bounded live presenter wiring; focused FSM test (19/0); no-ROM
  and verified-ROM suites (120 files each); verified-ROM capture/save/restart
  replay with `presentation=true`, Mart scene `0 -> 1`, and fresh-process
  Mart scene `2`; independent functional review.
- Not completed: none for this bounded presentation task. Oak/Dex cutscene
  presentation remains explicitly outside this task.
- Current blocker: none.
- Next action if not DONE: none — independently reviewed completion.
