-- Run: lua5.1 tests/pointer_string_table_test.lua
package.path = package.path .. ";./?.lua"
local PointerStringTable = require("import.PointerStringTable")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local romBase = PointerStringTable.romBase
local function u32le(n)
  return string.char(n % 256, math.floor(n / 256) % 256, math.floor(n / 65536) % 256, math.floor(n / 16777216) % 256)
end

-- "STENCH" in charmap bytes (verified real values), terminated with 0xFF.
local stenchStr = string.char(0xcd, 0xce, 0xbf, 0xc8, 0xbd, 0xc2, 0xff)

-- Pointer table: index 0 -> NULL, index 1 -> the string above.
local table_ = u32le(0) .. u32le(romBase + 0x100)
local rom = table_ .. string.rep("\0", 0x100 - #table_) .. stenchStr

check("index 0 (NULL pointer) resolves to nil", PointerStringTable.resolveAt(rom, 0, 0, 60) == nil)
check("index 1 resolves and decodes to STENCH", PointerStringTable.resolveAt(rom, 0, 1, 60) == "STENCH")

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
