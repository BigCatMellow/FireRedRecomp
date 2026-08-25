# FireRed ReComp — Object-Event (NPC) Spawn/Facing/Movement/Interaction Task (independent, parallel-safe)

## Context you need

This project (`/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp/`)
is a **recomp** of Pokémon FireRed: real decompiled C source
(`/home/mellow/Documents/Projects/Pokemon ReComp/Disassembled_Games/Classic/pokefirered-master/`)
ported by hand into Lua/LÖVE2D, pulling every asset directly out of a
verified real ROM at load time. Nothing is placeholder — every module is
verified against real ROM bytes, documented in its header comment.

Verified ROM:
`/home/mellow/Documents/Projects/Pokemon ReComp/FireRed/pokefirered-master/pokefirered.gba`
(SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`). A different-revision copy
also exists in the same folder — always use this exact one. The built ELF
(for finding real symbol addresses) is at
`.../pokefirered-master/pokefirered.elf`; the toolchain is at
`/home/mellow/toolchains/arm-gnu-toolchain-13.2.Rel1-x86_64-arm-none-eabi/bin`
(`arm-none-eabi-nm`/`objdump`).

Checklist: `/home/mellow/Documents/Projects/Pokemon ReComp/docs/handoffs/firered-recomp-checklist.md`
(plain file, not in the git repo — edit directly). This is Phase 3's
`- [ ] Object-event spawn/facing/movement/interaction/dialogue` line,
fully unchecked as of this writing.

## What NOT to touch

Do not edit `main.lua`. Build in new/existing `import/`, `src/core/`,
and `tests/` files instead. Leave a clear written note in your summary
about exactly what a `main.lua` wiring pass would need to do — someone
else (or a later solo pass) will do that integration once this and any
other in-flight Phase 3 handoffs have landed, since multiple handoffs
touching `main.lua` concurrently is how merge conflicts happen.

## Background: what's already built

- `import/MapEvents.lua` already decodes every map's real object events
  (`ObjectEventTemplate`, both union variants including the "clone"
  variant) — `localId`, `graphicsId`, starting `x`/`y`, `movementType`,
  `trainerType`, and a `scriptPtr`. This is Phase 1 work, already done
  and verified (Pallet Town + Celadon City clone data). You do NOT need
  to redecode this — call `MapEvents.resolve(data, header.eventsPtr)`
  and use its `.objects` array.
- `import/ObjectSprite.lua` + `import/OamShapeSize.lua` +
  `import/SubspriteTable.lua` decode real overworld sprite graphics
  (uncompressed pics, 1D OBJ mapping, OAM shape/size, multi-OAM
  compositing). This project has NOT yet resolved a `graphicsId` (from
  an object event template) to its real sprite/palette ROM pointers —
  that lookup table (`gObjectEventGraphicsInfo[graphicsId]`, real struct
  in `src/data/object_events/object_event_graphics_info.h`) is the
  missing link between "this NPC has graphicsId 5" and "here are its
  actual pixels."
- `src/core/PlayerMovement.lua` has the real grid-walk timing/animation
  state machine for ONE actor (the player). NPCs need their own
  movement, driven by their real `movementType` (`include/constants/
  event_object_movement.h` / `src/field_specials.c`'s movement-type
  tables) — most NPCs are stationary or walk a small fixed pattern
  (`MOVEMENT_TYPE_FACE_DOWN`, `MOVEMENT_TYPE_WANDER_AROUND`, etc.), not
  free-roaming like the player.
- `src/core/ScriptInterpreter.lua` can already execute a script given
  its bytecode — an NPC's `scriptPtr` (from `MapEvents.lua`) is exactly
  the kind of pointer it consumes. `faceplayer` and `lock`/`release`
  opcodes are already implemented.
- `src/core/TaskScheduler.lua` exists if NPC movement/animation needs
  per-tick driving (it's the same scheduler font-reveal/flame particles
  already use).

## The task

1. **Real graphics lookup**: decode `gObjectEventGraphicsInfo` (an array
   indexed by `graphicsId`) — read the real struct in
   `include/global.fieldmap.h`/`object_event.h` (search for
   `struct ObjectEventGraphicsInfo`), confirm field layout/size against
   real ROM bytes the way every other struct in this project has been
   (don't assume padding — this project has hit real agbcc padding
   surprises more than once). Fields you need at minimum: the pic
   table/size pointer (feeds into `ObjectSprite`/`OamShapeSize`), the
   palette pointer or palette tag, and `width`/`height` (already known
   to matter from the subsprite-table work — objects over 64x64 need
   `SubspriteTable`). New module: `import/ObjectEventGraphicsInfo.lua`.
2. **Wire it to real sprite decode**: given a `graphicsId`, resolve and
   decode the NPC's actual standing-frame image using the existing
   `ObjectSprite`/`OamShapeSize`/`SubspriteTable` pipeline — no new
   graphics-decode primitives should be needed, this step is about
   connecting `graphicsId -> real pixels`.
3. **Facing direction**: real object events have a default facing baked
   into their `movementType`'s initial state (check
   `src/event_object_movement.c`'s movement-type init functions) — most
   sprites have 4 real facing-direction frame sets (up/down/left/right,
   sometimes with left/right sharing frames via horizontal flip — check
   the real `gObjectEventGraphicsInfo` framePicTable size vs. 4 to see
   if this game does the flip trick or has distinct L/R frames).
4. **`src/core/ObjectEventState.lua`**: a per-map runtime NPC list built
   from `MapEvents.resolve(...).objects` — position, facing direction,
   current movement-type, and a reference to its decoded sprite. Should
   be independently testable (pure Lua, no love2d), same pattern as
   `PlayerMovement.lua`/`MenuCursor.lua`.
5. **Basic movement types**: implement the real behavior for at least
   `MOVEMENT_TYPE_FACE_DOWN/UP/LEFT/RIGHT` (stationary, just a facing)
   and `MOVEMENT_TYPE_WANDER_AROUND` (real random-walk within a small
   radius, driven by `Rng.lua` — check `src/event_object_movement.c`'s
   `MovementType_WanderAround` for the real step-selection logic, don't
   invent your own random-walk). Other movement types (patrol routes,
   look-around, etc.) are good stretch goals but not required.
6. **Interaction**: real NPC interaction is "player faces an object
   event and presses A" → `faceplayer` (NPC turns to face the player) →
   run the NPC's `scriptPtr` through `ScriptInterpreter`. Build a
   testable trigger function: given the player's position+facing and
   the object-event list, return the NPC (if any) the player is
   currently facing and adjacent to. Wiring the actual A-button press
   and interpreter execution into `main.lua`'s live loop is explicitly
   the deferred integration step (see "What NOT to touch") — but the
   trigger-detection logic itself should be built and tested here.
7. **Trainer sight/battle-trigger detection is explicitly OUT of scope**
   for this task (that's `trainerbattle`'s territory, already partially
   modeled in `ScriptInterpreter.lua`, and real sight-range detection is
   a distinct, more involved system — Phase 7 lists "trainer sight/
   approach" separately). Don't try to build it here.

### Explicitly out of scope

- No `main.lua` wiring (see above).
- No trainer sight-range/approach detection (Phase 7 scope).
- No movement types beyond the ones listed in step 5 unless they're
  quick wins — note what's covered vs. not in your summary, per the
  project's "loudly fail on unimplemented, never silently no-op"
  convention (see `ScriptInterpreter.lua`'s `error()`-on-unknown-opcode
  pattern for the house style).
- No dialogue-box UI changes — `TextWindow`/`TextRenderer`/
  `TextPrinterState` already exist and are out of scope to modify here;
  this task's job is "can we find the right script and hand it to the
  interpreter," not "does dialogue render prettier."

## Conventions to follow

- Every module's header comment cites the real struct/function/source
  file and states exactly what was verified against real ROM data.
- `RomAddresses.lua`: real addresses via `arm-none-eabi-nm
  pokefirered.elf | grep <name>` for static/local symbols not in the
  linker `.map`. Addresses are stored pre-subtracted
  (`0x08xxxxxx - 0x08000000`); raw pointers decoded out of ROM bytes
  themselves stay as full addresses — don't mix these two conventions
  up, it's a recurring bug class in this project's history (bit me
  twice already per the project's own memory notes on `WildEncounters`
  and `TitleScreen`).
- No `bit` library / Lua 5.3 bitwise operators anywhere (LuaJIT + plain
  Lua 5.1 compatibility) — pure arithmetic bit extraction.
- Tests: plain-Lua unit tests always run; ROM-integration tests check
  `POKEPORT_ROM` and skip cleanly if unset. Run the full suite before
  finishing:
  ```
  cd "/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp"
  ROMPATH="/home/mellow/Documents/Projects/Pokemon ReComp/FireRed/pokefirered-master/pokefirered.gba"
  for f in tests/*.lua; do POKEPORT_ROM="$ROMPATH" lua5.1 "$f" || echo "FAILED: $f"; done
  lua5.1 -e "assert(loadfile('main.lua'))"
  ```
- **Don't commit anything** — leave changes in the working tree; the
  project owner reviews and commits in logical chunks.
- Update the checklist (Phase 3 section) for what you actually
  finished/verified, in the existing entry style — cite real struct/
  function names, what was verified against real ROM bytes vs.
  documented as a scoped simplification.

## Deliverable

A summary of what real structs/functions you read, which real NPC(s)
you verified against (name the map + object event), what movement
types are implemented vs. stubbed, exactly what a `main.lua` integration
pass would need to do, and the file list touched.
