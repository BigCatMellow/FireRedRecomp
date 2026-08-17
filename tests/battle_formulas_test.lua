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
