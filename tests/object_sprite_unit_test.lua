-- Run: lua5.1 tests/object_sprite_unit_test.lua
package.path = package.path .. ";./?.lua"
local ObjectSprite = require("import.ObjectSprite")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- Two 1x1-tile frames: frame0 solid color-index 1 (red in a synthetic
-- palette), frame1 solid color-index 0 (transparent), to prove frame
-- offset math and transparency both work.
local redTile = string.rep(string.char(0x11), 32) -- both nibbles = index 1
local transparentTile = string.rep(string.char(0x00), 32) -- both nibbles = index 0
local sheet = redTile .. transparentTile

local palette = {}
for i = 0, 15 do palette[i] = { r = 0, g = 0, b = 0 } end
palette[1] = { r = 200, g = 20, b = 20 }

local frame0Tiles = ObjectSprite.decodeFrameTiles(sheet, 0, 1, 1, 0)
check("frame 0 tile decodes", frame0Tiles[0][0] == 1)

local frame1Tiles = ObjectSprite.decodeFrameTiles(sheet, 0, 1, 1, 1)
check("frame 1 (offset by 1 tile = 32 bytes) decodes the second tile", frame1Tiles[0][0] == 0)

local img0 = ObjectSprite.buildImage(frame0Tiles, palette, 1, 1)
check("frame 0 image is 8x8", img0.width == 8 and img0.height == 8)
local p0 = img0.getPixel(0, 0)
check("frame 0 pixel is opaque red", p0.a == 1 and p0.r == 200 and p0.g == 20 and p0.b == 20)

local img1 = ObjectSprite.buildImage(frame1Tiles, palette, 1, 1)
local p1 = img1.getPixel(0, 0)
check("frame 1 pixel (color index 0) is fully transparent", p1.a == 0)

-- decodeFrame convenience wrapper.
local palBlob = {}
for i = 0, 15 do
  local c = palette[i]
  -- pack back to BGR555-ish isn't needed here since decodeFrame reads a
  -- real palette via GbaGraphics.decodePalette -- build minimal raw bytes.
  palBlob[#palBlob + 1] = string.char(0, 0) -- placeholder; only testing shape below
end
local ok = pcall(ObjectSprite.decodeFrame, sheet, 0, nil, 1, 1, 0)
check("decodeFrame requires a real palette offset (nil errors, doesn't silently misbehave)", ok == false)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
