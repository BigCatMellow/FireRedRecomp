-- Decodes FireRed's real dialogue-box font glyphs (pokefirered src/text.c
-- FONT_NORMAL / DecompressGlyph_Normal -- the main font used for
-- overworld/menu dialogue), not a placeholder font. This is Phase 2's
-- "text windows, fonts" item.
--
-- The glyph storage format doesn't come apart the way every other graphic
-- in this project does -- there's no plain 4bpp/8bpp array. It's a packed
-- 2-bit-per-pixel scheme (3 real values used: 0=background, 1=foreground,
-- 2=shadow) unpacked through DecompressGlyphTile, a hand-written ARM
-- routine with no C source in this decomp (only a prototype in
-- include/text.h). Its logic was recovered by disassembling the real
-- built ELF (`arm-none-eabi-objdump -d`) and cross-referencing the one
-- piece that *does* have C source, GenerateFontHalfRowLookupTable
-- (src/text_printer.c), which explains what the disassembly's two lookup
-- tables mean:
--   * sFontHalfRowOffsets (ROM, static local -- found via `nm`, 256 bytes):
--     maps a raw glyph-data byte (which packs 4 pixels x 2 bits) to an
--     index 0-80 into a 3^4=81-entry combination space.
--   * sFontHalfRowLookupTable (IWRAM, runtime-built by
--     GenerateFontHalfRowLookupTable from the TextPrinter's current
--     fgColor/bgColor/shadowColor): maps that combination index to the 4
--     actual pixel color values, packed as 4 nibbles in a u16.
-- GenerateFontHalfRowLookupTable's nested-loop source shows the packed
-- value is (colors[l]<<12)|(colors[k]<<8)|(colors[j]<<4)|colors[i] where
-- (i,j,k,l) is the base-3 decomposition of the combination index
-- (index = i*27 + j*9 + k*3 + l). Calling it with colors=[0,1,2] (i.e.
-- fgColor=1, bgColor=0, shadowColor=2) makes the "color" values equal the
-- raw pixel-type indices themselves (0/1/2), so decoding an index straight
-- back into (i,j,k,l) recovers the 4 pixel types directly -- no separate
-- runtime color table needed, this module inlines that identity case.
--
-- Each decoded pixel-type pair packs into one standard 4bpp byte (low
-- nibble/high nibble = 2 pixels), so 16 "half-row" outputs (4 pixels each)
-- reassemble into one ordinary 32-byte 4bpp tile decodable by
-- GbaGraphics.decode4bppTile -- reused here rather than duplicating pixel
-- unpacking logic.
--
-- A glyph is 4 tiles (2x2, 16x16px; DecompressGlyph_Normal's real visible
-- height is 14px, width is per-glyph via the width table). glyphId is the
-- charmap byte value directly (e.g. 0xBB for 'A') -- FireRed's text
-- renderer passes the raw decoded character straight through as the
-- font's glyph index, no separate remapping table.
--
-- Verified against real ROM data: glyphId 0xBB ('A') and 0xBC ('B') both
-- decode, by eye, to their real letterforms with a drop shadow -- and 'A'
-- 's decoded width (6px) matches sFontNormalLatinGlyphWidths[0xBB].

local GbaGraphics = require("import.GbaGraphics")

local Font = {}

Font.GLYPH_PIXEL_TYPE_BACKGROUND = 0
Font.GLYPH_PIXEL_TYPE_FOREGROUND = 1
Font.GLYPH_PIXEL_TYPE_SHADOW = 2

local byte = string.byte

