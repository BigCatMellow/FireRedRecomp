-- Parses a map's border block data (a MapLayout's `border` pointer):
-- borderWidth x borderHeight raw metatile ids, tiled to fill the area past
-- a map's edge (pokefirered src/fieldmap.c's GetBorderBlockAt: it indexes
-- this array modulo borderWidth/borderHeight and ORs in
-- MAPGRID_COLLISION_MASK, meaning the stored values are bare metatile ids
-- with no collision/elevation bits packed in -- unlike MapBlockData's
-- per-cell u16s).
--
-- Verified against real MAP_PALLET_TOWN data: border is exactly
-- {28, 29, 20, 21} (2x2, matching borderWidth=borderHeight=2), an exact
-- match for data/layouts/PalletTown/border.bin in pokefirered-master.

local MapBorder = {}

MapBorder.romBase = 0x08000000

local byte = string.byte

local function u16le(data, offset0based)
  return byte(data, offset0based + 1) + byte(data, offset0based + 2) * 256
end

-- data: full ROM bytes. borderPtr: raw ROM address (from a MapLayout's
-- borderPtr field). borderWidth, borderHeight: from the same MapLayout.
-- Returns a 0-indexed, row-major array of raw metatile ids, length
-- borderWidth*borderHeight.
function MapBorder.resolve(data, borderPtr, borderWidth, borderHeight)
  local base = borderPtr - MapBorder.romBase
  local out = {}
  for i = 0, borderWidth * borderHeight - 1 do
    out[i] = u16le(data, base + i * 2)
  end
  return out
end

return MapBorder
