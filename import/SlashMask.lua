-- Decodes the real title screen slash sprite's pixel data (sSlash_Gfx,
-- pokefirered src/title_screen.c) as a boolean window mask rather than a
-- visible image. On real hardware the slash sprite is ST_OAM_OBJ_WINDOW
-- mode (sOamData_SlashSprite), which never draws its own pixels -- its
-- non-transparent silhouette instead defines a hardware "window" region
-- where a separate blend effect gets applied to whatever's underneath
-- (see SlashSprite.lua's header comment). So this module only cares
-- about *which pixels are non-zero* (opaque, index != 0), not their
-- palette colors -- there's no need to decode a palette at all.
--
-- ST_OAM_SIZE_3 SQUARE = 64x64px = 8x8 tiles. Verified against real ROM
-- data: decoded to an ASCII mask during development, showing an
-- unmistakable diagonal band/streak shape (a "slash"), not noise --
-- consistent with the real visual effect (a diagonal flash of light
-- sweeping across the logo).

local Lz77 = require("import.Lz77")
local GbaGraphics = require("import.GbaGraphics")

local SlashMask = {}

SlashMask.TILE_WIDTH = 8
SlashMask.TILE_HEIGHT = 8
SlashMask.PIXEL_WIDTH = SlashMask.TILE_WIDTH * 8
SlashMask.PIXEL_HEIGHT = SlashMask.TILE_HEIGHT * 8

-- data: full ROM bytes. tilesOffset: 0-based offset of sSlash_Gfx
-- (LZ77-compressed, confirmed from the real INCBIN_U32(...".4bpp.lz")
-- source). Returns a function isOpaque(x, y) -> boolean, x/y in
-- 0..63 (0..PIXEL_WIDTH-1/PIXEL_HEIGHT-1), true where the real slash
-- silhouette is solid.
function SlashMask.decode(data, tilesOffset)
  local decompressed, err = Lz77.decompress(data, tilesOffset + 1)
  if not decompressed then error("slash mask decompression failed: " .. tostring(err)) end
  local tiles = GbaGraphics.decodeTiles(decompressed, 0, SlashMask.TILE_WIDTH * SlashMask.TILE_HEIGHT)

  return function(x, y)
    if x < 0 or x >= SlashMask.PIXEL_WIDTH or y < 0 or y >= SlashMask.PIXEL_HEIGHT then
      return false
    end
    local tx, ty = math.floor(x / 8), math.floor(y / 8)
    local tile = tiles[ty * SlashMask.TILE_WIDTH + tx]
    local px, py = x % 8, y % 8
    return tile[py * 8 + px] ~= 0
  end
end

return SlashMask
