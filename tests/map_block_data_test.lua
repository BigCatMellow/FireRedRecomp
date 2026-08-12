-- Run: lua5.1 tests/map_block_data_test.lua
package.path = package.path .. ";./?.lua"
local MapBlockData = require("import.MapBlockData")

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

-- Real Pallet Town cell 0: metatileId=28, collision=1, elevation=0.
-- Packed: 28 | (1 << 10) | (0 << 12) = 28 + 1024 = 1052.
local cell0 = u16le(28 + 1024)
-- A cell with elevation set: metatileId=5, collision=0, elevation=3 -> 5 + 3*4096.
local cell1 = u16le(5 + 3 * 4096)

local rom = cell0 .. cell1
-- MapBlockData.resolve expects a raw ROM address for mapPtr; pass the GBA
-- ROM base address directly since this synthetic "ROM" starts at offset 0.
local blocks = MapBlockData.resolve(rom, 0x08000000, 2, 1)

check("cell0 metatileId", blocks[0].metatileId == 28, blocks[0].metatileId)
check("cell0 collision", blocks[0].collision == 1, blocks[0].collision)
check("cell0 elevation", blocks[0].elevation == 0, blocks[0].elevation)
check("cell1 metatileId", blocks[1].metatileId == 5, blocks[1].metatileId)
check("cell1 elevation", blocks[1].elevation == 3, blocks[1].elevation)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
