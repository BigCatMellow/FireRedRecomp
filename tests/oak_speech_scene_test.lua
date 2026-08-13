-- Tests for import/OakSpeechScene.lua -- the real Professor Oak intro
-- scene frame (pokefirered src/oak_speech.c).
--
-- Two halves:
--   1. Pure-Lua structural tests (always run, no ROM needed): the
--      transcribed geometry and the DrawDialogueFrame tile layout, pinned
--      against the real C source.
--   2. ROM-integration tests (opt-in via POKEPORT_ROM, skip cleanly
--      otherwise): the five file-static oak_speech graphics symbols are
--      checked BYTE-FOR-BYTE against the sha1 of the corresponding built
--      asset in the decomp tree, then decoded and composited.
--
-- Run: POKEPORT_ROM=/path/to/verified/pokefirered.gba lua5.1 tests/oak_speech_scene_test.lua
package.path = package.path .. ";./?.lua"

local OakSpeechScene = require("import.OakSpeechScene")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

--------------------------------------------------------------------------
-- 1. Pure-Lua structural tests
--------------------------------------------------------------------------

-- LoadTrainerPic's OAK_PIC case + CopyRectToBgTilemapBufferRect(2, ..., 8,
-- 12, 11, 2, 8, 12, 16, (tileOffset / 64) + 24, 0).
check("Oak pic is 8x12 tiles", OakSpeechScene.OAK_TILES_WIDE == 8 and OakSpeechScene.OAK_TILES_TALL == 12)
check("Oak pic lands at tile (11,2)", OakSpeechScene.OAK_DEST_TILE_X == 11 and OakSpeechScene.OAK_DEST_TILE_Y == 2)
-- The real VRAM destination is VRAM + 0x600 and the real tilemap base is
-- (tileOffset / 64) + 24 -- these agree only if tiles are 64 bytes, i.e.
-- 8bpp. That consistency is the reason we decode this layer as 8bpp.
check("VRAM offset 0x600 / 64 bytes-per-8bpp-tile == the real +24 tile base", 0x600 / 64 == 24)
check("Oak palette is 32 colors based at BG_PLTT_ID(6) = 96",
  OakSpeechScene.OAK_PALETTE_BASE == 6 * 16 and OakSpeechScene.OAK_PALETTE_COLORS == 32)

-- sIntro_WindowTemplates[WIN_INTRO_TEXTBOX]
local win = OakSpeechScene.TEXTBOX
check("textbox window is bg0 tile rect (1,4) 28x15",
  win.left == 1 and win.top == 4 and win.width == 28 and win.height == 15)
-- AddTextPrinterParameterized2 always sets printer.x = 0, printer.y = 1.
check("text printer origin is (0,1) inside the window",
  OakSpeechScene.TEXT_ORIGIN_X == 0 and OakSpeechScene.TEXT_ORIGIN_Y == 1)
-- OakSpeechPrintMessage's real color arguments.
check("printer colors are DARK_GRAY on WHITE with LIGHT_GRAY shadow",
  OakSpeechScene.TEXT_FG_COLOR == 2 and OakSpeechScene.TEXT_BG_COLOR == 1 and OakSpeechScene.TEXT_SHADOW_COLOR == 3)

