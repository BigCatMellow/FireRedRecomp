-- Run: lua5.1 tests/capture_rules_test.lua
--   (optionally POKEPORT_ROM=/path/to/pokefirered.gba lua5.1 ...)
--
-- Golden tests for Cmd_handleballthrow's normal wild-battle Poke Ball path.
-- The scripted draws make the strict comparison and early-stop RNG order
-- observable; seeded tests use src/core/Rng.lua's real FireRed Random() LCG.
package.path = package.path .. ";./?.lua"

local CaptureRules = require("src.core.CaptureRules")
local Rng = require("src.core.Rng")

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local function scriptedRng(values)
  return {
    draws = 0,
    next16 = function(self)
      self.draws = self.draws + 1
      local value = values[self.draws]
      assert(value ~= nil, "scripted RNG exhausted")
      return value
    end,
  }
end

check("real Poke Ball item id is 4", CaptureRules.ITEM_POKE_BALL == 4)
check("real Poke Ball multiplier is 10 tenths", CaptureRules.POKE_BALL_MULTIPLIER_TENTHS == 10)
check("BALL_3_SHAKES_SUCCESS is enum value 4", CaptureRules.SUCCESS_SHAKES == 4)

-- Hand-computed source golden values.  Poke Ball/no status means the first
-- division leaves catchRate unchanged:
-- full HP: floor(45 * (60 - 40) / 60) = 15
-- 1 HP:    floor(45 * (60 -  2) / 60) = 43
local fullHP = { catchRate = 45, maxHP = 20, hp = 20 }
local oneHP = { catchRate = 45, maxHP = 20, hp = 1 }
check("catch rate 45 at full HP gives catch value 15",
  CaptureRules.calculateCatchValue(fullHP) == 15,
  CaptureRules.calculateCatchValue(fullHP))
check("catch rate 45 at 1/20 HP gives catch value 43",
  CaptureRules.calculateCatchValue(oneHP) == 43,
  CaptureRules.calculateCatchValue(oneHP))
check("catch rate 255 at full HP gives catch value 85",
  CaptureRules.calculateCatchValue({ catchRate = 255, maxHP = 20, hp = 20 }) == 85)

-- Golden nested-BIOS-Sqrt thresholds, calculated from the exact source
-- constants.  These values also catch a common wrong 65536-based rewrite.
check("catch value 15 has exact shake threshold 32767",
  CaptureRules.calculateShakeThreshold(15) == 32767,
  CaptureRules.calculateShakeThreshold(15))
check("catch value 43 has exact shake threshold 43690",
  CaptureRules.calculateShakeThreshold(43) == 43690,
  CaptureRules.calculateShakeThreshold(43))
check("catch value 254 has exact shake threshold 65535",
  CaptureRules.calculateShakeThreshold(254) == 65535,
  CaptureRules.calculateShakeThreshold(254))

-- The comparison is strict: threshold-1 passes; threshold itself fails.
-- The failing draw is consumed and the loop stops immediately.
local threshold = CaptureRules.calculateShakeThreshold(15)
local scripted = scriptedRng({ threshold - 1, threshold - 1, threshold })
local result = CaptureRules.tryPokeBall(fullHP, scripted)
check("two passing comparisons produce two shakes before failure", not result.captured and result.shakes == 2, result.shakes)
check("draw equal to threshold fails the strict Random < threshold check", result.rngDraws == 3 and scripted.draws == 3, scripted.draws)
check("failed result exposes source catch value and threshold", result.catchValue == 15 and result.shakeThreshold == 32767)
check("result carries Poke Ball item id for persistence", result.ballItemId == 4)

-- Four passes are required for BALL_3_SHAKES_SUCCESS and consume four draws.
scripted = scriptedRng({ 0, 1, 2, 3, 65535 })
result = CaptureRules.tryPokeBall(fullHP, scripted)
check("four passing checks catch despite presentation saying three shakes", result.captured and result.shakes == 4)
check("successful non-auto capture consumes exactly four draws", result.rngDraws == 4 and scripted.draws == 4, scripted.draws)

-- Immediate failure consumes one draw, never the unused tail.
scripted = scriptedRng({ 65535, 0, 0, 0 })
result = CaptureRules.tryPokeBall(fullHP, scripted)
check("first failed comparison reports zero shakes", not result.captured and result.shakes == 0)
check("first failure stops RNG consumption", result.rngDraws == 1 and scripted.draws == 1, scripted.draws)

