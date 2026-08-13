-- Run: lua5.1 tests/party_model_test.lua
package.path = package.path .. ";./?.lua"
local PartyModel = require("src.core.PartyModel")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local party = PartyModel.new()
check("new party is empty", party:size() == 0)
check("new party is not full", party:isFull() == false)
check("get on empty slot returns nil", party:get(1) == nil)

local slot1 = party:add({ name = "Bulbasaur" })
check("first add goes to slot 1", slot1 == 1, slot1)
check("size is 1", party:size() == 1)
check("get(1) returns the mon", party:get(1).name == "Bulbasaur")

for i = 2, 6 do
  local slot = party:add({ name = "Mon" .. i })
  check(("add #%d goes to slot %d"):format(i, i), slot == i, slot)
end
check("party is full at 6", party:isFull() == true)
check("size is 6", party:size() == 6)

local slot7, err = party:add({ name = "Overflow" })
check("add past 6 fails", slot7 == nil and err ~= nil, { slot7, err })
check("size unchanged after failed add", party:size() == 6)

-- removeAt shifts later slots down, no gaps.
local removed = party:removeAt(2)
check("removeAt returns the removed mon", removed.name == "Mon2")
check("size decreases", party:size() == 5)
check("slot 2 now holds what was slot 3", party:get(2).name == "Mon3")
check("last slot (6) is now empty", party:get(6) == nil)
check("not full after removal", party:isFull() == false)

check("removeAt out of range returns nil", party:removeAt(99) == nil)
check("removeAt 0 returns nil", party:removeAt(0) == nil)

-- iterate visits occupied slots in order.
local names = {}
for i, mon in party:iterate() do
  names[#names + 1] = mon.name
  check(("iterate index %d matches get(%d)"):format(i, i), mon == party:get(i))
end
check("iterate visited exactly size() mons", #names == party:size(), #names)
check("iterate order starts with Bulbasaur", names[1] == "Bulbasaur", names[1])

check("MAX_PARTY_SIZE is 6", PartyModel.MAX_PARTY_SIZE == 6)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
