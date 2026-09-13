-- Run: lua5.1 tests/trainer_pokemon_factory_test.lua
package.path = package.path .. ";./?.lua"

local Factory = require("src.core.TrainerPokemonFactory")

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
  end
end

local natures = {}
for i = 0, 24 do
  natures[i] = {attack=0, defense=0, speed=0, spAttack=0, spDefense=0}
end
local species = {
  baseHP=30, baseAttack=56, baseDefense=35, baseSpeed=72,
  baseSpAttack=25, baseSpDefense=35, types={0,0}, catchRate=255,
  genderRatio=127, abilities={50,62},
}
local moves = { [33]={pp=35}, [39]={pp=30}, [45]={pp=40}, [98]={pp=30} }
local learnset = {{level=1,move=33},{level=1,move=39},{level=7,move=98}}
local rawTrainerName = string.char(0xC6, 0xBF, 0xC0, 0xFF)
local rawSpeciesName = string.char(0xCC, 0xBB, 0xCE, 0xCE, 0xBB, 0xCE, 0xBB, 0xFF)

local function rng()
  return { next16=function() return 0 end }
end

local function generate(trainer, partyMon, extra)
  extra = extra or {}
  return Factory.generate({
    trainer=trainer, partyMon=partyMon, speciesInfo=species,
    speciesName=rawSpeciesName, learnset=extra.learnset or learnset,
    battleMoves=extra.battleMoves or moves, natures=natures, rng=rng(),
  })
end

local defaultTrainer = {partyFlags=0, rawName=rawTrainerName, doubleBattle=false}
local defaultMon = {species=19, lvl=10, iv=100}
local default = generate(defaultTrainer, defaultMon)
check("default layout retains level-up move selection", #default.moves == 3
  and default.moves[1].move == 33 and default.moves[1].pp == 35
  and default.moves[2].move == 39 and default.moves[2].pp == 30
  and default.moves[3].move == 98 and default.moves[3].pp == 30)
check("default layout retains deterministic personality and IVs",
  default.personality == (0x88 + (Factory.byteSumUntilEos(rawTrainerName)
    + Factory.byteSumUntilEos(rawSpeciesName)) * 256) % 4294967296
  and default.ivs.hp == math.floor(100 * 31 / 255))

local custom = generate({partyFlags=1, rawName=rawTrainerName, doubleBattle=false}, {
  species=19, lvl=10, iv=100, moves={[0]=33,[1]=45,[2]=39,[3]=98},
})
check("custom layout copies all four ROM move slots in source order", #custom.moves == 4
  and custom.moves[1].move == 33 and custom.moves[2].move == 45
  and custom.moves[3].move == 39 and custom.moves[4].move == 98)
check("custom layout obtains each PP from catalog", custom.moves[1].pp == 35
  and custom.moves[2].pp == 40 and custom.moves[3].pp == 30 and custom.moves[4].pp == 30)
check("custom layout retains deterministic construction fields",
  custom.personality == default.personality and custom.nature == default.nature
  and custom.ivs.hp == default.ivs.hp and custom.stats.hp == default.stats.hp)

local function rejects(name, trainer, partyMon, pattern)
  local ok, err = pcall(generate, trainer, partyMon)
  check(name, not ok and tostring(err):find(pattern, 1, true) ~= nil, err)
end
rejects("held-item default layout is rejected", {partyFlags=2,rawName=rawTrainerName,doubleBattle=false},
  {species=19,lvl=10,iv=100,heldItem=1}, "unsupported")
rejects("held-item custom layout is rejected", {partyFlags=3,rawName=rawTrainerName,doubleBattle=false},
  {species=19,lvl=10,iv=100,heldItem=1,moves={[0]=33,[1]=45,[2]=39,[3]=98}}, "unsupported")
rejects("unknown party flag is rejected", {partyFlags=4,rawName=rawTrainerName,doubleBattle=false},
  defaultMon, "unsupported")
rejects("custom layout refuses absent ROM move slot", {partyFlags=1,rawName=rawTrainerName,doubleBattle=false},
  {species=19,lvl=10,iv=100,moves={[0]=33,[1]=45,[2]=39}}, "missing ROM move slot 3")

print(("trainer_pokemon_factory_test: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
