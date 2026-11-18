# P5-07 — field-side design for the Viridian tutorial triggers, with a guarded-evidence proposal

- Status: `READY_FOR_REVIEWER`. This is a design only. It gives no
  implementation or route authority.
- Task: [P5-07 design](../tasks/phase5-viridian-old-man-tutorial-trigger-design.md).
- Base: PR #80 head `cc287e5`. Runtime: `df53c7770c1df5884f4c3924e331c5efebe91925`
  (tracked Lua is unchanged).
- Source: clean pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
  All source citations use this pin.
- Adopts:
  - the [P5-07 discovery](phase5-viridian-old-man-tutorial-trigger-source-discovery.md)
    (admission, collision proof, script order, UNKNOWNs);
  - [P5-05](phase5-viridian-northbound-gate-discovery.md);
  - the [C0 design](phase5-viridian-roadblock-design.md) (lock, NEW A/B,
    reveal latch, held movement, CB1/CB2 order, refusal pattern).

  None of these is repeated here.
- Proposed implementation: one C2/C3-specific module plus existing services.
  It runs to a fail-closed refusal at the battle special. It does not run the
  battle, write scene 2, give Teachy TV, run `release`, add a generic VM, or
  claim the gate is complete.

## Outside dependency: the Old Man tutorial battle

The battle lane owns everything from `special StartOldManTutorialBattle`
(`data/maps/ViridianCity/scripts.inc:229`) onward:

- the battle itself, and the `waitstate` return (`:230`);
- `lock`/`faceplayer` (`:231–232`);
- the scene-2 write (`:234`);
- Teachy TV (`:235`);
- the caller's `release`/`end` (`:210–211`, `:221–222`).

**The post-battle state stays UNKNOWN**: party, bag, vars, flags, RNG and
anything else saved. Nothing here assumes restoration or rollback.

The battle-lane trace `ec2d8e9` is **pending review** and is cited only as
input. It reports:

- no party writes;
- a bag swap and restore;
- save-block re-encryption;
- `VAR_POISON_STEP_COUNTER` set to 0;
- result 7.

No decision below depends on it.

## Additional source facts that control this slice

- **Script bytes.** All opcodes come from `asm/macros/event.inc`:

  | Instruction | Bytes | Macro line |
  | --- | --- | --- |
  | lockall | 0x69 | :858–859 |
  | textcolor | 0xC7 + u8 | :1545–1547 |
  | applymovement | 0x4F + u16 localId + u32 ptr | :598–602 |
  | waitmovement | 0x51 + u16 | :616–619 |
  | call | 0x04 + u32 | :22–24 |
  | msgbox | loadword 0x0F, 0 + u32, then callstd 0x09, 4 | :1778–1781, :104–107, :68–70, :59 |
  | closemessage | 0x68 | :853–854 |
  | special | 0x25 + u16 | :274–276 |

  - `goto_if_questlog` expands to `special GetQuestLogState`, then
    `compare VAR_RESULT, 2`, then `goto_if_eq` (`:1838–1841`).
  - The special IDs are positional (`data/specials.inc:1–12`, with no
    conditional blocks): `StartOldManTutorialBattle` = **0x9D** (`:168`) and
    `QuestLog_CutRecording` = **0x188** (`:403`). The descriptor derives
    `GetQuestLogState`'s ID the same way. Tests recompute every ID from the
    pinned file; none is a guessed literal.
  - `LOCALID_PLAYER` = 255 (`include/constants/event_objects.h:205`).
    `LOCALID_TUTORIAL_MAN` is object 4 (`map.json:77–91`).
  - `waitmovement 0` uses `LOCALID_NONE` = 0 (`:202`), meaning the last moved
    object (`src/scrcmd.c:983–1019`, per P5-05).
- **The man's turn.**
  - C2 turns the man left and the player right (`scripts.inc:205,207`).
  - C3 turns the man right and the player left (`:216,218`).
  - The movements are single actions followed by `step_end`
    (`data/scripts/movement.inc:28–30,36–38`). Faster-left is 0x2F and
    faster-right is 0x30 (`include/constants/event_object_movement.h:135–136`;
    `asm/macros/movement.inc:54–55`).
  - Each action sets the direction at once and runs for **4 frames** without
    moving (`src/event_object_movement.c:6133–6140,6245–6255,6142–6151`).
  - `applymovement` installs a held action and unfreezes that object, even
    under `lockall` (C0 design, `event_object_movement.c:5049–5061`).
    `step_end` re-freezes it.
