-- Port of pokefirered's real title screen flame particle system
-- (src/title_screen.c's Task_FlameSpawner + SpriteCallback_TitleScreenFlame,
-- FireRed only). Spawns a burst of ~16 flame sprites every 18 ticks, each
-- with its own real RNG-rolled position/velocity, moving with real
-- fixed-point (4-bit fractional) physics until it drifts off-screen or
-- its animation finishes.
--
-- Ported faithfully: the exact same RNG seed (30840), the same spawn
-- cadence (an immediate first burst, then every 18 ticks), the same
-- per-particle roll order (xspeed, yspeed, y, x, a "createFlame" coin
-- flip for one extra randomly-placed particle, then 15 particles at the
-- real fixed sFlameXPositions offsets with fresh xspeed/yspeed rerolled
-- after each), and the real movement/destruction rule (sPosX -= speedX,
-- sPosY += speedY, both >>4 for the real pixel position; destroyed once
-- x < -8, y outside [16,200], or the flame animation reaches its end).
--
-- One deliberate simplification: the real CreateFlameSprite's
-- `createFlame` bool picks between two sprite templates -- a real
-- visible flame (sSpriteTemplate_FlameOrLeaf) or a "blank" one
-- (sSpriteTemplate_BlankFlame, sBlankFlames_Gfx) that starts invisible
-- and only turns visible after an additional delay (the real sprite's
-- data[7] countdown, itself only ever set by other callers this project
-- doesn't port -- CreateFlameSprite as shown in the real source never
-- actually sets data[7], so that branch is dead code as called from the
-- spawner). Since the "blank" flame's own graphic isn't decoded here,
-- particles that would use it are simply not spawned -- the real spawn
-- roll (TitleScreen_rand(...) % 16 < 8) still consumes the same RNG call
-- so the sequence of *visible* flames stays in sync with the real game,
-- it just also silently drops that one coin-flip particle when it lands
-- on the "blank" side, rather than spawning an invisible sprite that
-- would never be seen anyway.

local Rng = require("src.core.Rng")
local SpriteAnimator = require("src.core.SpriteAnimator")

local TitleScreenFlameSpawner = {}

local RNG_SEED = 30840 -- TitleScreen_srand(taskId, 3, 30840)
local SPAWN_DELAY_TICKS = 18
local DISPLAY_WIDTH = 240
local FLAME_X_POSITIONS = { 4, 16, 26, 32, 48, 200, 216, 224, 232, 60, 76, 92, 108, 128, 144, 0 }

-- flameCmds: SpriteAnim.decodeCmds() output for the real flame animation
-- (sSpriteAnim_Flame) -- each particle gets its own SpriteAnimator over
-- the same decoded command list, so they animate independently.
function TitleScreenFlameSpawner.new(flameCmds)
  return setmetatable({
    flameCmds = flameCmds,
    rng = Rng.new(RNG_SEED),
    tickTimer = 0,
    spawnDelay = 0, -- 0 until the first spawn state runs, matching the real tDelay starting at 0
    started = false,
    offsetIndex = 0, -- tOffsetX
    particles = {},
  }, { __index = TitleScreenFlameSpawner })
end

local function rollSpeed4(rng) return (rng:next16() % 4) - 2 end
local function rollSpeed8(rng) return (rng:next16() % 8) - 16 end

local function spawnParticle(self, x, y, speedX, speedY)
  self.particles[#self.particles + 1] = {
    posX = x * 16, posY = y * 16, -- fixed-point (4-bit fractional), matches sPosX/sPosY
    speedX = speedX, speedY = speedY,
    x = x, y = y,
    animator = SpriteAnimator.new(self.flameCmds),
    alive = true,
  }
end

local function spawnBurst(self)
  self.rng:next16() -- the real code's unused warm-up TitleScreen_rand call
  local xspeed, yspeed = rollSpeed4(self.rng), rollSpeed8(self.rng)
  local y = (self.rng:next16() % 3) + 116
  local x = self.rng:next16() % DISPLAY_WIDTH
  local createFlame = (self.rng:next16() % 16) >= 8
  if createFlame then spawnParticle(self, x, y, xspeed, yspeed) end

  for i = 1, 15 do
    spawnParticle(self, self.offsetIndex + FLAME_X_POSITIONS[i], y, xspeed, yspeed)
    xspeed, yspeed = rollSpeed4(self.rng), rollSpeed8(self.rng)
  end

  self.offsetIndex = self.offsetIndex + 1
  if self.offsetIndex > 3 then self.offsetIndex = 0 end
end

local function updateParticle(p)
  p.posX = p.posX - p.speedX
  p.x = math.floor(p.posX / 16)
  if p.x < -8 then p.alive = false; return end
  p.posY = p.posY + p.speedY
  p.y = math.floor(p.posY / 16)
  if p.y < 16 or p.y > 200 then p.alive = false; return end
  p.animator:tick()
  if p.animator.ended then p.alive = false end
end

function TitleScreenFlameSpawner:tick()
  -- Existing particles move first, so a particle spawned this tick shows
  -- its real un-moved starting position on the tick it's created (the
  -- real engine's sprite callbacks don't run on a sprite the same frame
  -- CreateSprite added it -- it joins next frame's update pass).
  local alive = {}
  for _, p in ipairs(self.particles) do
    if p.alive then
      updateParticle(p)
      if p.alive then alive[#alive + 1] = p end
    end
  end
  self.particles = alive

  if not self.started then
    self.started = true
  else
    self.tickTimer = self.tickTimer + 1
    if self.tickTimer >= self.spawnDelay then
      self.tickTimer = 0
      self.spawnDelay = SPAWN_DELAY_TICKS
      spawnBurst(self)
    end
  end
end

return TitleScreenFlameSpawner
