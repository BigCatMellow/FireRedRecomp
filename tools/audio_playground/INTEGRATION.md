# Wiring real cry/SFX/music playback into `main.lua`

Written for whoever owns `main.lua` / `import/TitleScreen.lua` — this task
built and verified the modules below but deliberately never touched either
file (they were being edited concurrently). Nothing here has been applied
to `main.lua`; it's just instructions + a working reference
(`tools/audio_playground/main.lua`) to copy from.

## What exists, ready to use

- `import/WaveData.lua` — decodes a real `struct WaveData` (GBA m4a sound
  engine PCM sample header) given a ROM byte offset. Returns
  `{ type, status, freq, sampleRateHz, loopStart, size, looping, samples }`.
- `src/core/AudioPlayer.lua` — turns a decoded `WaveData` into a
  `love.audio.Source` via `AudioPlayer.build(wav)`. Also has
  `AudioPlayer.cgbChannel(toneType)` (0 = DirectSound/PCM, 1-4 = CGB
  hardware channel) and `AudioPlayer.isCgbTone(toneType)` to detect
  non-PCM instruments you should skip rather than pass to `build()`, plus
  `AudioPlayer.buildSquareSoundData(duty)` for the CGB square channels.
  Every builder takes an optional trailing `loveApi` argument so a stub
  can be injected in tests.
- `src/core/SongPlayer.lua` — the real M4A/Sappy playback scheduler (pure
  Lua, no love): tick clock, per-track command advance, note gate-time
  release, and the real `MidiKeyToFreq` / `MidiKeyToCgbFreq` /
  `TrkVolPitSet` / `ChnVolSetAsm` pitch and volume math.
- `src/core/SongAudio.lua` — the love.audio back end for those scheduled
  events: resolves each VOICE to a real `ToneData`, builds/caches its
  buffer, and starts/stops one `Source` per sounding note.
- Both are covered by `tests/wave_data_test.lua` (unit + real-ROM
  integration checks) and manually run end-to-end in
  `tools/audio_playground/main.lua` (headless LÖVE run: ROM verifies, 5
  real cries decode, `Source` construction + `play()` succeed with no
  errors — audio output itself wasn't confirmed by ear, no speaker in that
  environment).

## Minimal wiring snippet

Given `romData` (full ROM bytes already loaded, as `main.lua` already does
for other importers) and `addrs` (the resolved `RomAddresses[sha1]` table):

```lua
local CryTable = require("import.CryTable")
local WaveData = require("import.WaveData")
local AudioPlayer = require("src.core.AudioPlayer")

-- cryId: gCryTable index (table position, not species id -- see
-- pokefirered src/data/pokemon/cry_ids.h for the species->cryId mapping).
local function playCry(cryId)
  local tone = CryTable.resolve(romData, addrs.gCryTable, cryId)
  if AudioPlayer.isCgbTone(tone.type) then
    return nil -- not a PCM sample, out of scope (see below)
  end
  local wav = WaveData.resolve(romData, tone.wavPtr - 0x08000000)
  local source, meta = AudioPlayer.build(wav)
  source:play()
  return source, meta
end
```

## Minimal music wiring snippet

```lua
local SongTable = require("import.SongTable")
local SongEvents = require("import.SongEvents")
local SongPlayer = require("src.core.SongPlayer")
local SongAudio = require("src.core.SongAudio")

local player, audio  -- keep these; nil means "nothing playing"

local function playSong(songId)          -- e.g. 257 = MUS_LEVEL_UP
  local entry = SongTable.resolve(romData, addrs.gSongTable, songId)
  local song = SongEvents.decodeSong(romData, entry.headerPtr)
  player = SongPlayer.new(song)
  audio = SongAudio.new({ romData = romData, tonePtr = song.tonePtr })
end

-- in love.update(dt):
if player then
  audio:handle(player:update(dt))       -- the entire playback loop
  if player:isFinished() and audio:activeCount() == 0 then
    player, audio = nil, nil
  end
end

-- to stop early: audio:stopAll(); player, audio = nil, nil
```

Notes on the music path:
- `SongPlayer:update(dt)` advances the real engine clock off wall-clock
  time (GBA VBlank rate, 59.7275 Hz) and returns this frame's
  `noteOn`/`noteOff` events; `SongAudio:handle()` is the only piece that
  touches `love.audio`. If `main.lua` ever gets a fixed-timestep loop,
  `SongPlayer:updateFrame()` is the one-VBlank version.
