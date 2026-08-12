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

**Phase 0 done. Phase 1 (importer/data model) underway — first real,
ROM-verified extraction works end-to-end.** No gameplay exists yet. What's
here:

- Directory layout matching the roadmap's target tree.
- `import/RomImporter.lua` — ROM identity verification (SHA-1) against the
  supported FireRed US release.
- `import/Lz77.lua` — GBA BIOS-compatible LZ77 decompressor (graphics,
  tilemaps, and some data tables in the ROM are LZ77-compressed). Verified
  against hand-built compressed fixtures, not yet against real ROM data.
- `import/SpeciesInfo.lua` — parses the 28-byte `struct SpeciesInfo` record
  (pokefirered `include/pokemon.h`) out of raw bytes.
- `import/RomAddresses.lua` — real ROM table addresses, keyed by SHA-1.
  `gSpeciesInfo`'s address was obtained by building `pokefirered-master`
  from source with an unprivileged local toolchain (ARM GNU toolchain +
  `agbcc`, no sudo/apt) and reading the resulting linker `.map`. **The build
  output is byte-identical to retail** (`sha1sum` matches the known
  `41cb23d8...` FireRed(US) v1.0 hash this project already treats as
  supported), so it's a legitimate stand-in for a player-supplied ROM during
  development.
- `tests/species_integration_test.lua` — parses Bulbasaur/Ivysaur/Venusaur/
  Charmander's real base stats out of that built ROM and checks them
  against known values. Passes. Opt-in via `POKEPORT_ROM=...`; skips
  cleanly with no ROM present (a fresh checkout has none).
- `conf.lua` / `main.lua` — boots a LÖVE2D window and reports ROM
  verification status. No rendering, no gameplay.
- `tests/` — all unit tests pass (`lua5.1 tests/*.lua`).

Next: extend `RomAddresses`/importer coverage to more tables (moves,
items, trainers, maps), starting to fill out the canonical data schemas the
roadmap's Phase 1 calls for.

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

Launches a window, and if `POKEPORT_ROM` (env var) points at a `.gba` file,
runs it through `RomImporter` and prints the verification result. No cache
is written yet — that's Phase 1.

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
