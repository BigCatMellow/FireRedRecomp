# P5-06 — C0 roadblock design and guarded evidence proposal

- Status: `READY_FOR_REVIEWER`; design only, not implementation/route authority.
- Task: [bounded C0 design](../tasks/phase5-viridian-roadblock-design.md).
- Dispatch base `d59f28f844ec9a45abec0f307bae92525c932501`; runtime
  `75b49f3a3cbeb877137372a40a0b92973172fad1` (tracked Lua unchanged at dispatch).
- Source: clean public pret/pokefirered
  `c75f352304d529f6ba92d4f74b9cf8b5c3810788`. Source citations below use this pin.
- Adopt [accepted northbound facts](phase5-viridian-northbound-gate-discovery.md)
  and [accepted elevation lifecycle](phase5-player-elevation-input-source-lock.md).
  PR44's actual movement ownership is consumed, not redesigned.
- One proposed implementation: a C0-specific descriptor/presenter plus existing
  main/player/text services. No C1/C2/C3, tutorial, reward, generic VM or gate-
  completion claim. Guarded gameplay evidence is required, not deferred under P4.

## Additional source facts that control this slice

`data/maps/ViridianCity/scripts.inc:188–201` is lockall, male text color,
default msgbox, closemessage, PLAYER walk_down, waitmovement0, releaseall/end.
The move is exactly one normal down action followed by step_end. No scene,
flag, item, party, bag, RNG or reward write is part of this script.

- Msgbox expands to loadword0/text plus callstd4
  (`asm/macros/event.inc:59,1778–1781`). STD default is message, waitmessage,
  waitbuttonpress, return (`data/scripts/std_msgbox.inc:18–22`); it does not
  implicitly release or close. `src/scrcmd.c:1264–1271,1301–1310` separates
  printing completion from hiding the message frame.
- C0 text structure at `data/maps/ViridianCity/text.inc:39–42` is two pages:
  a newline within page1, then paragraph-clear, then page2/end. No dialogue
  bytes or reconstructed strings belong in git. `include/characters.h:178–182`
  identifies paragraph-clear0xFB/newline0xFE/end0xFF. Source paragraph-clear
  waits for NEW A/B, clears the window and resets its cursor
  (`src/text.c:550–585,796–803,863–870`). Holding a button is not a page press.
- Final acknowledgment tests NEW A first, then NEW B
  (`src/scrcmd.c:1313–1318`). The directional-dismiss optimization does not
  apply: `ScriptContext_NextCommandEndsScript:1351–1363` follows the standard
  script return to C0's **closemessage**, not release. START/SELECT/D-pad are
  not C0 message acknowledgment. Quest Log playback is excluded, not emulated.
- Reveal speedup is not reveal-all: `src/text.c:639–650` latches acceleration
  on NEW A/B while a character delay is pending, then HELD A/B clears delay
  once latched. The activation frame returns without printing that character;
  waits/pages still require NEW presses. `src/new_menu_helpers.c:27–32,423–435,
  658–663` supplies delays8/4/1 for valid slow/mid/fast options. Unsupported
  options are refused here, not repaired by writing saved options.
- Source male style uses blue text and distinct male glyphs
  (`src/new_menu_helpers.c:429–431`, `src/text.c:252–253,1593–1598`). Existing
  TextRenderer exposes normal glyphs only. This design retains that inherited
  glyph/layout/audio limitation, can use the existing blue palette token, and
  makes **no source styling/visual parity claim**. No guessed male-font pointer
  or renderer/import expansion is needed for readable page progression.
- `src/event_object_lock.c:26–40` freezes NPCs and waits for the player to stop;
  selected C0 admission occurs at an already completed ordinary step.
  `src/script_movement.c:20–28,202–225` installs a held movement action directly,
  waiting if an action is already active. `ObjectEventSetHeldMovement`
  (`src/event_object_movement.c:5049–5061`) unfreezes that object and starts the
  action. This route does **not** call ordinary collision/ledge admission.
  The accepted normal action timing applies: sixteen 1px ticks for walk_down.
  `MOVEMENT_ACTION_WALK_NORMAL_DOWN=0x10`, STEP_END=0xFE
  (`include/constants/event_object_movement.h:104,262`).
- Step_end reports completion and freezes the moved object; waitmovement0
  waits for the last moved object (`src/scrcmd.c:983–1019`). Releaseall clears
  the frame/finished action and unfreezes objects (`1231–1240`). Script controls
  unlock only when the script terminates (`src/script.c:326–340`). Native waits
  return to bytecode on a later script pass (`82–103`), not recursively in the
  same call. CB1 input precedes CB2 script/tasks/sprites, as already accepted;
  a CB2 release cannot retroactively enable that frame's CB1 input.

