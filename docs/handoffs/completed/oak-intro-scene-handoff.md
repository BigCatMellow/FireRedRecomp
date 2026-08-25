# FireRed ReComp — Oak Intro Scene Task (independent, parallel-safe)

## Context you need

This project (`/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp/`)
is a **recomp** of Pokémon FireRed: real decompiled C source
(`/home/mellow/Documents/Projects/Pokemon ReComp/Disassembled_Games/Classic/pokefirered-master/`)
ported by hand into Lua/LÖVE2D, pulling every asset directly out of a
verified real ROM at load time. Nothing is placeholder — every module is
verified against real ROM bytes, documented in its header comment.

Verified ROM:
`/home/mellow/Documents/Projects/Pokemon ReComp/FireRed/pokefirered-master/pokefirered.gba`
(SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`).

Checklist: `/home/mellow/Documents/Projects/Pokemon ReComp/docs/handoffs/firered-recomp-checklist.md`
(plain file, not in the git repo — edit directly). Look under Phase 2's
"title screen, Oak intro, Pallet Town screenshot parity" exit-criterion
item, sub-line "Oak intro scene — **partial**". As of this writing, only
the opening narration text (`gOakSpeech_Text_WelcomeToTheWorld`) renders
through the existing font/window/text-printer pipeline; there's no Oak
sprite, no Nidoran release, no dedicated background layer, and no
gender/naming flow.

## What NOT to touch

Do not edit `main.lua`. Build in new/existing `import/`, `src/core/`,
and `tests/` files instead, and note in your summary exactly what a
`main.lua` wiring pass (a new view mode showing the scene) would need.

## Background: the real scene (`src/oak_speech.c`, ~2200 lines)

This is genuinely large in the real game — full scope is NOT the goal
here. The real scene, roughly: black screen → Oak's narration text →
Oak's sprite appears → a wild Pokémon (real: a Nidoran, sex depends on
which starter data table happens to be loaded at this point — check the
source, don't assume M/F) bursts out of grass and "attacks" → Oak saves
the player → more dialogue → player enters name → gender select → rival
naming → walk to the lab. **Pick a meaningfully-sized real slice, not
the whole thing** — see suggested scope below.

Already built and reusable as-is: `Font.lua`/`TextWindow.lua`/
`TextRenderer.lua`/`TextPrinterState.lua`/`Charmap.lua` (full text
pipeline), `PaletteFade.lua`/`PaletteBlend.lua` (fades), `ObjectSprite.lua`
+ `OamShapeSize.lua` + `SubspriteTable.lua` (sprite decode/compositing —
Oak's real sprite may need subsprites if it's a "trainer" pic rather
than an object-event pic; check which real pointer table it lives in
before assuming), `TaskScheduler.lua` (if the scene needs multi-tick
choreography), `AffineAnimator.lua` (only if something in this scene
actually uses affine transforms — check first, don't assume).

## The task: pick ONE of these two real slices (your call, note which)

### Option A — Oak sprite + background layer (visual-only slice)

1. Find Oak's real overworld/scene sprite pointer (search
   `src/data/object_events/object_event_graphics_info.h` for an
   Oak-related `graphicsId`, or check if the intro scene actually uses a
   distinct non-object-event sprite — read `oak_speech.c`'s real sprite
   setup calls to confirm which real pointer table applies; don't guess).
   Decode it through the existing `ObjectSprite` pipeline.
2. Find and decode the real intro-scene background layer(s) (grass/
   scenery behind Oak and the narration text — check `oak_speech.c` for
   the real BG tilemap/tileset symbols it loads). This is likely a
   fixed non-scrolling BG, not a full `MapCompositor` map — confirm from
   source before assuming which decode path applies.
3. Composite Oak + background + the already-working narration text into
   one scene, verified by eye via a live screenshot (same pattern as
   every other Phase 2 visual milestone — `POKEPORT_SCREENSHOT=1` or a
   dedicated env var for this scene).

### Option B — Nidoran encounter beat (animation/choreography slice)

1. Find the real Nidoran "burst out of grass" sprite/animation data
   (`oak_speech.c`'s real sprite callback for this beat) and decode it
   through `ObjectSprite`/`SpriteAnimator` (reuse, don't reinvent — this
   project already has a working frame-stepped sprite-animation system
   from the title-screen flames).
2. Port the real timing/choreography (when the Nidoran appears, how it
   moves, when it's replaced by the "Oak saves you" dialogue trigger) as
   a testable, pure-Lua state machine (same pattern as
   `TitleScreenFlameSpawner.lua`), not raw main.lua glue code.
3. Verify via unit tests pinning exact tick timing (ground-truth from
   the real source, the same way `TitleScreenFlameSpawner`'s RNG rolls
   were ground-truthed independently) plus a live-screenshot spot check
   if feasible.

### Explicitly out of scope (either option)

- Player naming (needs a keyboard/character-select UI, a much bigger
  separate task) and gender selection — stub these as "not yet
  reachable," don't fake a naming UI.
- Rival naming.
- Actually wiring this into a playable sequence in `main.lua` — leave a
  clear note of what that would require.
- The full ~2200-line `oak_speech.c` script logic — you're porting one
  visual/animation slice with real verified data, not writing a general
  cutscene scripting system (that's `ScriptInterpreter.lua`'s territory,
  already partially built elsewhere).

## Conventions to follow

- Every module's header comment cites the real struct/function/source
  file and states exactly what was verified against real ROM data —
  see `import/AffineAnim.lua` or `src/core/TitleScreenFlameSpawner.lua`
  for house style on ground-truthing real timing/sequence data.
- No `bit` library / Lua 5.3 bitwise operators (LuaJIT + plain Lua 5.1
  compatibility).
- Tests: plain-Lua unit tests always run; ROM-integration tests check
  `POKEPORT_ROM` and skip cleanly if unset. Run the full suite before
  finishing:
  ```
  cd "/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp"
  ROMPATH="/home/mellow/Documents/Projects/Pokemon ReComp/FireRed/pokefirered-master/pokefirered.gba"
  for f in tests/*.lua; do POKEPORT_ROM="$ROMPATH" lua5.1 "$f" || echo "FAILED: $f"; done
  lua5.1 -e "assert(loadfile('main.lua'))"
  ```
- **Don't commit anything** — leave changes in the working tree.
- Update the checklist's Oak-intro sub-line for what you actually
  finished/verified.

## Deliverable

Which option (A or B) you picked and why, what real source you read,
what was verified against real ROM bytes vs. hand-traced timing, a
live-screenshot description if you got one, what's explicitly left out,
and the file list touched.
