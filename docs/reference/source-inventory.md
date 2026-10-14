# Source Inventory

## FireRed decompilation / behavioral reference

**Canonical upstream:** https://github.com/pret/pokefirered

**Pinned reference revision:** `037335f4c725d7c9aecdac87066f2002b4bd7e14`
(pret/pokefirered `master` as observed 2026-09-29).

The decompilation is a **reference**, not a FireRedRecomp build or runtime
dependency. Do not vendor the decompilation into this repository.

For local source crosswalk work, clone it separately. A sibling checkout is
the simplest convention:

```text
Projects/
├── FireRedRecomp/
└── pokefirered/
```

Agents or local tooling that need an explicit locator may use
`POKEFIRERED_DECOMP=/path/to/pokefirered` as a local convention. No checked-in
FireRedRecomp script currently requires that variable.

**Use the pinned decomp for:** game behavior and data crosswalks.

- `graphics/` — Pokémon, trainers, tilesets, UI art, region-map tiles, and
  palettes.
- `data/` and `src/data/` — maps, encounters, trainers, constants, layouts,
  events, and text data.
- `src/` and `include/` — the behavioral specification for battle, menus,
  scripts, field systems, task flows, audio, and rendering effects.
- `sound/` — music/song assets and audio definitions.

When a FireRedRecomp implementation or evidence note depends on decomp source
behavior, record the relevant upstream path and use the pinned revision above
unless a deliberate reference-pin update has been reviewed.

The public application must continue to import a player-supplied, verified
FireRed ROM rather than bundle the decompilation, ROM content, generated
caches, or extracted game assets.

## GBA BIOS disassembly

**Path:**
`/home/mellow/Documents/Projects/Pokemon ReComp/Disassembled_Games/Bios/gba_bios-master`

**Use it for:** reference behavior for GBA BIOS calls used by FireRed.

Most relevant native-runtime references:

- LZ77 decompression semantics.
- Affine-transform helpers.
- Fixed-point helpers such as square root and arctangent.

Do not treat it as a runtime dependency. Native ReComp code replaces hardware
interrupts, DMA/VRAM copies, reset, and timing waits with desktop equivalents.

## Local GBA BIOS binary

**Path:**
`/home/mellow/Documents/Projects/Pokemon ReComp/Disassembled_Games/Bios/gba_bios.bin`

- Size: 16,384 bytes.
- Verified MD5: `a860e8c0b6d573d191e4ec7db1b1e4f6`.

This matches the adjacent BIOS project's documented checksum. It can be kept
as a local validation oracle for BIOS-call behavior; do not package it or
require it at runtime.

## Current Gen1Recomp engine reference

**Path:**
`/home/mellow/Downloads/0-Pokemon-Recomp/engine_src/gen1recomp-0.1.75`

**Reuse conceptually:** LÖVE application lifecycle, mod loader, settings,
input, logging, test harness, cache/import workflow, packaging, and modern UI
patterns.

**Do not reuse as the final FireRed gameplay engine:** Gen1Recomp is a
hand-written 160×144 Gen 1 runtime. FireRed requires a new 240×160 GBA-era
world, battle, script, render, audio, and save implementation.

## Immediate reference milestones

1. ROM importer and canonical generated-data schema.
2. Title/Oak/Pallet screenshot parity at 240×160.
3. New game to Route 1 vertical slice, including a wild battle and save/load.
4. Deterministic Gen 3 battle rules engine.
5. Full Kanto credits-path parity, then Sevii/postgame.
