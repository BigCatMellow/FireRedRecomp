-- The audio back end for src/core/SongPlayer.lua: turns the scheduler's
-- noteOn/noteOff events into real love.audio Sources, one per sounding
-- note, with the real per-note pitch and volume applied.
--
-- Split out of tools/audio_playground/main.lua so the wiring itself is
-- testable: the love API is injected (opts.love, defaulting to the global
-- `love`), so tests/song_audio_test.lua drives this exact code path against
-- a stub that records every newSource/setPitch/setVolume/play/stop call.
-- That is how "the right sources start at the right times" is verified in
-- an environment with no audio device -- and, in this one, no LOVE2D
-- install at all.
--
-- Voice resolution (real `struct ToneData`, include/gba/m4a_internal.h):
-- a song's SongHeader.tone points at its voicegroup, a flat ToneData[]
-- indexed by the VOICE command's argument. That is byte-for-byte the same
-- struct gCryTable holds, so import/CryTable.lua's resolve() is reused as
-- the generic ToneData decoder rather than duplicating it here.
--   * DirectSound voice (type & 7 == 0): ToneData.wav is a real
--     `struct WaveData *`; import/WaveData.lua decodes it and
--     AudioPlayer.buildSoundData turns it into PCM. The note's pitch is
--     applied as a playback-rate ratio (Source:setPitch) computed by
--     SongPlayer.pitchRatio -- exactly the real MidiKeyToFreq result over
--     the sample's own recorded rate.
--   * CGB square voice (type & 7 == 1 or 2): ToneData.wav is the 2-bit duty
--     code, and AudioPlayer.buildSquareSoundData synthesizes one period,
--     pitched to SongPlayer.cgbFreqHz(key).
--   * CGB wave (3) / noise (4): not synthesized -- the note is counted in
--     `skipped` and silently dropped (documented gap, see AudioPlayer.lua).
--
-- Documented simplifications (same house style as AudioPlayer.lua):
--   * Volume: the real engine mixes independent 0-255 left/right channel
--     volumes (SongPlayer.channelVolumes). love.audio has no per-source
--     L/R gain for a mono Source, so this sets Source:setVolume to the
--     mean of the two divided by 255 and approximates the stereo placement
--     with love's positional audio (setRelative + setPosition on the X
--     axis). Both numbers are still carried on the event if a future mixer
--     wants to do it properly.
--   * No ADSR envelope and no LFO -- see SongPlayer.lua's gap list.
--   * No channel stealing: every scheduled note gets its own Source, where
--     real hardware has a fixed channel pool.

local CryTable = require("import.CryTable")
local WaveData = require("import.WaveData")
local AudioPlayer = require("src.core.AudioPlayer")
local SongPlayer = require("src.core.SongPlayer")

local SongAudio = {}
SongAudio.__index = SongAudio

local ROM_BASE = 0x08000000

-- Real GBA channel volumes are 0-255 per side (the clamp in ChnVolSetAsm).
SongAudio.VOLUME_FULL_SCALE = 255

-- opts.romData: full ROM bytes. opts.tonePtr: the decoded song's raw
-- voicegroup pointer (SongEvents.decodeSong(...).tonePtr). opts.love: the
-- love API table (defaults to the global `love`).
function SongAudio.new(opts)
  local self = setmetatable({}, SongAudio)
  self.romData = assert(opts.romData, "SongAudio needs romData")
  self.tonePtr = assert(opts.tonePtr, "SongAudio needs the song's tonePtr")
  self.love = opts.love or love
  assert(self.love and self.love.audio and self.love.sound,
    "SongAudio needs love.audio/love.sound (or an injected stub)")
  self.voices = {}   -- voice number -> resolved instrument (cached)
  self.playing = {}  -- noteId -> { source =, event = }
  self.started = 0
  self.stopped = 0
  self.skipped = 0
  return self
end

-- Resolves (and caches) one voicegroup slot into something playable.
-- Returns a table { kind = "pcm"|"square"|"unsupported", tone =, ... }.
function SongAudio:voice(voiceNumber)
  local cached = self.voices[voiceNumber]
  if cached then return cached end

  local tone = CryTable.resolve(self.romData, self.tonePtr - ROM_BASE, voiceNumber)
  local channel = AudioPlayer.cgbChannel(tone.type)
  local entry = { tone = tone, cgbChannel = channel }

  if channel == 0 then
    entry.kind = "pcm"
    entry.wav = WaveData.resolve(self.romData, tone.wavPtr - ROM_BASE)
    entry.soundData = AudioPlayer.buildSoundData(entry.wav, self.love)
  elseif channel == 1 or channel == 2 then
    entry.kind = "square"
    -- ToneData.wav is the duty code for a square voice, not a pointer.
    entry.dutyCode = tone.wavPtr % 4
    entry.soundData, entry.squareMeta = AudioPlayer.buildSquareSoundData(entry.dutyCode, self.love)
  else
    entry.kind = "unsupported" -- CGB wave (3) / noise (4)
  end

  self.voices[voiceNumber] = entry
  return entry
end

-- Starts one scheduled note (a SongPlayer noteOn event).
function SongAudio:noteOn(event)
  local voice = self:voice(event.voice)
  if voice.kind == "unsupported" then
    self.skipped = self.skipped + 1
    return nil
  end

  local source = self.love.audio.newSource(voice.soundData)

  if voice.kind == "pcm" then
    source:setPitch(SongPlayer.pitchRatio(voice.wav.freq, event.effectiveKey, event.fineAdjust))
    -- Real WaveData loop flag; see AudioPlayer.lua's header for love's
    -- whole-buffer-only loop limitation.
    if voice.wav.looping then source:setLooping(true) end
  else
    local hz = SongPlayer.cgbFreqHz(event.effectiveKey, event.fineAdjust)
    if not hz then
      self.skipped = self.skipped + 1
      return nil
    end
    source:setPitch(hz / voice.squareMeta.frequencyHz)
    source:setLooping(true)
  end

  local mean = (event.volumeLeft + event.volumeRight) / 2
  source:setVolume(mean / SongAudio.VOLUME_FULL_SCALE)
  -- Approximate stereo placement (see header): PAN is signed -64..+63.
  if source.setRelative and source.setPosition then
    local x = event.pan / 64
    if x < -1 then x = -1 elseif x > 1 then x = 1 end
    source:setRelative(true)
    source:setPosition(x, 0, 0)
  end

  source:play()
  self.playing[event.noteId] = { source = source, event = event }
  self.started = self.started + 1
  return source
end

-- Releases one scheduled note (a SongPlayer noteOff event).
function SongAudio:noteOff(event)
  local entry = self.playing[event.noteId]
  if not entry then return end
  entry.source:stop()
  self.playing[event.noteId] = nil
  self.stopped = self.stopped + 1
end

-- Applies a whole batch of SongPlayer events (the list :update()/:step()
-- returns), in order.
function SongAudio:handle(events)
  for _, e in ipairs(events) do
    if e.type == "noteOn" then
      self:noteOn(e)
    elseif e.type == "noteOff" then
      self:noteOff(e)
    end
  end
end

function SongAudio:activeCount()
  local n = 0
  for _ in pairs(self.playing) do n = n + 1 end
  return n
end

function SongAudio:stopAll()
  for id, entry in pairs(self.playing) do
    entry.source:stop()
    self.playing[id] = nil
  end
end

return SongAudio
