-- Unit test: verifies SlashSprite's real movement/visibility timing
-- (src/title_screen.c's SpriteCallback_Slash).
-- Run: lua5.1 tests/slash_sprite_test.lua
package.path = package.path .. ";./?.lua"
local SlashSprite = require("src.core.SlashSprite")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- Starts invisible, waiting at its real spawn position.
do
  local s = SlashSprite.new()
  check("starts invisible", s.invisible)
  check("starts at the real spawn position (-32, 27)", s.x == -32 and s.y == 27)
  check("starts in the waiting state", s.state == 0)
end

-- Stays invisible and doesn't move for the full 540-tick wait, then
-- becomes visible on exactly the 540th tick.
do
  local s = SlashSprite.new()
  for i = 1, 539 do s:tick() end
  check("still invisible/waiting after 539 of 540 ticks", s.invisible and s.state == 0)
  check("hasn't moved during the wait", s.x == -32)
  s:tick()
  check("becomes visible on exactly the 540th tick", not s.invisible and s.state == 1)
end

-- Moves at a constant 9px/tick once visible, with the two real one-time
-- vertical jumps at x==67 and x==148.
do
  local s = SlashSprite.new()
  for i = 1, 540 do s:tick() end -- finish the wait, now moving
  local startY = s.y
  -- -32 + 9*11 = 67 exactly
  for i = 1, 11 do s:tick() end
  check("x reaches exactly 67 after 11 moving ticks", s.x == 67, s.x)
  check("y jumps -7 exactly when x hits 67", s.y == startY - 7, s.y)
  local yAfterFirstJump = s.y
  -- 67 -> 148 is 81px = 9 ticks exactly
  for i = 1, 9 do s:tick() end
  check("x reaches exactly 148 after 9 more ticks", s.x == 148, s.x)
  check("y jumps +7 back exactly when x hits 148", s.y == yAfterFirstJump + 7, s.y)
end

-- Loops by default: after sweeping off the right edge, goes invisible
-- and resets to wait another 540 ticks (undeactivated behavior).
do
  local s = SlashSprite.new()
  for i = 1, 540 do s:tick() end -- finish the wait
  -- -32 + 9*34 = 274, just past DISPLAY_WIDTH+32=272
  for i = 1, 34 do s:tick() end
  check("goes invisible once x exceeds DISPLAY_WIDTH+32", s.invisible)
  check("resets position for another sweep", s.x == -32)
  check("resets to the waiting state", s.state == 0)
  check("resets the wait timer", s.timer == 540)
end

-- deactivate() during the wait freezes it immediately instead of
-- eventually appearing.
do
  local s = SlashSprite.new()
  for i = 1, 100 do s:tick() end
  s:deactivate()
  s:tick()
  check("deactivating during the wait freezes immediately", s.invisible and s.state == 2)
  local xBefore = s.x
  for i = 1, 50 do s:tick() end
  check("stays frozen indefinitely once deactivated", s.invisible and s.state == 2 and s.x == xBefore)
end

-- deactivate() during a sweep lets the current sweep finish, then freezes
-- instead of looping again.
do
  local s = SlashSprite.new()
  for i = 1, 540 do s:tick() end -- start moving
  s:deactivate()
  for i = 1, 34 do s:tick() end -- finish this sweep (same math as the loop test above)
  check("finishes the current sweep before freezing", s.invisible and s.state == 2)
  local xAfterFreeze = s.x
  for i = 1, 600 do s:tick() end
  check("never resets/loops again once frozen", s.state == 2 and s.x == xAfterFreeze)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
