# FireRed ReComp — Real Save File I/O Task (independent, parallel-safe)

## Context you need

This project (`/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp/`)
is a **recomp** of Pokémon FireRed: real decompiled C source
(`/home/mellow/Documents/Projects/Pokemon ReComp/Disassembled_Games/Classic/pokefirered-master/`)
ported by hand into Lua/LÖVE2D, pulling every asset directly out of a
verified real ROM at load time. Nothing is placeholder — every module is
verified against real ROM bytes or real source, documented in its header
comment.

Verified ROM:
`/home/mellow/Documents/Projects/Pokemon ReComp/FireRed/pokefirered-master/pokefirered.gba`
(SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`).

Checklist: `/home/mellow/Documents/Projects/Pokemon ReComp/docs/handoffs/firered-recomp-checklist.md`.
This is Phase 3's `- [ ] Save/load with schema versioning, corruption-safe
writes` line, fully unchecked.

## What NOT to touch

Do not edit `main.lua` — a separate, concurrently-running integration
handoff (`phase3-integration-handoff.md`, if still open, check
`handoffs/`) owns that file right now. Build in `src/core/` and `tests/`
only.

## Background: what's already built (reuse, don't reinvent)

- `src/core/SaveBlockLayout.lua` — real `SaveBlock1`/`SaveBlock2` field
  names/offsets/sizes (scoped to new-game-relevant fields — check its
  header for exactly what's modeled vs. deliberately left out, e.g. PC
  boxes/quest log/mail aren't in there yet).
- `src/core/NewGameDefaults.lua` — real default field values for a fresh
  save.
- `src/core/BoxPokemonCodec.lua` — real 80-byte `BoxPokemon` encrypt/
  decrypt (both directions implemented).
- `src/core/PartyModel.lua`, `PcBoxes.lua`, `Bag.lua`, `Money.lua`,
  `DexTracker.lua` — the in-memory runtime models this task needs to
  serialize/deserialize.

None of the above does actual file I/O — they're all in-memory data
shapes. This task is: **turn an in-memory save state into real save-file
bytes matching FireRed's actual on-disk format, and back.**

## The task

1. **Read the real save format**: `src/save.c` is the real save-system
   implementation — read it for the real section-based scheme: multiple
   ~4KB "sections" per save slot (`SaveSector`/similar real struct —
   confirm the exact name from source, don't guess), each with a real
   footer containing a signature, a section ID, a save-counter/generation
   number, and a checksum. FireRed keeps **two full save copies**
   (alternating slots) so a power-loss mid-write can't corrupt the only
   copy — read `TrySavingData`/`HandleSavingData`/`LoadGameSave` (real
   function names — confirm exact ones from source) for the real
   read-back/validation/slot-selection logic (which of the two slots is
   "current" is decided by comparing save-counters, not just "the last
   one written").
2. **Read the real checksum algorithm**: FireRed uses a real 16-bit
   checksum over each section's data (`CalculateChecksum`-equivalent,
   confirm the real name/algorithm from `src/save.c` — don't assume it's
   a standard CRC16 variant without checking, GBA-era Pokémon games have
   historically used a simple additive checksum, not real CRC).
3. **`src/core/SaveFileCodec.lua`**: given an in-memory save state
   (built from `SaveBlockLayout.lua`'s field shape, populated by
   `PartyModel`/`Bag`/`Money`/etc.), serialize it into the real
   section-based, checksummed, dual-slot byte format. And the reverse:
   given real save-file bytes, decode them back into the in-memory shape,
   including real slot-selection (pick the newer of the two save copies)
   and corruption handling (a slot with a bad checksum should be
   rejected in favor of the other real copy, matching real game
   behavior — don't invent your own recovery policy, port the real one).
4. **Schema versioning**: this project's own concern, not something to
   port from the real game (FireRed doesn't version its own save format
   the way this project might need to as it evolves `SaveBlockLayout.lua`
   over time). Add a small versioning scheme — e.g. a leading version
   byte/field in whatever wrapper this project uses around the real
   section data — so a future `SaveBlockLayout.lua` change can detect
   and migrate (or at least loudly refuse) an old-shape save rather than
   silently misreading it. Keep this simple; don't over-engineer a full
   migration framework for a single current schema version.
5. **Round-trip test**: build a synthetic in-memory save state (using
   `NewGameDefaults.lua`'s real fresh-game values as a starting point,
   then mutate a few fields — money, a party member via
   `BoxPokemonCodec`, a flag), encode it, decode it back, and assert the
   round-trip is lossless. Also test the corruption-handling path:
   corrupt one slot's checksum and confirm the codec correctly falls
   back to the other real copy instead of returning corrupted data.

### Explicitly out of scope

- No actual filesystem read/write wiring into `main.lua` (that's the
  integration task's territory, or a future follow-up) — this task
  produces/consumes byte buffers in memory (e.g. Lua strings or byte
  arrays), not files on disk. If you want to demonstrate it working
  end-to-end, write a small standalone test/tool that does real
  `io.open`/file write, but don't wire it into the live game loop.
- No options-menu/save-UI.
- Don't try to model every single real save-block field if
  `SaveBlockLayout.lua` doesn't have it yet (PC boxes, quest log, mail,
  etc.) — serialize what's modeled, and clearly note what's NOT
  round-trippable yet because the in-memory shape doesn't exist (that's
  a `SaveBlockLayout.lua` gap, not this task's to fix, though flagging
  it in the checklist is useful).

## Conventions to follow

- Every module's header comment cites the real struct/function/source
  file (`src/save.c`) and states exactly what was verified/transcribed
  vs. what's this-project-specific (the version byte).
- No `bit` library / Lua 5.3 bitwise operators (LuaJIT + plain Lua 5.1
  compatibility) — see `import/Lz77.lua` or `src/core/BoxPokemonCodec.lua`
  (which already does real XOR-based encrypt/decrypt without a bit
  library) for the established pattern.
- Tests: plain-Lua unit tests, no ROM needed (this is compile-time
  struct/algorithm work, not ROM-byte decoding — though double-check
  `src/save.c`'s real checksum algorithm/section layout against source,
  don't guess). Run the full suite before finishing:
  ```
  cd "/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp"
  for f in tests/*.lua; do lua5.1 "$f" || echo "FAILED: $f"; done
  ```
- **Don't commit anything** — leave changes in the working tree.
- Update the checklist's "Save/load with schema versioning" line for
  exactly what you finished/verified.

## Deliverable

A summary of the real save format you read (section/slot/checksum
scheme), what's transcribed directly from `src/save.c` vs.
this-project-specific (the version byte), what round-trips correctly,
how corruption-fallback was verified, what's explicitly not
round-trippable yet (missing `SaveBlockLayout.lua` fields), and the file
list touched.
