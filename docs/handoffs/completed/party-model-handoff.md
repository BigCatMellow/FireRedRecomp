# FireRed ReComp — Pokémon/Party Data Model Task (independent, parallel-safe)

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
(plain file, not in the git repo — edit directly). This is Phase 3's
"Party model, dex ownership/seen, bag, money, PC stub" line.

**Before starting**, check whether another handoff
(`save-block-handoff.md`, same folder) has already landed relevant code
— `src/core/SaveBlockLayout.lua`/`NewGameDefaults.lua` may exist by the
time you read this and could be useful context (a Pokémon's owned-party
data ultimately lives in the save block). If those files don't exist
yet, don't wait for them — this task can proceed independently using
Phase 1's already-built species/move/growth-rate data.

## What NOT to touch

Someone else is actively editing `main.lua` and map/movement-related
files (`src/core/PlayerMovement.lua`, map compositor code) concurrently.
**Do not edit `main.lua`.** Build in new files under `src/core/`,
`import/`, and `tests/`.

## Background: what's already built (Phase 1)

- `import/SpeciesInfo.lua` decodes real `struct SpeciesInfo` (base
  stats, types, growth rate, abilities, catch rate, etc.) — real,
  tested, verified.
- `import/BattleMove.lua`, `import/TypeChart.lua`, `import/Nature.lua`
  — real move data, type effectiveness, nature stat modifiers.
- `import/PokedexOrder.lua` — real dex ordering/species-to-national-dex
  mapping.

None of this models an actual **Pokémon instance** (a specific caught
Bulbasaur at level 12 with specific IVs/EVs/moves/nickname) — that's a
different, real struct (`struct Pokemon`/`struct BoxPokemon`,
`include/pokemon.h`) this task builds.

## The task

1. **Read the real structs**: `include/pokemon.h`'s `struct BoxPokemon`
   (the "storage" form — what's actually saved, including its real
   **encrypted substruct** layout) and `struct Pokemon` (adds runtime-
   only fields like current HP, status, stat stages on top of a
   `BoxPokemon`). Don't guess field layout — these are real, documented
   structs, read them directly.
2. **The real substruct encryption/shuffle**: FireRed's `BoxPokemon`
   data is checksummed and the order of its 4 core substructs (growth/
   attacks/EVs-condition/misc) is shuffled based on personality value —
   this is real, documented behavior (`src/pokemon.c`'s
   `EncryptBoxMon`/`DecryptBoxMon`/`sBoxMonSubstructOrders` or similar —
   grep for the real function/table names, don't guess). You need this
   to correctly interpret a real captured Pokémon's data (relevant for
   later save-file reading), but you can build and test the stat-
   calculation math (step 3) without it using synthetic/unencrypted
   test data — don't block on fully implementing decrypt if it's taking
   too long; get it working for at least reading, note if write/
   encrypt is skipped.
3. **`src/core/PokemonStats.lua`**: the real stat calculation formula
   (`CalculateMonStats`/`CalculateStat` or equivalent — find the real
   function in `src/pokemon.c`) — given species base stats (from
   `SpeciesInfo.lua`), level, IVs, EVs, and nature (from `Nature.lua`),
   compute real HP/Attack/Defense/Sp.Atk/Sp.Def/Speed. This is pure,
   real, well-defined math — verify it against a real known Pokémon
   (e.g. a fresh level-5 starter's real stats, which you can find
   documented in-game or derive by hand-checking the formula against
   known IV=0/EV=0 values).
4. **`src/core/ExperienceTable.lua`**: the real growth-rate exp curves
   (`gExperienceTables` or equivalent in `src/pokemon.c`/
   `src/data/... ` — there are several real growth rate formulas:
   Erratic/Fast/MediumFast/MediumSlow/Slow/Fluctuating — `SpeciesInfo`
   already tells you which one a species uses). Verify against real
   known level thresholds if you can find/derive them.
5. **`src/core/PartyModel.lua`**: a simple in-memory party (array of up
   to 6 Pokémon instances) with basic operations (add, is-full, get by
   slot) — this is mostly project-specific plumbing, not something to
   "verify against ROM," just keep it clean and tested.
6. **Tests**: plain-Lua unit tests for the stat formula and exp tables
   (pure math, no ROM needed for the formula itself, though citing real
   verification values is good); ROM-integration tests
   (`POKEPORT_ROM` opt-in) for anything that reads real species/growth-
   rate data to compute against.

### Explicitly out of scope

- No real save-file reading/writing (that's the save-block handoff's
  territory, or a later task) — this task models a Pokémon instance
  in memory, not how it round-trips through save data.
- No move-learning-on-level-up logic, no evolution logic — just stats/
  exp/party structure. Note these as real follow-up systems if you want,
  but don't build them here.
- No battle-specific state (this isn't the battle engine) — just "what
  is a Pokémon, structurally, and what are its real stats."

## Conventions to follow

- Every module's header comment cites the real struct/function/file and
  states exactly what was verified — see `import/SpeciesInfo.lua` for
  house style on citing a real struct, or `import/AffineAnim.lua` for
  an example of catching a real struct-padding surprise by checking
  actual bytes rather than trusting the C declaration (expect similar
  possible surprises here, especially in the substruct shuffle table).
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
  `import/Lz77.lua`'s header comment. The real substruct
  encryption/shuffle involves real XOR-based decryption — you'll need
  arithmetic-based XOR (a small helper, e.g. bit-by-bit via `%`/
  `math.floor`, the same pattern every other module in this project
  uses) since there's no bit library available.
- **Don't commit anything** — leave changes in the working tree.
- Update the checklist for what you actually finished/verified, in the
  existing entry style.

## Deliverable

A summary of what real structs/formulas you read and verified, what you
built, what's deliberately left out (especially if encrypt/decrypt is
incomplete), and the file list touched.
