-- Integration test for the actual love.audio playback wiring
-- (src/core/SongAudio.lua): plays a real song out of a real ROM through
-- SongTable -> SongEvents -> SongPlayer -> SongAudio, in simulated real
-- time, against a stub love API that records every SoundData/Source call.
--
-- This is how playback is verified without an audio device -- and, in the
-- environment this was written in, without a LOVE2D install at all: it
-- proves the right number of Sources are created, with the right pitch,
-- volume, looping and stereo placement, started and stopped at the right
-- wall-clock times, with none left hanging. What it CANNOT prove is what
-- the result sounds like; that is unconfirmed by ear.
--
-- Run: POKEPORT_ROM=/path/to/pokefirered.gba lua5.1 tests/song_audio_test.lua
package.path = package.path .. ";./?.lua"

local romPath = os.getenv("POKEPORT_ROM")
if not romPath then
  print("SKIP: set POKEPORT_ROM=/path/to/verified/pokefirered.gba to run this test")
  os.exit(0)
end

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local SongTable = require("import.SongTable")
local SongEvents = require("import.SongEvents")
local SongPlayer = require("src.core.SongPlayer")
local SongAudio = require("src.core.SongAudio")
local AudioPlayer = require("src.core.AudioPlayer")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- ---------------------------------------------------------------------
-- Stub love API. Implements exactly the surface AudioPlayer/SongAudio use
-- (love.sound.newSoundData, love.audio.newSource + the Source setters), and
-- records everything for assertions.
-- ---------------------------------------------------------------------
local clock = 0 -- simulated seconds, advanced by the driver loop below
local sources = {}

local function newStubSoundData(sampleCount, rate, bits, channels)
  return {
    _sampleCount = sampleCount,
    _rate = rate,
    _bits = bits,
    _channels = channels,
    _samples = {},
    setSample = function(self, i, v) self._samples[i] = v end,
    getSampleCount = function(self) return self._sampleCount end,
  }
end

