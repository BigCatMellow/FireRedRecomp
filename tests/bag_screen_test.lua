-- Pure BagScreen.lua state-machine coverage (no ROM needed -- a real
-- Bag.lua instance over a small synthetic itemLookup is enough).
-- Run: lua5.1 tests/bag_screen_test.lua
package.path = package.path .. ";./?.lua"

local BagScreen = require("src.core.BagScreen")
local Bag = require("src.core.Bag")
local InputState = require("src.core.InputState")

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
  end
end

local itemLookup = {
  [13] = { pocket = Bag.POCKET_ITEMS, price = 300 },   -- Potion
  [14] = { pocket = Bag.POCKET_ITEMS, price = 100 },   -- Antidote
  [265] = { pocket = Bag.POCKET_KEY_ITEMS, price = 0 }, -- arbitrary key item
  [4] = { pocket = Bag.POCKET_POKE_BALLS, price = 200 }, -- Poke Ball
}

local function tap(screen, buttonMask)
  local input = InputState.new()
  input:update(0)
  input:update(buttonMask)
  screen:processInput(input)
end

local function newBag()
  local bag = Bag.new(itemLookup)
  bag:addItem(13, 5)
  bag:addItem(14, 1)
  bag:addItem(265, 1)
  bag:addItem(4, 3)
  return bag
end

