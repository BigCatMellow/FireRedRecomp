-- Primary (status1) battle status conditions: pure helpers, no engine or
-- presentation state. Source pin pret/pokefirered c75f352.
--
-- Bit layout (include/constants/battle.h:91-101), kept identical so the
-- value BattlePartyBridge already round-trips is the real status1 word:
--   bits 0-2  STATUS1_SLEEP turns remaining
--   bit 3     STATUS1_POISON
--   bit 4     STATUS1_BURN
--   bit 5     STATUS1_FREEZE
--   bit 6     STATUS1_PARALYSIS
--   bit 7     STATUS1_TOXIC_POISON
--   bits 8-11 STATUS1_TOXIC_COUNTER
-- Lua 5.1 has no bit library here, so bits are read with arithmetic.
--
-- canApply mirrors the represented guards of SetMoveEffect
-- (src/battle_script_commands.c:2140-2350): effect battler alive, no
-- existing status1, and the type immunities (Poison/Steel vs poison and
-- toxic, Fire vs burn, Ice vs freeze; Electric is NOT immune to paralysis
-- in Gen 3). Abilities, Safeguard, Substitute, Uproar and sun are not
-- represented in this project and are deliberately absent.

local StatusConditions = {}

StatusConditions.SLEEP_MASK = 7
StatusConditions.POISON = 8
StatusConditions.BURN = 16
StatusConditions.FREEZE = 32
StatusConditions.PARALYSIS = 64
StatusConditions.TOXIC_POISON = 128
StatusConditions.TOXIC_COUNTER_UNIT = 256
StatusConditions.TOXIC_COUNTER_MAX = 15

local TYPE_POISON, TYPE_STEEL, TYPE_FIRE, TYPE_ICE = 3, 8, 10, 15
StatusConditions.TYPE_POISON = TYPE_POISON
StatusConditions.TYPE_STEEL = TYPE_STEEL
StatusConditions.TYPE_FIRE = TYPE_FIRE
StatusConditions.TYPE_ICE = TYPE_ICE

local function hasBit(value, bit)
  return math.floor((value or 0) / bit) % 2 == 1
end
StatusConditions.hasBit = hasBit

function StatusConditions.sleepTurns(status)
  return (status or 0) % 8
end

function StatusConditions.toxicCounter(status)
  return math.floor((status or 0) / 256) % 16
end

function StatusConditions.isAsleep(status) return StatusConditions.sleepTurns(status) > 0 end
function StatusConditions.isPoisoned(status) return hasBit(status, 8) end
function StatusConditions.isBurned(status) return hasBit(status, 16) end
function StatusConditions.isFrozen(status) return hasBit(status, 32) end
function StatusConditions.isParalyzed(status) return hasBit(status, 64) end
function StatusConditions.isBadlyPoisoned(status) return hasBit(status, 128) end

-- Real STATUS1_ANY excludes the toxic counter bits.
function StatusConditions.hasAny(status)
  return (status or 0) % 256 ~= 0
end

-- Returns the status1 word with the sleep turns replaced by `turns`.
function StatusConditions.withSleepTurns(status, turns)
  status = status or 0
  return status - (status % 8) + turns
end

-- Returns the status1 word with the toxic counter replaced by `n` (0-15).
function StatusConditions.withToxicCounter(status, n)
  status = status or 0
  local low = status % 256
  local high = math.floor(status / 4096) * 4096
  return high + n * 256 + low
end

local function isType(battler, t)
  local types = battler.types or {}
  return types[1] == t or types[2] == t
end

StatusConditions.KINDS = {
  sleep = true, poison = true, burn = true, freeze = true,
  paralysis = true, toxic = true,
}

-- Returns true, or false plus a reason:
--   "fainted"  effect battler at 0 HP
--   "hasStatus" status1 already nonzero (any primary status)
--   "immune"   a type immunity applies
-- Reasons follow source order (SetMoveEffect): types before status1 for
-- poison (:2197-2211), burn (:2238-2252) and freeze (:2260-2263); status1
-- before types for toxic (:2332), where a healthy Poison/Steel target is
-- the real MOVE_RESULT_DOESNT_AFFECT_FOE branch (:2334-2346).
function StatusConditions.canApply(target, kind)
  assert(StatusConditions.KINDS[kind], "unknown status kind " .. tostring(kind))
  if target.hp <= 0 then return false, "fainted" end
  -- Source tests the whole status1 word (`if (gBattleMons[].status1)`), not
  -- STATUS1_ANY, so a word holding only toxic counter bits also blocks.
  local status = target.status or 0
  if kind == "toxic" then
    if status ~= 0 then return false, "hasStatus" end
    if isType(target, TYPE_POISON) or isType(target, TYPE_STEEL) then
      return false, "immune"
    end
    return true
  end
  if kind == "poison" and (isType(target, TYPE_POISON) or isType(target, TYPE_STEEL)) then
    return false, "immune"
  end
  if kind == "burn" and isType(target, TYPE_FIRE) then return false, "immune" end
  if kind == "freeze" and isType(target, TYPE_ICE) then return false, "immune" end
  if status ~= 0 then return false, "hasStatus" end
  return true
end

-- Sets the status on `target` (caller already checked canApply). Sleep
-- draws its duration from the shared RNG, `(Random() & 3) + 2` = 2-5
-- (battle_script_commands.c:2356); no other kind draws. Toxic starts with
-- a zero counter. Returns the new status1 word.
function StatusConditions.apply(target, kind, rng)
  local status = target.status or 0
  if kind == "sleep" then
    status = StatusConditions.withSleepTurns(status, (rng:next16() % 4) + 2)
  elseif kind == "poison" then
    status = status + StatusConditions.POISON
  elseif kind == "burn" then
    status = status + StatusConditions.BURN
  elseif kind == "freeze" then
    status = status + StatusConditions.FREEZE
  elseif kind == "paralysis" then
    status = status + StatusConditions.PARALYSIS
  elseif kind == "toxic" then
    status = StatusConditions.withToxicCounter(status + StatusConditions.TOXIC_POISON, 0)
  else
    error("unknown status kind " .. tostring(kind))
  end
  target.status = status
  return status
end

return StatusConditions