- **Text.** `ViridianCity_Text_ShowYouHowToCatchMons`
  (`data/maps/ViridianCity/text.inc:44–59`) has this control structure only:
  - seven pages, separated by six paragraph-clears (0xFB);
  - in-page newlines (0xFE);
  - **one scroll prompt** (0xFA, `\l`), which C0 lacked;
  - end (0xFF);
  - no placeholders (0xFD) and no extended controls (0xFC).

  Its bytes are not copied. Scroll waits for NEW A/B with the down arrow
  (`src/text.c:800–803,872–880`). It then scrolls the window by one line
  height, at the text-speed rate (`:881–901`, speeds `:36–38`), before the
  next character. Paragraph-clear follows C0 (`:863–870`). As in C0, the
  last page then goes to the default msgbox's wait-for-A/B, and only after
  that to `closemessage` (`src/scrcmd.c:1307–1311`).
- **Quest Log pair.** In live (non-playback) field play, `GetQuestLogState`
  is not the playback value 2. Playback is an excluded context (P5-05), so
  the goto falls through. `QuestLog_CutRecording` affects only Quest Log
  recording, which the reconstruction does not have. Both are validated byte
  for byte and treated as **no-ops in the reconstruction**, with no claim of
  Quest Log emulation.
- **Priority.**
  - Same as C0: trainer sightline once, then the on-frame table check, then
    coordinates.
  - Viridian has no trainer-type objects (`map.json` object_events, all
    `TRAINER_TYPE_NONE`), but the single trainer call is kept for parity with
    C0.
  - The map-script table holds only ON_TRANSITION (`scripts.inc:1–3`).

## Admission and dispatch

The dispatch location is `main.lua:playerMovementTask`, immediately after the
existing `tryViridianRoadblockAt` returns `not_selected` (`main.lua:1084–1085`)
and before the EarlyStory, connection, warp, trainer and wild fall-through
(`:1089–1093`). C0 is scene 0 and C2/C3 are scene 1, so the predicates are
disjoint. C0's code and order stay untouched.

The new `world.tryViridianTutorialTriggerAt(step)` returns the same three
states as C0: `not_selected`, `owned` or `refused`.

`ViridianTutorialTrigger.classify(context)` uses the same inputs as C0's
(`src/core/ViridianRoadblock.lua:66–97`):

- Only map 769 with (x,y) equal to (20,8) or (22,8) can be selected.
  Anything else returns `not_selected`.
- Scene: the raw saved entry must be an integer from 0 to 65535, otherwise
  `refused invalid_scene` (missing storage is never 0). A value other than 1
  returns `not_selected`.
- The step must be a normal, completed, nonmoving step whose
  `stepGeneration` equals the current generation. Otherwise
  `refused unqualified_step`.
- The event must be exactly one decoded coordinate event at that (x,y),
  with trigger 0x4051 and index/value 1, and its key must be 2 for (20,8)
  or 3 for (22,8). A missing, mismatched or duplicate event is refused
  (`invalid_c2c3` / `conflicting_c2c3`).
- **Elevation (D2)**: follow the C0 rule (`ViridianRoadblock.lua:93–95`;
  `src/field_control_avatar.c:1045–1063`). Unknown player elevation is
  `refused unknown_elevation`. A nonzero event elevation must equal the
  effective player elevation, otherwise `not_selected`. Event elevation 0
  is a wildcard for any *known* player elevation. Never use a literal 3
  (P5-05 report :155). The ROM fixture asserts that the decoded value is 3;
  synthetic tests cover the wildcard.
- The man (object local 4) must be present and stationary at (21,8), with
  the scene-1 projection (`src/core/ViridianOldManProjection.lua:46–47`).
  Otherwise `refused missing_tutorial_man`.

After a successful classify, the host does four things in order:

1. It calls `tryTrainerSightlineAt` once. If that wins, the step is owned.
2. It checks for any other owner. An active C0 owner, dialogue, Mart, Oak,
   trainer, battle or menu means `refused conflicting_owner`.
