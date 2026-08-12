-- Run: lua5.1 tests/battle_move_test.lua
package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

check("record size is 12 (padded, not the struct's raw 9)", BattleMove.RECORD_SIZE == 12)

-- Pound, as it actually appears in the ROM (verified against real bytes):
-- effect=0, power=40, type=0(NORMAL), accuracy=100, pp=35, secEffChance=0,
-- target=0, priority=0, flags=0x33, then 3 zero pad bytes.
local pound = string.char(0x00, 0x28, 0x00, 0x64, 0x23, 0x00, 0x00, 0x00, 0x33, 0x00, 0x00, 0x00)
local parsed = BattleMove.parseRecord(pound)
check("effect", parsed.effect == 0, parsed.effect)
check("power", parsed.power == 40, parsed.power)
check("type", parsed.type == 0, parsed.type)
check("accuracy", parsed.accuracy == 100, parsed.accuracy)
check("pp", parsed.pp == 35, parsed.pp)
check("priority", parsed.priority == 0, parsed.priority)
check("flags", parsed.flags == 0x33, parsed.flags)

-- Negative priority (s8): 0xFA = -6, e.g. a move like Counter.
local negPriority = string.char(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFA, 0x00, 0x00, 0x00, 0x00)
check("negative priority decodes as signed", BattleMove.parseRecord(negPriority).priority == -6)

local blob = pound .. pound
local rows = BattleMove.parseTable(blob, 0, 2)
check("parseTable reads 2 rows", rows[0].power == 40 and rows[1].power == 40)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
