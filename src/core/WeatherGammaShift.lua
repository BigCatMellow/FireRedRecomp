-- Port of pokefirered's real weather gamma-shift system (src/field_weather.c:
-- BuildGammaShiftTables / UpdateWeatherGammaShift / ApplyGammaShift) -- the
-- mechanism behind weather darkening the whole screen over time (e.g. rain,
-- sandstorm), stepping every palette color through a precomputed per-channel
-- lookup table one gamma "index" at a time. This is a genuinely different
-- kind of palette animation from PaletteFade.lua: PaletteFade linearly
-- blends every color toward one flat target color; the gamma shift instead
-- runs each channel through a nonlinear, precomputed gamma curve (built
-- once, then indexed per frame) -- real FireRed uses both mechanisms for
-- different jobs (PaletteFade for screen-transition fades, this for
-- weather's continuous darkening while the weather is active).
--
-- Concrete verified real case ported: WEATHER_RAIN_THUNDERSTORM /
-- WEATHER_DOWNPOUR (src/field_weather_effects.c's Thunderstorm_InitVars/
-- Downpour_InitVars) set `gammaTargetIndex = 3` and `gammaStepDelay = 20`
-- -- real, not guessed, values read straight from those two functions.
-- That's the real "weather darkens the screen a few notches, a few frames
-- apart" effect this module reproduces the timing and table math for.
--
-- BuildGammaShiftTables (ported in buildTables() below) is transcribed
-- line-for-line from the real function, including its exact fixed-point
-- integer steps -- not reimplemented from a guessed "gamma curve" formula.
-- One simplification made safely: the real function guards a `v10 =
-- 0x1f00 - v4` subtraction against going negative (u32 wraparound handling)
-- and biases a `dunno >> 15` term for sign-extension -- both dead code for
-- every actual (tableIdx, channel) combination this table is ever built
-- over (v4's value never exceeds 0x1f00 in this domain, and `dunno` is
-- always non-negative when the `dunno > 0` branch runs), confirmed by
-- direct calculation, not assumed; the simplified arithmetic below is
-- exactly what those branches evaluate to over the real input domain, not
-- a behavior change.
--
-- Unlike PaletteFade.lua/PaletteBlend.lua's data (which is materialized
-- straight-to-8bpp RGB throughout this project), the real gamma tables are
-- inherently defined over 5-bit (0-31) GBA palette channel values, because
-- they're gamma *curves*, not linear blends -- BuildGammaShiftTables's own
-- math only makes sense in that native precision. So this module keeps the
-- table itself in 5-bit space (exactly matching the real one) and only
-- converts at the boundary, using the same 5-bit<->8-bit formulas
-- GbaGraphics.lua already established for this project (decodeColor's
-- `floor(c5*255/31+0.5)` upscale, inverted the same way for the downscale).

local WeatherGammaShift = {}

local GAMMA_INDEX_COUNT = 19 -- gWeatherPtr->gammaShifts[19][32] (field_weather.h)
local CHANNEL_COUNT = 32 -- 5-bit channel values, 0-31

-- Builds one of the two real tables (gammaShifts when useDecay is true --
-- v0==0 in the real function -- altGammaShifts when false). Rows are
-- indexed 0..18 (matching the real gammaShifts[gammaIndex][channel] after
-- ApplyGammaShift's real `gammaIndex--`), columns 0..31 (the raw 5-bit
-- channel value being shifted).
local function buildOneTable(useDecay)
  local t = {}
  for gi = 0, GAMMA_INDEX_COUNT - 1 do t[gi] = {} end

  for c = 0, CHANNEL_COUNT - 1 do
    local v4 = c * 256 -- c << 8
    local v5 = useDecay and math.floor((c * 256) / 16) or 0
    local gammaIndex = 0
    for gi = 0, 2 do
      v4 = v4 - v5
      t[gi][c] = math.floor(v4 / 256) -- v4 >> 8
      gammaIndex = gi + 1
    end

    local v9 = v4
    -- Real: v10 = 0x1f00 - v4 (never negative here -- see header comment).
    local v11 = math.floor((0x1f00 - v4) / 16)

    if c < 12 then
      for gi = gammaIndex, GAMMA_INDEX_COUNT - 1 do
        v4 = v4 + v11
        local dunno = v4 - v9
        if dunno > 0 then
          -- Real: v4 -= (dunno + ((u16)dunno >> 15)) >> 1 -- the >>15 term
          -- is always 0 here (dunno is a positive s16, see header comment).
          v4 = v4 - math.floor(dunno / 2)
        end
        local val = math.floor(v4 / 256)
        if val > 0x1f then val = 0x1f end
        t[gi][c] = val
      end
    else
      for gi = gammaIndex, GAMMA_INDEX_COUNT - 1 do
        v4 = v4 + v11
        local val = math.floor(v4 / 256)
        if val > 0x1f then val = 0x1f end
        t[gi][c] = val
      end
    end
  end

  return t
