-- Run: lua5.1 tests/map_layout_test.lua
package.path = package.path .. ";./?.lua"
local MapLayout = require("import.MapLayout")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local function u32le(n)
  return string.char(n % 256, math.floor(n / 256) % 256, math.floor(n / 65536) % 256, math.floor(n / 16777216) % 256)
end

-- Real Pallet Town field values, laid out at ROM address romBase (offset 0).
local layout = u32le(24)          -- width
  .. u32le(20)                     -- height
  .. u32le(0x082dd0f8)             -- border ptr
  .. u32le(0x082dd100)             -- map ptr
  .. u32le(0x082d4a94)             -- primary tileset ptr
  .. u32le(0x082d4aac)             -- secondary tileset ptr
  .. string.char(2)                -- borderWidth
  .. string.char(2)                -- borderHeight

local h = MapLayout.resolve(layout, MapLayout.romBase)
check("width", h.width == 24, h.width)
check("height", h.height == 20, h.height)
check("borderWidth", h.borderWidth == 2, h.borderWidth)
check("borderHeight", h.borderHeight == 2, h.borderHeight)
check("primaryTilesetPtr kept raw", h.primaryTilesetPtr == 0x082d4a94, h.primaryTilesetPtr)

-- Negative width/height should decode as signed (sanity check for s32le,
-- even though real map dimensions are never negative).
local negLayout = u32le(4294967295) .. string.rep("\0", 22) -- -1 as u32
local negH = MapLayout.resolve(negLayout, MapLayout.romBase)
check("width decodes as signed", negH.width == -1, negH.width)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