## Admission and bounded priority

At the real completed normal-step boundary in `main.lua:playerMovementTask`,
before existing EarlyStory/connection/warp/trainer/wild fallthrough, classify
only map769 at (22,11). Require a completed, nonmoving normal-input step whose
map generation still matches; use PlayerMovement's valid effective E getter.
Do not inspect raw height instead, qualify script motion, or accept debug
coordinate assignment as a completed ordinary step.

Require decoded C0 index0 with x22/y11, trigger0x4051, index/value0 and a valid
scriptPtr. Check the saved var entry exists and is an integer0..65535 before
using the session getter; missing storage must not be treated as default0.
Nonzero scene is not selected. Known E must equal event elevation, or the event
elevation must be0 wildcard (`field_control_avatar.c:1045–1063`). Known player
E0 is valid but does not match pinned event3; unknown E never satisfies even a
wildcard. ROM fixture must assert the actual selected event elevation is3;
synthetic wildcard tests distinguish source semantics, not broaden selection.

Before publishing an action, validate a bounded descriptor from C0.scriptPtr:
exact lockall/textcolor0/loadword0/callstd4/closemessage/applymovement PLAYER/
waitmovement0/releaseall/end sequence; resolve text and movement pointers from
that byte stream, range-check every read, and verify movement0x10/0xFE. Existing
ScriptBytecode can read most instructions but not textcolor0xC7; a C0-local
fixed-layout descriptor reader is preferable to widening the generic decoder.
Its opcode/operand constants come from the pinned macros, never guessed ROM
addresses. Bound text scanning to a conservative limit; accept the selected
plain-character/newline/one-paragraph/end shape, reject unexpected controls,
missing terminator, malformed pointers or conflicting C0 identity.

For a selected candidate, call the **existing trainer sightline owner once
before C0**. If it starts an approach/battle, it wins and no C0/warp/wild runs.
Do not retry trainer detection later in the same step. Source on-frame scripts
also precede coordinates. Pinned Viridian's map-script table contains only
ON_TRANSITION (`data/maps/ViridianCity/scripts.inc:1–3`); validate that bounded
table shape from decoded header data before C0 admission. An unexpected
on-frame table is unsupported: stop the selected candidate rather than invent
a generic on-frame executor. Other maps and nonselected scenes/positions keep
their existing dispatcher order and Pallet/lab predicates unchanged.

Return a tri-state to main: not_selected (unchanged legacy fallthrough), owned
(trainer/C0 consumed this step), or refused (selected context unsupported).
Missing/malformed selected input, unknown E, conflicting active owner, script
shape mismatch or unavailable text becomes an explicit diagnostic refusal,
not “no event” followed by encounter/warp progress. Keep a C0-owned refused
state that suppresses further player actions until map teardown/recovery;
do not pretend this unsupported context is playable. No teleport, scene write,
silent E default or permanent global lock. Refusal and cleanup are defensive
reconstruction behavior, not claimed retail error recovery.

## Presenter, text, movement and input owners

One new `ViridianRoadblock` module owns descriptor validation and the bounded
presentation state. It has nonmutating admission inputs and explicit host
notifications; it cannot write session state. Proposed progression:

`IDLE → PRINT_PAGE1 → WAIT_PAGE → PRINT_PAGE2 → WAIT_FINAL → CLOSE_PENDING
→ WALK_DOWN → WAIT_MOVEMENT_END → RELEASE_PENDING → DONE`.

Refusal/cancellation is separate from DONE. A page press is consumed once:
no same NEW A/B may both clear page1 and acknowledge page2, or accelerate the
last character and acknowledge the just-finished message. Arm final wait only
after printing completes; close occurs on a later update than acknowledgment.
Preserve native-wait ordering without claiming cycle-exact VM/task latency.
Do not unlock at the last pixel before movement completion has been reported.

- C0-specific raw-text splitting preserves 0xFB before Charmap.tokenize, which
  currently collapses 0xFA/FB/FE to newline (`import/Charmap.lua:274–278,428`).
  Tokenize each page through existing services. Use a narrow page-printer view
  (`tokenIndex`, `revealedTokens`) compatible with existing main text rendering.
  Reveal plain glyphs/newlines with the source delay/latch rules above; do not
  call TextPrinterState.revealAll or borrow Mart's A-only policy. No generic
  Charmap/TextPrinterState/DialogueRunner change. Page replacement must reset
  main's image cache even when old/new token indices happen to be equal.
- Main adds this printer to existing `ensureDialogueImagesCurrent` and draw
  selection, resets cache on page/close, uses blue foreground for C0 only and
  preserves existing other presenters. Normal glyphs, existing geometry and
  no source arrow/audio parity remain explicit presentation limits.
