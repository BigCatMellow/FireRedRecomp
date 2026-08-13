-- Integration test: schedules a real song out of a real FireRed(US) v1.0
-- ROM end to end -- SongTable -> SongEvents (byte decode) -> SongPlayer
-- (tick clock + note scheduling + real pitch/volume math) -- and checks the
-- resulting timeline against facts that can be verified independently of
-- the code under test:
--   * the CGB square channels' computed frequencies must land on real
--     equal-tempered note pitches (A440), to within the GBA's own 11-bit
--     rate-register resolution;
--   * the DirectSound sample's pitch ratios must be 2^((key-60)/12);
--   * every note must be released exactly gateTime ticks after it starts;
--   * a musical duration identity: 24 ticks == one quarter note at the
--     song's own TEMPO.
-- Opt-in, skips cleanly without a ROM -- same pattern as the other
-- ROM-integration tests.
--
-- Run: POKEPORT_ROM=/path/to/pokefirered.gba lua5.1 tests/song_player_test.lua
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
local CryTable = require("import.CryTable")
local WaveData = require("import.WaveData")
local SongPlayer = require("src.core.SongPlayer")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

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
check("RomAddresses has an entry for this ROM", addrs ~= nil)

-- MUS_LEVEL_UP (include/constants/songs.h id 257) -- the same short fanfare
-- import/SongEvents.lua was ground-truthed against. 5 tracks: three play the
-- DirectSound instrument (voice 46) and two the CGB square channels
-- (voices 84/85), so one song exercises both synthesis paths.
local MUS_LEVEL_UP = 257

local song = SongTable.resolve(data, addrs.gSongTable, MUS_LEVEL_UP)
local decoded = SongEvents.decodeSong(data, song.headerPtr)
check("MUS_LEVEL_UP decodes to 5 tracks", decoded.trackCount == 5, decoded.trackCount)

local player = SongPlayer.new(decoded)
local timeline = player:renderTimeline()

check("the whole song terminates (no tick cap hit)", not timeline.hitTickCap)
check("every track ended cleanly (FINE), none truncated/unimplemented", (function()
  for _, t in ipairs(player.tracks) do
    if t.stopReason ~= "end" then return false, t.stopReason end
  end
  return true
end)())
check("the song's TEMPO was applied (87 -> tempoD 174)", player.tempoD == 174, player.tempoD)

-- A short fanfare: a second or so, tens of scheduled events. These bounds
-- are deliberately loose -- they catch "the clock is off by an order of
-- magnitude", not musical nuance.
check("song length is a plausible fanfare duration (0.5-3 s)",
  timeline.seconds > 0.5 and timeline.seconds < 3.0, timeline.seconds)
check("scheduled a plausible number of events", #timeline.events > 20 and #timeline.events < 500,
  #timeline.events)

-- 24 ticks is one quarter note; at the song's own tempo that must equal
-- 60/bpm seconds (scaled by the real 59.7275 Hz VBlank the engine runs on).
local quarter = 24 * player:secondsPerTick()
local nominal = 60 / player.tempoD
check("24 ticks is one quarter note at the song's tempo",
  math.abs(quarter - nominal) / nominal < 0.01, ("%.4f vs %.4f"):format(quarter, nominal))

-- Note bookkeeping: every noteOn is matched by exactly one noteOff, and the
-- gap is exactly the note's gate time (real MPlayMain ages gateTime once per
-- tick and stops the channel when it reaches 0).
local open, ons, offs, badGate = {}, 0, 0, 0
local firstTick, tracksSounding = nil, {}
for _, e in ipairs(timeline.events) do
  if e.type == "noteOn" then
    ons = ons + 1
    open[e.noteId] = e
    firstTick = firstTick or e.tick
    if e.tick == firstTick then tracksSounding[e.track] = true end
  else
    offs = offs + 1
    local on = open[e.noteId]
    if on then
      if e.tick - on.tick ~= on.gateTime then badGate = badGate + 1 end
      open[e.noteId] = nil
    end
  end
end
check("every note that started was released", ons == offs and next(open) == nil,
  ("%d on / %d off"):format(ons, offs))
check("every note lasted exactly its gate time", badGate == 0, badGate)
check("all 5 tracks attack together on the song's first beat", (function()
  local n = 0
  for _ in pairs(tracksSounding) do n = n + 1 end
  return n == 5, n
end)())

