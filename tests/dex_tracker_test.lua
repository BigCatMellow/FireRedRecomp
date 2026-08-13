-- Run: lua5.1 tests/dex_tracker_test.lua
package.path = package.path .. ";./?.lua"
local DexTracker = require("src.core.DexTracker")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local dex = DexTracker.new()

check("nothing seen/owned initially", dex:isSeen(1) == false and dex:isOwned(1) == false)

dex:setSeen(1) -- Bulbasaur
check("Bulbasaur seen after setSeen", dex:isSeen(1) == true)
check("Bulbasaur still not owned", dex:isOwned(1) == false)

dex:setOwned(1)
check("Bulbasaur owned after setOwned", dex:isOwned(1) == true)

check("Charmander (4) unaffected", dex:isSeen(4) == false and dex:isOwned(4) == false)

-- Cross-byte-boundary check: dex# 8 is bit 7 of byte 0, dex# 9 is bit 0
-- of byte 1 (zero-based index = (n-1); n=8 -> zeroBased=7 -> byte0 bit7;
-- n=9 -> zeroBased=8 -> byte1 bit0), per the real
-- DexScreen_GetSetPokedexFlag formula.
dex:setSeen(8)
check("dex #8 seen (byte0 bit7)", dex:isSeen(8) == true)
check("dex #9 unaffected by #8", dex:isSeen(9) == false)
dex:setSeen(9)
check("dex #9 seen (byte1 bit0)", dex:isSeen(9) == true)
check("dex #8 still seen after #9 set", dex:isSeen(8) == true)

-- National dex #411 (last valid entry, NATIONAL_DEX_COUNT) is in range.
dex:setSeen(411)
check("last national dex entry (411) settable", dex:isSeen(411) == true)

local ok = pcall(function() dex:isSeen(0) end)
check("dex #0 out of range rejected", ok == false)
local ok2 = pcall(function() dex:isSeen(412) end)
check("dex #412 (past NATIONAL_DEX_COUNT) rejected", ok2 == false)

check("DEX_FLAGS_NO is 52", DexTracker.DEX_FLAGS_NO == 52)
check("NATIONAL_DEX_COUNT is 411", DexTracker.NATIONAL_DEX_COUNT == 411)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
