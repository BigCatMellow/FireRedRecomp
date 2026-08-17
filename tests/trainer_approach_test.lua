-- Unit test: TrainerApproach's real exclamation + walk-up sequence
-- (pokefirered src/trainer_see.c's sTrainerSeeFuncList task chain). Pure
-- Lua, no ROM needed.
--
-- Run: lua5.1 tests/trainer_approach_test.lua
package.path = package.path .. ";./?.lua"
local ObjectEventState = require("src.core.ObjectEventState")
local TrainerApproach = require("src.core.TrainerApproach")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local template = {
  localId = 2, graphicsId = 1, kind = 0, x = 5, y = 5, elevation = 3,
  movementType = 8, movementRangeX = 0, movementRangeY = 0,
  trainerType = 1, trainerRangeOrBerryTreeId = 5, scriptPtr = 0, flagId = 0,
}

-- approachDistance=4 -> real CheckTrainer seeds
-- TrainerApproachPlayer(trainerObj, approachDistance - 1) == 3 tiles walked,
-- stopping one tile short of the player (who is 4 tiles away).
do
  local npcs = ObjectEventState.new({ [0] = template })
  local trainer = npcs[1]
  local approach = TrainerApproach.new(trainer, ObjectEventState.DOWN, 4)

  check("starts in the exclamation state", approach.state == TrainerApproach.STATE_EXCLAMATION)

  -- Real sAnimCmd_ExclamationMark1: 4 + 4 + 52 = 60 frames exactly.
  for _ = 1, TrainerApproach.EXCLAMATION_FRAMES - 1 do approach:tick() end
  check("still in exclamation state one frame before the real 60-frame anim ends",
    approach.state == TrainerApproach.STATE_EXCLAMATION)
  approach:tick()
  check("transitions to walking exactly at the real 60-frame exclamation duration",
    approach.state == TrainerApproach.STATE_WALKING)

  -- Walk 3 tiles (each a real 16-frame step, this project's WALK_FRAMES_PER_TILE).
  local ticks = 0
  while not approach:isDone() and ticks < 1000 do
    approach:tick()
    ticks = ticks + 1
  end
  check("sequence reaches STATE_DONE", approach:isDone())
  check("trainer walked exactly 3 tiles (approachDistance - 1), stopping short of the player",
    trainer.y == 5 + 3 and trainer.x == 5, ("x=%d y=%d"):format(trainer.x, trainer.y))
  check("trainer ends facing the direction it approached from (== facing the player)",
    trainer.facingDirection == ObjectEventState.DOWN)
end

-- approachDistance=1 (player already adjacent): real
-- TrainerApproachPlayer(trainerObj, 0) walks zero tiles -- trainer only
-- plays the exclamation mark and immediately "faces" (no-op) the player.
do
  local npcs = ObjectEventState.new({ [0] = template })
  local trainer = npcs[1]
  local approach = TrainerApproach.new(trainer, ObjectEventState.DOWN, 1)
  for _ = 1, TrainerApproach.EXCLAMATION_FRAMES do approach:tick() end
  check("zero-step approach reaches STATE_WALKING then immediately STATE_DONE on the next tick",
    approach.state == TrainerApproach.STATE_WALKING)
  approach:tick()
  check("adjacent player: trainer never moves, sequence completes immediately",
    approach:isDone() and trainer.x == 5 and trainer.y == 5)
end

-- approachDistance must be a real positive TrainerSightline result.
do
  local npcs = ObjectEventState.new({ [0] = template })
  local ok = pcall(TrainerApproach.new, npcs[1], ObjectEventState.DOWN, 0)
  check("approachDistance == 0 is rejected loudly (not a real TrainerSightline hit)", not ok)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
