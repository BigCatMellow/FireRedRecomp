-- Real stat calculation, pokefirered src/pokemon.c's CalculateMonStats
-- and its CALC_STAT macro / ModifyStatByNature. Given a species' base
-- stats (import/SpeciesInfo.lua), a level, IVs, EVs, and a nature row
-- (import/Nature.lua), computes real HP/Attack/Defense/SpAttack/
-- SpDefense/Speed exactly as the retail game does.
--
-- HP (CalculateMonStats, non-Shedinja branch):
--   maxHP = (((2*baseHP + hpIV + hpEV/4) * level) / 100) + level + 10
-- Other five stats (CALC_STAT macro):
--   n = (((2*baseStat + iv + ev/4) * level) / 100) + 5
--   n = ModifyStatByNature(nature, n, statIndex)   -- not HP
-- All division here is C integer truncation (floor, since every operand
-- is non-negative) -- Lua's `math.floor` after `/` reproduces it exactly.
--
-- ModifyStatByNature: nature rows are {attack,defense,speed,spAttack,
-- spDefense} each in {-1,0,+1} (import/Nature.lua's parsed shape).
-- +1 -> floor(n*110/100), -1 -> floor(n*90/100), 0 -> n unchanged. HP is
-- never nature-modified (real code: "if (statIndex <= STAT_HP ...)
-- return stat" -- STAT_HP is index 0, so HP is skipped structurally, not
-- as a special case here; this module just never applies a nature to HP).
--
-- Verified by hand against real Bulbasaur base stats (HP45/Atk49/Def49/
-- Spe45/SpA65/SpD65, GROWTH_MEDIUM_SLOW, pokefirered
-- src/data/pokemon/species_info.h) at level 5, IV=0, EV=0, neutral
-- nature (all modifiers 0): HP = ((90*5)/100)+5+10 = floor(4.5)+15 = 19;
-- Attack = ((98*5)/100)+5 = floor(4.9)+5 = 9. These are the well-known
-- "IV 0, EV 0, neutral nature" minimum stats documented for a level-5
-- Bulbasaur (e.g. via Bulbapedia's/Serebii's stat calculators) -- see
-- pokemon_stats_test.lua.
--
-- Shedinja's real maxHP-is-always-1 special case (CalculateMonStats:
-- `if (species == SPECIES_SHEDINJA) newMaxHP = 1;`) and the mid-battle
-- Deoxys forme stat override (GetDeoxysStat) are both real behavior but
-- deliberately out of scope here -- this module computes the plain
-- CALC_STAT/HP formula only; callers needing the Shedinja special case
-- can special-case species == SPECIES_SHEDINJA themselves (species id
-- 303 in pokefirered's constants/species.h).

local PokemonStats = {}

local function idiv(a, b)
  return math.floor(a / b)
end

-- Real CalculateMonStats HP formula.
function PokemonStats.calculateHP(baseHP, iv, ev, level)
  local n = 2 * baseHP + iv
  return idiv((n + idiv(ev, 4)) * level, 100) + level + 10
end

-- natureMod: -1, 0, or +1 (one field of a Nature.lua parsed row).
-- Real ModifyStatByNature, applied after the shared CALC_STAT core.
function PokemonStats.calculateStat(baseStat, iv, ev, level, natureMod)
  local n = idiv((2 * baseStat + iv + idiv(ev, 4)) * level, 100) + 5
  if natureMod == 1 then
    return idiv(n * 110, 100)
  elseif natureMod == -1 then
    return idiv(n * 90, 100)
  end
  return n
end

-- species: a parsed SpeciesInfo record (baseHP/baseAttack/... fields).
-- ivs/evs: tables with hp/attack/defense/speed/spAttack/spDefense keys
--   (same key names SpeciesInfo.evYield uses).
-- natureRow: a parsed Nature.lua row ({attack,defense,speed,spAttack,
--   spDefense}, each -1/0/+1), or nil for no nature modification.
-- Returns { hp, attack, defense, speed, spAttack, spDefense }.
function PokemonStats.calculateAll(species, level, ivs, evs, natureRow)
  natureRow = natureRow or { attack = 0, defense = 0, speed = 0, spAttack = 0, spDefense = 0 }
  return {
    hp = PokemonStats.calculateHP(species.baseHP, ivs.hp, evs.hp, level),
    attack = PokemonStats.calculateStat(species.baseAttack, ivs.attack, evs.attack, level, natureRow.attack),
    defense = PokemonStats.calculateStat(species.baseDefense, ivs.defense, evs.defense, level, natureRow.defense),
    speed = PokemonStats.calculateStat(species.baseSpeed, ivs.speed, evs.speed, level, natureRow.speed),
    spAttack = PokemonStats.calculateStat(species.baseSpAttack, ivs.spAttack, evs.spAttack, level, natureRow.spAttack),
    spDefense = PokemonStats.calculateStat(species.baseSpDefense, ivs.spDefense, evs.spDefense, level, natureRow.spDefense),
  }
end

return PokemonStats
