-- Parses FireRed's gSongTable (struct Song[], pokefirered
-- include/gba/m4a_internal.h) -- extraction only. ms/me are the m4a sound
-- engine's track-count fields (music tracks / sfx tracks used); actually
-- playing the sequence data is Phase 2/8 work.
--
-- Verified against real ROM data: entries 0-2 decode to exactly
-- {ms=0,me=0}, {ms=1,me=1}, {ms=1,me=1} -- an exact match for
-- sound/song_table.inc's `song mus_dummy, 0, 0` / `song se_use_item, 1, 1`
-- / `song se_pc_login, 1, 1` declarations, in the same order.
--
-- Struct layout (8 bytes, no padding -- ends on a 4-byte boundary):
--   0x00 header  u32 LE pointer (raw -- struct SongHeader*, sequence data)
--   0x04 ms        u16 LE
--   0x06 me        u16 LE
local SongTable = {}

SongTable.romBase = 0x08000000
SongTable.RECORD_SIZE = 8

local byte = string.byte

local function u16le(data, offset0based)
  return byte(data, offset0based + 1) + byte(data, offset0based + 2) * 256
end

local function u32le(data, offset0based)
  return byte(data, offset0based + 1)
    + byte(data, offset0based + 2) * 256
    + byte(data, offset0based + 3) * 65536
    + byte(data, offset0based + 4) * 16777216
end

-- data: full ROM bytes. tableOffset: 0-based file offset of gSongTable.
-- songId: a MUS_*/SE_* id.
function SongTable.resolve(data, tableOffset, songId)
  local base = tableOffset + songId * SongTable.RECORD_SIZE
  return {
    headerPtr = u32le(data, base + 0x00),
    ms = u16le(data, base + 0x04),
    me = u16le(data, base + 0x06),
  }
end

return SongTable
