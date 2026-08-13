-- Ports pokefirered's real wild-encounter species/level roll
-- (src/wild_encounter.c). Consumes a WildEncounters.lua-decoded
-- WildPokemonInfo (real per-map slot table) and an Rng instance
-- (src/core/Rng.lua, the real ISO_RANDOMIZE1 LCG).
--
-- Three real pieces ported here:
--
-- 1. Slot selection -- ChooseWildMonIndex_Land / ChooseWildMonIndex_
--    WaterRock. NOT uniform: real weighted cumulative tables from
--    src/data/wild_encounters.h:
--      land (12 slots, ENCOUNTER_CHANCE_LAND_MONS_SLOT_0..11, total 100):
--        20 20 10 10 10 10 5 5 4 4 1 1
--      water/rock (5 slots, ENCOUNTER_CHANCE_WATER_MONS_SLOT_0..4, total 100):
--        60 30 5 4 1
--    Real code: `rand = Random() % TOTAL`, then walks ascending cumulative
--    bounds to find the first slot whose bound exceeds rand.
--    ChooseWildMonIndex_WaterRock is reused as-is by real TryGenerateWildMon
--    for both WILD_AREA_WATER and WILD_AREA_ROCKS.
--
-- 2. Level roll -- ChooseWildMonLevel: lo=min(minLevel,maxLevel),
--    hi=max(...) (real code defensively swaps if maxLevel < minLevel,
--    though FireRed's real data never hits that), mod = hi-lo+1,
--    level = lo + Random() % mod.
--
-- Both (1) and (2) draw from the SAME Rng stream/instance the caller
-- passes in (the real global Random()/gRngValue stream).
--
-- 3. Encounter-trigger dice roll -- StandardWildEncounter's real chain:
--      DoGlobalWildEncounterDiceRoll: only rolled when the player's
--      current-step metatile behavior differs from the previous step's
--      (previousMetatileBehavior != currentBehavior); `Random() % 100 < 60`
--      to pass. Uses the SAME global Random() stream as (1)/(2), not a
--      separate one.
--      DoWildEncounterRateTest -> DoWildEncounterRateDiceRoll: real base
--      formula `rate = encounterRate * 16`, clamped to MAX_ENCOUNTER_RATE
--      (1600), then `WildEncounterRandom() % 1600 < rate` to pass.
--      WildEncounterRandom() is a SEPARATE, independently-seeded RNG
--      stream (sWildEncounterData.rngState, real SeedWildEncounterRng) --
--      ISO_RANDOMIZE2 (add 12345), not ISO_RANDOMIZE1 (add 24691).
--      Rng.lua's `add` parameter (this session) reproduces that second
--      stream: WildEncounterSelector.newTriggerRng(seed) below.
--
-- Out of scope (real modifiers requiring player/party/inventory state
-- not yet ported in this project): Mach/Acro Bike 80% rate modifier,
-- sWildEncounterData.encounterRateBuff step accumulation (AddToWild
-- EncounterRateBuff), White/Black Flute (ApplyFluteEncounterRateMod),
-- Cleanse Tag (ApplyCleanseTagEncounterRateMod), Stench/Illuminate
-- ability modifiers (GetAbilityEncounterRateModType), repel level
-- filtering (IsWildLevelAllowedByRepel), roamer encounters
-- (TryStartRoamerEncounter), Unown personality-letter search
-- (GenerateUnownPersonalityByLetter). shouldTrigger() implements only
-- the base rate*16/clamp/dice-roll formula plus the global dice roll.
--
-- Verified: tests/wild_encounter_selector_test.lua --
--  - 10,000-roll statistical test against Route 1's real 12-slot land
--    table (species_integration_test.lua's verified real data: Pidgey/
--    Rattata at levels 2-5), confirming per-slot pick frequency is
--    within tolerance of the real weight table and every rolled level
--    stays within its slot's real declared min/max range.
--  - One exact seeded golden sequence (fixed seed, hand-traced expected
--    slot+level outputs) for deterministic regression coverage.

local Rng = require("src.core.Rng")

local WildEncounterSelector = {}

-- Real per-slot weights, src/data/wild_encounters.h. Index 1 = slot 0.
WildEncounterSelector.LAND_SLOT_WEIGHTS = { 20, 20, 10, 10, 10, 10, 5, 5, 4, 4, 1, 1 }
WildEncounterSelector.WATER_SLOT_WEIGHTS = { 60, 30, 5, 4, 1 }

-- ISO_RANDOMIZE2's real additive constant (include/random.h), used by
-- the separate WildEncounterRandom() stream.
WildEncounterSelector.TRIGGER_RNG_ADD = 12345

-- src/wild_encounter.c MAX_ENCOUNTER_RATE.
WildEncounterSelector.MAX_ENCOUNTER_RATE = 1600

-- DoGlobalWildEncounterDiceRoll's real pass threshold: Random()%100 < 60.
WildEncounterSelector.GLOBAL_DICE_ROLL_PERCENT = 60

local function cumulativeTable(weights)
  local cum, total = {}, 0
  for i, w in ipairs(weights) do
    total = total + w
    cum[i] = total
  end
  return cum, total
end

local landCum, landTotal = cumulativeTable(WildEncounterSelector.LAND_SLOT_WEIGHTS)
local waterCum, waterTotal = cumulativeTable(WildEncounterSelector.WATER_SLOT_WEIGHTS)

-- rand: already-reduced value in [0, total). Returns the 0-based slot
-- index (matching WildPokemonInfo.mons[]'s 0-based indexing).
local function pickSlot(rand, cum)
  for i = 1, #cum do
    if rand < cum[i] then
      return i - 1
    end
  end
  return #cum - 1
end

-- Real ChooseWildMonIndex_Land: rand = Random() % ENCOUNTER_CHANCE_LAND_
-- MONS_TOTAL (100), then walks the cumulative land-slot table.
function WildEncounterSelector.chooseLandSlot(rng)
  local rand = rng:next16() % landTotal
  return pickSlot(rand, landCum)
end

-- Real ChooseWildMonIndex_WaterRock: same shape, 5-slot water/rock table.
-- Used for both WILD_AREA_WATER and WILD_AREA_ROCKS in the real code.
function WildEncounterSelector.chooseWaterRockSlot(rng)
  local rand = rng:next16() % waterTotal
  return pickSlot(rand, waterCum)
end

-- Real ChooseWildMonLevel(&info->wildPokemon[slot]).
function WildEncounterSelector.chooseLevel(rng, minLevel, maxLevel)
  local lo, hi = minLevel, maxLevel
  if hi < lo then
    lo, hi = hi, lo
  end
  local mod = hi - lo + 1
  return lo + (rng:next16() % mod)
end

-- info: a WildEncounters.lua-resolved WildPokemonInfo ({encounterRate,
-- mons = {[0]=..., [1]=..., ...}}). rng: an Rng instance for the real
-- global Random() stream (shared across slot + level rolls, matching
-- real TryGenerateWildMon's single Random() call sequence per roll).
-- area: "land" (default) or "water" -- selects which real slot table to
-- use; FireRed's real rock-smash encounters also use the water table
-- (WILD_AREA_ROCKS shares ChooseWildMonIndex_WaterRock).
-- Returns { slot, species, level } -- species/level generation only, no
-- battle triggering (out of scope, Phase 4).
function WildEncounterSelector.roll(info, rng, area)
  local slot
  if area == "water" then
    slot = WildEncounterSelector.chooseWaterRockSlot(rng)
  else
    slot = WildEncounterSelector.chooseLandSlot(rng)
  end
  local mon = info.mons[slot]
  local level = WildEncounterSelector.chooseLevel(rng, mon.minLevel, mon.maxLevel)
  return { slot = slot, species = mon.species, level = level }
end

-- Constructs the real independent WildEncounterRandom() stream (real
-- SeedWildEncounterRng(seed) equivalent) -- must NOT be the same Rng
-- instance passed to roll()/chooseLandSlot()/etc, which use the real
-- global Random() stream instead.
function WildEncounterSelector.newTriggerRng(seed)
  return Rng.new(seed, WildEncounterSelector.TRIGGER_RNG_ADD)
end

-- Real StandardWildEncounter's trigger chain (species/level-selection
-- scope only -- does not itself start a battle).
--   globalRng: the real global Random() stream (same instance roll()
--     would use).
--   triggerRng: the real separate WildEncounterRandom() stream, from
--     newTriggerRng().
--   encounterRate: the real WildPokemonInfo.encounterRate for this map's
--     area (land/water/rock).
--   behaviorChanged: true when this step's metatile behavior differs
--     from the previous step's -- DoGlobalWildEncounterDiceRoll is real-
--     coded to only run on that transition (standing still or walking
--     within one uniform-behavior patch doesn't reroll it).
-- Returns true if an encounter should trigger this step.
function WildEncounterSelector.shouldTrigger(globalRng, triggerRng, encounterRate, behaviorChanged)
  if behaviorChanged then
    if (globalRng:next16() % 100) >= WildEncounterSelector.GLOBAL_DICE_ROLL_PERCENT then
      return false
    end
  end
  local rate = encounterRate * 16
  if rate > WildEncounterSelector.MAX_ENCOUNTER_RATE then
    rate = WildEncounterSelector.MAX_ENCOUNTER_RATE
  end
  return (triggerRng:next16() % WildEncounterSelector.MAX_ENCOUNTER_RATE) < rate
end

return WildEncounterSelector
