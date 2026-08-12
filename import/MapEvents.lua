-- Parses a struct MapEvents (pokefirered include/global.fieldmap.h) and its
-- four event-array pointers, given the raw pointer MapHeader.resolve() left
-- in a header's eventsPtr.
--
-- All four sub-structs verified against real MAP_PALLET_TOWN data (which
-- has 3 object events, 3 warps, 3 coord events, 5 bg events -- counts match
-- data/maps/PalletTown/map.json exactly):
--   * object event 0 (Sign Lady): x=3, y=10, elevation=3,
--     movementRangeX=1, movementRangeY=4, trainerType=0 -- all match.
--   * warp 0: x=6, y=7, elevation=0, warpId=1, mapGroup=4, mapNum=0 --
--     mapGroup/mapNum match MAP_PALLET_TOWN_PLAYERS_HOUSE_1F exactly
--     (dest_warp_id=1 in the source JSON).
--   * coord event 0 (Oak trigger): x=12, y=1, elevation=3, trigger=0x4050
--     -- exactly VAR_MAP_SCENE_PALLET_TOWN_OAK.
--   * bg event 0 (Oak's Lab sign): x=16, y=16, elevation=0, kind=0.
--
-- Struct layouts (pokefirered include/global.fieldmap.h):
--
-- MapEvents (20 bytes, no padding: 4 u8 counts fill exactly to the 4-byte
-- boundary before the pointers start):
--   0x00 objectEventCount  u8
--   0x01 warpCount          u8
--   0x02 coordEventCount   u8
--   0x03 bgEventCount       u8
--   0x04 objectEvents       u32 LE pointer -> ObjectEventTemplate[]
--   0x08 warps               u32 LE pointer -> WarpEvent[]
--   0x0C coordEvents        u32 LE pointer -> CoordEvent[]
--   0x10 bgEvents            u32 LE pointer -> BgEvent[]
--
-- ObjectEventTemplate (24 bytes -- struct comment says "size = 0x18", and
-- real data confirms it). Only the "normal" union variant is decoded here
-- (kind == 0, ordinary NPCs/trainers); the "clone" variant (kind != 0,
-- object-event clones referencing another map's template) is NOT handled
-- yet -- its fields are left nil.
--   0x00 localId     u8
--   0x01 graphicsId  u8
--   0x02 kind         u8
--   0x03 padding (align x to 2)
--   0x04 x             s16 LE
--   0x06 y             s16 LE
--   0x08 elevation    u8   (normal variant)
--   0x09 movementType u8
--   0x0A movementRangeX:4, movementRangeY:4  u8 bitfield
--   0x0B padding (part of the u16 bitfield's second byte, unused)
--   0x0C trainerType  u16 LE
--   0x0E trainerRangeOrBerryTreeId  u16 LE
--   0x10 script        u32 LE pointer (raw)
--   0x14 flagId        u16 LE
--   0x16-0x17 padding to 24 bytes
--
-- WarpEvent (8 bytes):
--   0x00 x  s16 LE
--   0x02 y  s16 LE
--   0x04 elevation  u8
--   0x05 warpId      u8
--   0x06 mapNum      u8
--   0x07 mapGroup   u8
--
-- CoordEvent (16 bytes):
--   0x00 x  u16 LE
--   0x02 y  u16 LE
--   0x04 elevation  u8
--   0x05 padding (align trigger to 2)
--   0x06 trigger  u16 LE (a VAR_* id for "trigger"-type coord events)
--   0x08 index      u16 LE (the value compared against, i.e. var_value)
--   0x0A-0x0B padding (align script to 4)
--   0x0C script    u32 LE pointer (raw)
--
-- BgEvent (12 bytes). Only the "script" union variant is decoded (kind==0,
-- signs); the "hiddenItem" u32 variant (kind!=0, hidden items) is left raw
-- in the same field since it's read as a u32 either way.
--   0x00 x  u16 LE
--   0x02 y  u16 LE
--   0x04 elevation  u8
--   0x05 kind         u8
--   0x06-0x07 padding (align union to 4)
--   0x08 bgUnion    u32 LE (script pointer OR hidden item data, by kind)
local MapEvents = {}

MapEvents.romBase = 0x08000000

local byte = string.byte

local function s16le(data, offset0based)
  local v = byte(data, offset0based + 1) + byte(data, offset0based + 2) * 256
  if v >= 32768 then v = v - 65536 end
  return v
end

local function u16le(data, offset0based)
  return byte(data, offset0based + 1) + byte(data, offset0based + 2) * 256
end

local function u32le(data, offset0based)
  return byte(data, offset0based + 1)
    + byte(data, offset0based + 2) * 256
    + byte(data, offset0based + 3) * 65536
    + byte(data, offset0based + 4) * 16777216
end

local function parseObjectEvent(data, offset0based)
  local kind = byte(data, offset0based + 0x02 + 1)
  local mon = {
    localId = byte(data, offset0based + 0x00 + 1),
    graphicsId = byte(data, offset0based + 0x01 + 1),
    kind = kind,
    x = s16le(data, offset0based + 0x04),
    y = s16le(data, offset0based + 0x06),
    scriptPtr = u32le(data, offset0based + 0x10),
    flagId = u16le(data, offset0based + 0x14),
  }
  if kind == 0 then
    local bitfield = byte(data, offset0based + 0x0A + 1)
    mon.elevation = byte(data, offset0based + 0x08 + 1)
    mon.movementType = byte(data, offset0based + 0x09 + 1)
    mon.movementRangeX = bitfield % 16
    mon.movementRangeY = math.floor(bitfield / 16) % 16
    mon.trainerType = u16le(data, offset0based + 0x0C)
    mon.trainerRangeOrBerryTreeId = u16le(data, offset0based + 0x0E)
  end
  return mon
end

local function parseWarp(data, offset0based)
  return {
    x = s16le(data, offset0based + 0x00),
    y = s16le(data, offset0based + 0x02),
    elevation = byte(data, offset0based + 0x04 + 1),
    warpId = byte(data, offset0based + 0x05 + 1),
    mapNum = byte(data, offset0based + 0x06 + 1),
    mapGroup = byte(data, offset0based + 0x07 + 1),
  }
end

local function parseCoordEvent(data, offset0based)
  return {
    x = u16le(data, offset0based + 0x00),
    y = u16le(data, offset0based + 0x02),
    elevation = byte(data, offset0based + 0x04 + 1),
    trigger = u16le(data, offset0based + 0x06),
    index = u16le(data, offset0based + 0x08),
    scriptPtr = u32le(data, offset0based + 0x0C),
  }
end

local function parseBgEvent(data, offset0based)
  return {
    x = u16le(data, offset0based + 0x00),
    y = u16le(data, offset0based + 0x02),
    elevation = byte(data, offset0based + 0x04 + 1),
    kind = byte(data, offset0based + 0x05 + 1),
    union = u32le(data, offset0based + 0x08), -- script ptr (kind==0) or hidden item data
  }
end

-- data: full ROM bytes. eventsPtr: raw ROM address (from a MapHeader's
-- eventsPtr field).
function MapEvents.resolve(data, eventsPtr)
  local base = eventsPtr - MapEvents.romBase

  local objectEventCount = byte(data, base + 0x00 + 1)
  local warpCount = byte(data, base + 0x01 + 1)
  local coordEventCount = byte(data, base + 0x02 + 1)
  local bgEventCount = byte(data, base + 0x03 + 1)

  local objectEventsPtr = u32le(data, base + 0x04)
  local warpsPtr = u32le(data, base + 0x08)
  local coordEventsPtr = u32le(data, base + 0x0C)
  local bgEventsPtr = u32le(data, base + 0x10)

  local objectEvents, warps, coordEvents, bgEvents = {}, {}, {}, {}

  for i = 0, objectEventCount - 1 do
    objectEvents[i] = parseObjectEvent(data, objectEventsPtr - MapEvents.romBase + i * 24)
  end
  for i = 0, warpCount - 1 do
    warps[i] = parseWarp(data, warpsPtr - MapEvents.romBase + i * 8)
  end
  for i = 0, coordEventCount - 1 do
    coordEvents[i] = parseCoordEvent(data, coordEventsPtr - MapEvents.romBase + i * 16)
  end
  for i = 0, bgEventCount - 1 do
    bgEvents[i] = parseBgEvent(data, bgEventsPtr - MapEvents.romBase + i * 12)
  end

  return {
    objectEvents = objectEvents,
    warps = warps,
    coordEvents = coordEvents,
    bgEvents = bgEvents,
  }
end

return MapEvents
