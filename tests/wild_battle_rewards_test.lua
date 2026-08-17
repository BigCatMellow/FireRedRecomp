-- Coverage for EarlyRivalRewards.applyWildVictory: the same real
-- Cmd_getexp EXP/EV/friendship/level-up math as the Oak-lab rival win
-- (early_rival_battle_test.lua covers that path directly), but without
-- the real BATTLE_TYPE_TRAINER 150% bonus, and tolerating a level-up
-- crossing a learnset move threshold instead of erroring.
-- Run: lua5.1 tests/wild_battle_rewards_test.lua
package.path = package.path .. ";./?.lua"

local BoxPokemonCodec = require("src.core.BoxPokemonCodec")
local Rewards = require("src.core.EarlyRivalRewards")
local StarterPokemonFactory = require("src.core.StarterPokemonFactory")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local natures = {}
for i = 0, 24 do natures[i] = { attack=0, defense=0, speed=0, spAttack=0, spDefense=0 } end

local bulba = {
  baseHP=45, baseAttack=49, baseDefense=49, baseSpeed=45, baseSpAttack=65, baseSpDefense=65,
  types={12,3}, catchRate=45, expYield=64, evYield={hp=0,attack=0,defense=0,speed=0,spAttack=1,spDefense=0},
  genderRatio=31, friendship=70, growthRate=3, abilities={65,0},
}
local char = {
  baseHP=39, baseAttack=52, baseDefense=43, baseSpeed=65, baseSpAttack=60, baseSpDefense=50,
  types={10,10}, catchRate=45, expYield=65, evYield={hp=0,attack=0,defense=0,speed=1,spAttack=0,spDefense=0},
  genderRatio=31, friendship=70, growthRate=3, abilities={66,0},
}
local species = { [1]=bulba, [4]=char }
local moves = { [33]={pp=35}, [45]={pp=40} }
local learnset = { {level=1, move=33}, {level=1, move=45}, {level=7, move=73} }
local trainerName = string.char(0xCC,0xBF,0xBE,0xFF,0xFF,0xFF,0xFF)

local function newStarter()
  return StarterPokemonFactory.generate({
    species=1, speciesInfo=bulba, speciesName=string.rep(string.char(0xBC), 9) .. string.char(0xFF),
    learnset=learnset, battleMoves=moves, natures=natures, rng={ index=0,
      next16 = function(self) self.index = self.index + 1; return 0 end },
    trainer={id=1, name=trainerName, gender=0}, metLocation=88,
  })
end

-- Real Cmd_getexp: calculatedExp = floor(65 * 5 / 7) = 46, no trainer
-- bonus for a wild win (early_rival_battle_test.lua's identical fixture
-- gets 69 == floor(46 * 150/100), confirming 46 is the real pre-bonus base).
local record = newStarter()
local reward = Rewards.applyWildVictory(record, { species=4, level=5 }, species, natures, learnset, 88)
check("wild win gets base EXP with no trainer-battle bonus", reward.exp == 46, reward.exp)
check("wild win still levels up and applies EVs/friendship the same real way",
  reward.oldLevel == 5 and reward.newLevel == 6 and record.level == 6)
local rewarded = BoxPokemonCodec.decode(record.box)
check("wild win grants the foe's real EV yield", rewarded.substructs[2].speedEV == 1)
check("wild win applies the real friendship-on-levelup delta", rewarded.substructs[0].friendship == 76)

-- A level-up move threshold crossed by a wild win must not error (unlike
-- the rival path's strict assertion) -- it's skipped and reported.
do
  local crossingLearnset = { {level=1, move=33}, {level=6, move=73} }
  local crossingRecord = newStarter()
  local crossingReward = Rewards.applyWildVictory(crossingRecord, { species=4, level=5 },
    species, natures, crossingLearnset, 88)
  check("a crossed level-up move is reported, not taught or errored",
    crossingReward.skippedLevelUpMoves ~= nil
      and crossingReward.skippedLevelUpMoves[1].move == 73
      and crossingReward.skippedLevelUpMoves[1].level == 6)
  check("the untaught move never enters the party record's move list",
    #crossingRecord.moves == 2 and crossingRecord.moves[1].move == 33
      and crossingRecord.moves[2].move == 45)
end

-- The original rival caller's behavior is provably unchanged: same
-- inputs as early_rival_battle_test.lua's first case still error on a
-- learnset gap by default (opts omitted).
do
  local gapLearnset = { {level=1, move=33}, {level=6, move=73} }
  local gapRecord = newStarter()
  local ok, err = pcall(Rewards.applyVictory, gapRecord, { species=4, level=5 },
    species, natures, gapLearnset, 88)
  check("applyVictory's default behavior (no opts) still errors on a learnset gap",
    not ok and tostring(err):find("unexpectedly requires level%-up move") ~= nil)
end

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
