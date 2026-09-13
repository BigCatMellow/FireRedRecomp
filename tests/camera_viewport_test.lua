-- Pure deterministic geometry coverage for the normal 240x160 field camera.
package.path = package.path .. ";./?.lua"
local CameraViewport = require("src.core.CameraViewport")

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
  end
end

local function near(a, b) return math.abs(a - b) < 0.000001 end

do
  local camera = CameraViewport.follow(640, 480, 320, 240)
  check("viewport is exactly GBA width", camera.width == 240, camera.width)
  check("viewport is exactly GBA height", camera.height == 160, camera.height)
  check("center player follows horizontally", camera.x == 208, camera.x)
  check("center player follows vertically", camera.y == 168, camera.y)
  local sx, sy = CameraViewport.worldToScreen(camera, 320, 240)
  check("center player maps to intended screen X", sx == 112, sx)
  check("center player maps to intended screen Y", sy == 72, sy)
end

do
  local camera = CameraViewport.follow(640, 480, 0, 0)
  check("left/top clamps at zero", camera.x == 0 and camera.y == 0,
    tostring(camera.x) .. "," .. tostring(camera.y))
  camera = CameraViewport.follow(640, 480, 639, 479)
  check("right clamp is map width minus viewport", camera.x == 400, camera.x)
  check("bottom clamp is map height minus viewport", camera.y == 320, camera.y)
end

do
  local camera = CameraViewport.follow(160, 96, 80, 48)
  check("small map clamps origin without a negative quad", camera.x == 0 and camera.y == 0,
    tostring(camera.x) .. "," .. tostring(camera.y))
  check("small map exposes only valid source width", camera.sourceWidth == 160, camera.sourceWidth)
  check("small map exposes only valid source height", camera.sourceHeight == 96, camera.sourceHeight)
end

do
  local before = CameraViewport.follow(640, 480, 320, 240)
  local during = CameraViewport.follow(640, 480, 320.5, 240.5)
  check("sub-tile movement updates camera continuously on X", near(during.x - before.x, 0.5), during.x - before.x)
  check("sub-tile movement updates camera continuously on Y", near(during.y - before.y, 0.5), during.y - before.y)
  local beforeX = 320
  local afterX = 320.5
  check("world positions remain caller-owned during camera follow", beforeX == 320 and afterX == 320.5)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
