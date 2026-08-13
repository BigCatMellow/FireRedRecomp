-- Parses a tileset's real per-metatile attributes array (pokefirered
-- src/fieldmap.c: `struct Tileset.metatileAttributes` -- one u32 per
-- metatile, packed per `sMetatileAttrMasks`/`sMetatileAttrShifts`):
--   bits 0-8   BEHAVIOR (metatile_behaviors.h MB_* constants -- e.g.
--              MB_TALL_GRASS=0x02, MB_JUMP_EAST/WEST/NORTH/SOUTH=0x38-0x3B,
--              MB_CAVE_DOOR=0x60, MB_WARP_DOOR=0x69)
--   bits 9-13  TERRAIN
--   bits 24-26 ENCOUNTER_TYPE
--   bits 29-30 LAYER_TYPE
-- (bits 14-23, 27-28, 31 exist in the real struct but have no known
-- consumer in vanilla FireRed and aren't decoded here.)
--
-- Metatile ids are combined-space like Metatile.lua/MapCompositor.lua:
-- ids 0-639 (NUM_METATILES_IN_PRIMARY) index the primary tileset's own
-- attributes array; ids 640+ index the secondary tileset's array,
-- re-indexed by subtracting 640.
--
-- Verified against real Pallet Town data: the player's-house warp-door
-- tile (map 3,0, block (6,7), metatile id 675 -- a secondary-tileset
-- metatile) decodes to BEHAVIOR 0x69 (MB_WARP_DOOR), matching the real
-- warp event MapEvents.lua already decodes at that exact coordinate.

local MetatileAttributes = {}

MetatileAttributes.NUM_METATILES_IN_PRIMARY = 640

MetatileAttributes.BEHAVIOR = {
  MB_TALL_GRASS = 0x02,
  MB_JUMP_EAST = 0x38,
  MB_JUMP_WEST = 0x39,
  MB_JUMP_NORTH = 0x3A,
  MB_JUMP_SOUTH = 0x3B,
  MB_CAVE_DOOR = 0x60,
  MB_WARP_DOOR = 0x69,
}

local byte = string.byte

local function u32le(data, offset0based)
  return byte(data, offset0based + 1)
    + byte(data, offset0based + 2) * 256
    + byte(data, offset0based + 3) * 65536
    + byte(data, offset0based + 4) * 16777216
end

-- data: full ROM bytes. attributesPtr: raw ROM address (a Tileset's
-- metatileAttributesPtr). localMetatileId: 0-based index into THIS
-- tileset's own array (already re-indexed by the caller for secondary
-- tilesets, matching Metatile.resolve's convention).
function MetatileAttributes.resolve(data, attributesPtr, localMetatileId)
  local base = attributesPtr - 0x08000000
  local raw = u32le(data, base + localMetatileId * 4)
  return {
    behavior = raw % 512, -- bits 0-8
    terrain = math.floor(raw / 512) % 32, -- bits 9-13
    encounterType = math.floor(raw / 16777216) % 8, -- bits 24-26
    layerType = math.floor(raw / 536870912) % 4, -- bits 29-30
  }
end

-- Combined-space convenience matching Metatile.resolve/MapCompositor's
-- addressing: metatileId 0-639 -> primary tileset, 640+ -> secondary.
function MetatileAttributes.resolveCombined(data, primaryAttributesPtr, secondaryAttributesPtr, metatileId)
  if metatileId < MetatileAttributes.NUM_METATILES_IN_PRIMARY then
    return MetatileAttributes.resolve(data, primaryAttributesPtr, metatileId)
  else
    return MetatileAttributes.resolve(data, secondaryAttributesPtr, metatileId - MetatileAttributes.NUM_METATILES_IN_PRIMARY)
  end
end

return MetatileAttributes
