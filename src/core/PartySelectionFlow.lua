-- Minimal, read-only normal-field party selection action flow.
-- Source lock: pret/pokefirered src/party_menu.c:
-- HandleChooseMonSelection -> Task_TryCreateSelectionWindow,
-- SetPartyMonFieldSelectionActions (SUMMARY first, CANCEL last),
-- CursorCB_Summary -> CB2_ReturnToPartyMenuFromSummaryScreen.
--
-- This is deliberately only SUMMARY / CANCEL. Retail SWITCH, ITEM and
-- field moves are NOT represented here because their normal callbacks and
-- mutation handling have not been implemented or accepted.
-- Summary mon cycling/page switching are deliberately excluded. Retail
-- CB2_ReturnToPartyMenuFromSummaryScreen restores GetLastViewedMonIndex;
-- it is the original slot here only because this reduced view cannot cycle.
-- The caller holds the original PartyScreen selection while this flow is
-- active; after closing, it calls PartyScreen:resumeBrowsing().

local InputState = require("src.core.InputState")
local MenuCursor = require("src.core.MenuCursor")

local PartySelectionFlow = {}
PartySelectionFlow.__index = PartySelectionFlow

PartySelectionFlow.ACTIONS = "actions"
PartySelectionFlow.SUMMARY = "summary"
PartySelectionFlow.CLOSED = "closed"
PartySelectionFlow.ACTION_SUMMARY = "SUMMARY"
PartySelectionFlow.ACTION_CANCEL = "CANCEL"

function PartySelectionFlow.new(partyScreen)
  assert(partyScreen and partyScreen.state == "confirmed"
    and type(partyScreen.confirmedSlot) == "number",
    "PartySelectionFlow requires a confirmed PartyScreen slot")
  assert(partyScreen.confirmedSlot >= 1
    and partyScreen.confirmedSlot <= partyScreen.party:size(),
    "confirmed PartyScreen slot is invalid")
  return setmetatable({
    partyScreen = partyScreen,
    slot = partyScreen.confirmedSlot,
    state = PartySelectionFlow.ACTIONS,
    cursor = MenuCursor.new(2, 0),
  }, PartySelectionFlow)
end

function PartySelectionFlow:isDone()
  return self.state == PartySelectionFlow.CLOSED
end

function PartySelectionFlow:currentAction()
  if self.cursor.cursorPos == 0 then return PartySelectionFlow.ACTION_SUMMARY end
  return PartySelectionFlow.ACTION_CANCEL
end

-- Read-only, decoded on demand so summary never writes the saved party.
function PartySelectionFlow:summaryData()
  if self.state ~= PartySelectionFlow.SUMMARY then return nil end
  return self.partyScreen:summaryData(self.slot)
end

function PartySelectionFlow:processInput(input)
  if self.state == PartySelectionFlow.CLOSED then return end

  if self.state == PartySelectionFlow.SUMMARY then
    -- One read-only projection: A/directional/L/R input cannot change mon
    -- or page. New B returns to actions without processing that input again.
    if input:isNewlyPressed(InputState.B_BUTTON) then
      self.state = PartySelectionFlow.ACTIONS
    end
    return
  end

  -- c75f352 party_menu.c:3069-3070 selects the <=3-action variant;
  -- menu.c:425-450 reads new A, new B, then JOY_REPT(DPAD_ANY), with
  -- exact UP/DOWN equality. Shared processInputNoWrap is new-D-pad-only,
  -- so keep this repeated-input variant local and reuse only its clamping.
  local result
  if input:isNewlyPressed(InputState.A_BUTTON) then
    result = "confirm"
  elseif input:isNewlyPressed(InputState.B_BUTTON) then
    result = "cancel"
  else
    -- DPAD_ANY is bits 4-7 (0xF0); ignore other buttons, reject chords.
    local dpad = input.newAndRepeatedKeys % 0x100 - input.newAndRepeatedKeys % 0x10
    if dpad == InputState.DPAD_UP then self.cursor:moveCursorNoWrap(-1)
    elseif dpad == InputState.DPAD_DOWN then self.cursor:moveCursorNoWrap(1) end
  end
  if result == "cancel"
      or (result == "confirm" and self:currentAction() == PartySelectionFlow.ACTION_CANCEL) then
    self.state = PartySelectionFlow.CLOSED
  elseif result == "confirm" then
    self.state = PartySelectionFlow.SUMMARY
  end
end

return PartySelectionFlow
