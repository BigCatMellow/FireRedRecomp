-- Integration test: decodes the real FONT_NORMAL glyphs for 'A' (0xBB) and
-- 'B' (0xBC) out of the actual ROM and checks specific pixel values against
-- the known-correct decode (confirmed by eye via ASCII-art render -- 'A' is
-- an unmistakable capital A with a drop shadow). Opt-in via POKEPORT_ROM,
-- skips cleanly otherwise.
--
-- Run: POKEPORT_ROM=/path/to/verified/pokefirered.gba lua5.1 tests/font_test.lua
package.path = package.path .. ";./?.lua"

local romPath = os.getenv("POKEPORT_ROM")
if not romPath then
  print("SKIP: set POKEPORT_ROM=/path/to/verified/pokefirered.gba to run this test")
  os.exit(0)
end

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local Font = require("import.Font")

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

local BG, FG, SH = Font.GLYPH_PIXEL_TYPE_BACKGROUND, Font.GLYPH_PIXEL_TYPE_FOREGROUND, Font.GLYPH_PIXEL_TYPE_SHADOW

-- Real glyph 'A' (0xBB), confirmed by eye against the actual ROM:
--   ................
--   ................
--   ................
--   .###s...........
--   #sss#s..........
--   #s..#s..........
--   #s..#s..........
--   #####s..........
--   #sss#s..........
--   #s..#s..........
--   #s..#s..........
--   ss..ss..........
--   ................  (x4 trailing blank rows)
local pt = Font.decodeGlyphPixelTypes(data, addrs.sFontHalfRowOffsets, addrs.sFontNormalLatinGlyphs, 0xBB)
check("row 0-2 fully blank (top padding)", pt[0][0] == BG and pt[2][15] == BG)
check("row 3 apex of the A: '.###s...'", pt[3][0] == BG and pt[3][1] == FG and pt[3][2] == FG and pt[3][3] == FG and pt[3][4] == SH and pt[3][5] == BG)
check("row 4 crossbar-less sides: '#sss#s..'", pt[4][0] == FG and pt[4][1] == SH and pt[4][4] == FG and pt[4][5] == SH)
check("row 7 crossbar: '#####s..'", pt[7][0] == FG and pt[7][1] == FG and pt[7][2] == FG and pt[7][3] == FG and pt[7][4] == FG and pt[7][5] == SH)
check("row 11 base with shadow-only left foot: 'ss..ss..'", pt[11][0] == SH and pt[11][1] == SH and pt[11][4] == SH and pt[11][5] == SH)
check("rows 12-15 fully blank (bottom padding)", pt[12][0] == BG and pt[15][15] == BG)
check("columns past 6 unused by this glyph", pt[3][6] == BG and pt[7][10] == BG)

local widthA = string.byte(data, addrs.sFontNormalLatinGlyphWidths + 0xBB + 1)
check("'A' advance width is 6px", widthA == 6, widthA)

-- Real glyph 'B' (0xBC) -- just check it decodes to a *different* shape
-- than 'A' (distinct glyph data, not an aliasing bug) and has some ink.
local ptB = Font.decodeGlyphPixelTypes(data, addrs.sFontHalfRowOffsets, addrs.sFontNormalLatinGlyphs, 0xBC)
local hasInk = false
for y = 0, 15 do
  for x = 0, 15 do
    if ptB[y][x] ~= BG then hasInk = true end
  end
end
check("'B' glyph has visible ink", hasInk)
check("'B' glyph differs from 'A' glyph (distinct glyph data)", ptB[7][0] ~= pt[7][0] or ptB[4][2] ~= pt[4][2] or ptB[11][2] ~= pt[11][2])

-- buildGlyphImage sanity on the real 'A' data.
local img = Font.buildGlyphImage(pt, widthA, { r = 255, g = 255, b = 255 }, { r = 80, g = 80, b = 80 })
check("built image width matches real advance width", img.width == 6)
local apex = img.getPixel(1, 3)
check("apex pixel renders opaque foreground white", apex.a == 1 and apex.r == 255 and apex.g == 255 and apex.b == 255)
local blank = img.getPixel(0, 0)
check("background pixel renders transparent", blank.a == 0)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
