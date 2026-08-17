-- Real Poke Mart BUY flow state machine coverage. Pure Lua, no ROM needed.
-- Run: lua5.1 tests/pokemon_mart_menu_test.lua
package.path = package.path .. ";./?.lua"

local Bag = require("src.core.Bag")
local InputState = require("src.core.InputState")
local PokemonMartMenu = require("src.core.PokemonMartMenu")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local function input(button)
  return { isNewlyPressed = function(_, b) return b == button end,
           isPressedOrRepeated = function(_, b) return b == button end }
end
local noInput = input(-1)

local itemLookup = {
  [4] = { pocket = Bag.POCKET_POKE_BALLS, price = 200 },  -- ITEM_POKE_BALL
  [13] = { pocket = Bag.POCKET_ITEMS, price = 300 },      -- ITEM_POTION
}

local function newMenu(money)
  return PokemonMartMenu.new({
    itemIds = { 4, 13 }, itemLookup = itemLookup, bag = Bag.new(itemLookup), money = money or 3000,
  })
end

-- Real Task_ShopMenu: Buy/Sell/Quit. Every test below that exercises the
-- BUY flow enters it explicitly first.
local function enterBuy(m)
  m:processInput(input(InputState.A_BUTTON)) -- topCursor 0 = Buy
  return m
end

do
  local m = newMenu()
  check("starts on the real top BUY/SELL/QUIT menu", m.state == PokemonMartMenu.TOPMENU
    and m.topCursor == 0)
  m:processInput(input(InputState.DPAD_DOWN))
  check("Down moves to Sell", m.topCursor == 1)
  m:processInput(input(InputState.DPAD_DOWN))
  check("Down moves to Quit", m.topCursor == 2)
  m:processInput(input(InputState.DPAD_DOWN))
  check("Down does not run past Quit", m.topCursor == 2)
  m:processInput(input(InputState.DPAD_UP))
  m:processInput(input(InputState.DPAD_UP))
  check("Up moves back to Buy", m.topCursor == 0)
end

do
  local m = newMenu()
  enterBuy(m)
  check("choosing Buy opens the item list at the first item", m.state == PokemonMartMenu.LIST
    and m:currentItemId() == 4)
  m:processInput(input(InputState.DPAD_DOWN))
  check("Down moves to the next real item", m:currentItemId() == 13)
  m:processInput(input(InputState.DPAD_DOWN))
  check("Down does not run past the real end of the list", m:currentItemId() == 13)
  m:processInput(input(InputState.DPAD_UP))
  check("Up moves back", m:currentItemId() == 4)
  m:processInput(input(InputState.B_BUTTON))
  check("B at the buy list returns to the real top shop menu, not straight out",
    m.state == PokemonMartMenu.TOPMENU)
end

do
  -- Real Task_BuyHowManyDialogueInit: maxQuantity = min(99, money/price).
  local m = enterBuy(newMenu(1000)) -- 1000 / 200 = 5
  m:processInput(input(InputState.A_BUTTON))
  check("A on an affordable item opens the real quantity dialog",
    m.state == PokemonMartMenu.QUANTITY and m.quantity == 1 and m.maxQuantity == 5, m.maxQuantity)
end

do
  local m = enterBuy(newMenu(150)) -- less than a single Poke Ball's real 200 price
  m:processInput(input(InputState.A_BUTTON))
  check("an unaffordable item shows the real not-enough-money message, not the quantity dialog",
    m.state == PokemonMartMenu.MESSAGE and m.message:find("enough money", 1, true) ~= nil, m.message)
  m:processInput(input(InputState.A_BUTTON))
  check("acknowledging returns to the list", m.state == PokemonMartMenu.LIST)
end

