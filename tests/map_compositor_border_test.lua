-- Run: lua5.1 tests/map_compositor_border_test.lua
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

-- Same synthetic fixture style as map_compositor_test.lua: metatile 0 is a
-- solid red tile (bottom layer red, top layer transparent), metatile 1 is
-- solid blue. A 1x1 map of metatile 0, with a 1x1 border of metatile 1.
local RED, BLUE = { r = 255, g = 0, b = 0 }, { r = 0, g = 0, b = 255 }
local TRANSPARENT_TILE, RED_TILE, BLUE_TILE = {}, {}, {}
for i = 0, 63 do
  TRANSPARENT_TILE[i] = 0
  RED_TILE[i] = 1
  BLUE_TILE[i] = 2
end

local palette0 = {}
for i = 0, 15 do palette0[i] = { r = 0, g = 0, b = 0 } end
palette0[1] = RED
palette0[2] = BLUE

local primary = {
  tiles = { [0] = TRANSPARENT_TILE, [1] = RED_TILE, [2] = BLUE_TILE },
  palettes = { [0] = palette0 },
  metatilesOffset = 0,
}
local secondary = { tiles = {}, palettes = {}, metatilesOffset = 0 }

local function tileEntry(tileId, palette)
  local v = tileId + palette * 4096
  return string.char(v % 256, math.floor(v / 256) % 256)
end
-- metatile 0 (red) at data offset 0, metatile 1 (blue) at offset 16.
local data = tileEntry(1, 0):rep(4) .. tileEntry(0, 0):rep(4) -- metatile 0: red
  .. tileEntry(2, 0):rep(4) .. tileEntry(0, 0):rep(4) -- metatile 1: blue

local blockData = { [0] = { metatileId = 0 } } -- the single map cell is red
local border = { [0] = 1 } -- border metatile id 1 (blue), 1x1 border pattern

local result = MapCompositor.compositeWithBorder(data, primary, secondary, blockData, 1, 1, border, 1, 1, 1)

check("padded to 3x3 metatiles (48x48 px)", result.width == 48 and result.height == 48, result.width .. "x" .. result.height)

local center = result.getPixel(24, 24) -- middle of the 1x1 map cell
check("center is the map's own red tile", center.r == 255 and center.g == 0 and center.b == 0)

local corner = result.getPixel(4, 4) -- inside the top-left border margin
check("border margin is blue", corner.r == 0 and corner.g == 0 and corner.b == 255, corner.r .. "," .. corner.g .. "," .. corner.b)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
