-- Run: lua5.1 tests/pokemon_stats_test.lua
package.path = package.path .. ";./?.lua"
local PokemonStats = require("src.core.PokemonStats")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- Real Bulbasaur base stats (pokefirered src/data/pokemon/species_info.h):
-- HP45 Atk49 Def49 Spe45 SpA65 SpD65.
local bulbasaur = { baseHP = 45, baseAttack = 49, baseDefense = 49, baseSpeed = 45, baseSpAttack = 65, baseSpDefense = 65 }
local zeroIVs = { hp = 0, attack = 0, defense = 0, speed = 0, spAttack = 0, spDefense = 0 }
local zeroEVs = { hp = 0, attack = 0, defense = 0, speed = 0, spAttack = 0, spDefense = 0 }
local neutralNature = { attack = 0, defense = 0, speed = 0, spAttack = 0, spDefense = 0 }

-- Level 5, IV=0, EV=0, neutral nature: real documented minimum stats for
-- a level-5 Bulbasaur (CalculateMonStats/CALC_STAT hand-derivation, see
-- PokemonStats.lua header). HP = floor((2*45+0+0)*5/100)+5+10 = 19.
-- Attack = floor((2*49+0+0)*5/100)+5 = 9.
local stats5 = PokemonStats.calculateAll(bulbasaur, 5, zeroIVs, zeroEVs, neutralNature)
check("Bulbasaur Lv5 IV0 EV0 HP = 19", stats5.hp == 19, stats5.hp)
check("Bulbasaur Lv5 IV0 EV0 Attack = 9", stats5.attack == 9, stats5.attack)
check("Bulbasaur Lv5 IV0 EV0 Defense = 9", stats5.defense == 9, stats5.defense)
check("Bulbasaur Lv5 IV0 EV0 Speed = 9", stats5.speed == 9, stats5.speed)
check("Bulbasaur Lv5 IV0 EV0 SpAttack = 11", stats5.spAttack == 11, stats5.spAttack)
check("Bulbasaur Lv5 IV0 EV0 SpDefense = 11", stats5.spDefense == 11, stats5.spDefense)

-- Level 100, IV=31 (max), EV=0, neutral nature -- real documented max-IV
-- level 100 Bulbasaur base stats (well-known Bulbapedia/Serebii stat
-- calculator values): HP=299(actually compute), Attack=124...
-- Hand-derive rather than assert unverified memory: HP =
-- floor((2*45+31)*100/100)+100+10 = 121+110 = 231.
-- Attack = floor((2*49+31)*100/100)+5 = 129+5 = 134.
local maxIVs = { hp = 31, attack = 31, defense = 31, speed = 31, spAttack = 31, spDefense = 31 }
local stats100 = PokemonStats.calculateAll(bulbasaur, 100, maxIVs, zeroEVs, neutralNature)
check("Bulbasaur Lv100 IV31 EV0 HP = 231", stats100.hp == 231, stats100.hp)
check("Bulbasaur Lv100 IV31 EV0 Attack = 134", stats100.attack == 134, stats100.attack)

-- Nature modifiers: +10%/-10%, floored. nil nature mod behaves like 0
-- (unchanged) -- calculateAll's default when no nature row is given.
local nilN = PokemonStats.calculateStat(200, 0, 0, 50, nil)
local baseN = PokemonStats.calculateStat(200, 0, 0, 50, 0) -- neutral
local plusN = PokemonStats.calculateStat(200, 0, 0, 50, 1)
local minusN = PokemonStats.calculateStat(200, 0, 0, 50, -1)
check("nil nature mod behaves like neutral (0)", nilN == baseN, { nilN, baseN })
check("positive nature increases stat", plusN > baseN, { plusN, baseN })
check("negative nature decreases stat", minusN < baseN, { minusN, baseN })
check("positive nature is floor(n*110/100)", plusN == math.floor(baseN * 110 / 100), { plusN, baseN })
check("negative nature is floor(n*90/100)", minusN == math.floor(baseN * 90 / 100), { minusN, baseN })

-- calculateAll with no nature row (nil) falls back to all-zero modifiers.
local statsNoNature = PokemonStats.calculateAll(bulbasaur, 5, zeroIVs, zeroEVs, nil)
check("calculateAll(nature=nil) matches explicit neutral nature", statsNoNature.attack == stats5.attack, statsNoNature.attack)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
