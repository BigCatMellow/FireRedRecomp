-- Run: POKEPORT_ROM=/path/to/verified/pokefirered.gba lua5.1 tests/phase4_high_critical_effect_rom_test.lua
package.path = package.path .. ";./?.lua"
local BattleEngine = require("src.core.BattleEngine")
local BattleMove = require("import.BattleMove")
local PokemonStats = require("src.core.PokemonStats")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local SpeciesInfo = require("import.SpeciesInfo")
local TypeChart = require("import.TypeChart")
local path = os.getenv("POKEPORT_ROM")
if not path then print("SKIP phase4_high_critical_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
local ok, info = RomImporter.verify(path)
if not ok then print("FAIL: ROM verification -- " .. tostring(info)); os.exit(1) end
local f = assert(io.open(path, "rb")); local rom = f:read("*a"); f:close()
local addrs = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, addrs.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
local species = SpeciesInfo.parseTable(rom, addrs.gSpeciesInfo, RomAddresses.COUNTS.NUM_SPECIES)
local typeChart = TypeChart.parseTable(rom, addrs.gTypeEffectiveness)
local ids = { 2, 75, 152, 163, 177, 238, 314, 348 }
local expected = { [2]={50,100}, [75]={55,95}, [152]={90,85}, [163]={70,100}, [177]={100,95}, [238]={100,80}, [314]={55,95}, [348]={70,100} }
local passed, failed = 0, 0
local function check(name, condition, detail) if condition then passed=passed+1 else failed=failed+1; print("FAIL: "..name..(detail and (" -- "..tostring(detail)) or "")) end end
local exact, count = true, 0
for id = 1, RomAddresses.COUNTS.MOVES_COUNT - 1 do if moves[id].effect == 43 and moves[id].power > 0 then count=count+1 end end
for _, id in ipairs(ids) do local m=moves[id]; exact=exact and m.effect==43 and m.power==expected[id][1] and m.accuracy==expected[id][2] end
check("ROM has exactly eight expected positive-power effect-43 records", exact and count==#ids, count)
local function rng(values) return { draws=0, next16=function(self) self.draws=self.draws+1; return values[self.draws] or 0 end } end
local zero={hp=0,attack=0,defense=0,speed=0,spAttack=0,spDefense=0}; local neutral={attack=0,defense=0,speed=0,spAttack=0,spDefense=0}
local playerStats=PokemonStats.calculateAll(species[1],20,zero,zero,neutral); local foeStats=PokemonStats.calculateAll(species[4],20,zero,zero,neutral); local scripted=rng({0,8,0})
local battle=BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=20,stats=playerStats,types=species[1].types,moves={{move=163,pp=moves[163].pp}}}),foe=BattleEngine.makeBattler({species=4,level=20,stats=foeStats,types=species[4].types,moves={{move=33,pp=moves[33].pp}}}),moves=moves,typeChart=typeChart,rng=scripted})
local events={}; battle:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
check("parsed Slash uses stage one and preserves three ordinary draws", events[2].type=="critical" and events[3].type=="damage" and scripted.draws==3, scripted.draws)
check("parsed Slash still deducts PP", battle.player.moves[1].pp==moves[163].pp-1, battle.player.moves[1].pp)
print(("phase4_high_critical_effect_rom_test: %d passed, %d failed"):format(passed,failed)); os.exit(failed==0 and 0 or 1)
