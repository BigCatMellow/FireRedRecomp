package.path=package.path..";./?.lua"
local B=require("import.BattleMove");local A=require("import.RomAddresses");local R=require("import.RomImporter")
local p=os.getenv("POKEPORT_ROM");if not p then print("SKIP phase4_ohko_effect_rom_test (set POKEPORT_ROM)");os.exit(0)end
local ok,i=R.verify(p);if not ok then print("FAIL: ROM verification -- "..tostring(i));os.exit(1)end
local f=assert(io.open(p,"rb"));local rom=f:read("*a");f:close();local a=assert(A["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"]);local m=B.parseTable(rom,a.gBattleMoves,A.COUNTS.MOVES_COUNT)
local ids={12,32,90,329};local types={0,0,4,15};local flags={19,19,18,18};local n=0
for i=0,A.COUNTS.MOVES_COUNT-1 do if m[i].effect==38 then n=n+1 end end
for j,id in ipairs(ids)do local x=m[id];if not(x.effect==38 and x.power==1 and x.type==types[j] and x.accuracy==30 and x.pp==5 and x.target==0 and x.priority==0 and x.flags==flags[j])then print("FAIL: OHKO ROM record changed");os.exit(1)end end
if n~=4 then print("FAIL: OHKO ROM record count changed");os.exit(1)end
print("phase4_ohko_effect_rom_test: 1 passed, 0 failed")
