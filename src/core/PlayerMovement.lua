-- Real grid-based overworld movement, ported from pokefirered's actual
-- per-frame walk animation (src/event_object_movement.c). The real
-- "normal" walk speed is `sSpeedNormalStepFuncs`, a 16-entry array of
-- all `Step1` (each frame moves the sprite exactly 1px in the facing
-- direction): 16 frames x 1px = one 16px metatile per 16 frames --
-- confirmed from the real array length and Step1's real body, not
-- assumed from community lore about "GBA walk speed" even though it
-- matches that.
--
-- Collision uses MapBlockData.lua's already-decoded `collision` field
-- (Phase 1 work -- the real per-cell u16's bits 10-11, per
-- include/global.fieldmap.h's MAPGRID_COLLISION_MASK) -- no new ROM
-- decode needed, this module just acts on it. Real collision semantics
-- confirmed from src/fieldmap.c's MapGridGetCollisionAt: collision != 0
-- (after masking/shifting) means impassable. This module only ports
-- that basic terrain collision check -- not the real game's fuller
-- GetCollisionFlagsAtCoords (object-event collision, elevation
-- mismatches, movement-range fencing, directionally-impassable
-- metatiles like one-way ledges) -- see the header comment on
-- :tryMove for exactly what's out of scope.
--
-- Real facing-direction behavior (confirmed from real
-- PlayerWalkNormal/DoForcedMovement-adjacent code, and well-documented
-- real series behavior): pressing a direction while blocked turns the
-- player to face that direction WITHOUT moving, rather than doing
-- nothing -- ported here as :tryMove always updating facingDirection
-- immediately, and only starting the 16-frame walk animation if the
-- destination tile isn't blocked.

local PlayerMovement = {}

local DIRECTION_DOWN = "down"
local DIRECTION_UP = "up"
local DIRECTION_LEFT = "left"
local DIRECTION_RIGHT = "right"
PlayerMovement.DOWN, PlayerMovement.UP, PlayerMovement.LEFT, PlayerMovement.RIGHT = DIRECTION_DOWN, DIRECTION_UP, DIRECTION_LEFT, DIRECTION_RIGHT

local DIRECTION_DELTA = {
  [DIRECTION_DOWN] = { dx = 0, dy = 1 },
  [DIRECTION_UP] = { dx = 0, dy = -1 },
  [DIRECTION_LEFT] = { dx = -1, dy = 0 },
  [DIRECTION_RIGHT] = { dx = 1, dy = 0 },
}

local TILE_SIZE = 16
local WALK_FRAMES_PER_TILE = 16 -- real sSpeedNormalStepFuncs length (Step1 x16)

-- tileX/tileY: starting grid position (metatile coordinates, matching
-- MapBlockData's row-major grid). facingDirection: initial facing.
function PlayerMovement.new(tileX, tileY, facingDirection)
  return setmetatable({
    tileX = tileX, tileY = tileY, -- the tile the player currently occupies (or is walking away from, mid-step)
    facingDirection = facingDirection or DIRECTION_DOWN,
    moving = false,
    stepFrame = 0, -- 0..WALK_FRAMES_PER_TILE-1 while moving
    moveDx = 0, moveDy = 0, -- direction of the in-progress step
    destTileX = tileX, destTileY = tileY,
  }, { __index = PlayerMovement })
end

-- Real pixel position (top-left of the player's tile, mid-step
-- interpolated) -- what a caller draws the player sprite at.
function PlayerMovement:pixelX()
  return (self.tileX * TILE_SIZE) + self.moveDx * self.stepFrame
end

function PlayerMovement:pixelY()
  return (self.tileY * TILE_SIZE) + self.moveDy * self.stepFrame
end

-- direction: one of PlayerMovement.DOWN/UP/LEFT/RIGHT. isBlocked(x, y):
-- caller-supplied function returning whether tile (x,y) is impassable
-- (typically `collisionGrid[y][x].collision ~= 0`, straight from
-- MapBlockData's real decode -- see this module's header comment for
-- what real collision cases beyond basic terrain aren't checked here).
-- No-op while already mid-step (real movement can't be redirected
-- mid-animation either -- the real game queues the next input instead;
-- this project doesn't queue, it just ignores the input, a documented
-- simplification).
--
-- getLedgeJumpDirection(x, y) (optional): real one-way ledges
-- (event_object_movement.c's `GetLedgeJumpDirection`/`ShouldJumpLedge` --
-- checked against the DESTINATION tile's real MB_JUMP_EAST/WEST/NORTH/
-- SOUTH behavior). When the destination tile is a ledge whose real jump
-- direction matches the direction being moved, this overrides normal
-- movement with a forced 2-tile hop covering the ledge tile, bypassing
-- `isBlocked` entirely -- matching the real game's `ShouldJumpLedge`
-- check running unconditionally, before/regardless of the raw collision
-- result. Real ledge jumps also play a distinct vertical sprite-offset
-- animation curve (`sJumpY_Normal`) and the real jump-in-progress state
-- is a bit more involved (`InitJump`/`UpdateJumpAnim`); this project
-- only reproduces the coordinate outcome (2 tiles, same 16-frame
-- duration as `JUMP_DISTANCE_NORMAL`'s real timing, so double px/frame)
-- and skips the arc animation as a documented visual simplification.
function PlayerMovement:tryMove(direction, isBlocked, getLedgeJumpDirection)
  if self.moving then return end
  self.facingDirection = direction
  local delta = DIRECTION_DELTA[direction]
  local destX, destY = self.tileX + delta.dx, self.tileY + delta.dy

  if getLedgeJumpDirection and getLedgeJumpDirection(destX, destY) == direction then
    self.moving = true
    self.stepFrame = 0
    self.moveDx, self.moveDy = delta.dx * TILE_SIZE * 2 / WALK_FRAMES_PER_TILE, delta.dy * TILE_SIZE * 2 / WALK_FRAMES_PER_TILE
    self.destTileX, self.destTileY = self.tileX + delta.dx * 2, self.tileY + delta.dy * 2
    return
  end

  if isBlocked(destX, destY) then return end

  self.moving = true
  self.stepFrame = 0
  self.moveDx, self.moveDy = delta.dx * TILE_SIZE / WALK_FRAMES_PER_TILE, delta.dy * TILE_SIZE / WALK_FRAMES_PER_TILE
  self.destTileX, self.destTileY = destX, destY
end

-- Advances the walk animation by one real frame (1px of the real
-- Step1-based normal speed). Call once per 60Hz tick.
function PlayerMovement:tick()
  if not self.moving then return end
  self.stepFrame = self.stepFrame + 1
  if self.stepFrame >= WALK_FRAMES_PER_TILE then
    self.tileX, self.tileY = self.destTileX, self.destTileY
    self.moving = false
    self.stepFrame = 0
    self.moveDx, self.moveDy = 0, 0
  end
end

return PlayerMovement
