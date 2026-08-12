-- Run: lua5.1 tests/map_compositor_test.lua
package.path = package.path .. ";./?.lua"
local MapCompositor = require("import.MapCompositor")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- Fully synthetic: a 1x1 metatile map, one metatile whose bottom layer is
-- all "tile 1" (solid red, palette 0) and top layer is all "tile 0"
-- (transparent -- index 0 is never drawn), so the result should be a solid
-- 16x16 red square.
local RED = { r = 255, g = 0, b = 0 }
local TRANSPARENT_TILE = {} -- decode4bppTile-shaped: all zeros (index 0)
for i = 0, 63 do TRANSPARENT_TILE[i] = 0 end
local RED_TILE = {}
for i = 0, 63 do RED_TILE[i] = 1 end -- palette index 1

local palette0 = {}
for i = 0, 15 do palette0[i] = { r = 0, g = 0, b = 0 } end
palette0[1] = RED

local primary = {
  tiles = { [0] = TRANSPARENT_TILE, [1] = RED_TILE },
  palettes = { [0] = palette0 },
  metatilesOffset = 0, -- unused directly; metatileEntries reads via Metatile.resolve on `data`
}
-- secondary is never indexed in this test (all tile/metatile ids are < the
-- primary thresholds), but the module still requires a table.
local secondary = { tiles = {}, palettes = {}, metatilesOffset = 0 }

-- Build the "ROM" bytes MapCompositor.composite() reads metatile entries
-- from: 8 tile-entries at metatilesOffset=0, bottom layer (entries 0-3) =
-- tile 1 (red) palette 0, top layer (entries 4-7) = tile 0 (transparent).
local function tileEntry(tileId, palette)
  local v = tileId + palette * 4096
  return string.char(v % 256, math.floor(v / 256) % 256)
end
local data = tileEntry(1, 0):rep(4) .. tileEntry(0, 0):rep(4)

local blockData = { [0] = { metatileId = 0, collision = 0, elevation = 0 } }

local result = MapCompositor.composite(data, primary, secondary, blockData, 1, 1)
check("image is 16x16 (one metatile)", result.width == 16 and result.height == 16)

local center = result.getPixel(8, 8)
check("center pixel is red", center.r == 255 and center.g == 0 and center.b == 0, center.r .. "," .. center.g .. "," .. center.b)

local corner = result.getPixel(0, 0)
check("corner pixel is also red (uniform tile)", corner.r == 255 and corner.g == 0 and corner.b == 0)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