do
  -- Real AdjustQuantityAccordingToDPadInput stepping (src/menu_helpers.c):
  -- Up +1 wraps 1 at the top, Down -1 wraps to max, Right +10 clamps at
  -- max (no wrap), Left -10 floors at 1 (no wrap to 0).
  local m = enterBuy(newMenu(99000)) -- affords the real 99-unit cap
  m:processInput(input(InputState.A_BUTTON))
  check("maxQuantity is capped at the real 99, even with more money than that would need",
    m.maxQuantity == 99, m.maxQuantity)
  m:processInput(input(InputState.DPAD_RIGHT))
  check("Right steps by +10", m.quantity == 11, m.quantity)
  m:processInput(input(InputState.DPAD_LEFT))
  check("Left steps by -10", m.quantity == 1, m.quantity)
  m:processInput(input(InputState.DPAD_LEFT))
  check("Left floors at 1, does not wrap to 0 or negative", m.quantity == 1, m.quantity)
  m:processInput(input(InputState.DPAD_DOWN))
  check("Down from 1 wraps to the real max", m.quantity == 99, m.quantity)
  m:processInput(input(InputState.DPAD_UP))
  check("Up from max wraps back to 1", m.quantity == 1, m.quantity)
  m:processInput(input(InputState.DPAD_RIGHT))
  m.quantity = 95
  m:processInput(input(InputState.DPAD_RIGHT))
  check("Right clamps at max instead of overshooting", m.quantity == 99, m.quantity)
end

do
  -- Full real purchase flow: list -> quantity -> confirm -> Bag/money
  -- actually change, matching PokemonMart.buy's already-tested formula.
  local m = enterBuy(newMenu(1000))
  m:processInput(input(InputState.A_BUTTON)) -- open quantity dialog for Poke Ball
  m:processInput(input(InputState.DPAD_UP)) -- quantity = 2
  m:processInput(input(InputState.A_BUTTON)) -- -> confirm
  check("A in the quantity dialog opens the real confirm step", m.state == PokemonMartMenu.CONFIRM)
  m:processInput(input(InputState.A_BUTTON)) -- confirm yes
  check("confirming actually buys through PokemonMart/Bag",
    m.bag:quantityOf(4) == 2 and m.money == 600, m.money)
  check("a successful purchase shows the real thank-you message",
    m.state == PokemonMartMenu.MESSAGE and m.message:find("Thank you", 1, true) ~= nil, m.message)
  m:processInput(input(InputState.A_BUTTON))
  check("returns to the list afterward (real \"Will that be all?\" loop)", m.state == PokemonMartMenu.LIST)
end

do
  -- B at the confirm step cancels without spending money (real path).
  local m = enterBuy(newMenu(1000))
  m:processInput(input(InputState.A_BUTTON))
  m:processInput(input(InputState.A_BUTTON))
  m:processInput(input(InputState.B_BUTTON))
  check("B at confirm cancels back to the list, no money spent",
    m.state == PokemonMartMenu.LIST and m.money == 1000 and m.bag:quantityOf(4) == 0)
end

do
  -- Real BuyMenuTryMakePurchase: a bag with no room fails the purchase
  -- and does NOT deduct money, even after confirming.
  local m = enterBuy(newMenu(100000))
  local bag = m.bag
  for i = 1, Bag.POCKET_CAPACITY[Bag.POCKET_POKE_BALLS] do
    itemLookup[9000 + i] = { pocket = Bag.POCKET_POKE_BALLS, price = 1 }
    bag:addItem(9000 + i, 1) -- fill every slot with distinct filler item ids
  end
  m:processInput(input(InputState.A_BUTTON)) -- Poke Ball quantity dialog
  m:processInput(input(InputState.A_BUTTON)) -- confirm
  m:processInput(input(InputState.A_BUTTON)) -- yes
  check("a full bag fails the purchase with the real no-room message",
    m.state == PokemonMartMenu.MESSAGE and m.message:find("no more room", 1, true) ~= nil, m.message)
  check("a failed purchase never deducts money", m.money == 100000, m.money)
end

do
  local m = newMenu()
  m:processInput(input(InputState.DPAD_DOWN))
  m:processInput(input(InputState.DPAD_DOWN))
  check("Quit is the 3rd top-menu option", m.topCursor == 2)
  m:processInput(input(InputState.A_BUTTON))
  check("choosing Quit leaves the mart", m:isDone())
  m:processInput(noInput)
  check("no input after leaving does not resurrect the menu", m:isDone())
end

do
  local m = newMenu()
  m:processInput(input(InputState.B_BUTTON))
  check("B at the real top shop menu also leaves the mart", m:isDone())
