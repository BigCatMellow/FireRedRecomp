-- Pure orchestration for FireRed's post-Oak new-game identity flow.
--
-- Source: pokefirered src/oak_speech.c, from
-- Task_OakSpeech_AskPlayerGender through Task_OakSpeech_LetsGo. The real
-- order is gender -> player naming keyboard -> Yes/No confirmation ->
-- rival NEW NAME/four-default menu -> optional naming keyboard -> Yes/No
-- confirmation. Names remain FireRed charmap byte strings (7 bytes + EOS)
-- so the completed result has the exact SaveBlockLayout field shape.
--
-- Visual fades, trainer-picture transitions, sound and the final shrink
-- animation are presentation concerns and are deliberately outside this
-- pure state machine. import/NamingScreenScene.lua and main.lua consume
-- this state without feeding presentation state back into it.

local Charmap = require("import.Charmap")
local InputState = require("src.core.InputState")
local MenuCursor = require("src.core.MenuCursor")
local NamingScreenState = require("src.core.NamingScreenState")

local NewGameFlow = {}

NewGameFlow.MALE = 0
NewGameFlow.FEMALE = 1

NewGameFlow.GENDER = "gender"
NewGameFlow.PLAYER_NAMING = "playerNaming"
NewGameFlow.PLAYER_CONFIRM = "playerConfirm"
NewGameFlow.RIVAL_CHOICE = "rivalChoice"
NewGameFlow.RIVAL_NAMING = "rivalNaming"
NewGameFlow.RIVAL_CONFIRM = "rivalConfirm"
NewGameFlow.COMPLETE = "complete"

