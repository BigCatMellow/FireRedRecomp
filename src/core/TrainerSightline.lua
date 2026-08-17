-- Real trainer "sightline" detection, ported from pokefirered's
-- src/trainer_see.c. Pure Lua, no love2d/ROM access -- operates on
-- ObjectEventState.lua's already-built NPC state tables (which now carry
-- the real trainerType/trainerRange fields, see that module's :new()) plus
-- the player's current tile position/facing.
--
-- Real entry point traced: field_control_avatar.c:209's
-- `CheckForTrainersWantingBattle()` (called every step the player takes
-- while not already scripted/locked) -> trainer_see.c:88.
--
--   bool8 CheckForTrainersWantingBattle(void)
--   {
--       for (i = 0; i < OBJECT_EVENTS_COUNT; i++)
--           if (gObjectEvents[i].active
--            && (gObjectEvents[i].trainerType == TRAINER_TYPE_NORMAL
--             || gObjectEvents[i].trainerType == TRAINER_TYPE_BURIED)
--            && CheckTrainer(i))
--               return TRUE;
--       return FALSE;
--   }
--
-- IMPORTANT real quirk, ported exactly rather than "fixed": the OUTER loop
-- only ever calls CheckTrainer for TRAINER_TYPE_NORMAL(1) or
-- TRAINER_TYPE_BURIED(3) object events -- TRAINER_TYPE_SEE_ALL_DIRECTIONS(2)
-- is never reached from here, even though GetTrainerApproachDistance
-- (below) has a real branch for it. This module's findTrainerWantingBattle
-- reproduces that same outer filter, not a "more correct" superset of it.
--
-- CheckTrainer (trainer_see.c:105) additionally gates on
-- `GetTrainerFlagFromScriptPointer(script)` (skip if this trainer's
-- FightTrainerFlag is already set, i.e. already defeated) and a doubles
-- mismatch check for TRAINER_BATTLE_DOUBLE scripts (`GetMonsStateToDoubles`)
-- before calling ConfigureAndSetUpOneTrainerBattle. Both real checks read
-- state this pure geometry module has no access to (the trainer's own
-- decoded trainerbattle script bytecode / the live player party) -- they
-- are exposed here as the optional `opts.alreadyBattled(trainer)` hook,
-- matching this project's established isBlocked-hook convention
-- (PlayerMovement.lua/ObjectEventState.lua). The doubles-mismatch check is
-- left entirely to the caller, once it has decoded the trainer's actual
-- trainerbattle instruction via ScriptBytecode.lua -- this module only
-- answers "is this trainer looking at the player right now."
--
-- TRAINER_TYPE_BURIED's real "buried in ash" reveal sequence
-- (TrainerSeeFunc_BeginRemoveDisguise/TrainerInAshFacesPlayer/etc, same
-- file) is explicitly commented "Not used in FRLG" at its real definition
-- (trainer_see.c lines 374, 394) -- i.e. real FireRed itself never
-- exercises that sub-path, so BURIED is treated identically to NORMAL
-- here (both use GetTrainerApproachDistance's directional/omnidirectional
-- split the same way real source does), and the disguise reveal state
-- machine is correctly out of scope, not a shortcut.

local TrainerSightline = {}

local DOWN, UP, LEFT, RIGHT = "down", "up", "left", "right"
TrainerSightline.DOWN, TrainerSightline.UP, TrainerSightline.LEFT, TrainerSightline.RIGHT = DOWN, UP, LEFT, RIGHT

-- Real TRAINER_TYPE_* (include/constants/trainer_types.h).
TrainerSightline.TRAINER_TYPE = {
  NONE = 0,
  NORMAL = 1,
  SEE_ALL_DIRECTIONS = 2,
  BURIED = 3,
}

-- Real GetTrainerApproachDistanceSouth (trainer_see.c:149). Returns how far
-- south (in tiles) the player is from the trainer, 0 if out of sight.
-- NOT ported: the real function's extra
-- `if (range > 3 && GetFirstInactiveObjectEventId() == OBJECT_EVENTS_COUNT)
--     return 0;`
-- (trainer_see.c lines 155-156) -- a real-hardware guard against spawning
-- a battle when the game's fixed OBJECT_EVENTS_COUNT object-event pool is
-- already full (so the engine has nowhere to allocate the trainer's
-- approach-walk bookkeeping object). This project has no such fixed-size
-- object pool, so the condition can never real-mean anything here;
-- documented simplification, not a guess.
local function distanceSouth(trainer, range, playerX, playerY)
  if trainer.x == playerX and playerY > trainer.y and playerY <= trainer.y + range then
    return playerY - trainer.y
  end
  return 0
end

-- Real GetTrainerApproachDistanceNorth (trainer_see.c:164).
local function distanceNorth(trainer, range, playerX, playerY)
  if trainer.x == playerX and playerY < trainer.y and playerY >= trainer.y - range then
    return trainer.y - playerY
  end
  return 0
end

-- Real GetTrainerApproachDistanceWest (trainer_see.c:175).
local function distanceWest(trainer, range, playerX, playerY)
  if trainer.y == playerY and playerX < trainer.x and playerX >= trainer.x - range then
    return trainer.x - playerX
  end
  return 0
end

-- Real GetTrainerApproachDistanceEast (trainer_see.c:186).
local function distanceEast(trainer, range, playerX, playerY)
  if trainer.y == playerY and playerX > trainer.x and playerX <= trainer.x + range then
    return playerX - trainer.x
  end
  return 0
end

