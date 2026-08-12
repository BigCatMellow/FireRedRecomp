-- Run: lua5.1 tests/pokedex_order_test.lua
package.path = package.path .. ";./?.lua"
local PokedexOrder = require("import.PokedexOrder")

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

-- Real first 3 entries of gPokedexOrder_Alphabetical: 387, 388, 389
-- (NATIONAL_DEX_OLD_UNOWN_B/C/D), padded to full table length.
local realEntries = u16le(387) .. u16le(388) .. u16le(389)
local blob = realEntries .. string.rep("\0", (PokedexOrder.NATIONAL_DEX_COUNT - 3) * 2)
check("fixture is full table size", #blob == PokedexOrder.NATIONAL_DEX_COUNT * 2)

local order = PokedexOrder.parseOrderTable(blob, 0)
check("entry 0 is NATIONAL_DEX_OLD_UNOWN_B (387)", order[0] == 387, order[0])
check("entry 2 is NATIONAL_DEX_OLD_UNOWN_D (389)", order[2] == 389, order[2])
check("full table parsed", order[PokedexOrder.NATIONAL_DEX_COUNT - 1] ~= nil)

-- Real sSpeciesToNationalPokedexNum: species 1-3 map to national dex 1-3.
local mapBlob = u16le(1) .. u16le(2) .. u16le(3)
check("SPECIES_NONE (0) maps to national dex 0", PokedexOrder.speciesToNationalDexNum(mapBlob, 0, 0) == 0)
check("species 1 maps to national dex 1", PokedexOrder.speciesToNationalDexNum(mapBlob, 0, 1) == 1)
check("species 3 maps to national dex 3", PokedexOrder.speciesToNationalDexNum(mapBlob, 0, 3) == 3)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
