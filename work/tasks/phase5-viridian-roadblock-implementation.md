# Task: implement bounded Viridian C0 roadblock behavior

- Task ID: `P5-06-VIRIDIAN-ROADBLOCK-IMPLEMENTATION`
- Status: `READY_FOR_REVIEWER — AUTHORITY ONLY`
- Type: `IMPLEMENTATION AUTHORITY / GUARDED ROUTE`
- Parent capability gate: [Phase 5/7 first-corridor progression](../roadmaps/CAPABILITY_CHECKLIST.md)
- Assigned role: `ORCHESTRATOR`; independent authorization reviewer: `REVIEWER`.
- Prerequisites: accepted C0 design PR45 merge `6006ab6fbc7b9f1dd60a88dcbf6a8b0a08692947`
  and independent PASS `1199a74db8dbbeb1528b171159096bd7d90767c5`; route
  configuration PR48 merge `2eb8fdd` after PASS `dbf2b389`; single readiness
  probe PR50 merge `8c6e4fa`, run `39165635888` / job `117787881344` SUCCESS
  with all eight patch-only steps skipped; independent probe-outcome PASS
  `work/reviews/2026-10-18-viridian-roadblock-route-probe-outcome-review.md`
  at `da0352d47a2b882b8bf5e147417090769f0b8478`, adopted unchanged through
  canonical coordination cherry-pick `2c11211`; and this authority's exact
  independent PASS `<AUTHORITY_REVIEW_PATH_AND_PASS_REVISION>` followed by
  Orchestrator adoption. The authority-review placeholder is the remaining
  hard gate.
- Risk: `HIGH` — incorrect admission, input ownership, forced movement, or
  guarded publication could change field progression or publish an unauthorized
  package.

## Goal and source of truth

Authorize independent review of one future, bounded C0 implementation request.
This authority authorizes no implementation, request, test, replay, ROM access,
or runner action until its own exact independent authorization review is PASS
and the Orchestrator adopts that PASS.

The complete accepted authority is
`work/reports/phase5-viridian-roadblock-design.md`; compile it, do not retrace
its source research or add behavior requirements. The accepted route
configuration and probe task/review receipts control guarded execution only.
Unknown or malformed selected C0 context remains refused, never approximated.

## Exact future MAY CHANGE and execution envelope

Only after the authorization gate passes, Worker may construct one isolated
package and prepare exactly one guarded patch request:
`work/local-runner/requests/phase5-viridian-roadblock-20261018.patch`.
The request is the triggering commit's sole changed file/input, selects only
`phase5-viridian-roadblock`, and its patch targets only these nine literal
paths:

1. `src/core/ViridianRoadblock.lua`
2. `src/core/PlayerMovement.lua`
3. `main.lua`
4. `tests/phase5_viridian_roadblock_test.lua`
5. `tests/phase5_viridian_roadblock_integration_test.lua`
6. `tests/phase5_viridian_roadblock_rom_test.lua`
7. `tests/player_movement_test.lua`
8. `scripts/runtime_viridian_roadblock_replay.sh`
9. `work/tasks/phase5-viridian-roadblock-implementation.md` — contract and
   local evidence only; no implementation report or tenth path is authorized.

The reviewed bridge validation/staging sets remain exactly those nine paths.
All nine must exist after application and before the focused/full/replay
evidence, and again before literal staging/publication. No tenth path, report,
shared fixture/wrapper change, route change, replacement input, retry, or
second request is authorized. The probe allowance is consumed.

After authority PASS, Worker may make only allowlisted edits in an isolated
worktree and run the required local no-ROM checks. Canonical runtime publication
is exclusively the one guarded request, never a direct implementation push.
Immediately before publishing it, the parent Orchestrator serializes the action
and freshly confirms: online and idle `firered-local`; no queued/running bridge
job; unchanged accepted route/configuration; applicable patch against current
main; and unchanged prerequisite revisions/verdicts. Any change stops dispatch.
No local/private ROM search or access is allowed; ROM and LÖVE execution occur
only inside the existing hash-gated guarded job.

## Required bounded behavior and acceptance evidence

1. At `main.lua:playerMovementTask`, before the existing EarlyStory,
   connection, warp, trainer and wild fallthrough, admit only a real completed,
   nonmoving normal-input step on map769 at (22,11), with matching map
   generation and valid effective elevation. Do not use raw height, debug
   coordinate assignment, or scripted motion as ordinary-step admission.
