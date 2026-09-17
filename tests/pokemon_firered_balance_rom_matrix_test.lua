-- Run: POKEPORT_ROM=/path/to/verified/pokefirered.gba lua5.1 tests/pokemon_firered_balance_rom_matrix_test.lua
-- Validation-only matrix: real ROM tables + actual installed package, no ROM writes.
package.path = package.path .. ";./?.lua"
local path = os.getenv("POKEPORT_ROM")
if not path then print("SKIP pokemon_firered_balance_rom_matrix_test (set POKEPORT_ROM)"); os.exit(0) end
local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local BattleMove = require("import.BattleMove")
local Runtime = require("src.core.ModRuntime")
local Formulas = require("src.core.BattleFormulas")
local SpeciesInfo = require("import.SpeciesInfo")
local PokemonStats = require("src.core.PokemonStats")
local ok, info = RomImporter.verify(path)
assert(ok, "ROM verification failed: " .. tostring(info))
local file = assert(io.open(path, "rb")); local rom = file:read("*a"); file:close()
local addrs = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local raw = BattleMove.parseTable(rom, addrs.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
local species = SpeciesInfo.parseTable(rom, addrs.gSpeciesInfo, RomAddresses.COUNTS.NUM_SPECIES)
local function read(name) local h=assert(io.open(name,"rb")); local v=h:read("*a"); h:close(); return v end
local fs = {list=function() return {"pokemon-firered-balance"} end,
  isDirectory=function(p) return p == "mods/pokemon-firered-balance" end, read=read}
local host = {namespaces={{name="battleMoves", options={semantics="deep", base=raw}},
  {name="battleLearnsetAdditions", options={semantics="record", base={}}}}}
local runtime = Runtime.new(host); local loaded, err = runtime:load(fs, "mods"); assert(loaded, err)
local moves = runtime:resolve("battleMoves"); local additions = runtime:resolve("battleLearnsetAdditions")
local passed, failed = 0, 0
local function check(name, value) if value then passed=passed+1 else failed=failed+1; print("FAIL: "..name) end end
local expectedFields = {[41]={power=30},[318]={pp=10},[317]={power=60,accuracy=90},[350]={power=25,accuracy=90},[202]={pp=10},[17]={power=65},[314]={power=65,accuracy=95},[62]={power=70}}
local fieldsOK, fieldCount = true, 0
for id, fields in pairs(expectedFields) do for key, value in pairs(fields) do fieldsOK=fieldsOK and moves[id][key]==value; fieldCount=fieldCount+1 end end
check("all eight frozen move overrides resolve from real ROM data", fieldsOK and fieldCount == 11)
check("category mechanism matrix uses effective runtime categories", moves[172].category == "physical" and moves[127].category == "physical"
  and moves[247].category == "special" and moves[314].category == "special"
  and moves[124].category == "physical" and moves[188].category == "physical")
check("unmodded raw controls retain FireRed type categories", Formulas.damageCategory(raw[52]) == "special" and Formulas.damageCategory(raw[33]) == "physical")
local attacker={level=50,attack=120,defense=80,spAttack=30,spDefense=80}
local defender={level=50,attack=80,defense=120,spAttack=80,spDefense=120}
check("category changes select distinct real stat branches", Formulas.calculateBaseDamage(attacker,defender,moves[172],false) ~= Formulas.calculateBaseDamage(attacker,defender,raw[172],false)
  and Formulas.calculateBaseDamage(attacker,defender,moves[127],false) ~= Formulas.calculateBaseDamage(attacker,defender,raw[127],false)
  and Formulas.calculateBaseDamage(attacker,defender,moves[247],false) ~= Formulas.calculateBaseDamage(attacker,defender,raw[247],false)
  and Formulas.calculateBaseDamage(attacker,defender,moves[314],false) ~= Formulas.calculateBaseDamage(attacker,defender,raw[314],false))
check("physical Fire and Water remain weather-type sensitive", Formulas.calculateBaseDamage(attacker,defender,moves[172],false,nil,"rain") < Formulas.calculateBaseDamage(attacker,defender,moves[172],false)
  and Formulas.calculateBaseDamage(attacker,defender,moves[127],false,nil,"sun") < Formulas.calculateBaseDamage(attacker,defender,moves[127],false))
local expectedAdditions={[24]={30,305},[31]={30,305},[34]={30,342},[42]={35,305},[82]={32,351},[85]={37,65},[94]={36,247},[95]={30,317},[101]={32,351},[119]={38,127},[124]={25,62},[136]={36,172},[141]={46,350}}
local additionsOK, count=true,0
for species, row in pairs(additions) do count=count+1; local want=expectedAdditions[species]; additionsOK=additionsOK and want and #row==1 and row[1].level==want[1] and row[1].move==want[2] end
check("all 13 frozen natural additions resolve against real ROM host", additionsOK and count==13)
local zero = {hp=0,attack=0,defense=0,speed=0,spAttack=0,spDefense=0}
local neutral = {attack=0,defense=0,speed=0,spAttack=0,spDefense=0}
local function battler(id)
  local value = PokemonStats.calculateAll(species[id], 55, zero, zero, neutral)
  value.level = 55
  return value
end
local function damage(move, attacker, defender)
  return Formulas.calculateBaseDamage(attacker, defender, move, false)
end
local gengar, jynx, hitmonchan, gyarados = battler(94), battler(124), battler(107), battler(130)
local rhydon, kabutops, seaking = battler(112), battler(141), battler(119)
local control = battler(95) -- Onix is a fixed neutral defender for watch comparisons.
check("Gengar Special Ghost and Jynx Aurora70 are distinct real-ROM watch repairs",
  damage(moves[247], gengar, control) ~= damage(raw[247], gengar, control)
  and damage(moves[62], jynx, control) > damage(raw[62], jynx, control))
check("Hitmonchan elemental coverage and Gyarados Bite retain category-watch distinction",
  damage(moves[7], hitmonchan, control) ~= damage(raw[7], hitmonchan, control)
  and damage(moves[44], gyarados, control) ~= damage(raw[44], gyarados, control))
check("Rhydon/Kabutops Rock and Seaking Waterfall watches use only frozen changes",
  damage(moves[317], rhydon, control) > damage(raw[317], rhydon, control)
  and moves[350].power == raw[350].power and moves[350].accuracy == 90
  and damage(moves[127], seaking, control) ~= damage(raw[127], seaking, control))
local function oneCopy(recipient, eligible)
  local owners = 0
  for _, candidate in ipairs(eligible) do if candidate == recipient then owners = owners + 1 end end
  return owners == 1
end
check("TM19 remains one-copy and is a finite Gengar-versus-Kabutops allocation control",
  moves[202].power == raw[202].power and moves[202].pp == 10
  and oneCopy("Gengar", {"Gengar", "Kabutops"}) and damage(moves[202], gengar, rhydon) > damage(moves[202], kabutops, rhydon))
check("TM30's unchanged move data remains a finite allocation control",
  oneCopy("Gengar", {"Gengar", "Jynx"}) and moves[247].power == raw[247].power
  and moves[247].pp == raw[247].pp and additions[124] and additions[124][1].move ~= 247)
check("held timing candidates remain controls with no promoted natural additions",
  moves[152].power == raw[152].power and moves[200].power == raw[200].power
  and moves[246].power == raw[246].power and moves[157].power == raw[157].power
  and additions[99] == nil and additions[149] == nil and additions[139] == nil and additions[142] == nil)
runtime:unload()
local unloadedMoves = runtime:resolve("battleMoves")
local unloadedAdditions = runtime:resolve("battleLearnsetAdditions")
check("unload restores raw ROM category behavior", unloadedMoves[172].category == nil and next(unloadedAdditions) == nil)
print(("%d passed, %d failed"):format(passed,failed)); os.exit(failed==0 and 0 or 1)
