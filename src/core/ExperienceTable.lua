-- Real exp-to-level growth curves, pokefirered
-- src/data/pokemon/experience_tables.h's gExperienceTables + macros
-- (EXP_SLOW/EXP_FAST/EXP_MEDIUM_FAST/EXP_MEDIUM_SLOW/EXP_ERRATIC/
-- EXP_FLUCTUATING), and src/pokemon.c's GetLevelFromMonExp/
-- GetLevelFromBoxMonExp (the "smallest exp table entry the mon's total
-- exp is NOT below" search) and CreateBoxMon's
-- gExperienceTables[growthRate][level] exp-for-level lookup.
--
-- Rather than hardcoding all 6*101 table entries, this recomputes each
-- entry from the same macros pokefirered uses to generate the table at
-- compile time (they're pure integer formulas of n = level, using
-- truncating integer division exactly like C's `/` on non-negative
-- operands -- Lua's `math.floor` after a plain `/` reproduces that).
-- Verified this reproduces the real generated table by hand-checking
-- documented real thresholds (see experience_table_test.lua):
-- GROWTH_MEDIUM_FAST's level-100 total is exactly 1,000,000 (n^3 at
-- n=100), and Bulbasaur's real growth rate (GROWTH_MEDIUM_SLOW) totals
-- 1,059,860 at level 100 -- both match the well-known documented totals
-- for these curves. growthRate indices match include/constants/pokemon.h's
-- GROWTH_* order (0=MediumFast,1=Erratic,2=Fluctuating,3=MediumSlow,
-- 4=Fast,5=Slow) and SpeciesInfo.growthRate reads that same byte
-- directly out of struct SpeciesInfo, so no remapping is needed between
-- the two.

local ExperienceTable = {}

ExperienceTable.MAX_LEVEL = 100 -- include/constants/pokemon.h MAX_LEVEL

ExperienceTable.GROWTH_MEDIUM_FAST = 0
ExperienceTable.GROWTH_ERRATIC = 1
ExperienceTable.GROWTH_FLUCTUATING = 2
ExperienceTable.GROWTH_MEDIUM_SLOW = 3
ExperienceTable.GROWTH_FAST = 4
ExperienceTable.GROWTH_SLOW = 5

local function idiv(a, b)
  -- Truncating integer division matching C's `/` for the non-negative
  -- operands these formulas always produce (n is 0..100 throughout).
  return math.floor(a / b)
end

local function cube(n) return n * n * n end
local function square(n) return n * n end

-- experience_tables.h macros, transcribed 1:1.
local function expSlow(n) return idiv(5 * cube(n), 4) end
local function expFast(n) return idiv(4 * cube(n), 5) end
local function expMediumFast(n) return cube(n) end
local function expMediumSlow(n)
  return idiv(6 * cube(n), 5) - 15 * square(n) + 100 * n - 140
end
local function expErratic(n)
  if n <= 50 then
    return idiv((100 - n) * cube(n), 50)
  elseif n <= 68 then
    return idiv((150 - n) * cube(n), 100)
  elseif n <= 98 then
    return idiv(idiv(1911 - 10 * n, 3) * cube(n), 500)
  else
    return idiv((160 - n) * cube(n), 100)
  end
end
local function expFluctuating(n)
  if n <= 15 then
    return idiv((idiv(n + 1, 3) + 24) * cube(n), 50)
  elseif n <= 36 then
    return idiv((n + 14) * cube(n), 50)
  else
    return idiv((idiv(n, 2) + 32) * cube(n), 50)
  end
end

local FORMULAS = {
  [ExperienceTable.GROWTH_MEDIUM_FAST] = expMediumFast,
  [ExperienceTable.GROWTH_ERRATIC] = expErratic,
  [ExperienceTable.GROWTH_FLUCTUATING] = expFluctuating,
  [ExperienceTable.GROWTH_MEDIUM_SLOW] = expMediumSlow,
  [ExperienceTable.GROWTH_FAST] = expFast,
  [ExperienceTable.GROWTH_SLOW] = expSlow,
}

-- Total exp required to be at exactly `level` (1..MAX_LEVEL) under the
-- given growth rate. Level 1 is always 0 exp (real table's row[1] is a
-- literal `1`, not a formula result -- see below); level 0 exists in the
-- real table too (always 0) as row[0] but no in-game mon is level 0.
function ExperienceTable.expForLevel(growthRate, level)
  local formula = FORMULAS[growthRate]
  if not formula then
    error(("unknown growth rate %s"):format(tostring(growthRate)))
  end
  if level <= 0 then return 0 end
  if level == 1 then
    -- Real table hardcodes row[1] = 1 (not formula(1), which would be 0
    -- for every curve) -- see experience_tables.h's literal `1, // 1`
    -- line right after every table's `0, // 0`. GetLevelFromMonExp's
    -- search still treats a mon with 0 exp as level 1 in practice
    -- (0 < 1 fails the "table[level] <= exp" advance check at level 1).
    return 1
  end
  return formula(level)
end

-- Transcribed 1:1 from GetLevelFromMonExp/GetLevelFromBoxMonExp:
--   s32 level = 1;
--   while (level <= MAX_LEVEL && gExperienceTables[growthRate][level] <= exp)
--       level++;
--   return level - 1;
-- Note the real function can return 0 for exp=0 (table[1]==1, so the
-- loop body never runs) -- not a real in-game state since CreateMon
-- always sets a level-1 mon's exp to table[1]==1, not 0, but preserved
-- here rather than special-cased, to match the real function exactly.
function ExperienceTable.levelForExp(growthRate, exp)
  local level = 1
  while level <= ExperienceTable.MAX_LEVEL and ExperienceTable.expForLevel(growthRate, level) <= exp do
    level = level + 1
  end
  return level - 1
end

return ExperienceTable