2. Select only decoded C0 index0 with x22/y11, trigger0x4051, index/value0,
   valid script pointer, existing integer scene var 0..65535 and scene0.
   Require known E to match event elevation or event E0 wildcard; known player
   E0 is valid but not pinned E3, and unknown E never qualifies. The ROM
   fixture asserts actual selected E3; synthetic wildcard coverage must not
   broaden the real selection.
3. Validate a bounded C0-local descriptor: exact
   lockall/textcolor0/loadword0/callstd4/closemessage/applymovement PLAYER/
   waitmovement0/releaseall/end, range-checked text/movement pointers and
   movement walk_normal_down0x10/step_end0xFE. Preserve only selected plain
   text/newline/one-paragraph/end and reject malformed/truncated/conflicting
   identity, unexpected controls, missing terminator, unavailable text or
   unexpected map-script table. Do not widen the generic decoder or guess ROM
   pointers/constants.
4. Call the existing trainer-sightline owner once before C0; a trainer approach
   or battle wins and C0/warp/wild do not run. Validate Viridian's bounded
   ON_TRANSITION-only map-script precondition. Use `not_selected` for unchanged
   legacy fallthrough, `owned` for trainer/C0 consumption, and `refused` for
   selected unsupported context. Refusal is a C0-owned suppression until
   teardown/recovery: no silent default, teleport, scene/reward write or
   permanent global lock. Other maps/nonselected contexts retain their current
   dispatch order.
5. `ViridianRoadblock` owns only the bounded descriptor/presenter state:
   `IDLE → PRINT_PAGE1 → WAIT_PAGE → PRINT_PAGE2 → WAIT_FINAL → CLOSE_PENDING
   → WALK_DOWN → WAIT_MOVEMENT_END → RELEASE_PENDING → DONE`, with separate
   refusal/cancellation. Preserve two pages, NEW A/B page acknowledgment,
   final NEW A before NEW B, held-versus-NEW distinction, and source delay
   acceleration latch across both pages (activation prints no character;
   no reveal-all). Use valid slow/mid/fast delays8/4/1 and refuse unsupported
   options without saved-option repair. A press is consumed once; it cannot
   clear/acknowledge two states or accelerate a final character and acknowledge
   the just-finished message. Close must occur before motion on a later update
   than acknowledgment; do not unlock at the last pixel. START/SELECT/directions do not
   acknowledge; Quest Log is excluded.
6. Preserve the narrow renderer boundary: retain paragraph-clear before
   tokenization, page-specific printer state and cache reset on page/close;
   use blue foreground only for C0. Existing normal glyphs, geometry and lack
   of source male glyph/arrow/audio/cycle-exact parity remain stated limits.
   Do not change generic Charmap, TextPrinterState, DialogueRunner, renderer,
   imports, or introduce a generic VM/scheduler.
7. Main owns a single C0 owner and locks ordinary player input/tick, NPC tick,
   interaction and menus without overlapping existing dialogue/Mart/Oak/trainer/
   battle owners. Add only the stationary scripted-down PlayerMovement primitive:
   invalidate E, direct destination(x,y+1), down facing and normal 16-frame
   animation. It must bypass `isBlocked`/ledge callbacks and normal provenance,
   require a loaded-map destination, make no completed-step story/connection/
   warp/trainer/wild dispatch during forced ticks, sync location once at (22,12),
   wait completion, then release on a later update. No saved write other than
   ordinary location/facing consequences.
8. Capture C0 ownership at each fixed-tick start. Even when the forced task
   ends in that tick, suppress subsequently updated ordinary input for the full
   release tick; ordinary held direction resumes only next tick. NEW A/B is
   processed after InputState update. A/START/SELECT/B/direction combinations
   cannot leak to interaction, menus, battle or movement while owned/releasing.
   `loadMap`, including same-ID reload, tears down only C0 state; stale
   generation/position/owner cancels/refuses, invalidates E and never releases
   another owner or resumes old-map motion. A later valid normal up-step may
   retrigger: scene0 has no one-shot write.
