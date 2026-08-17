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

do
  local m = newMenu()
  check("starts on the item list at the first item", m.state == PokemonMartMenu.LIST
    and m:currentItemId() == 4)
  m:processInput(input(InputState.DPAD_DOWN))
  check("Down moves to the next real item", m:currentItemId() == 13)
  m:processInput(input(InputState.DPAD_DOWN))
  check("Down does not run past the real end of the list", m:currentItemId() == 13)
  m:processInput(input(InputState.DPAD_UP))
  check("Up moves back", m:currentItemId() == 4)
end

do
  -- Real Task_BuyHowManyDialogueInit: maxQuantity = min(99, money/price).
  local m = newMenu(1000) -- 1000 / 200 = 5
  m:processInput(input(InputState.A_BUTTON))
  check("A on an affordable item opens the real quantity dialog",
    m.state == PokemonMartMenu.QUANTITY and m.quantity == 1 and m.maxQuantity == 5, m.maxQuantity)
end

do
  local m = newMenu(150) -- less than a single Poke Ball's real 200 price
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
  local m = newMenu(99000) -- affords the real 99-unit cap
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
  local m = newMenu(1000)
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
  local m = newMenu(1000)
  m:processInput(input(InputState.A_BUTTON))
  m:processInput(input(InputState.A_BUTTON))
  m:processInput(input(InputState.B_BUTTON))
  check("B at confirm cancels back to the list, no money spent",
    m.state == PokemonMartMenu.LIST and m.money == 1000 and m.bag:quantityOf(4) == 0)
end

do
  -- Real BuyMenuTryMakePurchase: a bag with no room fails the purchase
  -- and does NOT deduct money, even after confirming.
  local m = newMenu(100000)
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
  m:processInput(input(InputState.B_BUTTON))
  check("B at the item list leaves the mart", m:isDone())
  m:processInput(noInput)
  check("no input after leaving does not resurrect the menu", m:isDone())
end

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
