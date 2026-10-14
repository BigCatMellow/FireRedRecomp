-- Run: lua5.1 tests/status_conditions_test.lua
--
-- Source oracles for src/core/StatusConditions.lua: status1 bit layout
-- (include/constants/battle.h:91-101) and the represented SetMoveEffect
-- guards/duration (src/battle_script_commands.c:2140-2356), pin c75f352.
package.path = package.path .. ";./?.lua"

local S = require("src.core.StatusConditions")

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
      return values[self.draws] or 0
    end,
  }
end

local function mon(types, status, hp)
  return { types = types, status = status, hp = hp or 10 }
end

-- Bit layout
check("sleep mask is bits 0-2", S.SLEEP_MASK == 7)
check("poison is bit 3", S.POISON == 8)
check("burn is bit 4", S.BURN == 16)
check("freeze is bit 5", S.FREEZE == 32)
check("paralysis is bit 6", S.PARALYSIS == 64)
check("toxic is bit 7", S.TOXIC_POISON == 128)
check("toxic counter starts at bit 8", S.TOXIC_COUNTER_UNIT == 256)

check("sleepTurns reads bits 0-2", S.sleepTurns(5) == 5 and S.sleepTurns(128 + 3) == 3)
check("isAsleep false at 0 turns", not S.isAsleep(0) and S.isAsleep(1))
check("nil status reads as healthy", not S.hasAny(nil) and S.sleepTurns(nil) == 0)
check("predicates read their own bit only",
  S.isPoisoned(8) and not S.isPoisoned(16) and S.isBurned(16) and S.isFrozen(32)
  and S.isParalyzed(64) and S.isBadlyPoisoned(128) and not S.isBadlyPoisoned(64))
check("toxicCounter reads bits 8-11", S.toxicCounter(128 + 3 * 256) == 3)
check("toxicCounter reads 15", S.toxicCounter(128 + 15 * 256) == 15)
check("toxicCounter reads 9", S.toxicCounter(9 * 256 + 64) == 9)
check("toxicCounter ignores bits 12+", S.toxicCounter(4096 + 2 * 256) == 2)
check("withToxicCounter masks a high counter to 0", S.withToxicCounter(128 + 9 * 256, 0) == 128)
check("withToxicCounter masks counter 15 and keeps bit 12", S.withToxicCounter(4096 + 15 * 256 + 128, 0) == 4096 + 128)
check("predicates read mixed words",
  S.isPoisoned(8 + 3) and S.isBurned(16 + 8 + 5) and S.isParalyzed(64 + 128 + 3 * 256)
  and S.isBadlyPoisoned(128 + 15 * 256) and not S.isFrozen(16 + 64 + 128 + 7)
  and S.sleepTurns(64 + 8 + 6) == 6)
check("hasAny ignores a stray toxic counter", not S.hasAny(5 * 256))
check("hasAny counts sleep, toxic and toxic-with-counter", S.hasAny(1) and S.hasAny(128) and S.hasAny(128 + 3 * 256) and S.hasAny(64))
check("withToxicCounter keeps flags", S.withToxicCounter(128 + 2 * 256, 15) == 128 + 15 * 256)
check("withToxicCounter preserves higher bits", S.withToxicCounter(4096 + 128, 1) == 4096 + 256 + 128)
check("withSleepTurns replaces only sleep bits", S.withSleepTurns(4, 1) == 1 and S.withSleepTurns(256 + 3, 0) == 256)

