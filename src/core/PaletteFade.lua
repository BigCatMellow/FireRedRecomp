-- Port of the real palette fade *timing* (src/palette.c's
-- BeginNormalPaletteFade + UpdateNormalPaletteFade's NORMAL_FADE stepping
-- -- the mechanism behind every screen transition in the game: title
-- screen fade-in, map transitions, battle intros). Produces the blend
-- coefficient (0-16) that PaletteBlend.lua's `coeff` parameter expects,
-- stepping it from startY to targetY over time.
--
-- Ported faithfully from UpdateNormalPaletteFade: every tick, if
-- delayCounter < delay, delayCounter++ and nothing else happens (no
-- coefficient movement) -- so `delay` is "ticks to wait between each
-- step," not the fade's total length. Once the delay elapses, y moves by
-- deltaY (2 per step by default, matching BeginNormalPaletteFade's real
-- default) toward targetY, clamped so it never overshoots.
--
-- Not ported: the real struct's separate BG/OBJ palette "toggle" pass
-- (gPaletteFade.objPaletteToggle) -- that's how the real hardware splits
-- one logical fade step across two half-steps to blend BG and OBJ
-- palette RAM banks in alternate VBlanks. This project has no separate
-- indexed palette buffers to split that way (see PaletteBlend.lua's
-- header comment), so one PaletteFade tick corresponds to one real
-- *pair* of half-steps (i.e. this module's timing already accounts for
-- it -- a fade started with the real game's delay/deltaY values reaches
-- its target in the same number of ticks the real game takes).

local PaletteFade = {}

local DEFAULT_DELTA_Y = 2 -- BeginNormalPaletteFade's real default (gPaletteFade.deltaY = 2)

-- startY/targetY: 0-16 blend coefficients (0 = original colors, 16 =
-- fully blendColor). delay: real ticks to wait between each step (0 =
-- step every tick). blendColor: {r,g,b} 0-255, passed through untouched
-- for PaletteBlend.lua to use.
function PaletteFade.new(startY, targetY, delay, blendColor)
  return setmetatable({
    y = startY,
    targetY = targetY,
    delay = delay,
    delayCounter = 0,
    deltaY = DEFAULT_DELTA_Y,
    blendColor = blendColor,
    active = startY ~= targetY,
  }, { __index = PaletteFade })
end

function PaletteFade:tick()
  if not self.active then return end
  if self.delayCounter < self.delay then
    self.delayCounter = self.delayCounter + 1
    return
  end
  self.delayCounter = 0

  if self.y == self.targetY then
    self.active = false
    return
  end
  if self.y < self.targetY then
    self.y = math.min(self.y + self.deltaY, self.targetY)
  else
    self.y = math.max(self.y - self.deltaY, self.targetY)
  end
  if self.y == self.targetY then self.active = false end
end

function PaletteFade:isDone()
  return not self.active
end

return PaletteFade
