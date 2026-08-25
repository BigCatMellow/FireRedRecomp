# FireRed ReComp — M4A/Sappy Song Sequencer Playback Task (independent, parallel-safe)

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
(plain file, not in the git repo — edit directly). Look under Phase 2's
"Audio mixer (music, SFX, cries, loops, fades) — **partial**" line.

## No speaker in this environment — read this first

The last two audio tasks in this project (raw PCM playback, song event
decode) both hit "no speaker in this sandbox" — audio correctness was
verified structurally (construction succeeds, no errors, decoded values
are sane against real source) rather than confirmed by ear. **This is
fine and expected; don't block on it.** Verify everything you can
structurally/numerically and say clearly in your summary what's
unconfirmed-by-ear vs. structurally verified. If a real speaker/audio
device happens to be available in your environment, confirming by ear
is a nice bonus, not a requirement.

## What NOT to touch

Do not edit `main.lua`. Build/extend in `import/`, `src/core/`, and
`tests/`, plus `tools/audio_playground/` if useful for manual testing
(it's already a standalone LÖVE2D project separate from the main game,
safe to extend). Note what `main.lua` wiring would look like in your
summary.

## Background: what's already built

- `import/WaveData.lua` decodes real `struct WaveData` (raw PCM sample
  headers pointed to by `CryTable`/`SongTable`'s `ToneData.wav`) and
  `src/core/AudioPlayer.lua` builds a `love.audio.Source` from one —
  this is **one-shot raw sample playback only** (a single cry/SFX
  sample), not a sequencer.
- `import/SongEvents.lua` **structurally decodes** (no playback) the
  real M4A/Sappy song event byte stream — notes/TIE, rests, FINE/GOTO/
  EOT, track-control commands (TEMPO/VOICE/VOL/PAN/BEND/etc.), and
  `XCMD` sub-dispatch. Verified against real `MUS_LEVEL_UP` (5 tracks,
  all terminate cleanly). Explicitly NOT implemented there: PATT, PEND,
  REPT, MEMACC, PORT (real control-flow/RAM-state commands that don't
  fit a linear byte decode) — these are "documented gaps," not silently
  skipped; check `import/SongEvents.lua`'s header for the exact list.
- `import/SongTable.lua`/`import/CryTable.lua` resolve the real
  pointer tables (`gSongTable`/`gCryTable`) this all hangs off of.

The gap: nothing turns a decoded `SongEvents` event list into actual
scheduled, multi-track, timed audio output. That's this task.

## The task

1. **Read the real M4A player loop**: `src/m4a_1.s`'s `MPlayMain` (you
   already have a head start — `SongEvents.lua`'s header comment cites
   exactly which real functions/tables it traced for the byte-format
   decode; now you need the *playback timing* side: `gClockTable` (real
   duration-in-frames per note-length code), how `ply_note`/`ply_endtie`
   turn a decoded note event into an actual sounding voice, and how the
   real player advances multiple tracks in lockstep on a shared clock).
2. **Design a testable scheduler** (pure Lua, no love2d coupling in the
   core logic — same pattern as `TaskScheduler.lua`/`PlayerMovement.lua`):
   given a decoded `SongEvents` event list (one per track) and a
   real-tick clock, advance each track's read position, and emit
   "start this note now" / "stop this note now" events at the correct
   real tick. `src/core/SongPlayer.lua` (or similar name — your call).
3. **Voice synthesis is the hard real constraint**: real FireRed music
   is NOT simple WAV playback per note — `ToneData` entries can be
   DirectSound (real PCM samples, pitch-shifted per note — `WaveData.lua`
   already handles the sample decode, you need the per-note pitch-shift
   math, real `m4a_1.s` frequency formula) or CGB (square/noise
   synthesis, which `AudioPlayer.isCgbTone` already detects-and-skips —
   check whether CGB tones appear in whatever song you test against
   before deciding if synthesizing them is in scope; if they don't,
   documenting the gap and moving on is fine, don't build a full CGB
   synth speculatively).
4. **Wire actual love.audio playback** for at least ONE real song,
   through `tools/audio_playground/` (not `main.lua`) — confirm sources
   get created/started for the correct notes at roughly the correct
   times (checkable via `love.audio` source count/timing introspection
   even without hearing it).
5. **ADSR envelope / precise loop points**: real games use ADSR volume
   envelopes and the real M4A player's own loop semantics
   (`WaveData.lua`'s header already documents `love.audio` only
   supporting whole-buffer looping as a known gap). Flat-volume playback
   without ADSR is an acceptable documented simplification (this
   project already made that exact call for cries) — don't block on it,
   just document it clearly like `WaveData.lua`/`AudioPlayer.lua` do.

### Explicitly out of scope

- PATT/PEND/REPT/MEMACC/PORT command support (documented gaps in
  `SongEvents.lua` already — extending the decoder is a bigger separate
  task; if a song you pick hits one of these, pick a different song or
  truncate playback there and say so).
- CGB channel synthesis, unless the song you verify against actually
  needs it and it turns out to be a quick win — check first.
- Full ADSR envelope timing (flat volume is fine, document it).
- `main.lua` wiring (see above).
- Don't try to cover every real song — get ONE real song playing
  correctly (or as correctly as structurally verifiable) end to end,
  and document what generalizes vs. what's song-specific.

## Conventions to follow

- Every module's header comment cites the real struct/function/source
  file (`m4a_1.s`, `m4a.c`, `m4a_tables.c`) and states exactly what was
  verified/ground-truthed, matching `import/SongEvents.lua`'s existing
  house style for this exact subsystem.
- No `bit` library / Lua 5.3 bitwise operators (LuaJIT + plain Lua 5.1
  compatibility).
- Tests: plain-Lua unit tests always run; ROM-integration tests check
  `POKEPORT_ROM` and skip cleanly if unset. Run the full suite before
  finishing:
  ```
  cd "/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp"
  ROMPATH="/home/mellow/Documents/Projects/Pokemon ReComp/FireRed/pokefirered-master/pokefirered.gba"
  for f in tests/*.lua; do POKEPORT_ROM="$ROMPATH" lua5.1 "$f" || echo "FAILED: $f"; done
  ```
- **Don't commit anything** — leave changes in the working tree.
- Update the checklist's audio-mixer line for what you actually
  finished/verified.

## Deliverable

Which real song you verified against, what the scheduler does and how
its timing was ground-truthed, how voice synthesis works (DirectSound
pitch-shift math, CGB handling/skip), what's structurally verified vs.
confirmed by ear (call out explicitly if you had no speaker), what's
explicitly left out (PATT/PEND/etc., ADSR, CGB), and the file list
touched.
