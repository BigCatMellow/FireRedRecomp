-- Integration test: decodes a real song's M4A event byte stream out of a
-- real FireRed(US) v1.0 ROM (SongTable -> SongEvents) and checks the
-- output is structurally sane -- not that it matches exact hand-verified
-- byte-for-byte values (see import/SongEvents.lua's header comment for
-- how the command format itself was derived and verified). Opt-in,
-- skips cleanly without a ROM -- same pattern as the other
-- tests/*_integration_test.lua files.
--
-- Run: POKEPORT_ROM=/path/to/pokefirered.gba lua5.1 tests/song_events_test.lua
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

local sha1 = RomImporter._sha1HexOfFile(romPath)
local addrs = RomAddresses[sha1]
check("RomAddresses has an entry for this ROM", addrs ~= nil, sha1)

-- MUS_LEVEL_UP (include/constants/songs.h, id 257) -- a short, well-known
-- fanfare, ideal for sanity-checking a decoded event stream isn't garbage.
local MUS_LEVEL_UP = 257

local song = SongTable.resolve(data, addrs.gSongTable, MUS_LEVEL_UP)
check("MUS_LEVEL_UP has a plausible headerPtr (within ROM address space)",
  song.headerPtr >= 0x08000000 and song.headerPtr < 0x0A000000, song.headerPtr)

local decoded = SongEvents.decodeSong(data, song.headerPtr)

check("trackCount is plausible (1-16, real M4A max is small)",
  decoded.trackCount >= 1 and decoded.trackCount <= 16, decoded.trackCount)
check("decoded exactly trackCount tracks", #decoded.tracks == decoded.trackCount)

local totalNotes, totalRests, totalControls = 0, 0, 0
local minKey, maxKey = 128, -1
local anyTruncated, anyUnimplemented = false, false
local allEndCleanly = true

for i, track in ipairs(decoded.tracks) do
  check(("track %d decoded at least one event"):format(i), #track.events > 0)
  check(("track %d stayed under the MAX_EVENTS safety cap"):format(i),
    #track.events < SongEvents.MAX_EVENTS, #track.events)

  local last = track.events[#track.events]
  if last.type ~= "end" and last.type ~= "goto" then
    allEndCleanly = false
  end

  for _, e in ipairs(track.events) do
    if e.type == "note" then
      totalNotes = totalNotes + 1
      if e.key then
        check(("track %d note key in valid MIDI range 0-127"):format(i),
          e.key >= 0 and e.key <= 127, e.key)
        if e.key < minKey then minKey = e.key end
        if e.key > maxKey then maxKey = e.key end
      end
      if e.velocity then
        check(("track %d note velocity in valid MIDI range 0-127"):format(i),
          e.velocity >= 0 and e.velocity <= 127, e.velocity)
      end
    elseif e.type == "rest" then
      totalRests = totalRests + 1
    elseif e.type == "control" then
      totalControls = totalControls + 1
    elseif e.type == "truncated" then
      anyTruncated = true
    elseif e.type == "unimplemented" then
      anyUnimplemented = true
    end
  end
end

check("decoded a plausible total event count (not empty, not runaway)",
  totalNotes + totalRests + totalControls > 0
    and totalNotes + totalRests + totalControls < SongEvents.MAX_EVENTS * decoded.trackCount)
check("recognizable note events present", totalNotes > 0, totalNotes)
check("recognizable rest events present", totalRests > 0, totalRests)
check("recognizable control events present (tempo/voice/vol/etc)", totalControls > 0, totalControls)
check("decoded note pitches fall in a plausible musical range (not garbage)",
  minKey <= maxKey and minKey >= 0 and maxKey <= 127, ("min=%d max=%d"):format(minKey, maxKey))
check("no track hit the truncation/EOF-run-off case", not anyTruncated)
check("every track's stream terminates cleanly (FINE/dummy/XCMD-end or GOTO)", allEndCleanly)

-- A real short fanfare's tracks should end via FINE/dummy/xcmd-end, not
-- wander into an unimplemented command before finishing -- if this ever
-- flips true, it means the real data uses PATT/PEND/REPT/MEMACC/PORT and
-- the module's documented gap list needs revisiting.
check("no unimplemented commands encountered decoding this song", not anyUnimplemented)

print(("MUS_LEVEL_UP: %d tracks, %d notes, %d rests, %d control events, key range %d-%d")
  :format(decoded.trackCount, totalNotes, totalRests, totalControls, minKey, maxKey))
print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