-- Real sDirectionalApproachDistanceFuncs (trainer_see.c:53), indexed by
-- our down/up/left/right facing strings the same way real source indexes
-- it by (facingDirection - 1) with DIR_SOUTH=1/NORTH=2/WEST=3/EAST=4.
local DISTANCE_FUNC = {
  [DOWN] = distanceSouth,
  [UP] = distanceNorth,
  [LEFT] = distanceWest,
  [RIGHT] = distanceEast,
}
TrainerSightline.distanceFuncByDirection = DISTANCE_FUNC

-- Real CheckPathBetweenTrainerAndPlayer (trainer_see.c:198). Walks the
-- tiles strictly between the trainer and the player (the real loop also
-- checks the trainer's own occupied tile at i=0, but that tile can never
-- itself be "blocked" by terrain/other-object collision against the
-- trainer standing on it, so it's a real no-op we don't reproduce).
-- isBlocked(x, y): same real-terrain-collision hook shape as
-- PlayerMovement.lua/ObjectEventState.lua's `opts.isBlocked` --
-- corresponds to real GetCollisionFlagsAtCoords' impassable/elevation-
-- mismatch/object-event bits (flags 2|4|8, i.e. `COLLISION_MASK = ~1`
-- masking out only the "outside movement range" bit, trainer_see.c:196,
-- 215) blocking the path.
--
-- The final tile (the player's own tile, at `approachDistance`) is NOT
-- run through isBlocked here: real source's final check
-- (`GetCollisionAtCoords(...) == COLLISION_OBJECT_EVENT`) exists to
-- confirm an object (the player) actually occupies that tile -- which is
-- already guaranteed by construction here, since the distance functions
-- above only return nonzero when playerX/playerY is exactly
-- `approachDistance` tiles from the trainer along `direction`.
function TrainerSightline.checkPathClear(trainer, approachDistance, direction, isBlocked)
  if approachDistance == 0 then return false end
  if not isBlocked then return true end

  local delta = ({
    [DOWN] = { dx = 0, dy = 1 }, [UP] = { dx = 0, dy = -1 },
    [LEFT] = { dx = -1, dy = 0 }, [RIGHT] = { dx = 1, dy = 0 },
  })[direction]
  local x, y = trainer.x, trainer.y
  for _ = 1, approachDistance - 1 do
    x, y = x + delta.dx, y + delta.dy
    if isBlocked(x, y) then return false end
  end
  return true
end

-- Real GetTrainerApproachDistance (trainer_see.c:123). For
-- TRAINER_TYPE_NORMAL, only the trainer's own current facing direction is
-- checked ("can only see in one direction"); for SEE_ALL_DIRECTIONS/
-- BURIED, all four directions are tried in real south/north/west/east
-- order and the first one with both a nonzero distance AND a clear path
-- wins. Returns approachDistance (0 if the trainer can't see the player)
-- and the direction that succeeded (nil if none).
function TrainerSightline.getApproachDistance(trainer, playerX, playerY, isBlocked)
  if trainer.trainerType == TrainerSightline.TRAINER_TYPE.NORMAL then
    local distFunc = DISTANCE_FUNC[trainer.facingDirection]
    if not distFunc then
      error("TrainerSightline: unknown facing direction " .. tostring(trainer.facingDirection))
    end
    local distance = distFunc(trainer, trainer.trainerRange, playerX, playerY)
    if distance ~= 0 and TrainerSightline.checkPathClear(trainer, distance, trainer.facingDirection, isBlocked) then
      return distance, trainer.facingDirection
    end
    return 0, nil
  end

  -- TRAINER_TYPE_SEE_ALL_DIRECTIONS / TRAINER_TYPE_BURIED: real south,
  -- north, west, east order (sDirectionalApproachDistanceFuncs index order).
  for _, direction in ipairs({ DOWN, UP, LEFT, RIGHT }) do
    local distance = DISTANCE_FUNC[direction](trainer, trainer.trainerRange, playerX, playerY)
    if distance ~= 0 and TrainerSightline.checkPathClear(trainer, distance, direction, isBlocked) then
      return distance, direction
    end
  end
  return 0, nil
end

-- Real CheckForTrainersWantingBattle (trainer_see.c:88), minus the
-- already-covered-elsewhere doubles-mismatch check (see header). npcs: an
-- ObjectEventState.new() result (or any list of tables shaped the same
-- way -- x, y, facingDirection, trainerType, trainerRange). opts.isBlocked:
-- optional terrain-collision hook, see checkPathClear. opts.alreadyBattled
-- (trainer) -> bool: optional real "FightTrainerFlag already set" hook
-- (see header -- this module has no access to the trainer's own decoded
-- trainerbattle script to derive the flag itself).
--
-- Returns the first trainer (in npcs' list order, matching real source's
-- gObjectEvents index-order scan) that currently wants to battle, plus its
-- approachDistance and the direction it saw the player from -- or nil if
-- none do.
function TrainerSightline.findTrainerWantingBattle(npcs, playerX, playerY, opts)
  opts = opts or {}
  local NORMAL, BURIED = TrainerSightline.TRAINER_TYPE.NORMAL, TrainerSightline.TRAINER_TYPE.BURIED
  for _, trainer in ipairs(npcs) do
    if trainer.trainerType == NORMAL or trainer.trainerType == BURIED then
      if not (opts.alreadyBattled and opts.alreadyBattled(trainer)) then
        local distance, direction = TrainerSightline.getApproachDistance(trainer, playerX, playerY, opts.isBlocked)
        if distance ~= 0 then
          return trainer, distance, direction
        end
      end
    end
  end
  return nil
end

return TrainerSightline
