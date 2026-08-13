# Wiring real cry/SFX playback into `main.lua`

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
  `AudioPlayer.isCgbTone(toneType)` to detect non-PCM instruments you
  should skip rather than pass to `build()`.
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

- Full M4A/Sappy event sequencer (music playback) — one-shot sample
  playback only.
- CGB (square/noise) channel synthesis — `AudioPlayer.isCgbTone()` detects
  and lets you skip these; they are not decoded or played.
- ADSR envelope (attack/decay/sustain/release) timing — playback is flat
  volume; `ToneData` has the fields (`attack`/`decay`/`sustain`/`release`)
  if this gets picked up later.
- Precise mid-buffer loop points (see `meta.preciseLoopUnsupported` above).

## Reference/demo

`tools/audio_playground/` is a fully standalone LÖVE2D project (own
`main.lua`/`conf.lua`) exercising this exact flow — run `love
tools/audio_playground` from the repo root, press 1-5 to play 5 real
cries. Good source to diff against if the snippet above doesn't behave as
expected once merged.
