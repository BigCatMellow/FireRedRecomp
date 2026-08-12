-- Run: lua5.1 tests/viewport_scale_test.lua
package.path = package.path .. ";./?.lua"
local ViewportScale = require("src.core.ViewportScale")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- GBA screen (240x160) in a window exactly 2x its size: scale 2, no offset.
local fit1 = ViewportScale.fit(240, 160, 480, 320)
check("exact 2x window: scale 2, centered with no remainder", fit1.scale == 2 and fit1.x == 0 and fit1.y == 0)

-- Same image in a window that's bigger than any integer multiple: picks
-- the largest integer scale that fits, centers the remainder.
local fit2 = ViewportScale.fit(240, 160, 1000, 700)
check("non-exact window: integer scale, not fractional", fit2.scale == 4, fit2.scale) -- floor(min(1000/240, 700/160)) = floor(min(4.16, 4.375)) = 4
check("centered horizontally", fit2.x == math.floor((1000 - 240 * 4) / 2))
check("centered vertically", fit2.y == math.floor((700 - 160 * 4) / 2))

-- Window smaller than the source: never scales below 1x (no shrinking/blur).
local fit3 = ViewportScale.fit(448, 384, 300, 200)
check("window smaller than source clamps to scale 1, not fractional/zero", fit3.scale == 1, fit3.scale)

-- Square source in a wide window: height is the limiting dimension.
local fit4 = ViewportScale.fit(256, 160, 2000, 320)
check("height-limited case picks the smaller ratio", fit4.scale == 2, fit4.scale) -- floor(min(2000/256=7.8, 320/160=2)) = 2

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
