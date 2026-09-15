package.path=package.path..";./?.lua"
local B=require("import.BattleMove");local A=require("import.RomAddresses");local R=require("import.RomImporter")
local p=os.getenv("POKEPORT_ROM");if not p then print("SKIP phase4_psywave_effect_rom_test (set POKEPORT_ROM)");os.exit(0)end
local ok,i=R.verify(p);if not ok then print("FAIL: ROM verification -- "..tostring(i));os.exit(1)end
local f=assert(io.open(p,"rb"));local rom=f:read("*a");f:close();local a=assert(A["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"]);local m=B.parseTable(rom,a.gBattleMoves,A.COUNTS.MOVES_COUNT)
if not(m[149].effect==88 and m[149].power==1 and m[149].type==14 and m[149].accuracy==80 and m[149].pp==15 and m[149].target==0 and m[149].priority==0 and m[149].flags==50)then print("FAIL: Psywave ROM record changed");os.exit(1)end
print("phase4_psywave_effect_rom_test: 1 passed, 0 failed")
