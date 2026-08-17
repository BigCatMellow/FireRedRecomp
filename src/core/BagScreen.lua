-- Pure state machine for FireRed's real field-context Bag screen (opened
-- by the real STARTMENU_BAG item; `src/item_menu.c`'s `Task_BagMenu_
-- HandleInput`). Same "pure state machine before its ROM-backed scene"
-- pattern as StartMenu.lua/PartyScreen.lua/PokemonMartMenu.lua.
--
-- Pocket cycle (real `ProcessPocketSwitchInput`, src/item_menu.c line
-- ~1119): DPAD_LEFT/RIGHT (or L/R) switch pockets, clamped (NOT wrapped)
-- at both ends -- `if (pocketId == POCKET_ITEMS - 1) return 0` blocks
-- LEFT past Items, `if (pocketId >= POCKET_POKE_BALLS - 1) return 0`
-- blocks RIGHT past Poké Balls. Confirmed real: the ordinary field Bag
-- ONLY cycles ITEMS -> KEY ITEMS -> POKÉ BALLS (3 pockets), never TM
-- Case or Berry Pouch -- those are real separate screens opened as key
-- items FROM the Key Items pocket (`GoToTMCase`/`GoToBerryPouch`,
-- already flagged the same way in PokemonMartMenu.lua's own header for
-- the sell-side equivalent), out of scope here.
--
-- List shape: real `ListMenu_ProcessInput` over the current pocket's
-- items, with one extra CLOSE row after the last item
-- (`input == sBagMenuDisplay->nItems[pocket]` is the real "close the
-- bag" case, same shape PartyScreen.lua's CANCEL row already models --
-- reused verbatim here as CANCEL). Real held-repeat nav
-- (`ListMenu_ProcessInput`), matching PartyScreen's own choice, NOT
-- StartMenu's newly-pressed-only nav.
--
-- A_BUTTON on CANCEL / B_BUTTON anywhere: real `LIST_CANCEL`/close-bag
-- path (`Bag_BeginCloseWin0Animation` -> `ItemMenu_StartFadeToExitCallback`)
-- closes the whole Bag screen back to the Start menu. Ported as the
-- CLOSED state, same as StartMenu/PartyScreen's own B-closes convention.
--
-- A_BUTTON on an item: real `Task_ItemContextMenuByLocation` opens a
-- real per-item context menu (USE/TOSS/etc., location-dependent). That's
-- separate, larger scope (its own window/cursor/task machinery, same
-- category of boundary PartyScreen.lua already drew around the real
-- SUMMARY/SWITCH/ITEM submenu) -- this module stops at reporting which
-- item was confirmed (`:confirmedItemId()`/`:confirmedPocket()`), same
-- shape as PartyScreen's `:confirmedSlot()`.
--
-- Real per-pocket cursor-position memory (`gBagMenuState.cursorPos[]`,
-- one remembered row per pocket, restored when you switch back) is NOT
-- ported -- switching pockets here always resets the cursor to row 0, a
-- documented simplification, not a guess at unverified per-pocket state
-- restoration behavior.

local InputState = require("src.core.InputState")
local MenuCursor = require("src.core.MenuCursor")
local Bag = require("src.core.Bag")

local BagScreen = {}
BagScreen.__index = BagScreen

BagScreen.BROWSING = "browsing"
BagScreen.CONFIRMED = "confirmed"
BagScreen.CLOSED = "closed"

-- Real field-Bag pocket cycle order (see header) -- POCKET_ITEMS first,
-- POCKET_POKE_BALLS last, TM_CASE/BERRY_POUCH never reached this way.
BagScreen.POCKET_CYCLE = { Bag.POCKET_ITEMS, Bag.POCKET_KEY_ITEMS, Bag.POCKET_POKE_BALLS }

-- bag: a real Bag.lua instance (read-only here).
function BagScreen.new(bag)
  assert(bag and bag.iteratePocket and bag.itemLookup, "BagScreen needs a real Bag instance")
  local self = setmetatable({
    bag = bag,
    pocketIndex = 1, -- 1-based index into POCKET_CYCLE
    state = BagScreen.BROWSING,
    confirmedItemId = nil,
    confirmedPocket = nil,
  }, BagScreen)
  self:_rebuildForPocket()
  return self
end

function BagScreen:pocket()
  return BagScreen.POCKET_CYCLE[self.pocketIndex]
end

function BagScreen:_rebuildForPocket()
  local items = {}
  for _, itemId, quantity in self.bag:iteratePocket(self:pocket()) do
    items[#items + 1] = { itemId = itemId, quantity = quantity }
  end
  self.items = items
  -- size()+1 rows: every occupied slot plus one CLOSE row, same real
  -- shape as PartyScreen's mons+CANCEL (see header).
  self.cursor = MenuCursor.new(#items + 1, 0)
end

function BagScreen:isDone()
  return self.state ~= BagScreen.BROWSING
end

function BagScreen:cursorRow()
  return self.cursor.cursorPos
end

function BagScreen:isCancelRow(row)
  return row == #self.items
end

-- input: an InputState instance already ticked this frame.
function BagScreen:processInput(input)
  if self.state ~= BagScreen.BROWSING then return end

  -- Real ProcessPocketSwitchInput: LEFT/RIGHT clamp (no wrap) at the
  -- pocket-cycle ends, checked before ordinary list nav.
  if input:isNewlyPressed(InputState.DPAD_LEFT) then
    if self.pocketIndex > 1 then
      self.pocketIndex = self.pocketIndex - 1
      self:_rebuildForPocket()
    end
    return
  elseif input:isNewlyPressed(InputState.DPAD_RIGHT) then
    if self.pocketIndex < #BagScreen.POCKET_CYCLE then
      self.pocketIndex = self.pocketIndex + 1
      self:_rebuildForPocket()
    end
    return
  end

  local result = self.cursor:processInput(input)
  if result == "cancel" then
    self.state = BagScreen.CLOSED
  elseif result == "confirm" then
    local row = self.cursor.cursorPos
    if self:isCancelRow(row) then
      self.state = BagScreen.CLOSED
    else
      local entry = self.items[row + 1]
      self.confirmedItemId = entry.itemId
      self.confirmedPocket = self:pocket()
      self.state = BagScreen.CONFIRMED
    end
  end
end

-- Iterates every row a caller should render, in real display order:
-- occupied slots first, then the CLOSE row last. `for row, isCancel,
-- itemId, quantity in bagScreen:iterateRows() do ... end` -- itemId/
-- quantity are nil for the CLOSE row (isCancel == true).
function BagScreen:iterateRows()
  local count = #self.items
  local row = -1
  return function()
    row = row + 1
    if row < count then
      local entry = self.items[row + 1]
      return row, false, entry.itemId, entry.quantity
    elseif row == count then
      return row, true, nil, nil
    end
  end
end

return BagScreen
