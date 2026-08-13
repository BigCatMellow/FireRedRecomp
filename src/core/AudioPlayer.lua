-- Turns a decoded import/WaveData.lua table (a real GBA `struct WaveData` --
-- raw 8-bit signed PCM, see that module's header for the struct/verification
-- details) into a playable love.audio.Source. This is the per-voice audio
-- back end: DirectSound (PCM sample) instruments, which covers Pokemon
-- cries, most SFX, and the sampled instruments of real songs, plus a
-- minimal CGB square-wave synth (see buildSquareSoundData) for the two
-- hardware square channels real music leans on. Scheduling notes over time
-- is src/core/SongPlayer.lua. Explicitly NOT implemented here (see
-- firered-recomp-checklist.md / handoff doc):
--   * CGB channel 3 (programmable wave, 32 4-bit samples in WAVE_RAM) and
--     channel 4 (noise, gNoiseTable) synthesis -- only the two square
--     channels are synthesized; see AudioPlayer.cgbChannel().
--   * ADSR envelope (attack/decay/sustain/release) shaping -- ToneData has
--     the fields but no envelope timing is applied; playback is flat volume.
--     For CGB squares the real hardware envelope (NRx2 step time/direction)
--     is likewise not modelled.
--
-- Needs love.sound/love.audio, so it can't run against the real LOVE2D API
-- under plain lua5.1. All the math that CAN be tested standalone is pushed
-- into import/WaveData.toFloatSamples() (tests/wave_data_test.lua) and
-- src/core/SongPlayer.lua (tests/song_player_unit_test.lua); the wiring
-- itself is covered by tests/song_audio_test.lua, which injects a stub love
-- API through every builder's optional trailing `loveApi` argument.
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

-- Every builder below takes an optional trailing `loveApi` so callers can
-- inject a stand-in for the global `love` (see src/core/SongAudio.lua and
-- tests/song_audio_test.lua -- that is how the playback wiring is verified
-- in an environment with no LOVE2D install). Defaults to the real global.
local function loveOf(loveApi)
  local api = loveApi or love
  assert(api and api.sound and api.audio,
    "AudioPlayer needs love.sound/love.audio (run inside LOVE2D, or inject a stub)")
  return api
end

local TONEDATA_TYPE_CGB = 0x07 -- pokefirered include/gba/m4a_internal.h

-- toneType: the `type` byte from a decoded ToneData (import/CryTable.lua
-- decodes the struct; it is the same struct in gCryTable and in a song's
-- voicegroup). TONEDATA_TYPE_CGB is a MASK, not a value: real ply_note
-- (src/m4a_1.s _081DDBA6) does `movs r6, TONEDATA_TYPE_CGB; ands r6, r0` and
-- treats the *result* as the CGB hardware channel number, routing to
-- gCgbChans[result - 1] when it is nonzero. So:
--   type & 7 == 0 -> DirectSound (a real PCM sample; ToneData.wav is a
--                    struct WaveData *)
--   type & 7 == 1 -> CGB square 1, 2 -> CGB square 2 (ToneData.wav is not a
--                    pointer at all but the 2-bit duty cycle written to
--                    NR11/NR21 bits 6-7, src/m4a.c:1001)
--   type & 7 == 3 -> CGB programmable wave, 4 -> CGB noise
-- Returns 0 for DirectSound, 1-4 for a CGB channel.
function AudioPlayer.cgbChannel(toneType)
  return toneType % (TONEDATA_TYPE_CGB + 1)
end

