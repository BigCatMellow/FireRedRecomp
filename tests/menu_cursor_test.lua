-- Unit test: verifies MenuCursor's wraparound movement and A/B/Up/Down
-- handling against the real Menu_MoveCursor/Menu_ProcessInput semantics
-- (src/menu.c).
-- Run: lua5.1 tests/menu_cursor_test.lua
package.path = package.path .. ";./?.lua"
local MenuCursor = require("src.core.MenuCursor")
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

-- Basic wraparound movement (real Menu_MoveCursor: moving past either end
-- jumps to the opposite end, not clamped).
do
  local c = MenuCursor.new(2, 0) -- a real Yes/No menu: 2 choices, starts on YES (index 0)
  check("starts at the initial position", c.cursorPos == 0)
  c:moveCursor(1)
  check("moves down to NO", c.cursorPos == 1)
  c:moveCursor(1)
  check("moving past the last item wraps to the first", c.cursorPos == 0)
  c:moveCursor(-1)
  check("moving up from the first item wraps to the last", c.cursorPos == 1)
end

-- A wider menu (e.g. a 5-item list) still wraps correctly at both ends.
do
  local c = MenuCursor.new(5, 2)
  c:moveCursor(-1); c:moveCursor(-1); c:moveCursor(-1)
  check("wraps from item 2 down past item 0 to the last item (4)", c.cursorPos == 4, c.cursorPos)
end

-- A minimal fake InputState -- only implements what MenuCursor:processInput
-- actually calls, so this test doesn't depend on real key polling.
local function fakeInput(pressed)
  return {
    isNewlyPressed = function(self, button) return pressed[button] == "new" end,
    isPressedOrRepeated = function(self, button) return pressed[button] == "new" or pressed[button] == "repeat" end,
  }
end

-- A confirms and returns "confirm" without moving the cursor.
do
  local c = MenuCursor.new(2, 0)
  local result = c:processInput(fakeInput({ [InputState.A_BUTTON] = "new" }))
  check("A button returns 'confirm'", result == "confirm")
  check("confirming doesn't move the cursor", c.cursorPos == 0)
end

-- B cancels.
do
  local c = MenuCursor.new(2, 0)
  local result = c:processInput(fakeInput({ [InputState.B_BUTTON] = "new" }))
  check("B button returns 'cancel'", result == "cancel")
end

-- Up/Down move the cursor and return nil (nothing chosen yet) -- and
-- respond to held-repeat, not just a fresh press, matching the real
-- code's `gMain.newAndRepeatedKeys & DPAD_UP` check.
do
  local c = MenuCursor.new(2, 0)
  local result = c:processInput(fakeInput({ [InputState.DPAD_DOWN] = "new" }))
  check("Down moves the cursor and returns nil", result == nil and c.cursorPos == 1)
  local result2 = c:processInput(fakeInput({ [InputState.DPAD_UP] = "repeat" }))
  check("a repeated (held) Up also moves the cursor", result2 == nil and c.cursorPos == 0)
end

-- No input pressed: nothing happens.
do
  local c = MenuCursor.new(2, 0)
  local result = c:processInput(fakeInput({}))
  check("no input returns nil and doesn't move the cursor", result == nil and c.cursorPos == 0)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
