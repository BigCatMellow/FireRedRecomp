-- Run: lua5.1 tests/wild_encounter_selector_test.lua
-- Unit test (no ROM required): verifies WildEncounterSelector's real
-- weighted-slot table and level-range logic against Route 1's real
-- decoded data (same 12-slot Pidgey/Rattata table verified against the
-- real ROM in tests/species_integration_test.lua), plus one exact
-- seeded golden sequence independently computed in Python (see the
-- comment below).
package.path = package.path .. ";./?.lua"
local WildEncounterSelector = require("src.core.WildEncounterSelector")
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

-- Real Route 1 land WildPokemonInfo, verified against the real ROM in
-- tests/species_integration_test.lua (Pidgey=16, Rattata=19).
local route1Land = {
  encounterRate = 21,
  mons = {
    [0] = { minLevel = 3, maxLevel = 3, species = 16 },
    [1] = { minLevel = 3, maxLevel = 3, species = 19 },
    [2] = { minLevel = 3, maxLevel = 3, species = 16 },
    [3] = { minLevel = 3, maxLevel = 3, species = 19 },
    [4] = { minLevel = 2, maxLevel = 2, species = 16 },
    [5] = { minLevel = 2, maxLevel = 2, species = 19 },
    [6] = { minLevel = 3, maxLevel = 3, species = 16 },
    [7] = { minLevel = 3, maxLevel = 3, species = 19 },
    [8] = { minLevel = 4, maxLevel = 4, species = 16 },
    [9] = { minLevel = 4, maxLevel = 4, species = 19 },
    [10] = { minLevel = 5, maxLevel = 5, species = 16 },
    [11] = { minLevel = 4, maxLevel = 4, species = 19 },
  },
}

-- ---------------------------------------------------------------------
-- Golden sequence: seed=12345, real ISO_RANDOMIZE1 stream, independently
-- computed in Python:
--   v = (1103515245*v + 24691) % 2**32; u16 = v >> 16
--   raw outputs: 54236, 48294, 33234, 26870, 17078, 24410
-- Each roll() consumes 2 draws (slot then level):
--   roll 1: r=54236, 54236%100=36 -> slot 1 (cum 20,40,...; 36<40) ->
--           Rattata, lvl range 3-3 -> r=48294%1=0 -> level 3
--   roll 2: r=33234, 33234%100=34 -> slot 1 -> Rattata -> r=26870%1=0 -> level 3
--   roll 3: r=17078, 17078%100=78 -> slot 5 (cum ...70,80; 78<80) ->
--           Rattata, lvl range 2-2 -> r=24410%1=0 -> level 2
-- ---------------------------------------------------------------------
do
  local rng = Rng.new(12345)
  local expected = {
    { slot = 1, species = 19, level = 3 },
    { slot = 1, species = 19, level = 3 },
    { slot = 5, species = 19, level = 2 },
  }
  for i, exp in ipairs(expected) do
    local r = WildEncounterSelector.roll(route1Land, rng, "land")
    check(("golden roll %d slot"):format(i), r.slot == exp.slot, r.slot)
    check(("golden roll %d species"):format(i), r.species == exp.species, r.species)
    check(("golden roll %d level"):format(i), r.level == exp.level, r.level)
  end
end

