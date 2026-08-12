-- Parses a map's block grid (pokefirered include/global.fieldmap.h
-- MAPGRID_* masks; the raw data behind a MapLayout's `map` pointer, one u16
-- per tile-grid cell, row-major, width x height cells).
--
-- Each u16 cell packs: bits 0-9 metatile id, bits 10-11 collision, bits
-- 12-15 elevation -- this is the exact format documented in
-- global.fieldmap.h as "the data stored in each data/layouts/*/map.bin
-- file", not something inferred.

local MapBlockData = {}

MapBlockData.METATILE_ID_MASK = 0x03FF
MapBlockData.UNDEFINED = MapBlockData.METATILE_ID_MASK

local byte = string.byte

local function u16le(data, offset0based)
  return byte(data, offset0based + 1) + byte(data, offset0based + 2) * 256
end

-- data: full ROM bytes. mapPtr: raw ROM address (from a MapLayout's mapPtr
-- field). width, height: from the same MapLayout. Returns a 0-indexed,
-- row-major array of {metatileId, collision, elevation}, length width*height.
function MapBlockData.resolve(data, mapPtr, width, height)
  local base = mapPtr - 0x08000000
  local out = {}
  local count = width * height
  for i = 0, count - 1 do
    local cell = u16le(data, base + i * 2)
    out[i] = {
      metatileId = cell % 1024,
      collision = math.floor(cell / 1024) % 4,
      elevation = math.floor(cell / 4096) % 16,
    }
  end
  return out
end

return MapBlockData
