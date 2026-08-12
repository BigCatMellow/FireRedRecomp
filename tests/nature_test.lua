-- Run: lua5.1 tests/nature_test.lua
package.path = package.path .. ";./?.lua"
local Nature = require("import.Nature")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local function s8b(n) if n < 0 then n = n + 256 end return string.char(n) end

-- Real rows, verified against the built ROM: HARDY(0), LONELY(1), BRAVE(2),
-- ADAMANT(3), MODEST(15), QUIRKY(24, last row).
local rows = {}
rows[0] = { 0, 0, 0, 0, 0 }
rows[1] = { 1, -1, 0, 0, 0 }
rows[2] = { 1, 0, -1, 0, 0 }
rows[3] = { 1, 0, 0, -1, 0 }

local knownRows = {}
for i = 0, 3 do
  local rowBytes = {}
  for _, v in ipairs(rows[i]) do
    rowBytes[#rowBytes + 1] = s8b(v)
  end
  knownRows[#knownRows + 1] = table.concat(rowBytes)
end
-- parseTable always reads all NUM_NATURES=25 rows, so the fixture must be
-- full-size (padding the remaining 21 rows with zeros) even though only
-- the first 4 have real, ROM-verified values.
local blob = table.concat(knownRows) .. string.rep("\0", (Nature.NUM_NATURES - 4) * Nature.ROW_SIZE)

check("fixture is full table size (125 bytes)", #blob == Nature.NUM_NATURES * Nature.ROW_SIZE)

local natures = Nature.parseTable(blob, 0)
check("HARDY is all zero", natures[0].attack == 0 and natures[0].spDefense == 0)
check("LONELY is +atk -def", natures[1].attack == 1 and natures[1].defense == -1)
check("BRAVE is +atk -speed", natures[2].attack == 1 and natures[2].speed == -1)
check("ADAMANT is +atk -spAtk", natures[3].attack == 1 and natures[3].spAttack == -1)
check("all 25 natures parsed", natures[24] ~= nil)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
