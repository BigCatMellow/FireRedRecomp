-- Integration test: decodes the real standard window border frame
-- (gStdTextWindow_Gfx + gTextWindowPalettes[3]) and checks the composited
-- box against the known-correct layout (confirmed by eye via ASCII-art
-- render -- a clean 3x3 corner/edge border with a transparent interior,
-- no visual noise). Opt-in via POKEPORT_ROM, skips cleanly otherwise.
--
-- Run: POKEPORT_ROM=/path/to/verified/pokefirered.gba lua5.1 tests/text_window_test.lua
package.path = package.path .. ";./?.lua"

local romPath = os.getenv("POKEPORT_ROM")
if not romPath then
  print("SKIP: set POKEPORT_ROM=/path/to/verified/pokefirered.gba to run this test")
  os.exit(0)
end

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local TextWindow = require("import.TextWindow")

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

local tiles = TextWindow.decodeFrameTiles(data, addrs.gStdTextWindow_Gfx)
check("decodes 9 frame tiles", tiles[0] ~= nil and tiles[8] ~= nil)

local pal = TextWindow.decodePalette(data, addrs.gTextWindowPalettes, TextWindow.STD_PALETTE_INDEX)
check("decodes a 16-color palette", pal[0] ~= nil and pal[15] ~= nil)

-- Real tile 4 (the interior-fill tile) is fully solid (every pixel non-zero
-- index) -- but WindowFunc_DrawStandardFrame never places it, per its real
-- C source (src/new_menu_helpers.c), which is exactly what makes the
-- composited interior transparent below despite this tile existing.
local tile4NonzeroCount = 0
for p = 0, 63 do
  if tiles[4][p] ~= 0 then tile4NonzeroCount = tile4NonzeroCount + 1 end
end
check("tile 4 (unused by the frame) is a fully solid fill tile", tile4NonzeroCount == 64, tile4NonzeroCount)

local img = TextWindow.compositeFrame(tiles, pal, 10, 3)
check("composited size matches (content+2 border) * 8px", img.width == 12 * 8 and img.height == 5 * 8)

-- The real corner/edge tiles are a *rounded*-corner border design (visible
-- via an ASCII dump of the raw decoded tiles: e.g. tile 0, the top-left
-- corner, has a 2px transparent margin on its top and left edges before
-- the solid rounded shape starts). So the literal outermost pixel (0,0) is
-- transparent by design, not a bug -- these checks probe a few pixels in
-- from each corner, still within that corner's tile, where the real
-- rounded shape is solid.
check("top-left corner tile has an opaque pixel near the corner", img.getPixel(5, 5).a == 1)
check("top-right corner tile has an opaque pixel near the corner", img.getPixel(img.width - 3, 5).a == 1)
check("bottom-left corner tile has an opaque pixel near the corner", img.getPixel(3, img.height - 3).a == 1)
check("bottom-right corner tile has an opaque pixel near the corner", img.getPixel(img.width - 5, img.height - 5).a == 1)

-- Interior (content) area is fully transparent -- the real frame-drawing
-- function never touches it, leaving it for the window's own text/content.
local interiorAllTransparent = true
for y = 8, img.height - 9 do
  for x = 8, img.width - 9 do
    if img.getPixel(x, y).a ~= 0 then interiorAllTransparent = false end
  end
end
check("interior content area is fully transparent", interiorAllTransparent)

-- Edge tiles repeat correctly along the top/bottom/left/right borders (same
-- rounded-margin caveat as the corners -- e.g. tile 1, the top edge, is
-- transparent for its first 2 rows, solid below that).
check("top edge (between the corners) is opaque border", img.getPixel(img.width / 2, 3).a == 1)
check("bottom edge (between the corners) is opaque border", img.getPixel(img.width / 2, img.height - 3).a == 1)
check("left edge (between the corners) is opaque border", img.getPixel(3, img.height / 2).a == 1)
check("right edge (between the corners) is opaque border", img.getPixel(img.width - 3, img.height / 2).a == 1)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
