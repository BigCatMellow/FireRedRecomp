-- FireRed's wild-Pokemon capture calculation, isolated as pure rules logic.
--
-- Source of truth: pokefirered src/battle_script_commands.c,
-- Cmd_handleballthrow (the non-trainer, non-Ghost, non-tutorial path), plus
-- include/battle_controllers.h's BALL_* animation-case enum.  This is a
-- direct port of the integer operations and Random() ordering in that code;
-- it is not the later-generation formula and it does not use a floating-
-- point probability approximation.
--
-- The bounded live API in this file is `tryPokeBall`: a normal ITEM_POKE_BALL
-- against a wild battler which supplies only `catchRate`, `maxHP`, and `hp`.
-- That is intentionally enough for the project's first capture slice.  The
-- lower-level `calculateCatchValue` accepts explicitly named multipliers so
-- later work can add the other real ball selectors and status-bit decoding
-- without changing the formula or the seeded replay contract:
--
--   ballMultiplierTenths:
--     sBallCatchBonuses gives Poke=10, Great=15, Ultra=20, Safari=15.
--     Cmd_handleballthrow separately selects Net/Dive/Nest/Repeat/Timer's
--     context-dependent values and Luxury/Premier=10.  This module does not
--     pretend those required battle/map/dex inputs exist yet.
--   statusNumerator/statusDenominator:
--     after the HP formula, Sleep/Freeze multiply the catch value by 2;
--     Poison/Burn/Paralysis/Toxic multiply it by 15/10.  Decoding FireRed's
--     STATUS1_* bitfield is deliberately left to the later status-system
--     integration.  The default here is the real no-status multiplier 1/1.
--
-- Exact real integer order (all values are non-negative, so floor is C
-- integer truncation):
--
--   value = (catchRate * ballMultiplierTenths / 10)
--   value = value * (3 * maxHP - 2 * hp) / (3 * maxHP)
--   value = value * statusNumerator / statusDenominator
--
-- The parentheses and truncation points matter.  In particular, the ball
-- factor is divided by 10 before the HP term is multiplied in.
--
-- If value > 254, FireRed catches immediately and consumes no Random().
-- Otherwise it calculates the shake threshold using the GBA BIOS Sqrt SWI:
--
--   root      = Sqrt(Sqrt(16711680 / value))
--   threshold = 1048560 / root
--
-- and then runs, literally:
--
--   for (shakes = 0; shakes < BALL_3_SHAKES_SUCCESS
--                    && Random() < threshold; shakes++);
--
-- BALL_3_SHAKES_SUCCESS is enum value 4.  Thus a capture needs FOUR passing
-- RNG comparisons even though the presentation calls it "3 shakes"; a
-- failure consumes its failing draw and prevents all later draws.  The `<`
-- comparison is strict.  These details are observable in a shared battle RNG
-- stream and are covered by tests below this module.
--
-- Rules/presentation/persistence separation:
-- this module does not remove a ball from Bag, animate, mutate BattleEngine,
-- copy the enemy Pokemon into PartyModel/PcBoxes, set its pokeball field, or
-- update the Pokedex.  In the real game those are separate battle-script
-- commands (`handleballthrow`, then `givecaughtmon`/GiveMonToPlayer and
-- `trysetcaughtmondexflags`).  A successful result carries the real item id
-- so the integration layer can perform those effects in the same separation.

local CaptureRules = {}

local floor = math.floor

CaptureRules.ITEM_POKE_BALL = 4 -- include/constants/items.h
CaptureRules.POKE_BALL_MULTIPLIER_TENTHS = 10 -- sBallCatchBonuses
CaptureRules.SUCCESS_SHAKES = 4 -- BALL_3_SHAKES_SUCCESS enum value

local function isInteger(value)
  return type(value) == "number" and value == floor(value)
end

local function assertInteger(name, value, minimum, maximum)
  assert(isInteger(value), name .. " must be an integer")
  assert(value >= minimum, name .. " must be >= " .. tostring(minimum))
  if maximum ~= nil then
    assert(value <= maximum, name .. " must be <= " .. tostring(maximum))
  end
end

-- Exact non-negative integer square root (floor(sqrt(value))).  The real code
-- calls the GBA BIOS `Sqrt(u32)` SWI twice.  The values on this capture path
-- are small enough for math.sqrt to be exact in practice, but using integer
-- division here makes the promised integer behavior explicit and independent
-- of a host libm implementation.
local function integerSqrt(value)
  assertInteger("sqrt value", value, 0)
  if value < 2 then return value end

  local low = 1
  local high = value
  local answer = 1
  while low <= high do
    local middle = floor((low + high) / 2)
    -- `middle <= value / middle` avoids squaring if this helper is reused
    -- with a larger u32.  The division is truncated just like the C/BIOS
    -- integer domain.
    if middle <= floor(value / middle) then
      answer = middle
      low = middle + 1
    else
      high = middle - 1
    end
  end
  return answer