local function encodeName(text)
  local out = {}
  for i = 1, math.min(#text, NamingScreenState.MAX_NAME_LENGTH) do
    local c = text:sub(i, i)
    local b
    if c == " " then b = 0x00
    elseif c >= "A" and c <= "Z" then b = 0xBB + string.byte(c) - string.byte("A")
    elseif c >= "a" and c <= "z" then b = 0xD5 + string.byte(c) - string.byte("a")
    elseif c >= "0" and c <= "9" then b = 0xA1 + string.byte(c) - string.byte("0")
    elseif c == "-" then b = 0xAE
    elseif c == "." then b = 0xAD
    elseif c == "," then b = 0xB8
    elseif c == "'" then b = 0xB4
    else error("name contains unsupported FireRed charmap character: " .. c) end
    out[#out + 1] = string.char(b)
  end
  while #out < NamingScreenState.MAX_NAME_LENGTH do out[#out + 1] = string.char(NamingScreenState.EOS) end
  out[#out + 1] = string.char(NamingScreenState.EOS)
  return table.concat(out)
end

-- Exact source lists, including the FireRed-only first entries. Only four
-- are printed in the menu; all 19 player entries participate in the real
-- Random()%ARRAY_COUNT fallback selected before DoNamingScreen.
local MALE_DEFAULTS = {
  "RED","FIRE","ASH","KENE","GEKI","JAK","JANNE","JONN","KAMON","KARL",
  "TAYLOR","OSCAR","HIRO","MAX","JON","RALPH","KAY","TOSH","ROAK",
}
local FEMALE_DEFAULTS = {
  "RED","FIRE","OMI","JODI","AMANDA","HILLARY","MAKEY","MICHI","PAULA","JUNE",
  "CASSIE","REY","SEDA","KIKO","MINA","NORIE","SAI","MOMO","SUZI",
}
local RIVAL_DEFAULTS = { "GREEN", "GARY", "KAZ", "TORU" }

NewGameFlow.MALE_DEFAULTS = MALE_DEFAULTS
NewGameFlow.FEMALE_DEFAULTS = FEMALE_DEFAULTS
NewGameFlow.RIVAL_DEFAULTS = RIVAL_DEFAULTS
NewGameFlow.encodeName = encodeName

function NewGameFlow.new(opts)
  opts = opts or {}
  return setmetatable({
    state = NewGameFlow.GENDER,
    genderCursor = MenuCursor.new(2, 0),
    rivalChoiceCursor = MenuCursor.new(5, 0),
    confirmCursor = MenuCursor.new(2, 0),
    playerGender = nil,
    playerName = nil,
    rivalName = nil,
    naming = nil,
    revision = 0,
    nextRandom16 = opts.nextRandom16 or function() return 0 end,
  }, { __index = NewGameFlow })
end

function NewGameFlow:_touch()
  self.revision = self.revision + 1
end

function NewGameFlow:_playerFallback()
  local choices = self.playerGender == NewGameFlow.FEMALE and FEMALE_DEFAULTS or MALE_DEFAULTS
  local index = (self.nextRandom16() % #choices) + 1
  return encodeName(choices[index])
end

function NewGameFlow:beginPlayerNaming(gender)
  self.playerGender = gender
  self.naming = NamingScreenState.new({ fallbackBytes = self:_playerFallback() })
  self.state = NewGameFlow.PLAYER_NAMING
  self:_touch()
end

function NewGameFlow:beginRivalChoice(playerName)
  if playerName then self.playerName = playerName end
  self.naming = nil
  self.rivalChoiceCursor.cursorPos = 0
  self.state = NewGameFlow.RIVAL_CHOICE
  self:_touch()
end

function NewGameFlow:beginRivalNaming()
  self.naming = NamingScreenState.new({ fallbackBytes = encodeName(RIVAL_DEFAULTS[1]) })
  self.state = NewGameFlow.RIVAL_NAMING
  self:_touch()
end

function NewGameFlow:activeCursor()
  if self.state == NewGameFlow.GENDER then return self.genderCursor end
  if self.state == NewGameFlow.RIVAL_CHOICE then return self.rivalChoiceCursor end
  if self.state == NewGameFlow.PLAYER_CONFIRM or self.state == NewGameFlow.RIVAL_CONFIRM then return self.confirmCursor end
  return nil
end

function NewGameFlow:activeNameBytes()
  if self.state == NewGameFlow.PLAYER_NAMING or self.state == NewGameFlow.PLAYER_CONFIRM then return self.playerName end
  if self.state == NewGameFlow.RIVAL_NAMING or self.state == NewGameFlow.RIVAL_CONFIRM then return self.rivalName end
  return nil
end

function NewGameFlow:displayName(bytes)
  return bytes and Charmap.decode(bytes) or ""
end

function NewGameFlow:isComplete()
  return self.state == NewGameFlow.COMPLETE
end

local function menuChanged(cursor, input)
  local before = cursor.cursorPos
  local outcome = cursor:processInput(input)
  return outcome, before ~= cursor.cursorPos
end

function NewGameFlow:processInput(input)
  if self.state == NewGameFlow.GENDER then
    local before = self.genderCursor.cursorPos
    local outcome = self.genderCursor:processInputNoWrap(input)
    local moved = before ~= self.genderCursor.cursorPos
    if moved then self:_touch() end
    -- Task_OakSpeech_HandleGenderInput ignores B; A commits cursor row.
    if outcome == "confirm" then self:beginPlayerNaming(self.genderCursor.cursorPos) end
    return
  end

  if self.state == NewGameFlow.PLAYER_NAMING then
    local before = self.naming.page .. ":" .. self.naming.cursorX .. ":" .. self.naming.cursorY .. ":" .. self.naming:entryBytes()
    if self.naming:processInput(input) == "finish" then
      self.playerName = self.naming:resultBytes()
      self.confirmCursor.cursorPos = 0
      self.state = NewGameFlow.PLAYER_CONFIRM
    end
    local after = self.naming.page .. ":" .. self.naming.cursorX .. ":" .. self.naming.cursorY .. ":" .. self.naming:entryBytes()
    if before ~= after or self.state ~= NewGameFlow.PLAYER_NAMING then self:_touch() end
    return
  end

  if self.state == NewGameFlow.PLAYER_CONFIRM then
    local outcome, moved = menuChanged(self.confirmCursor, input)
    if moved then self:_touch() end
    if outcome == "cancel" or (outcome == "confirm" and self.confirmCursor.cursorPos == 1) then
      self.naming = NamingScreenState.new({ fallbackBytes = self:_playerFallback() })
      self.state = NewGameFlow.PLAYER_NAMING
      self:_touch()
    elseif outcome == "confirm" then
      self:beginRivalChoice()
    end
    return
  end

  if self.state == NewGameFlow.RIVAL_CHOICE then
    local outcome, moved = menuChanged(self.rivalChoiceCursor, input)
    if moved then self:_touch() end
    -- Like Task_OakSpeech_HandleRivalNameInput, B is ignored.
    if outcome == "confirm" then
      if self.rivalChoiceCursor.cursorPos == 0 then
        self:beginRivalNaming()
      else
        self.rivalName = encodeName(RIVAL_DEFAULTS[self.rivalChoiceCursor.cursorPos])
        self.confirmCursor.cursorPos = 0
        self.state = NewGameFlow.RIVAL_CONFIRM
        self:_touch()
      end
    end
    return
  end

  if self.state == NewGameFlow.RIVAL_NAMING then
    local before = self.naming.page .. ":" .. self.naming.cursorX .. ":" .. self.naming.cursorY .. ":" .. self.naming:entryBytes()
    if self.naming:processInput(input) == "finish" then
      self.rivalName = self.naming:resultBytes()
      self.confirmCursor.cursorPos = 0
      self.state = NewGameFlow.RIVAL_CONFIRM
    end
    local after = self.naming.page .. ":" .. self.naming.cursorX .. ":" .. self.naming.cursorY .. ":" .. self.naming:entryBytes()
    if before ~= after or self.state ~= NewGameFlow.RIVAL_NAMING then self:_touch() end
    return
  end

  if self.state == NewGameFlow.RIVAL_CONFIRM then
    local outcome, moved = menuChanged(self.confirmCursor, input)
    if moved then self:_touch() end
    if outcome == "cancel" or (outcome == "confirm" and self.confirmCursor.cursorPos == 1) then
      self:beginRivalChoice()
    elseif outcome == "confirm" then
      self.naming = nil
      self.state = NewGameFlow.COMPLETE
      self:_touch()
    end
  end
end

function NewGameFlow:result()
  if not self:isComplete() then return nil end
  return {
    playerGender = self.playerGender,
    playerName = self.playerName,
    rivalName = self.rivalName,
  }
end

return NewGameFlow
