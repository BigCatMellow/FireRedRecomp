-- ROM-backed compositor for FireRed's real naming-screen keyboard.
--
-- Source: pokefirered src/naming_screen.c and src/keyboard_text.c.
-- Decoded from the verified ROM:
--   * gNamingScreenMenu_Gfx (shared 48-tile 4bpp set)
--   * background + upper/lower/symbols 32x20 LZ77 tilemaps
--   * six menu palettes + the keyboard text palette
--   * sNamingScreenKeyboardText's twelve pointer-resolved, control-code-
--     spaced rows (the keyboard letters are real font text, not tiles)
--   * gNamingScreenCursor_Gfx, the real 16x16 selection cursor OBJ
--
-- The PAGE/BACK/OK sprites and player/rival target icons are represented
-- by real-font labels in this bounded pass; their input roles, coordinates
-- and navigation topology are real and live. Everything else in the
-- keyboard panel is decoded from the player's verified ROM rather than
-- recreated art.

local Charmap = require("import.Charmap")
local GbaGraphics = require("import.GbaGraphics")
local Lz77 = require("import.Lz77")
local NamingScreenState = require("src.core.NamingScreenState")
local ObjectSprite = require("import.ObjectSprite")
local TextRenderer = require("import.TextRenderer")

local NamingScreenScene = {}

NamingScreenScene.SCREEN_WIDTH = 240
NamingScreenScene.SCREEN_HEIGHT = 160
NamingScreenScene.TILE_SIZE = 8
NamingScreenScene.TILEMAP_WIDTH = 32
NamingScreenScene.TILEMAP_HEIGHT = 20
NamingScreenScene.VISIBLE_TILE_WIDTH = 30

local byte, floor = string.byte, math.floor

local PAGE_TILEMAP_SYMBOL = {
  [NamingScreenState.PAGE_SYMBOLS] = "gNamingScreenKeyboardSymbols_Tilemap",
  [NamingScreenState.PAGE_UPPER] = "gNamingScreenKeyboardUpper_Tilemap",
  [NamingScreenState.PAGE_LOWER] = "gNamingScreenKeyboardLower_Tilemap",
}

-- sKeyboardChars/sNamingScreenKeyboardText use KEYBOARD_* order, unlike
-- KBPAGE_*; this is sPageToKeyboardId in table form.
local PAGE_TO_KEYBOARD = {
  [NamingScreenState.PAGE_SYMBOLS] = 2,
  [NamingScreenState.PAGE_UPPER] = 1,
  [NamingScreenState.PAGE_LOWER] = 0,
}

local function rgba(c, a)
  return { r = c.r, g = c.g, b = c.b, a = a == nil and 1 or a }
end

local function emptyPixels(fill)
  local pixels = {}
  for y = 0, NamingScreenScene.SCREEN_HEIGHT - 1 do
    pixels[y] = {}
    for x = 0, NamingScreenScene.SCREEN_WIDTH - 1 do pixels[y][x] = rgba(fill) end
  end
  return pixels
end

local function toImage(pixels)
  return {
    width = NamingScreenScene.SCREEN_WIDTH,
    height = NamingScreenScene.SCREEN_HEIGHT,
    getPixel = function(x, y)
      return (pixels[y] and pixels[y][x]) or { r=0,g=0,b=0,a=1 }
    end,
  }
end

local function decompress(data, offset, what)
  local raw, err = Lz77.decompress(data, offset + 1)
  if not raw then error(what .. " decompression failed: " .. tostring(err)) end
  return raw
end

local function flatMenuPalettes(data, addrs)
  return GbaGraphics.decodeFlatPalette(data, addrs.gNamingScreenMenu_Pal, 6 * 16)
end

local function paletteForBank(data, addrs, menu, bank)
  local out = {}
  if bank >= 0 and bank <= 5 then
    for i = 0, 15 do out[i] = menu[bank * 16 + i] end
  elseif bank == 10 then
    out = GbaGraphics.decodePalette(data, addrs.gNamingScreenKeyboard_Pal)
  elseif bank == 15 then
    -- InitStandardTextBoxWindows/InitTextBoxGfxAndPrinters supplies the
    -- palette used by the solid banner tile (background tile 15).
    out = GbaGraphics.decodePalette(data, addrs.gTextWindowPalettes)
  else
    for i = 0, 15 do out[i] = menu[i] end
  end
  return out
end

