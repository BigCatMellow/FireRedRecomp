-- Pure save-party <-> live BattleEngine bridge coverage.
-- Run: lua5.1 tests/battle_party_bridge_test.lua
package.path = package.path .. ";./?.lua"

local BattlePartyBridge = require("src.core.BattlePartyBridge")
local BoxPokemonCodec = require("src.core.BoxPokemonCodec")
local Rng = require("src.core.Rng")
local SaveFileCodec = require("src.core.SaveFileCodec")
local WildPokemonFactory = require("src.core.WildPokemonFactory")

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
  end
end

local species = {
  baseHP=30, baseAttack=56, baseDefense=35, baseSpeed=72,
  baseSpAttack=25, baseSpDefense=35, types={0,0}, catchRate=255,
  genderRatio=127, friendship=70, growthRate=0, abilities={50,62},
}
local speciesTable = { [19]=species }
local moves = {
  [33]={pp=35, power=35},
  [39]={pp=30, power=0},
}
local natures = {}
for i = 0, 24 do
  natures[i] = {attack=0,defense=0,speed=0,spAttack=0,spDefense=0}
end
local rawName = string.char(0xCC,0xBB,0xCE,0xCE,0xBB,0xCE,0xBB,0xFF,0,0)
local trainerName = string.char(0xCC,0xBF,0xBE,0xFF,0xFF,0xFF,0xFF)

local function partyRecord(seed)
  local instance = WildPokemonFactory.generate({
    species=19, level=3, speciesInfo=species,
    learnset={{level=1,move=33},{level=1,move=39}},
    battleMoves=moves, natures=natures, rng=Rng.new(seed),
    speciesName=rawName, trainer={id=0x12345678,name=trainerName,gender=0},
    metLocation=88,
  })
  return WildPokemonFactory.capture(instance, {ball=4}), instance
end

local empty, emptySlot, emptyReason = BattlePartyBridge.findUsableLead({
  playerPartyCount=0, playerParty={},
})
check("empty fresh party has no fabricated battle lead",
  empty == nil and emptySlot == nil and emptyReason:find("empty", 1, true) ~= nil)

local fainted = partyRecord(200)
fainted.hp = 0
local living, generated = partyRecord(201)
local lead, slot, reason = BattlePartyBridge.findUsableLead({
  playerPartyCount=2, playerParty={fainted,living},
})
check("first conscious real party record becomes lead",
  lead == living and slot == 2 and reason == nil)

local battler, decoded = BattlePartyBridge.battlerFromParty(living, speciesTable)
check("party battler uses encrypted species/personality/moves",
  battler.species == 19 and battler.personality == decoded.personality
    and #battler.moves == 2 and battler.moves[1].move == 33
    and battler.moves[2].move == 39)
check("party battler uses cached current HP and stats",
  battler.hp == living.hp and battler.maxHP == living.maxHP
    and battler.attack == living.attack and battler.speed == living.speed)

battler.hp = 4
battler.moves[1].pp = 31
battler.moves[2].pp = 27
BattlePartyBridge.persistPartyBattler(living, battler)
local after = BoxPokemonCodec.decode(living.box)
check("resolved battle HP and PP persist to the same party record",
  living.hp == 4 and after.substructs[1].pp[1] == 31
    and after.substructs[1].pp[2] == 27 and after.checksumValid)
check("bridge refreshes decoded metadata without changing identity",
  living.boxData.personality == generated.personality
    and living.moves[1].pp == 31 and living.moves[2].pp == 27)

local bytes = SaveFileCodec.encodeSaveBlock1({
  playerPartyCount=1, playerParty={living},
}, 0)
local saved = SaveFileCodec.decodeSaveBlock1(bytes, 0).playerParty[1]
local savedBox = BoxPokemonCodec.decode(saved.box)
check("persisted battle state remains SaveFileCodec-compatible",
  saved.hp == 4 and savedBox.substructs[1].pp[1] == 31
    and savedBox.substructs[1].pp[2] == 27 and savedBox.checksumValid)

local generatedBattler = BattlePartyBridge.battlerFromGenerated(generated)
check("factory foe keeps generated stats, moves, and personality",
  generatedBattler.maxHP == generated.stats.hp
    and generatedBattler.moves[1].move == generated.moves[1].move
    and generatedBattler.personality == generated.personality
    and generatedBattler.nature == generated.nature)

print(("battle_party_bridge_test: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
