package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path = os.getenv("POKEPORT_ROM")
if not path then print("SKIP phase4_super_fang_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
local ok, info = RomImporter.verify(path)
if not ok then print("FAIL: ROM verification -- " .. tostring(info)); os.exit(1) end
local f=assert(io.open(path,"rb")); local rom=f:read("*a"); f:close()
local a=assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves=BattleMove.parseTable(rom,a.gBattleMoves,RomAddresses.COUNTS.MOVES_COUNT)
local m=moves[162]
if m.effect ~= 40 or m.power ~= 1 or m.type ~= 0 or m.accuracy ~= 90 or m.pp ~= 10 or m.priority ~= 0 then
  print("FAIL: Super Fang #162 ROM record changed"); os.exit(1)
end
print("phase4_super_fang_effect_rom_test: 1 passed, 0 failed")