3. It validates the descriptor (next section).
4. It validates the text speed, as C0 does
   (`src/new_menu_helpers.c:27–32`). An unsupported value is refused.

## Descriptor (C2/C3-local, fixed layout)

The descriptor starts from the selected `scriptPtr`, with every read
range-checked:

1. It verifies `lockall`; `textcolor 0`; `applymovement 4,ptrA`;
   `waitmovement 0`; `applymovement 255,ptrB`; `waitmovement 0`;
   `call ptrT`.
2. At `ptrA` and `ptrB` it verifies one action plus 0xFE. The expected
   (man, player) actions are (0x2F, 0x30) for C2 and (0x30, 0x2F) for C3.
3. At `ptrT` it verifies the following, then **stops**:
   - `loadword 0, textPtr` + `callstd 4`;
   - `closemessage`;
   - `special GetQuestLogState` + `compare VAR_RESULT,2` + `goto_if_eq ptr`;
   - `special 0x188`;
   - `special 0x9D`.

   Every byte from `waitstate` on belongs to the dependency and is not
   validated as behavior.
4. It checks that both triggers' `ptrT` values are equal (the shared
   routine).

Text is checked with a bounded scan. Only plain characters plus 0xFE, 0xFB,
0xFA and 0xFF are accepted. Anything else, a missing terminator or a
malformed pointer is a refusal. It is split into pages on 0xFB and into
scroll segments on 0xFA. This happens *before* `Charmap.tokenize`, which
merges these codes (`import/Charmap.lua:274–278,428`, per C0). There is no
generic ScriptBytecode or Charmap change, and no reuse of C0 internals that
would need C0 edits. The three text-speed delays are restated in the new
module, with the source citation.

## States and owners

```
IDLE → TURN_MAN → WAIT_MAN → TURN_PLAYER → WAIT_PLAYER → PRINT
     → (WAIT_PAGE | WAIT_SCROLL → SCROLL)* → WAIT_FINAL → CLOSE_PENDING
     → QUESTLOG_NOOP → REFUSED_AT_BATTLE
```

- **Turns.**
  - `TURN_MAN` sets the man's `facingDirection` (C2 west, C3 east).
  - `WAIT_MAN` lasts exactly 4 fixed ticks. The next state begins on a
    later tick (the native wait, per C0).
  - The player's turn works the same way (C2 east, C3 west), using
    `playerMovement.facingDirection` only.
  - There is no tile change, no collision call and no completed-step
    dispatch.
  - Effective elevation is unchanged: the player stays on the same tile,
    and the source sampling at `event_object_movement.c:8400–8411` reads
    the same tile.
  - The walk-in-place animation frames are a presentation limit, with no
    parity claim.
- **Text.** The page printer shows only the current window. NEW A/B
  latching, reveal speed-up and the same-press isolation all follow C0
  exactly.
  - At 0xFA, the printer waits for NEW A/B, then drops the top visible line.
    The scroll is one step in the view, with the cache reset. The source
    pixel scroll rate is a presentation limit, and it adds no extra
    acknowledgment.
  - At 0xFB, the printer clears the window.
  - After the last page comes the final NEW A/B wait, then close on a later
    tick.
  - The C0 blue-foreground token is reused for textcolor 0. The male glyph
    limitation is inherited.
- **Quest Log pair.** `QUESTLOG_NOOP` runs one tick with no effect, then
  moves to the refusal.
- **`REFUSED_AT_BATTLE` (terminal until teardown).** In this state:
  - the message stays closed;
  - the lock is held, and all ordinary player input, NPC ticks, interaction
    and menus stay suppressed;
  - no `release` runs;
  - the scene stays 1, and no item is given;
  - no var, flag, bag, party or RNG write happens;
  - one diagnostic `addLine("Viridian tutorial refused: battle_dependency_unavailable")`
    is shown.

  The north tiles (20,7)/(22,7) are open (discovery decode). Releasing the
  player would therefore let them pass, so the refusal keeps the lock.
  **This makes northbound traversal blocked, not invalid.** That is
  deliberate reconstruction behavior until the battle lane supplies an
  accepted entry and return contract. It is not retail behavior.
- **Earlier refusals** (malformed input, unknown elevation, conflicting
  owner, unsupported speed) use the C0 pattern: a module-owned refused state
  that suppresses player actions until teardown.
