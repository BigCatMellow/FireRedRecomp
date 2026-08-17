-- Real Poké Mart buy/sell transaction coverage. Pure Lua, no ROM needed.
-- Run: lua5.1 tests/pokemon_mart_test.lua
package.path = package.path .. ";./?.lua"

local Bag = require("src.core.Bag")
local PokemonMart = require("src.core.PokemonMart")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- ITEM_POKE_BALL(4)/ITEM_POTION(13) with representative price fixtures
-- (this test exercises the real buy/sell formulas, not a specific item's
-- exact real price -- see import/Item.lua for the real ROM-decoded field
-- this project's live callers would actually pass). Item 259 stands in
-- for a real price-0 (unsellable) key item, e.g. ITEM_TOWN_MAP.
local itemLookup = {
  [4] = { pocket = Bag.POCKET_POKE_BALLS, price = 200 },
  [13] = { pocket = Bag.POCKET_ITEMS, price = 300 },
  [259] = { pocket = Bag.POCKET_KEY_ITEMS, price = 0 },
}

do
  local bag = Bag.new(itemLookup)
  local newMoney = PokemonMart.buy(bag, 3000, 4, 5, itemLookup)
  check("buying 5 Poke Balls at 200 each costs exactly 1000", newMoney == 2000, newMoney)
  check("bought balls land in the bag", bag:quantityOf(4) == 5)
end

do
  local bag = Bag.new(itemLookup)
  local newMoney, reason = PokemonMart.buy(bag, 500, 13, 2, itemLookup)
  check("can't afford 2 Potions at 300 each (600 > 500)", newMoney == nil and reason ~= nil, reason)
  check("a failed purchase adds nothing to the bag", bag:quantityOf(13) == 0)
end

do
  -- A purchase that would exceed a stack's real 999 cap must fail and not
  -- silently take the player's money for nothing (Bag:addItem's own real
  -- MAX_STACK check surfaces through here).
  local bag = Bag.new(itemLookup)
  bag:addItem(4, 995)
  local newMoney, reason = PokemonMart.buy(bag, 999999, 4, 10, itemLookup)
  check("a purchase that would overflow the real 999 stack cap fails",
    newMoney == nil and reason ~= nil, reason)
  check("money is untouched by a failed purchase", bag:quantityOf(4) == 995)
end

do
  -- Real sell price: price/2 * quantity (floored once on the unit price).
  local bag = Bag.new(itemLookup)
  bag:addItem(13, 3)
  local newMoney = PokemonMart.sell(bag, 1000, 13, 2, itemLookup)
  check("selling 2 Potions at 300 each nets 150 each (floor(300/2))", newMoney == 1300, newMoney)
  check("sold items leave the bag", bag:quantityOf(13) == 1)
end

do
  local bag = Bag.new(itemLookup)
  local newMoney, reason = PokemonMart.sell(bag, 1000, 13, 1, itemLookup)
  check("can't sell an item you don't own", newMoney == nil and reason ~= nil, reason)
end

do
  -- Real price=0 items (key items) can never be sold, regardless of
  -- whether the player happens to own one.
  local bag = Bag.new(itemLookup)
  bag:addItem(259, 1)
  local newMoney, reason = PokemonMart.sell(bag, 1000, 259, 1, itemLookup)
  check("a real price-0 item cannot be sold", newMoney == nil and reason ~= nil, reason)
  check("an unsellable item stays in the bag", bag:quantityOf(259) == 1)
end

do
  -- Real MAX_MONEY (999999) caps a sale's proceeds.
  local bag = Bag.new(itemLookup)
  bag:addItem(13, 1)
  local newMoney = PokemonMart.sell(bag, 999999, 13, 1, itemLookup)
  check("selling near the real money cap clamps at MAX_MONEY, doesn't overflow", newMoney == 999999, newMoney)
end

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
