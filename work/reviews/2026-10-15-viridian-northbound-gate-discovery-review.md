# P5-05 Viridian northbound discovery — independent review

- Verdict: **PASS** for the bounded source/runtime discovery, not gameplay.
- Reviewed PR #42 revision: `684f69caa0f4efba2953b2782f0340d11913a0ac`.
- Authority/base: `86bf0aceeb81140dad703efc4fb5ffa3b529029c`;
  runtime: `ba669fb420d68f54c8dab362c21bc0faf874f372`.
- Contract: [P5-05 discovery](../tasks/phase5-viridian-northbound-gate-discovery.md).
- Artifact: [source/runtime lock](../reports/phase5-viridian-northbound-gate-discovery.md).
- Independent source checkout verified clean at
  `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.

## Findings and evidence

No material correction required. The exact two-path delta adds the report
and changes only task status/Worker evidence; acceptance and scope are intact.
There is no tracked Lua delta from the stated runtime baseline, nor any ROM,
asset, generated content, runtime, test or runner change.

Independently checked pinned source and actual production seams:

- Selected map entries are C0 `(22,11,3,scene0)`, C2
  `(20,8,3,scene1)`, C3 `(22,8,3,scene1)`, using scene var `0x4051`.
  `field_control_avatar.c:193–248,618–640,1025–1063` supports the recorded
  source-order/elevation/variable predicate and priority: trainer/on-frame
  checks precede the selected coordinate path; that path precedes ordinary
  warp/miscellaneous/step-count/repel and wild-encounter dispatch.
- `PlayerGetElevation` (`field_player_avatar.c:1092–1094`) really returns
  `previousElevation`. `ObjectEventUpdateElevation`
  (`event_object_movement.c:8400–8411`) retains both fields when either
  sampled grid height is 15, and retains previousElevation at current height
  0. The report correctly does **not** infer initialization or observation
  timing from this function alone.
- Viridian scripts `188–237` establish the forced down-step, mirrored
  in-place tutorial turns, waitstate continuation, and scene-2 write before
  reward insertion. NPC predicates `97–104,123–126`, Quest Log branch, and
  obtain-item failure path support the recorded exclusions and lack of an
  automatic scene-2 reward retry.
- Tutorial setup/controller selection, temporary bag backup/restoration,
  forced-catch branch without ordinary capture/Dex/delivery steps, and
  saved callback through `FieldCB_ContinueScriptHandleMusic` agree with the
  report's cited source. The apparent Pokerus calls in common cleanup are
  no-op FireRed stubs (`pokemon.c:5608–5616,5674–5686`), not an omitted party
  mutation. Ordinary settlement is not justified by this tutorial path.
  Exact scene RNG/frame counts and abnormal paths remain explicitly UNKNOWN.
- Production `main.lua` completed-step ordering, EarlyStory's Pallet/lab-only
  handlers, absent effective-elevation owner, limited DialogueRunner hooks,
  absent waitstate decoding and ordinary bag/battle adapters substantiate
  the missing wiring. Decoding and accepted Old Man projection do not close
  this gate. No existing accepted projection or Party/Dex review is reopened.

Actual independent checks at the reviewed revision:

- `git diff --check 86bf0ac HEAD`: PASS; two-path delta inspected.
- `git diff --exit-code ba669fb HEAD -- '*.lua'`: PASS, no runtime delta.
- Selected-source JSON query and numbered source/control-flow reads: PASS.
- No-ROM Lua gap witnesses: all four stated scene/coordinate cases return
  nil without session writes; new PlayerMovement has neither elevation
  field; opcode `0x27` decodes as `unimplemented`: PASS. These demonstrate
  missing behavior only, not route acceptance.
- `lua5.1 scripts/check_repository.lua`: PASS, 320 tracked Lua,
  363 tracked Markdown, 1205 local targets before this review addition.
- Live GitHub metadata independently confirms both exact-head public runs
  [38811790116](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/38811790116)
  and [38811761935](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/38811761935)
  completed successfully for `684f69c` (pull_request and push respectively).

The reported parent 192-file baseline is retained as parent evidence, not
claimed as a Reviewer rerun. No local full suite, ROM, private runner, replay
or gameplay traversal was performed or required for this documentation scope.

## Exact next allowance

Orchestrator may reconcile this source-only PASS and compile exactly the
proposed `P5-05-PLAYER-ELEVATION-INPUT-SOURCE-LOCK` documentation task:
bootstrap/map-load/relocation and ordinary-step producer/observation timing
for effective player elevation. UNKNOWN is a permitted research outcome;
the present uncertainty does not require guessed implementation.

That proposal is **not** runtime authority. Forced movement, generic script
VM, waitstate, tutorial battle/bag/reward lifecycle and encounter-priority
implementation remain later separately scoped work. No northbound traversal,
normal-save parity, retail presentation, phase completion or outstanding
battle/replay gate is accepted here. Final PR-head CI must pass after this
review-only publication before merge; Orchestrator owns merge/coordination.
