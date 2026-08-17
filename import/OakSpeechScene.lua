-- Composites the real Professor Oak intro scene (pokefirered
-- src/oak_speech.c) -- the still frame the player actually sees during
-- Task_OakSpeech_Init -> Task_OakSpeech_WelcomeToTheWorld: the gradient
-- background layer, Oak's picture, and the narration dialogue box.
--
-- This is the "Oak intro scene" Phase 2 checklist sub-item, previously
-- only covering the narration *text* (gOakSpeech_Text_WelcomeToTheWorld
-- decoded through Charmap/Font). This module adds the two graphics layers
-- underneath it and the real dialogue frame around it.
--
-- ----------------------------------------------------------------------
-- What the real source actually says (read, not guessed)
-- ----------------------------------------------------------------------
--
-- Oak is NOT a sprite. This is the single most important thing to get
-- right here, and it contradicts the obvious assumption. There is no
-- object-event graphicsId for him in this scene and he does not come out
-- of gTrainerFrontPicTable. src/oak_speech.c's Task_OakSpeech_Init calls
-- `LoadTrainerPic(OAK_PIC, 0)`, and LoadTrainerPic's OAK_PIC case is:
--
--     LoadPalette(sOakSpeech_Oak_Pal, BG_PLTT_ID(6), sizeof(...));
--     LZ77UnCompVram(sOakSpeech_Oak_Tiles, (void *)VRAM + 0x600 + tileOffset);
--
-- i.e. a file-static LZ77-compressed *8bpp* picture blitted straight into
-- BG2's character base, then mapped in as a plain tile rect:
--
--     CopyRectToBgTilemapBufferRect(2, tilemap, 0, 0, 8, 12,   -- src 8x12
--                                   11, 2, 8, 12,              -- dest 11,2
--                                   16, (tileOffset / 64) + 24, 0);
--
-- with the src tilemap being the trivial `for (i = 0; i < 0x60; i++)
-- tilemap[i] = i` ramp. So: 96 tiles, laid out 8 wide x 12 tall at tile
-- (11,2) = pixel (88,16), 64x96px. The `+ 24` base and the `VRAM + 0x600`
-- destination agree exactly (0x600 / 64 bytes-per-8bpp-tile = 24), which
-- is the cross-check that this really is 8bpp and not 4bpp.
--
-- BG2's `struct BgTemplate` (sBgTemplates) confirms it independently:
-- .paletteMode = 1 (256-color), .priority = 1. It is the only 8bpp layer
-- in the scene -- the same situation as the title screen logo, which is
-- why GbaGraphics already has decodeTiles8bpp/decodeFlatPalette.
--
-- The background is likewise NOT a MapCompositor map -- it is a fixed,
-- non-scrolling BG1 layer (ChangeBgX/Y(1, 0, BG_COORD_SET)), loaded once
-- in Task_OakSpeech_Init as
--     LoadBgTiles(1, MallocAndDecompress(sOakSpeech_Background_Tiles), ...)
--     CopyToBgTilemapBuffer(1, sOakSpeech_Background_Tilemap, 0, 0)
-- and it is genuinely tiny: 10 tiles total, and its 32x20 tilemap is
-- constant across each row -- a horizontal banding/gradient backdrop
-- (rows 0-7 tile 8, row 8-9 tile 7, then 6, 5, 4, 3, and rows 14-19 tile
-- 2), all palette bank 0, no flips.
--
-- The dialogue box is sIntro_WindowTemplates[WIN_INTRO_TEXTBOX]:
-- bg0 (priority 0, front), tilemapLeft 1, tilemapTop 4, width 28,
-- height 15, paletteNum 15. OakSpeechPrintMessage does
-- DrawDialogueFrame(WIN_INTRO_TEXTBOX, FALSE) -- which draws the frame
-- via WindowFunc_DrawDialogueFrame and then FillWindowPixelBuffer(...,
-- PIXEL_FILL(1)), i.e. floods the whole 28x15 content rect with color 1
-- of window palette 15 -- and then prints with
-- AddTextPrinterParameterized2(..., FONT_MALE, ..., TEXT_COLOR_DARK_GRAY,
-- TEXT_COLOR_WHITE, TEXT_COLOR_LIGHT_GRAY) at printer x=0, y=1.
--
-- Note the real frame is only 5 tile-rows tall (WindowFunc_DrawDialogueFrame
-- hardcodes rows tilemapTop-1 .. tilemapTop+4 regardless of the window's
-- declared height) while the white content fill is the full 15 rows, and
-- the fill is applied *after* the frame -- so the frame's bottom edge
-- across columns 1..28 is immediately painted over by the window itself.
-- That asymmetry is real, transcribed from the source, not a bug here.
--
-- ----------------------------------------------------------------------
-- Verified against real ROM bytes
-- ----------------------------------------------------------------------
--
-- All five oak_speech graphics symbols (see RomAddresses.lua) are
-- file-static, so they were located with `nm pokefirered.elf` and then
-- confirmed byte-for-byte: the ROM bytes at each address, for exactly the
-- length implied by the next symbol, sha1-hash identical to the matching
-- built asset in the decomp tree (graphics/oak_speech/bg_tiles.gbapal,
-- oak_speech_bg.4bpp.lz, oak_speech_bg.bin.lz, oak/pal.gbapal,
-- oak/pic.8bpp.lz). The decompressed sizes are then checked at runtime by
-- oak_speech_scene_test.lua (320 / 1280 / 6144 bytes).
--
-- Oak's 8bpp pixel bytes are only ever 0 or 97..121 -- entirely inside the
-- 96..127 window that BG_PLTT_ID(6) + a 32-color palette occupies, which
-- is what proves the BG_PLTT_ID(6) base offset is being applied correctly
-- rather than the picture being palette-index-0-based.
--
-- ----------------------------------------------------------------------
-- Not implemented here (deliberate scope boundary)
-- ----------------------------------------------------------------------
--
-- * The Nidoran-F release/return beat (CreateNidoranFSprite +
--   CreatePokeballSpriteToReleaseMon + the cry), the platform sprites
--   (CreatePikachuOrPlatformSprites, SPRITE_TYPE_PLATFORM -- three OBJs
--   at y=112), and the fade-in (BeginNormalPaletteFade) / 80-frame hold.
--   This module is the static frame; those are OBJ + choreography work.
-- * Player naming, gender select, rival naming -- not reachable.
-- * The text printer's per-character reveal: this renders the full
--   message at once (TextPrinterState.lua already models the reveal
--   separately and can drive the token list).

