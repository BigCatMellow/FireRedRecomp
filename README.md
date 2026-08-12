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

**Phase 0 and Phase 1 are both complete.** The full ROM importer/canonical
data model (species, moves, types, items, abilities, natures, trainers +
parties, full text/charmap decoding including control codes, the complete
map pipeline — header/layout/events/connections/scripts/tilesets/graphics,
a correctly-colored real map renderer, wild encounters, Pokédex order, and
sprite/cry/song pointer tables) is built, and every module is verified
against real ROM bytes, not just struct definitions — see
[`../FireRed/firered-recomp-checklist.md`](../FireRed/firered-recomp-checklist.md)
for the complete, itemized breakdown (kept current as work lands; treat it
as the source of truth over this section).

Phase 1's exit criterion — "a read-only data viewer capable of displaying
every map, species, move, and trainer record" — is met: run `love .` with
a verified ROM and press **V** to browse. `tests/full_sweep_validation_test.lua`
decodes all 411 species, 354 moves, and 743 trainers (not just hand-picked
ones) and confirms they're all sane.

**Visual milestone:** the same boot renders an actual, correctly-colored,
recognizable map (Pallet Town by default; `POKEPORT_MAP=group,num` for any
other — Route 1 and an indoor map are also verified) straight out of ROM
bytes. Still no gameplay, no player, no camera — that's Phase 2+.

No gameplay exists yet; Phase 2 (the real GBA renderer/scene runtime) is
next. Every module was checked against bytes from a real, verified ROM —
several surprises (padded record sizes, byte-offset quirks, the
640-tile/640-metatile/7-palette primary/secondary tileset split, static
symbols with no linker-map entry) only showed up that way. See
`tests/species_integration_test.lua` and `tests/full_sweep_validation_test.lua`
(both opt-in via `POKEPORT_ROM=...`, skip cleanly with no ROM present) and
the rest of `tests/` (30 test files, 298 checks total with a verified ROM
present).

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
file, it composites and draws Pallet Town — press **V** to switch to the
data viewer (Tab: cycle species/moves/trainers/maps, Up/Down: ±1 record,
PageUp/PageDown: ±10, Left/Right: change map group, V again: back to the
map). `POKEPORT_MAP=group,num` picks a different starting map.
`POKEPORT_VIEWER=category:index` (e.g. `species:1`) boots straight into a
specific viewer record. Set `POKEPORT_SCREENSHOT=1` to save a screenshot
(`screenshot.png` in LÖVE's save directory, e.g.
`~/.local/share/love/firered-recomp/` on Linux) and quit automatically —
useful for headless verification. No save-game cache is written yet.

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
