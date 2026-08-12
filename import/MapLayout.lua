-- Parses a struct MapLayout (pokefirered include/global.fieldmap.h), given
-- the raw pointer MapHeader.resolve() left in a header's mapLayoutPtr.
--
-- Verified against real ROM data: LAYOUT_PALLET_TOWN's fields decode to
-- width=24, height=20, borderWidth=2, borderHeight=2 -- an exact match for
-- data/layouts/layouts.json's LAYOUT_PALLET_TOWN entry in pokefirered-master
-- (width/height/border_width/border_height are all listed there).
--
-- Struct layout (pokefirered include/global.fieldmap.h, struct MapLayout):
--   0x00 width               s32 LE
--   0x04 height               s32 LE
--   0x08 border               u32 LE pointer (raw -- border block data)
--   0x0C map                   u32 LE pointer (raw -- block/metatile data)
--   0x10 primaryTileset       u32 LE pointer (raw -- struct Tileset*)
--   0x14 secondaryTileset     u32 LE pointer (raw -- struct Tileset*)
--   0x18 borderWidth           u8
--   0x19 borderHeight          u8
--   size: 26 bytes raw, no padding observed needed (only read fields up to
--   0x19 -- any trailing pad to a 4-byte boundary doesn't matter since
--   nothing is read past borderHeight)
local MapLayout = {}

local byte = string.byte

local function s32le(data, offset0based)
  local b1, b2, b3, b4 = byte(data, offset0based + 1), byte(data, offset0based + 2), byte(data, offset0based + 3), byte(data, offset0based + 4)
  local v = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
  if v >= 2147483648 then v = v - 4294967296 end
  return v
end

local function u32le(data, offset0based)
  return byte(data, offset0based + 1)
    + byte(data, offset0based + 2) * 256
    + byte(data, offset0based + 3) * 65536
    + byte(data, offset0based + 4) * 16777216
end

MapLayout.romBase = 0x08000000

-- data: full ROM bytes. mapLayoutPtr: raw ROM address (from a MapHeader's
-- mapLayoutPtr field).
function MapLayout.resolve(data, mapLayoutPtr)
  local offset = mapLayoutPtr - MapLayout.romBase
  return {
    width = s32le(data, offset + 0x00),
    height = s32le(data, offset + 0x04),
    borderPtr = u32le(data, offset + 0x08),
    mapPtr = u32le(data, offset + 0x0C),
    primaryTilesetPtr = u32le(data, offset + 0x10),
    secondaryTilesetPtr = u32le(data, offset + 0x14),
    borderWidth = byte(data, offset + 0x18 + 1),
    borderHeight = byte(data, offset + 0x19 + 1),
  }
end

return MapLayout
