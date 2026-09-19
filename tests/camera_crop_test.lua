-- Pure contract tests for the live 240x160 overworld camera crop.
package.path = package.path .. ";./?.lua"

local CameraCrop = require("src.core.CameraCrop")
local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
  end
end

check("real GBA camera width is 240", CameraCrop.WIDTH == 240)
check("real GBA camera height is 160", CameraCrop.HEIGHT == 160)

local centred = CameraCrop.forPlayer(400, 300, 1000, 800)
check("centred crop is 240x160", centred.width == 240 and centred.height == 160)
check("player is centred horizontally where bounds allow", centred.x == 288, centred.x)
check("player is centred vertically where bounds allow", centred.y == 228, centred.y)

local topLeft = CameraCrop.forPlayer(0, 0, 1000, 800)
check("top-left crop clamps x", topLeft.x == 0, topLeft.x)
check("top-left crop clamps y", topLeft.y == 0, topLeft.y)

local bottomRight = CameraCrop.forPlayer(990, 790, 1000, 800)
check("bottom-right crop clamps x", bottomRight.x == 760, bottomRight.x)
check("bottom-right crop clamps y", bottomRight.y == 640, bottomRight.y)

local exact = CameraCrop.forPlayer(120, 80, 240, 160)
check("screen-sized map has origin crop", exact.x == 0 and exact.y == 0)
local ok = pcall(CameraCrop.forPlayer, 0, 0, 239, 160)
check("undersized map fails closed", not ok)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