local function drawTilemap(pixels, rawMap, tiles, data, addrs, menu, overlay)
  for ty = 0, NamingScreenScene.TILEMAP_HEIGHT - 1 do
    for tx = 0, NamingScreenScene.VISIBLE_TILE_WIDTH - 1 do
      local pos = (ty * NamingScreenScene.TILEMAP_WIDTH + tx) * 2
      local entry = byte(rawMap, pos + 1) + byte(rawMap, pos + 2) * 256
      local tileId = entry % 1024
      local hFlip = floor(entry / 1024) % 2 == 1
      local vFlip = floor(entry / 2048) % 2 == 1
      local bank = floor(entry / 4096)
      local tile = tiles[tileId]
      local pal = paletteForBank(data, addrs, menu, bank)
      if tile then
        for py = 0, 7 do
          for px = 0, 7 do
            local sx = hFlip and 7 - px or px
            local sy = vFlip and 7 - py or py
            local colorIndex = tile[sy * 8 + sx]
            if colorIndex ~= 0 or not overlay then
              pixels[ty * 8 + py][tx * 8 + px] = rgba(pal[colorIndex])
            end
          end
        end
      end
    end
  end
end

local function u32le(data, offset)
  return byte(data, offset + 1) + byte(data, offset + 2) * 256
    + byte(data, offset + 3) * 65536 + byte(data, offset + 4) * 16777216
end

local function rawStringAt(data, offset, max)
  local endAt = offset
  local cap = offset + (max or 128) - 1
  while endAt <= cap and byte(data, endAt + 1) ~= Charmap.TERMINATOR do endAt = endAt + 1 end
  return data:sub(offset + 1, endAt + 1)
end

local CHAR_TO_BYTE = {}
for b = 0, 255 do
  local ch = Charmap.BYTE_TO_CHAR[b]
  if ch and #ch == 1 and not CHAR_TO_BYTE[ch] then CHAR_TO_BYTE[ch] = b end
end

