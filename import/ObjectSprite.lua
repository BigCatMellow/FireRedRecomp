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
local OamShapeSize = require("import.OamShapeSize")

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

-- Composites a real multi-OAM-entry object sprite (bigger/more complex
-- than the single-OAM 64x64px cap decodeFrame/buildImage assume) from a
-- decoded SubspriteTable (SubspriteTable.decodeTable/decodeSubsprites --
-- see that module's header for the real struct verification). Real
-- pokefirered (src/sprite.c AddSubspritesToOamBuffer) places each
-- subsprite's own OAM entry at (spriteCornerX + x, spriteCornerY + y);
-- for a static decode with no live camera/sprite instance this reduces to
-- placing every subsprite in one shared coordinate space and letting the
-- canvas bounding box fall out of the extremes -- confirmed this is
-- exactly what real data expects: SS Anne's 4 real 64x32 subsprites at
-- x=-32/32,y=-16/16 combine to a real 128x64 bounding box, matching
-- gObjectEventGraphicsInfo_SSAnne's real .width=128/.height=64 declared
-- in src/data/object_events/object_event_graphics_info.h.
--
-- Each subsprite's own tile data lives in the SAME pic sheet
-- decodeFrameTiles already reads (a subsprite's real tileOffset is a
-- tile-unit offset into it, not a separate graphic) -- confirmed for SS
-- Anne: its raw 8-tile-wide x 16-tile-tall sheet is just four consecutive
-- 64x32 (8x4-tile) blocks at tileOffset 0/32/64/96, and the subsprite
-- table's x/y offsets are what rearrange those four blocks into the
-- correct 2x2 visual grid.
--
-- picOffset/palOffset: same as decodeFrame (0-based ROM offsets of the
-- pic sheet / palette; frameIndex is always 0 here -- multi-frame
-- subsprited objects aren't exercised by the object this was verified
-- against). subsprites: a list from SubspriteTable.decodeSubsprites.
-- hFlip/vFlip/OAM-priority draw ordering (real AddSubspritesToOamBuffer
-- handles both) are intentionally NOT applied -- out of scope, this
-- composites the default (unflipped) static layout only, matching how
-- ObjectSprite.decodeFrame already only decodes frame 0 unflipped.
--
-- Returns the same { width, height, getPixel(x,y) } image shape as
-- buildImage, with (0,0) at the composited bounding box's top-left.
function ObjectSprite.compositeSubsprites(data, picOffset, palOffset, subsprites)
  local palette = GbaGraphics.decodePalette(data, palOffset)

  local pieces = {}
  local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
  for _, s in ipairs(subsprites) do
    local dims = OamShapeSize.PIXEL_DIMENSIONS[s.shape][s.size]
    local widthTiles, heightTiles = dims.width / 8, dims.height / 8
    local tiles = ObjectSprite.decodeFrameTiles(data, picOffset + s.tileOffset * 32, widthTiles, heightTiles, 0)
    local image = ObjectSprite.buildImage(tiles, palette, widthTiles, heightTiles)

    pieces[#pieces + 1] = { image = image, x = s.x, y = s.y }
    if s.x < minX then minX = s.x end
    if s.y < minY then minY = s.y end
    if s.x + dims.width > maxX then maxX = s.x + dims.width end
    if s.y + dims.height > maxY then maxY = s.y + dims.height end
  end

  local width, height = maxX - minX, maxY - minY
  local pixels = {}
  for _, piece in ipairs(pieces) do
    local originX, originY = piece.x - minX, piece.y - minY
    for y = 0, piece.image.height - 1 do
      for x = 0, piece.image.width - 1 do
        local p = piece.image.getPixel(x, y)
        if p.a > 0 then
          local canvasY, canvasX = originY + y, originX + x
          pixels[canvasY] = pixels[canvasY] or {}
          pixels[canvasY][canvasX] = p
        end
      end
    end
  end

  return {
    width = width,
    height = height,
    getPixel = function(x, y)
      local row = pixels[y]
      return (row and row[x]) or { r = 0, g = 0, b = 0, a = 0 }
    end,
  }
end

return ObjectSprite