end

-- Real BuildGammaShiftTables() builds both tables once (StartWeather calls
-- it a single time). Returns { normal = <table>, alt = <table> }, each
-- gammaShifts[gammaIndexRow 0..18][channel 0..31] -> shifted channel
-- (0..31). "normal"/"alt" mirror the real per-palette GAMMA_NORMAL/
-- GAMMA_ALT split (sBasePaletteGammaTypes) -- which real palette slot uses
-- which table is out of scope here (this module doesn't track a whole
-- palette bank set, just the shift math -- see the per-color API below).
function WeatherGammaShift.buildTables()
  return {
    normal = buildOneTable(true),
    alt = buildOneTable(false),
  }
end

-- Applies one already-built table's gamma curve to a single 5-bit channel
-- value (0-31). gammaIndex is the *external* value (matching
-- gWeatherPtr->gammaIndex/ApplyGammaShift's parameter): 0 means "no
-- shift" (real ApplyGammaShift's `else` branch -- straight copy, table not
-- consulted at all), gammaIndex >= 1 indexes gammaTable[gammaIndex - 1]
-- (real ApplyGammaShift's `gammaIndex--` before use).
function WeatherGammaShift.shiftChannel5(table19x32, gammaIndex, channel5)
  if gammaIndex <= 0 then return channel5 end
  local row = gammaIndex - 1
  if row > GAMMA_INDEX_COUNT - 1 then row = GAMMA_INDEX_COUNT - 1 end
  return table19x32[row][channel5]
end

-- 8-bit (0-255) <-> 5-bit (0-31) conversions, the same formulas
-- GbaGraphics.decodeColor already established for this project (kept
-- local rather than requiring import.GbaGraphics, since this is a
-- src/core pure-math module and that's an import/ ROM decoder).
local function to5(c8) return math.floor(c8 * 31 / 255 + 0.5) end
local function to8(c5) return math.floor(c5 * 255 / 31 + 0.5) end

-- tables: WeatherGammaShift.buildTables() result. gammaIndex: external
-- index, see shiftChannel5. useAlt: pick tables.alt instead of
-- tables.normal (real GAMMA_ALT sprite palettes, e.g. the player sprite,
-- shift on a different curve than background palettes -- see
-- sBasePaletteGammaTypes). color: {r,g,b} 0-255. Returns a new {r,g,b}
-- 0-255 table, gamma-shifted the same way real ApplyGammaShift shifts one
-- palette color.
function WeatherGammaShift.applyToColor(tables, gammaIndex, useAlt, color)
  local t = useAlt and tables.alt or tables.normal
  local r5 = WeatherGammaShift.shiftChannel5(t, gammaIndex, to5(color.r))
  local g5 = WeatherGammaShift.shiftChannel5(t, gammaIndex, to5(color.g))
  local b5 = WeatherGammaShift.shiftChannel5(t, gammaIndex, to5(color.b))
  return { r = to8(r5), g = to8(g5), b = to8(b5) }
end

-- Tick-driven timing, ported from UpdateWeatherGammaShift: steps
-- gammaIndex by 1 toward targetIndex every stepDelay ticks (0 = step every
-- tick), and does nothing once it arrives -- same "wait N ticks between
-- each single-unit step" shape as PaletteFade.lua's delay/deltaY, just
-- with a fixed step size of 1 (the real gammaIndex step is always ±1,
-- unlike PaletteFade's deltaY=2 default).
function WeatherGammaShift.new(targetIndex, stepDelay)
  return setmetatable({
    index = 0, -- gWeatherPtr->gammaIndex always starts at 0 (None_Init)
    targetIndex = targetIndex,
    stepDelay = stepDelay,
    frameCounter = 0,
  }, { __index = WeatherGammaShift })
end

-- Real WeatherBeginGammaFade(gammaIndex, gammaTargetIndex, gammaStepDelay)
-- -- changes the target (and step timing) a weather transition retargets,
-- e.g. moving from clear weather (target 0) to thunderstorm (target 3,
-- delay 20) without recreating the whole object.
function WeatherGammaShift:setTarget(targetIndex, stepDelay)
  self.targetIndex = targetIndex
  self.stepDelay = stepDelay
  self.frameCounter = 0
end

function WeatherGammaShift:tick()
  if self.index == self.targetIndex then return end
  self.frameCounter = self.frameCounter + 1
  if self.frameCounter >= self.stepDelay then
    self.frameCounter = 0
    if self.index < self.targetIndex then
      self.index = self.index + 1
    else
      self.index = self.index - 1
    end
  end
end

function WeatherGammaShift:isDone()
  return self.index == self.targetIndex
end

return WeatherGammaShift
