-- Run: lua5.1 tests/money_test.lua
package.path = package.path .. ";./?.lua"
local Money = require("src.core.Money")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local m = Money.new()
check("starts at 0", m:get() == 0)

m:add(3000)
check("add increases balance", m:get() == 3000)

check("isEnough true under balance", m:isEnough(3000) == true)
check("isEnough false over balance", m:isEnough(3001) == false)

m:subtract(1000)
check("subtract decreases balance", m:get() == 2000)

m:subtract(999999999)
check("subtract floors at 0", m:get() == 0)

local m2 = Money.new(999000)
m2:add(5000)
check("add clamps at MAX_MONEY", m2:get() == Money.MAX_MONEY)
check("MAX_MONEY is 999999", Money.MAX_MONEY == 999999)

local m3 = Money.new(500000)
m3:add(500000)
check("add exactly at boundary sums normally or clamps, never exceeds cap", m3:get() <= Money.MAX_MONEY)
check("500000+500000 clamps to MAX_MONEY (would be 1000000)", m3:get() == Money.MAX_MONEY)

local m4 = Money.new()
m4:add(999999)
check("add up to exactly MAX_MONEY allowed", m4:get() == 999999)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
