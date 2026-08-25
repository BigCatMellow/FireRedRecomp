# FireRed ReComp — Audio Playback Task (independent, parallel-safe)

## Context you need

This project (`/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp/`)
is a **recomp** of Pokémon FireRed: not an emulator, not a from-scratch
game. We're porting the real decompiled C source
(`/home/mellow/Documents/Projects/Pokemon ReComp/Disassembled_Games/Classic/pokefirered-master/`,
a community reverse-engineering project that reproduces a byte-identical
ROM when compiled) into Lua/LÖVE2D by hand, while pulling every real
asset (sprites, maps, text, audio) directly out of a verified real ROM
file at load time. **Nothing is placeholder, hand-drawn, or approximated
— every module must be verified against real ROM bytes**, and every
doc comment must say exactly what was verified and how.

The verified ROM is at:
`/home/mellow/Documents/Projects/Pokemon ReComp/FireRed/pokefirered-master/pokefirered.gba`
(SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`, FireRed US v1.0).

A second copy at `/home/mellow/Documents/Projects/Pokemon ReComp/FireRed/Pokemon - FireRed Version (USA, Europe) (Rev 1)/...gba`
also exists but is a **different revision** — always use the
`pokefirered-master/pokefirered.gba` one, and confirm via
`import/RomImporter.lua`'s `verify()` before trusting any address.

The checklist tracking the whole project is at
`/home/mellow/Documents/Projects/Pokemon ReComp/docs/handoffs/firered-recomp-checklist.md`
(NOT inside the git repo — edit it directly, it's a plain file). Look at
Phase 2's "Audio mixer (music, SFX, cries, loops, fades)" line and
Phase 8 for where this task fits.

## What NOT to touch (another agent is actively editing these)

Someone else is finishing Phase 2 rendering work concurrently in:
- `main.lua`
- `import/TitleScreen.lua`

**Do not edit either of those files.** Everything you build should live
in new files. If you want something wired into `main.lua` as a visible
demo, either (a) build a **fully standalone** LÖVE2D mini-project under
`tools/audio_playground/` with its own `main.lua`/`conf.lua` that
`require`s the real project's `import/`/`src/core/` modules via a
relative `package.path`, so it never touches the real `main.lua`, or
(b) just leave your modules tested and documented, and note in your
final summary exactly what a one-line `main.lua` wiring snippet would
look like, for the other agent to merge in later.

You're free to create/edit anything under `import/*.lua`, `src/core/*.lua`,
`tests/*.lua`, and `import/RomAddresses.lua` (just add new entries,
don't touch existing ones).

## The task: real GBA audio playback (DirectSound instruments)

FireRed's real audio engine is "M4A" / Sappy, a GBA-standard MIDI-like
sequencer + software synthesizer. Fully emulating it (the real mixer is
hand-written ARM assembly, `src/m4a_1.s`) is out of scope. **Scope this
down to: decode and play real PCM sample data directly**, which covers
Pokémon cries and most sound effects without needing a synthesizer.

### Why this works: the real struct is dead simple

`include/gba/m4a_internal.h` in the decomp:

```c
struct WaveData
{
    u16 type;
    u16 status;
    u32 freq;       // fixed-point; real sample rate = freq / 1024
    u32 loopStart;
    u32 size;       // number of samples
    s8 data[1];     // signed 8-bit PCM samples follow immediately
};

struct ToneData    // aka "instrument" — this project already has
{                   // CryTable.lua decoding this exact struct
    u8 type;
    u8 key;
    u8 length;
    u8 pan_sweep;
    struct WaveData *wav;
    u8 attack, decay, sustain, release;
};
```

This project's `import/CryTable.lua` already decodes `ToneData` (real,
tested, verified — see its header comment) and gives you a `wavPtr`
(a raw ROM address, e.g. `0x08510C50` — NOT pre-subtracted, since it's
decoded straight out of ROM bytes as a real pointer value; subtract
`0x08000000` yourself to get a file offset). `import/SongTable.lua`
similarly decodes `struct Song[]` (`gSongTable`), each entry pointing at
a `voicegroup` (an array of `ToneData`, one per MIDI-style instrument
slot) plus a compressed MIDI-like event stream — **you do not need the
event stream for this task**, just individual `ToneData`/`WaveData`
playback.

**Already independently verified** (during scoping for this handoff,
2026-08-12): decoding `gCryTable` entry 1 (a real Pokémon cry) gives
`type=32`, `key=60`, and a `wavPtr` whose `WaveData` decodes to
`freq=10764288` (→ 10512 Hz, a standard real GBA sample rate),
`size=8187` samples, and real-looking signed-8-bit waveform data (not
zeros/garbage). This confirms the approach is sound — you're not
starting from an unverified guess.

### Suggested scope, in order

1. **`import/WaveData.lua`** — decode a real `struct WaveData` given a
   ROM offset: `type`, `status`, `freq` (both raw and the real Hz via
   `/1024`), `loopStart`, `size`, and the raw PCM sample bytes
   (`data:sub(...)`, `size` bytes starting right after the 16-byte
   header). Convert each signed-8-bit sample (range -128..127) to a
   normalized float (-1.0..1.0) for love.audio, or keep raw and convert
   at the love.audio boundary — your call, document the choice.
   Follow the existing file-header-comment convention (see
   `import/CryTable.lua` or `import/Lz77.lua` for the house style: cite
   the real struct, the real field offsets, and what was verified
   against real ROM data).

2. **Real-ROM integration test** (`tests/wave_data_test.lua`, following
   the existing `POKEPORT_ROM` opt-in pattern every other
   `tests/*_test.lua` file uses — copy the skip-if-unset boilerplate
   from any existing test like `tests/font_test.lua`): decode a few real
   cries' `WaveData` via `CryTable` + your new module, assert sane
   `freq`/`size` values and that the sample data isn't all-zero/all-one-
   value (a cheap "this isn't garbage" check, same spirit as this
   project's other tests).

3. **`src/core/AudioPlayer.lua`** (or similar name) — given a decoded
   `WaveData`, build a `love.sound.SoundData` (16-bit PCM, love.audio's
   native format) at the real sample rate, resampling/upsampling your
   8-bit signed samples into it, and return a `love.audio.Source` ready
   to `:play()`. Support looping via `loopStart` (real GBA instruments
   loop from `loopStart` to `size` when `status` indicates a looping
   sample — check the real usage in `src/m4a.c` for how `status` is
   interpreted, don't guess). This module can't be tested with plain
   `lua5.1` (no `love.sound` outside LÖVE) — that's fine, keep it thin
   and push all the testable logic (WaveData decode, resampling math)
   into plain-Lua-testable helper functions it calls.

4. **Verification**: build the standalone `tools/audio_playground/`
   LÖVE2D mini-project mentioned above. It should verify the ROM (reuse
   `import/RomImporter.lua`), decode a real cry's `WaveData` via
   `CryTable` + your `WaveData.lua`, build a `Source` via `AudioPlayer.lua`,
   and play it on a keypress. Confirm **by actually running it** (`love
   tools/audio_playground` from the repo root, or wherever you set it
   up) that you hear a real Pokémon-cry-like sound, not silence or
   noise. If you can't personally verify audio output, at minimum
   confirm no errors and that `SoundData`/`Source` construction
   succeeds, and clearly flag in your summary that audio output itself
   is unverified by ear.

### Explicitly out of scope for this task (leave for later)

- CGB (square wave / noise) channel synthesis — only DirectSound (PCM)
  instruments. Check a `ToneData.type` byte's low bits against
  `TONEDATA_TYPE_CGB` (`0x07`, `include/gba/m4a_internal.h`) if you want
  to detect and skip/report these rather than mis-decode them as PCM.
- The real MIDI-like event sequencer (playing full songs/music tracks)
  — that's a much bigger separate task (real Sappy event-byte
  interpreter). This task is single-sample/one-shot playback only
  (cries, SFX).
- ADSR envelope (attack/decay/sustain/release) shaping — `ToneData` has
  the fields, but implementing real envelope timing is a nice-to-have,
  not required for this task. Note it as a follow-up if you skip it.
- Wiring into the real game's task/scene system (`PlaySE`/`PlayCry`
  equivalents) — that depends on `src/core/TaskScheduler.lua` and
  scene state this project doesn't have a clean hook for yet. Just get
  raw playback working and tested.

## Conventions to follow (established across this whole project)

- **Every `import/*.lua` module's header comment** must cite the real C
  struct/source file it's decoding and state exactly what was verified
  against real ROM data (not just "should be correct"). Look at
  `import/CryTable.lua`, `import/Font.lua`, or `import/SpriteAnim.lua`
  for the house style before writing yours.
- **RomAddresses.lua**: this project's ROM data table addresses live in
  `import/RomAddresses.lua`, keyed by the ROM's SHA-1. If you need a new
  symbol's real address, find it via
  `arm-none-eabi-nm pokefirered.elf | grep <name>` — the toolchain is at
  `/home/mellow/toolchains/arm-gnu-toolchain-13.2.Rel1-x86_64-arm-none-eabi/bin`
  and the built ELF is at
  `/home/mellow/Documents/Projects/Pokemon ReComp/FireRed/pokefirered-master/pokefirered.elf`.
  Static/local C symbols won't be in the linker `.map` file — `nm` finds
  them anyway. Addresses in `RomAddresses.lua` are stored **pre-subtracted**
  (`0x08xxxxxx - 0x08000000`) to match every module's `resolve(data,
  offset, ...)` convention — but raw pointers *decoded out of ROM data
  itself* (like `CryTable`'s `wavPtr`) stay as full addresses; you
  subtract `0x08000000` yourself when using them. Don't mix these two
  conventions up — it's a recurring bug class in this project's history.
- **Tests**: plain-Lua unit tests run always (`lua5.1 tests/foo_test.lua`);
  ROM-integration tests check `POKEPORT_ROM` and skip cleanly if unset
  (copy the boilerplate from any existing `tests/*_test.lua`). Run the
  *entire* suite before considering anything done:
  ```
  cd "/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp"
  ROMPATH="/home/mellow/Documents/Projects/Pokemon ReComp/FireRed/pokefirered-master/pokefirered.gba"
  for f in tests/*.lua; do POKEPORT_ROM="$ROMPATH" lua5.1 "$f" || echo "FAILED: $f"; done
  ```
- **No `bit` library / Lua 5.3 bitwise operators anywhere** — this
  project runs under both LuaJIT (LÖVE) and plain Lua 5.1 (the test
  harness), neither of which reliably has the same bitwise-op story, so
  every module does bit extraction via pure arithmetic
  (`math.floor`/`%`). Follow this pattern — see `import/Lz77.lua`'s
  header comment for the exact rationale, or `import/SpriteAnim.lua`
  for a recent example decoding packed bitfields this way.
- **After editing `main.lua`** (only relevant if you build the
  standalone `tools/audio_playground/main.lua`, which is a *different*
  file but follows the same LÖVE2D conventions): sanity-check it loads
  with `lua5.1 -e "assert(loadfile('tools/audio_playground/main.lua'))"`.
  This project hit a real Lua 60-upvalue-per-function limit bug
  recently that the test suite didn't catch (tests never load
  `main.lua`-shaped files) — cheap to check, don't skip it.
- **Don't commit anything.** Leave changes staged/unstaged in the
  working tree; the user reviews and commits.
- **Update the checklist** (`firered-recomp-checklist.md`) and, if you
  have persistent memory in this environment, a project-memory note —
  but only for what you actually finished and verified, matching this
  project's existing checklist-entry style (see how other Phase 2 items
  are written: `[x]`/`[~]` with a one-paragraph justification citing
  what was verified).

## Deliverable

When done (or when you've made solid, honestly-scoped progress and are
stopping): a short summary of exactly what was built, what was verified
and how (including whether you personally confirmed audible playback),
what's explicitly left out-of-scope, and the file list touched. Don't
overstate confidence — if something is unverified, say so plainly.
