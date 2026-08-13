-- Plain-Lua unit test (no ROM needed) for import/SongEvents.lua's byte
-- decoder, using synthetic streams built to exercise the real M4A command
-- encoding traced in that module's header comment (src/m4a_1.s MPlayMain
-- / ply_note / ply_endtie, src/m4a.c ply_xcmd, src/m4a_tables.c
-- gClockTable / gXcmdTable). tests/song_events_test.lua covers the real
-- ROM integration path; this covers the decoder logic itself in
-- isolation.
--
-- Run: lua5.1 tests/song_events_unit_test.lua
package.path = package.path .. ";./?.lua"
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

-- 1) A single explicit note (0xD3 = TIE(0xCF)+4 -> gateTime base
--    gClockTable[4]=4) with key=60, velocity=100, no extra gate byte
--    (next byte is FINE, >=0x80, so gate-time stays at the table value),
--    then FINE.
do
  local stream = string.char(0xD3, 60, 100, 0xB1)
  local events = SongEvents.decodeTrack(stream, 0)
  check("note+FINE: 2 events", #events == 2, #events)
  check("note: key=60 velocity=100 gateTime=4 not tied", events[1].type == "note"
    and events[1].key == 60 and events[1].velocity == 100 and events[1].gateTime == 4 and events[1].tie == false)
  check("terminates with end (FINE)", events[2].type == "end" and not events[2].dummy)
end

-- 2) TIE (0xCF) with no args (immediately followed by FINE) -- tie=true,
--    gateTime = gClockTable[0] = 0.
do
  local stream = string.char(0xCF, 0xB1)
  local events = SongEvents.decodeTrack(stream, 0)
  check("bare TIE decodes as tie=true, gateTime=0", events[1].type == "note" and events[1].tie == true and events[1].gateTime == 0)
end

-- 3) Running status: ply_note always consumes up to 3 optional bytes
--    (key, velocity, extra-gate) while they're <0x80, so a clean
--    running-status boundary between two notes requires the first note
--    to consume exactly 3 -- then the next <0x80 byte re-dispatches
--    MPlayMain's TIE running-status as a second, separate note command
--    with no repeated command byte (real MIDI-style running status).
do
  local stream = string.char(0xCF, 60, 100, 10, 40, 90, 20, 0xB1)
  local events = SongEvents.decodeTrack(stream, 0)
  check("running status: 3 events (2 notes + end)", #events == 3, #events)
  check("first note key=60 vel=100 gateTime=0+10", events[1].key == 60 and events[1].velocity == 100 and events[1].gateTime == 10)
  check("running-status note key=40 vel=90 gateTime=0+20", events[2].type == "note" and events[2].key == 40 and events[2].velocity == 90 and events[2].gateTime == 20)
end

-- 4) Rest command: 0x88 = 0x80 + 8 -> gClockTable[8] = 8.
do
  local stream = string.char(0x88, 0xB1)
  local events = SongEvents.decodeTrack(stream, 0)
  check("rest 0x88 decodes to duration 8", events[1].type == "rest" and events[1].duration == 8)
end

-- 5) TEMPO control command doubles its argument into bpm (real ply_tempo:
--    tempoD = arg * 2).
do
  local stream = string.char(0xBB, 75, 0xB1) -- TEMPO 75 -> bpm 150
  local events = SongEvents.decodeTrack(stream, 0)
  check("TEMPO 75 -> bpm 150", events[1].type == "control" and events[1].name == "tempo" and events[1].bpm == 150)
end

-- 6) PAN is signed-centered on C_V (0x40): raw 0x40 -> signedValue 0,
--    raw 0x70 -> signedValue 48 (real ply_pan: subs r3, C_V).
do
  local stream = string.char(0xBF, 0x40, 0xBF, 0x70, 0xB1)
  local events = SongEvents.decodeTrack(stream, 0)
  check("PAN 0x40 -> signedValue 0", events[1].name == "pan" and events[1].signedValue == 0)
  check("PAN 0x70 -> signedValue 48", events[2].name == "pan" and events[2].signedValue == 48)
