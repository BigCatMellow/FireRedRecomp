# FireRed ReComp

A native desktop/mobile recreation of Pokémon FireRed (US v1.0), built the
same way Gen1Recomp built Pokémon Red: the player supplies a legally
obtained, verified ROM on first launch; an importer decodes it into a
private generated cache; gameplay then runs in a native LÖVE2D runtime, not
an emulator.

This is a new sibling engine to Gen1Recomp, not a reskin of it. FireRed is a
GBA-era game with its own display format, save layout, map model, scripting
system, and Gen 3 battle system. Gen1Recomp's product/engine patterns (app
shell, mod loader, settings, input, save tooling) are worth reusing
conceptually; its Gen 1 gameplay code is not.

Full plan: [`../firered-recomp-roadmap.md`](../firered-recomp-roadmap.md).
Source crosswalk: [`../firered-recomp-reference/source-inventory.md`](../firered-recomp-reference/source-inventory.md).

## Status

**Phase 0 done. Phase 1 (importer/data model) well underway, and the first
real visual milestone is in: `love .` with a verified ROM renders an actual,
correctly-colored, recognizable Pallet Town** — houses, Oak's lab, the pond,
the garden, tree borders, straight out of ROM bytes (block grid + metatiles
+ tile graphics + palettes, all decoded from scratch). No gameplay, no
player, no camera movement yet — this is "does the data pipeline produce a
real picture," not a game. Working checklist (kept up to date as work
lands): [`../FireRed/firered-recomp-checklist.md`](../FireRed/firered-recomp-checklist.md).

**Data tables:**

- `import/RomImporter.lua` — ROM identity verification (SHA-1).
- `import/RomAddresses.lua` — real ROM table addresses, keyed by SHA-1.
  Obtained by building `pokefirered-master` from source with an
  unprivileged local toolchain (ARM GNU toolchain + `agbcc`, no sudo/apt)
  and reading the resulting linker `.map`. **The build output is
  byte-identical to retail** (sha1 `41cb23d8...`, the exact hash this
  project already treats as supported), so it's a legitimate stand-in for a
  player-supplied ROM during development.
- `import/Lz77.lua` — GBA BIOS-compatible LZ77 decompressor. Verified
  against hand-built fixtures, not yet against real ROM data.
- `import/SpeciesInfo.lua` — species base stats (28-byte struct).
- `import/BattleMove.lua` — moves. **Real record size is 12 bytes, not the
  struct's 9** (agbcc pads byte-only structs to a 4-byte multiple in
  arrays) — caught by checking real Pound/Karate Chop data, not by trusting
  the header.
- `import/TypeChart.lua` — the type effectiveness chart.
- `import/Item.lua` — items (44-byte struct, has raw pointer fields).
- `import/AbilityNames.lua` — ability name strings (raw charmap bytes).
- `import/Charmap.lua` — FireRed's custom text encoding, generated from
  pokefirered's own `charmap.txt`. Decodes real names correctly
  end-to-end ("BULBASAUR", "MASTER BALL", "STENCH", ...).
- `import/Trainer.lua` — trainers (40-byte struct).
- `import/TrainerParty.lua` — resolves a trainer's party pointer into real
  Pokémon data. **All 4 party-record layouts** (no-item/held-item ×
  default/custom-moves) **are individually verified against real trainers**
  (Youngster Ben, Camper Liam, Black Belt Koichi, Elite Four Lorelei).
- `import/MapHeader.lua` — resolves `gMapGroups[group][num]` (a double
  pointer indirection, not a flat array) to a map's header.
- `import/MapLayout.lua`, `import/MapEvents.lua`, `import/MapConnections.lua`
  — a map's dimensions/tilesets, object events/warps/coord events/bg
  events, and inter-map connections. All verified field-by-field against
  real Pallet Town data.

**Graphics (the new part):**

- `import/GbaGraphics.lua` — GBA 4bpp tile decoding and BGR555→RGB888
  palette decoding. Pure data, no rendering dependency.
- `import/Tileset.lua` — `struct Tileset` (tile/palette/metatile pointers).
- `import/Metatile.lua` — decodes metatile tile entries using the standard
  GBA background-tile-entry bit layout (tile id + h/v flip + palette
  number) — this is universal GBA hardware format, not something
  reverse-engineered from FireRed specifically.
- `import/MapBlockData.lua` — a map's metatile grid.
- `import/MapCompositor.lua` — combines all of the above into full map
  pixel data, correctly handling the primary/secondary tileset split.
- `main.lua` composites Pallet Town and draws it. **Known simplification:**
  metatile layer-type attributes aren't read yet, so both of a metatile's
  layers are always drawn — looked correct for every tile in Pallet Town,
  but isn't guaranteed correct on every map.

Every module above was checked against bytes from a real, verified ROM, not
just against the struct definitions in the header — several surprises
(padded record sizes, byte-offset quirks, the 640-tile/640-metatile/7-palette
primary/secondary tileset split) only showed up that way. See
`tests/species_integration_test.lua` (opt-in via `POKEPORT_ROM=...`, skips
cleanly with no ROM present) and the rest of `tests/`.

Not yet started: map scripts (raw bytecode extraction, not a VM), encounters,
natures, message/control-code text beyond names, save format, borders,
compositing maps beyond Pallet Town, and everything else in Phase 2+ (actual
gameplay, player movement, camera, menus, battles).

## Supported ROM

FireRed (US) v1.0 only, for now. LeafGreen and the v1.1 revision are later
importer variants, added after FireRed parity (see the roadmap's scope-lock
table). No ROM is bundled or distributed by this project; the player
supplies their own dump.

| Release | SHA-1 | Status |
| --- | --- | --- |
| Pokémon FireRed (US) v1.0 | `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc` | Supported |
| Pokémon FireRed (US) v1.1 (rev1) | `dd5945db9b930750cb39d00c84da8571feebf417` | Not yet |

Hashes are taken from the local `pokefirered-master` decompilation's own
`firered.sha1` / `firered_rev1.sha1` files, which is also the disassembly
this project uses as a behavior/data reference (see source inventory doc
above) — it is not bundled here and is not a build dependency of the ROM
itself.

## Running

```
love .
```

Launches a window. If `POKEPORT_ROM` (env var) points at a verified `.gba`
file, it composites and draws Pallet Town. Set `POKEPORT_SCREENSHOT=1` to
save a screenshot (`screenshot.png` in LÖVE's save directory, e.g.
`~/.local/share/love/firered-recomp/` on Linux) and quit automatically —
useful for headless verification. No cache is written yet.

No system `love` binary is required for development: this session used the
LÖVE runtime bundled inside the existing `gen1recomp-x86_64.AppImage`,
extracted with `--appimage-extract` (see project memory for the exact
unprivileged toolchain setup).

## Directory layout

```
firered-recomp/
  src/      native runtime (empty until Phase 2+)
  import/   verified-ROM importer and cache writer
  data/     schemas, defaults, generated-data readers
  assets/   engine-owned art only (no game assets)
  mods/     examples and test mods
  tests/    headless and replay tests
```

## No-ROM contribution rule

Never commit ROM files, GBA BIOS dumps, or any extracted game asset
(graphics, audio, text, maps) to this repository. `.gitignore` excludes the
generated cache directory and common ROM extensions. If you're unsure
whether something is derived game content, don't commit it.
