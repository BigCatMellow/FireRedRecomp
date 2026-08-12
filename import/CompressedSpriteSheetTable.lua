-- Parses struct CompressedSpriteSheet[] tables (pokefirered include/sprite.h)
-- -- the format shared by gMonFrontPicTable, gMonBackPicTable, and
-- gTrainerFrontPicTable (include/data.h). Extraction only: resolves the
-- LZ77-compressed graphics pointer + declared size + OAM tag. Actually
-- decoding the pixel data into an image is Phase 2 renderer work (see
-- GbaGraphics.lua for the general 4bpp/Lz77 decode primitives already
-- built and reused here for verification).
--
-- Verified against real ROM data: gMonFrontPicTable[SPECIES_BULBASAUR]
-- decodes to size=2048, and Lz77-decompressing its data pointer produces
-- exactly 2048 bytes (64x64px at 4bpp = 64*64/2) -- the declared size and
-- the real decompressed length matching exactly confirms both the struct
-- layout and the pointer are correct.
--
-- Struct layout (8 bytes, no padding -- ends on a 4-byte boundary):
--   0x00 data  u32 LE pointer (raw -- LZ77-compressed 4bpp tile data)
--   0x04 size   u16 LE (uncompressed byte size)
--   0x06 tag     u16 LE (OAM/sprite tag)
local CompressedSpriteSheetTable = {}

CompressedSpriteSheetTable.romBase = 0x08000000
CompressedSpriteSheetTable.RECORD_SIZE = 8

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

-- data: full ROM bytes. tableOffset: 0-based file offset of the table.
-- index: entry index (e.g. a SPECIES_* id for gMonFrontPicTable).
function CompressedSpriteSheetTable.resolve(data, tableOffset, index)
  local base = tableOffset + index * CompressedSpriteSheetTable.RECORD_SIZE
  return {
    dataPtr = u32le(data, base + 0x00),
    size = u16le(data, base + 0x04),
    tag = u16le(data, base + 0x06),
  }
end

return CompressedSpriteSheetTable