end

-- 7) XCMD sub-op dispatch: xiecv (sub=8, 1 byte) and xwave (sub=1, 4
--    bytes LE), per the real gXcmdTable arg widths.
do
  local stream = string.char(0xCD, 0x08, 0x2A, 0xCD, 0x01, 0x01, 0x02, 0x03, 0x04, 0xB1)
  local events = SongEvents.decodeTrack(stream, 0)
  check("XCMD xiecv: value=0x2A", events[1].type == "control" and events[1].name == "xiecv" and events[1].value == 0x2A)
  check("XCMD xwave: 4-byte LE value", events[2].name == "xwave" and events[2].value == 0x04030201, events[2].value)
end

-- 8) XCMD sub-op 0 (xxx) ends the track (calls ply_fine in the real
--    engine) instead of continuing to read further bytes.
do
  local stream = string.char(0xCD, 0x00, 0xAA, 0xAA) -- trailing bytes should never be reached
  local events = SongEvents.decodeTrack(stream, 0)
  check("XCMD sub 0 (xxx) produces a single end event", #events == 1 and events[1].type == "end" and events[1].via == "xcmd/xxx")
end

-- 9) GOTO: real 4-byte little-endian absolute pointer target, decode
--    stops there (does not follow it).
do
  local stream = string.char(0xB2, 0x00, 0xD0, 0x86, 0x08, 0xAA) -- target = 0x0886D000, trailing byte unreached
  local events = SongEvents.decodeTrack(stream, 0)
  check("GOTO: 1 event with the real target address", #events == 1 and events[1].type == "goto" and events[1].target == 0x0886D000)
end

-- 10) An unimplemented control-flow command (PATT) stops decoding
--     cleanly and is reported, rather than misreading its 4-byte target
--     as something else.
do
  local stream = string.char(0xB3, 0x00, 0x00, 0x00, 0x08, 0xAA)
  local events = SongEvents.decodeTrack(stream, 0)
  check("PATT reported as unimplemented, decode stops", #events == 1 and events[1].type == "unimplemented" and events[1].name == "patt")
end

-- 11) decodeSong: a synthetic 2-track SongHeader (trackCount=2,
--     blockCount/priority/reverb arbitrary, tone ptr arbitrary, then two
--     part[] pointers) at romBase, each track's stream placed later in
--     the buffer.
do
  local romBase = SongEvents.romBase
  local function u32le(n)
    return string.char(n % 256, math.floor(n / 256) % 256, math.floor(n / 65536) % 256, math.floor(n / 16777216) % 256)
  end
  local track0 = string.char(0xCF, 60, 100, 0xB1) -- 4 bytes
  local track1 = string.char(0x88, 0xB1) -- 2 bytes

  local track0Addr = romBase + 0x100
  local track1Addr = romBase + 0x200
  local header = string.char(2, 0, 5, 0) .. u32le(romBase + 0x50) .. u32le(track0Addr) .. u32le(track1Addr)

  local buf = header
  buf = buf .. string.rep("\0", 0x100 - #buf) .. track0
  buf = buf .. string.rep("\0", 0x200 - #buf) .. track1

  local decoded = SongEvents.decodeSong(buf, romBase)
  check("decodeSong: trackCount=2", decoded.trackCount == 2)
  check("decodeSong: priority=5", decoded.priority == 5)
  check("decodeSong: track 1 ptr matches", decoded.tracks[1].ptr == track0Addr)
  check("decodeSong: track 2 ptr matches", decoded.tracks[2].ptr == track1Addr)
  check("decodeSong: track 1 decodes note+end", decoded.tracks[1].events[1].type == "note" and decoded.tracks[1].events[2].type == "end")
  check("decodeSong: track 2 decodes rest+end", decoded.tracks[2].events[1].type == "rest" and decoded.tracks[2].events[2].type == "end")
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
