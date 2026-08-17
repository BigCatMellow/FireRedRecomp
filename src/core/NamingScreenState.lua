-- Pure input/state port of FireRed's naming-screen keyboard.
--
-- Source: pokefirered src/naming_screen.c, specifically sKeyboardChars,
-- sPageColumnCounts, sPageToKeyboardId, HandleDpadMovement,
-- HandleKeyboardEvent, DeleteTextCharacter, AddTextCharacter and
-- SaveInputText. The player/rival templates both use
-- PLAYER_NAME_LENGTH=7 (include/constants/global.h), stored as seven
-- charmap bytes plus EOS (0xFF) in SaveBlock2.playerName and
-- SaveBlock1.rivalName.
--
-- This module intentionally has no LÖVE dependency. Graphics are decoded
-- separately by import/NamingScreenScene.lua; keeping the rules pure makes
-- cursor wrapping, page transitions and byte-buffer behavior deterministic
-- and unit-testable under Lua 5.1.

local InputState = require("src.core.InputState")

local NamingScreenState = {}

NamingScreenState.MAX_NAME_LENGTH = 7
NamingScreenState.EOS = 0xFF
NamingScreenState.SPACE = 0x00

-- KBPAGE_* order (the order pages cycle in), not KEYBOARD_* order.
NamingScreenState.PAGE_SYMBOLS = 0
NamingScreenState.PAGE_UPPER = 1
NamingScreenState.PAGE_LOWER = 2
NamingScreenState.PAGE_COUNT = 3

NamingScreenState.ROLE_CHAR = "char"
NamingScreenState.ROLE_PAGE = "page"
NamingScreenState.ROLE_BACKSPACE = "backspace"
NamingScreenState.ROLE_OK = "ok"

-- Transcribed byte-for-byte from sKeyboardChars. Rows retain their real
-- eight-byte storage width even though the symbols page exposes six cols.
local KEYBOARD_CHARS = {
  [NamingScreenState.PAGE_LOWER] = {
    {0xD5,0xD6,0xD7,0xD8,0xD9,0xDA,0x00,0xAD},
    {0xDB,0xDC,0xDD,0xDE,0xDF,0xE0,0x00,0xB8},
    {0xE1,0xE2,0xE3,0xE4,0xE5,0xE6,0xE7,0x00},
    {0xE8,0xE9,0xEA,0xEB,0xEC,0xED,0xEE,0x00},
  },
  [NamingScreenState.PAGE_UPPER] = {
    {0xBB,0xBC,0xBD,0xBE,0xBF,0xC0,0x00,0xAD},
    {0xC1,0xC2,0xC3,0xC4,0xC5,0xC6,0x00,0xB8},
    {0xC7,0xC8,0xC9,0xCA,0xCB,0xCC,0xCD,0x00},
    {0xCE,0xCF,0xD0,0xD1,0xD2,0xD3,0xD4,0x00},
  },
  [NamingScreenState.PAGE_SYMBOLS] = {
    {0xA1,0xA2,0xA3,0xA4,0xA5,0x00,0x00,0x00},
    {0xA6,0xA7,0xA8,0xA9,0xAA,0x00,0x00,0x00},
    {0xAB,0xAC,0xB5,0xB6,0xBA,0xAE,0x00,0x00},
    {0xB0,0xB1,0xB2,0xB3,0xB4,0x00,0x00,0x00},
  },
}

local COLUMN_COUNTS = {
  [NamingScreenState.PAGE_SYMBOLS] = 6,
  [NamingScreenState.PAGE_UPPER] = 8,
  [NamingScreenState.PAGE_LOWER] = 8,
}

-- Real cursor sprite x positions before the +38 screen offset.
local COLUMN_X = {
  [NamingScreenState.PAGE_SYMBOLS] = {0,22,44,66,88,110},
  [NamingScreenState.PAGE_UPPER] = {0,12,24,56,68,80,92,123},
  [NamingScreenState.PAGE_LOWER] = {0,12,24,56,68,80,92,123},
}

NamingScreenState.KEYBOARD_CHARS = KEYBOARD_CHARS
NamingScreenState.COLUMN_COUNTS = COLUMN_COUNTS
NamingScreenState.COLUMN_X = COLUMN_X

