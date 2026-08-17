-- Unit test: TrainerAI's real dispatch (src/battle_ai_script_commands.c's
-- BattleAI_SetupAIData -> BattleAI_ChooseMoveOrAction), the two tiers this
-- project ports: aiFlags==0 (real uniform-random-among-valid-moves) and
-- aiFlags==EarlyRivalAI.AI_FLAGS (delegates to the existing exact port).
-- Pure Lua, no ROM needed.
--
-- Run: lua5.1 tests/trainer_ai_test.lua
package.path = package.path .. ";./?.lua"
local BattleEngine = require("src.core.BattleEngine")
local TrainerAI = require("src.core.TrainerAI")
local EarlyRivalAI = require("src.core.EarlyRivalAI")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local function sequenceRng(values)
  local rng = { index = 0 }
  function rng:next16()
    self.index = self.index + 1
    return values[self.index] or 0
  end
  return rng
end

local TYPE_NORMAL = 0
local moves = {
  [10] = { effect = 0, power = 40, type = TYPE_NORMAL, accuracy = 100, pp = 35, priority = 0 },
  [33] = { effect = 0, power = 35, type = TYPE_NORMAL, accuracy = 95, pp = 35, priority = 0 },
  [39] = { effect = 19, power = 0, type = TYPE_NORMAL, accuracy = 100, pp = 30, priority = 0 },
  [45] = { effect = 18, power = 0, type = TYPE_NORMAL, accuracy = 100, pp = 40, priority = 0 },
}
local typeChart = {}
local stats = { hp = 20, attack = 10, defense = 10, speed = 10, spAttack = 10, spDefense = 10 }

local function battler(id, monMoves)
  return BattleEngine.makeBattler({ species = id, level = 5, stats = stats, types = { TYPE_NORMAL, TYPE_NORMAL }, moves = monMoves })
end

local function newEngine(rng, foeMoves)
  return BattleEngine.new({
    player = battler(1, { { move = 10, pp = 35 } }),
    foe = battler(4, foeMoves),
    moves = moves, typeChart = typeChart, rng = rng,
  })
end

-- aiFlags == 0: real BattleAI_ChooseMoveOrAction's while loop never runs a
-- single AI script (every move's score stays tied at its initialized 100
-- except 0-PP moves, which are zeroed) -- picks uniformly at random among
-- PP-remaining moves.
do
  local rng = sequenceRng({ 0 })
  local engine = newEngine(rng, {
    { move = 10, pp = 35 }, { move = 33, pp = 0 }, { move = 39, pp = 30 }, nil,
  })
  local slot = TrainerAI.choose(engine, 0)
  check("aiFlags=0 returns a real valid move slot (1)", slot == 1, slot)

  -- Force the RNG to select index 2 among the 2 remaining valid slots
  -- ({1, 3}, since slot 2 has 0 PP and slot 4 is empty).
  local rng2 = sequenceRng({ 1 })
  local engine2 = newEngine(rng2, {
    { move = 10, pp = 35 }, { move = 33, pp = 0 }, { move = 39, pp = 30 }, nil,
  })
  local slot2 = TrainerAI.choose(engine2, 0)
  check("aiFlags=0 skips 0-PP and nil move slots, picks slot 3 on the second RNG draw", slot2 == 3, slot2)
end

-- aiFlags == 0 with every move at 0 PP: real Struggle case, not ported --
-- must fail loudly rather than return an invalid slot.
do
  local rng = sequenceRng({ 0 })
  local engine = newEngine(rng, {
    { move = 10, pp = 0 }, { move = 33, pp = 0 }, nil, nil,
  })
  local ok, err = pcall(TrainerAI.choose, engine, 0)
  check("aiFlags=0 with no PP left errors loudly (real Struggle not ported)",
    not ok and tostring(err):find("Struggle") ~= nil, err)
end

-- aiFlags == EarlyRivalAI.AI_FLAGS delegates to EarlyRivalAI.choose exactly
-- (same fixture shape as tests/early_rival_battle_test.lua's tutorial
-- battle, using only the two moves that module supports).
do
  local rng = sequenceRng({ 0, 0, 0, 0, 0, 0, 0, 0 })
  local engine = newEngine(rng, {
    { move = 10, pp = 35 }, { move = 45, pp = 40 }, nil, nil,
  })
  local slot = TrainerAI.choose(engine, EarlyRivalAI.AI_FLAGS)
  check("aiFlags==EarlyRivalAI.AI_FLAGS returns a valid 1-4 move slot", slot == 1 or slot == 2, slot)
end

-- Any other real aiFlags combination is out of this module's ported scope
-- and must fail loudly, not silently approximate.
do
  local rng = sequenceRng({ 0 })
  local engine = newEngine(rng, { { move = 10, pp = 35 }, nil, nil, nil })
  local ok, err = pcall(TrainerAI.choose, engine, TrainerAI.AI_SCRIPT_TRY_TO_FAINT) -- 0x4 alone, not the full rival set
  check("an unported aiFlags combination errors loudly rather than guessing",
    not ok and tostring(err):find("not ported") ~= nil, err)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