local Lz77 = require("import.Lz77")
local GbaGraphics = require("import.GbaGraphics")
local Charmap = require("import.Charmap")
local TextRenderer = require("import.TextRenderer")

local OakSpeechScene = {}

local floor = math.floor
local byte = string.byte

-- Real GBA visible screen. The BG1 tilemap is 32 tiles wide (rows are
-- constant so the 2 off-screen columns are the same banding anyway), and
-- the real scene setup only ever clears/uses 30x20
-- (FillBgTilemapBufferRect_Palette0(1, 0, 0, 0, 30, 20)).
OakSpeechScene.SCREEN_WIDTH = 240
OakSpeechScene.SCREEN_HEIGHT = 160
OakSpeechScene.TILE_SIZE = 8
OakSpeechScene.BG_TILEMAP_WIDTH = 32
OakSpeechScene.BG_TILEMAP_HEIGHT = 20

-- LoadTrainerPic's OAK_PIC case + the CopyRectToBgTilemapBufferRect call.
OakSpeechScene.OAK_TILES_WIDE = 8
OakSpeechScene.OAK_TILES_TALL = 12
OakSpeechScene.OAK_DEST_TILE_X = 11
OakSpeechScene.OAK_DEST_TILE_Y = 2
-- BG_PLTT_ID(6) = 6 * 16 = flat 256-color palette index 96.
OakSpeechScene.OAK_PALETTE_BASE = 96
OakSpeechScene.OAK_PALETTE_COLORS = 32
-- sOakSpeech_Background_Pals is 0x80 bytes = 64 colors = 4 banks of 16,
-- loaded at BG_PLTT_ID(0). BG1 is 4bpp so each tilemap entry picks a bank.
OakSpeechScene.BG_PALETTE_COLORS = 64

-- sIntro_WindowTemplates[WIN_INTRO_TEXTBOX].
OakSpeechScene.TEXTBOX = { left = 1, top = 4, width = 28, height = 15 }
-- AddTextPrinterParameterized2's fixed printer.x / printer.y.
OakSpeechScene.TEXT_ORIGIN_X = 0
OakSpeechScene.TEXT_ORIGIN_Y = 1
-- TEXT_COLOR_* slot indices from OakSpeechPrintMessage's real arguments.
OakSpeechScene.TEXT_FG_COLOR = 2 -- TEXT_COLOR_DARK_GRAY
OakSpeechScene.TEXT_BG_COLOR = 1 -- TEXT_COLOR_WHITE
OakSpeechScene.TEXT_SHADOW_COLOR = 3 -- TEXT_COLOR_LIGHT_GRAY
-- gMenuMessageWindow_Gfx is loaded with an 0x280-byte length = 20 4bpp
-- tiles; WindowFunc_DrawDialogueFrame only ever uses indices 0..13.
OakSpeechScene.DLG_FRAME_TILES = 20

