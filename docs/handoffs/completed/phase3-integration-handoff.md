# FireRed ReComp — Phase 3 Vertical-Slice Integration Task (main.lua owner — run ALONE, not in parallel with any other main.lua work)

## Context you need

This project (`/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp/`)
is a **recomp** of Pokémon FireRed: real decompiled C source
(`/home/mellow/Documents/Projects/Pokemon ReComp/Disassembled_Games/Classic/pokefirered-master/`)
ported by hand into Lua/LÖVE2D, pulling every asset directly out of a
verified real ROM at load time.

Verified ROM:
`/home/mellow/Documents/Projects/Pokemon ReComp/FireRed/pokefirered-master/pokefirered.gba`
(SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`).

Checklist: `/home/mellow/Documents/Projects/Pokemon ReComp/docs/handoffs/firered-recomp-checklist.md`.

## Why this task is different from every other handoff

Every previous handoff explicitly avoided `main.lua` to stay parallel-safe.
The result: a large amount of real, verified, tested logic now exists —
object-event NPCs, wild encounter selection, the Oak intro scene, the
script interpreter — and **none of it is connected to the live game loop**.
`main.lua`'s W (walk) view still only moves the player around empty maps.
This task is the integration pass. **Because it's the one task allowed to
touch `main.lua`, do not run this concurrently with any other handoff that
also claims `main.lua`.** If you see `git status` showing another agent's
uncommitted `main.lua` changes when you start, stop and report back rather
than merging over them.

## What's already built (read each module's header comment, don't re-derive)

- `src/core/ObjectEventState.lua` — per-map NPC list + movement ticking
  (built from `MapEvents.resolve(...).objectEvents`).
- `import/ObjectEventGraphicsInfo.lua` — `graphicsId -> real pixels` via
  `.decodeStandingImage()`.
- `src/core/ObjectEventInteraction.lua` — `findInteractionTarget(player,
  npcList)` trigger detection.
- `src/core/WildEncounterSelector.lua` — real slot/level/trigger-dice
  rolls, needs a real `Rng` instance (`Rng.new(seed)` for the main stream,
  `Rng.new(seed, 12345)` for the independent wild-encounter-rate stream —
  see `WildEncounterSelector.newTriggerRng`).
- `import/OakSpeechScene.lua` — `.composite(data, addrs)` returns a
  240x160 image (Oak sprite + background + dialogue frame). No per-
  character text reveal wired in yet (see its own file for what's left).
- `src/core/ScriptInterpreter.lua` — steppable VM; needs a caller-supplied
  "world" callback table (check its constructor/`:step()` signature for
  exactly what hooks it expects — message display, flag storage, warp,
  etc.).
- Existing `main.lua` state you'll be extending: `walkMapBlockData`/
  `walkMapWarps`/`walkMapPrimaryAttrsPtr` (map-load state), `playerMovement`
  (the player actor), `getMetatileBehaviorAt`/`isTallGrassTile` (already
  wired), `loadMap()` (reusable map loader), `InputState` (real input
  polling), `TextWindow`/`TextRenderer`/`TextPrinterState` (dialogue
  rendering primitives).

## The task, in priority order (do as much as you can cleanly finish; stop and document rather than rushing a later item)

### 1. NPCs: render + tick + interact (highest value, most mechanical)

1. In `loadMap()` (or wherever per-map state resets), build a fresh
   `ObjectEventState` list for the newly-loaded map from its
   `MapEvents.resolve(...).objectEvents`.
2. Each frame (same fixed-tick loop `playerMovement`/`InputState` already
   use), call `:tick()` on every NPC.
3. In the W view's draw call, decode each NPC's standing image via
   `ObjectEventGraphicsInfo.decodeStandingImage()` (cache per graphicsId
   the same way the player sprite/flame particles already cache decoded
   images — don't redecode every frame) and draw it through the existing
   camera-crop compositor, at the NPC's current tile position.
4. On A button press (`InputState`, same button that already confirms
   Yes/No menus), call `ObjectEventInteraction.findInteractionTarget` —
   if it finds an NPC, that's the interaction hook point for step 2 below.

### 2. Minimal script interpreter world bridge (message boxes only — don't try to wire every opcode's real-world effect)

The interpreter needs a "world" implementation to actually do anything.
Scope this narrowly: implement enough of the world callback interface
that a `message`/`waitmessage`/`waitbuttonpress`/`lock`/`release`/
`faceplayer` sequence (exactly what the Town Sign script and most NPC
dialogue uses) renders real dialogue through `TextWindow`/`TextRenderer`/
`TextPrinterState` and advances on a real A-button press — mirroring how
`TextPrinterState`'s pause/reveal state machine already works, since the
interpreter needs the same kind of "pause execution until an external
event" state.
- Wire NPC interaction (from step 1.4) to: find the NPC's `scriptPtr` →
  decode via `ScriptBytecode` → run through `ScriptInterpreter` with this
  message-box world implementation → `faceplayer` turns the NPC to face
  the player (use `ObjectEventState`'s facing field).
- Other opcodes (warp, flag/var, trainerbattle, etc.) are explicitly OUT
  OF SCOPE for this pass — if a script hits one, either skip past it with
  a stubbed handler that returns immediately (documented), or let the
  interpreter's existing loud-`error()`-on-unimplemented behavior surface
  it and just don't run that particular script live yet. Your call which
  is less disruptive; document whichever you pick.
- Verify against the real thing this project already ground-truthed: the
  Pallet Town Town Sign script and/or interacting with the real Sign
  Lady/Prof Oak NPCs.

### 3. Wild encounter trigger (small, mechanical)

`main.lua`'s `isTallGrassTile` check currently only logs a status line.
Replace/extend it: on entering tall grass, roll the real trigger dice
(`WildEncounterSelector`'s trigger-rate roll, needs the previous-tile
metatile behavior — track it, same pattern the real
`DoGlobalWildEncounterDiceRoll` needs "did behavior change since last
step") using a persistent trigger-RNG instance
(`WildEncounterSelector.newTriggerRng`, seeded once at boot/map-load —
your call, document which). On a successful roll, resolve the real
`WildEncounters.lua` data for the current map and roll a
slot+level via `WildEncounterSelector`. Since there's no battle engine
yet (Phase 4), the real outcome here is just: **display what was rolled**
(e.g. a status line "Wild PIDGEY (Lv 3) appeared!" or reuse the dialogue
box) — do NOT try to start a battle, that's explicitly out of scope
until Phase 4 exists.

### 4. Oak intro scene as a new view (smallest, most isolated)

Add a new view mode (pick an unused key, following the existing pattern
of T=title, W=walk, F=font, etc. — check `main.lua`'s current key list
first) that draws `OakSpeechScene.composite(data, addrs)`. Static
composite is fine — the scene module's own header documents what
animation/sequencing is still open; you don't need to add any of that
here, just get the static composite showing up as a real view.

### Explicitly out of scope for this whole task

- Actual battles (Phase 4 doesn't exist yet).
- New-game naming/gender flow (needs a keyboard/character-select UI, a
  separate task).
- Real save file I/O (a separate handoff, `save-file-io-handoff.md`, may
  be running in parallel right now — it does NOT touch `main.lua`, so no
  conflict, but don't duplicate its scope).
- Any script opcode beyond the message-box family (see step 2).
- Elevation/movement-range collision refinements.

## Conventions to follow

- Cache decoded images (sprites, scene composites) — don't redecode every
  frame, this project already established that pattern for the player
  sprite and flame particles.
- No `bit` library / Lua 5.3 bitwise operators.
- Tests: this task is necessarily more integration-shaped than most —
  still add real unit/integration tests where the logic is testable in
  isolation (e.g. "does the trigger-rate roll get invoked on grass entry"
  can be tested without love2d if you structure it as a pure function
  main.lua calls). A live screenshot (`POKEPORT_SCREENSHOT=1` or similar,
  check existing env-var conventions in `main.lua`) for at least the NPC
  rendering and Oak intro view is expected, matching this project's
  established "visually confirmed" standard for anything rendering.
- Run the full suite before finishing:
  ```
  cd "/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp"
  ROMPATH="/home/mellow/Documents/Projects/Pokemon ReComp/FireRed/pokefirered-master/pokefirered.gba"
  for f in tests/*.lua; do POKEPORT_ROM="$ROMPATH" lua5.1 "$f" || echo "FAILED: $f"; done
  lua5.1 -e "assert(loadfile('main.lua'))"
  ```
- **Don't commit anything** — leave changes in the working tree.
- Update the checklist for exactly what you finished — this task likely
  touches several checklist lines at once (NPC line, wild-encounter line,
  Oak-intro sub-line, script-interpreter line); update each precisely.

## Deliverable

Which of the 4 priority items you completed (all 4 is the goal, but
partial is fine if honestly documented), what real behavior you verified
live (describe screenshots/test output), what's explicitly deferred and
why, and the file list touched (should be almost entirely `main.lua` plus
maybe a small new pure-Lua helper module if the trigger-rate/interaction
logic is cleaner extracted out for testability).
