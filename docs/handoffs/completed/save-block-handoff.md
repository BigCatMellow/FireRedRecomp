# FireRed ReComp — Save Block Data Model Task (independent, parallel-safe)

**Status note (2026-08-13): still not started.** Everything below is
unchanged from when this was written, except one thing worth knowing:
`src/core/BoxPokemonCodec.lua` and `src/core/PartyModel.lua` now exist
(a separate handoff landed them) — a real 80-byte `BoxPokemon`
encrypt/decrypt codec and a simple in-memory party model. Neither does
save-FILE I/O; they operate on synthetic in-memory blobs. This task can
now build `SaveBlockLayout.lua` referencing those two as the real
per-party-slot/box-slot payload shape instead of guessing it — check
`src/core/BoxPokemonCodec.lua`'s header comment before starting.

## Context you need

This project (`/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp/`)
is a **recomp** of Pokémon FireRed: real decompiled C source
(`/home/mellow/Documents/Projects/Pokemon ReComp/Disassembled_Games/Classic/pokefirered-master/`)
ported by hand into Lua/LÖVE2D, pulling every asset directly out of a
verified real ROM at load time. Nothing is placeholder — every module is
verified against real data, documented in its header comment.

Verified ROM:
`/home/mellow/Documents/Projects/Pokemon ReComp/FireRed/pokefirered-master/pokefirered.gba`
(SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`).

Checklist: `/home/mellow/Documents/Projects/Pokemon ReComp/docs/handoffs/firered-recomp-checklist.md`
(plain file, not in the git repo — edit directly). This is **Phase 3**
groundwork (`## Phase 3 — Playable vertical slice`), specifically
"New-game naming, initial flags/vars" and save data structure —
Phase 1/2 explicitly deferred this ("Save defaults — resolved: N/A for
Phase 1... real defaults come from procedural code
(`SetDefaultOptions()`, `NewGameInitData()`, `src/new_game.c`)... this
is Phase 3 runtime logic, not a Phase 1 data-model gap").

## What NOT to touch

Someone else is actively editing `main.lua` and `import/TitleScreen.lua`
concurrently. **Do not edit either file.** This task is pure data-model
work — new files under `src/core/` (or `import/` if you're extracting
something ROM-side, though this task is mostly about procedural
defaults, not ROM tables) and `tests/`.

## The task: model the real save data structure + real default values

This is **not** about building a save/load UI or file I/O — it's about
faithfully modeling *what fields exist* in FireRed's save data and
*what their real default values are* when a new game starts, so future
Phase 3 work (new-game flow, options menu, flags/vars) has a real
foundation instead of guessing field names.

### Suggested scope

1. **Read the real save block structs**: `include/global.h` defines
   `struct SaveBlock1` and `struct SaveBlock2` (or check
   `include/global.fieldmap.h`/similar — search for `struct SaveBlock`).
   These are large, real, fully-documented C structs (player position,
   party, bag/inventory, flags array, vars array, options, Pokédex
   flags, etc.) — don't guess field names or offsets, read them
   directly from the header.
2. **Read the real default-assignment code**: `src/new_game.c`'s
   `NewGameInitData()` and `SetDefaultOptions()` (also referenced from
   `src/load_save.c` / `src/start_menu.c` — grep for these function
   names to find every real call site) — these are the functions that
   actually populate a fresh save with its starting values (starting
   money, starting flags set TRUE/FALSE, default text speed, etc.).
3. **`src/core/SaveBlockLayout.lua`**: a **pure data model** — Lua
   tables describing the real struct field names, types, and byte
   offsets/sizes for `SaveBlock1`/`SaveBlock2` (at least the fields
   relevant to a fresh new-game state — you don't need to model every
   single field on day one, but don't invent fields that don't exist in
   the real struct either). Cite the real header file and line/field
   names in your doc comments.
4. **`src/core/NewGameDefaults.lua`**: the real default VALUES a fresh
   save gets, transcribed from `NewGameInitData()`/`SetDefaultOptions()`
   — e.g. real default text speed, real default battle style, which
   real `FLAG_*`/`VAR_*` constants get set on a new game (check
   `include/constants/flags.h`/`vars.h` for the real names — these are
   compile-time constants, already confirmed in Phase 1 as "not a ROM
   data table," so you're reading real header `#define`s, not decoding
   ROM bytes here).
5. **Tests**: this is pure Lua-testable logic (no ROM needed for most
   of it, since you're modeling compile-time struct layout + procedural
   defaults, not decoding binary ROM data) — write real unit tests
   asserting the documented default values match what you read from the
   real source (e.g. "default text speed constant equals X, matching
   `SetDefaultOptions()`'s real assignment").

### Explicitly out of scope

- No actual save file read/write (SRAM emulation, checksums, sector
  management) — that's real save I/O, a separate and much bigger task.
  This task only models the *shape* and *default values* of save data.
- No options menu UI — that's rendering work, someone else's active
  files right now anyway.
- Don't try to model every single field in the real structs if they're
  huge (SaveBlock1 in particular has a lot of surface area: full party,
  full bag, full flags/vars arrays, PC boxes, etc.) — prioritize what a
  "new game just started" state actually needs: player name/gender,
  starting flags/vars, default options, starting money, starting
  location. Note in your summary what you deliberately left out.

## Conventions to follow

- Every module's header comment cites the real struct/function/file and
  states exactly what was verified/transcribed — see
  `import/CryTable.lua` for house style on citing real structs, or
  `import/PokedexOrder.lua` for citing real header constants.
- Tests: plain-Lua unit tests always run. Run the full suite before
  finishing:
  ```
  cd "/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp"
  for f in tests/*.lua; do lua5.1 "$f" || echo "FAILED: $f"; done
  ```
  (Most of your tests likely won't need `POKEPORT_ROM` at all, since
  this task is about compile-time constants and struct shape, not ROM
  bytes — that's fine, plain unit tests are the majority pattern here.)
- **Don't commit anything** — leave changes in the working tree.
- Update the checklist (Phase 3 section) for what you actually
  finished, in the existing entry style.

## Deliverable

A summary of what real structs/functions you read, what you modeled,
what you deliberately left out and why, and the file list touched. Be
precise about which fields/defaults are directly transcribed from real
source vs. any you had to infer.
