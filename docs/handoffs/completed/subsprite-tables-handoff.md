# FireRed ReComp — Subsprite Tables Task (independent, parallel-safe)

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
(plain file, not in the git repo — edit directly). Look at the "any
sprite, any size/shape" sub-item under Phase 2's `ObjectSprite.lua` line.

## What NOT to touch

Someone else is actively editing `main.lua` and `import/TitleScreen.lua`
concurrently. **Do not edit either file.** Build in new/existing
`import/`, `src/core/`, and `tests/` files instead. You may extend
`import/ObjectSprite.lua` and `import/OamShapeSize.lua` (both already
exist and are safe to edit — they're not part of the other agent's
active work), and add new `RomAddresses.lua` entries.

## Background: what's already built

- `import/OamShapeSize.lua` decodes a real `struct OamData`'s shape/size
  fields into real pixel dimensions (the standard GBA hardware table).
  Verified against real data.
- `import/ObjectSprite.lua` decodes overworld sprite pics given explicit
  tile width/height (now sourced from `OamShapeSize` rather than a
  hardcoded constant).

Both work correctly for sprites that fit in **one** real OAM entry (max
64x64px on real hardware). The gap: some real game objects are visually
larger/more complex than one OAM entry allows, and are built from
**multiple** OAM entries ("subsprites") positioned relative to the
sprite's origin. Real pokefirered has `struct SubspriteTable`/
`struct Subsprite` (`include/sprite.h`) for exactly this, e.g.
`gObjectEventSpriteOamTables_16x32` (referenced by the player's own
`ObjectEventGraphicsInfo`, even though 16x32 *does* fit one OAM entry —
worth checking why it still uses a subsprite table; may be a real
`.subspriteTables = NULL`-equivalent single-passthrough case, or reveal
something about when subsprite tables are actually necessary).

## The task

1. **Research the real struct layout** in
   `include/sprite.h` (`struct Subsprite`, `struct SubspriteTable`) and
   how it's consumed — grep `src/sprite.c` for
   `AddSubspritesToOamBuffer` (declared in `include/sprite.h`) and read
   its real implementation to understand exactly how subsprite x/y
   offsets and shape/size combine with the parent sprite's position.
   Don't guess the struct layout — confirm field offsets against real
   ROM bytes the same way `import/AffineAnim.lua` or `import/SpriteAnim.lua`
   did (both hit real agbcc struct-padding surprises that only showed up
   when checked against actual ROM bytes, not just the C declaration —
   expect the same here, verify don't assume).
2. **`import/SubspriteTable.lua`**: decode a real `SubspriteTable` (an
   array of `Subsprite` entries: x offset, y offset, shape, size) given
   a ROM offset.
3. **Find a real object that actually needs multiple OAM entries** — a
   sprite whose real `.width`/`.height` in its `ObjectEventGraphicsInfo`
   exceeds 64x64 (the largest single real OAM size), or whose subsprite
   table has more than one real entry with meaningfully different
   offsets (not just a 1-entry passthrough). Search
   `src/data/object_events/object_event_graphics_info.h` for large
   `.width`/`.height` values, and their matching
   `gObjectEventSpriteOamTables_*` arrays in
   `src/data/object_events/object_event_subsprite_tables.h` to find a
   concrete multi-entry example.
4. **Extend `import/ObjectSprite.lua`** (or add a new function
   alongside it, your call) to composite a sprite from multiple OAM
   entries using a decoded `SubspriteTable`: for each subsprite entry,
   decode its own tile block (using that entry's own shape/size-derived
   dimensions) at the appropriate x/y offset from the sprite's origin,
   and composite them into one combined image.
5. **Verify against the real multi-entry object you found** in step 3 —
   decode it, confirm the composited result's overall dimensions and
   that it doesn't look garbled (spot-check a recognizable region by
   eye if you can render it, or at minimum verify structurally: correct
   overall bounding box, no overlapping-garbage pixel regions where two
   subsprites shouldn't overlap).

### Explicitly out of scope

- Don't try to wire this into `main.lua` (someone else owns that file
  right now) — just get the decode+composite pipeline built and tested.
  Note in your summary what a `main.lua` integration would look like.
- Don't worry about subsprite *animation* (subsprites can have their own
  per-frame OAM tables in some games) unless you find pokefirered
  actually uses that — check first, don't assume.

## Conventions to follow

- Every module's header comment cites the real struct/source file and
  states exactly what was verified against real ROM data — see
  `import/OamShapeSize.lua` or `import/AffineAnim.lua` for house style
  (both recently hit real agbcc padding surprises worth reading as
  examples of "verify, don't assume the C struct's raw size").
- `RomAddresses.lua`: real addresses via `arm-none-eabi-nm
  pokefirered.elf | grep <name>` (static/local symbols aren't in the
  linker `.map` but `nm` finds them anyway). Addresses are stored
  pre-subtracted (`0x08xxxxxx - 0x08000000`); raw pointers decoded out
  of ROM bytes themselves stay as full addresses — don't mix these two
  conventions up, it's a recurring bug class in this project's history.
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

A summary of what was built, what was verified against real ROM data
and how, which real multi-OAM object you tested against, what's
explicitly left out of scope, and the file list touched.
