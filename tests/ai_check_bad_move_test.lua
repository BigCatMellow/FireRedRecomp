-- Unit test: AICheckBadMove.score, the native port of real AI_CheckBadMove
-- (data/battle_ai_scripts.s:52-602). Pure Lua, no ROM needed.
--
-- Run: lua5.1 tests/ai_check_bad_move_test.lua
package.path = package.path .. ";./?.lua"
local AICheckBadMove = require("src.core.AICheckBadMove")
local BattleEngine = require("src.core.BattleEngine")
local Data = require("tests.battle_test_data")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local TYPE_NORMAL, TYPE_GHOST, TYPE_GRASS, TYPE_POISON, TYPE_GROUND, TYPE_ELECTRIC, TYPE_STEEL =
  0, 7, 12, 3, 4, 13, 8

-- Real ability ids used below (include/constants/abilities.h).
local ABILITY_NONE = 0
local ABILITY_LEVITATE = 26
local ABILITY_VOLT_ABSORB = 10
local ABILITY_WONDER_GUARD = 25
local ABILITY_SOUNDPROOF = 43
local ABILITY_HYPER_CUTTER = 52
local ABILITY_CLEAR_BODY = 29
local ABILITY_STURDY = 5

local sideStatus = {
  [BattleEngine.SIDE_PLAYER] = { reflect = false, lightScreen = false },
  [BattleEngine.SIDE_FOE] = { reflect = false, lightScreen = false },
}

local function mon(opts)
  return {
    level = opts.level or 10,
    hp = opts.hp or 30,
    maxHP = opts.maxHP or 30,
    types = opts.types or { TYPE_NORMAL, TYPE_NORMAL },
    ability = opts.ability or ABILITY_NONE,
    statStages = opts.statStages or {
      attack = 6, defense = 6, speed = 6, spAttack = 6, spDefense = 6, accuracy = 6, evasion = 6,
    },
  }
end

local function score(user, target, move, moveId, status)
  return AICheckBadMove.score(user, target, move, moveId, Data.typeChart, status or sideStatus)
end

------------------------------------------------------------------------
-- Top-level type-immunity / ability-cancellation section
------------------------------------------------------------------------

-- Ghost is immune to Normal (real gTypeEffectiveness row, Data.typeChart[109]).
do
  local user = mon({})
  local target = mon({ types = { TYPE_GHOST, TYPE_GHOST } })
  local tackle = Data.moves[Data.MOVE_TACKLE]
  check("real x0 type immunity (Normal into Ghost) scores -10",
    score(user, target, tackle, Data.MOVE_TACKLE) == -10)
end

-- Volt Absorb cancels an Electric move (Score_Minus12), but not otherwise.
do
  local user = mon({})
  local target = mon({ ability = ABILITY_VOLT_ABSORB })
  local thunderbolt = { effect = 0, power = 90, type = TYPE_ELECTRIC, accuracy = 100 }
  check("Volt Absorb cancels an Electric move: -12",
    score(user, target, thunderbolt, 9001) == -12)
  local tackle = Data.moves[Data.MOVE_TACKLE]
  check("Volt Absorb does not cancel a Normal move",
    score(user, target, tackle, Data.MOVE_TACKLE) == 0)
end

-- Wonder Guard: blocks anything not super-effective-or-better.
do
  local user = mon({})
  local target = mon({ ability = ABILITY_WONDER_GUARD })
  local tackle = Data.moves[Data.MOVE_TACKLE] -- neutral vs Normal/Normal target
  check("Wonder Guard blocks a merely-neutral move: -10",
    score(user, target, tackle, Data.MOVE_TACKLE) == -10)
  -- Real CheckIfWonderGuardCancelsMove (data/battle_ai_scripts.s:83-85) only
  -- exempts an EXACT AI_EFFECTIVENESS_x2 match -- a real, confirmed quirk:
  -- a x4 hit is NOT exempted (eff ~= X2 is still true at x4) and still
  -- scores -10, only a plain x2 hit passes through.
  local grassMove = { effect = 0, power = 40, type = TYPE_GRASS, accuracy = 100 }
  local grassTarget = mon({ ability = ABILITY_WONDER_GUARD, types = { 11, 11 } }) -- mono Water: Grass is exactly x2
  check("Wonder Guard allows an exact x2 hit through (no penalty)",
    score(user, grassTarget, grassMove, 9002) == 0)
  local grassTarget4x = mon({ ability = ABILITY_WONDER_GUARD, types = { 11, 4 } }) -- Water/Ground: Grass is x4
  check("Wonder Guard's real quirk: a x4 hit is NOT exempted (only exact x2 is), still -10",
    score(user, grassTarget4x, grassMove, 9002) == -10)
end

-- Levitate cancels a Ground move.
do
  local user = mon({})
  local target = mon({ ability = ABILITY_LEVITATE })
  local earthquake = { effect = 0, power = 100, type = TYPE_GROUND, accuracy = 100 }
  check("Levitate cancels a Ground move: -10",
    score(user, target, earthquake, 9003) == -10)
end

-- Soundproof blocks the real listed sound moves (Growl among them),
-- independent of the power-discouraged gate (Growl is power<=1, so this
-- also exercises the "always runs" Soundproof step).
do
  local user = mon({})
  local target = mon({ ability = ABILITY_SOUNDPROOF })
  local growl = Data.moves[Data.MOVE_GROWL]
  check("Soundproof blocks Growl (a real listed sound move): -10",
    score(user, target, growl, Data.MOVE_GROWL) == -10)
  local tailWhip = Data.moves[Data.MOVE_TAIL_WHIP]
  check("Soundproof does not block Tail Whip (not a real listed sound move)",
    score(user, target, tailWhip, Data.MOVE_TAIL_WHIP) == 0)