- Decoding + `SongAudio.new` do the per-sample buffer work lazily on the
  first note of each voice. For BGM you switch to often, keep the decoded
  song and the `SongAudio` around rather than rebuilding them.
- Looping BGM does not loop yet: `import/SongEvents.lua` stops decoding at
  the real `GOTO` loop point, so a song plays once through and ends. Short
  fanfares/jingles (which end in `FINE`) are complete.
- Only DirectSound and the two CGB *square* channels sound. CGB wave/noise
  notes are counted in `audio.skipped` and dropped, so percussion-heavy
  tracks will be missing parts.

Notes:
- `tone.wavPtr` is a raw ROM pointer decoded straight out of ROM bytes
  (e.g. `0x08510C50`) — subtract `0x08000000` yourself to get the file
  offset. This is NOT the same convention as `RomAddresses.lua`'s
  pre-subtracted table addresses; don't mix them up.
- Building a `Source` does real per-sample work (`AudioPlayer.buildSoundData`
  loops over every sample calling `SoundData:setSample`) — for an 8000-ish
  sample cry that's cheap, but don't call `playCry()` every frame. Cache
  the built `Source` per cry id if you'll replay it (e.g. a
  `cryId -> Source` table), and call `:stop(); :play()` on the cached
  source to replay it, same as `tools/audio_playground/main.lua` does.
- `meta.preciseLoopUnsupported` is `true` when the sample loops from a
  nonzero `loopStart` — `love.audio` can only loop an entire buffer from
  sample 0, so in that case `AudioPlayer.build()` still calls
  `source:setLooping(true)` but the intro before `loopStart` will
  incorrectly replay on every loop. None of the cries checked so far
  (`tests/wave_data_test.lua`) actually loop, so this path is unexercised
  against real looping data — treat it as untested if you hit it.
- For SFX (not cries), the same pattern applies once you resolve a
  `ToneData` from a voicegroup via `SongTable.lua` instead of `CryTable.lua`
  — `SongTable.lua` already decodes voicegroups (arrays of `ToneData`, one
  per instrument slot); this task didn't wire that path up but the
  `ToneData -> WaveData -> AudioPlayer` chain is identical.

## Explicitly not done (see checklist / handoff doc for full detail)

- Song loop points (`GOTO`) and the `PATT`/`PEND`/`REPT`/`MEMACC`/`PORT`
  commands — `import/SongEvents.lua` stops decoding at those, so a track
  ends there instead of looping/branching.
- CGB channel 3 (programmable wave) and channel 4 (noise) synthesis — only
  the two square channels are synthesized; `AudioPlayer.cgbChannel()`
  identifies which is which.
- ADSR envelope (attack/decay/sustain/release) timing — playback is flat
  volume; `ToneData` has the fields (`attack`/`decay`/`sustain`/`release`)
  if this gets picked up later. Likewise no LFO/vibrato, no pseudo-echo,
  no reverb, and no channel stealing/priority.
- True per-source stereo: the real engine mixes independent 0-255 left and
  right volumes; `SongAudio` sets one `Source:setVolume` (their mean) and
  approximates the placement with `setRelative`/`setPosition`.
- Precise mid-buffer loop points (see `meta.preciseLoopUnsupported` above).

## Reference/demo

`tools/audio_playground/` is a fully standalone LÖVE2D project (own
`main.lua`/`conf.lua`) exercising both flows — run `love
tools/audio_playground` from the repo root, press 1-5 to play 5 real
cries, S to play MUS_LEVEL_UP, X to stop it. It prints a live
tick/elapsed/live-Source/notes-started readout while the song plays. Good
source to diff against if the snippets above don't behave as expected once
merged.

Note on verification: the environment this music work was written in had
no LÖVE2D install and no audio device, so the playground itself was never
executed. The playback wiring is instead covered headlessly by
`tests/song_audio_test.lua`, which drives the *same* `SongPlayer` +
`SongAudio` code path against a stub `love` API and asserts the Sources,
pitches, volumes, loop flags and start/stop times. Nothing here has been
confirmed by ear — if you can run it with a speaker, that is the one
outstanding check.