local function copyBytes(bytes, maxChars)
  local out = {}
  if type(bytes) == "string" then
    for i = 1, math.min(#bytes, maxChars) do
      local b = string.byte(bytes, i)
      if b == NamingScreenState.EOS then break end
      out[#out + 1] = b
    end
  elseif type(bytes) == "table" then
    for i = 1, math.min(#bytes, maxChars) do
      local b = bytes[i]
      if b == NamingScreenState.EOS then break end
      out[#out + 1] = b
    end
  end
  return out
end

-- fallbackBytes mirrors oak_speech.c's GetDefaultName call immediately
-- before DoNamingScreen: an empty/all-space entry leaves that destination
-- unchanged. The flow supplies a real FireRed default-name byte string.
function NamingScreenState.new(opts)
  opts = opts or {}
  local maxChars = opts.maxChars or NamingScreenState.MAX_NAME_LENGTH
  return setmetatable({
    maxChars = maxChars,
    page = opts.page == nil and NamingScreenState.PAGE_UPPER or opts.page,
    cursorX = 0,
    cursorY = 0,
    savedKeyRow = 0, -- Task_HandleInput's tButtonId while on button col
    buffer = copyBytes(opts.initialBytes, maxChars),
    fallback = copyBytes(opts.fallbackBytes, maxChars),
    finished = false,
  }, { __index = NamingScreenState })
end

function NamingScreenState:columnCount()
  return COLUMN_COUNTS[self.page]
end

function NamingScreenState:keyRole()
  if self.cursorX < self:columnCount() then return NamingScreenState.ROLE_CHAR end
  if self.cursorY == 0 then return NamingScreenState.ROLE_PAGE end
  if self.cursorY == 1 then return NamingScreenState.ROLE_BACKSPACE end
  return NamingScreenState.ROLE_OK
end

function NamingScreenState:currentChar()
  if self:keyRole() ~= NamingScreenState.ROLE_CHAR then return nil end
  return KEYBOARD_CHARS[self.page][self.cursorY + 1][self.cursorX + 1]
end

-- Exact HandleDpadMovement topology: keys have 4 rows, the right-hand
-- PAGE/BACK/OK column has 3. Horizontal movement remembers which key row
-- BACK came from so moving left returns to that row.
function NamingScreenState:move(dx, dy)
  local count = self:columnCount()
  local previousX = self.cursorX
  local x, y = self.cursorX + dx, self.cursorY + dy

  if x < 0 then x = count end
  if x > count then x = 0 end

  if dx ~= 0 then
    if x == count then
      self.savedKeyRow = y
      local keyToButton = { [0]=0, [1]=1, [2]=1, [3]=2 }
      y = keyToButton[y]
    elseif previousX == count then
      if y == 1 then
        y = self.savedKeyRow
      else
        local buttonToKey = { [0]=0, [2]=3 }
        y = buttonToKey[y] or 0
      end
    end
  end

  if x == count then
    if y < 0 then y = 2 end
    if y >= 3 then y = 0 end
    if y == 0 then self.savedKeyRow = 1 end -- BUTTON_BACK, real code
    if y == 2 then self.savedKeyRow = 2 end -- BUTTON_OK, real code
  else
    if y < 0 then y = 3 end
    if y >= 4 then y = 0 end
  end

  self.cursorX, self.cursorY = x, y
end

function NamingScreenState:swapPage()
  local wasButtonColumn = self.cursorX == self:columnCount()
  self.page = (self.page + 1) % NamingScreenState.PAGE_COUNT
  local count = self:columnCount()
  if wasButtonColumn then
    self.cursorX = count
  elseif self.cursorX >= count then
    self.cursorX = count - 1
  end
end

function NamingScreenState:addCharacter()
  if #self.buffer >= self.maxChars then
    -- BufferCharacter overwrites the final byte once full because
    -- GetTextEntryPosition returns maxChars-1 in that case.
    self.buffer[self.maxChars] = self:currentChar()
  else
    self.buffer[#self.buffer + 1] = self:currentChar()
  end
  if #self.buffer >= self.maxChars then
    self.cursorX, self.cursorY = self:columnCount(), 2 -- MoveCursorToOKButton
  end
end

function NamingScreenState:backspace()
  if #self.buffer > 0 then self.buffer[#self.buffer] = nil end
end

function NamingScreenState:hasNonSpaceCharacter()
  for _, b in ipairs(self.buffer) do
    if b ~= NamingScreenState.SPACE and b ~= NamingScreenState.EOS then return true end
  end
  return false
end

function NamingScreenState:resultBytes()
  local source = self:hasNonSpaceCharacter() and self.buffer or self.fallback
  local chars = {}
  for i = 1, math.min(#source, self.maxChars) do chars[#chars + 1] = string.char(source[i]) end
  while #chars < self.maxChars do chars[#chars + 1] = string.char(NamingScreenState.EOS) end
  chars[#chars + 1] = string.char(NamingScreenState.EOS)
  return table.concat(chars)
end

function NamingScreenState:entryBytes()
  local chars = {}
  for i = 1, #self.buffer do chars[#chars + 1] = string.char(self.buffer[i]) end
  chars[#chars + 1] = string.char(NamingScreenState.EOS)
  return table.concat(chars)
end

function NamingScreenState:cursorScreenPosition()
  if self.cursorX >= self:columnCount() then return nil end
  return COLUMN_X[self.page][self.cursorX + 1] + 38, self.cursorY * 16 + 88
end

-- Returns "finish" when OK is activated; every other action mutates the
-- state and returns nil. SELECT swaps pages, B backspaces, START jumps to
-- OK exactly like HandleKeyboardEvent.
function NamingScreenState:processInput(input)
  -- Input_Enabled's real priority is A, B, SELECT, START, then D-pad.
  if input:isNewlyPressed(InputState.A_BUTTON) then
    local role = self:keyRole()
    if role == NamingScreenState.ROLE_CHAR then
      self:addCharacter()
    elseif role == NamingScreenState.ROLE_PAGE then
      self:swapPage()
    elseif role == NamingScreenState.ROLE_BACKSPACE then
      self:backspace()
    else
      self.finished = true
      return "finish"
    end
  elseif input:isNewlyPressed(InputState.B_BUTTON) then
    self:backspace()
  elseif input:isNewlyPressed(InputState.SELECT_BUTTON) then
    self:swapPage()
  elseif input:isNewlyPressed(InputState.START_BUTTON) then
    self.cursorX, self.cursorY = self:columnCount(), 2
  elseif input:isPressedOrRepeated(InputState.DPAD_UP) then
    self:move(0, -1)
  elseif input:isPressedOrRepeated(InputState.DPAD_DOWN) then
    self:move(0, 1)
  elseif input:isPressedOrRepeated(InputState.DPAD_LEFT) then
    self:move(-1, 0)
  elseif input:isPressedOrRepeated(InputState.DPAD_RIGHT) then
    self:move(1, 0)
  end
  return nil
end

return NamingScreenState
