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

-- 4. A on an item confirms it (real per-item context menu is out of
-- scope -- see header).
do
  local screen = BagScreen.new(newBag())
  tap(screen, InputState.buildMask({ DPAD_DOWN = true })) -- row 0 -> row 1 (Antidote)
  tap(screen, InputState.buildMask({ A_BUTTON = true }))
  check("A on an item confirms it", screen.state == BagScreen.CONFIRMED
    and screen.confirmedItemId == 14 and screen.confirmedPocket == Bag.POCKET_ITEMS)
  check("isDone true once confirmed", screen:isDone())
end

-- 5. A on the CLOSE row closes with no confirmed item.
do
  local screen = BagScreen.new(newBag())
  tap(screen, InputState.buildMask({ DPAD_UP = true })) -- wraps to CLOSE row
  check("Up from row 0 wraps to CLOSE", screen:isCancelRow(screen:cursorRow()))
  tap(screen, InputState.buildMask({ A_BUTTON = true }))
  check("A on CLOSE closes with no confirmed item", screen.state == BagScreen.CLOSED
    and screen.confirmedItemId == nil)
end

-- 6. B anywhere closes with no confirmed item.
do
  local screen = BagScreen.new(newBag())
  tap(screen, InputState.buildMask({ DPAD_DOWN = true }))
  tap(screen, InputState.buildMask({ B_BUTTON = true }))
  check("B closes with no confirmed item", screen.state == BagScreen.CLOSED
    and screen.confirmedItemId == nil)
end

-- 7. Once done, further input is inert.
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
