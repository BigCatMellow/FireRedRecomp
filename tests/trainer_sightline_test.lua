-- Unit test: TrainerSightline's real sightline geometry, ported from
-- pokefirered's src/trainer_see.c (CheckForTrainersWantingBattle ->
-- GetTrainerApproachDistance -> the 4 directional distance functions ->
-- CheckPathBetweenTrainerAndPlayer). Pure Lua, no ROM needed.
--
-- Run: lua5.1 tests/trainer_sightline_test.lua
package.path = package.path .. ";./?.lua"
local TrainerSightline = require("src.core.TrainerSightline")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local DOWN, UP, LEFT, RIGHT = TrainerSightline.DOWN, TrainerSightline.UP, TrainerSightline.LEFT, TrainerSightline.RIGHT
local NORMAL, SEE_ALL, BURIED = TrainerSightline.TRAINER_TYPE.NORMAL,
  TrainerSightline.TRAINER_TYPE.SEE_ALL_DIRECTIONS, TrainerSightline.TRAINER_TYPE.BURIED

-- A TRAINER_TYPE_NORMAL trainer at (5,5) facing DOWN (south) with range 3:
-- real GetTrainerApproachDistanceSouth requires same x, player strictly
-- south, within range.
do
  local trainer = { x = 5, y = 5, facingDirection = DOWN, trainerType = NORMAL, trainerRange = 3 }

  local dist, dir = TrainerSightline.getApproachDistance(trainer, 5, 8, nil)
  check("player directly south, at max range, is spotted (distance 3)", dist == 3 and dir == DOWN)

  dist = TrainerSightline.getApproachDistance(trainer, 5, 9, nil)
  check("player one tile past max range is NOT spotted", dist == 0)

  dist = TrainerSightline.getApproachDistance(trainer, 6, 8, nil)
  check("player off the trainer's column (same distance) is NOT spotted", dist == 0)

  dist = TrainerSightline.getApproachDistance(trainer, 5, 2, nil)
  check("player north of a south-facing trainer is NOT spotted (behind them)", dist == 0)

  dist = TrainerSightline.getApproachDistance(trainer, 5, 5, nil)
  check("player on the trainer's own tile is NOT spotted (distance must be > 0)", dist == 0)
end

-- Facing gates which of the 4 real per-direction functions applies for
-- TRAINER_TYPE_NORMAL ("can only see in one direction" -- trainer_see.c:130).
do
  local trainerFacingUp = { x = 5, y = 5, facingDirection = UP, trainerType = NORMAL, trainerRange = 5 }
  local dist = TrainerSightline.getApproachDistance(trainerFacingUp, 5, 8, nil)
  check("a south-facing player position is invisible to a north-facing trainer", dist == 0)
  dist = TrainerSightline.getApproachDistance(trainerFacingUp, 5, 2, nil)
  check("north-facing trainer spots a player to their north", dist == 3)

  local trainerFacingLeft = { x = 5, y = 5, facingDirection = LEFT, trainerType = NORMAL, trainerRange = 5 }
  dist = TrainerSightline.getApproachDistance(trainerFacingLeft, 2, 5, nil)
  check("west-facing trainer spots a player to their west", dist == 3)
  dist = TrainerSightline.getApproachDistance(trainerFacingLeft, 8, 5, nil)
  check("west-facing trainer does not see a player to their east", dist == 0)

  local trainerFacingRight = { x = 5, y = 5, facingDirection = RIGHT, trainerType = NORMAL, trainerRange = 5 }
  dist = TrainerSightline.getApproachDistance(trainerFacingRight, 8, 5, nil)
  check("east-facing trainer spots a player to their east", dist == 3)
end

-- Real CheckPathBetweenTrainerAndPlayer: a blocked tile between trainer
-- and player breaks the sightline even though the raw distance math says
-- otherwise.
do
  local trainer = { x = 5, y = 5, facingDirection = DOWN, trainerType = NORMAL, trainerRange = 5 }
  local isBlocked = function(x, y) return x == 5 and y == 7 end -- wall 2 tiles south
  local dist = TrainerSightline.getApproachDistance(trainer, 5, 9, isBlocked)
  check("a blocked tile between trainer and player breaks the sightline", dist == 0)

  local isBlockedElsewhere = function(x, y) return x == 9 and y == 9 end
  dist = TrainerSightline.getApproachDistance(trainer, 5, 9, isBlockedElsewhere)
  check("a block off the sightline path does not affect detection", dist == 4)
end

-- TRAINER_TYPE_SEE_ALL_DIRECTIONS / BURIED: real GetTrainerApproachDistance
-- tries south, north, west, east in that exact real order and returns the
-- first that both has a nonzero distance and a clear path.
do
  local trainer = { x = 5, y = 5, facingDirection = DOWN, trainerType = SEE_ALL, trainerRange = 5 }
  local dist, dir = TrainerSightline.getApproachDistance(trainer, 2, 5, nil) -- player west
  check("SEE_ALL_DIRECTIONS spots a player regardless of the trainer's own facing", dist == 3 and dir == LEFT)

  local buried = { x = 5, y = 5, facingDirection = UP, trainerType = BURIED, trainerRange = 5 }
  dist, dir = TrainerSightline.getApproachDistance(buried, 8, 5, nil) -- player east
  check("BURIED also checks all 4 real directions", dist == 3 and dir == RIGHT)
end

-- findTrainerWantingBattle: real CheckForTrainersWantingBattle's exact
-- outer filter (trainer_see.c:96-99) only fires for trainerType NORMAL or
-- BURIED -- SEE_ALL_DIRECTIONS is real, verified dead code at this outer
-- layer even though GetTrainerApproachDistance itself has a branch for it.
do
  local seeAllTrainer = { x = 5, y = 5, facingDirection = DOWN, trainerType = SEE_ALL, trainerRange = 5, name = "seeAll" }
  local npcs = { seeAllTrainer }
  local found = TrainerSightline.findTrainerWantingBattle(npcs, 2, 5, {})
  check("a SEE_ALL_DIRECTIONS trainer is never found by the real outer loop, even if it could see the player",
    found == nil)

  local normalTrainer = { x = 10, y = 10, facingDirection = DOWN, trainerType = NORMAL, trainerRange = 5, name = "normal" }
  npcs = { seeAllTrainer, normalTrainer }
  local trainer, dist, dir = TrainerSightline.findTrainerWantingBattle(npcs, 10, 13, {})
  check("a NORMAL trainer later in the list is still found", trainer == normalTrainer and dist == 3 and dir == DOWN)
end

-- opts.alreadyBattled: real GetTrainerFlagFromScriptPointer gate (skip a
-- trainer whose FightTrainerFlag is already set).
do
  local trainer = { x = 5, y = 5, facingDirection = DOWN, trainerType = NORMAL, trainerRange = 5, defeated = true }
  local found = TrainerSightline.findTrainerWantingBattle({ trainer }, 5, 8,
    { alreadyBattled = function(t) return t.defeated end })
  check("an already-defeated trainer is skipped even though they could see the player", found == nil)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