-- Decodes one 8x8 tile's worth (32 bytes) of real 4bpp-tile-format bytes
-- from 16 bytes of packed glyph source data, starting at srcOffset0based
-- (0-based file offset). Returns the 32-byte string, ready for
-- GbaGraphics.decode4bppTile.
local function decompressGlyphTileBytes(data, offsetsTableOffset, srcOffset0based)
  local out = {}
  local srcPos = srcOffset0based
  for i = 0, 15 do
    local b
    if i % 2 == 0 then
      b = byte(data, srcPos + 2) -- high byte of the u16 at srcPos, no advance
    else
      b = byte(data, srcPos + 1) -- low byte of the same u16
      srcPos = srcPos + 2
    end
    local idx = byte(data, offsetsTableOffset + b + 1) -- sFontHalfRowOffsets[b], 0-80
    local i_ = math.floor(idx / 27)
    local rem = idx % 27
    local j_ = math.floor(rem / 9)
    local rem2 = rem % 9
    local k_ = math.floor(rem2 / 3)
    local l_ = rem2 % 3
    -- low byte = pixel0|pixel1<<4, high byte = pixel2|pixel3<<4 (standard 4bpp packing)
    out[#out + 1] = string.char(i_ + j_ * 16)
    out[#out + 1] = string.char(k_ + l_ * 16)
  end
  return table.concat(out)
end

-- data: full ROM bytes. offsetsTableOffset: 0-based offset of
-- sFontHalfRowOffsets (256 bytes). glyphsOffset: 0-based offset of the
-- glyph sheet (e.g. sFontNormalLatinGlyphs). glyphId: the raw charmap byte.
-- Returns a 16x16 grid of pixel-type values (0/1/2), row-major, as
-- pixelTypes[y][x] (both 0-indexed) -- the caller decides what RGB each
-- type renders as (0=background, typically transparent; 1=foreground;
-- 2=shadow).
function Font.decodeGlyphPixelTypes(data, offsetsTableOffset, glyphsOffset, glyphId)
  local glyphBase = glyphsOffset + glyphId * 64 -- 4 tiles x 16 bytes-of-source-per-tile
  local tiles = {}
  for t = 0, 3 do
    local tileBytes = decompressGlyphTileBytes(data, offsetsTableOffset, glyphBase + t * 16)
    tiles[t] = GbaGraphics.decode4bppTile(tileBytes)
  end

  local pixelTypes = {}
  for y = 0, 15 do
    pixelTypes[y] = {}
    for x = 0, 15 do
      -- 2x2 tile arrangement: tile0=top-left, tile1=top-right, tile2=bottom-left, tile3=bottom-right.
      local tileIndex = (y < 8 and 0 or 2) + (x < 8 and 0 or 1)
      local tile = tiles[tileIndex]
      pixelTypes[y][x] = tile[(y % 8) * 8 + (x % 8)]
    end
  end
  return pixelTypes
end

-- Renders a decoded glyph's pixel-type grid into a
-- { width, height, getPixel(x,y) -> {r,g,b,a} } image (same shape as
-- ObjectSprite/MapCompositor/TitleScreen), given RGB for foreground and
-- shadow (background is always fully transparent). visibleWidth caps the
-- drawn width to the glyph's real advance width (from the width table);
-- height is always 16 (the full glyph cell -- callers wanting exactly the
-- visible 14px can just not draw/ignore the last 2 rows).
function Font.buildGlyphImage(pixelTypes, visibleWidth, fgColor, shadowColor)
  return {
    width = visibleWidth,
    height = 16,
    getPixel = function(x, y)
      if x < 0 or x >= visibleWidth or y < 0 or y > 15 then
        return { r = 0, g = 0, b = 0, a = 0 }
      end
      local t = pixelTypes[y][x]
      if t == Font.GLYPH_PIXEL_TYPE_FOREGROUND then
        return { r = fgColor.r, g = fgColor.g, b = fgColor.b, a = 1 }
      elseif t == Font.GLYPH_PIXEL_TYPE_SHADOW then
        return { r = shadowColor.r, g = shadowColor.g, b = shadowColor.b, a = 1 }
      else
        return { r = 0, g = 0, b = 0, a = 0 }
      end
    end,
  }
end

-- Lays out a sequence of raw glyph ids left-to-right, each advancing by its
-- real width-table entry (plus 1px inter-glyph spacing, matching
-- GetGlyphWidth's callers in src/text.c), into one composited
-- { width, height, getPixel } image -- same shape as buildGlyphImage, just
-- spanning the whole string instead of one glyph cell.
function Font.renderString(data, offsetsTableOffset, glyphsOffset, widthsTableOffset, glyphIds, fgColor, shadowColor)
  local glyphs = {}
  local widths = {}
  local totalWidth = 0
  for i, glyphId in ipairs(glyphIds) do
    local w = byte(data, widthsTableOffset + glyphId + 1)
    glyphs[i] = Font.decodeGlyphPixelTypes(data, offsetsTableOffset, glyphsOffset, glyphId)
    widths[i] = w
    totalWidth = totalWidth + w + (i < #glyphIds and 1 or 0)
  end

  return {
    width = totalWidth,
    height = 16,
    getPixel = function(x, y)
      if y < 0 or y > 15 then return { r = 0, g = 0, b = 0, a = 0 } end
      local cursor = 0
      for i = 1, #glyphIds do
        local w = widths[i]
        if x >= cursor and x < cursor + w then
          local t = glyphs[i][y][x - cursor]
          if t == Font.GLYPH_PIXEL_TYPE_FOREGROUND then
            return { r = fgColor.r, g = fgColor.g, b = fgColor.b, a = 1 }
          elseif t == Font.GLYPH_PIXEL_TYPE_SHADOW then
            return { r = shadowColor.r, g = shadowColor.g, b = shadowColor.b, a = 1 }
          else
            return { r = 0, g = 0, b = 0, a = 0 }
          end
        end
        cursor = cursor + w + 1
      end
      return { r = 0, g = 0, b = 0, a = 0 }
    end,
  }
end

return Font
