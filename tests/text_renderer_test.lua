-- Integration test: renders a synthetic tokenized message (built with
-- Charmap.tokenize on real charmap bytes) through TextRenderer against
-- the real ROM's font glyph data and gTextWindowPalettes, and checks that
-- a mid-string EXT_CTRL_CODE_COLOR switch actually changes the rendered
-- pixel color -- not just that it parses. Opt-in via POKEPORT_ROM, skips
-- cleanly otherwise.
--
-- Run: POKEPORT_ROM=/path/to/verified/pokefirered.gba lua5.1 tests/text_renderer_test.lua
package.path = package.path .. ";./?.lua"

local romPath = os.getenv("POKEPORT_ROM")
if not romPath then
  print("SKIP: set POKEPORT_ROM=/path/to/verified/pokefirered.gba to run this test")
  os.exit(0)
end

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local Charmap = require("import.Charmap")
local TextRenderer = require("import.TextRenderer")
local GbaGraphics = require("import.GbaGraphics")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

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

local palette = GbaGraphics.decodePalette(data, addrs.gTextWindowPalettes) -- gTextWindowPalettes[0], the overworld dialogue box's bank

-- "A" (0xBB), then FC 01 04 (COLOR -> TEXT_COLOR_RED), then "A" again.
-- Real charmap bytes, not guessed -- 0xBB is confirmed elsewhere
-- (font_test.lua) to be 'A', and 0x01/0x04 are EXT_CTRL_CODE_COLOR and
-- TEXT_COLOR_RED from characters.h.
local message = string.char(0xBB, 0xFC, 0x01, 0x04, 0xBB, 0xFF)
local tokens = Charmap.tokenize(message)
check("tokenizes to char, color, char", #tokens == 3 and tokens[1].type == "char" and tokens[2].type == "color" and tokens[2].fg == 4 and tokens[3].type == "char")

local img = TextRenderer.renderTokens(data, addrs, tokens, palette)
check("composited width covers both glyphs", img.width > 6)
check("composited height is one glyph row", img.height == 16)

-- Row 7 is the 'A' crossbar (confirmed solid at columns 0-4 in
-- font_test.lua's real 'A' pixel-row assertions) -- opaque foreground on
-- both the pre-color and post-color glyph.
local firstGlyphPixel = img.getPixel(0, 7)
check("first 'A' (before the color switch) renders in the default white", firstGlyphPixel.a == 1 and firstGlyphPixel.r == 255 and firstGlyphPixel.g == 255 and firstGlyphPixel.b == 255, ("r=%d g=%d b=%d"):format(firstGlyphPixel.r, firstGlyphPixel.g, firstGlyphPixel.b))

-- Second 'A' starts at x = widthOf('A') + 1 = 6 + 1 = 7 (confirmed 6px
-- wide in font_test.lua).
local secondGlyphPixel = img.getPixel(7, 7)
check("second 'A' (after the color switch) renders in red", secondGlyphPixel.a == 1 and secondGlyphPixel.r == 230 and secondGlyphPixel.g == 8 and secondGlyphPixel.b == 8, ("r=%d g=%d b=%d"):format(secondGlyphPixel.r, secondGlyphPixel.g, secondGlyphPixel.b))

-- Shadow color is unaffected by an fg-only COLOR code -- both glyphs'
-- shadow pixels (row 11, confirmed shadow-only in font_test.lua) still
-- use the default TEXT_COLOR_LIGHT_GRAY.
local firstShadowPixel = img.getPixel(0, 11)
local secondShadowPixel = img.getPixel(7, 11)
check("shadow color is unaffected by an fg-only color switch", firstShadowPixel.r == 214 and firstShadowPixel.g == 214 and firstShadowPixel.b == 206 and secondShadowPixel.r == 214 and secondShadowPixel.g == 214 and secondShadowPixel.b == 206)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
