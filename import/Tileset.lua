-- Parses struct Tileset (pokefirered include/global.fieldmap.h), given the
-- raw pointer MapLayout.resolve() left in primaryTilesetPtr/secondaryTilesetPtr.
--
-- Verified against real MAP_PALLET_TOWN data: primaryTileset's isCompressed
-- flag is 1, and decompressing its tiles pointer with Lz77 produces exactly
-- 640 whole 32-byte tiles (20480 bytes, no partial/leftover tile) --
-- decompression only comes out even like that if the pointer and format are
-- both right.
--
-- Struct layout (pokefirered include/global.fieldmap.h, struct Tileset,
-- 24 bytes, no padding surprises -- ends exactly on a 4-byte boundary):
--   0x00 isCompressed        u8 (bool8)
--   0x01 isSecondary          u8 (bool8)
--   0x02-0x03 padding (align tiles to 4)
--   0x04 tiles                 u32 LE pointer -> 4bpp tile data (LZ77-compressed if isCompressed)
--   0x08 palettes              u32 LE pointer -> 16 palettes x 16 colors (u16 BGR555 each), NOT compressed
--   0x0C metatiles              u32 LE pointer -> metatile definitions (raw, not parsed here)
--   0x10 callback               u32 LE pointer (native code pointer, meaningless off-GBA; kept raw/unused)
--   0x14 metatileAttributes    u32 LE pointer (raw, not parsed here)
local Tileset = {}

Tileset.romBase = 0x08000000

local byte = string.byte

local function u32le(data, offset0based)
  return byte(data, offset0based + 1)
    + byte(data, offset0based + 2) * 256
    + byte(data, offset0based + 3) * 65536
    + byte(data, offset0based + 4) * 16777216
end

function Tileset.resolve(data, tilesetPtr)
  local offset = tilesetPtr - Tileset.romBase
  return {
    isCompressed = byte(data, offset + 0x00 + 1) ~= 0,
    isSecondary = byte(data, offset + 0x01 + 1) ~= 0,
    tilesPtr = u32le(data, offset + 0x04),
    palettesPtr = u32le(data, offset + 0x08),
    metatilesPtr = u32le(data, offset + 0x0C),
    metatileAttributesPtr = u32le(data, offset + 0x14),
  }
end

return Tileset
