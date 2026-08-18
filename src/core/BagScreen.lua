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
-- A_BUTTON on an item: real `Task_ItemContextMenuByLocation` opens a real
-- per-item context menu. Real action lists are per-pocket
-- (`sContextMenuItems_Field`, src/item_menu.c ~209): ITEMS gets
-- USE/GIVE/TOSS/CANCEL, KEY ITEMS gets USE/REGISTER/CANCEL, POKÉ BALLS
-- gets GIVE/TOSS/CANCEL (no USE -- you can't "use" a Poké Ball from the
-- bag outside battle). Ported here: CANCEL and TOSS are real and fully
-- functional (see the TOSS flow below); USE (real per-item field-effect
-- dispatch, `ItemId_GetFieldFunc`) and GIVE (attaching a held item to a
-- party mon, needs a live party-select UI) are both separate, larger
-- systems this project doesn't have yet -- selecting either shows a
-- bounded "not available yet" message rather than pretending to work.
-- REGISTER (binding an item to the Select button) is not ported at all
-- (omitted from the Key Items action list) -- a real, minor, standalone
-- feature with no dependency on anything else here.
--
-- TOSS flow (real `Task_ItemMenuAction_Toss` -> `Task_SelectQuantityToToss`
-- -> `Task_ConfirmTossItems`/`sYesNoMenu_Toss` -> `Task_TossItem_Yes` ->
-- `Task_WaitAB_RedrawAndReturnToBag`, src/item_menu.c ~1479-1573): owning
-- exactly 1 of an item skips the quantity dialog and goes straight to
-- the Yes/No confirmation (real `data[2] == 1` branch, same real pattern
-- already ported for Mart SELL in PokemonMartMenu.lua). A genuinely
-- subtle real detail, ported exactly: `RemoveBagItem` is NOT called at
-- the Yes/No confirmation -- it only happens once the player dismisses
-- the FOLLOWING "Threw away N ITEMs!" message
-- (`Task_WaitAB_RedrawAndReturnToBag`), not at the moment of confirming.
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
BagScreen.CONTEXT_MENU = "context_menu"
BagScreen.TOSS_QUANTITY = "toss_quantity"
BagScreen.TOSS_CONFIRM = "toss_confirm"
BagScreen.MESSAGE = "message"
BagScreen.CLOSED = "closed"

-- Real field-Bag pocket cycle order (see header) -- POCKET_ITEMS first,
-- POCKET_POKE_BALLS last, TM_CASE/BERRY_POUCH never reached this way.
BagScreen.POCKET_CYCLE = { Bag.POCKET_ITEMS, Bag.POCKET_KEY_ITEMS, Bag.POCKET_POKE_BALLS }

-- Real sContextMenuItems_Field (src/item_menu.c ~209), REGISTER omitted
-- (see header). "USE"/"GIVE" are bounded stubs; "TOSS"/"CANCEL" are real.
BagScreen.CONTEXT_ACTIONS = {
  [Bag.POCKET_ITEMS] = { "USE", "GIVE", "TOSS", "CANCEL" },
  [Bag.POCKET_KEY_ITEMS] = { "USE", "CANCEL" },
  [Bag.POCKET_POKE_BALLS] = { "GIVE", "TOSS", "CANCEL" },
}

