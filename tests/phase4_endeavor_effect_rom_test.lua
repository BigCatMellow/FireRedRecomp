package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path = os.getenv("POKEPORT_ROM")
if not path then print("SKIP phase4_endeavor_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
local ok, info = RomImporter.verify(path)
if not ok then print("FAIL: ROM verification -- " .. tostring(info)); os.exit(1) end
local f = assert(io.open(path, "rb")); local rom = f:read("*a"); f:close()
local a = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, a.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
local m, count = moves[283], 0
for i = 0, RomAddresses.COUNTS.MOVES_COUNT - 1 do if moves[i].effect == 189 then count = count + 1 end end
if not (m.effect == 189 and m.power == 1 and m.type == 0 and m.accuracy == 100 and m.pp == 5 and m.target == 0 and m.priority == 0 and m.flags == 51 and count == 1) then
  print("FAIL: Endeavor ROM record changed"); os.exit(1)
end
print("phase4_endeavor_effect_rom_test: 1 passed, 0 failed")
