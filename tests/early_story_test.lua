-- Run: lua5.1 tests/early_story_test.lua
package.path = package.path .. ";./?.lua"

love = {}
local App = require("main")
local EarlyStory = require("src.core.EarlyStory")
local Flow = require("src.core.NewGameFlow")

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
  end
end

local session = App.GameSession.fromNewGame({
  playerGender=Flow.MALE,
  playerName=Flow.encodeName("RED"),
  rivalName=Flow.encodeName("GREEN"),
}, { nextRandom16=function() return 0x1234 end, generatedTrainerIdLower=0x5678 })
local story = EarlyStory.new(session)

local palletEvents = {
  [0]={x=12,y=1,trigger=EarlyStory.VAR_PALLET_OAK_SCENE,index=0},
  [1]={x=13,y=1,trigger=EarlyStory.VAR_PALLET_OAK_SCENE,index=0},
}
check("ordinary Pallet tile does not skip into Oak's lab",
  story:onStep(EarlyStory.MAP_PALLET_TOWN, 12, 2, palletEvents) == nil)
local escort = story:onStep(EarlyStory.MAP_PALLET_TOWN, 12, 1, palletEvents)
check("real north-exit coord event starts Oak escort", escort and escort.kind == "oakEscort")
check("escort ends at source-derived lab coordinate after eight walk_up steps",
  escort and escort.mapId == EarlyStory.MAP_OAKS_LAB and escort.x == 6 and escort.y == 4)
check("Pallet and lab scene vars reach their real post-intro values",
  session:getVar(EarlyStory.VAR_PALLET_OAK_SCENE) == 1
    and session:getVar(EarlyStory.VAR_OAKS_LAB_SCENE) == 2)
check("Oak visibility/visited flags match real transition",
  session:getFlag(EarlyStory.FLAG_HIDE_OAK_IN_PALLET_TOWN)
    and not session:getFlag(EarlyStory.FLAG_HIDE_OAK_IN_HIS_LAB)
    and session:getFlag(EarlyStory.FLAG_VISITED_OAKS_LAB))
check("trigger cannot replay after Pallet scene advances",
  story:onStep(EarlyStory.MAP_PALLET_TOWN, 12, 1, palletEvents) == nil)

local leaveEvents = {
  [0]={x=5,y=8,trigger=EarlyStory.VAR_OAKS_LAB_SCENE,index=2},
  [1]={x=6,y=8,trigger=EarlyStory.VAR_OAKS_LAB_SCENE,index=2},
  [2]={x=7,y=8,trigger=EarlyStory.VAR_OAKS_LAB_SCENE,index=2},
  [3]={x=5,y=8,trigger=EarlyStory.VAR_OAKS_LAB_SCENE,index=3},
  [4]={x=6,y=8,trigger=EarlyStory.VAR_OAKS_LAB_SCENE,index=3},
  [5]={x=7,y=8,trigger=EarlyStory.VAR_OAKS_LAB_SCENE,index=3},
}
local stopped = story:onStep(EarlyStory.MAP_OAKS_LAB, 6, 8, leaveEvents)
check("scene 2 leave trigger returns the real one-tile-up stop", stopped and stopped.kind == "stayForStarter" and stopped.y == 7)

local unavailable = story:beginStarterChoice(EarlyStory.MAP_PALLET_TOWN, 5)
check("starter cannot be chosen outside the lab", unavailable == nil)
local squirtle = story:beginStarterChoice(EarlyStory.MAP_OAKS_LAB, 6)
check("Squirtle ball maps to species 7, starter value 1, rival Bulbasaur",
  squirtle and squirtle.kind == "confirmStarter" and squirtle.choice.species == 7
    and squirtle.choice.starterNum == 1 and squirtle.choice.rivalSpecies == 1)
check("declining leaves party and story state unchanged",
  story:declineStarter().species == 7 and session.state.saveBlock1.playerPartyCount == 0
    and session:getVar(EarlyStory.VAR_OAKS_LAB_SCENE) == 2)

local charmander = story:beginStarterChoice(EarlyStory.MAP_OAKS_LAB, 7)
local record = { species=4, box=string.rep("\0",80), hp=20, maxHP=20 }
local accepted = story:acceptStarter(record, 4)
check("Charmander acceptance inserts the exact supplied persistent record in slot 1",
  accepted.species == 4 and session.state.saveBlock1.playerPartyCount == 1
    and session.state.saveBlock1.playerParty[1] == record)
