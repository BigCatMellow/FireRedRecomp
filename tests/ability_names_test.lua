-- Run: lua5.1 tests/ability_names_test.lua
package.path = package.path .. ";./?.lua"
local AbilityNames = require("import.AbilityNames")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- Real bytes for ABILITY_NONE (index 0, "-------" placeholder) and
-- ABILITY_STENCH (index 1), verified against the built ROM.
local none = string.char(0xae, 0xae, 0xae, 0xae, 0xae, 0xae, 0xae, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00)
local stench = string.char(0xcd, 0xce, 0xbf, 0xc8, 0xbd, 0xc2, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
local blob = none .. stench

check("record size is 13", AbilityNames.RECORD_SIZE == 13)

local rawNone = AbilityNames.rawNameRecord(blob, 0, 0)
check("ABILITY_NONE trims at terminator (7 bytes)", #rawNone == 7, #rawNone)

local rawStench = AbilityNames.rawNameRecord(blob, 0, 1)
check("ABILITY_STENCH trims at terminator (6 bytes)", #rawStench == 6, #rawStench)
check("ABILITY_STENCH bytes match", rawStench == string.char(0xcd, 0xce, 0xbf, 0xc8, 0xbd, 0xc2))

local rows = AbilityNames.parseTable(blob, 0, 2)
check("parseTable returns both", #rows[0] == 7 and #rows[1] == 6)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