local TRANSPARENT = { r = 0, g = 0, b = 0, a = 0 }

--------------------------------------------------------------------------
-- Small shared pixel-grid helpers (pixels[y][x] = {r,g,b,a}), same shape
-- as TitleScreen.lua's so the two composite the same way.
--------------------------------------------------------------------------

local function toImage(pixels, opaqueBase)
  local empty = { r = 0, g = 0, b = 0, a = opaqueBase and 1 or 0 }
  return {
    width = OakSpeechScene.SCREEN_WIDTH,
    height = OakSpeechScene.SCREEN_HEIGHT,
    getPixel = function(x, y)
      local row = pixels[y]
      return (row and row[x]) or empty
    end,
  }
end

local function plot(pixels, x, y, color)
  if x < 0 or y < 0 or x >= OakSpeechScene.SCREEN_WIDTH or y >= OakSpeechScene.SCREEN_HEIGHT then
    return
  end
  pixels[y] = pixels[y] or {}
  pixels[y][x] = { r = color.r, g = color.g, b = color.b, a = 1 }
end

-- Draws one decoded 4bpp tile (64-entry index array) at tile coords,
-- honoring the GBA "palette index 0 is transparent" convention and
-- optional H/V flip (the real tilemap entry bits).
local function drawTile4bpp(pixels, tile, palette, tileX, tileY, hFlip, vFlip)
  local TS = OakSpeechScene.TILE_SIZE
  for py = 0, TS - 1 do
    for px = 0, TS - 1 do
      local sx = hFlip and (TS - 1 - px) or px
      local sy = vFlip and (TS - 1 - py) or py
      local idx = tile[sy * TS + sx]
      if idx ~= 0 then
        plot(pixels, tileX * TS + px, tileY * TS + py, palette[idx])
      end
    end
  end
end

--------------------------------------------------------------------------
-- BG1: the banded gradient backdrop (priority 2, furthest back)
--------------------------------------------------------------------------

-- Returns the 64-color flat palette block the real game loads at
-- BG_PLTT_ID(0); index it as palette[bank * 16 + colorIndex].
function OakSpeechScene.decodeBackgroundPalettes(data, addrs)
  return GbaGraphics.decodeFlatPalette(data, addrs.sOakSpeech_Background_Pals, OakSpeechScene.BG_PALETTE_COLORS)
end

