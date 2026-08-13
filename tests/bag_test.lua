-- Run: lua5.1 tests/bag_test.lua
package.path = package.path .. ";./?.lua"
local Bag = require("src.core.Bag")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- Minimal itemId -> pocket lookup, shaped like import/Item.lua's
-- Item.parseTable() output (real itemId 1 = ITEM_MASTER_BALL, real
-- pocket 3 = POCKET_POKE_BALLS, per Item.lua's own header comment).
local itemLookup = {
  [1] = { pocket = Bag.POCKET_POKE_BALLS },  -- Master Ball
  [13] = { pocket = Bag.POCKET_ITEMS },      -- Potion (ITEM_POTION)
  [259] = { pocket = Bag.POCKET_KEY_ITEMS }, -- an arbitrary key item id
  [328] = { pocket = Bag.POCKET_TM_CASE },   -- an arbitrary TM id
  [149] = { pocket = Bag.POCKET_BERRY_POUCH }, -- an arbitrary berry id
}

check("pocket capacities match real BAG_*_COUNT constants",
  Bag.POCKET_CAPACITY[Bag.POCKET_ITEMS] == 42
  and Bag.POCKET_CAPACITY[Bag.POCKET_KEY_ITEMS] == 30
  and Bag.POCKET_CAPACITY[Bag.POCKET_POKE_BALLS] == 13
  and Bag.POCKET_CAPACITY[Bag.POCKET_TM_CASE] == 58
  and Bag.POCKET_CAPACITY[Bag.POCKET_BERRY_POUCH] == 43)
check("MAX_STACK is 999", Bag.MAX_STACK == 999)

local bag = Bag.new(itemLookup)
check("quantity 0 for unowned item", bag:quantityOf(13) == 0)

local ok = bag:addItem(13, 5)
check("addItem succeeds", ok == true)
check("quantity reflects add", bag:quantityOf(13) == 5)

bag:addItem(13, 3)
check("second add stacks onto existing slot", bag:quantityOf(13) == 8)

local rok = bag:removeItem(13, 8)
check("removeItem succeeds and empties the stack", rok == true and bag:quantityOf(13) == 0)

local rfail, err = bag:removeItem(13, 1)
check("removeItem fails on empty stack", rfail == false and err ~= nil)

-- Stack cap.
bag:addItem(13, 999)
local capFail, capErr = bag:addItem(13, 1)
check("addItem rejects exceeding MAX_STACK", capFail == false and capErr ~= nil)
check("quantity unchanged after rejected overflow add", bag:quantityOf(13) == 999)

-- Pocket-full behavior: Poké Balls pocket capacity is 13.
local ballsBag = Bag.new(itemLookup)
for i = 1, 13 do
  -- Fake distinct item ids all mapped to POCKET_POKE_BALLS to force
  -- 13 distinct slots (real pockets are per-slot, not per-itemId).
  itemLookup[1000 + i] = { pocket = Bag.POCKET_POKE_BALLS }
  local addOk = ballsBag:addItem(1000 + i, 1)
  check(("Poke Ball pocket slot %d fills"):format(i), addOk == true)
end
local overflowOk, overflowErr = ballsBag:addItem(1, 1)
check("Poke Ball pocket rejects a 14th distinct item (capacity 13)", overflowOk == false and overflowErr ~= nil)

-- Pockets are independent: filling POCKET_POKE_BALLS doesn't affect POCKET_ITEMS.
check("POCKET_ITEMS untouched by POCKET_POKE_BALLS fill", ballsBag:quantityOf(13) == 0)

-- iteratePocket visits occupied slots.
local iterBag = Bag.new(itemLookup)
iterBag:addItem(13, 5)
iterBag:addItem(1, 2)
local visited = {}
for i, itemId, quantity in iterBag:iteratePocket(Bag.POCKET_ITEMS) do
  visited[#visited + 1] = { i = i, itemId = itemId, quantity = quantity }
end
check("iteratePocket finds the one item added to POCKET_ITEMS", #visited == 1, #visited)
check("iteratePocket reports correct itemId/quantity", visited[1] and visited[1].itemId == 13 and visited[1].quantity == 5)

local unknownOk = pcall(function() iterBag:addItem(99999, 1) end)
check("unknown itemId rejected", unknownOk == false)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