end

-- Real SELL flow: Task_ItemContext_Sell/Task_SelectQuantityToSell/
-- Task_SellItem_Yes, ported over PokemonMart.sell (see PokemonMartMenu's
-- own header for the documented simplification vs. the real general Bag
-- UI this reuses this module's own list/quantity/confirm machinery
-- instead of).
local function enterSell(m)
  m:processInput(input(InputState.DPAD_DOWN)) -- topCursor 1 = Sell
  m:processInput(input(InputState.A_BUTTON))
  return m
end

do
  local m = newMenu(1000)
  m.bag:addItem(13, 5) -- 5 Potions, real price 300 -> sell 150 each
  local n = enterSell(m)
  check("Sell opens a real sell list sourced from the bag's own contents",
    n.state == PokemonMartMenu.LIST and n.transactionType == "sell"
      and #n.itemIds == 1 and n.itemIds[1] == 13, n.itemIds[1])
end

do
  -- Real Task_ItemContext_Sell: maxQuantity = min(99, quantityOwned), not
  -- money-based like buying.
  local m = newMenu(0)
  m.bag:addItem(13, 5)
  local n = enterSell(m)
  n:processInput(input(InputState.A_BUTTON)) -- select the only sellable item
  check("sell maxQuantity is capped at the real quantity owned, not money",
    n.state == PokemonMartMenu.QUANTITY and n.maxQuantity == 5, n.maxQuantity)
end

do
  -- Real data[2] == 1 branch: owning exactly one copy skips the quantity
  -- dialog and goes straight to sale confirmation.
  local m = newMenu(0)
  m.bag:addItem(13, 1)
  local n = enterSell(m)
  n:processInput(input(InputState.A_BUTTON))
  check("a single-copy item skips the quantity dialog entirely",
    n.state == PokemonMartMenu.CONFIRM and n.quantity == 1, n.state)
end

do
  -- Full real sell flow: list -> quantity -> confirm -> Bag/money change,
  -- matching PokemonMart.sell's already-tested floor(price/2) formula.
  local m = newMenu(0)
  m.bag:addItem(13, 5)
  local n = enterSell(m)
  n:processInput(input(InputState.A_BUTTON)) -- select Potion, quantity dialog
  n:processInput(input(InputState.DPAD_UP)) -- quantity = 2
  n:processInput(input(InputState.A_BUTTON)) -- -> confirm
  n:processInput(input(InputState.A_BUTTON)) -- confirm yes
  check("confirming actually sells through PokemonMart/Bag",
    n.bag:quantityOf(13) == 3 and n.money == 300, n.money) -- floor(300/2)*2 = 300
  check("a successful sale shows a sale-confirmation message",
    n.state == PokemonMartMenu.MESSAGE, n.state)
  n:processInput(input(InputState.A_BUTTON)) -- acknowledge
  check("acknowledging returns to the (now-updated) sell list",
    n.state == PokemonMartMenu.LIST and #n.itemIds == 1 and n.itemIds[1] == 13)
end

do
  -- Selling the entire stack removes the item from the sell list (real
  -- Task_FinalizeSaleToShop rebuilds the bag ListMenu from its now-
  -- changed contents).
  local m = newMenu(0)
  m.bag:addItem(13, 1)
  local n = enterSell(m)
  n:processInput(input(InputState.A_BUTTON)) -- single copy -> straight to confirm
  n:processInput(input(InputState.A_BUTTON)) -- confirm yes
  n:processInput(input(InputState.A_BUTTON)) -- acknowledge sale message
  check("selling the last copy empties the sell list",
    n.state == PokemonMartMenu.LIST and #n.itemIds == 0, #n.itemIds)
end

do
  -- Key items and any other price-0 item are real-unsellable and never
  -- even appear in the sell list (ItemId_GetPrice(id) == 0 filtering).
  local m = newMenu(0)
  itemLookup[999] = { pocket = Bag.POCKET_ITEMS, price = 0 }
  m.bag:addItem(999, 1)
  local n = enterSell(m)
  check("a price-0 item is filtered out of the real sell list",
    #n.itemIds == 0, #n.itemIds)
end

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