- **Input.** Same as C0:
  - The tick-start ownership capture also covers this owner.
  - NEW A/B are read after `InputState.update`.
  - No A/B/START/SELECT/direction leaks into interaction, menus, battle or
    movement.
  - The man's `LOOK_AROUND` tick is suppressed while this owner is active.
- **C0 mutual exclusion.** `world.roadblockHasOtherOwner` (`main.lua:825–831`)
  also lists the tutorial owner. The new module's own conflict check lists
  C0's owner. Every C0 guard site in main also tests this owner:
  - tick guards `:1074,1127`;
  - frame ownership `:4763–4782,4995`;
  - render selection `:3393–3410`;
  - message routing `:5311`;
  - input routing `:5436`.
- **Teardown.** `loadMap`, including a same-ID reload, cancels the owner
  before map data is replaced. A generation, position, man-object or owner
  mismatch during the scene cancels the work, invalidates elevation and
  exposes a refusal. A later qualified step onto C2/C3 retriggers the scene,
  because scene 1 is unchanged and there is no one-shot flag.

## One implementation proposal — exactly seven paths

The proposed task is `P5-07-VIRIDIAN-TUTORIAL-TRIGGER-IMPLEMENTATION`. It is
not dispatched here.

1. `src/core/ViridianTutorialTrigger.lua` (new: classify, descriptor, turns,
   page/scroll printer, refusal)
2. `main.lua` (dispatch after C0, owner guards, render selection, replay branch)
3. `tests/phase5_viridian_tutorial_trigger_test.lua` (new, synthetic)
4. `tests/phase5_viridian_tutorial_trigger_integration_test.lua` (new, actual main paths)
5. `tests/phase5_viridian_tutorial_trigger_rom_test.lua` (new, opt-in fixture)
6. `scripts/runtime_viridian_tutorial_trigger_replay.sh` (new guarded wrapper)
7. `work/tasks/phase5-viridian-tutorial-trigger-implementation.md` (contract and evidence)