- Main owns lock guards on ordinary player input/tick, NPC tick and interaction/
  menus. Use one active C0 owner, no overlap with dialogue/Mart/Oak/trainer/battle
  owners. Its own forced-motion task may tick the player while ordinary movement
  is paused. No generic script scheduler is introduced.
- Add one narrow PlayerMovement scripted-down start API: only when stationary,
  invalidate elevation, set destination(x,y+1), down facing and normal16-frame
  animation directly. **No isBlocked or ledge callback**, no normal provenance.
  Preflight must have the destination in the loaded map; an unavailable map
  target is refusal, not permission to use ordinary collision as an oracle.
  During forced ticks, do not call completed-step story/connection/warp/trainer/
  wild dispatch. At (22,12), sync the existing session location once, report
  movement complete, then release/end on a later update. No other saved write.
- Main's scheduler runs before its input update, unlike source CB1. Capture
  whether C0 owned the start of each fixed tick; even if its movement task ends
  in that tick, consume/suppress the subsequently updated ordinary input for
  that entire tick. Process message NEW A/B after InputState.update, not the
  previous tick's mask. On the next tick, ordinary held direction may resume.
  A/START/SELECT/B/direction combinations must not leak into interaction, menus,
  battle or movement during ownership or the release barrier.
- loadMap tears down only the C0-owned printer/lock/pending forced action before
  replacing map data, including same-ID reloads. Generation/position/owner
  mismatch during the scene cancels its work, invalidates elevation and exposes
  refusal; do not release another owner's lock or resume stale motion on a new
  map. Existing source-elevation rules deliberately leave scripted motion E
  unknown. A later normal up-step onto height3 may converge and retrigger C0:
  scene0 is unchanged, so there is no one-shot flag.

## One implementation proposal — exact nine paths

Proposed task `P5-06-VIRIDIAN-ROADBLOCK-IMPLEMENTATION`, not dispatched here:

1. `src/core/ViridianRoadblock.lua` (descriptor/presenter/page reveal)
2. `src/core/PlayerMovement.lua` (narrow scripted-down start only)
3. `main.lua` (selected dispatch, ownership, existing rendering, replay branch)
4. `tests/phase5_viridian_roadblock_test.lua` (new synthetic descriptor/presenter)
5. `tests/phase5_viridian_roadblock_integration_test.lua` (new actual main paths)
6. `tests/phase5_viridian_roadblock_rom_test.lua` (new opt-in fixture)
7. `tests/player_movement_test.lua` (scripted-down primitive regressions)
8. `scripts/runtime_viridian_roadblock_replay.sh` (new guarded wrapper)
9. `work/tasks/phase5-viridian-roadblock-implementation.md` (contract/evidence)

No generic decoder, text renderer, save, projection, unrelated scene, shared
replay wrapper or existing bridge request belongs to this code package.
Keep main's existing world.* helper pattern to avoid its 200-local ceiling.

Literal tests: descriptor with bounded pointers and malformed/truncated input;
map/scene/position/C0 identity; correct3/wrong4/known0/unknown E; wildcard only
with known E; trainer priority/single call; no-on-frame precondition; complete
two-page A and B paths, A-before-B, held versus NEW, delay activation frame,
no reveal-all, page/final same-press isolation; close before motion; blocked/
ledge callbacks must not be invoked by the scripted primitive; exact down
destination/facing/16px/16ticks; wait-before-release; NPC/input lock; full
release-tick suppression and next-tick recovery; no nested encounters/RNG;
map teardown/stale owner refusal; re-entry; source lacks scene/reward writes.

Production extraction tests must execute actual completed-step dispatcher,
InputState/love.update, presenter task, renderer selection and forced movement
through completion, with synthetic map/text bytes and service stubs. Compare
serialized state before/after allowing only ordinary location/facing changes;
no helper-only returned-action proof. Include mutation witnesses for omitting
the release-tick barrier and accidentally calling ordinary collision/ledge
admission or nested completed-step dispatch.

## Complete evidence and guarded-route proposal

Implementation baseline/final: `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY
bash scripts/test_all.sh`, `lua5.1 scripts/check_repository.lua`, both whitespace
checks. Focused commands (literal new route list):

```sh
lua5.1 tests/phase5_viridian_roadblock_test.lua
lua5.1 tests/phase5_viridian_roadblock_integration_test.lua
lua5.1 tests/player_movement_test.lua
lua5.1 tests/phase5_player_elevation_input_test.lua
lua5.1 tests/early_story_test.lua
lua5.1 tests/phase5_viridian_roadblock_rom_test.lua
```

