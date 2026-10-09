-- Minimal, read-only normal-field party selection action flow.
-- Source lock: pret/pokefirered src/party_menu.c:
-- HandleChooseMonSelection -> Task_TryCreateSelectionWindow,
-- SetPartyMonFieldSelectionActions (SUMMARY first, CANCEL last),
-- CursorCB_Summary -> CB2_ReturnToPartyMenuFromSummaryScreen.
--
-- This is deliberately only SUMMARY / CANCEL. Retail SWITCH, ITEM and
-- field moves are NOT represented here because their normal callbacks and
-- mutation handling have not been implemented or accepted.
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
    -- The bounded summary has one information page. In FireRed B returns
    -- to the previous party-slot action window, preserving the selected mon.
    if input:isNewlyPressed(InputState.B_BUTTON) then
      self.state = PartySelectionFlow.ACTIONS
    end
    return
  end

  -- The real Task_HandleSelectionMenuInput uses a no-wrap cursor when
  -- there are three or fewer actions (we have two).
  local result = self.cursor:processInputNoWrap(input)
  if result == "cancel"
      or (result == "confirm" and self:currentAction() == PartySelectionFlow.ACTION_CANCEL) then
    self.state = PartySelectionFlow.CLOSED
  elseif result == "confirm" then
    self.state = PartySelectionFlow.SUMMARY
  end
end

return PartySelectionFlow
