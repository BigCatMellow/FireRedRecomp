-- Pure source-backed coverage for Oak's mandatory first battle. The ROM
-- records themselves are cross-checked in early_story_rom_test.lua.
package.path = package.path .. ";./?.lua"

local BattleEngine = require("src.core.BattleEngine")
local Controller = require("src.core.BattleSceneController")
local RivalAI = require("src.core.EarlyRivalAI")
local Rewards = require("src.core.EarlyRivalRewards")
local StarterFactory = require("src.core.StarterPokemonFactory")
local PartyBridge = require("src.core.BattlePartyBridge")
local BoxPokemonCodec = require("src.core.BoxPokemonCodec")
local InputState = require("src.core.InputState")

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
  end
end

local function sequenceRng(values)
  local rng = {index=0}
  function rng:next16()
    self.index = self.index + 1
    return values[self.index] or 0
  end
  return rng
end

local TYPE_NORMAL, TYPE_FIRE, TYPE_WATER, TYPE_GRASS, TYPE_POISON = 0,10,11,12,3
local moves = {
  [10]={effect=0,power=40,type=TYPE_NORMAL,accuracy=100,pp=35,priority=0},
  [33]={effect=0,power=35,type=TYPE_NORMAL,accuracy=95,pp=35,priority=0},
  [39]={effect=19,power=0,type=TYPE_NORMAL,accuracy=100,pp=30,priority=0},
  [45]={effect=18,power=0,type=TYPE_NORMAL,accuracy=100,pp=40,priority=0},
}
local typeChart = {
  [0]={attackingType=TYPE_NORMAL,defendingType=5,multiplier=5},
}
local bulba = {
  baseHP=45,baseAttack=49,baseDefense=49,baseSpeed=45,baseSpAttack=65,baseSpDefense=65,
  types={TYPE_GRASS,TYPE_POISON},catchRate=45,expYield=64,
  evYield={hp=0,attack=0,defense=0,speed=0,spAttack=1,spDefense=0},
  genderRatio=31,friendship=70,growthRate=3,abilities={65,0},
}
local char = {
  baseHP=39,baseAttack=52,baseDefense=43,baseSpeed=65,baseSpAttack=60,baseSpDefense=50,
  types={TYPE_FIRE,TYPE_FIRE},catchRate=45,expYield=65,
  evYield={hp=0,attack=0,defense=0,speed=1,spAttack=0,spDefense=0},
  genderRatio=31,friendship=70,growthRate=3,abilities={66,0},
}
local squirt = {
  baseHP=44,baseAttack=48,baseDefense=65,baseSpeed=43,baseSpAttack=50,baseSpDefense=64,
  types={TYPE_WATER,TYPE_WATER},catchRate=45,expYield=66,
  evYield={hp=0,attack=0,defense=1,speed=0,spAttack=0,spDefense=0},
  genderRatio=31,friendship=70,growthRate=3,abilities={67,0},
}
local species = {[1]=bulba,[4]=char,[7]=squirt}
local natures = {}
for i=0,24 do natures[i]={attack=0,defense=0,speed=0,spAttack=0,spDefense=0} end
local stats = {hp=20,attack=10,defense=10,speed=10,spAttack=10,spDefense=10}
local function battler(id, info, monMoves)
  return BattleEngine.makeBattler({species=id,level=5,stats=stats,types=info.types,moves=monMoves})
end

-- FIRST_BATTLE independently guarantees the first player status/damage
-- accuracy check, suppresses the first damage crit roll, and then restores
-- the ordinary RNG path.
local tutorialRng = sequenceRng({0,0,0,0})
local tutorial = BattleEngine.new({
  player=battler(1,bulba,{{move=33,pp=35},{move=45,pp=40}}),
  foe=battler(4,char,{{move=10,pp=35},{move=45,pp=40}}),
  moves=moves,typeChart=typeChart,rng=tutorialRng,firstBattle=true,
})
local events = {}
tutorial:resolveMove("player", 2, events)
check("first tutorial Growl is guaranteed, spends PP, and lowers Attack",
  tutorialRng.index == 0 and tutorial.foe.statStages.attack == 5
    and tutorial.player.moves[2].pp == 39)
