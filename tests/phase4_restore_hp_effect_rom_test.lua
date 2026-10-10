package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path = os.getenv("POKEPORT_ROM")
if not path then print("SKIP phase4_restore_hp_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
local ok, info = RomImporter.verify(path)
if not ok then print("FAIL: ROM verification -- " .. tostring(info)); os.exit(1) end
local f = assert(io.open(path, "rb")); local rom = f:read("*a"); f:close()
local a = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, a.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
local recover, slackOff, count = moves[105], moves[303], 0
for i = 0, RomAddresses.COUNTS.MOVES_COUNT - 1 do if moves[i].effect == 32 then count = count + 1 end end
if not (recover.effect == 32 and recover.power == 0 and recover.type == 0 and recover.accuracy == 0 and recover.pp == 20 and recover.target == 16 and recover.priority == 0 and recover.flags == 8
  and slackOff.effect == 32 and slackOff.power == 0 and slackOff.type == 0 and slackOff.accuracy == 100 and slackOff.pp == 10 and slackOff.target == 16 and slackOff.priority == 0 and slackOff.flags == 8 and count == 2) then
  print("FAIL: Restore HP ROM records changed"); os.exit(1)
end
print("phase4_restore_hp_effect_rom_test: 1 passed, 0 failed")