-- Returns { tiles, tilemapRaw, palettes } -- the raw decoded pieces, so a
-- test can assert on decompressed sizes / tilemap contents without
-- re-running the whole composite.
function OakSpeechScene.decodeBackground(data, addrs)
  local tilesRaw, tilesErr = Lz77.decompress(data, addrs.sOakSpeech_Background_Tiles + 1)
  if not tilesRaw then error("oak speech background tiles decompression failed: " .. tostring(tilesErr)) end
  local mapRaw, mapErr = Lz77.decompress(data, addrs.sOakSpeech_Background_Tilemap + 1)
  if not mapRaw then error("oak speech background tilemap decompression failed: " .. tostring(mapErr)) end
  return {
    tiles = GbaGraphics.decodeTiles(tilesRaw, 0, floor(#tilesRaw / 32)),
    tilesRaw = tilesRaw,
    tilemapRaw = mapRaw,
    palettes = OakSpeechScene.decodeBackgroundPalettes(data, addrs),
  }
end

function OakSpeechScene.compositeBackground(data, addrs)
  local bg = OakSpeechScene.decodeBackground(data, addrs)
  local pixels = {}
  for ty = 0, OakSpeechScene.BG_TILEMAP_HEIGHT - 1 do
    for tx = 0, OakSpeechScene.BG_TILEMAP_WIDTH - 1 do
      local i = (ty * OakSpeechScene.BG_TILEMAP_WIDTH + tx) * 2
      local b1, b2 = byte(bg.tilemapRaw, i + 1), byte(bg.tilemapRaw, i + 2)
      if not (b1 and b2) then error(("bg tilemap read ran past end at tile %d,%d"):format(tx, ty)) end
      local entry = b1 + b2 * 256
      local tileId = entry % 1024
      local hFlip = floor(entry / 1024) % 2 == 1
      local vFlip = floor(entry / 2048) % 2 == 1
      local bank = floor(entry / 4096)
      local tile = bg.tiles[tileId]
      if tile then
        -- 4bpp: the entry's palette nibble picks a 16-color bank inside
        -- the 64-color block loaded at BG_PLTT_ID(0). (This scene's real
        -- tilemap only ever uses bank 0, but the nibble is honored rather
        -- than assumed so the decode is the general one.)
        local palette = {}
        for c = 0, 15 do palette[c] = bg.palettes[bank * 16 + c] end
        drawTile4bpp(pixels, tile, palette, tx, ty, hFlip, vFlip)
      end
    end
  end
  return toImage(pixels, true) -- back-most layer: always opaque
end

--------------------------------------------------------------------------
-- BG2: Oak's picture (priority 1) -- 8bpp, palette based at index 96
--------------------------------------------------------------------------

-- Returns { tiles, palette } where tiles is the 96-entry 8bpp tile list
-- (row-major, 8 wide) and palette is the 32-color block loaded at
-- BG_PLTT_ID(6). Pixel byte b maps to palette[b - OAK_PALETTE_BASE].
function OakSpeechScene.decodeOakPic(data, addrs)
  local raw, err = Lz77.decompress(data, addrs.sOakSpeech_Oak_Tiles + 1)
  if not raw then error("oak pic decompression failed: " .. tostring(err)) end
  local expected = OakSpeechScene.OAK_TILES_WIDE * OakSpeechScene.OAK_TILES_TALL * 64
  if #raw ~= expected then
    error(("oak pic decompressed to %d bytes, expected %d (8x12 8bpp tiles)"):format(#raw, expected))
  end
  return {
    tiles = GbaGraphics.decodeTiles8bpp(raw, 0, OakSpeechScene.OAK_TILES_WIDE * OakSpeechScene.OAK_TILES_TALL),
    raw = raw,
    palette = GbaGraphics.decodeFlatPalette(data, addrs.sOakSpeech_Oak_Pal, OakSpeechScene.OAK_PALETTE_COLORS),
  }
end

-- Transparent everywhere Oak isn't, so it layers over the background.
function OakSpeechScene.compositeOakPic(data, addrs)
  local oak = OakSpeechScene.decodeOakPic(data, addrs)
  local TS = OakSpeechScene.TILE_SIZE
  local base = OakSpeechScene.OAK_PALETTE_BASE
  local pixels = {}
  for i = 0, OakSpeechScene.OAK_TILES_WIDE * OakSpeechScene.OAK_TILES_TALL - 1 do
    -- The real src tilemap is the identity ramp tilemap[i] = i, so tile i
    -- lands at (destX + i % 8, destY + i / 8).
    local tileX = OakSpeechScene.OAK_DEST_TILE_X + (i % OakSpeechScene.OAK_TILES_WIDE)
    local tileY = OakSpeechScene.OAK_DEST_TILE_Y + floor(i / OakSpeechScene.OAK_TILES_WIDE)
    local tile = oak.tiles[i]
    for py = 0, TS - 1 do
      for px = 0, TS - 1 do
        local idx = tile[py * TS + px]
        if idx ~= 0 then
          local color = oak.palette[idx - base]
          if not color then
            error(("oak pic pixel index %d falls outside the 32 colors loaded at BG_PLTT_ID(6) (%d..%d)")
              :format(idx, base, base + OakSpeechScene.OAK_PALETTE_COLORS - 1))
          end
          plot(pixels, tileX * TS + px, tileY * TS + py, color)
        end
      end
    end
  end
  return toImage(pixels, false)
end

--------------------------------------------------------------------------
-- BG0: the dialogue frame + white message panel + narration text
--------------------------------------------------------------------------

-- Transcribed one-for-one from WindowFunc_DrawDialogueFrame's non-signpost
-- branch (src/new_menu_helpers.c). Each entry is
-- {tileIndex, colOffsetExpr, rowOffset, spanWidth, vFlip}, where the
-- column is resolved against (left, width) below. `spanWidth = nil` means
-- a single tile; the two full-width runs use the window's width.
--
-- Real layout, with L = tilemapLeft, T = tilemapTop, W = width:
--   row T-1: (L-2)=0  (L-1)=1  [L..L+W-1]=2  (L+W)=3  (L+W+1)=4
--   row T+0: (L-2)=5  (L-1)=6                (L+W)=8  (L+W+1)=9
--   row T+1: (L-2)=10 (L-1)=11               (L+W)=12 (L+W+1)=13
--   row T+2: vflip of row T+1's tiles
--   row T+3: vflip of row T+0's tiles
--   row T+4: vflip of row T-1's tiles
-- (Tile 7 is never used by this function -- that gap is in the real code.)
local DLG_FRAME_LAYOUT = {
  { tile = 0,  col = "L-2",   row = -1 },
  { tile = 1,  col = "L-1",   row = -1 },
  { tile = 2,  col = "L",     row = -1, span = true },
  { tile = 3,  col = "L+W",   row = -1 },
  { tile = 4,  col = "L+W+1", row = -1 },
  { tile = 5,  col = "L-2",   row = 0 },
  { tile = 6,  col = "L-1",   row = 0 },
  { tile = 8,  col = "L+W",   row = 0 },
  { tile = 9,  col = "L+W+1", row = 0 },
  { tile = 10, col = "L-2",   row = 1 },
  { tile = 11, col = "L-1",   row = 1 },
  { tile = 12, col = "L+W",   row = 1 },
  { tile = 13, col = "L+W+1", row = 1 },
  { tile = 10, col = "L-2",   row = 2, vFlip = true },
  { tile = 11, col = "L-1",   row = 2, vFlip = true },
  { tile = 12, col = "L+W",   row = 2, vFlip = true },
  { tile = 13, col = "L+W+1", row = 2, vFlip = true },
  { tile = 5,  col = "L-2",   row = 3, vFlip = true },
  { tile = 6,  col = "L-1",   row = 3, vFlip = true },
  { tile = 8,  col = "L+W",   row = 3, vFlip = true },
  { tile = 9,  col = "L+W+1", row = 3, vFlip = true },
  { tile = 0,  col = "L-2",   row = 4, vFlip = true },
  { tile = 1,  col = "L-1",   row = 4, vFlip = true },
  { tile = 2,  col = "L",     row = 4, span = true, vFlip = true },
  { tile = 3,  col = "L+W",   row = 4, vFlip = true },
  { tile = 4,  col = "L+W+1", row = 4, vFlip = true },
}

local function resolveCol(expr, L, W)
  if expr == "L-2" then return L - 2 end
  if expr == "L-1" then return L - 1 end
  if expr == "L" then return L end
  if expr == "L+W" then return L + W end
  if expr == "L+W+1" then return L + W + 1 end
  error("unknown dialogue frame column expression: " .. tostring(expr))
end

OakSpeechScene.DLG_FRAME_LAYOUT = DLG_FRAME_LAYOUT

-- gMenuMessageWindow_Gfx (20 uncompressed 4bpp tiles) + gTextWindowPalettes
-- bank 0 -- exactly what LoadMenuMessageWindowGfx pairs, and what
-- DLG_WINDOW_PALETTE_NUM (15) ends up holding.
function OakSpeechScene.decodeDialogueFrame(data, addrs)
  return {
    tiles = GbaGraphics.decodeTiles(data, addrs.gMenuMessageWindow_Gfx, OakSpeechScene.DLG_FRAME_TILES),
    palette = GbaGraphics.decodePalette(data, addrs.gTextWindowPalettes),
  }
end

-- tokens: Charmap.tokenize() output for the message to show, or nil to
-- draw the empty box. Returns a transparent-based layer.
function OakSpeechScene.compositeTextbox(data, addrs, tokens, substitutions)
  local frame = OakSpeechScene.decodeDialogueFrame(data, addrs)
  local win = OakSpeechScene.TEXTBOX
  local TS = OakSpeechScene.TILE_SIZE
  local pixels = {}

  -- 1. CallWindowFunction(windowId, WindowFunc_DrawDialogueFrame)
  for _, item in ipairs(DLG_FRAME_LAYOUT) do
    local col = resolveCol(item.col, win.left, win.width)
    local row = win.top + item.row
    local span = item.span and win.width or 1
    for n = 0, span - 1 do
      drawTile4bpp(pixels, frame.tiles[item.tile], frame.palette, col + n, row, false, item.vFlip or false)
    end
  end

  -- 2. FillWindowPixelBuffer(windowId, PIXEL_FILL(1)) + PutWindowTilemap:
  --    the whole 28x15 content rect floods to window-palette color 1,
  --    painting over the frame's bottom edge run (see header comment).
  local white = frame.palette[OakSpeechScene.TEXT_BG_COLOR]
  for row = win.top, win.top + win.height - 1 do
    for col = win.left, win.left + win.width - 1 do
      for py = 0, TS - 1 do
        for px = 0, TS - 1 do
          plot(pixels, col * TS + px, row * TS + py, white)
        end
      end
    end
  end

  -- 3. AddTextPrinterParameterized2 at printer (x=0, y=1) inside the
  --    window, dark gray on white with a light gray shadow.
  if tokens then
    -- TextRenderer resolves glyph colors by TEXT_COLOR_* slot index and
    -- starts from its own defaults (fg = TEXT_COLOR_WHITE). Rather than
    -- change that shared module's signature, the palette handed to it has
    -- slot 1 remapped to the real TEXT_COLOR_DARK_GRAY color, which is
    -- what this printer call actually asks for. Safe here specifically
    -- because gOakSpeech_Text_WelcomeToTheWorld contains no mid-string
    -- color control codes (verified by tokenizing it -- see the test), so
    -- nothing else ever reads slot 1.
    local printerPalette = {}
    for i = 0, 15 do printerPalette[i] = frame.palette[i] end
    printerPalette[TextRenderer.DEFAULT_FG] = frame.palette[OakSpeechScene.TEXT_FG_COLOR]
    printerPalette[TextRenderer.DEFAULT_SHADOW] = frame.palette[OakSpeechScene.TEXT_SHADOW_COLOR]

    local text = TextRenderer.renderTokens(data, addrs, tokens, printerPalette, substitutions)
    local originX = win.left * TS + OakSpeechScene.TEXT_ORIGIN_X
    local originY = win.top * TS + OakSpeechScene.TEXT_ORIGIN_Y
    for y = 0, text.height - 1 do
      for x = 0, text.width - 1 do
        local p = text.getPixel(x, y)
        if p.a ~= 0 then plot(pixels, originX + x, originY + y, p) end
      end
    end
  end

  return toImage(pixels, false)
end

--------------------------------------------------------------------------
-- Full scene
--------------------------------------------------------------------------

-- Reads and tokenizes the real opening narration
-- (gOakSpeech_Text_WelcomeToTheWorld), the message
-- Task_OakSpeech_WelcomeToTheWorld prints.
function OakSpeechScene.narrationTokens(data, addrs)
  local raw = data:sub(addrs.gOakSpeech_Text_WelcomeToTheWorld + 1,
                       addrs.gOakSpeech_Text_WelcomeToTheWorld + 300)
  return Charmap.tokenize(raw)
end

-- opts.withText (default true): false gives the frame the player sees
-- during Task_OakSpeech_Init's real 80-tick hold after the fade-in, when
-- Oak is on screen but no message has been printed yet.
-- opts.withOak (default true): false reproduces the gender-prompt state
-- after Task_OakSpeech_FadeOutOak has cleared BG2, while retaining the
-- real banded backdrop and BG0 message box.
-- opts.tokens: override the message shown (defaults to the real opening
-- narration).
-- opts.substitutions: optional TextRenderer placeholder values, used by
-- the post-naming confirmation prompts for {PLAYER}/{RIVAL}.
--
-- Composited back-to-front in real BG priority order: bg1 (priority 2)
-- then bg2 (priority 1) then bg0 (priority 0).
function OakSpeechScene.composite(data, addrs, opts)
  opts = opts or {}
  local withText = opts.withText
  if withText == nil then withText = true end

  local layers = { OakSpeechScene.compositeBackground(data, addrs) }
  if opts.withOak ~= false then layers[#layers + 1] = OakSpeechScene.compositeOakPic(data, addrs) end
  if withText ~= false or opts.showTextbox then
    layers[#layers + 1] = OakSpeechScene.compositeTextbox(
      data, addrs, withText ~= false and (opts.tokens or OakSpeechScene.narrationTokens(data, addrs)) or nil,
      opts.substitutions)
  end

  local pixels = {}
  for y = 0, OakSpeechScene.SCREEN_HEIGHT - 1 do
    pixels[y] = {}
    for x = 0, OakSpeechScene.SCREEN_WIDTH - 1 do
      local out = nil
      for i = #layers, 1, -1 do
        local p = layers[i].getPixel(x, y)
        if p.a ~= 0 then out = p break end
      end
      pixels[y][x] = out or { r = 0, g = 0, b = 0, a = 1 }
    end
  end
  return toImage(pixels, true)
end

return OakSpeechScene