-- canApply guards
local NORMAL, POISON, STEEL, FIRE, ICE, ELECTRIC, WATER = 0, 3, 8, 10, 15, 13, 11
check("healthy Normal can be slept", S.canApply(mon({ NORMAL, NORMAL }, 0), "sleep"))
local ok, why = S.canApply(mon({ NORMAL, NORMAL }, 0, 0), "burn")
check("fainted target cannot be statused", not ok and why == "fainted", why)
for _, kind in ipairs({ "sleep", "poison", "burn", "freeze", "paralysis", "toxic" }) do
  ok, why = S.canApply(mon({ WATER, WATER }, S.PARALYSIS), kind)
  check("existing status blocks " .. kind, not ok and why == "hasStatus", why)
  ok, why = S.canApply(mon({ WATER, WATER }, S.TOXIC_POISON + 3 * 256), kind)
  check("bad poison blocks " .. kind, not ok and why == "hasStatus", why)
  ok, why = S.canApply(mon({ WATER, WATER }, 2 * 256), kind)
  check("whole status1 word blocks " .. kind .. " (source if (status1))", not ok and why == "hasStatus", why)
  ok, why = S.canApply(mon({ WATER, WATER }, 2), kind)
  check("sleeping target blocks " .. kind, not ok and why == "hasStatus", why)
end
ok, why = S.canApply(mon({ POISON, POISON }, 0), "poison")
check("Poison type immune to poison", not ok and why == "immune", why)
ok, why = S.canApply(mon({ NORMAL, STEEL }, 0), "poison")
check("secondary Steel type immune to poison", not ok and why == "immune", why)
ok, why = S.canApply(mon({ STEEL, STEEL }, 0), "toxic")
check("Steel type immune to toxic", not ok and why == "immune", why)
ok, why = S.canApply(mon({ POISON, POISON }, S.BURN), "toxic")
check("toxic checks status before type (source :2332)", not ok and why == "hasStatus", why)
ok, why = S.canApply(mon({ POISON, POISON }, 0), "toxic")
check("Poison type immune to toxic (source :2334)", not ok and why == "immune", why)
-- Source checks type before status1 for poison/burn/freeze (:2197-2211,
-- :2238-2252, :2260-2263).
ok, why = S.canApply(mon({ STEEL, STEEL }, S.BURN), "poison")
check("poison reports immunity before existing status", not ok and why == "immune", why)
ok, why = S.canApply(mon({ FIRE, FIRE }, S.PARALYSIS), "burn")
check("burn reports immunity before existing status", not ok and why == "immune", why)
ok, why = S.canApply(mon({ ICE, ICE }, 1), "freeze")
check("freeze reports immunity before existing status", not ok and why == "immune", why)
ok, why = S.canApply(mon({ FIRE, FIRE }, 0), "burn")
check("Fire type immune to burn", not ok and why == "immune", why)
ok, why = S.canApply(mon({ WATER, ICE }, 0), "freeze")
check("Ice type immune to freeze", not ok and why == "immune", why)
check("Electric type NOT immune to paralysis in Gen 3", S.canApply(mon({ ELECTRIC, ELECTRIC }, 0), "paralysis"))
check("Fire type can be frozen", S.canApply(mon({ FIRE, FIRE }, 0), "freeze"))
check("Poison type can be burned", S.canApply(mon({ POISON, POISON }, 0), "burn"))
check("unknown kind errors", not pcall(S.canApply, mon({ NORMAL, NORMAL }, 0), "confusion"))

-- apply
local rng = scriptedRng({ 0, 3, 7, 65535 })
local target = mon({ NORMAL, NORMAL }, 0)
check("sleep draw 0 -> 2 turns", S.apply(target, "sleep", rng) == 2 and target.status == 2)
target.status = 0
check("sleep draw 3 -> 5 turns", S.apply(target, "sleep", rng) == 5)
target.status = 0
check("sleep uses & 3 (draw 7 -> 5)", S.apply(target, "sleep", rng) == 5)
target.status = 0
check("sleep draw 65535 -> 5", S.apply(target, "sleep", rng) == 5)
check("sleep took one draw each", rng.draws == 4, rng.draws)

local quiet = scriptedRng({})
for kind, bit in pairs({ poison = 8, burn = 16, freeze = 32, paralysis = 64, toxic = 128 }) do
  target.status = 0
  check(kind .. " sets its bit", S.apply(target, kind, quiet) == bit, target.status)
end
check("non-sleep kinds draw nothing", quiet.draws == 0, quiet.draws)
target.status = 7 * 256
check("toxic resets a stray counter to 0", S.apply(target, "toxic", quiet) == 128)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
