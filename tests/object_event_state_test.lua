-- Unit test: verifies ObjectEventState's real movement-type behavior
-- (initial facing, MOVEMENT_TYPE_FACE_*/NONE stationary idle,
-- MOVEMENT_TYPE_WANDER_AROUND's real pause/pick-direction/step/repeat
-- cycle and real movement-range fencing) against pokefirered's real
-- src/event_object_movement.c logic, plus ObjectEventInteraction's
-- facing-adjacency trigger detection. Pure Lua, no ROM/love2d needed.
--
-- Run: lua5.1 tests/object_event_state_test.lua
package.path = package.path .. ";./?.lua"
local ObjectEventState = require("src.core.ObjectEventState")
local ObjectEventInteraction = require("src.core.ObjectEventInteraction")
local Rng = require("src.core.Rng")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- Real Pallet Town Sign Lady (MapEvents.lua's already-verified fixture):
-- graphicsId=OBJ_EVENT_GFX_WOMAN_1(23), x=3,y=10, movementType=
-- MOVEMENT_TYPE_WANDER_AROUND(2), rangeX=1, rangeY=4.
local signLadyTemplate = {
  localId = 1, graphicsId = 23, kind = 0, x = 3, y = 10,
  elevation = 3, movementType = 2, movementRangeX = 1, movementRangeY = 4,
  trainerType = 0, scriptPtr = 0x0816575c, flagId = 0,
}

-- Real Pallet Town Prof Oak: graphicsId=OBJ_EVENT_GFX_PROF_OAK(71), x=10,y=8,
-- movementType=MOVEMENT_TYPE_FACE_UP(7).
local profOakTemplate = {
  localId = 3, graphicsId = 71, kind = 0, x = 10, y = 8,
  elevation = 3, movementType = 7, movementRangeX = 1, movementRangeY = 1,
  trainerType = 0, scriptPtr = 0, flagId = 0,
}

local cloneTemplate = { localId = 13, kind = 255, x = -7, y = 21, targetLocalId = 7, targetMapNum = 34, targetMapGroup = 3 }

do
  local npcs, skippedClones = ObjectEventState.new({ [0] = signLadyTemplate, [1] = profOakTemplate, [2] = cloneTemplate })
  check("2 real object-event NPCs built", #npcs == 2, #npcs)
  check("1 clone skipped, not silently dropped", #skippedClones == 1 and skippedClones[1].targetLocalId == 7)

  local signLady, profOak = npcs[1], npcs[2]
  check("Sign Lady spawns at her real x/y", signLady.x == 3 and signLady.y == 10)
  check("Sign Lady's real initial facing is DOWN (WANDER_AROUND -> DIR_SOUTH)", signLady.facingDirection == ObjectEventState.DOWN)
  check("Prof Oak's real initial facing is UP (MOVEMENT_TYPE_FACE_UP -> DIR_NORTH)", profOak.facingDirection == ObjectEventState.UP)

  -- MOVEMENT_TYPE_FACE_UP: real MovementType_FaceDirection idles forever
  -- after the initial face -- ticking it must be a genuine no-op, not an
  -- error (this is REAL behavior, not an unimplemented stub).
  for _ = 1, 200 do profOak:tick() end
  check("Prof Oak (FACE_UP) never moves, ticking is a real no-op", profOak.x == 10 and profOak.y == 8 and profOak.facingDirection == ObjectEventState.UP)
end

-- MOVEMENT_TYPE_NONE: also a real stationary no-op.
do
  local template = { localId = 5, graphicsId = 1, kind = 0, x = 4, y = 4, movementType = 0, movementRangeX = 0, movementRangeY = 0, scriptPtr = 0, flagId = 0 }
  local npcs = ObjectEventState.new({ [0] = template })
  local npc = npcs[1]
  check("MOVEMENT_TYPE_NONE's real initial facing is DOWN", npc.facingDirection == ObjectEventState.DOWN)
  npc:tick()
  check("MOVEMENT_TYPE_NONE never moves", npc.x == 4 and npc.y == 4)
end

-- Unknown/unimplemented movement type: must fail loudly, never silently no-op.
do
  local template = { localId = 6, graphicsId = 1, kind = 0, x = 0, y = 0, movementType = 0x19, movementRangeX = 0, movementRangeY = 0, scriptPtr = 0, flagId = 0 } -- WALK_UP_AND_DOWN, not implemented
  local npcs = ObjectEventState.new({ [0] = template })
  local ok, err = pcall(function() npcs[1]:tick() end)
  check("unimplemented movement type errors loudly on tick", not ok and tostring(err):find("no ported per%-tick behavior") ~= nil, err)
end

-- WANDER_AROUND with a real Rng.lua instance: drive many ticks and confirm
-- it (a) actually moves at some point, (b) never leaves its real
-- movement-range fence (rangeX=1/rangeY=4 around its initialX/Y=3,10 --
-- IsCoordOutsideObjectEventMovementRange's real x in [2,4], y in [6,14]),
-- and (c) only ever walks one tile at a time (never teleports).
do
  local npcs = ObjectEventState.new({ [0] = signLadyTemplate }, { rng = Rng.new(12345) })
  local signLady = npcs[1]
  local everMoved = false
  local prevX, prevY = signLady.x, signLady.y
  for _ = 1, 20000 do
    signLady:tick()
    local dx, dy = math.abs(signLady.x - prevX), math.abs(signLady.y - prevY)
    if dx > 1 or dy > 1 or (dx == 1 and dy == 1) then
      check("wander never jumps more than one tile per completed step", false, ("(%d,%d)->(%d,%d)"):format(prevX, prevY, signLady.x, signLady.y))
      break
    end
    if signLady.x ~= prevX or signLady.y ~= prevY then everMoved = true end
    check("wander stays within its real movement range (x in [2,4])", signLady.x >= 2 and signLady.x <= 4, signLady.x)
    check("wander stays within its real movement range (y in [6,14])", signLady.y >= 6 and signLady.y <= 14, signLady.y)
    prevX, prevY = signLady.x, signLady.y
  end
  check("wander actually moves over 20000 ticks", everMoved)
end

-- WANDER_AROUND requires an injected Rng -- must fail loudly if omitted,
-- not silently sit still forever pretending to be a FACE_* type.
do
  local npcs = ObjectEventState.new({ [0] = signLadyTemplate })
  local ok, err = pcall(function() npcs[1]:tick() end)
  check("WANDER_AROUND without opts.rng errors loudly", not ok and tostring(err):find("opts.rng") ~= nil, err)
end

-- Movement-range fencing with rangeX/rangeY == 0 (real convention: 0 means
-- unrestricted on that axis).
do
  check("rangeX=0 does not fence the x axis", not ObjectEventState.isOutsideRange({ initialX = 5, initialY = 5, rangeX = 0, rangeY = 2 }, 999, 5))
  check("rangeY=2 still fences the y axis", ObjectEventState.isOutsideRange({ initialX = 5, initialY = 5, rangeX = 0, rangeY = 2 }, 999, 8))
end

-- ObjectEventInteraction.findInteractionTarget: real "player faces an
-- object event" adjacency check.
do
  local npcs = ObjectEventState.new({ [0] = signLadyTemplate, [1] = profOakTemplate })
  -- Player at (3,9), facing down -> targets tile (3,10), exactly Sign Lady's spawn tile.
  local target = ObjectEventInteraction.findInteractionTarget(3, 9, ObjectEventState.DOWN, npcs)
  check("player facing down at (3,9) finds Sign Lady at (3,10)", target == npcs[1])

  -- Player at (10,9), facing up -> targets (10,8), exactly Prof Oak's tile.
  local target2 = ObjectEventInteraction.findInteractionTarget(10, 9, ObjectEventState.UP, npcs)
  check("player facing up at (10,9) finds Prof Oak at (10,8)", target2 == npcs[2])

  -- Player facing an empty tile finds nothing.
  local target3 = ObjectEventInteraction.findInteractionTarget(0, 0, ObjectEventState.DOWN, npcs)
  check("facing an empty tile finds no NPC", target3 == nil)

  -- FireRed's GetInteractedObjectEventScript probes exactly one tile beyond
  -- an empty MB_COUNTER tile. This allows shop-clerk interaction without
  -- allowing arbitrary interaction through walls.
  local clerk = { x = 2, y = 3, localId = 1 }
  local counterBehavior = function(x, y)
    return x == 3 and y == 3 and ObjectEventInteraction.MB_COUNTER or 0
  end
  local counterTarget = ObjectEventInteraction.findInteractionTarget(4, 3, ObjectEventState.LEFT,
    { clerk }, { behaviorAt = counterBehavior })
  check("MB_COUNTER probes one tile beyond to find a clerk", counterTarget == clerk)
  local wallTarget = ObjectEventInteraction.findInteractionTarget(4, 3, ObjectEventState.LEFT,
    { clerk }, { behaviorAt = function() return 0 end })
  check("non-counter faced tile does not permit through-wall interaction", wallTarget == nil)
  local adjacentCounterNpc = { x = 3, y = 3, localId = 2 }
  local precedence = ObjectEventInteraction.findInteractionTarget(4, 3, ObjectEventState.LEFT,
    { adjacentCounterNpc, clerk }, { behaviorAt = counterBehavior })
  check("adjacent object wins over counter fallback", precedence == adjacentCounterNpc)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
