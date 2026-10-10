package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path = os.getenv("POKEPORT_ROM")
if not path then print("SKIP phase4_magnitude_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
local ok, info = RomImporter.verify(path)
if not ok then print("FAIL: ROM verification -- " .. tostring(info)); os.exit(1) end
local f = assert(io.open(path, "rb")); local rom = f:read("*a"); f:close()
local a = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, a.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
local magnitude, count = moves[222], 0
for i = 0, RomAddresses.COUNTS.MOVES_COUNT - 1 do if moves[i].effect == 126 then count = count + 1 end end
if not (magnitude.effect == 126 and magnitude.power == 1 and magnitude.type == 4
  and magnitude.accuracy == 100 and magnitude.pp == 30 and count == 1) then
  print("FAIL: Magnitude ROM record changed"); os.exit(1)
end
print("phase4_magnitude_effect_rom_test: 1 passed, 0 failed")
