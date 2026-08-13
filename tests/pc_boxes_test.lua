-- Run: lua5.1 tests/pc_boxes_test.lua
package.path = package.path .. ";./?.lua"
local PcBoxes = require("src.core.PcBoxes")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

check("TOTAL_BOXES_COUNT is 14", PcBoxes.TOTAL_BOXES_COUNT == 14)
check("IN_BOX_COUNT is 30", PcBoxes.IN_BOX_COUNT == 30)

local pc = PcBoxes.new()
check("box 1 not full initially", pc:isFull(1) == false)
check("get on empty slot returns nil", pc:get(1, 1) == nil)

local slot1 = pc:add(1, { species = 1 }) -- Bulbasaur
check("first add goes to slot 1", slot1 == 1, slot1)
check("get(1,1) returns the mon", pc:get(1, 1).species == 1)

-- Fill box 1 completely.
for i = 2, 30 do
  local slot = pc:add(1, { species = i })
  check(("add #%d goes to slot %d"):format(i, i), slot == i, slot)
end
check("box 1 full at 30", pc:isFull(1) == true)

local slot31, err = pc:add(1, { species = 999 })
check("add past 30 fails", slot31 == nil and err ~= nil, { slot31, err })

-- Box 2 is independent of box 1.
check("box 2 starts empty", pc:isFull(2) == false and pc:get(2, 1) == nil)
pc:add(2, { species = 4 })
check("box 2 slot 1 filled independently", pc:get(2, 1).species == 4)
check("box 1 unaffected by box 2 add", pc:get(1, 1).species == 1)

-- removeAt leaves a hole (no compaction), unlike PartyModel.
local removed = pc:removeAt(1, 2)
check("removeAt returns removed mon", removed.species == 2)
check("removed slot now nil (hole, no shift)", pc:get(1, 2) == nil)
check("slot 3 unaffected by removal of slot 2", pc:get(1, 3).species == 3)
check("box 1 no longer full after removal", pc:isFull(1) == false)

check("removeAt out of range returns nil", pc:removeAt(1, 999) == nil)

local ok = pcall(function() pc:get(0, 1) end)
check("box 0 out of range rejected", ok == false)
local ok2 = pcall(function() pc:get(15, 1) end)
check("box 15 (past TOTAL_BOXES_COUNT) rejected", ok2 == false)

-- iterate skips the hole left by removeAt.
local seen = {}
for i, mon in pc:iterate(1) do
  seen[#seen + 1] = i
end
check("iterate skips hole at slot 2", (function()
  for _, i in ipairs(seen) do
    if i == 2 then return false end
  end
  return true
end)())
check("iterate visits 29 remaining mons in box 1", #seen == 29, #seen)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
