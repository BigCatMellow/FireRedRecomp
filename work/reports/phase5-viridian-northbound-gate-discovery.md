# P5-05 — Viridian northbound source/runtime lock

- Status: `READY_FOR_REVIEWER`; research, not implementation or traversal proof.
- Task: [P5-05 discovery](../tasks/phase5-viridian-northbound-gate-discovery.md).
- Runtime: `ba669fb420d68f54c8dab362c21bc0faf874f372`; research base/live main
  `86bf0aceeb81140dad703efc4fb5ffa3b529029c` has identical tracked Lua.
- Public pret/pokefirered source: `c75f352304d529f6ba92d4f74b9cf8b5c3810788`,
  clean checkout verified. All source citations below refer to this revision.
- Result: decoded events and accepted Old Man projection do not execute this
  gate. Select exactly one prerequisite: source-lock the missing live player
  elevation owner and its normal-step/bootstrap lifecycle. No implementation
  leaf is yet source-ready; do not substitute raw map height or a constant 3.

## Selected predicates and step priority

Source `data/maps/ViridianCity/map.json:202–238`,
`include/constants/vars.h:133`: scene variable is `0x4051`.

| Entry | Map-local x,y | Elevation | Scene equality | Script |
| --- | --- | --- | --- | --- |
| C0 | 22,11 | 3 | 0 | `ViridianCity_EventScript_RoadBlocked` |
| C2 | 20,8 | 3 | 1 | `ViridianCity_EventScript_TutorialTriggerLeft` |
| C3 | 22,8 | 3 | 1 | `ViridianCity_EventScript_TutorialTriggerRight` |

C1/gym is excluded. `src/field_control_avatar.c:1025–1063` scans source order,
matches x/y and equal elevation (or event elevation 0 wildcard), then compares
`VarGet(trigger)` with the event index cast to u8. These three entries have
nonzero triggers and scripts; immediate/weather cases are not their behavior.
`src/event_data.c:235–248` resolves the scene through saved vars.

`src/field_control_avatar.c:193–248,618–640` checks trainer sightlines, then
on-frame scripts, before completed-step coordinate scripts. A coordinate
script takes precedence over step warps/miscellaneous/step-count/repel work;
successful dispatch returns before ordinary wild encounters. This is not a
claim that coordinates precede trainers. `FieldGetPlayerInput:94–143`
constrains completed-step eligibility; arbitrary coordinate assignment is not
a source step event. Setup locks field controls (`src/script.c:347–369`).

The elevation input is stateful: `GetPlayerPosition`
(`src/field_control_avatar.c:345–348`) calls `PlayerGetElevation`
(`src/field_player_avatar.c:1092–1094`), which returns the player's object
event **previousElevation**, not the current map block's elevation.
`src/event_object_movement.c:8400–8411` samples both current/previous coordinate
grid heights. If either is 15, neither stored elevation changes; otherwise
currentElevation takes the current grid height, while previousElevation takes
it only if nonzero. Current height 0 therefore preserves previousElevation.
The bootstrap and exact update ordering relative to the first/completed
ordinary step are **UNKNOWN in this lock**; the assignment/update function
alone is not proof of when its value reaches the coordinate predicate.

## Source actions, continuation, and saved-state boundaries

`data/maps/ViridianCity/scripts.inc:188–237` establishes:

- Scene 0/C0: lock all, show/close the blocking message, move PLAYER one tile
  down, wait for that movement, release all, end. No scene write or reward.
  After release, another eligible entry can block again.
- Scene 1/C2: lock all; Old Man faces left in place and waits, PLAYER faces
  right in place and waits; call shared tutorial; release, end. C3 mirrors
  those directions. Neither turn displaces a tile.
- Shared tutorial: message/close; explicit Quest Log branch; cut recording;
  `StartOldManTutorialBattle`; `waitstate`; on return lock/face player/message;
  **write scene 2, then attempt Teachy TV**, final message, return to caller.
- Scene 2+: none of C0/C2/C3 matches. The shared NPC branch checks badge 1
  first, then scene >=2/completed, then scene 1/tutorial or scene 0/not-ready
  (`scripts.inc:97–104,123–126`). Thus scene 2 is not a reward retry route.

`src/scrcmd.c:983–1019` ties waitmovement 0 to the last moved object and waits
for completion. Lock/release behavior is at `1193–1254`; special dispatch at
`99–106` is not itself a wait, and waitstate (`127–130`) stops the script.
Quest Log is an excluded context, not deleted semantics: the macro at
`asm/macros/event.inc:1838–1841` branches on state 2 to
`EventScript_ReleaseEnd` (`data/event_scripts.s:1171–1173`), bypassing the
battle, scene write and reward. No Quest Log implementation is proposed.

Tutorial-specific path, not ordinary wild settlement:

