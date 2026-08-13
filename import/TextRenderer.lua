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
--
-- Also acts on the remaining control codes real RenderFont's
-- EXT_CTRL_CODE_BEGIN switch (src/text.c, confirmed against the actual
-- switch/case, not guessed) handles that were previously parsed-but-
-- ignored here:
--   * EXT_CTRL_CODE_SHIFT_RIGHT (0x0D)/SHIFT_DOWN (0x0E): real behavior
--     sets currentX/currentY to an *absolute* position
--     (`textPrinter->printerTemplate.x + param`), not a relative offset
--     from the current cursor -- ported the same way (this renderer has
--     no separate window-origin x/y, so the real formula collapses to
--     `cursorX/cursorY = param`).
--   * EXT_CTRL_CODE_FILL_WINDOW (0x0F): real code calls
--     FillWindowPixelBuffer(windowId, PIXEL_FILL(bgColor)), which wipes
--     the *entire* window's pixel buffer to the current highlight color
--     and resets nothing else. Ported as "discard every glyph placed so
--     far and reset the cursor to (0,0)" -- the erase-everything part of
--     the real behavior. The actual highlight-colored fill isn't
--     reproduced because this renderer never paints an opaque background
--     (see the color-token handling below, an existing scope boundary,
--     not a new one introduced here).
--   * EXT_CTRL_CODE_CLEAR (0x11)/CLEAR_TO (0x13): both real codes call
--     ClearTextSpan(textPrinter, width) then advance currentX -- but
--     ClearTextSpan's real function body (src/text_printer.c) is
--     *empty*, i.e. on real hardware these codes only ever move the
--     cursor forward and never actually clear any pixels. Ported
--     faithfully as cursor-advance-only, matching that real no-op.
--   * Sound cues (EXT_CTRL_CODE_WAIT_SE 0x0A, PLAY_BGM 0x0B, PLAY_SE
--     0x10, PAUSE_MUSIC 0x17, RESUME_MUSIC 0x18): no audio mixer is
--     wired into text rendering yet, so these don't play anything --
--     instead, if the caller passes an `onSoundCue(kind, params)`
--     callback, it's invoked with a descriptive kind string
--     ("wait_se"/"play_bgm"/"play_se"/"pause_music"/"resume_music") and
--     the code's raw parameter bytes, letting a future audio-wired
--     caller act on it without this module needing to know how.
--   * {PLAYER}/{RIVAL}/{STR_VAR_1/2/3} placeholders (0xFD subcodes):
--     real FireRed expands these via a separate preprocessing pass
--     (StringExpandPlaceholders, src/string_util.c) *before* the text
--     printer ever sees the string -- by the time RenderFont's own
--     PLACEHOLDER_BEGIN case runs, expansion has already happened, so
--     that case is just a 1-byte skip. This project has no player-
--     name/save-data system to expand against, so the caller passes an
--     optional `substitutions` table (e.g. {PLAYER = "RED"}) and this
--     module does the substitution itself at render time. With no
--     substitution given for a placeholder, it falls back to rendering
--     the raw placeholder name in real parenthesis glyphs, e.g. "(PLAYER)"
--     -- reusing Charmap.decode's established bracketed-placeholder
--     convention (which renders "{PLAYER}" in its debug string), but
--     substituting "(" "..." ")" for "{" "..." "}" because curly braces
--     aren't glyphs FireRed's real charmap defines (0x5C/0x5D, which
--     *are* real charmap glyphs, are used instead). Any character in a
--     substitution or fallback name without a real charmap glyph (e.g.
--     "_" in "STR_VAR_1") renders as a space, the same "renderer decides
--     what to do with a glyph id it can't represent" policy
--     Charmap.tokenize's header already documents for raw glyph ids.

local Font = require("import.Font")
local Charmap = require("import.Charmap")

local TextRenderer = {}

TextRenderer.DEFAULT_FG = 1 -- TEXT_COLOR_WHITE
TextRenderer.DEFAULT_SHADOW = 3 -- TEXT_COLOR_LIGHT_GRAY
local GLYPH_ROW_HEIGHT = 16 -- Font.lua glyph cell height

-- EXT_CTRL_CODE_* subcode values (charmap.txt / src/text.c), for the
-- "control" tokens this module now acts on.
local CTRL_SHIFT_RIGHT = 0x0D
local CTRL_SHIFT_DOWN = 0x0E
local CTRL_FILL_WINDOW = 0x0F
local CTRL_CLEAR = 0x11
local CTRL_CLEAR_TO = 0x13
local SOUND_CUE_KINDS = {
  [0x0A] = "wait_se",
  [0x0B] = "play_bgm",
  [0x10] = "play_se",
  [0x17] = "pause_music",
  [0x18] = "resume_music",
}