end

-- Returns FireRed's HP/ball/status-adjusted `odds` (called catchValue here to
-- distinguish it from the later shake threshold).  `target` fields:
--   catchRate -- gSpeciesInfo[species].catchRate (u8)
--   maxHP     -- gBattleMons[target].maxHP
--   hp        -- gBattleMons[target].hp
--
-- `modifiers` is an extension seam, not an item/status policy layer.  Omit it
-- for a normal Poke Ball against an unstatused target, which is the current
-- supported slice.
function CaptureRules.calculateCatchValue(target, modifiers)
  assert(type(target) == "table", "capture target must be a table")
  modifiers = modifiers or {}

  local catchRate = target.catchRate
  local maxHP = target.maxHP
  local hp = target.hp
  local ballMultiplier = modifiers.ballMultiplierTenths
    or CaptureRules.POKE_BALL_MULTIPLIER_TENTHS
  local statusNumerator = modifiers.statusNumerator or 1
  local statusDenominator = modifiers.statusDenominator or 1

  assertInteger("catchRate", catchRate, 0, 255)
  assertInteger("maxHP", maxHP, 1)
  assertInteger("hp", hp, 0, maxHP)
  assertInteger("ballMultiplierTenths", ballMultiplier, 1)
  assertInteger("statusNumerator", statusNumerator, 1)
  assertInteger("statusDenominator", statusDenominator, 1)

  -- Keep each floor at the corresponding C division.  Collapsing this into
  -- one fraction changes edge cases for non-integral ball multipliers.
  local catchValue = floor(catchRate * ballMultiplier / 10)
  catchValue = floor(catchValue * (3 * maxHP - 2 * hp) / (3 * maxHP))
  catchValue = floor(catchValue * statusNumerator / statusDenominator)
  return catchValue
end

-- Returns the exact u32 threshold compared to each Random() u16.  The real
-- legal FireRed species/ball combinations always produce a positive value;
-- rejecting zero here is preferable to silently inventing behavior for the
-- source's division-by-zero-invalid state.
function CaptureRules.calculateShakeThreshold(catchValue)
  assertInteger("catchValue", catchValue, 1, 254)
  local root = integerSqrt(integerSqrt(floor(16711680 / catchValue)))
  return floor(1048560 / root)
end

-- Generic resolver kept public so future ball/status selectors can feed the
-- exact same rules and RNG contract.  It returns a plain event-like result:
--   captured       -- true after four passing comparisons or an auto-catch
--   shakes         -- 0..4; values map directly to FireRed's BALL_* cases
--   catchValue     -- HP/ball/status-adjusted value
--   shakeThreshold-- nil for the >254 auto-catch path
--   automatic      -- whether the >254 branch bypassed RNG
--   rngDraws       -- draws consumed by this attempt (0..4)
--   ballItemId     -- real item id, for later inventory/mon persistence
function CaptureRules.tryCapture(target, rng, modifiers)
  assert(rng and type(rng.next16) == "function", "capture needs an RNG with next16()")
  local catchValue = CaptureRules.calculateCatchValue(target, modifiers)

  if catchValue > 254 then
    return {
      captured = true,
      shakes = CaptureRules.SUCCESS_SHAKES,
      catchValue = catchValue,
      shakeThreshold = nil,
      automatic = true,
      rngDraws = 0,
      ballItemId = (modifiers and modifiers.ballItemId) or CaptureRules.ITEM_POKE_BALL,
    }
  end

  assert(catchValue > 0,
    "capture catchValue is zero; no legal FireRed wild species/Poke Ball state reaches this path")

  local threshold = CaptureRules.calculateShakeThreshold(catchValue)
  local shakes = 0
  local draws = 0
  while shakes < CaptureRules.SUCCESS_SHAKES do
    draws = draws + 1
    if rng:next16() >= threshold then
      break
    end
    shakes = shakes + 1
  end

  return {
    captured = shakes == CaptureRules.SUCCESS_SHAKES,
    shakes = shakes,
    catchValue = catchValue,
    shakeThreshold = threshold,
    automatic = false,
    rngDraws = draws,
    ballItemId = (modifiers and modifiers.ballItemId) or CaptureRules.ITEM_POKE_BALL,
  }
end

-- The supported first vertical slice: ITEM_POKE_BALL (10/10 modifier), no
-- status multiplier.  Keeping this wrapper narrow prevents a caller from
-- accidentally claiming an unimplemented contextual ball or status policy.
function CaptureRules.tryPokeBall(target, rng)
  return CaptureRules.tryCapture(target, rng, {
    ballMultiplierTenths = CaptureRules.POKE_BALL_MULTIPLIER_TENTHS,
    statusNumerator = 1,
    statusDenominator = 1,
    ballItemId = CaptureRules.ITEM_POKE_BALL,
  })
end

return CaptureRules
