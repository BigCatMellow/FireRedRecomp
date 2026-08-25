# FireRed ReComp — Dex Ownership/Seen, Bag, Money, PC Box Stub Task (independent, parallel-safe)

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
(plain file, not in the git repo — edit directly). This continues Phase
3's `- [~] Party model, dex ownership/seen, bag, money, PC stub` line —
the Pokémon-instance data model (stats/XP/box codec/party) is already
done; this task is the four things explicitly left out of that pass:
**dex ownership/seen tracking, bag, money, PC box stub.**

## What NOT to touch

Do not edit `main.lua`. Pure data-model work: new files under
`src/core/` and `tests/`.

## Background: what's already built (reuse, don't reinvent)

- `src/core/BoxPokemonCodec.lua` — real 80-byte `BoxPokemon`
  encrypt/decrypt + substruct parsing. A PC box slot holds exactly this
  shape (a boxed Pokémon has no battle-stat cache the way a party
  member does — check `struct BoxPokemon` vs. `struct Pokemon` in
  `include/pokemon.h` to confirm this before assuming).
- `src/core/PartyModel.lua` — simple tested 6-slot in-memory party.
  Your PC-box stub should follow the same lightweight, testable pattern
  (not full save-file I/O — see "explicitly out of scope").
- Phase 1 already confirmed (documented in the checklist's "Dex & Save
  Data" section) that `FLAG_*`/`VAR_*` and dex-related flags are
  compile-time constants (`include/constants/flags.h` and similar), NOT
  ROM data tables — you're reading real header `#define`s here, not
  decoding binary ROM data for this part.
- `import/PokedexOrder.lua` already resolves species ↔ national dex
  number mapping (`sSpeciesToNationalPokedexNum`) — dex ownership/seen
  tracking is indexed by national dex number, so this is your species
  ↔ dex-index bridge; reuse it, don't rebuild it.

## The task

1. **Dex ownership/seen**: real FireRed tracks this as two bit arrays
   (owned/caught, seen) indexed by national dex number, living in the
   save block (`include/pokemon.h` / `include/global.h` — search for
   `pokedexOwned` FLAG_* range or bit-array fields referenced by
   `GetSetPokedexFlag`/`GetPokedexFlagAndOrder` type functions in
   `src/pokedex.c`). Read the real accessor functions to confirm exactly
   how the bit-per-species indexing works (national dex # → byte/bit
   offset), don't invent your own indexing scheme. `src/core/
   DexTracker.lua`: a tested bit-array model with get/set/isOwned/
   isSeen, built on the real indexing formula.
2. **Bag**: real FireRed's bag is split into real pockets (items,
   key items, balls, TMs/HMs, berries — check
   `include/constants/items.h` / `src/item.c`'s real pocket
   constants/capacity limits, e.g. `BAG_ITEMS_COUNT` and similar real
   `#define`s — don't guess capacity numbers). `src/core/Bag.lua`: a
   tested model of pocket-bounded itemId+quantity slots, with real
   pocket-assignment lookup (`gItems[itemId].pocket` — `Item.lua` from
   Phase 1 already decodes item records; check whether the pocket field
   is already exposed or needs adding).
3. **Money**: real FireRed stores money as a real encrypted/XORed value
   in the save block with a real max cap (`MAX_MONEY`, check
   `include/constants/pokemon.h`/`include/global.h` for the real
   constant — commonly seen as 999999 but confirm from source, don't
   assume). `src/core/Money.lua`: a tested wrapper enforcing the real
   cap on add/subtract, with the encryption note documented (actual
   encrypt/decrypt XOR-with-security-key is real save-block behavior;
   whether you implement the XOR here or just document it as save-I/O's
   job later is your call — state which you did clearly).
4. **PC box stub**: real FireRed has 14 boxes x 30 slots each (confirm
   `TOTAL_BOXES_COUNT`/`IN_BOX_COUNT` real constants from
   `include/constants/pokemon.h`, don't hardcode without checking).
   `src/core/PcBoxes.lua`: modeled the same lightweight way as
   `PartyModel.lua`, storing `BoxPokemonCodec`-shaped entries, with
   add/get/removeAt/iterate per box. This is explicitly a "shape and
   bounds are real, don't invent capacity numbers" task, not a UI or
   box-scrolling-animation task.

### Explicitly out of scope

- No actual save-file read/write (SRAM emulation, checksums) for any of
  these four systems — that's the save-block handoff's territory
  (`FireRed/save-block-handoff.md`, check its status before assuming
  it's landed or still open).
- No UI (bag screen, PC screen, dex screen rendering) — pure data model
  only.
- No item *effects* (using a Potion, a TM teaching a move) — just the
  bag as a bounded inventory container. Effects are separate systems
  this project hasn't built anywhere yet.

## Conventions to follow

- Every module's header comment cites the real struct/constant/function
  and source file, and states exactly what was verified/transcribed —
  see `import/PokedexOrder.lua` (Phase 1) for house style on citing real
  header constants precisely.
- Tests: plain-Lua unit tests, no ROM needed for most of this (compile-
  time constants and struct shape, not ROM-byte decoding) — same
  pattern as the save-block handoff's expected test shape. Run the full
  suite before finishing:
  ```
  cd "/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp"
  for f in tests/*.lua; do lua5.1 "$f" || echo "FAILED: $f"; done
  ```
- **Don't commit anything** — leave changes in the working tree.
- Update the checklist's party-model line for what you actually
  finished, in the existing entry style — be precise about which real
  constants you transcribed vs. anything you had to infer.

## Deliverable

A summary of what real structs/functions/constants you read for each of
the four systems, what you modeled, what's directly transcribed from
real source vs. inferred, what's explicitly left out, and the file list
touched.