| Seam | Source lock and consequence |
| --- | --- |
| Setup/control | `src/battle_setup.c:301–308` creates male level-5 Weedle in enemy slot 0, locks controls, sets the continue-script/music callback and exact OLD_MAN_TUTORIAL flag. `src/battle_controllers.c:84–109,290–321` selects Old Man control and the player's first living non-Egg party member; this is not the unused Pokédude party-backup path. |
| Temporary bag | `src/item_menu.c:2061–2103,2106–2139` backs up/replaces Items, Key Items, Poké Balls, registered item and pocket/cursor state, supplies temporary Potion/Poké Ball, then restores before returning from the automated bag. `src/battle_controller_oak_old_man.c:278–307,371–400` selects the item action. This is not ordinary player ball-use consumption/storage-capacity validation. |
| Capture destination | `src/battle_script_commands.c:9485–9489` forces tutorial success; `data/battle_scripts_2.s:99–103` sets CAUGHT and finishes without ordinary capture count/Dex/nickname/givecaughtmon steps at `73–97`. No tutorial Weedle is delivered to party or PC. Seen writes exclude this flag (`src/battle_main.c:2623–2630,2773–2785`). |
| Return | `src/battle_main.c:3824–3876,3915–3938` cleans up and invokes the saved callback; caught skips the evolution branch. `src/overworld.c:1670–1674` chooses `FieldCB_ContinueScriptHandleMusic`; `src/field_fadetransition.c:146–160` locks/fades and enables the script after the transition finishes. This resumes the script after waitstate, not a new NPC conversation. |
| Persistent reward | `asm/macros/event.inc:1787–1790` gives quantity 1 using STD_OBTAIN_ITEM. Teachy TV is key item 366 (`include/constants/items.h:438`, `src/data/items.json:5917–5929`). `src/item.c:201–261` can fail insertion for capacity; `data/scripts/obtain_item.inc:10–25,61–71` returns failure without rolling back the already-written scene 2. The final tutorial message still follows; no automatic retry is scripted. |

The normal scripted tutorial path does not replace the saved player party,
give a caught mon, or execute an EXP-award command. This is not a universal
claim that the tutorial flag disables every possible party mutation:
the EXP exclusion mask itself does not include Old Man
(`src/battle_script_commands.c:3127–3135`). Do not route reconstruction through
ordinary win/capture settlement. RNG is not zero: enemy creation and opponent
selection have random calls (`src/pokemon.c:1833–1852,1908–1919`,
`src/battle_controller_opponent.c:1350–1400`). Whole-scene RNG draw count,
frame-exact presentation, abnormal interruption/allocation failure recovery,
and malformed/empty-player-party behavior are **UNKNOWN**, not parity claims.
They do not block the selected elevation research, but would need explicit
decisions/source locks before a tutorial implementation or broader claim.

## Current production owners versus evidence

Runtime paths/line numbers below refer to the pinned runtime, not pret.

| Necessary seam | Current boundary and evidence |
| --- | --- |
| Scene/map input | `main.lua:388–407` owns location and saveBlock1 vars; `src/core/ViridianParcelStory.lua:75` writes scene 1. `main.lua:1783–1826` stores decoded coord events and applies accepted pre-spawn projection. Neither is coordinate execution. |
| Actual completed step | `main.lua:809–833` dispatches EarlyStory, connection, warp, trainer, then wild. `main.lua:2504–2531` passes map/x/y/events only, handling Oak escort/starter/rival actions. Its trainer ordering differs from the source above. `src/core/EarlyStory.lua:56–108` has only Pallet/lab branches and no elevation check. Selected Viridian cases return nil. |
| Missing live elevation | `import/MapBlockData.lua:24–35` decodes raw height; `main.lua:2282–2284` retains block data. `src/core/PlayerMovement.lua:50–58,95–127` owns position/normal-step timing but no currentElevation/previousElevation. No producer supplies effective player elevation to the story call. `tests/map_block_data_test.lua` asserts decoding only; `tests/player_movement_test.lua` is not proof of source elevation lifecycle. |
| Movement/lock | `main.lua:815–818,863–877` pauses ordinary movement while dialogue/presenters own input. This is not a script-controlled movement/wait scheduler. A message lock alone cannot execute C0's forced step or tutorial turns. |
| Script execution | `main.lua:2875–2908` starts DialogueRunner with text/facing/removal hooks, not saved vars, special/battle continuation, movement or item reward. `src/core/DialogueRunner.lua:80–135,207–215` exposes a limited world and terminates on interpreter errors. `import/ScriptBytecode.lua` does not decode waitstate 0x27. `src/core/ScriptInterpreter.lua:92–98,124–138,270–275,299–301,330–335` supplies optional hooks, not production lifecycle; STD_OBTAIN_ITEM 0 is absent and item hook handling does not set VAR_RESULT. `tests/dialogue_runner_test.lua:108–120` deliberately tolerates unhooked special/var operations, not tutorial execution. |
| Bag/battle settlement | `src/core/SessionBagBridge.lua:34–66` copies/persists ordinary pockets and `src/core/Bag.lua:101–124` models insertion limits; neither owns this temporary tutorial transaction. `main.lua:4495,4541,4583–4594` contains ordinary party/victory/capture/Dex settlement, not an Old Man callback adapter. Existing ordinary battle assertions cannot certify this branch. |

