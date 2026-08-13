-- Per-map runtime NPC (object-event) list, ported from pokefirered's real
-- movement-type state machines (src/event_object_movement.c). Builds one
-- NPC state per real ObjectEventTemplate (import/MapEvents.lua's
-- `.objectEvents` array, indexed 0-based like that module) and drives its
-- position/facing per real tick, the same "pure Lua, no love2d" pattern as
-- PlayerMovement.lua/MenuCursor.lua -- no ROM/graphics decode happens here
-- (see import/ObjectEventGraphicsInfo.lua for graphicsId -> pixels; a
-- caller wires that up separately, see this repo's handoff doc for exactly
-- what a main.lua integration pass needs to do).
--
-- Real per-object state (src/event_object_movement.c's `struct
-- ObjectEvent`) is reduced here to just what movement needs: current tile
-- position, facing direction, the object's ORIGINAL spawn tile (real
-- `objectEvent->initialCoords`, used for real movement-range fencing --
-- IsCoordOutsideObjectEventMovementRange), and rangeX/rangeY (real
-- `movementRangeX`/`movementRangeY`, MapEvents.lua's already-decoded
-- bitfield).
--
-- OBJ_KIND_CLONE templates (MapEvents.lua's `.kind == 255` variant --
-- Celadon City's real clone object is the verified example) are
-- INTENTIONALLY SKIPPED, not silently dropped: `.new()` returns a second
-- `skippedClones` list of the raw template + why, since resolving a real
-- clone object means loading and re-parsing a DIFFERENT map's object-event
-- template (targetMapNum/targetMapGroup/targetLocalId) -- a genuinely
-- separate system this task's brief didn't require, not a shortcut taken
-- silently.
--
-- Real initial facing per movement type (gInitialMovementTypeFacingDirections,
-- src/event_object_movement.c ~line 359) is transcribed IN FULL below (all
-- 0x51 real MOVEMENT_TYPES_COUNT entries) even though only a subset of
-- movement types have real per-tick behavior implemented (see
-- MOVEMENT_TICK below) -- so every real NPC's spawn facing is correct even
-- for a movement type whose ongoing animation isn't ported yet. An
-- unimplemented movement type's NPC still spawns facing the right real
-- direction; only ITS :tick() call errors loudly (see MOVEMENT_TICK), never
-- silently no-ops, per this project's "fail loudly on unimplemented"
-- convention (ScriptInterpreter.lua's unknown-opcode error is the house
-- style this follows).

local PlayerMovement = require("src.core.PlayerMovement")

local ObjectEventState = {}

local DOWN, UP, LEFT, RIGHT = PlayerMovement.DOWN, PlayerMovement.UP, PlayerMovement.LEFT, PlayerMovement.RIGHT
ObjectEventState.DOWN, ObjectEventState.UP, ObjectEventState.LEFT, ObjectEventState.RIGHT = DOWN, UP, LEFT, RIGHT

local DIRECTION_DELTA = {
  [DOWN] = { dx = 0, dy = 1 },
  [UP] = { dx = 0, dy = -1 },
  [LEFT] = { dx = -1, dy = 0 },
  [RIGHT] = { dx = 1, dy = 0 },
}
ObjectEventState.DIRECTION_DELTA = DIRECTION_DELTA

local TILE_SIZE = 16
local WALK_FRAMES_PER_TILE = 16 -- same real "normal speed" as PlayerMovement.lua

-- Real MOVEMENT_TYPE_* numeric ids (include/constants/event_object_movement.h).
local MOVEMENT_TYPE = {
  NONE = 0x0,
  LOOK_AROUND = 0x1,
  WANDER_AROUND = 0x2,
  WANDER_UP_AND_DOWN = 0x3,
  WANDER_DOWN_AND_UP = 0x4,
  WANDER_LEFT_AND_RIGHT = 0x5,
  WANDER_RIGHT_AND_LEFT = 0x6,
  FACE_UP = 0x7,
  FACE_DOWN = 0x8,
  FACE_LEFT = 0x9,
  FACE_RIGHT = 0xA,
  PLAYER = 0xB,
}
ObjectEventState.MOVEMENT_TYPE = MOVEMENT_TYPE

-- Real gInitialMovementTypeFacingDirections[MOVEMENT_TYPES_COUNT], transcribed
-- verbatim (DIR_SOUTH/NORTH/WEST/EAST -> our down/up/left/right strings).
-- Keyed by the real numeric movement type id, not just the ones this module
-- implements ongoing movement for -- see header comment.
local INITIAL_FACING = {
  [0x0] = DOWN,  [0x1] = DOWN,  [0x2] = DOWN,  [0x3] = UP,    [0x4] = DOWN,
  [0x5] = LEFT,  [0x6] = RIGHT, [0x7] = UP,    [0x8] = DOWN,  [0x9] = LEFT,
  [0xA] = RIGHT, [0xB] = DOWN,  [0xC] = DOWN,  [0xD] = DOWN,  [0xE] = LEFT,
  [0xF] = UP,    [0x10] = UP,   [0x11] = DOWN, [0x12] = DOWN, [0x13] = DOWN,
  [0x14] = DOWN, [0x15] = UP,   [0x16] = DOWN, [0x17] = DOWN, [0x18] = DOWN,
  [0x19] = UP,   [0x1A] = DOWN, [0x1B] = LEFT, [0x1C] = RIGHT,
  [0x1D] = UP,   [0x1E] = RIGHT,[0x1F] = DOWN, [0x20] = LEFT, [0x21] = UP,
  [0x22] = LEFT, [0x23] = DOWN, [0x24] = RIGHT,[0x25] = LEFT, [0x26] = UP,
  [0x27] = RIGHT,[0x28] = DOWN, [0x29] = RIGHT,[0x2A] = UP,   [0x2B] = LEFT,
  [0x2C] = DOWN, [0x2D] = UP,   [0x2E] = DOWN, [0x2F] = LEFT, [0x30] = RIGHT,
  [0x31] = UP,   [0x32] = DOWN, [0x33] = LEFT, [0x34] = RIGHT,
  [0x35] = UP,   [0x36] = DOWN, [0x37] = LEFT, [0x38] = RIGHT,
  [0x39] = DOWN, [0x3A] = DOWN, [0x3B] = UP,   [0x3C] = DOWN, [0x3D] = LEFT,
  [0x3E] = RIGHT,[0x3F] = DOWN, [0x40] = DOWN, [0x41] = UP,   [0x42] = LEFT,
  [0x43] = RIGHT,[0x44] = DOWN, [0x45] = UP,   [0x46] = LEFT, [0x47] = RIGHT,
  [0x48] = DOWN, [0x49] = UP,   [0x4A] = LEFT, [0x4B] = RIGHT,[0x4C] = DOWN,
  [0x4D] = DOWN, [0x4E] = DOWN, [0x4F] = DOWN, [0x50] = DOWN,
}
ObjectEventState.INITIAL_FACING = INITIAL_FACING

-- Real gStandardDirections/gUpAndDownDirections/gLeftAndRightDirections
-- (src/data/object_events/movement_type_func_tables.h) -- the real
-- direction pools MovementType_WanderAround*'s Step4 picks a random index
-- from via `Random() & (n-1)`.
local WANDER_POOL = {
  [MOVEMENT_TYPE.WANDER_AROUND] = { DOWN, UP, LEFT, RIGHT }, -- gStandardDirections
  [MOVEMENT_TYPE.WANDER_UP_AND_DOWN] = { DOWN, UP },          -- gUpAndDownDirections
  [MOVEMENT_TYPE.WANDER_DOWN_AND_UP] = { DOWN, UP },
  [MOVEMENT_TYPE.WANDER_LEFT_AND_RIGHT] = { LEFT, RIGHT },    -- gLeftAndRightDirections
  [MOVEMENT_TYPE.WANDER_RIGHT_AND_LEFT] = { LEFT, RIGHT },
}

-- Real gMovementDelaysMedium (src/event_object_movement.c line 679) -- the
-- pause (in frames) MovementType_WanderAround's Step2/Step3 waits between
-- steps, picked by `gMovementDelaysMedium[Random() & 3]`.
local MOVEMENT_DELAYS_MEDIUM = { 32, 64, 96, 128 }

local FACE_DIRECTION_TYPE = {
  [MOVEMENT_TYPE.FACE_UP] = UP,
  [MOVEMENT_TYPE.FACE_DOWN] = DOWN,
  [MOVEMENT_TYPE.FACE_LEFT] = LEFT,
  [MOVEMENT_TYPE.FACE_RIGHT] = RIGHT,
}

-- objectEvents: MapEvents.resolve(...).objectEvents (0-based array).
-- opts.rng: an Rng.lua instance (required if any NPC here uses a WANDER_*
-- movement type -- see :tick()). opts.isBlocked(x, y): optional real
-- terrain-collision hook, same shape as PlayerMovement:tryMove's --
-- omitted, range fencing (real IsCoordOutsideObjectEventMovementRange) is
-- still enforced, matching real GetCollisionInDirection's two checks in
-- order (real object-event/elevation/one-way-ledge collision checks are
-- NOT reproduced here, same documented scope as PlayerMovement.lua).
--
-- Returns (npcs, skippedClones): npcs is a plain array (1-based, Lua
-- convention) of NPC state tables; skippedClones is the raw
-- OBJ_KIND_CLONE templates that weren't turned into NPC state (see header
-- comment).
function ObjectEventState.new(objectEvents, opts)
  opts = opts or {}
  local npcs, skippedClones = {}, {}

  local i = 0
  while objectEvents[i] ~= nil do
    local template = objectEvents[i]
    if template.kind ~= nil and template.kind ~= 0 then
      skippedClones[#skippedClones + 1] = template
    else
      local facing = INITIAL_FACING[template.movementType]
      if not facing then
        error(("ObjectEventState: unknown real movementType 0x%X on localId %d " ..
          "(not in gInitialMovementTypeFacingDirections's real 0x51 entries)"):format(
          template.movementType, template.localId))
      end
      npcs[#npcs + 1] = setmetatable({
        localId = template.localId,
        graphicsId = template.graphicsId,
        movementType = template.movementType,
        scriptPtr = template.scriptPtr,
        flagId = template.flagId,
        rangeX = template.movementRangeX,
        rangeY = template.movementRangeY,
        x = template.x, y = template.y,
        initialX = template.x, initialY = template.y,
        facingDirection = facing,
        moving = false,
        stepFrame = 0,
        moveDx = 0, moveDy = 0,
        destX = template.x, destY = template.y,
        delayFrames = 0,
        rng = opts.rng,
        isBlocked = opts.isBlocked,
      }, { __index = ObjectEventState })
    end
    i = i + 1
  end

  return npcs, skippedClones
end

function ObjectEventState:pixelX()
  return (self.x * TILE_SIZE) + self.moveDx * self.stepFrame
end

function ObjectEventState:pixelY()
  return (self.y * TILE_SIZE) + self.moveDy * self.stepFrame
end

-- Real IsCoordOutsideObjectEventMovementRange (src/event_object_movement.c
-- ~line 4861): rangeX/rangeY of 0 means "unrestricted on that axis" (a real
-- convention -- a real map.json movement_range_x/y of 0 fences nothing).
local function isOutsideRange(npc, x, y)
  if npc.rangeX ~= 0 then
    if x < npc.initialX - npc.rangeX or x > npc.initialX + npc.rangeX then
      return true
    end
  end
  if npc.rangeY ~= 0 then
    if y < npc.initialY - npc.rangeY or y > npc.initialY + npc.rangeY then
      return true
    end
  end
  return false
end
ObjectEventState.isOutsideRange = isOutsideRange

-- Begins a walk to the tile in `direction` if it's real-passable (range
-- fence + optional terrain isBlocked, see :new()'s opts). Always faces the
-- direction first, matching real SetObjectEventDirection being called
-- unconditionally before the collision check (MovementType_WanderAround_Step4).
-- Returns true if the NPC started walking, false if it just turned in place.
local function tryStep(npc, direction)
  npc.facingDirection = direction
  local delta = DIRECTION_DELTA[direction]
  local destX, destY = npc.x + delta.dx, npc.y + delta.dy
  if isOutsideRange(npc, destX, destY) then return false end
  if npc.isBlocked and npc.isBlocked(destX, destY) then return false end

  npc.moving = true
  npc.stepFrame = 0
  npc.moveDx, npc.moveDy = delta.dx * TILE_SIZE / WALK_FRAMES_PER_TILE, delta.dy * TILE_SIZE / WALK_FRAMES_PER_TILE
  npc.destX, npc.destY = destX, destY
  return true
end

-- Advances an in-progress walk by one real frame. Returns true once the
-- step completes (tile position updated), false if still mid-step or not
-- moving.
local function tickWalk(npc)
  if not npc.moving then return false end
  npc.stepFrame = npc.stepFrame + 1
  if npc.stepFrame >= WALK_FRAMES_PER_TILE then
    npc.x, npc.y = npc.destX, npc.destY
    npc.moving = false
    npc.stepFrame = 0
    npc.moveDx, npc.moveDy = 0, 0
    return true
  end
  return false
end

-- Real MovementType_WanderAround (and its WANDER_UP_AND_DOWN/DOWN_AND_UP/
-- LEFT_AND_RIGHT/RIGHT_AND_LEFT siblings, which share the exact same
-- Step0-6 shape with just a different real direction pool/initial facing --
-- see WANDER_POOL above) collapsed into one tick function: pause for a
-- real gMovementDelaysMedium[Random()&3]-frame delay, then face+try a
-- random direction from the pool; a blocked direction (real
-- GetCollisionInDirection != 0) re-loops back into a fresh delay+retry
-- (matching real Step4's `sprite->data[1] = 1` fallback), an open one
-- walks one real tile then loops back to a fresh delay.
local function tickWander(npc, pool)
  if tickWalk(npc) then
    npc.delayFrames = MOVEMENT_DELAYS_MEDIUM[(npc.rng:next16() % 4) + 1]
    return
  end
  if npc.moving then return end

  if npc.delayFrames > 0 then
    npc.delayFrames = npc.delayFrames - 1
    return
  end

  local direction = pool[(npc.rng:next16() % #pool) + 1]
  if not tryStep(npc, direction) then
    -- Real Step4 -> Step1 retry: re-face (already done by tryStep) and
    -- queue a fresh delay before trying again next tick.
    npc.delayFrames = MOVEMENT_DELAYS_MEDIUM[(npc.rng:next16() % 4) + 1]
  end
end

-- Advances this NPC by one real 60Hz-tick-equivalent frame. Requires
-- opts.rng (see :new()) for any WANDER_* movement type; errors loudly for
-- any real movement type not listed here (see header comment) rather than
-- silently doing nothing -- MOVEMENT_TYPE.NONE/FACE_* are real "stationary"
-- types (spawn-facing set once, never moves again -- real
-- MovementType_None/MovementType_FaceDirection's post-init steps are
-- genuine no-ops, so a no-op tick for THOSE ids is the real behavior, not
-- a stub).
function ObjectEventState:tick()
  local movementType = self.movementType
  if movementType == MOVEMENT_TYPE.NONE or FACE_DIRECTION_TYPE[movementType] then
    return -- real MovementType_None/FaceDirection: face once at spawn, then idle forever
  end

  local pool = WANDER_POOL[movementType]
  if pool then
    if not self.rng then
      error("ObjectEventState: WANDER_* movement types need opts.rng (an Rng.lua instance) passed to .new()")
    end
    tickWander(self, pool)
    return
  end

  error(("ObjectEventState: movementType 0x%X on localId %d has no ported per-tick behavior " ..
    "(pokefirered src/event_object_movement.c has a real handler -- not implemented here, " ..
    "see the handoff doc's scope list)"):format(movementType, self.localId))
end

return ObjectEventState
