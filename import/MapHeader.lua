-- Resolves FireRed's map tables: gMapGroups (an array of per-group tables,
-- each holding pointers to struct MapHeader instances -- pokefirered
-- include/global.fieldmap.h / src/overworld.c) into a specific map's header
-- fields.
--
-- This is two levels of pointer indirection, not a flat struct array like
-- everything else parsed so far: gMapGroups[group] is itself a pointer to a
-- table of MapHeader pointers, and gMapGroups[group][num] is the pointer to
-- the actual header. Map IDs elsewhere in the game encode this as a single
-- u16: group = id >> 8, num = id & 0xFF (include/constants/maps.h).
--
-- Verified against real ROM data: MAP_PALLET_TOWN (group 3, num 0) resolves
-- through both indirections to a header whose mapLayoutId field is exactly
-- 78 -- LAYOUT_PALLET_TOWN, pokefirered include/constants/layouts.h. A
-- coincidental match on a specific 2-byte value like that would be
-- vanishingly unlikely, so the pointer-chasing logic here is correct.
--
-- Struct layout (pokefirered include/global.fieldmap.h, struct MapHeader):
--   0x00 mapLayout            u32 LE pointer (kept raw; see roadmap Phase 1
--                              "maps, layouts, tilesets" for actually
--                              resolving MapLayout -- not done here)
--   0x04 events                u32 LE pointer (struct MapEvents*, raw)
--   0x08 mapScripts             u32 LE pointer (raw bytecode, raw)
--   0x0C connections            u32 LE pointer (struct MapConnections*, raw)
--   0x10 music                  u16 LE
--   0x12 mapLayoutId            u16 LE
--   0x14 regionMapSectionId    u8
--   0x15 cave                   u8
--   0x16 weather                 u8
--   0x17 mapType                 u8
--   0x18 bikingAllowed          u8 (bool8)
--   0x19 allowEscaping:1, allowRunning:1, showMapName:6  u8 bitfield
--   0x1A floorNum               s8
--   0x1B battleType             u8
--   size: 0x1C = 28 bytes (already a multiple of 4, no extra padding)
local MapHeader = {}

local RECORD_SIZE = 28
MapHeader.RECORD_SIZE = RECORD_SIZE

local byte = string.byte

local function u16le(record, offset0based)
  return byte(record, offset0based + 1) + byte(record, offset0based + 2) * 256
end

local function u32leAtFileOffset(data, offset0based)
  return byte(data, offset0based + 1)
    + byte(data, offset0based + 2) * 256
    + byte(data, offset0based + 3) * 65536
    + byte(data, offset0based + 4) * 16777216
end

local function s8(record, index1based)
  local b = byte(record, index1based)
  if b >= 128 then return b - 256 end
  return b
end

MapHeader.romBase = 0x08000000

-- data: full ROM bytes. gMapGroupsOffset: 0-based file offset of gMapGroups.
-- mapId: the packed u16 (group << 8 | num), matching in-game MAP_* constants.
function MapHeader.resolve(data, gMapGroupsOffset, mapId)
  local group = math.floor(mapId / 256)
  local num = mapId % 256

  local groupTablePtr = u32leAtFileOffset(data, gMapGroupsOffset + group * 4)
  local groupTableOffset = groupTablePtr - MapHeader.romBase

  local headerPtr = u32leAtFileOffset(data, groupTableOffset + num * 4)
  local headerOffset = headerPtr - MapHeader.romBase

  local record = data:sub(headerOffset + 1, headerOffset + RECORD_SIZE)
  if #record < RECORD_SIZE then
    error("map header read ran past end of data")
  end

  local flags = byte(record, 0x1A)

  return {
    mapLayoutPtr = u32leAtFileOffset(data, headerOffset + 0x00),
    eventsPtr = u32leAtFileOffset(data, headerOffset + 0x04),
    mapScriptsPtr = u32leAtFileOffset(data, headerOffset + 0x08),
    connectionsPtr = u32leAtFileOffset(data, headerOffset + 0x0C),
    music = u16le(record, 0x10),
    mapLayoutId = u16le(record, 0x12),
    regionMapSectionId = byte(record, 0x15),
    cave = byte(record, 0x16),
    weather = byte(record, 0x17),
    mapType = byte(record, 0x18),
    bikingAllowed = byte(record, 0x19) ~= 0,
    allowEscaping = flags % 2 == 1,
    allowRunning = math.floor(flags / 2) % 2 == 1,
    showMapName = math.floor(flags / 4) % 64,
    floorNum = s8(record, 0x1B),
    battleType = byte(record, 0x1C),
  }
end

return MapHeader
