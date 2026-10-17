-- Unit test: verifies PlayerMovement's real grid-walk timing (16 frames/
-- tile, matching the real sSpeedNormalStepFuncs Step1 x16) and collision
-- blocking, against a synthetic isBlocked callback (no ROM needed).
-- Run: lua5.1 tests/player_movement_test.lua
package.path = package.path .. ";./?.lua"
local PlayerMovement = require("src.core.PlayerMovement")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local function neverBlocked() return false end

-- Starts stationary at the given tile.
do
  local p = PlayerMovement.new(5, 5, PlayerMovement.DOWN)
  check("starts at the given tile", p.tileX == 5 and p.tileY == 5)
  check("starts not moving", not p.moving)
  check("starting pixel position matches the tile (5*16, 5*16)", p:pixelX() == 80 and p:pixelY() == 80)
end

-- A real tile-to-tile walk takes exactly 16 frames (real Step1 x16).
do
  local p = PlayerMovement.new(0, 0, PlayerMovement.DOWN)
  p:tryMove(PlayerMovement.DOWN, neverBlocked)
  check("starts moving after tryMove into open space", p.moving)
  for i = 1, 15 do p:tick() end
  check("still on the old tile after 15 of 16 frames", p.tileY == 0 and p.moving)
  check("pixel position is 15/16 of the way to the next tile", p:pixelY() == 15)
  p:tick()
  check("arrives at the new tile on exactly the 16th frame", p.tileY == 1 and not p.moving)
  check("pixel position exactly matches the new tile", p:pixelY() == 16)
end

-- Each real direction moves the correct axis.
do
  local p = PlayerMovement.new(5, 5, PlayerMovement.DOWN)
  p:tryMove(PlayerMovement.RIGHT, neverBlocked)
  for i = 1, 16 do p:tick() end
  check("RIGHT moves +1 tileX", p.tileX == 6 and p.tileY == 5)
  p:tryMove(PlayerMovement.UP, neverBlocked)
  for i = 1, 16 do p:tick() end
  check("UP moves -1 tileY", p.tileX == 6 and p.tileY == 4)
  p:tryMove(PlayerMovement.LEFT, neverBlocked)
  for i = 1, 16 do p:tick() end
  check("LEFT moves -1 tileX", p.tileX == 5 and p.tileY == 4)
end

-- A blocked destination: the player turns to face that direction but
-- does not move (matches real GBA behavior -- walking into an obstacle
-- still updates facing).
do
  local p = PlayerMovement.new(5, 5, PlayerMovement.DOWN)
  local function alwaysBlocked() return true end
  p:tryMove(PlayerMovement.UP, alwaysBlocked)
  check("facing updates even when blocked", p.facingDirection == PlayerMovement.UP)
  check("does not start moving when blocked", not p.moving)
  check("stays on the same tile when blocked", p.tileX == 5 and p.tileY == 5)
end

