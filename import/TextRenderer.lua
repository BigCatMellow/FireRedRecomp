-- Renders a tokenized message (Charmap.tokenize) into one composited
-- image, acting on the real EXT_CTRL_CODE_COLOR/HIGHLIGHT/SHADOW control
-- codes as it goes (mid-string color switches -- e.g. FireRed's move-name
-- highlighting, "Rare Candy!" flavor-text emphasis) rather than just
-- showing them as bracketed placeholders like Charmap.decode does.
--
-- Color values (0-9) are TEXT_COLOR_* palette-slot indices (characters.h),
-- not RGB -- real FireRed resolves them against whatever 16-color window
-- palette is currently loaded, and by convention slot 1=white, 2=dark
-- gray, 3=light gray, 4=red, 5=light red, 6=green, 7=light green, 8=blue,
-- 9=light blue (confirmed by decoding gTextWindowPalettes[3] with
-- GbaGraphics.decodePalette: slot 1 is exactly (255,255,255), slot 2 is
-- (99,99,99), etc., across the board). So a caller passes in one already-
-- decoded 16-color palette (TextWindow.decodePalette) and this module
-- looks colors up by that same slot-index convention.
--
-- Default fg/bg/shadow (TEXT_COLOR_WHITE=1, TRANSPARENT=0, LIGHT_GRAY=3)
-- match the real default seen at every fgColor/bgColor/shadowColor
-- initialization site in src/text.c (e.g. RenderTextHandleBold's
-- `fgColor = 1; bgColor = 0; shadowColor = 3;` immediately followed by
-- the equivalent GenerateFontHalfRowLookupTable(TEXT_COLOR_WHITE,
-- TEXT_COLOR_TRANSPARENT, TEXT_COLOR_LIGHT_GRAY) call).

local Font = require("import.Font")

local TextRenderer = {}

TextRenderer.DEFAULT_FG = 1 -- TEXT_COLOR_WHITE
TextRenderer.DEFAULT_SHADOW = 3 -- TEXT_COLOR_LIGHT_GRAY
local GLYPH_ROW_HEIGHT = 16 -- Font.lua glyph cell height

-- data: full ROM bytes. addrs: RomAddresses entry (needs
-- sFontHalfRowOffsets/sFontNormalLatinGlyphs/sFontNormalLatinGlyphWidths).
-- tokens: Charmap.tokenize() output. palette: a decoded 16-color palette
-- (TextWindow.decodePalette or GbaGraphics.decodePalette), indexed by the
-- TEXT_COLOR_* slot convention above.
-- Returns { width, height, getPixel } like Font.renderString, but
-- multi-line (newline tokens start a new row) and with the fg/shadow
-- color actually changing partway through where "color" tokens appear.
function TextRenderer.renderTokens(data, addrs, tokens, palette)
  local fg, shadow = TextRenderer.DEFAULT_FG, TextRenderer.DEFAULT_SHADOW
  local cursorX, cursorY = 0, 0
  local maxWidth = 0
  -- placedGlyphs: { x, y, pixelTypes, width, fgColor, shadowColor }
  local placedGlyphs = {}

  for _, token in ipairs(tokens) do
    if token.type == "char" then
      local pixelTypes = Font.decodeGlyphPixelTypes(data, addrs.sFontHalfRowOffsets, addrs.sFontNormalLatinGlyphs, token.glyphId)
      local w = string.byte(data, addrs.sFontNormalLatinGlyphWidths + token.glyphId + 1)
      placedGlyphs[#placedGlyphs + 1] = {
        x = cursorX, y = cursorY, pixelTypes = pixelTypes, width = w,
        fgColor = palette[fg], shadowColor = palette[shadow],
      }
      cursorX = cursorX + w + 1
      if cursorX > maxWidth then maxWidth = cursorX end
    elseif token.type == "newline" then
      cursorX = 0
      cursorY = cursorY + GLYPH_ROW_HEIGHT
    elseif token.type == "color" then
      if token.fg ~= nil then fg = token.fg end
      if token.shadow ~= nil then shadow = token.shadow end
      -- token.hl (highlight/background) isn't acted on: normal text
      -- rendering keeps the background transparent (TEXT_COLOR_TRANSPARENT)
      -- regardless -- an opaque highlight box behind text isn't
      -- implemented, matching Font.lua's glyph decode which only ever
      -- treats pixel type 0 as "fully transparent," not "a solid color."
    end
    -- "control" and "placeholder" tokens (pause, wait, sound cues, {PLAYER}
    -- etc.) aren't acted on yet -- no gameplay/save state to substitute a
    -- placeholder with, and no scheduler-driven pause/wait wired into text
    -- rendering yet. They're silently skipped rather than erroring so a
    -- real message with these codes still renders the parts it can.
  end

  local totalHeight = cursorY + GLYPH_ROW_HEIGHT

  return {
    width = maxWidth,
    height = totalHeight,
    getPixel = function(x, y)
      for _, g in ipairs(placedGlyphs) do
        if x >= g.x and x < g.x + g.width and y >= g.y and y < g.y + 16 then
          local t = g.pixelTypes[y - g.y][x - g.x]
          if t == Font.GLYPH_PIXEL_TYPE_FOREGROUND then
            return { r = g.fgColor.r, g = g.fgColor.g, b = g.fgColor.b, a = 1 }
          elseif t == Font.GLYPH_PIXEL_TYPE_SHADOW then
            return { r = g.shadowColor.r, g = g.shadowColor.g, b = g.shadowColor.b, a = 1 }
          end
        end
      end
      return { r = 0, g = 0, b = 0, a = 0 }
    end,
  }
end

return TextRenderer