local function encodeText(text)
  local out = {}
  for i = 1, #text do
    local ch = text:sub(i,i)
    -- FireRed's English apostrophe macro encodes to the same glyph byte
    -- Charmap displays typographically as U+2019.
    out[#out + 1] = string.char(ch == "'" and 0xB4 or (CHAR_TO_BYTE[ch] or 0x00))
  end
  out[#out + 1] = string.char(Charmap.TERMINATOR)
  return table.concat(out)
end

local function printerPalette(palette, fg, shadow)
  local out = {}
  for i = 0, 15 do out[i] = palette[i] end
  out[TextRenderer.DEFAULT_FG] = palette[fg]
  out[TextRenderer.DEFAULT_SHADOW] = palette[shadow]
  return out
end

local function drawText(pixels, data, addrs, raw, palette, x0, y0, fg, shadow)
  local image = TextRenderer.renderTokens(data, addrs, Charmap.tokenize(raw), printerPalette(palette, fg, shadow))
  for y = 0, image.height - 1 do
    for x = 0, image.width - 1 do
      local p = image.getPixel(x, y)
      local dx, dy = x0 + x, y0 + y
      if p.a ~= 0 and dx >= 0 and dx < NamingScreenScene.SCREEN_WIDTH and dy >= 0 and dy < NamingScreenScene.SCREEN_HEIGHT then
        pixels[dy][dx] = p
      end
    end
  end
end

function NamingScreenScene.decode(data, addrs, page)
  local gfx = decompress(data, addrs.gNamingScreenMenu_Gfx, "naming menu gfx")
  local background = decompress(data, addrs.gNamingScreenBackground_Tilemap, "naming background tilemap")
  local keyboard = decompress(data, addrs[PAGE_TILEMAP_SYMBOL[page]], "naming keyboard tilemap")
  if #gfx ~= 1536 then error("naming menu gfx must decompress to 1536 bytes, got " .. #gfx) end
  if #background ~= 1280 or #keyboard ~= 1280 then error("naming tilemaps must each decompress to 1280 bytes") end
  return {
    gfxRaw = gfx,
    backgroundRaw = background,
    keyboardRaw = keyboard,
    tiles = GbaGraphics.decodeTiles(gfx, 0, #gfx / 32),
  }
end

function NamingScreenScene.keyboardRowRaw(data, addrs, page, row)
  local keyboardId = PAGE_TO_KEYBOARD[page]
  local ptr = u32le(data, addrs.sNamingScreenKeyboardText + (keyboardId * 4 + row) * 4)
  return rawStringAt(data, ptr - 0x08000000, 96)
end

-- Reads the compact insertion table and cursor geometry directly from ROM
-- for fixture tests; the runtime state uses its source-transcribed copy so
-- it stays testable without distributing any ROM bytes.
function NamingScreenScene.decodeKeyboardFixture(data, addrs)
  local chars = {}
  for i = 0, 95 do chars[i] = byte(data, addrs.sKeyboardChars + i + 1) end
  local counts = {}
  for i = 0, 2 do counts[i] = byte(data, addrs.sPageColumnCounts + i + 1) end
  local x = {}
  for keyboard = 0, 2 do
    x[keyboard] = {}
    for col = 0, 7 do x[keyboard][col] = byte(data, addrs.sPageColumnXPos + keyboard * 8 + col + 1) end
  end
  return { chars = chars, counts = counts, columnX = x }
end

function NamingScreenScene.compositeCursor(data, addrs)
  local tiles = ObjectSprite.decodeFrameTiles(data, addrs.gNamingScreenCursor_Gfx, 2, 2, 0)
  local palette = GbaGraphics.decodePalette(data, addrs.gNamingScreenMenu_Pal + 5 * 32)
  return ObjectSprite.buildImage(tiles, palette, 2, 2)
end

-- opts.kind: "player" or "rival". opts.entryBytes is a FireRed charmap
-- buffer terminated with EOS. opts.state is NamingScreenState for page and
-- cursor. The returned 240x160 frame includes the real cursor when it is
-- over a character; button-column selection uses a real-font selector.
function NamingScreenScene.composite(data, addrs, opts)
  opts = opts or {}
  local state = assert(opts.state, "NamingScreenState is required")
  local decoded = NamingScreenScene.decode(data, addrs, state.page)
  local menu = flatMenuPalettes(data, addrs)
  local pixels = emptyPixels(menu[0])
  drawTilemap(pixels, decoded.backgroundRaw, decoded.tiles, data, addrs, menu, false)
  drawTilemap(pixels, decoded.keyboardRaw, decoded.tiles, data, addrs, menu, true)

  local textPal = GbaGraphics.decodePalette(data, addrs.gNamingScreenKeyboard_Pal)
  local title = opts.kind == "rival" and "RIVAL's NAME?" or "YOUR NAME?"
  drawText(pixels, data, addrs, encodeText(title), textPal, 73, 33, 2, 3)
  drawText(pixels, data, addrs, opts.entryBytes or string.char(0xFF), textPal, 98, 49, 2, 3)

  local keyboardId = PAGE_TO_KEYBOARD[state.page]
  local pageFg = ({ [0]=14, [1]=13, [2]=15 })[keyboardId]
  for row = 0, 3 do
    drawText(pixels, data, addrs, NamingScreenScene.keyboardRowRaw(data, addrs, state.page, row), textPal, 24, 81 + row * 16, pageFg, 2)
  end

  local nextLabel = ({
    [NamingScreenState.PAGE_SYMBOLS] = "ABC",
    [NamingScreenState.PAGE_UPPER] = "abc",
    [NamingScreenState.PAGE_LOWER] = "!?",
  })[state.page]
  drawText(pixels, data, addrs, encodeText(nextLabel), textPal, 190, 80, 2, 3)
  drawText(pixels, data, addrs, encodeText("BACK"), textPal, 186, 108, 2, 3)
  drawText(pixels, data, addrs, encodeText("OK"), textPal, 194, 132, 2, 3)

  local cursorPosX, cursorPosY = state:cursorScreenPosition()
  if cursorPosX then
    local cursor = NamingScreenScene.compositeCursor(data, addrs)
    for y = 0, cursor.height - 1 do
      for x = 0, cursor.width - 1 do
        local p = cursor.getPixel(x, y)
        local dx, dy = cursorPosX - 8 + x, cursorPosY - 8 + y
        if p.a ~= 0 and dx >= 0 and dx < NamingScreenScene.SCREEN_WIDTH and dy >= 0 and dy < NamingScreenScene.SCREEN_HEIGHT then
          pixels[dy][dx] = p
        end
      end
    end
  else
    local buttonY = ({ [0]=80, [1]=108, [2]=132 })[state.cursorY]
    drawText(pixels, data, addrs, string.char(0xEF, 0xFF), textPal, 174, buttonY, 2, 3)
  end

  return toImage(pixels)
end

return NamingScreenScene
