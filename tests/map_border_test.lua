-- Run: lua5.1 tests/map_border_test.lua
package.path = package.path .. ";./?.lua"
local MapBorder = require("import.MapBorder")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local function u16le(n) return string.char(n % 256, math.floor(n / 256) % 256) end

-- Real Pallet Town border: {28, 29, 20, 21}, 2x2.
local rom = u16le(28) .. u16le(29) .. u16le(20) .. u16le(21)
local border = MapBorder.resolve(rom, 0x08000000, 2, 2)

check("4 cells", border[3] ~= nil and border[4] == nil)
check("row-major order matches Pallet Town's border.bin", border[0] == 28 and border[1] == 29 and border[2] == 20 and border[3] == 21)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
