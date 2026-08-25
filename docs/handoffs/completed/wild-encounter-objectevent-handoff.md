# FireRed ReComp — Wild Encounter Selection + Object-Event Sprites Task (independent, parallel-safe)

## Context you need

This project (`/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp/`)
is a **recomp** of Pokémon FireRed: real decompiled C source
(`/home/mellow/Documents/Projects/Pokemon ReComp/Disassembled_Games/Classic/pokefirered-master/`)
ported by hand into Lua/LÖVE2D, pulling every asset directly out of a
verified real ROM at load time. Nothing is placeholder — every module is
verified against real ROM bytes, documented in its header comment.

Verified ROM:
`/home/mellow/Documents/Projects/Pokemon ReComp/FireRed/pokefirered-master/pokefirered.gba`
(SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`). The built ELF (for
real symbol addresses) is at `.../pokefirered-master/pokefirered.elf`;
toolchain at
`/home/mellow/toolchains/arm-gnu-toolchain-13.2.Rel1-x86_64-arm-none-eabi/bin`
(`arm-none-eabi-nm`/`objdump`).

Checklist: `/home/mellow/Documents/Projects/Pokemon ReComp/docs/handoffs/firered-recomp-checklist.md`
(plain file, not in the git repo — edit directly). This covers two
related Phase 3 lines: "Object-event spawn/facing/movement/interaction/
dialogue" and "Wild encounter selection + minimal single battle" (this
task is the *selection* half — species/level rolling — not the battle
engine itself, which is Phase 4 scope).

This is genuinely two related sub-tasks. If you only have time for one,
prioritize wild encounter selection (smaller, more self-contained).

## What NOT to touch

Someone else is actively editing `main.lua` and
`src/core/PlayerMovement.lua` concurrently. **Do not edit `main.lua`.**
Build in new files under `src/core/`, `import/`, and `tests/`. It's fine
to note in your summary what a `main.lua` integration would look like
(e.g. "call `WildEncounterSelector.roll(...)` when the player steps onto
a real tall-grass metatile") without actually wiring it in.

## Part 1: Wild encounter species/level selection

### Background already built

- `import/WildEncounters.lua` (Phase 1) already decodes real
  `gWildMonHeaders`/`WildPokemonInfo`/`WildPokemon` — per-map encounter
  tables (species + level range per slot, real encounter rate), already
  verified against real Route 1 data.
- `src/core/Rng.lua` (this session) ports the real GBA LCG (`src/random.c`'s
  `ISO_RANDOMIZE1`) — verified against independently-computed ground
  truth. This is the real RNG FireRed's wild encounter roll uses.

### The task

1. **Find the real encounter-roll algorithm** in
   `src/wild_encounter.c` (real function likely named something like
   `ChooseWildMonIndex_Land`/`ChooseWildMonLevel`/`TryGenerateWildMon`
   — grep for the real names, don't guess) — the real logic for: (a)
   whether an encounter triggers at all this step (uses the real
   encounter rate + a probability table indexed by which "grass rustle"
   region or repel/etc. state — a real, documented formula, not a flat
   percentage), (b) which of the 12 real land-encounter slots gets
   picked (a real weighted-slot table, not uniform random — FireRed's
   real slot weights are documented in the decomp), (c) what level
   within that slot's real min/max range gets picked.
2. **`src/core/WildEncounterSelector.lua`**: given a real decoded
   `WildPokemonInfo` (from `WildEncounters.lua`) and an `Rng` instance,
   implement the real selection algorithm faithfully. Verify with a
   large-sample statistical test (e.g. roll 10,000 times against Route
   1's real real data and confirm the slot-selection frequencies
   roughly match the real weight table, and levels stay within each
   slot's real declared range) — this kind of statistical verification
   is a legitimate substitute for exact-value verification when the
   output is inherently randomized, similar in spirit to how this
   project's `TitleScreenFlameSpawner.lua` verified exact RNG-seeded
   values, but here you're verifying distribution shape instead since
   there's no fixed seed to reproduce a golden sequence against (unless
   you want to also pin one exact seeded sequence for a golden test,
   which is even better if practical).

## Part 2: Object-event (NPC) sprite decode + static placement

### Background already built

- `import/MapEvents.lua` (Phase 1) already decodes real object-event
  templates per map (position, graphics ID, facing direction, movement
  type, script pointer) — verified against real Pallet Town data.
- `import/ObjectSprite.lua` + `import/OamShapeSize.lua` +
  `import/SubspriteTable.lua` (this session, likely already
  landed by the time you start — check `git status`/`git log`) decode
  real overworld sprites generically, including multi-OAM objects.
- `include/graphics.h`/`src/data/object_events/object_event_graphics_info.h`
  (already referenced elsewhere in this project) maps a real graphics
  ID to its real pic/palette/OAM data.

### The task

1. **`src/core/ObjectEventRenderer.lua`** (or similar name): given a
   real map's decoded object-event templates (from `MapEvents.lua`) and
   the ROM data, resolve each template's `graphicsId` to its real
   sprite (reusing `ObjectSprite.lua`) and decode a static frame at the
   real facing direction (object events have per-direction frame
   indices — check the real `ObjectEventGraphicsInfo`/anim table
   structure for how facing maps to frame index, don't guess).
2. **Verify against a real map with real NPCs** — Pallet Town itself
   has few/no NPCs early on; check other maps (Viridian City, Route 1)
   via `MapEvents.lua` for ones with real object events present, and
   decode+verify at least one real NPC sprite renders as a recognizable
   character (by eye, or structurally: correct non-blank pixel data,
   correct real dimensions from its real OAM).
3. Note in your summary what static-placement rendering would look like
   if wired into a map view (position each decoded NPC sprite at its
   real map-tile coordinates) — you don't need to actually build that
   wiring since it likely touches `main.lua`.

### Explicitly out of scope (both parts)

- No real movement/AI for NPCs (wandering, facing changes) — static
  placement only for this task.
- No dialogue/interaction triggering — that's the script interpreter
  handoff's territory (a separate doc in this same folder,
  `script-interpreter-handoff.md`, if you want context on where this
  connects).
- No actual battle triggering from a wild encounter roll — selection
  only (which species/level), not starting a fight.

## Conventions to follow

- Every module's header comment cites the real function/struct/file and
  states exactly what was verified — see `import/WildEncounters.lua`
  (Phase 1, already in this style) or `import/OamShapeSize.lua` for
  examples to match.
- `RomAddresses.lua`: real addresses via `arm-none-eabi-nm
  pokefirered.elf | grep <name>`. Addresses stored pre-subtracted
  (`0x08xxxxxx - 0x08000000`); raw pointers decoded out of ROM bytes
  themselves stay as full addresses — don't mix these conventions up.
- Tests: plain-Lua unit tests always run; ROM-integration tests check
  `POKEPORT_ROM` and skip cleanly if unset. Run the full suite before
  finishing:
  ```
  cd "/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp"
  ROMPATH="/home/mellow/Documents/Projects/Pokemon ReComp/FireRed/pokefirered-master/pokefirered.gba"
  for f in tests/*.lua; do POKEPORT_ROM="$ROMPATH" lua5.1 "$f" || echo "FAILED: $f"; done
  ```
- No `bit` library / Lua 5.3 bitwise operators anywhere (LuaJIT + plain
  Lua 5.1 compatibility) — pure arithmetic bit extraction, see
  `import/Lz77.lua`'s header comment.
- **Don't commit anything** — leave changes in the working tree.
- Update the checklist for what you actually finished/verified, in the
  existing entry style.

## Deliverable

A summary of what real functions/tables you traced for each part, what
you built and verified (including the statistical verification approach
for encounter selection, and which real map/NPC you tested object-event
rendering against), what's explicitly out of scope, and the file list
touched. If you only completed one of the two parts, say so clearly.
