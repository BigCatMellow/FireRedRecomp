-- Unit test: verifies PaletteBlend's channel interpolation against the
-- real BlendPalette formula (src/blend_palette.c), hand-computed.
-- Run: lua5.1 tests/palette_blend_test.lua
package.path = package.path .. ";./?.lua"
local PaletteBlend = require("src.core.PaletteBlend")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- coeff=0 leaves the color completely unchanged (real formula: c + (t-c)*0>>4 = c).
do
  local c = PaletteBlend.blendColor({ r = 100, g = 150, b = 200 }, { r = 0, g = 0, b = 0 }, 0)
  check("coeff=0 is a no-op", c.r == 100 and c.g == 150 and c.b == 200)
end

-- coeff=16 produces exactly blendColor (real formula: c + (t-c)*16>>4 = c + (t-c) = t).
do
  local c = PaletteBlend.blendColor({ r = 100, g = 150, b = 200 }, { r = 10, g = 20, b = 30 }, 16)
  check("coeff=16 produces exactly the blend color", c.r == 10 and c.g == 20 and c.b == 30)
end

-- Midpoint (coeff=8) hand-computed: c + floor((t-c)*8/16).
do
  local c = PaletteBlend.blendColor({ r = 100, g = 0, b = 255 }, { r = 200, g = 255, b = 0 }, 8)
  -- r: 100 + floor((200-100)*8/16) = 100 + 50 = 150
  -- g: 0   + floor((255-0)*8/16)   = 0   + 127 = 127
  -- b: 255 + floor((0-255)*8/16)   = 255 + floor(-2040/16) = 255 + floor(-127.5) = 255 + (-128) = 127
  --    (real arithmetic right shift rounds toward -infinity, same as Lua's math.floor -- not truncation)
  check("midpoint blend matches the real floor-division formula", c.r == 150 and c.g == 127 and c.b == 127, ("%d,%d,%d"):format(c.r, c.g, c.b))
end

-- Fading toward black (a real, extremely common case -- every screen
-- transition in the game).
do
  local c = PaletteBlend.blendColor({ r = 255, g = 255, b = 255 }, { r = 0, g = 0, b = 0 }, 16)
  check("fully faded to black", c.r == 0 and c.g == 0 and c.b == 0)
end

-- Out-of-range coeff is clamped to the real hardware's meaningful 0-16 range.
do
  local over = PaletteBlend.blendColor({ r = 0, g = 0, b = 0 }, { r = 100, g = 100, b = 100 }, 99)
  check("coeff above 16 clamps to 16 (fully blended)", over.r == 100)
  local under = PaletteBlend.blendColor({ r = 50, g = 50, b = 50 }, { r = 0, g = 0, b = 0 }, -5)
  check("negative coeff clamps to 0 (unchanged)", under.r == 50)
end

-- blendImage: alpha passes through untouched, RGB blends normally.
do
  local source = {
    width = 2, height = 1,
    getPixel = function(x, y)
      if x == 0 then return { r = 255, g = 255, b = 255, a = 1 } end
      return { r = 0, g = 0, b = 0, a = 0 } -- transparent pixel
    end,
  }
  local blended = PaletteBlend.blendImage(source, { r = 0, g = 0, b = 0 }, 16)
  local opaque = blended.getPixel(0, 0)
  local transparent = blended.getPixel(1, 0)
  check("opaque pixel blends toward the target color", opaque.a == 1 and opaque.r == 0 and opaque.g == 0 and opaque.b == 0)
  check("transparent pixel passes through unblended (alpha=0 short-circuits)", transparent.a == 0)
  check("blendImage preserves the source image's dimensions", blended.width == 2 and blended.height == 1)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
