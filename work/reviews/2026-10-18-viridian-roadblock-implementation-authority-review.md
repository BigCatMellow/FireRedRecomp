# Viridian C0 roadblock implementation authority — independent review

Verdict: **PASS** for exact authority revision
`0a15a5d14871a4aeb7d82164cda32b5d3c0f071e`.

This accepts only the bounded authority for a future nine-path implementation
package and one guarded request. It does not implement or accept C0 behavior,
authorize a direct runtime push, establish guarded gameplay evidence, or
advance Phase 5/7. The authority-review placeholder in the task remains
intentionally unresolved for Orchestrator adoption of this separate review.

## Authority and accepted sources

- Authority contract: [P5-06-VIRIDIAN-ROADBLOCK-IMPLEMENTATION](../tasks/phase5-viridian-roadblock-implementation.md), SHA-256 `61f0210857bccee6d6d4ca4fb01596a1238f0b0d31ea93302548113220c03478`.
- Accepted design: PR45 merge `6006ab6fbc7b9f1dd60a88dcbf6a8b0a08692947`, exact design `a7e12e0023a92b1790e3391ac64657f42e54e486`, independent PASS `1199a74db8dbbeb1528b171159096bd7d90767c5`.
- Accepted source pin: public pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`. I relied on the accepted design/report and did not retrace source research.
- Reviewed route: PR48 merge `2eb8fddac1cbb410097c8bcc9e44885e3c395cad`, configuration PASS `dbf2b3896e2993f86da8a0c2bbe251eb0b07db1c`.
- Readiness: PR50 merge `8c6e4fa90fa4fa49a9fbb17c64e16f37bd1e964b`, run `39165635888` / job `117787881344`, independent outcome PASS `da0352d47a2b882b8bf5e147417090769f0b8478`, adopted unchanged at `2c11211`.

The accepted design report, configuration review, and probe-outcome review are
byte-identical at this authority head to their accepted revisions. The source
references compiled by the authority remain the accepted C0 script/text,
message wait and speed-latch, scripted movement/wait/release, field ownership,
event priority, and current production-owner citations recorded in the design
report and design review.

## Findings

The contract faithfully compiles the accepted behavior without widening it:

- Admission is limited to a completed, stationary normal-input step on map 769
  at `(22,11)`, matching generation and valid effective elevation. Selection is
  exact C0 index 0 / trigger `0x4051` / scene value 0, with actual E3,
  event-E0 wildcard semantics, known player E0 distinction, and unknown-E
  refusal preserved.
- The bounded descriptor is exactly lock/text-style/default-message/explicit
  close/PLAYER normal-down/wait/release/end, with dynamic bounded pointer and
  text/control validation. Malformed selected context refuses; nonselected
  contexts retain legacy fallthrough. Trainer sightline is called once and
  wins before C0; the Viridian ON_TRANSITION-only precondition is retained.
- The presenter preserves exactly two pages, NEW A/B page acknowledgment,
  final NEW A before NEW B, held-versus-NEW isolation, one-press consumption,
  and the cross-page noninstant speed latch with delays 8/4/1 and no reveal-all.
  Unsupported options refuse without saved-option repair.
- The corrected timing matches the accepted report: acknowledgment does not
  close immediately; close occurs on a later update and before forced motion,
  with the runtime witness requiring a closed frame before the sixteen forced
  pixels. Movement is one direct stationary down step, bypassing ordinary
  collision/ledge admission, invalidating elevation, using no normal-step
  provenance, and releasing only after completion on a later update.
- Main retains one transient C0 owner and the full start-of-tick release input
  barrier. Player/NPC/input/menu/interaction ownership, no nested completed-step
  dispatch, refusal/cancellation, same-ID map teardown, stale-owner protection,
  and later normal-step re-entry are explicit. No persistent scene/reward state
  is added; serialized-state evidence permits only ordinary location/facing.
- Production tests must traverse actual completed-step dispatch,
  `InputState`/`love.update`, presenter, renderer selection, forced movement,
  teardown and recovery—not a helper-only action. Required negative mutation
  witnesses cover release-barrier omission, accidental collision/ledge
  admission, and nested completed-step dispatch.
- The dynamic SHA-verified ROM fixture must resolve and assert the selected
  event/map-script/script/movement/text shape through existing interfaces,
  without guessed constants, dumped bytes, or dialogue. Its guarded result must
  be non-skipped.
- The dedicated real LÖVE witness must use actual ordinary UP/tick completion
  from fixture setup, then prove page/input locks, NEW B page clear, NEW A final
  acknowledgment, close-before-motion, sixteen forced pixels, release barrier,
  persistent-state identity, no leakage/nested dispatch, and re-entry. It is
  explicitly fixture-backed C0 evidence, not normal traversal or tutorial proof.

The six focused commands remain in reviewed route order. Local baseline/final
evidence clears both ROM variables and runs the no-ROM suite, checker, and
whitespace checks. The guarded job retains apply/diff guards, the full no-ROM
suite, full non-skipped SHA-ROM suite, and dedicated replay before publication.
A separate exact guarded-outcome review remains mandatory.

The future patch and staging allowlists are exactly these nine paths:

1. `src/core/ViridianRoadblock.lua`
2. `src/core/PlayerMovement.lua`
3. `main.lua`
4. `tests/phase5_viridian_roadblock_test.lua`
5. `tests/phase5_viridian_roadblock_integration_test.lua`
6. `tests/phase5_viridian_roadblock_rom_test.lua`
7. `tests/player_movement_test.lua`
8. `scripts/runtime_viridian_roadblock_replay.sh`
9. `work/tasks/phase5-viridian-roadblock-implementation.md`

The sole future bridge input is
`work/local-runner/requests/phase5-viridian-roadblock-20261018.patch`.
It must be the triggering commit's only changed file/input. All nine artifacts
must exist before evidence and again before literal staging. There is no tenth
path, report, replacement input, retry, or second request. Canonical runtime
publication is exclusively through that guarded request after fresh parent
checks; a failed guard/job stops without retry.

The exclusions remain intact: no generic decoder/text renderer/VM/scheduler,
save/schema, imports/assets, route/workflow changes, shared replay wrapper,
other maps or C1/C2/C3, tutorial/Teachy TV, accepted projection redesign,
generic trainer/warp/encounter or collision/ledge expansion, private content,
normal traversal proof, visual/male-font/audio parity, or phase claim.

## Exact change and checks

Live GitHub recovery found PR51 open, non-draft, mergeable/`CLEAN`, at exact
head `0a15a5d14871a4aeb7d82164cda32b5d3c0f071e`, with no prior reviews and both
public Lua-test checks successful. Its eight changed paths are documentation,
coordination, the already accepted probe-outcome review, and this authority
task only. There is no request, implementation code/test/replay, workflow, ROM,
or runner artifact.

At the exact authority head:

- `git diff --check origin/main...HEAD`, working-tree diff check, and staged
  diff check passed.
- `lua5.1 scripts/check_repository.lua` with the project toolchain passed:
  **321 tracked Lua, 379 tracked Markdown, 1276 local targets**.
- Accepted design/configuration/probe review blob comparisons passed unchanged.
- No full no-ROM suite was repeated, as this is a documentation-only authority
  contract and the task explicitly defers execution evidence to the future
  implementation/guarded package.

After staging only this review artifact, the checker passed again at **321
tracked Lua, 380 tracked Markdown, 1277 local targets**; staged
`git diff --check` also passed.

No source retracing, ROM access, runner action, request, implementation,
workflow dispatch, or gameplay execution occurred in this review.

## Smallest correction and next allowance

Smallest correction: **none**.

After the Orchestrator adopts this exact PASS, it may assign one independent
Worker to construct the isolated nine-path package and collect the required
local no-ROM evidence. The parent may publish the sole literal guarded request
only after its fresh serialization, runner/job, route, prerequisite, current-
main applicability, and patch checks. Failure consumes the allowance; there is
no retry. Success still requires an independent exact guarded-outcome review
before bounded C0 behavior can be accepted.

Only this review artifact was authored. No authority task, coordination,
runtime, test, replay, request, workflow, ROM, or capability record was edited;
nothing was pushed or merged by the Reviewer.