-- bag: a real Bag.lua instance (mutated in place by a real TOSS).
function BagScreen.new(bag)
  assert(bag and bag.iteratePocket and bag.itemLookup, "BagScreen needs a real Bag instance")
  local self = setmetatable({
    bag = bag,
    pocketIndex = 1, -- 1-based index into POCKET_CYCLE
    state = BagScreen.BROWSING,
    selectedItemId = nil,
    tossQuantity = 1,
    tossMaxQuantity = 1,
    message = nil,
    afterMessage = BagScreen.BROWSING,
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
  return self.state == BagScreen.CLOSED
end

function BagScreen:cursorRow()
  return self.cursor.cursorPos
end

function BagScreen:isCancelRow(row)
  return row == #self.items
end

function BagScreen:contextActions()
  return BagScreen.CONTEXT_ACTIONS[self:pocket()]
end

function BagScreen:_setMessage(text, afterState)
  self.message = text
  self.afterMessage = afterState
  self.state = BagScreen.MESSAGE
end

function BagScreen:_quantityOfSelected()
  return self.bag:quantityOf(self.selectedItemId)
end

-- input: an InputState instance already ticked this frame.
function BagScreen:processInput(input)
  if self.state == BagScreen.MESSAGE then
    if input:isNewlyPressed(InputState.A_BUTTON) or input:isNewlyPressed(InputState.B_BUTTON) then
      if self.pendingTossQuantity then
        -- Real Task_WaitAB_RedrawAndReturnToBag: RemoveBagItem only runs
        -- here, on dismissing the "Threw away..." message (see header).
        self.bag:removeItem(self.selectedItemId, self.pendingTossQuantity)
        self.pendingTossQuantity = nil
        self:_rebuildForPocket()
        if self.cursor.cursorPos > self.cursor.maxCursorPos then
          self.cursor.cursorPos = self.cursor.maxCursorPos
        end
      end
      self.state = self.afterMessage
      self.message = nil
    end
    return
  end

  if self.state == BagScreen.BROWSING then
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
        self.selectedItemId = self.items[row + 1].itemId
        self.contextCursor = MenuCursor.new(#self:contextActions(), 0)
        self.state = BagScreen.CONTEXT_MENU
      end
    end
    return
  end

  if self.state == BagScreen.CONTEXT_MENU then
    local result = self.contextCursor:processInput(input)
    if result == "cancel" then
      self.state = BagScreen.BROWSING
    elseif result == "confirm" then
      local action = self:contextActions()[self.contextCursor.cursorPos + 1]
      if action == "CANCEL" then
        self.state = BagScreen.BROWSING
      elseif action == "TOSS" then
        self.tossMaxQuantity = self:_quantityOfSelected()
        if self.tossMaxQuantity <= 1 then
          -- Real Task_ItemMenuAction_Toss: data[2] == 1 skips the
          -- quantity dialog and goes straight to the Yes/No confirm.
          self.tossQuantity = 1
          self.state = BagScreen.TOSS_CONFIRM
        else
          self.tossQuantity = 1
          self.state = BagScreen.TOSS_QUANTITY
        end
      else -- USE / GIVE: real systems this project doesn't have yet.
        self:_setMessage(action .. " is not available yet.", BagScreen.BROWSING)
      end
    end
    return
  end

  if self.state == BagScreen.TOSS_QUANTITY then
    -- Real AdjustQuantityAccordingToDPadInput (src/menu_helpers.c), same
    -- math already ported in PokemonMartMenu.lua's own QUANTITY state.
    if input:isPressedOrRepeated(InputState.DPAD_UP) then
      self.tossQuantity = self.tossQuantity + 1
      if self.tossQuantity > self.tossMaxQuantity then self.tossQuantity = 1 end
    elseif input:isPressedOrRepeated(InputState.DPAD_DOWN) then
      self.tossQuantity = self.tossQuantity - 1
      if self.tossQuantity <= 0 then self.tossQuantity = self.tossMaxQuantity end
    elseif input:isPressedOrRepeated(InputState.DPAD_RIGHT) then
      self.tossQuantity = math.min(self.tossMaxQuantity, self.tossQuantity + 10)
    elseif input:isPressedOrRepeated(InputState.DPAD_LEFT) then
      self.tossQuantity = math.max(1, self.tossQuantity - 10)
    elseif input:isNewlyPressed(InputState.B_BUTTON) then
      -- Real Task_SelectQuantityToToss's B: back to the bag list directly
      -- (Task_RedrawArrowsAndReturnToBagMenuSelect), not the context menu.
      self.state = BagScreen.BROWSING
    elseif input:isNewlyPressed(InputState.A_BUTTON) then
      self.state = BagScreen.TOSS_CONFIRM
    end
    return
  end

  if self.state == BagScreen.TOSS_CONFIRM then
    if input:isNewlyPressed(InputState.B_BUTTON) then
      self.state = BagScreen.BROWSING
      return
    end
    if input:isNewlyPressed(InputState.A_BUTTON) then
      -- Real Task_TossItem_Yes shows the "Threw away N ITEMs!" message;
      -- RemoveBagItem only actually runs once that message is dismissed
      -- (Task_WaitAB_RedrawAndReturnToBag) -- ported via
      -- self.pendingTossQuantity, applied in the MESSAGE-ack branch above.
      self.pendingTossQuantity = self.tossQuantity
      self:_setMessage(("Threw away %d item(s)!"):format(self.tossQuantity), BagScreen.BROWSING)
    end
    return
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
