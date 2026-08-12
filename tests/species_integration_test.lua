-- Integration test: parses gSpeciesInfo out of a real FireRed(US) v1.0 ROM
-- and checks known values. This is the only test that touches a real ROM,
-- so it's opt-in and skips cleanly when one isn't available (a fresh
-- checkout has no ROM -- see README's no-ROM contribution rule).
--
-- Run: POKEPORT_ROM=/path/to/pokefirered.gba lua5.1 tests/species_integration_test.lua
package.path = package.path .. ";./?.lua"

local romPath = os.getenv("POKEPORT_ROM")
if not romPath then
  print("SKIP: set POKEPORT_ROM=/path/to/verified/pokefirered.gba to run this test")
  os.exit(0)
end

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local SpeciesInfo = require("import.SpeciesInfo")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local ok, info = RomImporter.verify(romPath)
check("ROM verifies", ok == true, info)
if not ok then
  print(("%d passed, %d failed"):format(passed, failed))
  os.exit(1)
end

local sha1 = RomImporter._sha1HexOfFile(romPath)

local addrs = RomAddresses[sha1]
check("known symbol addresses for this ROM", addrs ~= nil)

local f = io.open(romPath, "rb")
local data = f:read("*a")
f:close()

local species = SpeciesInfo.parseTable(data, addrs.gSpeciesInfo, 5)

-- SPECIES_NONE=0, BULBASAUR=1, IVYSAUR=2, VENUSAUR=3, CHARMANDER=4
check("Bulbasaur baseHP", species[1].baseHP == 45, species[1].baseHP)
check("Bulbasaur baseAttack", species[1].baseAttack == 49, species[1].baseAttack)
check("Bulbasaur types (Grass/Poison)", species[1].types[1] == 12 and species[1].types[2] == 3)
check("Venusaur baseHP", species[3].baseHP == 80, species[3].baseHP)
check("Charmander baseSpeed", species[4].baseSpeed == 65, species[4].baseSpeed)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
