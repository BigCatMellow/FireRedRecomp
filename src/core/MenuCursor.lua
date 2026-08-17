-- Port of pokefirered's real menu cursor logic (src/menu.c's
-- Menu_MoveCursor + Menu_ProcessInput -- the cursor behind every simple
-- vertical choice menu in the game, most visibly CreateYesNoMenu's real
-- "YES/NO" confirmation prompt used everywhere: save confirmations,
-- battle prompts, "would you like to..." dialogue choices).
--
-- Ported faithfully: Menu_MoveCursor wraps around at the ends (moving up
-- from the first item jumps to the last, and vice versa -- confirmed
-- from the real source, not the no-wraparound variant
-- Menu_MoveCursorNoWrapAround the game also has for other menus).
-- Menu_ProcessInput's real button mapping: A confirms (returns the
-- current cursor position), B cancels, Up/Down move the cursor one step
-- -- using the real newAndRepeatedKeys (auto-repeat while held), not
-- just a fresh press, matching InputState.lua's isPressedOrRepeated.
-- Also exposes the real no-wrap variant used by Oak's BOY/GIRL picker:
-- Menu_MoveCursorNoWrapAround clamps at the ends and
-- Menu_ProcessInputNoWrapAround reads newly-pressed D-pad keys (not held
-- repeat), exactly as src/menu.c does.

local InputState = require("src.core.InputState")

local MenuCursor = {}

-- numChoices: how many selectable rows (2 for a real Yes/No menu).
-- initialCursorPos: which row starts selected (0-based).
function MenuCursor.new(numChoices, initialCursorPos)
  return setmetatable({
    cursorPos = initialCursorPos or 0,
    minCursorPos = 0,
    maxCursorPos = numChoices - 1,
  }, { __index = MenuCursor })
end

-- delta: +1 (down) or -1 (up). Wraps at the real min/max bounds.
function MenuCursor:moveCursor(delta)
  local newPos = self.cursorPos + delta
  if newPos < self.minCursorPos then
    self.cursorPos = self.maxCursorPos
  elseif newPos > self.maxCursorPos then
    self.cursorPos = self.minCursorPos
  else
    self.cursorPos = newPos
  end
end

function MenuCursor:moveCursorNoWrap(delta)
  local newPos = self.cursorPos + delta
  if newPos < self.minCursorPos then
    self.cursorPos = self.minCursorPos
  elseif newPos > self.maxCursorPos then
    self.cursorPos = self.maxCursorPos
  else
    self.cursorPos = newPos
  end
end

-- inputState: an InputState.lua instance already ticked this frame.
-- Returns "confirm", "cancel", or nil (nothing chosen this tick) --
-- MENU_NOTHING_CHOSEN/MENU_B_PRESSED/cursorPos in the real code's terms,
-- just spelled as strings since this project doesn't need the numeric
-- cursorPos-as-return-value trick C uses to pack three outcomes into one
-- return type.
function MenuCursor:processInput(inputState)
  if inputState:isNewlyPressed(InputState.A_BUTTON) then
    return "confirm"
  end
  if inputState:isNewlyPressed(InputState.B_BUTTON) then
    return "cancel"
  end
  if inputState:isPressedOrRepeated(InputState.DPAD_UP) then
    self:moveCursor(-1)
  elseif inputState:isPressedOrRepeated(InputState.DPAD_DOWN) then
    self:moveCursor(1)
  end
  return nil
end

function MenuCursor:processInputNoWrap(inputState)
  if inputState:isNewlyPressed(InputState.A_BUTTON) then return "confirm" end
  if inputState:isNewlyPressed(InputState.B_BUTTON) then return "cancel" end
  if inputState:isNewlyPressed(InputState.DPAD_UP) then
    self:moveCursorNoWrap(-1)
  elseif inputState:isNewlyPressed(InputState.DPAD_DOWN) then
    self:moveCursorNoWrap(1)
  end
  return nil
end

return MenuCursor
