# Task: prove bounded Viridian Parcel/Dex runtime progression

- Status: `DONE`
- AGI status: `AGI READY`
- Type: `IMPLEMENTATION`
- Owner: `/root`
- Risk: `MEDIUM`
- Goal: A fresh post-rival runtime can prove the bounded persistent Viridian
  Mart -> Parcel -> Oak -> Dex -> Mart-unlock state sequence, then save/reload
  a catch. This is a child proof task, not the visible-cutscene completion.

## Inputs and source of truth

- Inputs: `main.lua`, `src/core/ViridianParcelStory.lua`,
  `tests/viridian_parcel_story_test.lua`,
  `scripts/runtime_natural_capture_replay.sh`, and the existing natural-capture
  replay.
- Authoritative sources: verified FireRed ROM and its local decomp sources
  `data/maps/ViridianCity_Mart/scripts.inc` and
  `data/maps/PalletTown_ProfessorOaksLab/scripts.inc`; the runtime's live
  collision map is authoritative for replay route selection.
- Evidence labels: source state transitions and the existing Route 1 failure
  at `(12,38)` are `VERIFIED`; a valid southbound Route 1 replay path is
  `UNKNOWN` until collision-derived and reproduced.
- Dependencies / preconditions: verified ROM at the path used by the test
  command; post-rival route replay remains passing before this work begins;
  `work/tasks/viridian-parcel-dex-progression.md` remains the parent contract
  for visible movement/message/fanfare parity.

## Change boundary

- MAY CHANGE: `main.lua`, `src/core/ViridianParcelStory.lua`,
  `tests/viridian_parcel_story_test.lua`, a new focused ROM/runtime test or
  `scripts/runtime_natural_capture_replay.sh`, and this task plus directly
  affected Phase 3 roadmap/handoff documentation.
- MUST NOT CHANGE: generic map-script execution, save-file format, battle
  rules, title/Oak intro, remote repository state, unrelated Phase work, or
  the parent task's visible-cutscene acceptance criterion.
- MAY CHANGE IF NECESSARY: a separate source-lock test, only after recording
  its path and acceptance purpose in this task.
- OPERATOR APPROVAL REQUIRED: publishing/pushing a resulting commit.

## Decision authority

- Owner may decide: collision-derived replay inputs, bounded controller API,
  diagnostics, and tests that preserve the listed retail persistent state.
- Owner must escalate: generic script-engine scope, retail cutscene/movement
  parity claims, altered save compatibility, or any new external publication.

## Acceptance criteria

- [ ] Scene 0 Mart entry grants exactly one Parcel and makes the scene-1 clerk
  non-shop; scene 2 reaches the real `pokemart` path. This criterion covers
  persistent state and interaction gating, not cutscene presentation.
- [ ] The replay reaches Oak through legal live movement from the Mart and
  persists Parcel removal, Dex flag `0x829`, five balls, Lab scene 6, and Mart
  scene 2 before its purchase/catch path.
- [ ] The replay's fresh-process restart marker confirms the caught party
  member, a positive reduced Poké Ball stack, Parcel absent, Dex flag `0x829`,
  Lab scene `6`, and Mart scene `2`.
- [ ] Focused unit/ROM tests, no-ROM suite, verified-ROM suite, and an
  independent functional review pass.

## Verification and evidence

- Verification: `lua5.1 tests/viridian_parcel_story_test.lua`; `bash
  scripts/test_all.sh`; `POKEPORT_ROM=/home/mellow/Documents/Projects/Pokemon_ReComp_FireRed/FireRed/pokefirered-master/pokefirered.gba bash scripts/test_all.sh`; and the same `POKEPORT_ROM` with
  `bash scripts/runtime_natural_capture_replay.sh`.
- Evidence to preserve: terminal results, replay marker with scene/Dex state,
  source-lock test evidence, and an independent review record.
- Review required: `INDEPENDENT_REVIEW`

## Conditional execution rules

- Environment / target: LÖVE 11.5 under the project runtime plus a verified
  FireRed ROM; deterministic runtime replay input.
- Ordered procedure: derive and reproduce the southbound Route 1 path first;
  only then integrate it into the replay; then verify persistence and review.
- Failure branches: IF a candidate route fails to reach Pallet, retain a
  diagnostic checkpoint and derive a new collision-valid path; IF controller
  changes require generic script scheduling, stop and create a separate task.
- Rollback / recovery: retain existing committed runtime behavior; do not
  commit/publish any regression. Revert only task-owned uncommitted paths if
  the bounded approach is disproven.
- Security / privacy controls: N/A; use only the local user-supplied ROM.
- External side effects: no publish within this task.
- Effort limit: stop and re-shape after three independently derived route
  attempts fail to reach Pallet.
- Approved reference: the two named FireRed map scripts and live ROM collision.

## Stop / escalate

Stop rather than guess if replay routing requires a collision bypass, direct
position/state injection, an unverified local-id assumption, or generic map
script behavior. Escalate to the operator for changed product scope; create a
research/repair task for a missing runtime capability.

## AGI readiness

- Fresh-Agent Test: `PASS` — sources, paths, state, and next action are here.
- No-Guess Test: `PASS` — only collision-derived route inputs are allowed.
- Scope Test: `PASS` — write paths and non-goals are explicit.
- Authority Test: `PASS` — publishing and broader engine work are excluded.
- Completion Test: `PASS` — replay markers and named commands are pass/fail.
- Failure Test: `PASS` — routing and scope failure branches are defined.
- Continuation Test: `PASS` — diagnostics/evidence and next action persist.

## Notes / decisions

- `VERIFIED`: a literal inverse of the northbound Route 1 inputs stops at
  Route 1 `(12,38)` because it is not valid against one-way/collision rules.
- `VERIFIED`: Oak's decoded object-event local id is 4, after three implicit
  Lab object ids; do not use the earlier incorrect id 1 claim.
- The parent task is not superseded: it still owns the unresolved visible
  movement/messages/fanfare requirement. This task may not claim that parity.

## Completion / handoff

- Completed: the current uncommitted worktree has a scoped controller, Mart
  on-load and clerk/Oak routing, a collision-valid southbound Route 1 replay,
  and fresh-process persistence assertions. The focused test, both 119-file
  suites, and `runtime_natural_capture_replay.sh` pass with the verified ROM.
- Not completed: publication; visible cutscene parity remains owned by the
  parent task.
- Current blocker: none.
- Next action if not DONE: none — this bounded task is independently reviewed.