The ROM fixture must verify SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`
through RomImporter before reading bytes. Resolve map header/events from existing
RomAddresses/MapHeader/MapEvents; assert pinned C0, map-script table, full script/
movement shape, text page structure and valid pointers. Resolve text dynamically,
never add guessed pointer constants or print/commit dialogue. Without ROM it
skips clearly; acceptance requires its later **non-skipped** guarded receipt.

New deterministic runtime case `viridian_roadblock`, wrapper command
`bash scripts/runtime_viridian_roadblock_replay.sh`; supported-ROM verification,
headless LÖVE, finite timeout and exact marker
`RUNTIME_REPLAY viridian_roadblock PASS` plus zero process exit required.
The wrapper sets `POKEPORT_RUNTIME_REPLAY=viridian_roadblock` with the existing
private verified-ROM environment; it must not write private paths/content.

Witness setup is an explicit fixture: construct a temporary session/map769,
scene0 and position(22,12) from verified data; then use actual ordinary UP input
and tick completion to obtain E3 at(22,11), never inject an eligibility result.
Observe page1 lock, real page clear/new B, page2/new A final acknowledgment,
closed frame before forced down, sixteen forced pixels, completion/release
barrier, location(22,12), unchanged scene/vars/flags/bag/party, NPC lock and no
encounter/nested dispatch. Repeat the up-entry to prove retrigger. Inject held
direction/START/A/B at selected locked/release ticks; fail on leakage. No
revealAll/teleport-to-completion in the witness. This is **fixture-backed C0
execution**, not a normal fresh-save walk to Viridian or whole northbound proof.

No current bridge route admits this package: projection has five unrelated
paths and explicitly no replay; the shared runtime_replay_smoke wrapper accepts
only house_to_pallet/route1_wild_defeat/route1_wild_win/natural_capture. Do not
reuse either route or alter their meaning. Proposed new literal selector:
`phase5-viridian-roadblock*.patch|phase5-viridian-roadblock*.probe` → route
`phase5-viridian-roadblock`. Its validation and staging allowlists must both
equal the nine code-package paths above; require every artifact before execution
and publication, reject all unknown paths. Run the six focused commands, shared
no-ROM and SHA-verified-ROM full suites, then the new replay wrapper. Probe mode
is readiness only and cannot establish gameplay or publish code.

Necessary separate configuration boundary is exactly
`.github/workflows/local-worker-bridge.yml` (selector/validation/focused/replay/
mandatory staging arms) and `work/coordination/LOCAL_RUNNER_BRIDGE.md`, plus its
compiled configuration task/evidence. This report already supplies the route
plan; no additional route-plan discovery is needed. Configuration syntax/safe-
stub tests must prove positive/negative selectors, all nine allowed targets,
unknown/forbidden target rejection, every missing artifact failure and exact
commands. New configuration/probe/request authority and fresh runner/job checks
are still required before guarded use; old allowances remain consumed. No
workflow/probe/request or ROM execution is authorized by this design.

## Actual checks, limits and handoff

Clean source/base verified; `git diff --exit-code 75b49f3 HEAD -- '*.lua'`
passed. Parent's independently accepted193-file no-ROM baseline is carried
evidence, not rerun locally. Baseline repository checker PASS (321 Lua,
370 Markdown,1242 targets). Final docs/whitespace receipts are in the task.

Executed narrow source searches/numbered reads: `rg -n 'WaitForAorBPress|ScriptContext_NextCommandEndsScript|ScrCmd_lockall|ScrCmd_releaseall' src/scrcmd.c`;
`nl -ba src/text.c | sed -n '550,585p;629,662p;858,890p'`;
`nl -ba src/script_movement.c | sed -n '196,226p'`; reads of default msgbox,
event macros, field-message/lock helpers and current main/text/movement owners.
Text was inspected only for control structure, not copied into this report.
Read-only route checks used `rg -n 'phase5-viridian-old-man-projection'
.github/workflows/local-worker-bridge.yml work/coordination/LOCAL_RUNNER_BRIDGE.md`
and the existing replay wrapper's accepted-case list. No gameplay tests,
ROM/replay/runner action or route readiness check occurred in this design task.

Remaining limits: source male-font/arrow/audio/cycle-exact presentation parity,
Quest Log/link mode, unexpected on-frame tables or message controls, abnormal
interruption and any other coordinate handler are not implemented by proposal.
Readability/page progress do not depend on solving the inherited font limitation.
Stop if implementation needs generic text/VM/collision architecture, a tenth
code path, new saved state or another map/tutorial branch. Exact independent
design/source review and new guarded receipts remain gates; no self-acceptance.
