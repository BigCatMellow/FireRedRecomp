-- Decodes a real GBA `struct OamData` (include/gba/types.h) and maps its
-- shape/size fields to real pixel dimensions -- the standard GBA OAM
-- hardware table (documented hardware behavior, identical across every
-- GBA game, not FireRed-specific data; pokefirered's own copy of it is
-- sOamDimensions/sOamDimensionsCopy in src/sprite.c, transcribed here
-- verbatim). This generalizes ObjectSprite.lua beyond the one sprite
-- (RedNormal, hand-fed tileWidth=2/tileHeight=4) it was originally
-- verified against -- decodeOamData lets a caller read a real object's
-- actual OAM shape/size straight from ROM and compute the right tile
-- dimensions for ObjectSprite.decodeFrameTiles automatically.
--
-- Verified against real ROM data: gObjectEventBaseOam_16x32 (the player's
-- own OAM template, already used indirectly via the hardcoded 2x4 tiles
-- in ObjectSprite's existing tests) decodes to shape=2 (V_RECTANGLE),
-- size=2 -- which this table maps to exactly {16,32}, matching the real
-- struct's name and the width/height already confirmed correct by eye.
-- gObjectEventBaseOam_16x16 (used by, among others, the real ItemBall/
-- Poké Ball ground-item sprite) decodes to shape=0 (SQUARE), size=1,
-- mapping to {16,16} -- a genuinely different real object, proving this
-- isn't special-cased to the one sprite already decoded.

local OamShapeSize = {}

OamShapeSize.SHAPE_SQUARE = 0
OamShapeSize.SHAPE_H_RECTANGLE = 1
OamShapeSize.SHAPE_V_RECTANGLE = 2

-- [shape][size] -> {width, height} in pixels. Transcribed from
-- pokefirered's real sOamDimensions table (src/sprite.c), which is
-- itself just the standard GBA hardware OAM size table.
OamShapeSize.PIXEL_DIMENSIONS = {
  [0] = { -- SQUARE
    [0] = { width = 8, height = 8 },
    [1] = { width = 16, height = 16 },
    [2] = { width = 32, height = 32 },
    [3] = { width = 64, height = 64 },
  },
  [1] = { -- H_RECTANGLE
    [0] = { width = 16, height = 8 },
    [1] = { width = 32, height = 8 },
    [2] = { width = 32, height = 16 },
    [3] = { width = 64, height = 32 },
  },
  [2] = { -- V_RECTANGLE
    [0] = { width = 8, height = 16 },
    [1] = { width = 8, height = 32 },
    [2] = { width = 16, height = 32 },
    [3] = { width = 32, height = 64 },
  },
}

local byte = string.byte

-- data: full ROM bytes. offset: 0-based offset of a real struct OamData
-- (8 bytes). Bitfield layout (confirmed against real ROM bytes for
-- gObjectEventBaseOam_16x32/_16x16, not just the C struct declaration):
--   byte0: y (whole byte)
--   byte1: affineMode:2, objMode:2, mosaic:1, bpp:1, shape:2 (top 2 bits)
--   byte2-3 (u16 LE): x:9, matrixNum:5, size:2 (top 2 bits of byte3)
--   byte4-5 (u16 LE): tileNum:10, priority:2, paletteNum:4
-- Only the fields this project currently has a use for are returned.
function OamShapeSize.decodeOamData(data, offset)
  local b1 = byte(data, offset + 2)
  local b3 = byte(data, offset + 4)
  local b4, b5 = byte(data, offset + 5), byte(data, offset + 6)

  local shape = math.floor(b1 / 64) % 4
  local size = math.floor(b3 / 64) % 4
  local tileNum16 = b4 + b5 * 256
  local tileNum = tileNum16 % 1024
  local priority = math.floor(tileNum16 / 1024) % 4
  local paletteNum = math.floor(tileNum16 / 4096) % 16

  local dims = OamShapeSize.PIXEL_DIMENSIONS[shape][size]
  return {
    shape = shape,
    size = size,
    width = dims.width,
    height = dims.height,
    widthTiles = dims.width / 8,
    heightTiles = dims.height / 8,
    tileNum = tileNum,
    priority = priority,
    paletteNum = paletteNum,
  }
end

return OamShapeSize