-- WindowFunc_DrawDialogueFrame (src/new_menu_helpers.c), non-signpost
-- branch: 26 FillBgTilemapBufferRect calls, spanning rows T-1..T+4.
local layout = OakSpeechScene.DLG_FRAME_LAYOUT
check("dialogue frame layout has the real 26 placements", #layout == 26, #layout)

local rowsSeen, tilesSeen, spans, vflips = {}, {}, 0, 0
for _, item in ipairs(layout) do
  rowsSeen[item.row] = (rowsSeen[item.row] or 0) + 1
  tilesSeen[item.tile] = true
  if item.span then spans = spans + 1 end
  if item.vFlip then vflips = vflips + 1 end
end
check("frame spans exactly rows T-1 .. T+4",
  rowsSeen[-1] == 5 and rowsSeen[0] == 4 and rowsSeen[1] == 4
  and rowsSeen[2] == 4 and rowsSeen[3] == 4 and rowsSeen[4] == 5)
-- The real function uses base+0..base+6 and base+8..base+13; base+7 is
-- genuinely never referenced (a gap in the real source, not an omission).
check("frame uses tiles 0-6 and 8-13, never tile 7",
  tilesSeen[7] == nil and tilesSeen[0] and tilesSeen[6] and tilesSeen[8] and tilesSeen[13])
for t = 0, 13 do
  if t ~= 7 then check("frame references tile " .. t, tilesSeen[t] == true) end
end
check("exactly the two full-width runs (top and bottom edges) span the window width", spans == 2, spans)
-- Rows T+2..T+4 are the v-flipped mirrors of rows T+1..T-1.
check("exactly 13 of the 26 placements are v-flipped", vflips == 13, vflips)

-- The real code draws the frame FIRST and then floods the window's whole
-- content rect -- so the frame's bottom-edge run (row T+4 = row 8) is
-- inside the window rect (rows 4..18) and gets painted over. Pin that
-- overlap so the ordering can't be silently "fixed".
check("the frame's bottom edge row falls inside the window's content rect (real overdraw)",
  win.top + 4 >= win.top and win.top + 4 <= win.top + win.height - 1)

check("screen is the real 240x160", OakSpeechScene.SCREEN_WIDTH == 240 and OakSpeechScene.SCREEN_HEIGHT == 160)

--------------------------------------------------------------------------
-- 2. ROM-integration tests
--------------------------------------------------------------------------

local romPath = os.getenv("POKEPORT_ROM")
if not romPath then
  print(("%d passed, %d failed"):format(passed, failed))
  print("SKIP: set POKEPORT_ROM=/path/to/verified/pokefirered.gba to run the ROM-integration half")
  os.exit(failed == 0 and 0 or 1)
end

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local Lz77 = require("import.Lz77")

local ok, info = RomImporter.verify(romPath)
if not ok then
  print("FAIL: ROM did not verify -- " .. tostring(info))
  os.exit(1)
end

local sha1 = RomImporter._sha1HexOfFile(romPath)
local addrs = RomAddresses[sha1]
local f = io.open(romPath, "rb")
local data = f:read("*a")
f:close()

-- Byte-for-byte ground truth. Each of these five symbols is file-static in
-- src/oak_speech.c (absent from the linker .map, located with `nm
-- pokefirered.elf`); the length is what the next symbol's address implies.
-- The expected hashes are the sha1s of the built assets in the decomp tree
-- (graphics/oak_speech/...), so a match proves the address AND the length
-- are exactly right, not merely plausible.
local function sha1OfSlice(offset, length)
  local slice = data:sub(offset + 1, offset + length)
  if #slice ~= length then return nil, ("only %d of %d bytes available"):format(#slice, length) end
  local tmp = os.tmpname()
  local out = io.open(tmp, "wb")
  out:write(slice)
  out:close()
  local hash = RomImporter._sha1HexOfFile(tmp)
  os.remove(tmp)
  return hash
end

local byteExact = {
  { "sOakSpeech_Background_Pals (bg_tiles.gbapal)", addrs.sOakSpeech_Background_Pals, 0x80,
    "41450519cbac0859353265a2b7227235b92f0990" },
  { "sOakSpeech_Background_Tiles (oak_speech_bg.4bpp.lz)", addrs.sOakSpeech_Background_Tiles, 0x44,
    "4d40747550313f5d3df8bcd12eed34e70e2f57b6" },
  { "sOakSpeech_Background_Tilemap (oak_speech_bg.bin.lz)", addrs.sOakSpeech_Background_Tilemap, 0xAC,
    "8381a15d81ff4397ffecb301e32aae24d174c24d" },
  { "sOakSpeech_Oak_Pal (oak/pal.gbapal)", addrs.sOakSpeech_Oak_Pal, 0x40,
    "4559005f3685627bcc97b2e2605e0593fe57a33f" },
  { "sOakSpeech_Oak_Tiles (oak/pic.8bpp.lz)", addrs.sOakSpeech_Oak_Tiles, 0x698,
    "20e0df0af13aea04ec4e5c8219164225eb4f097b" },
}
for _, entry in ipairs(byteExact) do
  local name, offset, length, expected = entry[1], entry[2], entry[3], entry[4]
  local got, err = sha1OfSlice(offset, length)
  check("ROM bytes match the real asset byte-for-byte: " .. name, got == expected, got or err)
end

-- Background layer: 10 4bpp tiles, 32x20 tilemap.
local bg = OakSpeechScene.decodeBackground(data, addrs)
check("background tiles decompress to 320 bytes = 10 4bpp tiles", #bg.tilesRaw == 320, #bg.tilesRaw)
check("background tilemap decompresses to 1280 bytes = 640 u16 entries", #bg.tilemapRaw == 1280, #bg.tilemapRaw)
check("background palette block is 64 colors (4 banks at BG_PLTT_ID(0))", #bg.palettes + 1 == 64, #bg.palettes + 1)

-- The real backdrop is horizontal banding: every entry in a row is
-- identical, all palette bank 0, no flips.
local rowConstant, allBank0, noFlips = true, true, true
local rowTiles = {}
for ty = 0, 19 do
  local first
  for tx = 0, 31 do
    local i = (ty * 32 + tx) * 2
    local entry = string.byte(bg.tilemapRaw, i + 1) + string.byte(bg.tilemapRaw, i + 2) * 256
    local tileId = entry % 1024
    if tx == 0 then first = tileId elseif tileId ~= first then rowConstant = false end
    if math.floor(entry / 4096) ~= 0 then allBank0 = false end
    if math.floor(entry / 1024) % 4 ~= 0 then noFlips = false end
  end
  rowTiles[ty] = first
end
check("every backdrop row is a single repeated tile (horizontal banding)", rowConstant)
check("backdrop uses only palette bank 0", allBank0)
check("backdrop uses no H/V flips", noFlips)
-- Pinned from the real decompressed oak_speech_bg.bin.
local expectedRows = { [0]=8,8,8,8,8,8,8,8,7,7,6,5,4,3,2,2,2,2,2,2 }
local rowsMatch = true
for ty = 0, 19 do if rowTiles[ty] ~= expectedRows[ty] then rowsMatch = false end end
check("backdrop row tile sequence is the real one (8x8, 7x2, 6, 5, 4, 3, 2x6)", rowsMatch,
  table.concat(rowTiles, ",", 0, 19))

-- Oak's picture: 96 8bpp tiles, palette-based at 96.
local oak = OakSpeechScene.decodeOakPic(data, addrs)
check("Oak pic decompresses to 6144 bytes = 96 8bpp tiles", #oak.raw == 6144, #oak.raw)
check("Oak palette is 32 colors", #oak.palette + 1 == 32, #oak.palette + 1)
-- Every non-transparent pixel byte must land inside the 32-color window
-- the real LoadPalette(..., BG_PLTT_ID(6), ...) occupies. This is what
-- proves the 96 base offset is real rather than assumed.
local minIdx, maxIdx, nonZero = 255, 0, 0
for i = 0, 95 do
  for p = 0, 63 do
    local v = oak.tiles[i][p]
    if v ~= 0 then
      nonZero = nonZero + 1
      if v < minIdx then minIdx = v end
      if v > maxIdx then maxIdx = v end
    end
  end
end
check("Oak pic's non-zero 8bpp indices all fall in 96..127 (BG_PLTT_ID(6) + 32 colors)",
  minIdx >= 96 and maxIdx <= 127, ("min %d max %d"):format(minIdx, maxIdx))
check("Oak pic is mostly-but-not-entirely opaque (a real picture, not a solid block)",
  nonZero > 1000 and nonZero < 6144, nonZero)

-- The palette remap OakSpeechScene uses to get dark-gray-on-white text is
-- only safe because this message has no mid-string color control codes.
local tokens = OakSpeechScene.narrationTokens(data, addrs)
local colorTokens, charTokens = 0, 0
for _, t in ipairs(tokens) do
  if t.type == "color" then colorTokens = colorTokens + 1 end
  if t.type == "char" then charTokens = charTokens + 1 end
end
check("the real narration has no mid-string color control codes", colorTokens == 0, colorTokens)
check("the real narration tokenizes to a sane number of characters", charTokens > 100 and charTokens < 200, charTokens)

-- Layer compositing.
local oakLayer = OakSpeechScene.compositeOakPic(data, addrs)
local x0, y0 = OakSpeechScene.OAK_DEST_TILE_X * 8, OakSpeechScene.OAK_DEST_TILE_Y * 8
local x1, y1 = x0 + 8 * 8 - 1, y0 + 12 * 8 - 1
check("Oak layer's real pixel rect is (88,16)-(151,111)", x0 == 88 and y0 == 16 and x1 == 151 and y1 == 111)
local outsideOpaque = 0
for y = 0, 159 do
  for x = 0, 239 do
    if (x < x0 or x > x1 or y < y0 or y > y1) and oakLayer.getPixel(x, y).a ~= 0 then
      outsideOpaque = outsideOpaque + 1
    end
  end
end
check("Oak layer paints nothing outside its 64x96 rect", outsideOpaque == 0, outsideOpaque)

local bgImage = OakSpeechScene.compositeBackground(data, addrs)
local bgFullyOpaque = true
for y = 0, 159 do
  for x = 0, 239 do
    if bgImage.getPixel(x, y).a == 0 then bgFullyOpaque = false end
  end
end
check("background layer covers the whole screen opaquely", bgFullyOpaque)

-- Full scene without the message: the real Task_OakSpeech_Init hold.
local noText = OakSpeechScene.composite(data, addrs, { withText = false })
check("scene is 240x160", noText.width == 240 and noText.height == 160)
-- Oak must actually show through: pixels inside his rect differ from the
-- bare background there.
local differing = 0
for y = y0, y1 do
  for x = x0, x1 do
    local a, b = noText.getPixel(x, y), bgImage.getPixel(x, y)
    if a.r ~= b.r or a.g ~= b.g or a.b ~= b.b then differing = differing + 1 end
  end
end
check("Oak is visible over the backdrop in the no-text frame", differing > 2000, differing)
-- ...and nothing outside his rect changed.
local strayChange = 0
for y = 0, 159 do
  for x = 0, 239 do
    if not (x >= x0 and x <= x1 and y >= y0 and y <= y1) then
      local a, b = noText.getPixel(x, y), bgImage.getPixel(x, y)
      if a.r ~= b.r or a.g ~= b.g or a.b ~= b.b then strayChange = strayChange + 1 end
    end
  end
end
check("no-text frame is exactly backdrop + Oak, nothing else", strayChange == 0, strayChange)

-- Full scene with the real narration.
local full = OakSpeechScene.composite(data, addrs)
local frame = OakSpeechScene.decodeDialogueFrame(data, addrs)
local white = frame.palette[OakSpeechScene.TEXT_BG_COLOR]
-- The window's content rect must be flooded white (except where glyphs
-- land). Sample the last content row, which is below the text.
local lastRowY = (win.top + win.height - 1) * 8 + 4
local whiteRun = 0
for x = win.left * 8, (win.left + win.width) * 8 - 1 do
  local p = full.getPixel(x, lastRowY)
  if p.r == white.r and p.g == white.g and p.b == white.b then whiteRun = whiteRun + 1 end
end
check("the window's content rect is flooded with window-palette color 1", whiteRun == win.width * 8, whiteRun)
-- The frame's top edge (row T-1 = 3) must NOT be that white -- it's the
-- decorative gMenuMessageWindow_Gfx border.
local topEdgeY = (win.top - 1) * 8 + 4
local frameNonWhite = 0
for x = win.left * 8, (win.left + win.width) * 8 - 1 do
  local p = full.getPixel(x, topEdgeY)
  if not (p.r == white.r and p.g == white.g and p.b == white.b) then frameNonWhite = frameNonWhite + 1 end
end
check("the dialogue frame's top edge renders above the white panel", frameNonWhite > 0, frameNonWhite)
-- Dark-gray glyph pixels must be present inside the panel.
local darkGray = frame.palette[OakSpeechScene.TEXT_FG_COLOR]
local glyphPixels = 0
for y = win.top * 8, (win.top + 6) * 8 do
  for x = win.left * 8, (win.left + win.width) * 8 - 1 do
    local p = full.getPixel(x, y)
    if p.r == darkGray.r and p.g == darkGray.g and p.b == darkGray.b then glyphPixels = glyphPixels + 1 end
  end
end
check("the narration renders in TEXT_COLOR_DARK_GRAY inside the panel", glyphPixels > 500, glyphPixels)
-- Oak's head still pokes out above the panel (rows 2-3), which is the
-- real geometry: the panel starts at row 4 but Oak starts at row 2.
local abovePanel = 0
for y = y0, win.top * 8 - 1 do
  for x = x0, x1 do
    local a, b = full.getPixel(x, y), bgImage.getPixel(x, y)
    if a.r ~= b.r or a.g ~= b.g or a.b ~= b.b then abovePanel = abovePanel + 1 end
  end
end
check("Oak's top 2 tile rows remain visible above the dialogue panel", abovePanel > 0, abovePanel)

-- Determinism: the whole pipeline is a pure ROM decode.
local again = OakSpeechScene.composite(data, addrs)
local mismatches = 0
for y = 0, 159 do
  for x = 0, 239 do
    local a, b = full.getPixel(x, y), again.getPixel(x, y)
    if a.r ~= b.r or a.g ~= b.g or a.b ~= b.b or a.a ~= b.a then mismatches = mismatches + 1 end
  end
end
check("compositing the scene twice is pixel-identical", mismatches == 0, mismatches)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
