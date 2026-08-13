-- Turns a decoded import/WaveData.lua table (a real GBA `struct WaveData` --
-- raw 8-bit signed PCM, see that module's header for the struct/verification
-- details) into a playable love.audio.Source. This is DirectSound-instrument
-- (PCM sample) playback only -- covers Pokemon cries and most SFX. Explicitly
-- NOT implemented here (see firered-recomp-checklist.md / handoff doc):
--   * the real M4A/Sappy MIDI-like event sequencer (full songs) -- one-shot
--     single-sample playback only.
--   * CGB (square/noise) channel synthesis -- ToneData.type low bits ==
--     TONEDATA_TYPE_CGB (0x07) samples are not PCM and are NOT handled here;
--     see AudioPlayer.isCgbTone().
--   * ADSR envelope (attack/decay/sustain/release) shaping -- ToneData has
--     the fields but no envelope timing is applied; playback is flat volume.
--
-- Needs love.sound/love.audio, so this can't run under plain lua5.1 (no
-- ROM-integration test for this file). All the math that CAN be tested
-- without love is pushed into import/WaveData.toFloatSamples() (see
-- tests/wave_data_test.lua) -- this module just wires that into love's API.
--
-- Loop support: GBA WaveData loops from `loopStart` sample index to `size`
-- (see import/WaveData.lua header for how `looping`/`loopStart` were
-- derived from real src/m4a_1.s asm, not guessed). love.audio's
-- Source:setLooping(true) only loops the ENTIRE buffer from sample 0, not
-- from an arbitrary loopStart offset -- love has no native mid-buffer loop
-- point. For loopStart == 0 (loop the whole sample) this is exact. For
-- loopStart > 0 this module approximates by looping the whole buffer
-- anyway (documented limitation, not silently wrong): the sample's intro
-- portion (before loopStart) will replay on every loop instead of being
-- skipped after the first pass. A precise fix needs queueable-source
-- stitching (play intro once, then loop just the tail) and is left as a
-- follow-up -- see AudioPlayer.build()'s returned `preciseLoopUnsupported`
-- flag.

local WaveData = require("import.WaveData")

local AudioPlayer = {}

local TONEDATA_TYPE_CGB = 0x07 -- pokefirered include/gba/m4a_internal.h

-- toneType: the `type` byte from a decoded ToneData (import/CryTable.lua).
-- Real m4a_1.s checks this low-nibble-ish value to route CGB vs DirectSound
-- channels; low 3 bits == TONEDATA_TYPE_CGB (0x07) means "not a PCM sample",
-- per the header comment above. Out of scope for this module to play.
function AudioPlayer.isCgbTone(toneType)
  return (toneType % 8) == TONEDATA_TYPE_CGB
end

-- Builds a love.sound.SoundData (16-bit PCM, mono) from a decoded WaveData
-- table (import/WaveData.lua's .resolve() output). Pure love.sound call,
-- no love.audio Source yet -- split out so callers/tests can construct one
-- without needing an audio device.
function AudioPlayer.buildSoundData(wav)
  assert(love and love.sound, "AudioPlayer.buildSoundData requires love.sound (run inside LOVE2D)")
  assert(wav.size > 0, "WaveData has zero samples")

  local rate = math.floor(wav.sampleRateHz + 0.5)
  local soundData = love.sound.newSoundData(wav.size, rate, 16, 1)

  local floats = WaveData.toFloatSamples(wav.samples)
  for i = 1, wav.size do
    -- love.sound.SoundData:setSample is 0-indexed; it accepts a normalized
    -- float and quantizes to the SoundData's own bit depth (16-bit here),
    -- which is the "upsample 8-bit -> 16-bit" step -- love does the actual
    -- integer requantization, we just hand it the true normalized value.
    soundData:setSample(i - 1, floats[i] or 0)
  end

  return soundData
end

-- Builds a ready-to-:play() love.audio.Source from a decoded WaveData
-- table. Returns (source, meta) where meta.preciseLoopUnsupported is true
-- iff wav.looping and wav.loopStart > 0 (see module header re: love.audio's
-- loop limitation).
function AudioPlayer.build(wav)
  assert(love and love.audio, "AudioPlayer.build requires love.audio (run inside LOVE2D)")

  local soundData = AudioPlayer.buildSoundData(wav)
  local source = love.audio.newSource(soundData)

  local meta = { preciseLoopUnsupported = false }
  if wav.looping then
    source:setLooping(true)
    if wav.loopStart and wav.loopStart > 0 then
      meta.preciseLoopUnsupported = true
    end
  end

  return source, meta
end

return AudioPlayer
