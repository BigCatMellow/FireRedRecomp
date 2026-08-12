-- Run: lua5.1 tests/type_chart_test.lua
package.path = package.path .. ";./?.lua"
local TypeChart = require("import.TypeChart")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- Fire > Grass (super effective), Fire > Fire (not very effective), then ENDTABLE.
local FIRE, GRASS = 10, 12 -- placeholder values, only need to round-trip
local blob = string.char(
  FIRE, GRASS, TypeChart.MUL_SUPER_EFFECTIVE,
  FIRE, FIRE, TypeChart.MUL_NOT_EFFECTIVE,
  TypeChart.ENDTABLE, TypeChart.ENDTABLE, TypeChart.MUL_NO_EFFECT
)

local rows = TypeChart.parseTable(blob, 0)
check("stops at ENDTABLE, not past it", #rows + 1 == 2, #rows) -- rows is 0-indexed with 2 entries: rows[0], rows[1]
check("row 0 is Fire/Grass super effective", rows[0].attackingType == FIRE and rows[0].defendingType == GRASS and rows[0].multiplier == 20)
check("row 1 is Fire/Fire not very effective", rows[1].attackingType == FIRE and rows[1].defendingType == FIRE and rows[1].multiplier == 5)

local ok = pcall(TypeChart.parseTable, string.char(1, 2, 3), 0) -- no ENDTABLE, runs off the end
check("errors instead of reading past end when ENDTABLE is missing", ok == false)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
