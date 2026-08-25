# FireRed ReComp — Song Event Stream Decode Task (independent, parallel-safe)

## Context you need

This project (`/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp/`)
is a **recomp** of Pokémon FireRed: real decompiled C source
(`/home/mellow/Documents/Projects/Pokemon ReComp/Disassembled_Games/Classic/pokefirered-master/`)
ported by hand into Lua/LÖVE2D, pulling every asset directly out of a
verified real ROM at load time. Nothing is placeholder — every module is
verified against real ROM bytes, documented in its header comment.

Verified ROM:
`/home/mellow/Documents/Projects/Pokemon ReComp/FireRed/pokefirered-master/pokefirered.gba`
(SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`).

Checklist: `/home/mellow/Documents/Projects/Pokemon ReComp/docs/handoffs/firered-recomp-checklist.md`
(plain file, not in the git repo — edit directly). Look at the "Audio
mixer (music, SFX, cries, loops, fades)" line — a prior handoff already
completed real DirectSound (PCM) sample playback
(`import/WaveData.lua`, `src/core/AudioPlayer.lua`,
`tools/audio_playground/` — read that code before starting, it's your
foundation and shows the established conventions for this exact
subsystem). This task is the natural next piece: **structurally decode**
the real MIDI-like event stream a `struct Song` points to — extraction
only, not playback/synthesis.

## What NOT to touch

Someone else is actively editing `main.lua` and `import/TitleScreen.lua`
concurrently. **Do not edit either file.** Also don't edit
`import/WaveData.lua` or `src/core/AudioPlayer.lua` unless you're
confident it won't conflict — prefer adding new files that `require`
them. Add new `RomAddresses.lua` entries freely (don't touch existing
ones).

## Background: what's already built

- `import/CryTable.lua` / `import/SongTable.lua` decode `struct
  ToneData[]` / `struct Song[]` headers (real, tested).
- `import/WaveData.lua` decodes the actual PCM sample data a `ToneData`
  points to, and `src/core/AudioPlayer.lua` plays it back via
  `love.audio`. This covers **individual instrument samples**, not
  songs.
- A real `struct Song` (`include/gba/m4a_internal.h` — check the exact
  field names, don't guess) points at a **compressed MIDI-like event
  byte stream** (the actual composition data — note-on/note-off/rest/
  tempo/etc. events) plus a `voicegroup` (array of `ToneData`
  instruments, one per MIDI channel/track). Nobody has decoded the
  event stream itself yet.

## The task: decode the event byte stream structurally (no playback)

This is explicitly **extraction only** — same spirit as Phase 1's
`MapScripts.lua` (raw script pointer/opcode extraction, no VM) or
`Charmap.tokenize` (structured tokens, not full text rendering). You are
building a **data model of what a song contains**, not making it play.

### Suggested scope

1. **Find the real event-byte format.** The M4A/Sappy event stream is a
   well-known, documented GBA format (a sequence of command bytes: note
   events encode pitch+velocity+duration, plus control events for
   tempo, volume, pan, track jumps/loops, etc.) — the authoritative
   reference is the real decompiled interpreter, `src/m4a.c` (look for
   the event-dispatch function, likely something like a big switch/jump
   table keyed on the command byte's high nibble or a `CMD_` constant
   table — grep `m4a.c` and `include/gba/m4a_internal.h` for constants
   starting with things like `CMD_` or note-related enums). Don't guess
   the opcode meanings — trace them from the real C source. This is the
   hardest part of the task; budget real research time for it before
   writing any decoder code.
2. **`import/SongEvents.lua`**: given a real `Song`'s event stream
   pointer (from `SongTable.lua`'s existing decode), walk the byte
   stream and produce a structured list of events — similar shape to
   `SpriteAnim.decodeCmds`'s output pattern (a flat list of typed
   tables, e.g. `{type="note", pitch=.., duration=..}`,
   `{type="rest", duration=..}`, `{type="tempo", bpm=..}`, etc.) rather
   than a flattened/opaque byte blob. You do not need to handle every
   possible command byte on day one — get the common ones (notes, rests,
   basic control commands) working and correctly tested, and clearly
   list which commands you encountered but didn't implement.
3. **Verify against a real, simple song** — pick something short and
   well-known in the ROM (a jingle/fanfare is easier to sanity-check
   than a full looping battle theme; check `include/constants/songs.h`
   or similar for real song ID names to pick a good candidate via
   `SongTable`). Decode its event stream and sanity-check the output
   isn't garbage: reasonable note pitch ranges, reasonable event count,
   the stream terminates (or loops) sensibly rather than running off
   into unrelated ROM data.
4. **Tests**: `tests/song_events_test.lua` (real-ROM integration,
   `POKEPORT_ROM` opt-in pattern — copy boilerplate from any existing
   `tests/*_test.lua`) decoding your chosen real song and asserting
   sane structural properties (event count in a plausible range, no
   crashes walking the whole stream, recognizable note/rest event
   types present).

### Explicitly out of scope

- No actual playback/sequencing (turning the decoded events into real
  audio timing + calling `AudioPlayer`) — that's a much bigger follow-up
  task (a real scheduler driving note-on/note-off through
  `TaskScheduler.lua`-style ticking). This task stops at "here is the
  song's structured event data."
- No tempo-accurate real-time interpretation — just decode the raw
  event list.
- Don't try to cover every exotic M4A command (there are quite a few
  obscure ones for pitch bends, LFO/vibrato, etc.) — get the core
  note/rest/tempo/track-control vocabulary working, document what's
  missing.

## Conventions to follow

- Every module's header comment cites the real struct/function/file and
  states exactly what was verified against real ROM data — see
  `import/SpriteAnim.lua` (a very similar "decode a real command byte
  stream into typed Lua tables" task) for the house style to match.
- `RomAddresses.lua`: real addresses via `arm-none-eabi-nm
  pokefirered.elf | grep <name>` (toolchain at
  `/home/mellow/toolchains/arm-gnu-toolchain-13.2.Rel1-x86_64-arm-none-eabi/bin`,
  ELF at `.../pokefirered-master/pokefirered.elf`). Addresses stored
  pre-subtracted (`0x08xxxxxx - 0x08000000`); raw pointers decoded out
  of ROM bytes themselves stay as full addresses — don't mix these two
  conventions up.
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
  existing entry style (the "Audio mixer" line already has a `[~]`
  partial entry from the DirectSound work — extend it, don't overwrite
  what's there).

## Deliverable

A summary of what real command byte format you traced (cite the real
function/file you derived it from), what event types you implemented vs.
skipped, which real song you verified against and what the decoded
output looked like structurally, and the file list touched.