-- True iff this instrument is played on a CGB hardware channel rather than
-- as a PCM sample -- i.e. do NOT hand it to build()/buildSoundData().
-- (This used to test `== 0x07`, which is wrong: 7 is the mask, not a channel
-- number, and no real tone has channel 7. Real cries are type 0x20 -> & 7
-- == 0, so cry playback is unaffected by the fix, but real song voicegroups
-- do use channels 1-4 -- e.g. MUS_LEVEL_UP's voices 84/85.)
function AudioPlayer.isCgbTone(toneType)
  return AudioPlayer.cgbChannel(toneType) ~= 0
end

-- Builds a love.sound.SoundData (16-bit PCM, mono) from a decoded WaveData
-- table (import/WaveData.lua's .resolve() output). Pure love.sound call,
-- no love.audio Source yet -- split out so callers/tests can construct one
-- without needing an audio device.
function AudioPlayer.buildSoundData(wav, loveApi)
  local api = loveOf(loveApi)
  assert(wav.size > 0, "WaveData has zero samples")

  local rate = math.floor(wav.sampleRateHz + 0.5)
  local soundData = api.sound.newSoundData(wav.size, rate, 16, 1)

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

-- Real GBA square-channel duty codes: the 2-bit value written to NR11/NR21
-- bits 6-7 (src/m4a.c:1001, `*nrx1ptr = (wavePointer << 6) + length`), which
-- for a CGB square instrument is what ToneData.wav holds instead of a
-- WaveData pointer. Values are the fraction of each period spent high.
AudioPlayer.SQUARE_DUTIES = { [0] = 0.125, [1] = 0.25, [2] = 0.5, [3] = 0.75 }

-- 100 samples per period puts every real duty edge (12.5/25/50/75%) on an
-- exact sample boundary, so the synthesized waveform has the true duty
-- rather than a rounded one. 44100/100 = a 441 Hz reference pitch.
AudioPlayer.SQUARE_SAMPLE_RATE = 44100
AudioPlayer.SQUARE_PERIOD_SAMPLES = 100

-- One period of a square wave at the given duty, as a looping
-- love.sound.SoundData. Play it back through Source:setPitch() to reach the
-- note's real frequency (src/core/SongPlayer.cgbFreqHz gives that in Hz):
-- the returned meta.frequencyHz is this buffer's own pitch, so the ratio is
-- targetHz / meta.frequencyHz.
--
-- This is a plain naive square (no band limiting), so it is brighter/more
-- aliased than the real hardware channel, and it has no NRx2 envelope or
-- sweep -- a deliberate minimal stand-in for the two square channels, not a
-- full CGB emulation. Returns (soundData, meta).
function AudioPlayer.buildSquareSoundData(dutyCode, loveApi)
  local api = loveOf(loveApi)
  local duty = AudioPlayer.SQUARE_DUTIES[dutyCode or 2] or 0.5
  local sampleRate = AudioPlayer.SQUARE_SAMPLE_RATE
  local periodSamples = AudioPlayer.SQUARE_PERIOD_SAMPLES

  local soundData = api.sound.newSoundData(periodSamples, sampleRate, 16, 1)
  local highSamples = math.floor(periodSamples * duty + 0.5)
  for i = 0, periodSamples - 1 do
    soundData:setSample(i, i < highSamples and 1.0 or -1.0)
  end

  return soundData, { duty = duty, frequencyHz = sampleRate / periodSamples }
end

-- Builds a looping love.audio.Source for a CGB square note. targetHz is the
-- real note frequency (SongPlayer.cgbFreqHz). Returns (source, meta).
function AudioPlayer.buildSquareSource(dutyCode, targetHz, loveApi)
  local api = loveOf(loveApi)
  local soundData, meta = AudioPlayer.buildSquareSoundData(dutyCode, api)
  local source = api.audio.newSource(soundData)
  source:setLooping(true)
  source:setPitch(targetHz / meta.frequencyHz)
  meta.targetHz = targetHz
  return source, meta
end

-- Builds a ready-to-:play() love.audio.Source from a decoded WaveData
-- table. Returns (source, meta) where meta.preciseLoopUnsupported is true
-- iff wav.looping and wav.loopStart > 0 (see module header re: love.audio's
-- loop limitation).
function AudioPlayer.build(wav, loveApi)
  local api = loveOf(loveApi)

  local soundData = AudioPlayer.buildSoundData(wav, api)
  local source = api.audio.newSource(soundData)

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
