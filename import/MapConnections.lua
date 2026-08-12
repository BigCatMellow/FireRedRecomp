-- Parses struct MapConnections / struct MapConnection (pokefirered
-- include/global.fieldmap.h), given the raw pointer MapHeader.resolve()
-- left in a header's connectionsPtr.
--
-- Verified against real MAP_PALLET_TOWN data: 2 connections, matching
-- data/maps/PalletTown/map.json exactly -- direction=CONNECTION_NORTH(2) to
-- MAP_ROUTE1 (group 3, num 19) for "up", direction=CONNECTION_SOUTH(1) to
-- MAP_ROUTE21_NORTH (group 3, num 39) for "down".
--
-- Struct layout (pokefirered include/global.fieldmap.h):
--   MapConnections:
--     0x00 count         s32 LE
--     0x04 connections  u32 LE pointer -> MapConnection[]
--   MapConnection (12 bytes -- raw fields total 10, rounded up to a
--   4-byte multiple like everything else in this ROM):
--     0x00 direction  u8  (CONNECTION_SOUTH=1, NORTH=2, WEST=3, EAST=4, DIVE=5, EMERGE=6)
--     0x01-0x03 padding (align offset to 4)
--     0x04 offset       u32 LE (signed in practice, but read as-is; s32 if negative offsets matter)
--     0x08 mapGroup    u8
--     0x09 mapNum       u8
--     0x0A-0x0B padding to 12 bytes
local MapConnections = {}

MapConnections.romBase = 0x08000000
MapConnections.RECORD_SIZE = 12

MapConnections.CONNECTION_SOUTH = 1
MapConnections.CONNECTION_NORTH = 2
MapConnections.CONNECTION_WEST = 3
MapConnections.CONNECTION_EAST = 4
MapConnections.CONNECTION_DIVE = 5
MapConnections.CONNECTION_EMERGE = 6

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

-- data: full ROM bytes. connectionsPtr: raw ROM address (from a MapHeader's
-- connectionsPtr field). Returns a list (0-indexed); an empty list if the
-- map has no connections (connectionsPtr is NULL for such maps -- callers
-- should check that before calling this).
function MapConnections.resolve(data, connectionsPtr)
  local base = connectionsPtr - MapConnections.romBase
  local count = s32le(data, base + 0x00)
  local listPtr = u32le(data, base + 0x04)
  local listOffset = listPtr - MapConnections.romBase

  local out = {}
  for i = 0, count - 1 do
    local o = listOffset + i * MapConnections.RECORD_SIZE
    out[i] = {
      direction = byte(data, o + 0x00 + 1),
      offset = s32le(data, o + 0x04),
      mapGroup = byte(data, o + 0x08 + 1),
      mapNum = byte(data, o + 0x09 + 1),
    }
  end
  return out
end

return MapConnections