-- ---------------------------------------------------------------------
-- Statistical test: 10,000 rolls against Route 1's real land table.
-- Real cumulative weights (src/data/wild_encounters.h): 20 20 10 10 10
-- 10 5 5 4 4 1 1 out of 100. Expect each slot's observed frequency
-- within a generous absolute tolerance of its real weight (this is a
-- distribution-shape check, not exact-value verification -- allow slack
-- for finite-sample noise, esp. on the 1% slots).
-- ---------------------------------------------------------------------
do
  local rng = Rng.new(987654321)
  local N = 10000
  local slotCounts = {}
  for i = 0, 11 do slotCounts[i] = 0 end
  local levelsOk = true
  for i = 1, N do
    local r = WildEncounterSelector.roll(route1Land, rng, "land")
    slotCounts[r.slot] = slotCounts[r.slot] + 1
    local mon = route1Land.mons[r.slot]
    if r.level < mon.minLevel or r.level > mon.maxLevel then
      levelsOk = false
    end
    if r.species ~= mon.species then
      levelsOk = false
    end
  end
  check("all 10,000 rolled levels stay within their slot's real min/max range", levelsOk)

  local weights = WildEncounterSelector.LAND_SLOT_WEIGHTS
  local allWithinTolerance = true
  local detail = {}
  for i = 0, 11 do
    local expectedPct = weights[i + 1]
    local observedPct = slotCounts[i] / N * 100
    -- Absolute tolerance of 3 percentage points is comfortably wide for
    -- N=10000 (e.g. a true 20% slot has stddev ~0.4pp; a true 1% slot
    -- has stddev ~0.1pp) while still catching a wrong/uniform table.
    local tol = 3
    if math.abs(observedPct - expectedPct) > tol then
      allWithinTolerance = false
    end
    detail[#detail + 1] = ("slot%d exp=%d%% obs=%.2f%%"):format(i, expectedPct, observedPct)
  end
  check("slot-selection frequencies match the real weight table within tolerance",
    allWithinTolerance, table.concat(detail, ", "))

  -- Sanity: a uniform distribution over 12 slots would put every slot at
  -- 8.33% -- confirm the low-weight slots (10, 11 at 1% each) are
  -- clearly NOT near that, proving the table is weighted, not uniform.
  local slot10Pct = slotCounts[10] / N * 100
  local slot11Pct = slotCounts[11] / N * 100
  check("low-weight slots 10/11 (real weight 1%) are far below a uniform 8.33%",
    slot10Pct < 4 and slot11Pct < 4, ("slot10=%.2f%% slot11=%.2f%%"):format(slot10Pct, slot11Pct))
end

-- ---------------------------------------------------------------------
-- Water/rock slot table sanity (60/30/5/4/1 over 5 slots).
-- ---------------------------------------------------------------------
do
  local rng = Rng.new(42)
  local N = 10000
  local counts = { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
  for i = 1, N do
    local slot = WildEncounterSelector.chooseWaterRockSlot(rng)
    counts[slot] = counts[slot] + 1
  end
  local weights = WildEncounterSelector.WATER_SLOT_WEIGHTS
  local ok = true
  for i = 0, 4 do
    local expectedPct = weights[i + 1]
    local observedPct = counts[i] / N * 100
    if math.abs(observedPct - expectedPct) > 3 then ok = false end
  end
  check("water/rock slot frequencies match the real 60/30/5/4/1 table within tolerance", ok)
end

-- ---------------------------------------------------------------------
-- chooseLevel: defensive min/max swap (real ChooseWildMonLevel swaps if
-- maxLevel < minLevel) and single-value range.
-- ---------------------------------------------------------------------
do
  local rng = Rng.new(1)
  local level = WildEncounterSelector.chooseLevel(rng, 10, 10)
  check("single-value level range always returns that level", level == 10, level)

  local rng2 = Rng.new(2)
  local sawLow, sawHigh = false, false
  for i = 1, 200 do
    local lvl = WildEncounterSelector.chooseLevel(rng2, 5, 7)
    check("level stays within swapped range", lvl >= 5 and lvl <= 7, lvl)
    if lvl == 5 then sawLow = true end
    if lvl == 7 then sawHigh = true end
  end
  check("level roll covers the full range over many samples", sawLow and sawHigh)

  -- maxLevel < minLevel: real code swaps lo/hi before rolling.
  local rng3 = Rng.new(3)
  for i = 1, 50 do
    local lvl = WildEncounterSelector.chooseLevel(rng3, 20, 15)
    check("swapped min>max range still bounds correctly", lvl >= 15 and lvl <= 20, lvl)
  end
end

-- ---------------------------------------------------------------------
-- shouldTrigger: base rate formula (encounterRate*16, clamp to 1600,
-- dice roll) and the behaviorChanged-gated global dice roll, using two
-- independent RNG streams (real ISO_RANDOMIZE1 vs ISO_RANDOMIZE2).
-- ---------------------------------------------------------------------
do
  local globalRng = Rng.new(55)
  local triggerRng = WildEncounterSelector.newTriggerRng(55)
  check("newTriggerRng uses the real ISO_RANDOMIZE2 additive constant (12345)",
    triggerRng.add == 12345, triggerRng.add)
  -- Compare raw 32-bit state (not the quantized u16 output, which can
  -- coincidentally collide since the two additive constants differ by
  -- only 12346 out of a 2^32 range and the high 16 bits often agree).
  do
    local isoRandomize1Rng = Rng.new(55)
    isoRandomize1Rng:next16()
    triggerRng:next16()
    check("newTriggerRng's stream differs from a same-seeded ISO_RANDOMIZE1 stream",
      triggerRng.value ~= isoRandomize1Rng.value)
  end

  -- encounterRate=100 (max real value) -> rate = 100*16 = 1600 = MAX,
  -- so the dice roll should always pass once encounterRate saturates it.
  do
    local gRng, tRng = Rng.new(1), WildEncounterSelector.newTriggerRng(1)
    local alwaysPassed = true
    for i = 1, 200 do
      if not WildEncounterSelector.shouldTrigger(gRng, tRng, 100, false) then
        alwaysPassed = false
      end
    end
    check("encounterRate=100 (saturating MAX_ENCOUNTER_RATE) always triggers", alwaysPassed)
  end

  -- encounterRate=0 should never trigger.
  do
    local gRng, tRng = Rng.new(2), WildEncounterSelector.newTriggerRng(2)
    local neverPassed = true
    for i = 1, 200 do
      if WildEncounterSelector.shouldTrigger(gRng, tRng, 0, false) then
        neverPassed = false
      end
    end
    check("encounterRate=0 never triggers", neverPassed)
  end

  -- behaviorChanged=false must not consume the globalRng stream (real
  -- code only calls DoGlobalWildEncounterDiceRoll on a behavior change).
  do
    local gRng = Rng.new(9)
    local tRng = WildEncounterSelector.newTriggerRng(9)
    local before = gRng.value
    WildEncounterSelector.shouldTrigger(gRng, tRng, 21, false)
    check("behaviorChanged=false doesn't advance the global RNG stream", gRng.value == before)
  end
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
