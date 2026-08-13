-- Run: lua5.1 tests/experience_table_test.lua
package.path = package.path .. ";./?.lua"
local ExperienceTable = require("src.core.ExperienceTable")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- Real, documented level-100 totals (pokefirered
-- src/data/pokemon/experience_tables.h, and well-known Pokémon growth
-- rate totals): MediumFast = 100^3 = 1,000,000. Fast = 4*100^3/5 =
-- 800,000. Slow = 5*100^3/4 = 1,250,000. MediumSlow (Bulbasaur's real
-- growth rate) = 6*100^3/5 - 15*100^2 + 100*100 - 140 = 1,059,860.
check("MediumFast level 100 = 1,000,000",
  ExperienceTable.expForLevel(ExperienceTable.GROWTH_MEDIUM_FAST, 100) == 1000000)
check("Fast level 100 = 800,000",
  ExperienceTable.expForLevel(ExperienceTable.GROWTH_FAST, 100) == 800000)
check("Slow level 100 = 1,250,000",
  ExperienceTable.expForLevel(ExperienceTable.GROWTH_SLOW, 100) == 1250000)
check("MediumSlow (Bulbasaur) level 100 = 1,059,860",
  ExperienceTable.expForLevel(ExperienceTable.GROWTH_MEDIUM_SLOW, 100) == 1059860)

-- Level 1 is always exp 1 for every growth rate (real table's row[1]
-- literal, not formula(1)).
for _, gr in ipairs({
  ExperienceTable.GROWTH_MEDIUM_FAST, ExperienceTable.GROWTH_ERRATIC,
  ExperienceTable.GROWTH_FLUCTUATING, ExperienceTable.GROWTH_MEDIUM_SLOW,
  ExperienceTable.GROWTH_FAST, ExperienceTable.GROWTH_SLOW,
}) do
  check(("growth rate %d: level 1 = exp 1"):format(gr), ExperienceTable.expForLevel(gr, 1) == 1, gr)
end

-- Erratic's real level-100 total (documented: 600,000) and its
-- piecewise-boundary values at n=50/51 and n=68/69 (formula switches
-- there) stay monotonically increasing across the boundary.
check("Erratic level 100 = 600,000", ExperienceTable.expForLevel(ExperienceTable.GROWTH_ERRATIC, 100) == 600000)
check("Erratic monotonic across n=50/51 boundary",
  ExperienceTable.expForLevel(ExperienceTable.GROWTH_ERRATIC, 51) > ExperienceTable.expForLevel(ExperienceTable.GROWTH_ERRATIC, 50))
check("Erratic monotonic across n=68/69 boundary",
  ExperienceTable.expForLevel(ExperienceTable.GROWTH_ERRATIC, 69) > ExperienceTable.expForLevel(ExperienceTable.GROWTH_ERRATIC, 68))

-- Fluctuating's real level-100 total (documented: 1,640,000).
check("Fluctuating level 100 = 1,640,000",
  ExperienceTable.expForLevel(ExperienceTable.GROWTH_FLUCTUATING, 100) == 1640000)

-- levelForExp mirrors GetLevelFromMonExp/GetLevelFromBoxMonExp exactly.
check("levelForExp(MediumFast, 0) = level 1's exp not yet reached -> 0",
  ExperienceTable.levelForExp(ExperienceTable.GROWTH_MEDIUM_FAST, 0) == 0)
check("levelForExp(MediumFast, 1) = 1",
  ExperienceTable.levelForExp(ExperienceTable.GROWTH_MEDIUM_FAST, 1) == 1)
check("levelForExp(MediumFast, 999999) = 99",
  ExperienceTable.levelForExp(ExperienceTable.GROWTH_MEDIUM_FAST, 999999) == 99)
check("levelForExp(MediumFast, 1000000) = 100",
  ExperienceTable.levelForExp(ExperienceTable.GROWTH_MEDIUM_FAST, 1000000) == 100)
check("levelForExp(MediumSlow, exp-for-level-50) = 50",
  ExperienceTable.levelForExp(ExperienceTable.GROWTH_MEDIUM_SLOW,
    ExperienceTable.expForLevel(ExperienceTable.GROWTH_MEDIUM_SLOW, 50)) == 50)

-- Table is monotonically non-decreasing across the full level range for
-- every growth rate (a real exp table must be, or level-up would break).
for _, gr in ipairs({
  ExperienceTable.GROWTH_MEDIUM_FAST, ExperienceTable.GROWTH_ERRATIC,
  ExperienceTable.GROWTH_FLUCTUATING, ExperienceTable.GROWTH_MEDIUM_SLOW,
  ExperienceTable.GROWTH_FAST, ExperienceTable.GROWTH_SLOW,
}) do
  local ok = true
  for lvl = 1, 99 do
    if ExperienceTable.expForLevel(gr, lvl + 1) < ExperienceTable.expForLevel(gr, lvl) then
      ok = false
      break
    end
  end
  check(("growth rate %d monotonic 1..100"):format(gr), ok, gr)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