-- Per-voice synthesis checks. Every note's computed pitch is compared to
-- the equal-tempered frequency of its MIDI key (A440), which is an
-- independent ground truth -- neither table nor formula under test.
local function equalTemperedHz(key)
  return 440 * 2 ^ ((key - 69) / 12)
end

local voicesSeen, cgbNotes, pcmNotes = {}, 0, 0
local worstCgbCents, worstPcmCents = 0, 0
local anyPannedLeft, anyPannedRight, volumesInRange = false, false, true

for _, e in ipairs(timeline.events) do
  if e.type == "noteOn" then
    local tone = CryTable.resolve(data, decoded.tonePtr - SongEvents.romBase, e.voice)
    voicesSeen[e.voice] = tone
    local cgbChannel = tone.type % 8

    if e.volumeLeft < 0 or e.volumeLeft > 255 or e.volumeRight < 0 or e.volumeRight > 255 then
      volumesInRange = false
    end
    if e.pan < 0 then anyPannedLeft = true elseif e.pan > 0 then anyPannedRight = true end

    if cgbChannel == 0 then
      pcmNotes = pcmNotes + 1
      local wav = WaveData.resolve(data, tone.wavPtr - SongEvents.romBase)
      local ratio = SongPlayer.pitchRatio(wav.freq, e.effectiveKey, e.fineAdjust)
      local expected = 2 ^ ((e.effectiveKey - 60) / 12)
      local cents = math.abs(1200 * math.log(ratio / expected) / math.log(2))
      if cents > worstPcmCents then worstPcmCents = cents end
    else
      cgbNotes = cgbNotes + 1
      local hz = SongPlayer.cgbFreqHz(e.effectiveKey, e.fineAdjust)
      local cents = math.abs(1200 * math.log(hz / equalTemperedHz(e.effectiveKey)) / math.log(2))
      if cents > worstCgbCents then worstCgbCents = cents end
    end
  end
end

check("both synthesis paths are exercised by this one song", pcmNotes > 0 and cgbNotes > 0,
  ("%d PCM / %d CGB"):format(pcmNotes, cgbNotes))
check("voice 46 is the DirectSound (PCM) instrument",
  voicesSeen[46] and voicesSeen[46].type % 8 == 0, voicesSeen[46] and voicesSeen[46].type)
check("voice 84 is CGB square channel 2",
  voicesSeen[84] and voicesSeen[84].type % 8 == 2, voicesSeen[84] and voicesSeen[84].type)
check("voice 85 is CGB square channel 1",
  voicesSeen[85] and voicesSeen[85].type % 8 == 1, voicesSeen[85] and voicesSeen[85].type)
-- 5 cents is inaudible; the GBA's 11-bit CGB rate register cannot do better
-- than a couple of cents at these pitches, and the DirectSound path only
-- loses the engine's own integer-Hz truncation.
check("every CGB square note lands on its real note pitch (<5 cents)", worstCgbCents < 5, worstCgbCents)
check("every DirectSound note is equal-tempered off key 60 (<5 cents)", worstPcmCents < 5, worstPcmCents)

check("channel volumes stay in the real 0-255 range", volumesInRange)
check("the song's real PAN commands produce both left and right placement",
  anyPannedLeft and anyPannedRight)

-- The DirectSound instrument this song uses is a real looping sample, so
-- it exercises AudioPlayer's documented whole-buffer-loop limitation.
do
  local wav = WaveData.resolve(data, voicesSeen[46].wavPtr - SongEvents.romBase)
  check("voice 46's sample decodes to a sane rate/size",
    wav.sampleRateHz > 1000 and wav.sampleRateHz < 50000 and wav.size > 0,
    ("%.0f Hz, %d samples"):format(wav.sampleRateHz, wav.size))
  check("voice 46's sample is a mid-buffer looping sample (loopStart > 0)",
    wav.looping and wav.loopStart > 0, ("looping=%s loopStart=%d"):format(tostring(wav.looping), wav.loopStart))
end

print(("MUS_LEVEL_UP: %d ticks / %d frames / %.3f s, %d notes (%d PCM, %d CGB), "
  .. "worst pitch error %.2f cents (PCM) / %.2f cents (CGB)")
  :format(timeline.ticks, timeline.frames, timeline.seconds, ons, pcmNotes, cgbNotes,
    worstPcmCents, worstCgbCents))
print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