local stubLove = {
  sound = { newSoundData = newStubSoundData },
  audio = {
    newSource = function(soundData)
      local src = {
        soundData = soundData,
        pitch = 1,
        volume = 1,
        looping = false,
        relative = false,
        position = nil,
        playedAt = nil,
        stoppedAt = nil,
        playCount = 0,
      }
      function src:setPitch(p) self.pitch = p end
      function src:setVolume(v) self.volume = v end
      function src:setLooping(l) self.looping = l end
      function src:setRelative(r) self.relative = r end
      function src:setPosition(x, y, z) self.position = { x, y, z } end
      function src:play() self.playedAt = clock; self.playCount = self.playCount + 1 end
      function src:stop() self.stoppedAt = clock end
      sources[#sources + 1] = src
      return src
    end,
  },
}

-- ---------------------------------------------------------------------
local ok, info = RomImporter.verify(romPath)
check("ROM verifies", ok == true, info)
if not ok then
  print(("%d passed, %d failed"):format(passed, failed))
  os.exit(1)
end

local file = io.open(romPath, "rb")
local data = file:read("*a")
file:close()
local addrs = RomAddresses[RomImporter._sha1HexOfFile(romPath)]

local MUS_LEVEL_UP = 257
local song = SongTable.resolve(data, addrs.gSongTable, MUS_LEVEL_UP)
local decoded = SongEvents.decodeSong(data, song.headerPtr)

-- Reference timeline (offline, independent of the real-time driver below).
local reference = SongPlayer.new(decoded):renderTimeline()
local expectedOns, expectedSeconds = 0, {}
for _, e in ipairs(reference.events) do
  if e.type == "noteOn" then
    expectedOns = expectedOns + 1
    expectedSeconds[e.noteId] = e.seconds
  end
end

-- Real-time playback: 60 Hz host frames through SongPlayer:update(dt), the
-- exact path tools/audio_playground/main.lua uses.
local player = SongPlayer.new(decoded)
local audio = SongAudio.new({ romData = data, tonePtr = decoded.tonePtr, love = stubLove })

local DT = 1 / 60
local peakActive, guard = 0, 0
local startedAt = {}
while not player:isFinished() and guard < 10000 do
  guard = guard + 1
  clock = clock + DT
  local events = player:update(DT)
  for _, e in ipairs(events) do
    if e.type == "noteOn" then startedAt[e.noteId] = clock end
  end
  audio:handle(events)
  if audio:activeCount() > peakActive then peakActive = audio:activeCount() end
end

check("real-time driver finished the song", player:isFinished())
check("a Source was created for every scheduled note", #sources == expectedOns,
  ("%d sources / %d notes"):format(#sources, expectedOns))
check("SongAudio counted the same starts", audio.started == expectedOns, audio.started)
check("every started note was also stopped", audio.stopped == audio.started,
  ("%d started / %d stopped"):format(audio.started, audio.stopped))
check("nothing is left sounding at the end", audio:activeCount() == 0, audio:activeCount())
check("no note was dropped as an unsupported voice", audio.skipped == 0, audio.skipped)
check("all 5 tracks sound simultaneously at the peak", peakActive == 5, peakActive)

local allPlayed, allStopped, badOrder = true, true, 0
for _, src in ipairs(sources) do
  if src.playedAt == nil then allPlayed = false end
  if src.stoppedAt == nil then allStopped = false end
  if src.playedAt and src.stoppedAt and src.stoppedAt < src.playedAt then badOrder = badOrder + 1 end
  if src.playCount ~= 1 then badOrder = badOrder + 1 end
end
check("every Source was play()ed exactly once", allPlayed and badOrder == 0, badOrder)
check("every Source was stop()ped", allStopped)

-- Timing: the real-time driver must start each note at the same wall-clock
-- second the offline timeline predicts, within one host frame of quantization.
local worstDrift = 0
for noteId, t in pairs(startedAt) do
  local drift = math.abs(t - expectedSeconds[noteId])
  if drift > worstDrift then worstDrift = drift end
end
check("real-time note starts match the offline timeline within a frame",
  worstDrift <= DT + 1e-9, worstDrift)

-- Per-Source audio parameters. Voice 46 is the DirectSound sample (3345 Hz,
-- looping); voices 84/85 are CGB squares synthesized at a 441 Hz reference.
local pcmSources, squareSources, volumesSane = 0, 0, true
local squareReference = AudioPlayer.SQUARE_SAMPLE_RATE / AudioPlayer.SQUARE_PERIOD_SAMPLES
for _, src in ipairs(sources) do
  if src.volume < 0 or src.volume > 1 then volumesSane = false end
  if src.soundData._sampleCount == AudioPlayer.SQUARE_PERIOD_SAMPLES then
    squareSources = squareSources + 1
    -- Square sources are pitched from the 441 Hz reference to a real note
    -- frequency; MUS_LEVEL_UP's square parts sit between B4 and B5.
    local hz = src.pitch * squareReference
    if hz < 400 or hz > 1100 then volumesSane = false end
    if not src.looping then volumesSane = false end
  else
    pcmSources = pcmSources + 1
    -- Every PCM note in this song is above key 60, so it plays back faster
    -- than its recorded rate; nothing is beyond a few octaves.
    if src.pitch <= 1 or src.pitch > 8 then volumesSane = false end
  end
end
check("both DirectSound and CGB square Sources were built",
  pcmSources > 0 and squareSources > 0, ("%d pcm / %d square"):format(pcmSources, squareSources))
check("every Source got a sane pitch, volume and loop flag", volumesSane)

-- Stereo placement: this song pans its tracks hard left and hard right.
local anyLeft, anyRight = false, false
for _, src in ipairs(sources) do
  if src.position then
    if src.position[1] < -0.1 then anyLeft = true end
    if src.position[1] > 0.1 then anyRight = true end
  end
end
check("real PAN commands placed Sources on both sides", anyLeft and anyRight)

-- The DirectSound SoundData is built once per voice and reused for every
-- note of that voice (building it is per-sample work).
local pcmSampleCounts = {}
for _, src in ipairs(sources) do pcmSampleCounts[src.soundData] = true end
local distinctBuffers = 0
for _ in pairs(pcmSampleCounts) do distinctBuffers = distinctBuffers + 1 end
check("SoundData buffers are cached per voice, not rebuilt per note",
  distinctBuffers == 3, distinctBuffers)

print(("MUS_LEVEL_UP through SongAudio: %d Sources (%d PCM, %d square), peak %d simultaneous, "
  .. "worst start drift %.4f s -- structural only, not confirmed by ear")
  :format(#sources, pcmSources, squareSources, peakActive, worstDrift))
print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