-- Only the destination tile is checked, not the current tile or
-- unrelated tiles.
do
  local p = PlayerMovement.new(5, 5, PlayerMovement.DOWN)
  local checkedCoords = {}
  local function isBlocked(x, y)
    checkedCoords[#checkedCoords + 1] = x .. "," .. y
    return x == 5 and y == 6
  end
  p:tryMove(PlayerMovement.DOWN, isBlocked)
  check("checks exactly the real destination tile (5,6)", checkedCoords[1] == "5,6" and #checkedCoords == 1, table.concat(checkedCoords, "|"))
  check("blocked destination prevents movement", not p.moving)
end

-- Movement can't be redirected mid-step (matches real hardware not
-- accepting a new direction until the current step finishes).
do
  local p = PlayerMovement.new(0, 0, PlayerMovement.DOWN)
  p:tryMove(PlayerMovement.DOWN, neverBlocked)
  p:tick(); p:tick()
  local yBefore = p.tileY
  p:tryMove(PlayerMovement.RIGHT, neverBlocked) -- should be ignored, still mid-step
  check("a tryMove during an in-progress step is ignored", p.moveDy ~= 0 and p.moveDx == 0)
  for i = 1, 14 do p:tick() end
  check("original DOWN movement completes uninterrupted", p.tileX == 0 and p.tileY == 1)
end

-- Ledge jump: moving toward a tile whose real jump direction matches
-- the direction of movement covers 2 tiles over the same 16-frame
-- duration, bypassing isBlocked entirely.
do
  local p = PlayerMovement.new(5, 5, PlayerMovement.UP)
  local function alwaysBlocked() return true end
  local function ledgeSouth(x, y)
    if x == 5 and y == 6 then return PlayerMovement.DOWN end
    return nil
  end
  p:tryMove(PlayerMovement.DOWN, alwaysBlocked, ledgeSouth)
  check("ledge jump starts moving despite isBlocked saying true", p.moving)
  check("ledge jump targets 2 tiles away", p.destTileX == 5 and p.destTileY == 7, p.destTileX .. "," .. p.destTileY)
  check("ledge jump moves at double px/frame", p.moveDy == 2, p.moveDy)
  for i = 1, 16 do p:tick() end
  check("ledge jump lands exactly 2 tiles south", p.tileX == 5 and p.tileY == 7, p.tileX .. "," .. p.tileY)
  check("ledge jump finishes in the real 16-frame duration", not p.moving)
end

-- A ledge only triggers when moved into from its matching real
-- direction -- approaching from a different direction is normal
-- blocked/unblocked movement, not a jump.
do
  local p = PlayerMovement.new(5, 5, PlayerMovement.DOWN)
  local function neverBlockedHere() return false end
  local function ledgeSouth(x, y)
    if x == 5 and y == 6 then return PlayerMovement.DOWN end
    return nil
  end
  p:tryMove(PlayerMovement.RIGHT, neverBlockedHere, ledgeSouth) -- destination (6,5), not the ledge tile
  check("non-matching direction is a normal 1-tile move", p.destTileX == 6 and p.destTileY == 5)
  check("non-matching direction moves at normal px/frame", p.moveDx == 1, p.moveDx)
end

-- c75f352 event_object_movement.c:8400–8411, 5110–5121, 5309–5346:
-- literal expectations below are source-derived, not computed by a second
-- copy of the implementation. These test admitted normal motion, not terrain
-- elevation collision admission (which this project still does not port).
local function elevationPlayer(heights, fresh)
  local p, generation = PlayerMovement.new(0, 0, PlayerMovement.RIGHT), { value=1 }
  local reads = {}
  p:bindElevationSource(function(x, y)
    reads[#reads+1] = {x, y}
    if y == 0 then return heights[x] end
  end, function() return generation.value end)
  if fresh then p:bootstrapElevation() end
  return p, generation, reads
end
local function state(name, p, current, effective, valid)
  local value, reason = p:getEffectiveElevation()
  check(name, p.currentElevation == current and p.previousElevation == effective
    and p.elevationValid == valid and value == effective
    and (valid and reason == nil or not valid and type(reason) == "string"))
end
local function start(p)
  p:tryMove(PlayerMovement.RIGHT, neverBlocked, nil, "normal")
end
local function finish(p, ticks)
  for _=1,ticks or 16 do p:tick() end
end
for _, case in ipairs({
  -- spawn, destination, C/E after begin, C/E after finish
  {3,4,4,4,4,4}, {0,3,3,3,3,3}, {15,3,0,0,3,3},
  {3,0,0,3,0,3}, {3,15,3,3,3,3},
}) do
  local p, _, reads = elevationPlayer({[0]=case[1], [1]=case[2]}, true)
  state("raw fresh avatar is known zero", p, 0, 0, true)
  start(p)
  check("no premature begin sampling in tryMove", #reads == 0)
  p:tick()
  state("literal begin " .. case[1] .. "->" .. case[2], p, case[3], case[4], true)
  check("spawn precedes destination/origin begin sample", #reads == 4
    and reads[1][1] == 0 and reads[2][1] == 0 and reads[3][1] == 1 and reads[4][1] == 0)
  finish(p, 14)
  check("frame15 retains origin/pixels and does not resample", p.moving and p.tileX == 0
    and p:pixelX() == 15 and #reads == 4)
  p:tick()
  state("literal finish " .. case[1] .. "->" .. case[2], p, case[5], case[6], true)
  check("frame16 samples destination twice after arrival", not p.moving and p.tileX == 1
    and p:pixelX() == 16 and #reads == 6 and reads[5][1] == 1 and reads[6][1] == 1)
end
for _, case in ipairs({{15,4,3,3,4,4}, {15,0,3,3,0,3}, {0,4,4,4,4,4}}) do
  local p = elevationPlayer({[0]=3, [1]=case[1], [2]=case[2]}, true)
  start(p); finish(p); start(p); p:tick()
  state("later step begin " .. case[1] .. "->" .. case[2], p, case[3], case[4], true)
  finish(p, 15)
  state("later step finish " .. case[1] .. "->" .. case[2], p, case[5], case[6], true)
end
for _, blocked in ipairs({false, true}) do
  local heights = {[0]=3, [1]=4}
  local p, _, reads = elevationPlayer(heights, true)
  if blocked then p:tryMove(PlayerMovement.RIGHT, function() return true end, nil, "normal") end
  p:tick()
  state("pending spawn samples while standing/blocked " .. tostring(blocked), p, 3, 3, true)
  check("no displaced step from blocked/standing spawn", not p.moving and p.tileX == 0 and #reads == 2)
  heights[0] = 4
  if blocked then p:tryMove(PlayerMovement.RIGHT, function() return true end, nil, "normal") end
  p:tick()
  state("no pending flag does not resample " .. tostring(blocked), p, 3, 3, true)
  check("stationary sample count unchanged", #reads == 2)
end
for _, destination in ipairs({0, 15, 4}) do
  local p = elevationPlayer({[0]=3, [1]=destination}, false)
  check("debug constructor unknown", p:getEffectiveElevation() == nil)
  start(p); p:tick()
  check("unknown never recovers at begin " .. destination, p:getEffectiveElevation() == nil)
  finish(p, 15)
  if destination == 4 then state("ordinary finish converges", p, 4, 4, true)
  else check("finish0/15 cannot recover", p:getEffectiveElevation() == nil and not p.elevationValid) end
end
do
  local p = elevationPlayer({[0]=0}, true)
  p:tick(); state("known E0 distinct from unknown", p, 0, 0, true)
end
for _, invalid in ipairs({false, "3", -1, 16, 1.5, math.huge, 0/0}) do
  local p = elevationPlayer({[0]=invalid}, true)
  p:tick()
  check("malformed height is unknown " .. tostring(invalid), p:getEffectiveElevation() == nil
    and p.elevationReason == "missing_elevation_sample")
end
do
  local p = elevationPlayer({}, true)
  p:tick(); check("missing height is unknown", p:getEffectiveElevation() == nil)
  local unwired = PlayerMovement.new(0,0)
  unwired:bootstrapElevation()
  check("bootstrap without production reader is unknown", unwired:getEffectiveElevation() == nil)
  local missingGeneration = elevationPlayer({[0]=3}, true)
  missingGeneration.readElevationGeneration=function() return nil end
  missingGeneration:tick()
  check("missing map generation refuses bootstrap provenance", missingGeneration:getEffectiveElevation()==nil
    and missingGeneration.elevationProvenance==nil)
end
for _, mode in ipairs({"script", "developer", "normal"}) do
  local p = elevationPlayer({[0]=3, [1]=4, [2]=4}, true)
  p:tick()
  p:tryMove(PlayerMovement.RIGHT, neverBlocked,
    mode == "normal" and function() return PlayerMovement.RIGHT end or nil, mode)
  finish(p)
  check("unqualified/ledge does not converge " .. mode, p:getEffectiveElevation() == nil)
end
for _, mode in ipairs({"script", "developer"}) do
  local p = elevationPlayer({[0]=3, [1]=4}, true)
  start(p); p:tick()
  p:tryMove(PlayerMovement.DOWN, neverBlocked, nil, mode)
  finish(p,15)
  check("unqualified takeover cannot inherit active normal step "..mode,
    p.tileX==1 and p.tileY==0 and p:getEffectiveElevation()==nil)
end
do
  local p, generation = elevationPlayer({[0]=3, [1]=4, [2]=3}, true)
  p:tick(); start(p); p:tick()
  generation.value = 2
  finish(p, 15)
  check("map mismatch cancels pending finish", p:getEffectiveElevation() == nil and p.elevationStep == nil)
  start(p); finish(p)
  state("next ordinary finish may converge in new map", p, 3, 3, true)
  check("normal finish records live provenance", p.elevationProvenance=="normal_finish")
  p:invalidateElevation("same_position_relocation")
  check("same tile explicit invalidation", p:getEffectiveElevation() == nil)
end
do
  local p = elevationPlayer({[0]=3, [1]=4, [2]=3}, true)
  p:tick(); p.tileX = 1
  check("direct coordinate mutation invalidates", p:getEffectiveElevation() == nil
    and p.elevationReason == "coordinate_changed")
  start(p); p.destTileX = 0; finish(p)
  check("destination mutation cancels elevation work", p:getEffectiveElevation() == nil)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
