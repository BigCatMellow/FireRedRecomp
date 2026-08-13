-- Run: lua5.1 tests/wild_encounter_trigger_test.lua
--   (optionally: POKEPORT_ROM=/path/to/verified/pokefirered.gba ... for the
--    real-Route-1 integration section at the bottom)
--
-- Covers src/core/WildEncounterTrigger.lua -- the per-step glue main.lua
-- calls when a real player step completes. The point of this file is the
-- handoff's "does the trigger-rate roll get invoked on grass entry" check,
-- structured as a pure function so it runs without love2d.
--
-- Both RNG streams are stubbed with scripted next16() sequences so each
-- real branch (global 60% dice roll on a behavior change, the
-- encounterRate*16/1600 rate roll, then the weighted slot + level roll) is
-- asserted exactly rather than statistically -- the statistical coverage of
-- the rolls themselves already lives in wild_encounter_selector_test.lua.
package.path = package.path .. ";./?.lua"
local WildEncounterTrigger = require("src.core.WildEncounterTrigger")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- Same interface as src/core/Rng.lua's :next16(), but with a fixed script
-- of values plus a draw counter, so "was the trigger roll invoked at all"
-- is directly observable.
local function scriptedRng(values)
  return {
    draws = 0,
    values = values,
    next16 = function(self)
      self.draws = self.draws + 1
      return self.values[self.draws] or 0
    end,
  }
end

local MB_TALL_GRASS = WildEncounterTrigger.MB_TALL_GRASS
local MB_NORMAL = 0x00

-- Real Route 1 land table shape (encounterRate 21, 12 slots) -- the
-- verified real data species_integration_test.lua/WildEncounters.lua's
-- header both cite.
local function route1Info()
  local mons = {}
  for i = 0, 11 do mons[i] = { minLevel = 2, maxLevel = 5, species = 16 } end
  mons[0] = { minLevel = 2, maxLevel = 5, species = 16 } -- PIDGEY
  mons[1] = { minLevel = 2, maxLevel = 4, species = 19 } -- RATTATA
  return { encounterRate = 21, mons = mons }
end

------------------------------------------------- non-encounter behaviors

local globalRng = scriptedRng({})
local trigger = WildEncounterTrigger.new({ globalRng = globalRng, triggerRng = scriptedRng({}) })
check("a step onto a plain tile triggers nothing", trigger:onStep(MB_NORMAL, route1Info()) == nil)
check("a non-encounter tile draws no RNG at all", globalRng.draws == 0, globalRng.draws)

------------------------------------------------ grass entry rolls the dice

-- First grass step: previousBehavior is nil, so behaviorChanged is true and
-- the real global dice roll runs (Random()%100 < 60 -> 0 passes). Then the
-- real rate roll on the SEPARATE stream (0 % 1600 < 21*16=336 -> passes).
-- Then the real slot roll (Random()%100 = 0 -> slot 0) and level roll
-- (Random()%(5-2+1) = 0 -> level 2).
local g = scriptedRng({ 0, 0, 0 })
local t = scriptedRng({ 0 })
trigger = WildEncounterTrigger.new({ globalRng = g, triggerRng = t })
local result = trigger:onStep(MB_TALL_GRASS, route1Info())
check("stepping into real tall grass triggers a real encounter", result ~= nil)
check("the real trigger-rate roll was drawn from the separate stream", t.draws == 1, t.draws)
check("the global stream covered the dice roll + slot + level", g.draws == 3, g.draws)
if result then
  check("real slot 0 was rolled", result.slot == 0, result.slot)
  check("real slot 0's species (PIDGEY=16) came back", result.species == 16, result.species)
  check("real level roll used the slot's own min/max", result.level == 2, result.level)
end

------------------------------------------- the global dice roll can fail

-- Random()%100 = 60 is NOT < 60, so the real global roll fails and the rate
-- roll is never reached.
g = scriptedRng({ 60 })
t = scriptedRng({ 0 })
trigger = WildEncounterTrigger.new({ globalRng = g, triggerRng = t })
check("a failed real global dice roll means no encounter", trigger:onStep(MB_TALL_GRASS, route1Info()) == nil)
check("a failed global roll never reaches the rate roll", t.draws == 0, t.draws)

--------------------------- the global roll only happens on a real change

