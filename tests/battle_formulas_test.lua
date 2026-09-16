-- Run: lua5.1 tests/battle_formulas_test.lua
--
-- Pure tests for the direct ports in BattleFormulas.lua. The fixed RNG
-- makes both values and real RNG-consumption order observable.
package.path = package.path .. ";./?.lua"
local F = require("src.core.BattleFormulas")
local Data = require("tests.battle_test_data")

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local function rng(values)
  return {
    draws = 0,
    next16 = function(self)
      self.draws = self.draws + 1
      return values[self.draws] or 0
    end,
  }
end

local bulbasaur = {
  level = 5, attack = 9, defense = 9, speed = 9, spAttack = 11, spDefense = 11,
  types = { Data.TYPE_GRASS, Data.TYPE_POISON },
}
local charmander = {
  level = 5, attack = 10, defense = 9, speed = 11, spAttack = 11, spDefense = 10,
  types = { Data.TYPE_FIRE, Data.TYPE_FIRE },
}

-- The physical/special split is type-id based in FireRed, not a field on
-- BattleMove. TYPE_MYSTERY is intentionally neither branch.
check("Normal is physical", F.isPhysicalType(Data.TYPE_NORMAL))
check("Steel is physical", F.isPhysicalType(Data.TYPE_STEEL))
check("Fire is special", F.isSpecialType(Data.TYPE_FIRE))
check("Dark is special", F.isSpecialType(Data.TYPE_DARK))
check("??? is neither physical nor special", not F.isPhysicalType(Data.TYPE_MYSTERY) and not F.isSpecialType(Data.TYPE_MYSTERY))
check("absent category keeps the FireRed type split",
  F.damageCategory(Data.moves[Data.MOVE_TACKLE]) == "physical"
    and F.damageCategory(Data.moves[Data.MOVE_EMBER]) == "special")
check("explicit per-move category overrides the type split",
  F.damageCategory({type=Data.TYPE_FIRE, category="physical"}) == "physical"
    and F.damageCategory({type=Data.TYPE_NORMAL, category="special"}) == "special")
check("status category selects no damage-stat branch",
  F.damageCategory({type=Data.TYPE_NORMAL, category="status"}) == "status"
    and F.calculateBaseDamage({}, {}, {type=Data.TYPE_NORMAL, power=50, category="status"}, false) == 2)
local invalidCategory = pcall(F.damageCategory, {type=Data.TYPE_NORMAL, category="mixed"})
check("invalid per-move category fails closed", not invalidCategory)

check("neutral stat stage leaves a stat unchanged", F.applyStatMod(100, 6) == 100)
check("-6 stat stage is one quarter", F.applyStatMod(100, 0) == 25)
check("+6 stat stage is four times", F.applyStatMod(100, 12) == 400)

-- Hand-derived from CalculateBaseDamage's separately-truncating steps:
-- Bulbasaur Lv5 Tackle vs Charmander: 9*35*(2*5/5+2)=1260; /9=140;
-- /50=2; +2=4. This is before STAB/type/random modifiers.
check("golden physical base damage: Lv5 Bulbasaur Tackle = 4",
  F.calculateBaseDamage(bulbasaur, charmander, Data.moves[Data.MOVE_TACKLE], false) == 4)
-- Charmander Lv5 Ember vs Bulbasaur: 11*40*4/11=160; /50=3; +2=5.
check("golden special base damage: Lv5 Charmander Ember = 5",
  F.calculateBaseDamage(charmander, bulbasaur, Data.moves[Data.MOVE_EMBER], false) == 5)
check("rain halves Fire base damage before CalculateBaseDamage's +2",
  F.calculateBaseDamage(charmander, bulbasaur, Data.moves[Data.MOVE_EMBER], false, nil, "rain") == 3)
check("sun boosts Fire base damage before CalculateBaseDamage's +2",
  F.calculateBaseDamage(charmander, bulbasaur, Data.moves[Data.MOVE_EMBER], false, nil, "sun") == 6)
local categoryAttacker = {level=50, attack=100, defense=80, spAttack=20, spDefense=80}
local categoryDefender = {level=50, attack=80, defense=100, spAttack=80, spDefense=100}
local physicalFire = {type=Data.TYPE_FIRE, power=60, category="physical"}
local specialFire = {type=Data.TYPE_FIRE, power=60, category="special"}
check("explicit category selects the matching attack and defense stats",
  F.calculateBaseDamage(categoryAttacker, categoryDefender, physicalFire, false)
    ~= F.calculateBaseDamage(categoryAttacker, categoryDefender, specialFire, false))
check("physical-category Fire still receives type-based rain modifier",
  F.calculateBaseDamage(categoryAttacker, categoryDefender, physicalFire, false, nil, "rain")
    < F.calculateBaseDamage(categoryAttacker, categoryDefender, physicalFire, false))

-- Cmd_remaininghptopower / sFlailHpScaleToPowerTable, used by Flail and
-- Reversal. maxHP=48 makes the source's scaled-HP threshold boundaries
-- direct; a living low-HP battler also preserves the source minimum of 1.
check("Flail power uses the real six scaled-HP tiers",
  F.flailPower(1, 48) == 200 and F.flailPower(4, 48) == 150
    and F.flailPower(9, 48) == 100 and F.flailPower(16, 48) == 80
    and F.flailPower(32, 48) == 40 and F.flailPower(48, 48) == 20)