-- >254 is the source's auto-catch branch and consumes no RNG.  Reaching it
-- here uses the generic extension seam (2x ball factor); tryPokeBall itself
-- remains the bounded normal-ball/no-status API.
scripted = scriptedRng({ 12345 })
result = CaptureRules.tryCapture(
  { catchRate = 255, maxHP = 20, hp = 0 },
  scripted,
  { ballMultiplierTenths = 20, statusNumerator = 1, statusDenominator = 1 }
)
check("catch value above 254 auto-catches", result.captured and result.automatic and result.catchValue == 510)
check("auto-catch branch consumes no Random draw", result.rngDraws == 0 and scripted.draws == 0, scripted.draws)
check("auto-catch has no shake threshold", result.shakeThreshold == nil)

-- Seeded replay golden #1.  For catch value 15 / threshold 32767, seed 0's
-- real Random() outputs begin 0, 59774.  The first passes and the second
-- fails: one shake, two draws, ending at the known LCG state 0xE97E7B6A.
local seeded = Rng.new(0)
result = CaptureRules.tryPokeBall(fullHP, seeded)
check("seed 0/full HP golden replay fails after one shake", not result.captured and result.shakes == 1)
check("seed 0/full HP golden replay consumes two draws", result.rngDraws == 2)
check("seed 0/full HP golden replay ends at exact LCG state",
  seeded.value == 0xE97E7B6A, string.format("0x%08X", seeded.value))

-- Seeded replay golden #2.  A real catch-rate-190 target at 1/20 HP has
-- catch value floor(190*58/60)=183 and threshold 61680.  Seed 0's first
-- four outputs (0,59774,21105,12720) all pass, ending at 0x31B0DDE4.
seeded = Rng.new(0)
result = CaptureRules.tryPokeBall({ catchRate = 190, maxHP = 20, hp = 1 }, seeded)
check("seed 0/catch-rate-190 golden replay catches", result.captured and result.shakes == 4, result.shakes)
check("seeded successful replay has expected catch value and threshold",
  result.catchValue == 183 and result.shakeThreshold == 61680,
  tostring(result.catchValue) .. "/" .. tostring(result.shakeThreshold))
check("seeded successful replay consumes four draws and exact LCG state",
  result.rngDraws == 4 and seeded.value == 0x31B0DDE4,
  string.format("%d/0x%08X", result.rngDraws, seeded.value))

-- Extension seam preserves the source's separate truncation points.  A Great
-- Ball-shaped 15/10 multiplier is floored before the HP fraction:
-- floor(45*15/10)=67, then floor(67*58/60)=64 (not floor(65.25)=65).
check("ball multiplier division truncates before HP multiplication",
  CaptureRules.calculateCatchValue(oneHP, {
    ballMultiplierTenths = 15,
    statusNumerator = 1,
    statusDenominator = 1,
  }) == 64)
check("status extension applies only after HP truncation",
  CaptureRules.calculateCatchValue(oneHP, {
    ballMultiplierTenths = 10,
    statusNumerator = 3,
    statusDenominator = 2,
  }) == 64) -- floor(43*15/10), matching Cmd_handleballthrow

-- Invalid battle-state inputs fail loudly instead of changing the formula.
check("maxHP zero is rejected", not pcall(function()
  CaptureRules.tryPokeBall({ catchRate = 45, maxHP = 0, hp = 0 }, Rng.new(0))
end))
check("HP above maxHP is rejected", not pcall(function()
  CaptureRules.tryPokeBall({ catchRate = 45, maxHP = 20, hp = 21 }, Rng.new(0))
end))

-- Optional retail-ROM grounding: the catch-rate field consumed by this core
-- comes from the already-verified SpeciesInfo parser, not a duplicated table.
local romPath = os.getenv("POKEPORT_ROM")
if romPath then
  local RomImporter = require("import.RomImporter")
  local RomAddresses = require("import.RomAddresses")
  local SpeciesInfo = require("import.SpeciesInfo")
  local addrs = RomAddresses[RomImporter._sha1HexOfFile(romPath)]
  local f = assert(io.open(romPath, "rb"))
  local data = f:read("*a")
  f:close()
  local species = SpeciesInfo.parseTable(data, addrs.gSpeciesInfo, 20)
  check("retail ROM Pidgey catch rate is 255", species[16].catchRate == 255, species[16].catchRate)
  check("retail ROM Rattata catch rate is 255", species[19].catchRate == 255, species[19].catchRate)
else
  print("SKIP: set POKEPORT_ROM=... to ground capture catch-rate fixtures in the retail ROM")
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
