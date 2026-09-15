package.path=package.path..";./?.lua"
local B=require("import.BattleMove");local A=require("import.RomAddresses");local R=require("import.RomImporter")
local p=os.getenv("POKEPORT_ROM");if not p then print("SKIP phase4_eruption_effect_rom_test (set POKEPORT_ROM)");os.exit(0)end
local ok,i=R.verify(p);if not ok then print("FAIL: ROM verification -- "..tostring(i));os.exit(1)end
local f=assert(io.open(p,"rb"));local rom=f:read("*a");f:close();local a=assert(A["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"]);local m=B.parseTable(rom,a.gBattleMoves,A.COUNTS.MOVES_COUNT)
if not(m[284].effect==190 and m[284].power==150 and m[284].type==10 and m[284].accuracy==100 and m[284].pp==5 and m[284].target==8 and m[323].effect==190 and m[323].power==150 and m[323].type==11 and m[323].accuracy==100 and m[323].pp==5 and m[323].target==8)then print("FAIL: Eruption/Water Spout ROM records changed");os.exit(1)end
print("phase4_eruption_effect_rom_test: 1 passed, 0 failed")