check("starter map vars and flags match ChoseStarter/RivalTakesStarter",
  session:getVar(EarlyStory.VAR_STARTER_MON) == 2
    and session:getVar(EarlyStory.VAR_OAKS_LAB_SCENE) == 3
    and session:getFlag(EarlyStory.FLAG_SYS_POKEMON_GET)
    and session:getFlag(EarlyStory.FLAG_PALLET_LADY_NOT_BLOCKING_SIGN))
local function dexBit(bytes, national)
  local zero = national - 1
  local b = string.byte(bytes, math.floor(zero / 8) + 1)
  return math.floor(b / 2^(zero % 8)) % 2 == 1
end
check("ScriptGiveMon seen/caught registration reaches all modeled save arrays",
  dexBit(session.state.saveBlock2.pokedex.seen, 4)
    and dexBit(session.state.saveBlock2.pokedex.owned, 4)
    and dexBit(session.state.saveBlock1.seen1, 4))
check("player and rival ball removals use source local-id counter-pick",
  story:isObjectRemoved(EarlyStory.MAP_OAKS_LAB, 7)
    and story:isObjectRemoved(EarlyStory.MAP_OAKS_LAB, 6)
    and not story:isObjectRemoved(EarlyStory.MAP_OAKS_LAB, 5)
    and session:getFlag(EarlyStory.FLAG_HIDE_CHARMANDER_BALL)
    and session:getFlag(EarlyStory.FLAG_HIDE_SQUIRTLE_BALL)
    and not session:getFlag(EarlyStory.FLAG_HIDE_BULBASAUR_BALL))
local rivalGate = story:onStep(EarlyStory.MAP_OAKS_LAB, 6, 8, leaveEvents)
check("scene 3 lab exit starts the correct mandatory rival trainer",
  rivalGate and rivalGate.kind == "rivalBattle" and rivalGate.trainerId == 326
    and rivalGate.y == 8 and rivalGate.lane == 2)
story:registerSeen(7)
check("trainer send-out registers the rival species seen but not owned",
  dexBit(session.state.saveBlock2.pokedex.seen, 7)
    and dexBit(session.state.saveBlock1.seen1, 7)
    and not dexBit(session.state.saveBlock2.pokedex.owned, 7))
local completed = story:completeRivalBattle("playerLost", 326)
check("early-rival loss returns to the common script without whiteout",
  completed.outcome == "playerLost" and session:getVar(EarlyStory.VAR_OAKS_LAB_SCENE) == 4
    and session:getFlag(EarlyStory.FLAG_BEAT_RIVAL_IN_OAKS_LAB)
    and session:getFlag(EarlyStory.FLAG_HIDE_RIVAL_IN_OAKS_LAB)
    and session:getFlag(EarlyStory.TRAINER_FLAGS_START + 326)
    and story:isObjectRemoved(EarlyStory.MAP_OAKS_LAB, 8))

local expectedTrainer = {
  {localId=5,trainerId=328,triggerX=5},
  {localId=6,trainerId=327,triggerX=6},
  {localId=7,trainerId=326,triggerX=7},
}
for _, fixture in ipairs(expectedTrainer) do
  local localId, trainerId = fixture.localId, fixture.trainerId
  local s = App.GameSession.fromNewGame({
    playerGender=Flow.MALE, playerName=Flow.encodeName("RED"), rivalName=Flow.encodeName("GREEN"),
  }, { nextRandom16=function() return 1 end, generatedTrainerIdLower=2 })
  s:setVar(EarlyStory.VAR_OAKS_LAB_SCENE, 2)
  local st = EarlyStory.new(s)
  local choice = st:beginStarterChoice(EarlyStory.MAP_OAKS_LAB, localId).choice
  st:acceptStarter({species=choice.species,box=string.rep("\0",80),hp=20,maxHP=20}, choice.species)
  local gate = st:onStep(EarlyStory.MAP_OAKS_LAB, fixture.triggerX, 8, leaveEvents)
  check(("starter ball %d maps to source trainer %d"):format(localId, trainerId),
    gate and gate.trainerId == trainerId and gate.lane == fixture.triggerX - 4
      and gate.x == fixture.triggerX and gate.y == 8)
  st:completeRivalBattle("playerWon", trainerId)
  local otherFlagsClear = true
  for otherId=326,328 do
    if otherId ~= trainerId and s:getFlag(EarlyStory.TRAINER_FLAGS_START + otherId) then
      otherFlagsClear = false
    end
  end
  check(("trainer %d win sets only its trainer flag and scene 4"):format(trainerId),
    s:getFlag(EarlyStory.TRAINER_FLAGS_START + trainerId)
      and otherFlagsClear and s:getVar(EarlyStory.VAR_OAKS_LAB_SCENE) == 4)
end

print(("early_story_test: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