end

------------------------------------------------------------------------
-- Representative AI_CBM_* branches: penalty-applied and no-penalty cases
------------------------------------------------------------------------

-- AI_CBM_HighRiskForDamage (Take Down's real effect id, EFFECT_RECOIL,
-- isn't itself in the dispatch chain -- use Focus Punch's real effect id
-- instead, which IS chain-mapped to this shared handler).
do
  local focusPunch = { effect = 170, power = 150, type = TYPE_NORMAL, accuracy = 100 }
  local user = mon({})
  local immuneTarget = mon({ types = { TYPE_GHOST, TYPE_GHOST } })
  check("HighRiskForDamage: x0 type immunity scores -10",
    score(user, immuneTarget, focusPunch, 9004) == -10)
  local normalTarget = mon({})
  check("HighRiskForDamage: ordinary neutral hit scores 0",
    score(user, normalTarget, focusPunch, 9004) == 0)
end

-- Stat-up family: already-maxed vs not.
do
  local swordsDance = Data.moves[Data.MOVE_SWORDS_DANCE] -- EFFECT_ATTACK_UP_2 (50)
  local target = mon({})
  local maxedUser = mon({ statStages = { attack = 12, defense = 6, speed = 6, spAttack = 6, spDefense = 6, accuracy = 6, evasion = 6 } })
  check("stat-up family: already at max stage (12) scores -10",
    score(maxedUser, target, swordsDance, Data.MOVE_SWORDS_DANCE) == -10)
  local freshUser = mon({})
  check("stat-up family: room to grow scores 0",
    score(freshUser, target, swordsDance, Data.MOVE_SWORDS_DANCE) == 0)
end

-- Stat-down family: already-zeroed, ability block, and normal case.
do
  local sandAttack = Data.moves[Data.MOVE_SAND_ATTACK] -- EFFECT_ACCURACY_DOWN (23)
  local user = mon({})
  local zeroedTarget = mon({ statStages = { attack = 6, defense = 6, speed = 6, spAttack = 6, spDefense = 6, accuracy = 0, evasion = 6 } })
  check("stat-down family: target already at stage 0 scores -10",
    score(user, zeroedTarget, sandAttack, Data.MOVE_SAND_ATTACK) == -10)
  local clearBodyTarget = mon({ ability = ABILITY_CLEAR_BODY })
  check("stat-down family: Clear Body blocks it, -10",
    score(user, clearBodyTarget, sandAttack, Data.MOVE_SAND_ATTACK) == -10)
  local ordinaryTarget = mon({})
  check("stat-down family: ordinary target scores 0",
    score(user, ordinaryTarget, sandAttack, Data.MOVE_SAND_ATTACK) == 0)
end

-- AI_CBM_OneHitKO: target's higher level blocks it (if_target_higher_level).
do
  local ohko = { effect = 38, power = 1, type = TYPE_NORMAL, accuracy = 30 }
  local lowLevelUser = mon({ level = 10 })
  local higherTarget = mon({ level = 20 })
  check("OHKO vs a higher-level target scores -10",
    score(lowLevelUser, higherTarget, ohko, 9005) == -10)
  local lowerTarget = mon({ level = 5 })
  check("OHKO vs a lower-level target scores 0",
    score(lowLevelUser, lowerTarget, ohko, 9005) == 0)
end

------------------------------------------------------------------------
-- Confirmed-real no-penalty fallback for an unlisted effect
-- (EFFECT_HIT=0, Tackle's real effect id, is genuinely absent from the
-- real ~80-entry if_effect dispatch chain -- data/battle_ai_scripts.s:214's
-- trailing plain `end`).
------------------------------------------------------------------------
do
  local user, target = mon({}), mon({})
  local tackle = Data.moves[Data.MOVE_TACKLE]
  check("EFFECT_HIT (Tackle) is absent from the real dispatch chain: confirmed 0 penalty",
    score(user, target, tackle, Data.MOVE_TACKLE) == 0)
end

------------------------------------------------------------------------
-- Loud-failure path for an in-list-but-unported effect (EFFECT_EXPLOSION,
-- real id 7 -- needs count_alive_pokemon, not modeled by this engine).
------------------------------------------------------------------------
do
  local user, target = mon({}), mon({})
  local explosion = { effect = 7, power = 250, type = TYPE_NORMAL, accuracy = 100 }
  local ok, err = pcall(score, user, target, explosion, 9006)
  check("EFFECT_EXPLOSION (in-list, unported) fails loudly rather than silently no-op'ing",
    not ok and tostring(err):find("EFFECT_EXPLOSION") ~= nil, err)
end

------------------------------------------------------------------------
-- "Confirmed no-op due to unmodeled mechanic" and "always-fires due to
-- structurally-false negation" classes: a couple of representative checks.
------------------------------------------------------------------------
do
  local user, target = mon({}), mon({})
  local mist = { effect = 46, power = 0, type = TYPE_NORMAL, accuracy = 0 }
  check("EFFECT_MIST: SIDE_STATUS_MIST never settable in this engine, confirmed 0",
    score(user, target, mist, 9007) == 0)

  local snore = { effect = 92, power = 40, type = TYPE_NORMAL, accuracy = 100 }
  check("EFFECT_SNORE: user's status1 can never be SLEEP, so \"not asleep\" always fires: -8",
    score(user, target, snore, 9008) == -8)

  local helpingHand = { effect = 176, power = 0, type = TYPE_NORMAL, accuracy = 0 }
  check("EFFECT_HELPING_HAND: this engine is always singles, so \"not double battle\" always fires: -10",
    score(user, target, helpingHand, 9009) == -10)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
