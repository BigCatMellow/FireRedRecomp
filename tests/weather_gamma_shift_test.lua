-- Run: lua5.1 tests/weather_gamma_shift_test.lua
-- Pure computed-math module (no ROM asset involved -- see
-- WeatherGammaShift.lua's header), so this test always runs, no
-- POKEPORT_ROM gate needed.
package.path = package.path .. ";./?.lua"
local WeatherGammaShift = require("src.core.WeatherGammaShift")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local tables = WeatherGammaShift.buildTables()

-- Shape: gammaShifts[19][32] / altGammaShifts[19][32] (field_weather.h's
-- real struct field sizes).
local rows = 0
for _ in pairs(tables.normal) do rows = rows + 1 end
check("normal table has 19 gamma-index rows", rows == 19, rows)
local cols = 0
for _ in pairs(tables.normal[0]) do cols = cols + 1 end
check("each row has 32 channel columns", cols == 32, cols)

-- gammaIndex == 0: real ApplyGammaShift's `else` branch is a straight
-- CpuFastCopy with no table lookup at all -- every channel value must
-- pass through unchanged.
for c = 0, 31 do
  check(("gammaIndex 0 passes channel %d through unchanged"):format(c),
    WeatherGammaShift.shiftChannel5(tables.normal, 0, c) == c)
end

-- Hand-computed from BuildGammaShiftTables's own transcribed formula (not
-- an independent real-hardware data point -- this table is built by code
-- at runtime in the real game too, so "real data" here is the real
-- algorithm, the same verification approach PaletteBlend.lua/
-- PaletteFade.lua already use for their computed math):
-- normal table, channel 31 (max 5-bit value), v0==0 branch:
--   v4 = 31*256 = 7936, v5 = (31*256)/16 = 496
--   gammaIndex row 0: v4 = 7936-496 = 7440 -> 7440>>8 = 29
--   row 1: v4 = 7440-496 = 6944 -> 6944>>8 = 27
--   row 2: v4 = 6944-496 = 6448 -> 6448>>8 = 25
check("normal table row0 (gammaIndex=1), channel 31 == 29",
  WeatherGammaShift.shiftChannel5(tables.normal, 1, 31) == 29,
  WeatherGammaShift.shiftChannel5(tables.normal, 1, 31))
check("normal table row1 (gammaIndex=2), channel 31 == 27",
  WeatherGammaShift.shiftChannel5(tables.normal, 2, 31) == 27,
  WeatherGammaShift.shiftChannel5(tables.normal, 2, 31))
check("normal table row2 (gammaIndex=3), channel 31 == 25",
  WeatherGammaShift.shiftChannel5(tables.normal, 3, 31) == 25,
  WeatherGammaShift.shiftChannel5(tables.normal, 3, 31))

-- Alt table (v0==1 branch, v5 always 0): the first 3 gammaIndex rows are
-- a no-op by construction (v4 -= 0 each time), so gammaIndex 1-3 should
-- leave channel 31 untouched at 31 -- distinguishing it from the normal
-- table's real darkening at the same indices.
check("alt table's first 3 rows are a no-op (v5=0 branch), channel 31 stays 31",
  WeatherGammaShift.shiftChannel5(tables.alt, 1, 31) == 31
  and WeatherGammaShift.shiftChannel5(tables.alt, 2, 31) == 31
  and WeatherGammaShift.shiftChannel5(tables.alt, 3, 31) == 31)

-- Every table entry must stay a valid 5-bit value (real code explicitly
-- clamps to 0x1f in the second loop half).
local allInRange = true
for gi = 0, 18 do
  for c = 0, 31 do
    local v = tables.normal[gi][c]
    if v < 0 or v > 31 then allInRange = false end
    local v2 = tables.alt[gi][c]
    if v2 < 0 or v2 > 31 then allInRange = false end
  end
end
check("every gamma table entry is a valid 5-bit value (0-31)", allInRange)

-- applyToColor: round-trips through GbaGraphics's real 5-bit<->8-bit
-- formula. White (255,255,255) at gammaIndex=1 (normal table) should
-- darken slightly, not stay pure white and not go black.
local shiftedWhite = WeatherGammaShift.applyToColor(tables, 1, false, { r = 255, g = 255, b = 255 })
check("gammaIndex=1 darkens white slightly (real weather subtly dims the screen per step)",
  shiftedWhite.r < 255 and shiftedWhite.r > 200, shiftedWhite.r)
check("applyToColor darkens all channels equally for a gray input", shiftedWhite.r == shiftedWhite.g and shiftedWhite.g == shiftedWhite.b)

local shiftedWhiteIdle = WeatherGammaShift.applyToColor(tables, 0, false, { r = 255, g = 255, b = 255 })
check("gammaIndex=0 leaves the color untouched", shiftedWhiteIdle.r == 255 and shiftedWhiteIdle.g == 255 and shiftedWhiteIdle.b == 255)

-- Tick timing: real WEATHER_RAIN_THUNDERSTORM/WEATHER_DOWNPOUR set
-- gammaTargetIndex=3, gammaStepDelay=20 (Thunderstorm_InitVars/
-- Downpour_InitVars, src/field_weather_effects.c -- real, verified
-- values, not guessed). Real UpdateWeatherGammaShift pre-increments its
-- frame counter then compares >=, so the Nth step lands exactly on tick
-- N*stepDelay.
local thunderstorm = WeatherGammaShift.new(3, 20)
check("starts at gammaIndex 0 (None_Init's real default)", thunderstorm.index == 0)
for i = 1, 19 do thunderstorm:tick() end
check("19 ticks in (< stepDelay), still at index 0", thunderstorm.index == 0, thunderstorm.index)
thunderstorm:tick() -- tick 20
check("tick 20 steps to gammaIndex 1", thunderstorm.index == 1, thunderstorm.index)
for i = 1, 19 do thunderstorm:tick() end
thunderstorm:tick() -- tick 40
check("tick 40 steps to gammaIndex 2", thunderstorm.index == 2, thunderstorm.index)
for i = 1, 20 do thunderstorm:tick() end -- tick 60
check("tick 60 reaches the real target gammaIndex 3 and stops", thunderstorm.index == 3, thunderstorm.index)
check("isDone() reports true once the target is reached", thunderstorm:isDone())
local indexBefore = thunderstorm.index
thunderstorm:tick()
check("ticking after reaching target is a no-op", thunderstorm.index == indexBefore)

-- setTarget: real WeatherBeginGammaFade retargets a live shift, e.g. the
-- weather clearing back toward gammaIndex 0.
thunderstorm:setTarget(0, 20)
check("setTarget changes the target without resetting the current index", thunderstorm.targetIndex == 0 and thunderstorm.index == 3)
check("isDone() reflects the new target immediately if not yet reached", not thunderstorm:isDone())

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