check("successful first stat move emits Oak's stat tutorial exactly once",
  events[#events].type == "tutorialTip" and events[#events].kind == "stat")
events = {}
tutorial:resolveMove("player", 1, events)
check("first player damage skips accuracy but consumes suppressed crit plus damage RNG",
  tutorialRng.index == 2 and tutorial.tutorialPlayerDamageDone)
tutorial:resolveMove("player", 1, {})
check("later player damage returns to accuracy, crit, damage RNG order", tutorialRng.index == 5)

local foeFirstRng = sequenceRng({0,0,0})
local foeFirst = BattleEngine.new({
  player=battler(1,bulba,{{move=33,pp=35}}),
  foe=battler(4,char,{{move=10,pp=35}}),
  moves=moves,typeChart=typeChart,rng=foeFirstRng,firstBattle=true,
})
local foeEvents = {}
foeFirst:resolveMove("foe", 1, foeEvents)
local emittedCritical = false
for _, event in ipairs(foeEvents) do
  if event.type == "critical" then emittedCritical = true end
end
check("foe crit roll is consumed but globally suppressed before first player damage",
  foeFirstRng.index == 3 and not emittedCritical and not foeFirst.tutorialPlayerDamageDone)

-- At full HP Tail Whip's CheckViability script exits at its neutral score;
-- this ties Tackle, so the fifth draw is the real tie breaker after four
-- simulated-damage draws.
local aiRng = sequenceRng({0,0,0,0,1})
local aiEngine = BattleEngine.new({
  player=battler(1,bulba,{{move=33,pp=35},{move=45,pp=40}}),
  foe=battler(7,squirt,{{move=33,pp=35},{move=39,pp=30}}),
  moves=moves,typeChart=typeChart,rng=aiRng,
})
local aiSlot, scores = RivalAI.choose(aiEngine, 7)
check("Oak-rival AI consumes four simulation draws plus tie draw",
  aiRng.index == 5 and scores[1] == 100 and scores[2] == 100)
check("source tie breaker can select Tail Whip", aiSlot == 2)

local growlRng = sequenceRng({0,0,0,0,100,0})
local growlEngine = BattleEngine.new({
  player=battler(7,squirt,{{move=33,pp=35},{move=39,pp=30}}),
  foe=battler(4,char,{{move=10,pp=35},{move=45,pp=40}}),
  moves=moves,typeChart=typeChart,rng=growlRng,
})
local growlSlot, growlScores = RivalAI.choose(growlEngine, 7)
check("Growl viability uses its conditional random branch against special types",
  growlRng.index == 6 and growlScores[2] == 98 and growlSlot == 1)

local noRunEngine = BattleEngine.new({
  player=battler(1,bulba,{{move=33,pp=35}}), foe=battler(4,char,{{move=10,pp=35}}),
  moves=moves,typeChart=typeChart,rng=sequenceRng({0}),
})
local noRun = Controller.new({engine=noRunEngine,runDisabledMessage="NO RUN"})
noRun:advanceMessage(); noRun:advanceMessage()
local function input(button) return {isNewlyPressed=function(_, b) return b == button end} end
noRun:processInput(input(InputState.DPAD_RIGHT)); noRun:processInput(input(InputState.DPAD_DOWN))
noRun:processInput(input(InputState.A_BUTTON))
check("trainer RUN refusal consumes no turn, PP, or RNG",
  noRun:message() == "NO RUN" and noRunEngine.turn == 0
    and noRunEngine.player.moves[1].pp == 35 and noRunEngine.rng.index == 0)

local trainerName = string.char(0xCC,0xBF,0xBE,0xFF,0xFF,0xFF,0xFF)
local starterLearnsets = {
  [1]={{level=1,move=33},{level=1,move=45},{level=7,move=73}},
  [4]={{level=1,move=10},{level=1,move=45},{level=7,move=52}},
  [7]={{level=1,move=33},{level=1,move=39},{level=7,move=55}},
}
local function newStarter(starterSpecies)
  starterSpecies = starterSpecies or 1
  return StarterFactory.generate({
    species=starterSpecies,speciesInfo=species[starterSpecies],
    speciesName=string.rep(string.char(0xBB + starterSpecies), 9) .. string.char(0xFF),
    learnset=starterLearnsets[starterSpecies],
    battleMoves=moves,natures=natures,rng=sequenceRng({0,0,0,0}),
    trainer={id=1,name=trainerName,gender=0},metLocation=88,
  })
end

local record = newStarter()
local live = PartyBridge.battlerFromParty(record, species)
live.hp = live.hp - 5; live.moves[1].pp = live.moves[1].pp - 2
PartyBridge.persistPartyBattler(record, live)
local reward = Rewards.applyVictory(record, {species=4,level=5}, species, natures,
  starterLearnsets[1], 88)
local rewarded = BoxPokemonCodec.decode(record.box)
check("trainer EXP uses base/7 then 1.5x and levels starter 5 to 6",
  reward.exp == 69 and reward.oldLevel == 5 and reward.newLevel == 6 and record.level == 6
    and rewarded.substructs[0].experience == 204)
check("victory grants foe EV before stat recalc and exact level friendship",
  rewarded.substructs[2].speedEV == 1 and rewarded.substructs[0].friendship == 76)
check("level-up persists cached stats and adds max-HP growth to current HP",
  record.maxHP == 21 and record.hp == 16 and record.attack == 10
    and record.defense == 10 and record.speed == 10
    and record.spAttack == 12 and record.spDefense == 12)

local winFixtures = {
  {player=7,foe=1,exp=67,ev="spAttackEV"},
  {player=4,foe=7,exp=70,ev="defenseEV"},
}
for _, fixture in ipairs(winFixtures) do
  local choiceRecord = newStarter(fixture.player)
  local choiceReward = Rewards.applyVictory(choiceRecord,
    {species=fixture.foe,level=5}, species, natures,
    starterLearnsets[fixture.player], 88)
  local choiceBox = BoxPokemonCodec.decode(choiceRecord.box)
  check(("starter %d receives exact counter-starter EXP/EV/friendship"):format(fixture.player),
    choiceReward.exp == fixture.exp and choiceRecord.level == 6
      and choiceBox.substructs[2][fixture.ev] == 1
      and choiceBox.substructs[0].friendship == 76)
end
Rewards.healParty({playerPartyCount=1,playerParty={record}}, moves)
local healed = BoxPokemonCodec.decode(record.box)
check("postbattle script restores HP/status/all move PP after a win",
  record.hp == record.maxHP and record.status == 0
    and healed.substructs[1].pp[1] == 35 and healed.substructs[1].pp[2] == 40)

local lost = newStarter()
lost.hp = 0; lost.status = 0x40
local lostBox = BoxPokemonCodec.decode(lost.box)
lostBox.substructs[0].ppBonuses = 1 -- one PP Up in move slot 1
lostBox.substructs[1].pp[1] = 1
lost.box = BoxPokemonCodec.encode(lostBox)
Rewards.applyLoss(lost)
Rewards.healParty({playerPartyCount=1,playerParty={lost}}, moves)
local lossHealed = BoxPokemonCodec.decode(lost.box)
check("early-rival loss applies faint friendship then heals without whiteout",
  lossHealed.substructs[0].friendship == 69 and lost.hp == lost.maxHP
    and lost.status == 0 and lossHealed.substructs[1].pp[1] == 42
    and lost.moves[1].pp == 42)
local sb1 = {money=3000}
Rewards.addPrizeMoney(sb1)
check("RivalEarly level-5 prize is exactly $80", sb1.money == 3080)

print(("early_rival_battle_test: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
