-- Unit test: verifies Rng's 32-bit LCG (ISO_RANDOMIZE1) against
-- independently-computed ground truth (arbitrary-precision Python, not
-- just self-consistency), including 32-bit wraparound.
-- Run: lua5.1 tests/rng_test.lua
package.path = package.path .. ";./?.lua"
local Rng = require("src.core.Rng")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- Ground truth computed independently in Python (arbitrary-precision
-- integers, not this module's own arithmetic):
--   seed=30840, v = (1103515245*v + 24691) % 2**32, output = v >> 16
-- giving state/output pairs:
--   v1=3384294283 r1=51640, v2=1578636450 r2=24088,
--   v3=2111210861 r3=32214, v4=3494667740 r4=53324, v5=2612578079 r5=39864
-- 30840 is the real seed the title screen's flame spawner uses
-- (TitleScreen_srand(taskId, 3, 30840), src/title_screen.c).
do
  local rng = Rng.new(30840)
  local expected = { 51640, 24088, 32214, 53324, 39864 }
  local expectedValue = { 3384294283, 1578636450, 2111210861, 3494667740, 2612578079 }
  for i, exp in ipairs(expected) do
    local r = rng:next16()
    check(("output %d matches ground truth"):format(i), r == exp, ("got %d want %d"):format(r, exp))
    check(("internal state %d matches ground truth"):format(i), rng.value == expectedValue[i], ("got %d want %d"):format(rng.value, expectedValue[i]))
  end
end

-- 32-bit wraparound: a seed near 2^32 must wrap correctly, not overflow
-- into float imprecision or produce a negative/out-of-range state.
do
  local seed = 4294967295 -- 2^32 - 1
  -- Ground truth (Python): (1103515245 * 4294967295 + 24691) % 2**32 = 3191476742
  local rng = Rng.new(seed)
  local r = rng:next16()
  check("wraparound near 2^32 produces the correct state", rng.value == 3191476742, rng.value)
  check("wraparound output is in range and correct", r == math.floor(3191476742 / 65536), r)
end

-- Different seeds produce different (independent) sequences -- sanity
-- check that state isn't shared/leaking between instances.
do
  local a = Rng.new(1)
  local b = Rng.new(2)
  check("independent instances don't share state", a:next16() ~= b:next16() or a.value ~= b.value)
end

-- Output is always a valid u16 (0-65535).
do
  local rng = Rng.new(12345)
  for i = 1, 50 do
    local r = rng:next16()
    check("output " .. i .. " is a valid u16", r >= 0 and r <= 65535, r)
  end
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