-- Reverse of Charmap.BYTE_TO_CHAR (single-character UTF-8 -> charmap byte),
-- built once. Where multiple bytes decode to the same character
-- (charmap.txt has a couple, per Charmap.lua's header comment), the
-- lowest byte value wins, iterating in ascending byte order.
local CHAR_TO_BYTE = {}
for b = 0x00, 0xFF do
  local ch = Charmap.BYTE_TO_CHAR[b]
  if ch ~= nil and CHAR_TO_BYTE[ch] == nil then
    CHAR_TO_BYTE[ch] = b
  end
end
local SPACE_BYTE = 0x00

-- Appends "char" placedGlyphs entries for each character of `text` (plain
-- ASCII expected -- see header comment) at the given starting cursor
-- position, returning the new cursorX. Shared by placeholder substitution
-- and fallback-name rendering below.
local function placeText(data, addrs, placedGlyphs, text, cursorX, cursorY, fg, shadow)
  for i = 1, #text do
    local ch = text:sub(i, i)
    local glyphId = CHAR_TO_BYTE[ch] or SPACE_BYTE
    local pixelTypes = Font.decodeGlyphPixelTypes(data, addrs.sFontHalfRowOffsets, addrs.sFontNormalLatinGlyphs, glyphId)
    local w = string.byte(data, addrs.sFontNormalLatinGlyphWidths + glyphId + 1)
    placedGlyphs[#placedGlyphs + 1] = {
      x = cursorX, y = cursorY, pixelTypes = pixelTypes, width = w,
      fgColor = fg, shadowColor = shadow,
    }
    cursorX = cursorX + w + 1
  end
  return cursorX
end

-- data: full ROM bytes. addrs: RomAddresses entry (needs
-- sFontHalfRowOffsets/sFontNormalLatinGlyphs/sFontNormalLatinGlyphWidths).
-- tokens: Charmap.tokenize() output. palette: a decoded 16-color palette
-- (TextWindow.decodePalette or GbaGraphics.decodePalette), indexed by the
-- TEXT_COLOR_* slot convention above.
-- substitutions (optional): { PLAYER = "RED", ... } for {PLACEHOLDER}
-- tokens -- see header comment for the no-substitution fallback.
-- onSoundCue (optional): function(kind, params) called instead of
-- playing anything when a sound-cue control code is hit -- see header.
-- Returns { width, height, getPixel } like Font.renderString, but
-- multi-line (newline tokens start a new row) and with the fg/shadow
-- color actually changing partway through where "color" tokens appear.
function TextRenderer.renderTokens(data, addrs, tokens, palette, substitutions, onSoundCue)
  local fg, shadow = TextRenderer.DEFAULT_FG, TextRenderer.DEFAULT_SHADOW
  local cursorX, cursorY = 0, 0
  local maxWidth, maxBottom = 0, GLYPH_ROW_HEIGHT
  -- placedGlyphs: { x, y, pixelTypes, width, fgColor, shadowColor }
  local placedGlyphs = {}

  local function trackExtent()
    if cursorX > maxWidth then maxWidth = cursorX end
    if cursorY + GLYPH_ROW_HEIGHT > maxBottom then maxBottom = cursorY + GLYPH_ROW_HEIGHT end
  end

  for _, token in ipairs(tokens) do
    if token.type == "char" then
      local pixelTypes = Font.decodeGlyphPixelTypes(data, addrs.sFontHalfRowOffsets, addrs.sFontNormalLatinGlyphs, token.glyphId)
      local w = string.byte(data, addrs.sFontNormalLatinGlyphWidths + token.glyphId + 1)
      placedGlyphs[#placedGlyphs + 1] = {
        x = cursorX, y = cursorY, pixelTypes = pixelTypes, width = w,
        fgColor = palette[fg], shadowColor = palette[shadow],
      }
      cursorX = cursorX + w + 1
      trackExtent()
    elseif token.type == "newline" then
      cursorX = 0
      cursorY = cursorY + GLYPH_ROW_HEIGHT
      trackExtent()
    elseif token.type == "color" then
      if token.fg ~= nil then fg = token.fg end
      if token.shadow ~= nil then shadow = token.shadow end
      -- token.hl (highlight/background) isn't acted on: normal text
      -- rendering keeps the background transparent (TEXT_COLOR_TRANSPARENT)
      -- regardless -- an opaque highlight box behind text isn't
      -- implemented, matching Font.lua's glyph decode which only ever
      -- treats pixel type 0 as "fully transparent," not "a solid color."
    elseif token.type == "placeholder" then
      local text = substitutions and substitutions[token.name]
      if text == nil then text = "(" .. token.name .. ")" end
      cursorX = placeText(data, addrs, placedGlyphs, text, cursorX, cursorY, palette[fg], palette[shadow])
      trackExtent()
    elseif token.type == "control" then
      if token.sub == CTRL_SHIFT_RIGHT then
        cursorX = token.params[1] or cursorX
        trackExtent()
      elseif token.sub == CTRL_SHIFT_DOWN then
        cursorY = token.params[1] or cursorY
        trackExtent()
      elseif token.sub == CTRL_FILL_WINDOW then
        -- Real FillWindowPixelBuffer wipes the whole window; ported as
        -- "forget everything drawn so far" (see header comment).
        placedGlyphs = {}
        cursorX, cursorY = 0, 0
        maxWidth, maxBottom = 0, GLYPH_ROW_HEIGHT
      elseif token.sub == CTRL_CLEAR then
        -- Real ClearTextSpan is an empty function -- cursor-advance only.
        local width = token.params[1] or 0
        if width > 0 then
          cursorX = cursorX + width
          trackExtent()
        end
      elseif token.sub == CTRL_CLEAR_TO then
        local target = token.params[1] or cursorX
        if target > cursorX then
          cursorX = target
          trackExtent()
        end
      else
        local kind = SOUND_CUE_KINDS[token.sub]
        if kind and onSoundCue then
          onSoundCue(kind, token.params)
        end
        -- Any other control code (PAUSE/PAUSE_UNTIL_PRESS handled by
        -- TextPrinterState.lua before tokens reach here; FONT/PALETTE/
        -- MIN_LETTER_SPACING/JPN/ENG/etc. have no visible effect this
        -- renderer needs to reproduce) is silently skipped, same as
        -- before.
      end
    end
  end

  return {
    width = maxWidth,
    height = maxBottom,
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
