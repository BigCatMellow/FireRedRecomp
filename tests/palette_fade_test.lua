-- Unit test: verifies PaletteFade's stepping timing against the real
-- UpdateNormalPaletteFade logic (src/palette.c) -- delay ticks between
-- each step, deltaY=2 per step, clamped at the target, done detection.
-- Run: lua5.1 tests/palette_fade_test.lua
package.path = package.path .. ";./?.lua"
local PaletteFade = require("src.core.PaletteFade")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- delay=0: steps every tick by deltaY=2, real BeginNormalPaletteFade
-- default. Fading 16 -> 0 takes 8 ticks (16/2).
do
  local f = PaletteFade.new(16, 0, 0, { r = 0, g = 0, b = 0 })
  check("starts at startY", f.y == 16)
  local ys = {}
  for i = 1, 8 do
    f:tick()
    ys[#ys + 1] = f.y
  end
  check("steps by 2 each tick with delay=0", table.concat(ys, ",") == "14,12,10,8,6,4,2,0", table.concat(ys, ","))
  check("reaches exactly targetY, not past it", f.y == 0)
  check("marks itself done once the target is reached", f:isDone())
end

-- delay=2: waits 2 ticks between each step (3 ticks per step total: 2
-- waits + 1 step, matching "delayCounter < delay" needing delay+1 ticks
-- to elapse before stepping).
do
  local f = PaletteFade.new(16, 0, 2, { r = 0, g = 0, b = 0 })
  f:tick(); f:tick()
  check("no step yet after 2 ticks (still within the delay)", f.y == 16)
  f:tick()
  check("first step lands on the 3rd tick (delay elapsed)", f.y == 14)
  f:tick(); f:tick()
  check("still holding at 14 through the next delay window", f.y == 14)
  f:tick()
  check("second step lands on the 6th tick overall", f.y == 12)
end

-- Fading upward (startY < targetY) -- e.g. fading TO a blend color
-- rather than away from one.
do
  local f = PaletteFade.new(0, 16, 0, { r = 255, g = 255, b = 255 })
  for i = 1, 8 do f:tick() end
  check("fades upward to the target", f.y == 16)
  check("done once it reaches the target", f:isDone())
end

-- A fade whose range isn't evenly divisible by deltaY clamps exactly at
-- the target rather than overshooting.
do
  local f = PaletteFade.new(5, 0, 0, { r = 0, g = 0, b = 0 })
  f:tick() -- 5 -> 3
  f:tick() -- 3 -> 1
  check("mid-fade, not yet clamped", f.y == 1)
  f:tick() -- 1 -> would be -1, clamps to 0
  check("final step clamps exactly at targetY instead of overshooting", f.y == 0)
  check("done after clamping to the target", f:isDone())
end

-- A degenerate fade (startY == targetY) is immediately done and never
-- steps.
do
  local f = PaletteFade.new(8, 8, 0, { r = 0, g = 0, b = 0 })
  check("startY == targetY is immediately done", f:isDone())
  f:tick()
  check("ticking a done fade is a no-op", f.y == 8)
end

-- Ticking past done doesn't move y further or error.
do
  local f = PaletteFade.new(2, 0, 0, { r = 0, g = 0, b = 0 })
  for i = 1, 10 do f:tick() end
  check("ticking well past completion stays clamped at targetY", f.y == 0)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