check("Flail's scaled-HP calculation preserves one pixel for a living mon",
  F.flailPower(1, 1000) == 200)
check("Eruption/Water Spout use real proportional power with a living minimum",
  F.healthScaledPower(100, 100, 150) == 150 and F.healthScaledPower(50, 100, 150) == 75
    and F.healthScaledPower(1, 1000, 150) == 1)
r = rng({ 4, 5, 14, 15, 34, 35, 64, 65, 84, 85, 94, 95 })
local magnitudeTiers = { {4,10}, {5,30}, {5,30}, {6,50}, {6,50}, {7,70}, {7,70}, {8,90}, {8,90}, {9,110}, {9,110}, {10,150} }
local magnitudeOk = true
for _, expected in ipairs(magnitudeTiers) do
  local level, power = F.rollMagnitude(r)
  magnitudeOk = magnitudeOk and level == expected[1] and power == expected[2]
end
check("Magnitude uses every real random-roll boundary", magnitudeOk and r.draws == 12)
r = rng({ 11, 15, 10 })
check("Psywave rejects 11-15 then uses the accepted ten-percent tier",
  F.psywaveDamage(20, r) == 30 and r.draws == 3)
check("Super Fang halves current HP with the real one-damage minimum",
  F.superFangDamage(19) == 9 and F.superFangDamage(1) == 1)

local damage, flags = F.typeCalc(4, Data.TYPE_NORMAL, bulbasaur.types, charmander.types, Data.typeChart)
check("Tackle is not STAB for Bulbasaur and stays at base damage", damage == 4, damage)
check("neutral Tackle has no effectiveness flags", not flags.superEffective and not flags.notVeryEffective and not flags.noEffect)
damage, flags = F.typeCalc(5, Data.TYPE_FIRE, charmander.types, bulbasaur.types, Data.typeChart)
check("Ember gets sequential STAB then Grass super effectiveness (5 -> 14)", damage == 14, damage)
check("Ember vs Bulbasaur is super-effective", flags.superEffective and not flags.notVeryEffective)
damage, flags = F.typeCalc(20, Data.TYPE_ELECTRIC, { Data.TYPE_ELECTRIC, Data.TYPE_ELECTRIC }, { Data.TYPE_GROUND, Data.TYPE_GROUND }, Data.typeChart)
check("Electric vs Ground is immune", damage == 0 and flags.noEffect and not flags.superEffective and not flags.notVeryEffective, damage)
damage, flags = F.typeCalc(10, Data.TYPE_FIRE, { Data.TYPE_FIRE, Data.TYPE_FIRE }, { Data.TYPE_GRASS, Data.TYPE_DRAGON }, Data.typeChart)
check("mixed 2x then 0.5x typing cancels effectiveness message flags", damage == 15 and not flags.superEffective and not flags.notVeryEffective, damage)

local r = rng({ 0, 15 })
check("random damage 0 gives real 100% roll", F.applyRandomDamageMultiplier(14, r) == 14)
check("random damage 15 gives real 85% roll", F.applyRandomDamageMultiplier(14, r) == 11)
check("each random-damage calculation consumes one draw", r.draws == 2, r.draws)

r = rng({ 94, 95 })
check("95-accuracy move hits when roll is 95", F.accuracyCheck(95, 6, 6, r))
check("95-accuracy move misses when roll is 96", not F.accuracyCheck(95, 6, 6, r))
r = rng({ 32, 33 })
check("-6 accuracy has real 33% threshold", F.accuracyCheck(100, 0, 6, r))
check("-6 accuracy misses above real 33% threshold", not F.accuracyCheck(100, 0, 6, r))

r = rng({ 0, 1 })
check("base crit roll hits on remainder zero", F.critRoll(r, 0))
check("base crit roll misses on remainder one", not F.critRoll(r, 0))

check("higher priority moves first even while slower",
  F.getWhoStrikesFirst(bulbasaur, charmander, Data.moves[Data.MOVE_QUICK_ATTACK], Data.moves[Data.MOVE_TACKLE], rng({})) == 0)
check("higher speed moves first at equal priority",
  F.getWhoStrikesFirst(bulbasaur, charmander, Data.moves[Data.MOVE_TACKLE], Data.moves[Data.MOVE_TACKLE], rng({})) == 1)
local tieA = { speed = 10 }
local tieB = { speed = 10 }
r = rng({ 1 })
check("equal-speed real coin flip can choose battler two", F.getWhoStrikesFirst(tieA, tieB, nil, nil, r) == 2)
check("speed tie consumes exactly one RNG draw", r.draws == 1, r.draws)

check("fast runner always escapes without a random draw", F.tryRunFromBattle(12, 10, 0, rng({})))
r = rng({ 63, 64 })
check("slower runner succeeds at roll 63 and fails at roll 64", F.tryRunFromBattle(10, 20, 0, r) and not F.tryRunFromBattle(10, 20, 0, r))
r = rng({ 17, 18 })
check("run speedVar has the real u8 overflow after seven attempts", F.tryRunFromBattle(10, 20, 7, r) and not F.tryRunFromBattle(10, 20, 7, r))

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