The [accepted projection review](../reviews/2026-10-10-viridian-old-man-projection-outcome-review.md)
at `d280751` records guarded run `38037052963`, job `114169565555`, with replay
not applicable; it proves projection, not tutorial/traversal. The
[accepted inventory](phase5-world-coverage-inventory.md) already leaves C0/C2/C3
execution uncovered. Neither inventory nor accepted Party/Dex work is reopened.

## Exactly one next prerequisite — proposal, not dispatch authority

Proposed ID: `P5-05-PLAYER-ELEVATION-INPUT-SOURCE-LOCK` (source-only).
Question: who initializes and updates the effective elevation consumed at a
normal Viridian completed step, and at which point can the reconstruction
read it without treating raw block height as that state?

Limit source tracing to avatar bootstrap, object-event elevation update call
sites, current/previous coordinate updates and the ordinary walking callback
leading to `GetPlayerPosition`; no general movement/collision rewrite or
tutorial implementation. Compare existing `src/core/PlayerMovement.lua`,
`import/MapBlockData.lua` and `main.lua` loadMap/playerMovementTask ownership.
Map-load/relocation entry must be classified before proposing initialization;
unsupported transitions must remain explicit stops, not silently reset to 3.

Proposed documentation-only allowlist (requires its own compiled task):
`work/tasks/phase5-player-elevation-input-source-lock.md` and
`work/reports/phase5-player-elevation-input-source-lock.md`.
Output must name the minimal future runtime/test paths only after proving
bootstrap/update timing. Likely inspection/test seams are the existing
`tests/player_movement_test.lua` and production completed-step dispatch in
`main.lua`, not a new unconsumed selector. No runtime changes are authorized
by this proposal or the present report.

Required future literal oracles: ordinary nonzero height updates both fields;
current 0 retains effective previousElevation; current or previous sampled 15
retains both fields; first-step and later-step observation matches proven
callback order; no update for a blocked/noncompleted step unless source shows
one. The first-step/timing expectations remain to be derived, not guessed.
Then require actual production ownership evidence, existing movement/early
story regressions, and source priority constraints before compiling any gate
implementation. A helper-only test cannot establish live input or gate closure.

Stops: unresolved bootstrap/timing, unsupported repositioning context,
private data dependence, another source revision, or needing general movement
state beyond the bounded prerequisite. Return exact UNKNOWN if encountered.
This dependency precedes C0/C2/C3 selection; waitstate/tutorial/reward gaps
remain later work, not parallel proposed leaves. Do not hardcode elevation 3,
use raw tile height unconditionally, change existing Pallet/lab predicates,
or claim this prerequisite alone opens/closes the northbound gate.

## Reproducible checks and receipts

Executed on 2026-10-15; no ROM, private runner or replay action:

- Source `git rev-parse HEAD` equals the pinned hash; `git status --short`
  empty. Runtime `git ls-remote origin refs/heads/main` equals research base;
  isolated worktree initially clean. `git diff --exit-code ba669fb HEAD --
  '*.lua'` passed (no runtime delta).
- From the pinned source checkout, `jq '.coord_events | to_entries |
  map(select(.key == 0 or .key == 2 or .key == 3))'
  data/maps/ViridianCity/map.json` reproduced the three literal predicates.
- Numbered reads: `nl -ba src/field_control_avatar.c | sed -n
  '193,248p;345,349p;618,640p;1025,1063p'`,
  `nl -ba src/field_player_avatar.c | sed -n '1090,1096p'`, and
  `nl -ba src/event_object_movement.c | sed -n '8400,8412p'` reproduced
  priority and stateful elevation; tutorial scripts/setup/bag/return anchors
  above were inspected separately, not inferred from reconstruction tests.
- A no-ROM Lua witness used EarlyStory with read-only stub vars and decoded-
  shape synthetic C0/C2/C3 events: map `3*256+1`, scene/position cases
  `(0,22,11)`, `(1,20,8)`, `(1,22,8)`, `(2,20,8)` all returned nil without
  writes. `PlayerMovement.new(22,11)` had both elevation fields nil;
  `ScriptBytecode.decode(string.char(0x27),0x08000000)[1].op` was
  `unimplemented`. These are gap witnesses, not gameplay acceptance tests.
- Repository checker baseline: PASS (320 tracked Lua, 362 tracked Markdown,
  1201 local targets). After-change checker/whitespace/public CI receipts are
  recorded in the task handoff; public CI is required before review acceptance.
- Parent's 192-file no-ROM baseline at `ba669fb` is carried as parent evidence,
  not rerun or independently claimed here. Docs-only full local suite N/A.

Independent Reviewer must verify exact report/source claims and two-path
scope. No source-lock PASS, normal-save proof, retail presentation parity,
route traversal, phase completion or implementation authority is self-awarded.
