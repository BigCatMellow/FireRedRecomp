-- Parses FireRed's gWildMonHeaders table (pokefirered include/wild_encounter.h)
-- and the WildPokemonInfo/WildPokemon data it points to.
--
-- gWildMonHeaders is a flat array, NOT indexed by map id -- callers linear-
-- scan it for a (mapGroup, mapNum) match, terminated by a sentinel entry
-- with mapGroup == MAP_GROUP(MAP_UNDEFINED) == 0xFF (pokefirered
-- src/wild_encounter.c GetCurrentMapWildMonHeaderId). No struct field
-- documents the array's length; the sentinel is the only way to know
-- where it ends.
--
-- Verified against real MAP_ROUTE1 data (found by scanning to index 87):
-- encounterRate=21, and the 12-entry land encounter list is exactly
-- PIDGEY/RATTATA at the levels listed in src/data/wild_encounters.json's
-- sRoute1_FireRed table.
--
-- Struct layouts (pokefirered include/wild_encounter.h):
--   WildPokemonHeader (20 bytes):
--     0x00 mapGroup            u8
--     0x01 mapNum               u8
--     0x02-0x03 padding (align pointers to 4)
--     0x04 landMonsInfo         u32 LE pointer -> WildPokemonInfo, or NULL
--     0x08 waterMonsInfo        u32 LE pointer -> WildPokemonInfo, or NULL
--     0x0C rockSmashMonsInfo   u32 LE pointer -> WildPokemonInfo, or NULL
--     0x10 fishingMonsInfo      u32 LE pointer -> WildPokemonInfo, or NULL
--   WildPokemonInfo (8 bytes -- raw 5 bytes rounded up to a 4-byte multiple,
--   same padding rule seen throughout this ROM):
--     0x00 encounterRate  u8
--     0x01-0x03 padding (align wildPokemon to 4)
--     0x04 wildPokemon     u32 LE pointer -> WildPokemon[]
--   WildPokemon (4 bytes, no padding needed):
--     0x00 minLevel  u8
--     0x01 maxLevel   u8
--     0x02 species     u16 LE

local WildEncounters = {}

WildEncounters.romBase = 0x08000000
WildEncounters.HEADER_RECORD_SIZE = 20
WildEncounters.TERMINATOR_MAP_GROUP = 0xFF

local byte = string.byte

local function u32le(data, offset0based)
  return byte(data, offset0based + 1)
    + byte(data, offset0based + 2) * 256
    + byte(data, offset0based + 3) * 65536
    + byte(data, offset0based + 4) * 16777216
end

-- data: full ROM bytes. headersOffset: 0-based file offset of
-- gWildMonHeaders (matching RomAddresses.lua's convention -- already
-- romBase-subtracted, unlike the *Ptr fields this module reads out of ROM
-- data, which are raw addresses). mapGroup, mapNum: the target map.
-- Returns the matching header (with raw pointer fields) or nil if none
-- found before the sentinel/end of data.
function WildEncounters.findHeader(data, headersOffset, mapGroup, mapNum)
  local base = headersOffset
  local i = 0
  while true do
    local o = base + i * WildEncounters.HEADER_RECORD_SIZE
    local group = byte(data, o + 1)
    if not group or group == WildEncounters.TERMINATOR_MAP_GROUP then
      return nil
    end
    local num = byte(data, o + 2)
    if group == mapGroup and num == mapNum then
      return {
        mapGroup = group,
        mapNum = num,
        landMonsInfoPtr = u32le(data, o + 0x04),
        waterMonsInfoPtr = u32le(data, o + 0x08),
        rockSmashMonsInfoPtr = u32le(data, o + 0x0C),
        fishingMonsInfoPtr = u32le(data, o + 0x10),
      }
    end
    i = i + 1
  end
end

-- infoPtr: a raw WildPokemonInfo pointer (e.g. a header's landMonsInfoPtr).
-- Returns nil if infoPtr is NULL (0) -- not every map has every encounter
-- type. count: how many WildPokemon entries to read.
function WildEncounters.resolveInfo(data, infoPtr, count)
  if infoPtr == 0 then return nil end
  local base = infoPtr - WildEncounters.romBase
  local encounterRate = byte(data, base + 0x00 + 1)
  local wildPokemonPtr = u32le(data, base + 0x04)

  local monsBase = wildPokemonPtr - WildEncounters.romBase
  local mons = {}
  for i = 0, count - 1 do
    local o = monsBase + i * 4
    mons[i] = {
      minLevel = byte(data, o + 0x00 + 1),
      maxLevel = byte(data, o + 0x01 + 1),
      species = byte(data, o + 0x02 + 1) + byte(data, o + 0x03 + 1) * 256,
    }
  end

  return { encounterRate = encounterRate, mons = mons }
end

return WildEncounters
