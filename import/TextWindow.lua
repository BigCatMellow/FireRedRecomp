-- Decodes and composites the real "standard window frame" -- the bordered
-- box behind menus and (with a different but structurally similar tile set)
-- the overworld dialogue box. This is the Phase 2 "text window box drawing"
-- checklist item, separate from Font.lua's glyph rendering.
--
-- gStdTextWindow_Gfx (pokefirered src/text_window_graphics.c) is an
-- uncompressed 4bpp graphic, 0x120 (288) bytes = 9 real 8x8 tiles: the
-- classic 3x3-corner/edge border set. gTextWindowPalettes[3] (also real
-- C source, GetTextWindowPalette(3) via LoadStdWindowGfx) is the palette
-- the standard frame actually uses at runtime.
--
-- The tile placement isn't guessed -- it's transcribed directly from the
-- real C source, WindowFunc_DrawStandardFrame (src/new_menu_helpers.c):
-- given a tilemapLeft/tilemapTop/width/height (the window's *content*
-- rect, in tiles), the border is drawn one tile outside that rect on all
-- sides using STD_WINDOW_BASE_TILE_NUM+0..8, skipping tile index 4 (the
-- content area itself isn't filled by this function -- that's the actual
-- window/message content, drawn separately). Tile layout:
--   0=top-left corner     1=top edge (repeated)      2=top-right corner
--   3=left edge (repeated)  [4 unused -- interior]    5=right edge (repeated)
--   6=bottom-left corner   7=bottom edge (repeated)   8=bottom-right corner

local GbaGraphics = require("import.GbaGraphics")

local TextWindow = {}

TextWindow.TILE_SIZE = 8
TextWindow.STD_PALETTE_INDEX = 3 -- gTextWindowPalettes[3], see LoadStdWindowGfx

-- data: full ROM bytes. gfxOffset: 0-based offset of gStdTextWindow_Gfx.
-- Returns the 9 decoded tiles (each a 64-entry 4bpp pixel-index array, 0-15).
function TextWindow.decodeFrameTiles(data, gfxOffset)
  return GbaGraphics.decodeTiles(data, gfxOffset, 9)
end

-- data: full ROM bytes. palettesOffset: 0-based offset of
-- gTextWindowPalettes (an array of 16-color palettes). index: which
-- palette (TextWindow.STD_PALETTE_INDEX for the standard frame).
function TextWindow.decodePalette(data, palettesOffset, index)
  return GbaGraphics.decodePalette(data, palettesOffset + index * 32)
end

-- Composites a bordered box around a contentWidth x contentHeight (in
-- tiles) interior. Returns a { width, height, getPixel } image spanning
-- (contentWidth+2)*8 x (contentHeight+2)*8 pixels -- the interior is left
-- fully transparent (alpha=0) so callers can layer window content (e.g.
-- Font.renderString output) on top, matching how the real frame-drawing
-- function never touches the content tiles itself.
function TextWindow.compositeFrame(tiles, palette, contentWidthTiles, contentHeightTiles)
  local TS = TextWindow.TILE_SIZE
  local cols = contentWidthTiles + 2
  local rows = contentHeightTiles + 2

  -- tileAt(col, row) -> tile index (1-9, GbaGraphics 0-indexed tiles table
  -- uses [0]..[8]) or nil for the transparent interior, per
  -- WindowFunc_DrawStandardFrame's layout.
  local function tileIndexAt(col, row)
    local isLeftEdge = col == 0
    local isRightEdge = col == cols - 1
    local isTopEdge = row == 0
    local isBottomEdge = row == rows - 1
    if isTopEdge and isLeftEdge then return 0 end
    if isTopEdge and isRightEdge then return 2 end
    if isBottomEdge and isLeftEdge then return 6 end
    if isBottomEdge and isRightEdge then return 8 end
    if isTopEdge then return 1 end
    if isBottomEdge then return 7 end
    if isLeftEdge then return 3 end
    if isRightEdge then return 5 end
    return nil -- interior: real code leaves this to the window's own content
  end

  return {
    width = cols * TS,
    height = rows * TS,
    getPixel = function(x, y)
      local col, row = math.floor(x / TS), math.floor(y / TS)
      local tileIdx = tileIndexAt(col, row)
      if tileIdx == nil then return { r = 0, g = 0, b = 0, a = 0 } end
      local tile = tiles[tileIdx]
      local px, py = x % TS, y % TS
      local paletteIndex = tile[py * TS + px]
      if paletteIndex == 0 then return { r = 0, g = 0, b = 0, a = 0 } end -- index 0 is always transparent (GBA convention)
      local color = palette[paletteIndex]
      return { r = color.r, g = color.g, b = color.b, a = 1 }
    end,
  }
end

return TextWindow
