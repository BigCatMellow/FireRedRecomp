package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path=os.getenv("POKEPORT_ROM")
if not path then print("SKIP phase4_flail_effect_rom_test (set POKEPORT_ROM)");os.exit(0) end
local ok,info=RomImporter.verify(path);if not ok then print("FAIL: ROM verification -- "..tostring(info));os.exit(1)end
local f=assert(io.open(path,"rb"));local rom=f:read("*a");f:close()
local a=assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local m=BattleMove.parseTable(rom,a.gBattleMoves,RomAddresses.COUNTS.MOVES_COUNT)
if not (m[175].effect==99 and m[175].power==1 and m[175].type==0 and m[175].accuracy==100 and m[175].pp==15 and m[179].effect==99 and m[179].power==1 and m[179].type==1 and m[179].accuracy==100 and m[179].pp==15) then print("FAIL: Flail/Reversal ROM records changed");os.exit(1) end
print("phase4_flail_effect_rom_test: 1 passed, 0 failed")
