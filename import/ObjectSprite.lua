-- Decodes FireRed overworld object-event sprites (players, NPCs, items on
-- the ground, etc. -- pokefirered include/global.fieldmap.h struct
-- ObjectEventGraphicsInfo / src/data/object_events/*). This is Phase 2's
-- "sprite/OAM composition" piece, the first sprite (as opposed to
-- background-tilemap) graphics this project decodes.
--
-- Unlike every background tile graphic decoded so far, overworld sprite
-- pics are stored **uncompressed** (INCBIN_U16 straight from a .4bpp file,
-- no ".lz" -- confirmed by checking pokefirered's own source, not
-- assumed), and use the standard GBA "1D object mapping" tile order (this
-- game sets DISPCNT_OBJ_1D_MAP, confirmed in src/title_screen.c): a
-- sprite's tiles are simply consecutive in ROM, arranged left-to-right
-- then top-to-bottom over the sprite's tile-width x tile-height grid --
-- there's no separate tilemap indirection like backgrounds have.
--
-- A `struct SpriteFrameImage` array (the "pic table", e.g.
-- sPicTable_RedNormal) holds one entry per animation frame; frame N's
-- pixel data starts at `width * height * N` tiles into the sprite sheet
-- (pokefirered asm/macros/map.inc's `overworld_frame` macro:
-- `.data = ptr + (width*height*frame*64)/2`, i.e. frame*width*height*32
-- bytes -- 64 4bpp-nibble-pairs per tile row-of-2px, /2 for byte count,
-- matches 32 bytes/tile).
--
-- Verified against real ROM data: gObjectEventGraphicsInfo_RedNormal's
-- frame 0 (width=2 height=4 tiles = 16x32px), decoded with
-- gObjectEventPal_Player, is visually the real FireRed player character
-- sprite (Red) facing down -- red/white cap, backpack straps, blue jeans,
-- spot-checked by eye.

local GbaGraphics = require("import.GbaGraphics")

local ObjectSprite = {}

local byte = string.byte

-- data: full ROM bytes. picOffset: 0-based file offset of the sprite
-- sheet (a *const u16[]* symbol, e.g. gObjectEventPic_RedNormal).
-- widthTiles/heightTiles: the sprite's size in 8px tiles (from
-- ObjectEventGraphicsInfo.width/height, which are already in pixels --
-- divide by 8 -- or straight from the source's overworld_frame() call,
-- which uses tile units directly). frameIndex: which animation frame.
-- Returns a widthTiles*heightTiles list of decoded 4bpp tiles (see
-- GbaGraphics.decode4bppTile), in left-to-right/top-to-bottom order.
function ObjectSprite.decodeFrameTiles(data, picOffset, widthTiles, heightTiles, frameIndex)
  local tilesPerFrame = widthTiles * heightTiles
  local frameByteOffset = picOffset + frameIndex * tilesPerFrame * 32
  return GbaGraphics.decodeTiles(data, frameByteOffset, tilesPerFrame)
end

-- Arranges decoded tiles (from decodeFrameTiles) + a palette (from
-- GbaGraphics.decodePalette) into a pixel image, the same
-- { width, height, getPixel(x,y) -> {r,g,b,a} } shape MapCompositor/
-- TitleScreen use. Palette index 0 renders as fully transparent (alpha 0)
-- rather than being skipped/blacked out, since sprites are meant to
-- composite over other content (unlike a standalone map/title image).
function ObjectSprite.buildImage(tiles, palette, widthTiles, heightTiles)
  local pixelWidth, pixelHeight = widthTiles * 8, heightTiles * 8
  local pixels = {}
  for ty = 0, heightTiles - 1 do
    for tx = 0, widthTiles - 1 do
      local tile = tiles[ty * widthTiles + tx]
      for py = 0, 7 do
        for px = 0, 7 do
          local colorIndex = tile[py * 8 + px]
          local y = ty * 8 + py
          pixels[y] = pixels[y] or {}
          if colorIndex == 0 then
            pixels[y][tx * 8 + px] = { r = 0, g = 0, b = 0, a = 0 }
          else
            local c = palette[colorIndex]
            pixels[y][tx * 8 + px] = { r = c.r, g = c.g, b = c.b, a = 1 }
          end
        end
      end
    end
  end
  return {
    width = pixelWidth,
    height = pixelHeight,
    getPixel = function(x, y)
      local row = pixels[y]
      return (row and row[x]) or { r = 0, g = 0, b = 0, a = 0 }
    end,
  }
end

-- Convenience: decode + arrange one frame in one call.
function ObjectSprite.decodeFrame(data, picOffset, palOffset, widthTiles, heightTiles, frameIndex)
  local tiles = ObjectSprite.decodeFrameTiles(data, picOffset, widthTiles, heightTiles, frameIndex or 0)
  local palette = GbaGraphics.decodePalette(data, palOffset)
  return ObjectSprite.buildImage(tiles, palette, widthTiles, heightTiles)
end

return ObjectSprite
