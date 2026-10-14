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

-- Status persistence (status-conditions design review F1/F2): flags and
-- sleep turns persist; the battle-local toxic counter is masked to 0.
battler.status = 128 + 5 * 256
BattlePartyBridge.persistPartyBattler(living, battler)
check("bad poison persists with its battle-local counter masked", living.status == 128, living.status)
battler.status = 3
BattlePartyBridge.persistPartyBattler(living, battler)
check("sleep turns persist as-is", living.status == 3, living.status)
check("persisted status reloads into a battler",
  BattlePartyBridge.battlerFromParty(living, speciesTable).status == 3)
battler.status = 0
BattlePartyBridge.persistPartyBattler(living, battler)

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

-- findSwitchTargets: real Cmd_jumpifcantswitch eligibility (living,
-- non-Egg, not the currently-active slot).
local activeRecord = partyRecord(210)
local benchRecord = partyRecord(211)
local faintedBenchRecord = partyRecord(212)
faintedBenchRecord.hp = 0
local sb1 = {
  playerPartyCount = 3,
  playerParty = { activeRecord, benchRecord, faintedBenchRecord },
}
local targets = BattlePartyBridge.findSwitchTargets(sb1, 1)
check("switch targets exclude the active slot and a fainted bench mon",
  #targets == 1 and targets[1].slot == 2 and targets[1].record == benchRecord)

local noOthers = BattlePartyBridge.findSwitchTargets({
  playerPartyCount = 1, playerParty = { activeRecord },
}, 1)
check("a solo party has no switch targets", #noOthers == 0)

local emptyState = BattlePartyBridge.findSwitchTargets({}, 1)
check("missing party state returns an empty list, not a crash", type(emptyState) == "table" and #emptyState == 0)

-- Invoked model-to-party persistence of actual crash results, not normal
-- gameplay lifecycle or disk save/reload proof.
do
  local Engine=require("src.core.BattleEngine")
  local kickMoves={
    [26]={effect=45,power=70,type=1,accuracy=95,pp=25,target=0,priority=0},
    [136]={effect=45,power=85,type=1,accuracy=90,pp=20,target=0,priority=0},
  }
  for _,id in ipairs({26,136}) do
    for _,mode in ipairs({"nonfatal","fatal","immune"}) do
      local instance=WildPokemonFactory.generate({species=19,level=20,speciesInfo=species,
        learnset={{level=1,move=id}},battleMoves=kickMoves,natures=natures,rng=Rng.new(201),
        speciesName=rawName,trainer={id=0x12345678,name=trainerName,gender=0},metLocation=88})
      local record=WildPokemonFactory.capture(instance,{ball=4})
      local active=BattlePartyBridge.battlerFromParty(record,speciesTable)
      if mode=="fatal" then active.hp=1; record.hp=1 end
      local beforeHP=active.hp
      local beforeBox=BoxPokemonCodec.decode(record.box)
      local target=Engine.makeBattler({species=4,level=20,
        stats={hp=100,attack=40,defense=100,speed=20,spAttack=40,spDefense=40},
        types=mode=="immune" and {7,7} or {10,10},moves={{move=26,pp=25}}})
      local draws=0
      local engine=Engine.new({player=active,foe=target,moves=kickMoves,
        typeChart={[0]={attackingType=1,defendingType=7,multiplier=0}},
        rng={next16=function() draws=draws+1; return draws==1 and 99 or 0 end}})
      local ev={}; engine:resolveMove("player",1,ev)
      local label=id..":"..mode
      check("party crash obtains real engine outcome "..label,
        (mode=="immune" and ev[2].type=="noEffect" and active.hp==beforeHP)
        or (mode~="immune" and ev[3].type=="crash" and active.hp==beforeHP-ev[3].amount
          and (mode~="fatal" or (active.hp==0 and ev[4].type=="faint"))))
      BattlePartyBridge.persistPartyBattler(record,active)
      local decoded=BoxPokemonCodec.decode(record.box)
      check("party crash HP PP checksum identity persist "..label,
        record.hp==active.hp and decoded.substructs[1].moves[1]==id
        and decoded.substructs[1].pp[1]==kickMoves[id].pp-1 and decoded.checksumValid
        and decoded.personality==beforeBox.personality and target.hp==100)
      local encoded=SaveFileCodec.encodeSaveBlock1({playerPartyCount=1,playerParty={record}},0)
      local roundtrip=SaveFileCodec.decodeSaveBlock1(encoded,0).playerParty[1]
      check("party crash in-memory codec compatibility "..label,
        roundtrip.hp==active.hp and BoxPokemonCodec.decode(roundtrip.box).substructs[1].pp[1]==kickMoves[id].pp-1)
    end
  end
end

print(("battle_party_bridge_test: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