Only facing fields are assigned, so there is no change to `PlayerMovement`,
`ObjectEventState`, `ViridianRoadblock`, the projection, the decoder,
Charmap, the renderer or any battle file. The existing `world.*` helper
pattern is kept (main's 200-local ceiling).

Literal tests:

- **Admission:**
  - map, position, scene 0/1/2, missing scene storage;
  - C2/C3 identity, including a duplicate event;
  - event elevation 3 against player elevation 3, 4, known 0 and unknown;
  - the wildcard with a known elevation only;
  - an unqualified or moving step, and a stale generation;
  - a missing or moving man.
- **Priority:** C0 at scene 0 is unchanged and is not called twice. The
  trainer sightline is called once.
- **Descriptor:** the exact byte layout; truncated and malformed pointers;
  wrong actions for each side; mismatched `ptrT`; the special IDs recomputed
  from `specials.inc`; and the text control filter (0xFA accepted, 0xFC and
  0xFD refused).
- **Turns:** both directions for both sides, exactly 4 ticks each, man
  before player, no tile change and no collision call.
- **Text:** seven pages and the scroll; NEW A/B against held buttons;
  same-press isolation across a page, the scroll and the final wait; and
  close before the Quest Log no-op.
- **Refusal:** terminal at the battle special; the lock is held; a held UP
  (and START, A, B) for N ticks produces no movement and no menu; scene 1,
  vars, flags, bag and party are byte-identical; no RNG draw; no `release`.
- **Lifecycle:** teardown on reload and retrigger afterwards; C0
  interaction under conflicting owners.
- **Mutation witnesses:** releasing the player at refusal, writing scene 2,
  and skipping the trigger. Each must fail a test.

## Evidence and guarded-route proposal

- **Baseline and final:** `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY
  bash scripts/test_all.sh`, `lua5.1 scripts/check_repository.lua`, and
  both whitespace checks.
- **Focused:**

  ```sh
  lua5.1 tests/phase5_viridian_tutorial_trigger_test.lua
  lua5.1 tests/phase5_viridian_tutorial_trigger_integration_test.lua
  lua5.1 tests/phase5_viridian_roadblock_test.lua
  lua5.1 tests/phase5_viridian_roadblock_integration_test.lua
  lua5.1 tests/phase5_viridian_old_man_projection_test.lua
  lua5.1 tests/phase5_player_elevation_input_test.lua
  lua5.1 tests/phase5_viridian_tutorial_trigger_rom_test.lua
  ```

- **ROM fixture:** verify SHA-1
  `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc` through RomImporter, then
  resolve the C2/C3 events, both scripts, the shared routine, the movements
  and the text structure dynamically. It must not print or commit dialogue.
  Without a ROM it skips. Acceptance needs a **non-skipped** guarded receipt.
- **Runtime case:** `viridian_tutorial_trigger`, run by
  `bash scripts/runtime_viridian_tutorial_trigger_replay.sh`. Required
  marker: `RUNTIME_REPLAY viridian_tutorial_trigger PASS`, with exit 0 and
  a finite timeout.
  - The fixture explicitly builds a session on verified map 769 with scene 1
    and the man projected. It starts at (20,9), then separately at (22,9).
    A real ordinary UP step admits the trigger.
  - The replay observes the turns, all pages with real NEW presses, the
    close, then `REFUSED_AT_BATTLE`. Held input must not leak, and the
    persistent state must be unchanged.
  - This is **fixture-backed field-side execution**. It is not a fresh-save
    walk and not tutorial completion.
- **Route:** no existing route admits this package. C0's route
  (`phase5-viridian-roadblock*`) and the shared smoke wrapper must not be
  reused.
  - New selector: `phase5-viridian-tutorial-trigger*.patch|*.probe` →
    `phase5-viridian-tutorial-trigger`.
  - Its validation and staging allowlists both equal the seven paths above.
    It runs the focused commands, the no-ROM suite, the SHA-ROM suite and
    the wrapper.
  - The configuration boundary is
    `.github/workflows/local-worker-bridge.yml` plus
    `work/coordination/LOCAL_RUNNER_BRIDGE.md`, under its own task. A new
    probe and request authority is still required. Consumed allowances stay
    consumed.
- **Sequencing:** behavior acceptance of this slice moves traversal from
  invalid to blocked. It does not close the gate. Closing the gate needs
  the battle-lane dependency plus a later reviewed slice for the
  `waitstate` return, scene 2, Teachy TV and `release`.

## UNKNOWNs and limits

- **Post-battle state** (party, bag, vars, flags, RNG): outside-dependency
  UNKNOWN. `ec2d8e9` is pending review.
- **The `lock`/`faceplayer` target after `waitstate`:** still UNKNOWN (per
  the discovery). It is not reached by this slice.
- **Frame timing:** the exact frame of msgbox start relative to the second
  `waitmovement`, and the scroll pixel timing, are not cycle-exact. Only the
  order and the 4-tick turns are claimed.
- **Presentation:** the walk-in-place animation, male glyphs, the down
  arrow and audio are inherited presentation limits.
- **Talking to the man at scene 1** (`scripts.inc:102,123–125`) is outside
  this slice. Talk dispatch keeps its existing behavior.
- **Operator note:** shipping the refusal leaves a visible hard block at
  (20/22,8) until the battle lane lands. The orchestrator or operator may
  choose to sequence implementation acceptance next to the dependency.

## Actual checks (executed 2026-11-18; no ROM, LÖVE, runner or tests)

- In the source checkout, `git rev-parse HEAD` equals the pin, and the
  status is clean.
- Special IDs: positional count over `def_special` in `data/specials.inc`
  (python3 -I), giving 0x9D and 0x188. No conditional blocks were found.
- Text: the control structure was extracted from `text.inc:44–59` with
  quoted content redacted. Result: 6×`\p`, 1×`\l`, `\n`, `$`, and no `{…}`
  placeholders.
- Numbered reads:
  - `event_object_movement.c:6133–6151,6235–6255`;
  - `include/constants/event_object_movement.h:133–137`;
  - `asm/macros/event.inc` at the lines cited above;
  - `src/text.c:36–38,550,795–805,855–905`;
  - `src/scrcmd.c:1307–1311`;
  - runtime `main.lua:1079–1093,3388–3415`;
  - `ViridianRoadblock.lua:66–97`;
  - `ViridianOldManProjection.lua:13–54`;
  - `ObjectEventState.lua:205–222`.
- The repository checker and `git diff --check origin/main` both pass after
  staging. Receipts are in the PR.
