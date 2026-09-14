-- Run: POKEPORT_ROM=/path/to/verified/pokefirered.gba lua5.1 tests/phase4_false_swipe_effect_rom_test.lua
package.path = package.path .. ";./?.lua"
local BattleEngine=require("src.core.BattleEngine"); local BattleMove=require("import.BattleMove"); local PokemonStats=require("src.core.PokemonStats"); local RomAddresses=require("import.RomAddresses"); local RomImporter=require("import.RomImporter"); local SpeciesInfo=require("import.SpeciesInfo"); local TypeChart=require("import.TypeChart")
local path=os.getenv("POKEPORT_ROM"); if not path then print("SKIP phase4_false_swipe_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
local ok,info=RomImporter.verify(path); if not ok then print("FAIL: ROM verification -- "..tostring(info)); os.exit(1) end
local f=assert(io.open(path,"rb")); local rom=f:read("*a"); f:close(); local addrs=assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves=BattleMove.parseTable(rom,addrs.gBattleMoves,RomAddresses.COUNTS.MOVES_COUNT); local species=SpeciesInfo.parseTable(rom,addrs.gSpeciesInfo,RomAddresses.COUNTS.NUM_SPECIES); local typeChart=TypeChart.parseTable(rom,addrs.gTypeEffectiveness)
local passed,failed=0,0; local function check(n,c,d) if c then passed=passed+1 else failed=failed+1; print("FAIL: "..n..(d and (" -- "..tostring(d)) or "")) end end
local count=0; for id=1,RomAddresses.COUNTS.MOVES_COUNT-1 do if moves[id].effect==101 and moves[id].power>0 then count=count+1 end end
local m=moves[206]; check("ROM has only False Swipe as positive-power effect 101", count==1 and m.effect==101 and m.power==40 and m.accuracy==100 and m.pp==40,count)
local function rng(v) return {draws=0,next16=function(self) self.draws=self.draws+1; return v[self.draws] or 0 end} end
local zero={hp=0,attack=0,defense=0,speed=0,spAttack=0,spDefense=0}; local neutral={attack=0,defense=0,speed=0,spAttack=0,spDefense=0}; local ps=PokemonStats.calculateAll(species[1],20,zero,zero,neutral); local fs=PokemonStats.calculateAll(species[4],20,zero,zero,neutral); local scripted=rng({0,15,0})
local battle=BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=20,stats=ps,types=species[1].types,moves={{move=206,pp=m.pp}}}),foe=BattleEngine.makeBattler({species=4,level=20,stats=fs,hp=1,types=species[4].types,moves={{move=33,pp=moves[33].pp}}}),moves=moves,typeChart=typeChart,rng=scripted}); local events={}; battle:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
check("parsed False Swipe leaves one HP with ordinary three draws", events[2].type=="damage" and events[2].amount==0 and battle.foe.hp==1 and scripted.draws==3,scripted.draws); check("parsed False Swipe deducts PP",battle.player.moves[1].pp==m.pp-1,battle.player.moves[1].pp)
print(("phase4_false_swipe_effect_rom_test: %d passed, %d failed"):format(passed,failed)); os.exit(failed==0 and 0 or 1)
