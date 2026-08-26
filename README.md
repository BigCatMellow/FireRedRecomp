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

Full plan: [`docs/roadmap.md`](docs/roadmap.md).
Source crosswalk: [`docs/reference/source-inventory.md`](docs/reference/source-inventory.md).

## Status

**Phase 1 is complete; every other phase remains evidence-gated.** Phase 0,
2–8 each contain implementation work, but none should be treated as complete
until its stated exit criterion passes. The full ROM importer/canonical
data model (species, moves, types, items, abilities, natures, trainers +
parties, full text/charmap decoding including control codes, the complete
map pipeline — header/layout/events/connections/scripts/tilesets/graphics,
a correctly-colored real map renderer, wild encounters, Pokédex order, and
sprite/cry/song pointer tables) is built, and every module is verified
against real ROM bytes, not just struct definitions — see
[`docs/handoffs/firered-recomp-checklist.md`](docs/handoffs/firered-recomp-checklist.md)
for the complete, itemized breakdown (kept current as work lands; treat it
as the source of truth over this section).

Phase 1's exit criterion — "a read-only data viewer capable of displaying
every map, species, move, and trainer record" — is met: run `love .` with
a verified ROM and press **V** to browse. `tests/full_sweep_validation_test.lua`
decodes all 411 species, 354 moves, and 743 trainers (not just hand-picked
ones) and confirms they're all sane.

**Playable milestone:** the same boot renders an actual, correctly-colored,
recognizable map (Pallet Town by default; `POKEPORT_MAP=group,num` for any
other — Route 1 and an indoor map are also verified) straight out of ROM
bytes. The W view now has a player/camera, movement, warps, NPC dialogue,
real grass encounter rolls, and a bounded live FIGHT/RUN wild battle using
ROM terrain and Pokémon art. A full new-game identity flow (gender/naming),
starter selection in Oak's Lab, and the mandatory Oak's-lab rival tutorial
battle (real trainer AI, win/loss rewards and heal) are also live end to
end, and losing a wild battle now runs a real whiteout (money loss, party
heal, respawn at the last real heal location). Wild captures persist to the
party and Pokédex when the party has room; PC overflow remains open. It is not
yet a full game loop: full move effects, general trainer AI, and battle
animation are still open. Every module was checked against bytes from a real, verified ROM —
several surprises (padded record sizes, byte-offset quirks, the
640-tile/640-metatile/7-palette primary/secondary tileset split, static
symbols with no linker-map entry) only showed up that way. See
`tests/species_integration_test.lua` and `tests/full_sweep_validation_test.lua`
(both opt-in via `POKEPORT_ROM=...`, skip cleanly with no ROM present) and
the full test suite (118 test files with a verified ROM present).

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

## Verification and project status

Run every checked-in test without a ROM:

```
bash scripts/test_all.sh
```

With a legally obtained, verified FireRed US v1.0 ROM, run the ROM-backed
checks as well:

```
POKEPORT_ROM=/path/to/pokefirered.gba bash scripts/test_all.sh
```

To include the opt-in headless LÖVE runtime smoke check (boot, fixed-tick
input, and real house-to-Pallet warps), install LÖVE 11.x and Xvfb, then run:

```
POKEPORT_ROM=/path/to/pokefirered.gba POKEPORT_RUNTIME_REPLAY=1 bash scripts/test_all.sh
```

The default replay is the house-to-Pallet smoke path. The stronger bounded
field/battle replay can be run explicitly:

```
POKEPORT_ROM=/path/to/pokefirered.gba POKEPORT_RUNTIME_REPLAY_CASE=route1_wild_defeat bash scripts/runtime_replay_smoke.sh
```

Use `POKEPORT_RUNTIME_REPLAY_CASE=route1_wild_win` for the corresponding
normal-input Route 1 victory replay.

The isolated persistence gate runs two fresh LÖVE processes in a temporary
XDG sandbox, saves through the normal **K** callback, and loads through the
normal **L** callback:

```
POKEPORT_ROM=/path/to/pokefirered.gba bash scripts/runtime_save_restart_replay.sh
```

The current-runtime natural-capture gate similarly exercises the Viridian Mart
clerk, purchase UI, Route 1 capture, and a fresh-process reload in an isolated
sandbox:

```
POKEPORT_ROM=/path/to/pokefirered.gba bash scripts/runtime_natural_capture_replay.sh
```

The evidence-backed project status is in
[`work/roadmaps/CAPABILITY_CHECKLIST.md`](work/roadmaps/CAPABILITY_CHECKLIST.md).

Launches a window. If `POKEPORT_ROM` (env var) points at a verified `.gba`
file, it composites and draws Pallet Town — press **V** to switch to the
data viewer (Tab: cycle species/moves/trainers/maps, Up/Down: ±1 record,
PageUp/PageDown: ±10, Left/Right: change map group, V again: back to the
map). `POKEPORT_MAP=group,num` picks a different starting map.
Press **N** for the post-Oak gender/player-name/rival-name flow, or press
Enter from the **S** Oak-scene view. Its naming keyboard uses arrows,
Enter=A, Backspace=B, Right Shift=Select/page, and Space=Start/jump-to-OK.
Press **W** for the overworld; stepping into real tall grass can launch the
live battle. In battle, arrows select FIGHT/RUN or a move, Enter=A, and
Backspace=B. A normal fresh session with no starter visibly refuses a wild
battle rather than inventing a party member. For a deterministic developer
battle only, `POKEPORT_BATTLE=16,3 POKEPORT_BATTLE_DEBUG_PARTY=1,5 POKEPORT_BATTLE_ADVANCE=2` boots a
deterministic Pidgey Lv3 action-menu view for screenshots/tests.
Press **K** to save the active session (a fixed file inside LÖVE's
sandboxed save directory) or **L** to load it back, from any view; a
loaded session resumes on its saved map at its saved position.
Press **M** for the real Viridian City Poké Mart BUY flow (real prices,
real purchase math, real Bag persistence) against the active session's
money/bag -- a dev-reachable trigger, since real map/NPC/script
interaction to walk in and talk to the clerk isn't wired yet.
`POKEPORT_VIEWER=category:index` (e.g. `species:1`) boots straight into a
specific viewer record. Set `POKEPORT_SCREENSHOT=1` to save a screenshot
(`screenshot.png` in LÖVE's save directory, e.g.
`~/.local/share/love/firered-recomp/` on Linux) and quit automatically —
useful for headless verification. Save files are separate from the ROM-derived
cache and are written only when the player saves.

A LÖVE 11.x runtime is required to launch the desktop app. The Lua test suite
uses `lua5.1` and does not require a display.

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
