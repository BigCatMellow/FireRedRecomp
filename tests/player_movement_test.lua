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

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
