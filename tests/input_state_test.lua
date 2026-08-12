-- Unit test: verifies InputState's key-repeat timing matches the real
-- ReadKeys logic (src/main.c) exactly -- 40-tick initial delay, then a
-- repeat every 5 ticks while the same keys stay held, reset immediately
-- on any change.
-- Run: lua5.1 tests/input_state_test.lua
package.path = package.path .. ";./?.lua"
local InputState = require("src.core.InputState")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- Pressing a key for the first time: newKeys set, not yet "repeated"
-- (newAndRepeatedKeys equals newKeysRaw on the same tick the key was
-- newly pressed -- matches real ReadKeys initializing it that way before
-- the repeat-counter branch runs).
do
  local s = InputState.new()
  s:update(InputState.A_BUTTON)
  check("first press sets newKeys", s:isNewlyPressed(InputState.A_BUTTON))
  check("first press also counts as newAndRepeatedKeys (not a real repeat yet, just newly pressed)", s:isPressedOrRepeated(InputState.A_BUTTON))
  check("held reflects the button", s:isHeld(InputState.A_BUTTON))
end

-- Holding the same key: newKeys clears after the first tick, and
-- newAndRepeatedKeys stays clear until the start delay elapses. The
-- counter starts at 40 on the press tick but only *decrements* starting
-- the tick after (the press tick's held-state comparison fails, since
-- heldKeys was 0 before the press), so the first repeat lands on the
-- 41st tick of holding -- 40 ticks after the initial press, matching
-- gKeyRepeatStartDelay's real 40-tick meaning.
do
  local s = InputState.new()
  s:update(InputState.A_BUTTON) -- tick 1: initial press
  for tick = 2, 41 do
    s:update(InputState.A_BUTTON)
    if tick < 41 then
      check("no repeat fires before the start delay elapses (tick " .. tick .. ")", not s:isPressedOrRepeated(InputState.A_BUTTON))
    end
  end
  check("newKeys cleared once the button is no longer newly pressed", not s:isNewlyPressed(InputState.A_BUTTON))
  check("repeat fires exactly 40 ticks after the initial press (gKeyRepeatStartDelay)", s:isPressedOrRepeated(InputState.A_BUTTON))
end

-- After the first repeat, subsequent repeats fire every 5 ticks
-- (gKeyRepeatContinueDelay), not another 40.
do
  local s = InputState.new()
  for tick = 1, 41 do s:update(InputState.A_BUTTON) end
  check("first repeat fired at tick 41", s:isPressedOrRepeated(InputState.A_BUTTON))
  local firedAt = {}
  for tick = 42, 51 do
    s:update(InputState.A_BUTTON)
    if s:isPressedOrRepeated(InputState.A_BUTTON) then firedAt[#firedAt + 1] = tick end
  end
  check("second repeat fires exactly 5 ticks after the first (tick 46)", firedAt[1] == 46, table.concat(firedAt, ","))
  check("third repeat fires 5 ticks after that (tick 51)", firedAt[2] == 51, table.concat(firedAt, ","))
end

-- Changing which keys are held resets the repeat counter (real ReadKeys:
-- "if the input has changed, reset the counter") -- a fresh press of B
-- still registers via newAndRepeatedKeys (it's a genuine first press, same
-- as the very first check above), but that's not a "repeat" firing early:
-- B needs its own full 40-tick delay before it repeats again.
do
  local s = InputState.new()
  for tick = 1, 40 do s:update(InputState.A_BUTTON) end -- one tick short of A repeating
  s:update(InputState.B_BUTTON) -- switched keys: a genuine new press of B
  check("the new key registers as newly pressed", s:isNewlyPressed(InputState.B_BUTTON))
  local repeatedEarly = false
  for tick = 1, 39 do
    s:update(InputState.B_BUTTON)
    if s:isPressedOrRepeated(InputState.B_BUTTON) then repeatedEarly = true end
  end
  check("B doesn't repeat again before its own 40-tick delay elapses (i.e. leftover A counter state didn't leak through)", not repeatedEarly)
  s:update(InputState.B_BUTTON)
  check("B repeats exactly 40 ticks after its own press", s:isPressedOrRepeated(InputState.B_BUTTON))
end

-- Releasing all keys resets the counter and clears held/new state.
do
  local s = InputState.new()
  for tick = 1, 41 do s:update(InputState.A_BUTTON) end
  s:update(0) -- release
  check("held clears on release", not s:isHeld(InputState.A_BUTTON))
  check("no repeat while nothing is held", not s:isPressedOrRepeated(InputState.A_BUTTON))
end

-- Multiple simultaneous keys (a real bitmask, not just one button at a
-- time) are tracked independently and repeat together.
do
  local s = InputState.new()
  local mask = InputState.buildMask({ DPAD_UP = true, A_BUTTON = true })
  check("buildMask combines multiple named buttons into one bitmask", mask == InputState.DPAD_UP + InputState.A_BUTTON)
  s:update(mask)
  check("both buttons register as held", s:isHeld(InputState.DPAD_UP) and s:isHeld(InputState.A_BUTTON))
  check("an unrelated button is not held", not s:isHeld(InputState.B_BUTTON))
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