9. Production extraction tests must drive actual completed-step dispatch,
   `InputState`/`love.update`, presenter task, renderer selection and forced
   movement through completion using synthetic map/text bytes and service stubs,
   not a helper-only returned action. Assert descriptor malformed/truncated
   paths; map/scene/position/C0 identity; E3/wrong4/known0/unknown and wildcard
   rules; trainer single-call priority; map-script precondition; A/B pages,
   latch/no-reveal-all/same-press isolation; close-before-move; exact facing,
   destination, 16px/16ticks and wait/release; locks/release barrier/recovery;
   no nested encounter/RNG; teardown/refusal/re-entry; and no scene/reward
   writes. Compare serialized state before/after allowing only location/facing.
   Include negative mutation witnesses for omitted release barrier, accidental
   collision/ledge admission, and nested completed-step dispatch.
10. Run these focused commands exactly, with the selected `$LUA`, in order:

    ```bash
    "$LUA" tests/phase5_viridian_roadblock_test.lua
    "$LUA" tests/phase5_viridian_roadblock_integration_test.lua
    "$LUA" tests/player_movement_test.lua
    "$LUA" tests/phase5_player_elevation_input_test.lua
    "$LUA" tests/early_story_test.lua
    "$LUA" tests/phase5_viridian_roadblock_rom_test.lua
    ```

    Local baseline and final runs use
    `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY bash scripts/test_all.sh`,
    `lua5.1 scripts/check_repository.lua`, and whitespace checks. The guarded
    job must pass `git apply --check`, `git diff --check`, full no-ROM
    `env -u POKEPORT_ROM bash scripts/test_all.sh`, then the full SHA-verified
    ROM `bash scripts/test_all.sh`. Local skips never substitute for guarded
    non-skipped evidence.
11. The ROM fixture verifies SHA-1
    `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc` through RomImporter before
    reads, resolves map/header/events through existing interfaces, and asserts
    C0/map-script/script/movement/text-pointer shape dynamically without guessed
    constants, dumped bytes or dialogue. Its guarded result must be non-skipped.
12. Guarded `bash scripts/runtime_viridian_roadblock_replay.sh` must execute the
    deterministic `viridian_roadblock` LÖVE case with private supported-ROM
    environment, finite timeout, zero exit, and exact marker
    `RUNTIME_REPLAY viridian_roadblock PASS`. Its fixture creates temporary
    session/map769, scene0 and (22,12) from verified data, then actual ordinary
    UP/tick completion reaches E3/(22,11): never inject eligibility. Witness
    page1 lock, NEW B clear, page2 NEW A final acknowledgment, closed frame,
    sixteen forced pixels, completion/release barrier, (22,12), unchanged
    scene/vars/flags/bag/party, NPC lock/no nested dispatch, input leakage
    failures, and re-entry. It is fixture-backed C0 execution, not normal
    traversal/fresh-save/northbound proof; no revealAll or teleport completion.
13. An independent exact guarded-outcome review verifies all nine paths,
    scope, local/guarded receipts, non-skipped SHA fixture, replay witness,
    assertions and exclusions before bounded behavior acceptance.

## MUST NOT CHANGE / stop conditions

No workflow/bridge/runner procedure, route configuration, requests other than
the sole input, probes, credentials, ROM configuration, canonical coordination,
capability status, generic decoder/text/rendering/VM architecture, save/schema,
imports/assets, accepted projection, other maps/scenes C1/C2/C3, tutorial,
Teachy TV, trainer/warp/encounter expansion, generic collision/ledge logic, or
shared replay wrapper. Do not commit ROM/BIOS/private path, extracted content,
caches, screenshots, private media or copied logs.

Stop for an unlisted/tenth path, changed prerequisite/route/current-main
applicability, source/design uncertainty, required new state, generic
architecture, missing non-skipped ROM evidence, failed guard/test/replay, or
need for a second request. Diagnose and record the precise blocker without
retry, replacement input, silent approximation, or status advancement.

## Completion and handoff

First independent Reviewer decides `PASS | NEEDS_FIX | BLOCK` on this exact
authority. Only after PASS and Orchestrator adoption may Worker construct the
nine-path isolated package, record its local evidence in path 9, and hand the
sole request to the parent. The parent performs fresh serial dispatch checks.
A failed guarded job stops. A successful guarded job requires a separate,
independent outcome review before C0 behavior acceptance. Orchestrator
reconciles only this bounded slice; it does not claim Phase 5/7 completion or
normal northbound/traversal proof.