-- 1. Starts on the Items pocket, listing occupied slots + CLOSE row.
do
  local screen = BagScreen.new(newBag())
  check("starts on POCKET_ITEMS", screen:pocket() == Bag.POCKET_ITEMS)
  check("cursor sized to 2 items + CLOSE", screen.cursor.maxCursorPos == 2, screen.cursor.maxCursorPos)
  local rows = {}
  for row, isCancel, itemId, quantity in screen:iterateRows() do
    rows[#rows + 1] = { row = row, isCancel = isCancel, itemId = itemId, quantity = quantity }
  end
  check("iterateRows yields exactly 3 rows (2 items + CLOSE)", #rows == 3, #rows)
  check("row 1 is Potion x5", rows[1].itemId == 13 and rows[1].quantity == 5)
  check("row 2 is Antidote x1", rows[2].itemId == 14 and rows[2].quantity == 1)
  check("row 3 is the CLOSE row", rows[3].isCancel == true and rows[3].itemId == nil)
end

-- 2. LEFT/RIGHT cycles pockets in the real ITEMS -> KEY ITEMS -> POKE
-- BALLS order, clamped (not wrapped) at both ends.
do
  local screen = BagScreen.new(newBag())
  tap(screen, InputState.buildMask({ DPAD_LEFT = true }))
  check("LEFT from the first pocket does not wrap", screen:pocket() == Bag.POCKET_ITEMS)
  tap(screen, InputState.buildMask({ DPAD_RIGHT = true }))
  check("RIGHT moves to Key Items", screen:pocket() == Bag.POCKET_KEY_ITEMS)
  tap(screen, InputState.buildMask({ DPAD_RIGHT = true }))
  check("RIGHT again moves to Poke Balls", screen:pocket() == Bag.POCKET_POKE_BALLS)
  tap(screen, InputState.buildMask({ DPAD_RIGHT = true }))
  check("RIGHT from the last pocket does not wrap", screen:pocket() == Bag.POCKET_POKE_BALLS)
  check("switching pockets rebuilds the item list", #screen.items == 1 and screen.items[1].itemId == 4)
  tap(screen, InputState.buildMask({ DPAD_LEFT = true }))
  tap(screen, InputState.buildMask({ DPAD_LEFT = true }))
  check("LEFT twice returns to Items", screen:pocket() == Bag.POCKET_ITEMS)
end

-- 3. Switching pockets resets the cursor to row 0 (documented
-- simplification -- see BagScreen.lua's header).
do
  local screen = BagScreen.new(newBag())
  tap(screen, InputState.buildMask({ DPAD_DOWN = true }))
  check("cursor moved off row 0", screen:cursorRow() == 1)
  tap(screen, InputState.buildMask({ DPAD_RIGHT = true }))
  check("switching pockets resets the cursor to row 0", screen:cursorRow() == 0)
end

-- 4. A on an item opens the real per-pocket context menu.
do
  local screen = BagScreen.new(newBag())
  tap(screen, InputState.buildMask({ DPAD_DOWN = true })) -- row 0 -> row 1 (Antidote)
  tap(screen, InputState.buildMask({ A_BUTTON = true }))
  check("A on an item opens the context menu", screen.state == BagScreen.CONTEXT_MENU
    and screen.selectedItemId == 14)
  check("Items pocket offers the real USE/GIVE/TOSS/CANCEL action list",
    #screen:contextActions() == 4 and screen:contextActions()[3] == "TOSS")
  check("not done while the context menu is open", not screen:isDone())
end

-- 5. Poke Balls pocket omits USE (real sContextMenuItems_Field[2]).
do
  local screen = BagScreen.new(newBag())
  tap(screen, InputState.buildMask({ DPAD_RIGHT = true }))
  tap(screen, InputState.buildMask({ DPAD_RIGHT = true })) -- Poke Balls pocket
  tap(screen, InputState.buildMask({ A_BUTTON = true }))
  local actions = screen:contextActions()
  local hasUse = false
  for _, a in ipairs(actions) do if a == "USE" then hasUse = true end end
  check("Poke Balls pocket context menu has no USE action", not hasUse)
end

-- 6. USE/GIVE are bounded stubs: a message, then back to browsing.
do
  local screen = BagScreen.new(newBag())
  tap(screen, InputState.buildMask({ A_BUTTON = true })) -- select Potion
  tap(screen, InputState.buildMask({ A_BUTTON = true })) -- USE (first action)
  check("USE shows a bounded not-available message", screen.state == BagScreen.MESSAGE
    and screen.message:find("not available", 1, true) ~= nil, screen.message)
  tap(screen, InputState.buildMask({ A_BUTTON = true }))
  check("acknowledging returns to browsing", screen.state == BagScreen.BROWSING)
end

-- 7. B at the context menu returns to browsing (not closed).
do
  local screen = BagScreen.new(newBag())
  tap(screen, InputState.buildMask({ A_BUTTON = true }))
  tap(screen, InputState.buildMask({ B_BUTTON = true }))
  check("B at the context menu returns to browsing", screen.state == BagScreen.BROWSING)
  check("not done", not screen:isDone())
end

-- 8. Full real TOSS flow: quantity dialog -> confirm -> message ->
-- RemoveBagItem only happens once the message is dismissed.
do
  local screen = BagScreen.new(newBag()) -- Potion x5
  tap(screen, InputState.buildMask({ A_BUTTON = true })) -- select Potion, opens context menu
  tap(screen, InputState.buildMask({ DPAD_DOWN = true })) -- USE -> GIVE
  tap(screen, InputState.buildMask({ DPAD_DOWN = true })) -- GIVE -> TOSS
  tap(screen, InputState.buildMask({ A_BUTTON = true })) -- confirm TOSS
  check("TOSS on a >1 stack opens the quantity dialog",
    screen.state == BagScreen.TOSS_QUANTITY and screen.tossMaxQuantity == 5, screen.state)
  tap(screen, InputState.buildMask({ DPAD_UP = true })) -- quantity = 2
  tap(screen, InputState.buildMask({ A_BUTTON = true })) -- -> confirm
  check("A in the toss quantity dialog opens the real Yes/No confirm",
    screen.state == BagScreen.TOSS_CONFIRM and screen.tossQuantity == 2)
  tap(screen, InputState.buildMask({ A_BUTTON = true })) -- yes
  check("confirming shows the real 'Threw away' message, without removing yet",
    screen.state == BagScreen.MESSAGE and screen.bag:quantityOf(13) == 5, screen.bag:quantityOf(13))
  tap(screen, InputState.buildMask({ A_BUTTON = true })) -- acknowledge
  check("RemoveBagItem only runs once the message is dismissed (real Task_WaitAB_RedrawAndReturnToBag)",
    screen.bag:quantityOf(13) == 3, screen.bag:quantityOf(13))
  check("returns to browsing afterward", screen.state == BagScreen.BROWSING)
end

-- 9. Owning exactly 1 of an item skips the quantity dialog (real
-- data[2] == 1 branch).
do
  local screen = BagScreen.new(newBag()) -- Antidote x1
  tap(screen, InputState.buildMask({ DPAD_DOWN = true })) -- row 0 -> Antidote
  tap(screen, InputState.buildMask({ A_BUTTON = true })) -- context menu
  tap(screen, InputState.buildMask({ DPAD_DOWN = true })) -- USE -> GIVE
  tap(screen, InputState.buildMask({ DPAD_DOWN = true })) -- GIVE -> TOSS
  tap(screen, InputState.buildMask({ A_BUTTON = true })) -- confirm TOSS
  check("a single-copy item skips straight to the Yes/No confirm",
    screen.state == BagScreen.TOSS_CONFIRM and screen.tossQuantity == 1, screen.state)
  tap(screen, InputState.buildMask({ A_BUTTON = true }))
  tap(screen, InputState.buildMask({ A_BUTTON = true }))
  check("tossing the last copy removes it from the bag entirely", screen.bag:quantityOf(14) == 0)
  check("the item disappears from the rebuilt list", #screen.items == 1 and screen.items[1].itemId == 13)
end

-- 10. B at the toss quantity dialog returns straight to browsing (real
-- Task_SelectQuantityToToss's B -- not back to the context menu).
do
  local screen = BagScreen.new(newBag())
  tap(screen, InputState.buildMask({ A_BUTTON = true }))
  tap(screen, InputState.buildMask({ DPAD_DOWN = true }))
  tap(screen, InputState.buildMask({ DPAD_DOWN = true }))
  tap(screen, InputState.buildMask({ A_BUTTON = true })) -- TOSS -> quantity dialog
  tap(screen, InputState.buildMask({ B_BUTTON = true }))
  check("B at the quantity dialog returns to browsing", screen.state == BagScreen.BROWSING)
  check("nothing was removed", screen.bag:quantityOf(13) == 5)
end

-- 11. B at the Yes/No confirm cancels the toss, nothing removed.
do
  local screen = BagScreen.new(newBag())
  tap(screen, InputState.buildMask({ DPAD_DOWN = true }))
  tap(screen, InputState.buildMask({ A_BUTTON = true })) -- select Antidote (qty 1)
  tap(screen, InputState.buildMask({ DPAD_DOWN = true }))
  tap(screen, InputState.buildMask({ DPAD_DOWN = true }))
  tap(screen, InputState.buildMask({ A_BUTTON = true })) -- TOSS -> straight to confirm
  tap(screen, InputState.buildMask({ B_BUTTON = true })) -- no
  check("B at the toss confirm cancels back to browsing", screen.state == BagScreen.BROWSING)
  check("nothing was removed", screen.bag:quantityOf(14) == 1)
end

-- 12. B on the item list closes the whole Bag screen.
do
  local screen = BagScreen.new(newBag())
  tap(screen, InputState.buildMask({ DPAD_DOWN = true }))
  tap(screen, InputState.buildMask({ B_BUTTON = true }))
  check("B closes the Bag screen", screen.state == BagScreen.CLOSED and screen:isDone())
end

-- 13. Once done, further input is inert.
do
  local screen = BagScreen.new(newBag())
  tap(screen, InputState.buildMask({ B_BUTTON = true }))
  tap(screen, InputState.buildMask({ DPAD_DOWN = true }))
  check("processInput after CLOSED does nothing further", screen:cursorRow() == 0)
end

-- 8. An empty pocket still has a working CLOSE row (0 items + CLOSE).
do
  local bag = Bag.new(itemLookup)
  bag:addItem(4, 1) -- only Poke Balls pocket has anything
  local screen = BagScreen.new(bag)
  check("empty Items pocket has 0 items + CLOSE", screen.cursor.maxCursorPos == 0)
  local rows = {}
  for row, isCancel in screen:iterateRows() do rows[#rows + 1] = isCancel end
  check("iterateRows yields exactly the CLOSE row", #rows == 1 and rows[1] == true)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