-- Two grass steps in a row: the second has behaviorChanged == false, so
-- real DoGlobalWildEncounterDiceRoll is skipped entirely and only the rate
-- roll runs. Rate roll returns 1599 (>= 336) both times so neither step
-- triggers and the draw counts stay easy to read.
g = scriptedRng({ 0, 0 })
t = scriptedRng({ 1599, 1599, 1599 })
trigger = WildEncounterTrigger.new({ globalRng = g, triggerRng = t })
trigger:onStep(MB_TALL_GRASS, route1Info())
check("first grass step ran the real global dice roll", g.draws == 1, g.draws)
trigger:onStep(MB_TALL_GRASS, route1Info())
check("a second consecutive grass step skips the real global dice roll", g.draws == 1, g.draws)
check("but still runs the real rate roll every step", t.draws == 2, t.draws)

-- Leaving grass and coming back is a real behavior change again.
trigger:onStep(MB_NORMAL, route1Info())
trigger:onStep(MB_TALL_GRASS, route1Info())
check("re-entering grass counts as a real behavior change again", g.draws == 2, g.draws)

---------------------------------------------------------- missing data

g = scriptedRng({ 0, 0, 0 })
trigger = WildEncounterTrigger.new({ globalRng = g, triggerRng = scriptedRng({ 0 }) })
check("a map with no real land encounter table triggers nothing", trigger:onStep(MB_TALL_GRASS, nil) == nil)
check("no RNG is drawn when the map has no encounter table", g.draws == 0, g.draws)

------------------------------------------------------- misuse is loud

local ok = pcall(WildEncounterTrigger.new, { globalRng = g })
check("constructing without both real streams errors loudly", not ok)
ok = pcall(WildEncounterTrigger.new, { globalRng = g, triggerRng = g })
check("passing one stream twice errors loudly (they are independent in real code)", not ok)

---------------------------------------------- real ROM integration (opt-in)

local romPath = os.getenv("POKEPORT_ROM")
if romPath then
  local RomImporter = require("import.RomImporter")
  local RomAddresses = require("import.RomAddresses")
  local WildEncounters = require("import.WildEncounters")
  local Rng = require("src.core.Rng")
  local WildEncounterSelector = require("src.core.WildEncounterSelector")
  local Charmap = require("import.Charmap")

  local addrs = RomAddresses[RomImporter._sha1HexOfFile(romPath)]
  local f = io.open(romPath, "rb")
  local data = f:read("*a")
  f:close()

  -- MAP_ROUTE1 = group 3, num 19 (same ids main.lua/POKEPORT_MAP use).
  local header = WildEncounters.findHeader(data, addrs.gWildMonHeaders, 3, 19)
  check("real Route 1 has a wild encounter header", header ~= nil)
  local info = header and WildEncounters.resolveInfo(data, header.landMonsInfoPtr, 12)
  check("real Route 1 land table resolves with its real encounterRate 21",
    info ~= nil and info.encounterRate == 21, info and info.encounterRate)

  if info then
    local seed = 0x5A0B -- main.lua's default POKEPORT_RNG_SEED
    local realTrigger = WildEncounterTrigger.new({
      globalRng = Rng.new(seed),
      triggerRng = WildEncounterSelector.newTriggerRng(seed),
    })
    -- Walk back and forth over real grass until the real dice land.
    local encounter, steps
    for i = 1, 400 do
      encounter = realTrigger:onStep(i % 2 == 0 and MB_TALL_GRASS or MB_NORMAL, info)
      if encounter then steps = i break end
    end
    check("real Route 1 grass eventually triggers a real encounter", encounter ~= nil, steps)
    if encounter then
      local name = Charmap.decodeAt(data, addrs.gSpeciesNames, 11, encounter.species)
      check("the rolled species is one of real Route 1's two (PIDGEY/RATTATA)",
        encounter.species == 16 or encounter.species == 19, name)
      check("the rolled level is inside real Route 1's declared range (2-5)",
        encounter.level >= 2 and encounter.level <= 5, encounter.level)
      print(("  (real roll: %s Lv %d, slot %d, after %d steps)"):format(name, encounter.level, encounter.slot, steps))
    end
  end
else
  print("SKIP: set POKEPORT_ROM=... to also run the real Route 1 integration section")
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
