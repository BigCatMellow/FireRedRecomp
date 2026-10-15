-- Run: lua5.1 tests/battle_weather_w3a_test.lua
--
-- Weather slice W3a (work/tasks/phase4-weather-w3a.md). Oracles come from
-- pret/pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788:
--   * Swift Swim/Chlorophyll: GetWhoStrikesFirst src/battle_main.c:3409-3452
--     (WEATHER_HAS_EFFECT multiplier 2 on the RAW stat, then the stage
--     ratio, then paralysis /4); ENDTURN_ORDER src/battle_util.c:484-501
--     reads it live, before the weather case decrements the timer;
--     TryRunFromBattle :4229-4270 uses the raw stat;
--   * Sand Veil: Cmd_accuracycheck src/battle_script_commands.c:1066-1074
--     (stage ratio, Compound Eyes x130/100, Sand Veil x80/100 under
--     WEATHER_HAS_EFFECT and sandstorm, Hustle x80/100, each truncating);
--   * Rain Dish: DoBattlerEndTurnEffects src/battle_util.c:720-743, :774-778
--     (ENDTURN_ABILITIES before ENDTURN_POISON/BURN and ENDTURN_THRASH, per
--     battler, after every field case), AbilityBattleEffects
--     (ABILITYEFFECT_ENDTURN) :1817-1831 (hp != 0, WEATHER_HAS_EFFECT, rain,
--     maxHP > hp, max(1, maxHP/16)); BattleScript_RainDishActivates
--     data/battle_scripts_1.s:3938-3944 (text, then HP); text
--     src/battle_message.c:283;
--   * Cloud Nine/Air Lock: include/battle_util.h:49-50 (HP-gated).
-- Every expected number below is worked from those formulas in the
-- comments, never read back from the engine.
package.path = package.path .. ";./?.lua"

local BattleEngine = require("src.core.BattleEngine")
local BattleFormulas = require("src.core.BattleFormulas")
local BattleSceneController = require("src.core.BattleSceneController")
local S = require("src.core.StatusConditions")
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

local function scriptedRng(values)
  return {
    draws = 0,
    next16 = function(self)
      self.draws = self.draws + 1
      return values[self.draws] or 0
    end,
  }
end

local function rec(effect, power, type_, acc, pp, chance, target, flags)
  return { effect = effect, power = power, type = type_, accuracy = acc, pp = pp,
    secondaryEffectChance = chance, target = target, priority = 0, flags = flags }
end

-- src/data/battle_moves.h records at the pin.
local RAIN_DANCE, SUNNY_DAY, THUNDER, THUNDER_WAVE = 240, 241, 87, 86
local THRASH, SPLASH = 37, 150
local moves = {}
for id, m in pairs(Data.moves) do moves[id] = m end
moves[RAIN_DANCE] = rec(136, 0, Data.TYPE_WATER, 0, 5, 0, 0x10, 0)
moves[SUNNY_DAY] = rec(137, 0, Data.TYPE_FIRE, 0, 5, 0, 0x10, 0)
moves[THUNDER] = rec(152, 120, Data.TYPE_ELECTRIC, 70, 10, 30, 0, 0x12)
moves[THUNDER_WAVE] = rec(67, 0, Data.TYPE_ELECTRIC, 100, 20, 0, 0, 0x16)
moves[THRASH] = rec(27, 90, Data.TYPE_NORMAL, 100, 20, 100, 0x04, 0x33)
moves[SPLASH] = rec(85, 0, Data.TYPE_NORMAL, 0, 40, 0, 0x10, 0)

-- include/constants/abilities.h
local SAND_VEIL, CLOUD_NINE, AIR_LOCK = 8, 13, 77
local COMPOUND_EYES, SWIFT_SWIM, CHLOROPHYLL, RAIN_DISH, HUSTLE = 14, 33, 34, 44, 55
local T = Data

local function moveList(list)
  local out = {}
  for i, id in ipairs(list) do out[i] = { move = id, pp = 10 } end
  return out
end

-- Level 10, attack/defense 20. Default: player faster (30 vs 20), player
-- Psychic, foe Normal, 400 HP so nothing faints unless a test says so.
local function battle(values, opts)
  opts = opts or {}
  local engine = BattleEngine.new({
    player = BattleEngine.makeBattler({ species = 1, level = 10,
      stats = { hp = opts.playerHP or 400, attack = 20, defense = 20,
        speed = opts.playerSpeed or 30, spAttack = 20, spDefense = 20 },
      types = opts.playerTypes or { T.TYPE_PSYCHIC, T.TYPE_PSYCHIC },
      status = opts.playerStatus, moves = moveList(opts.playerMoves or { Data.MOVE_TACKLE }) }),
    foe = BattleEngine.makeBattler({ species = 4, level = 10,
      stats = { hp = opts.foeHP or 400, attack = 20, defense = 20, speed = opts.foeSpeed or 20,
        spAttack = 20, spDefense = 20 },
      types = opts.foeTypes or { T.TYPE_NORMAL, T.TYPE_NORMAL },
      status = opts.foeStatus, moves = moveList(opts.foeMoves or { Data.MOVE_TACKLE }) }),
    moves = moves, typeChart = Data.typeChart, rng = scriptedRng(values),
    hasReplacement = opts.hasReplacement,
  })
  engine.player.ability = opts.playerAbility or 0
  engine.foe.ability = opts.foeAbility or 0
  if opts.playerCurrentHP then engine.player.hp = opts.playerCurrentHP end
  if opts.foeCurrentHP then engine.foe.hp = opts.foeCurrentHP end
  if opts.playerSpeedStage then engine.player.statStages.speed = opts.playerSpeedStage end
  if opts.weather then
    engine.weather = { kind = opts.weather, permanent = false }
    engine.weatherDuration = opts.duration or 5
  end
  return engine
end

local MOVE = { action = "move", moveSlot = 1 }
local MISS = 99 -- misses a 95-accuracy Tackle with one draw
local function types(events)
  local out = {}
  for _, e in ipairs(events) do out[#out + 1] = e.type end
  return table.concat(out, ",")
end
local function find(events, t, side)
  for i, e in ipairs(events) do
    if e.type == t and (side == nil or e.side == side) then return e, i end
  end
end
local function firstOf(events, t)
  for _, e in ipairs(events) do
    if e.type == t then return e.side end
  end
end
local function firstUse(events) return firstOf(events, "useMove") end
local function firstTick(events) return firstOf(events, "statusDamage") end
local POISONED = { playerStatus = S.POISON, foeStatus = S.POISON }
local function with(base, extra)
  local out = {}
  for k, v in pairs(base) do out[k] = v end
  for k, v in pairs(extra or {}) do out[k] = v end
  return out
end

---------------------------------------------------------------------------
-- Swift Swim / Chlorophyll: effectiveSpeed
---------------------------------------------------------------------------
do
  local F = BattleFormulas
  local function mon(speed, ability, stage, status)
    return { speed = speed, ability = ability, statStages = { speed = stage or 6 }, status = status or 0 }
  end
  check("Swift Swim rain: 13 x2 = 26", F.effectiveSpeed(mon(13, SWIFT_SWIM), "rain") == 26)
  check("Chlorophyll sun: 13 x2 = 26", F.effectiveSpeed(mon(13, CHLOROPHYLL), "sun") == 26)
  for _, row in ipairs({ { SWIFT_SWIM, "sun" }, { SWIFT_SWIM, "sandstorm" }, { SWIFT_SWIM, "hail" },
      { SWIFT_SWIM, nil }, { CHLOROPHYLL, "rain" }, { CHLOROPHYLL, "sandstorm" }, { CHLOROPHYLL, "hail" },
      { CHLOROPHYLL, nil }, { 0, "rain" }, { 0, "sun" } }) do
    check("no doubling: ability " .. row[1] .. " in " .. tostring(row[2]),
      F.effectiveSpeed(mon(13, row[1]), row[2]) == 13)
  end
  -- Truncation witnesses: the x2 is on the raw stat, before the ratio.
  -- -1 (10/15): 13*2*10/15 = 260/15 = 17, while 2 * (130/15 = 8) = 16.
  check("x2 before the -1 stage: 17 (not 16)", F.effectiveSpeed(mon(13, SWIFT_SWIM, 5), "rain") == 17,
    F.effectiveSpeed(mon(13, SWIFT_SWIM, 5), "rain"))
  -- +1 (15/10): 7*2*15/10 = 21, while 2 * (105/10 = 10) = 20.
  check("x2 before the +1 stage: 21 (not 20)", F.effectiveSpeed(mon(7, CHLOROPHYLL, 7), "sun") == 21,
    F.effectiveSpeed(mon(7, CHLOROPHYLL, 7), "sun"))
  -- Paralysis /4 comes after: 31*2 = 62, /4 = 15, while 2 * (31/4 = 7) = 14.
  check("x2 before paralysis: 15 (not 14)",
    F.effectiveSpeed(mon(31, SWIFT_SWIM, 6, S.PARALYSIS), "rain") == 15,
    F.effectiveSpeed(mon(31, SWIFT_SWIM, 6, S.PARALYSIS), "rain"))
  check("paralysis without rain: 31/4 = 7", F.effectiveSpeed(mon(31, SWIFT_SWIM, 6, S.PARALYSIS), nil) == 7)
  -- getWhoStrikesFirst threads the weather: 15 x2 = 30 > 20.
  local a, b = mon(15, SWIFT_SWIM), mon(20, 0)
  local r = scriptedRng({})
  check("getWhoStrikesFirst rain: Swift Swim first, no draw",
    F.getWhoStrikesFirst(a, b, nil, nil, r, "rain") == 0 and r.draws == 0)
  check("getWhoStrikesFirst clear: slower, no draw",
    F.getWhoStrikesFirst(a, b, nil, nil, r, nil) == 1 and r.draws == 0)
  -- Priority still wins over doubled speed.
  check("priority beats doubled speed", F.getWhoStrikesFirst(b, a, Data.moves[Data.MOVE_QUICK_ATTACK],
    Data.moves[Data.MOVE_TACKLE], r, "rain") == 0 and r.draws == 0)
  -- Ties: 10 x2 = 20 vs 20 draws once.
  r = scriptedRng({ 1 })
  check("doubled speed ties: one draw", F.getWhoStrikesFirst(mon(10, SWIFT_SWIM), b, nil, nil, r, "rain") == 2
    and r.draws == 1)
end

do
  -- The engine feeds activeWeather(): Cloud Nine/Air Lock suppress, but a
  -- 0-HP holder no longer does.
  for _, ab in ipairs({ CLOUD_NINE, AIR_LOCK }) do
    local b = battle({}, { playerAbility = SWIFT_SWIM, playerSpeed = 10, foeAbility = ab, weather = "rain" })
    check("ability " .. ab .. ": no doubling while the holder stands",
      BattleFormulas.effectiveSpeed(b.player, b:activeWeather()) == 10)
    b.foe.hp = 0
    check("ability " .. ab .. ": a 0-HP holder no longer suppresses",
      BattleFormulas.effectiveSpeed(b.player, b:activeWeather()) == 20)
  end
end

---------------------------------------------------------------------------
-- Turn order through runTurn (turn start and the W0 end-of-turn order)
---------------------------------------------------------------------------
for _, row in ipairs({ { "Swift Swim", SWIFT_SWIM, "rain" }, { "Chlorophyll", CHLOROPHYLL, "sun" } }) do
  local name, ability, kind = row[1], row[2], row[3]
  -- 15 x2 = 30 > 20: the holder moves and ticks first; 2 miss draws only.
  local b = battle({ MISS, MISS }, with(POISONED, { playerAbility = ability, playerSpeed = 15, weather = kind }))
  local events = b:runTurn(MOVE, MOVE)
  check(name .. ": doubled holder moves first", firstUse(events) == "player", types(events))
  check(name .. ": doubled holder ticks first", firstTick(events) == "player", types(events))
  check(name .. ": no tie draws (2)", b.rng.draws == 2, b.rng.draws)
  -- Clear weather: 15 < 20.
  b = battle({ MISS, MISS }, with(POISONED, { playerAbility = ability, playerSpeed = 15 }))
  events = b:runTurn(MOVE, MOVE)
  check(name .. ": clear weather, foe first both times", firstUse(events) == "foe"
    and firstTick(events) == "foe" and b.rng.draws == 2, b.rng.draws)
  -- The other weathers do nothing for this ability.
  for _, other in ipairs({ "rain", "sun", "sandstorm", "hail" }) do
    if other ~= kind then
      b = battle({ MISS, MISS }, with(POISONED, { playerAbility = ability, playerSpeed = 15, weather = other }))
      events = b:runTurn(MOVE, MOVE)
      check(name .. " in " .. other .. ": not doubled", firstUse(events) == "foe"
        and firstTick(events) == "foe" and b.rng.draws == 2, b.rng.draws)
    end
  end

  -- Creating a tie: 10 x2 = 20 == 20. Turn start draws, then two misses,
  -- then ENDTURN_ORDER draws again (W0).
  for _, d in ipairs({ { 1, 0 }, { 0, 1 } }) do
    b = battle({ d[1], MISS, MISS, d[2] }, with(POISONED, { playerAbility = ability, playerSpeed = 10,
      weather = kind }))
    events = b:runTurn(MOVE, MOVE)
    check(name .. " creates a tie: turn-start draw " .. d[1] .. " decides the action order",
      firstUse(events) == (d[1] == 0 and "player" or "foe"), types(events))
    check(name .. " creates a tie: end-of-turn draw " .. d[2] .. " decides the tick order",
      firstTick(events) == (d[2] == 0 and "player" or "foe"), types(events))
    check(name .. " creates a tie: exactly 4 draws", b.rng.draws == 4, b.rng.draws)
  end
  b = battle({ MISS, MISS }, with(POISONED, { playerAbility = ability, playerSpeed = 10 }))
  events = b:runTurn(MOVE, MOVE)
  check(name .. ": no tie in clear weather (10 vs 20, 2 draws)", firstUse(events) == "foe"
    and firstTick(events) == "foe" and b.rng.draws == 2, b.rng.draws)

  -- Removing a tie: 20 x2 = 40 vs 20, no draws at either point.
  b = battle({ MISS, MISS }, with(POISONED, { playerAbility = ability, playerSpeed = 20, weather = kind }))
  events = b:runTurn(MOVE, MOVE)
  check(name .. " removes a tie: player first, 2 draws", firstUse(events) == "player"
    and firstTick(events) == "player" and b.rng.draws == 2, b.rng.draws)
  b = battle({ 1, MISS, MISS, 1 }, with(POISONED, { playerAbility = ability, playerSpeed = 20 }))
  events = b:runTurn(MOVE, MOVE)
  check(name .. ": the same speeds tie in clear weather (4 draws)", firstUse(events) == "foe"
    and firstTick(events) == "foe" and b.rng.draws == 4, b.rng.draws)

  -- Cloud Nine / Air Lock on the foe: no doubling, so 10 vs 20 has no tie
  -- and 20 vs 20 ties at both points.
  for _, ab in ipairs({ CLOUD_NINE, AIR_LOCK }) do
    b = battle({ MISS, MISS }, with(POISONED, { playerAbility = ability, playerSpeed = 10, weather = kind,
      foeAbility = ab }))
    events = b:runTurn(MOVE, MOVE)
    check(name .. " vs ability " .. ab .. ": 10 vs 20, foe first, 2 draws", firstUse(events) == "foe"
      and firstTick(events) == "foe" and b.rng.draws == 2, b.rng.draws)
    b = battle({ 0, MISS, MISS, 1 }, with(POISONED, { playerAbility = ability, playerSpeed = 20, weather = kind,
      foeAbility = ab }))
    events = b:runTurn(MOVE, MOVE)
    check(name .. " vs ability " .. ab .. ": 20 vs 20 ties (4 draws)", firstUse(events) == "player"
      and firstTick(events) == "foe" and b.rng.draws == 4, b.rng.draws)
  end
end

do
  -- The foe can hold it too: foe Swift Swim 15 x2 = 30 > player 20.
  local b = battle({ MISS, MISS }, with(POISONED, { foeAbility = SWIFT_SWIM, foeSpeed = 15, playerSpeed = 20,
    weather = "rain" }))
  local events = b:runTurn(MOVE, MOVE)
  check("foe Swift Swim: foe first at both points, 2 draws", firstUse(events) == "foe"
    and firstTick(events) == "foe" and b.rng.draws == 2, b.rng.draws)
end

do
  -- Truncation witness through runTurn: 13 at -1 in rain is 17 (tie with
  -- 17, two draws); 2 x staged would be 16 (no tie, no draws).
  local b = battle({ 1, MISS, MISS, 0 }, with(POISONED, { playerAbility = SWIFT_SWIM, playerSpeed = 13,
    playerSpeedStage = 5, foeSpeed = 17, weather = "rain" }))
  local events = b:runTurn(MOVE, MOVE)
  check("13 at -1 doubled = 17 ties 17: 4 draws", b.rng.draws == 4 and firstUse(events) == "foe"
    and firstTick(events) == "player", b.rng.draws)
end

do
  -- W0 reads the weather live: the faster foe's Rain Dance this turn
  -- doubles the player's 10 at ENDTURN_ORDER (20 == 20), so the end of turn
  -- draws although turn start did not. Foe Rain Dance (no draws), player
  -- miss (1), end-of-turn tie (1).
  for _, d in ipairs({ 0, 1 }) do
    local b = battle({ MISS, d }, with(POISONED, { playerAbility = SWIFT_SWIM, playerSpeed = 10,
      foeMoves = { RAIN_DANCE } }))
    local events = b:runTurn(MOVE, MOVE)
    check("same-turn Rain Dance: foe acted first", firstUse(events) == "foe" and find(events, "weatherSet"),
      types(events))
    check("same-turn Rain Dance: end-of-turn draw " .. d .. " decides the tick order",
      firstTick(events) == (d == 0 and "player" or "foe"), types(events))
    check("same-turn Rain Dance: 2 draws", b.rng.draws == 2, b.rng.draws)
  end
  -- Sunny Day from the player itself (Chlorophyll 10, faster foe 20).
  local b = battle({ MISS, 1 }, with(POISONED, { playerAbility = CHLOROPHYLL, playerSpeed = 10,
    playerMoves = { SUNNY_DAY } }))
  local events = b:runTurn(MOVE, MOVE)
  check("own Sunny Day: end-of-turn tie draw (foe miss + tie = 2)", b.rng.draws == 2
    and firstUse(events) == "foe" and firstTick(events) == "foe", b.rng.draws)
end

do
  -- ENDTURN_ORDER precedes the weather case: on rain's last turn the
  -- doubling still counts at end of turn, then the rain stops.
  local b = battle({ 0, MISS, MISS, 1 }, with(POISONED, { playerAbility = SWIFT_SWIM, playerSpeed = 10,
    weather = "rain", duration = 1 }))
  local events = b:runTurn(MOVE, MOVE)
  check("last rain turn: still a tie at end of turn (4 draws)", b.rng.draws == 4
    and firstUse(events) == "player" and firstTick(events) == "foe", b.rng.draws)
  check("last rain turn: the rain stopped", find(events, "weatherEnded") and b.weather.kind == nil,
    types(events))
  b.rng = scriptedRng({ MISS, MISS })
  events = b:runTurn(MOVE, MOVE)
  check("after the rain: 10 vs 20, no draws", b.rng.draws == 2 and firstUse(events) == "foe"
    and firstTick(events) == "foe", b.rng.draws)
end

---------------------------------------------------------------------------
-- Paralysis
---------------------------------------------------------------------------
do
  -- Paralyzed Swift Swim 31 in rain: 62/4 = 15 == 15 (tie). Draws: turn
  -- start, the paralysis % 4 (1: acts), player miss, foe miss, end of turn.
  local b = battle({ 0, 1, MISS, MISS, 0 }, { playerAbility = SWIFT_SWIM, playerSpeed = 31, foeSpeed = 15,
    playerStatus = S.PARALYSIS, weather = "rain" })
  local events = b:runTurn(MOVE, MOVE)
  check("paralyzed Swift Swim ties 15: 5 draws, player first", b.rng.draws == 5
    and firstUse(events) == "player", b.rng.draws)
  b = battle({ 1, MISS, 1, MISS, 0 }, { playerAbility = SWIFT_SWIM, playerSpeed = 31, foeSpeed = 15,
    playerStatus = S.PARALYSIS, weather = "rain" })
  events = b:runTurn(MOVE, MOVE)
  check("paralyzed Swift Swim ties 15: draw 1 puts the foe first (5 draws)", b.rng.draws == 5
    and firstUse(events) == "foe", b.rng.draws)
  -- Clear weather: 31/4 = 7 < 15, no tie draws: foe miss, % 4, player miss.
  b = battle({ MISS, 1, MISS }, { playerAbility = SWIFT_SWIM, playerSpeed = 31, foeSpeed = 15,
    playerStatus = S.PARALYSIS })
  events = b:runTurn(MOVE, MOVE)
  check("paralyzed in clear weather: 7 vs 15, 3 draws", b.rng.draws == 3 and firstUse(events) == "foe",
    b.rng.draws)
end

do
  -- Paralysis applied mid-turn (W0): Swift Swim 20 in rain = 40 vs 10;
  -- the foe's Thunder Wave makes it 40/4 = 10 == 10 at end of turn.
  -- Draws: player miss, Thunder Wave accuracy, end-of-turn tie.
  local b = battle({ MISS, 0, 1 }, { playerAbility = SWIFT_SWIM, playerSpeed = 20, foeSpeed = 10,
    foeMoves = { THUNDER_WAVE }, weather = "rain" })
  local events = b:runTurn(MOVE, MOVE)
  check("mid-turn Thunder Wave on doubled 20: end-of-turn tie (3 draws)", S.isParalyzed(b.player.status)
    and find(events, "statusApplied", "player") and b.rng.draws == 3, b.rng.draws)
  -- Clear weather: 20/4 = 5 vs 10, no tie.
  b = battle({ MISS, 0 }, { playerAbility = SWIFT_SWIM, playerSpeed = 20, foeSpeed = 10,
    foeMoves = { THUNDER_WAVE } })
  events = b:runTurn(MOVE, MOVE)
  check("mid-turn Thunder Wave in clear weather: no tie (2 draws)", S.isParalyzed(b.player.status)
    and b.rng.draws == 2, b.rng.draws)
end

do
  -- Run odds use the raw stat (TryRunFromBattle): Swift Swim 15 in rain
  -- still runs slower than 20, so the escape roll is drawn.
  -- speedVar = 15*128/20 + 0 = 96; Random() & 0xFF = 200 > 96 fails.
  local b = battle({ 200, MISS }, { playerAbility = SWIFT_SWIM, playerSpeed = 15, weather = "rain" })
  local events = b:runTurn({ action = "run" }, MOVE)
  check("run odds ignore Swift Swim: escape roll drawn and failed", b.outcome == nil
    and b.rng.draws == 2, types(events))
end

---------------------------------------------------------------------------
-- Sand Veil accuracy
---------------------------------------------------------------------------
do
  local F = BattleFormulas
  local function acc(accuracy, roll, ability, moveType, sandVeil)
    return F.accuracyCheck(accuracy, 6, 6, scriptedRng({ roll }), ability, moveType, sandVeil)
  end
  -- 95 * 80 / 100 = 76: roll value 75 (76) hits, 76 (77) misses.
  check("Sand Veil 95 -> 76: 76 hits", acc(95, 75, nil, nil, true))
  check("Sand Veil 95 -> 76: 77 misses", not acc(95, 76, nil, nil, true))
  check("no Sand Veil: 77 hits 95", acc(95, 76, nil, nil, false))
  -- Order against Compound Eyes (accuracy 75): CE first gives
  -- 75*130/100 = 97, then *80/100 = 77; Sand Veil first would give 60 then
  -- 78. So 77 hits and 78 misses.
  check("Compound Eyes then Sand Veil: 77 hits", acc(75, 76, COMPOUND_EYES, nil, true))
  check("Compound Eyes then Sand Veil: 78 misses (not 78)", not acc(75, 77, COMPOUND_EYES, nil, true))
  check("Compound Eyes alone: 97 hits", acc(75, 96, COMPOUND_EYES, nil, false))
  -- Hustle (physical): 75 -> 60 -> 48.
  check("Sand Veil then Hustle: 48 hits", acc(75, 47, HUSTLE, T.TYPE_NORMAL, true))
  check("Sand Veil then Hustle: 49 misses", not acc(75, 48, HUSTLE, T.TYPE_NORMAL, true))
  -- Hustle on a special type: Sand Veil only, 60.
  check("Sand Veil, Hustle special: 60 hits", acc(75, 59, HUSTLE, T.TYPE_WATER, true))
  check("Sand Veil, Hustle special: 61 misses", not acc(75, 60, HUSTLE, T.TYPE_WATER, true))
  -- After the stage ratio: +1 (133/100): 75*133/100 = 99, *80/100 = 79.
  check("Sand Veil after the +1 stage: 79 hits",
    F.accuracyCheck(75, 7, 6, scriptedRng({ 78 }), nil, nil, true))
  check("Sand Veil after the +1 stage: 80 misses",
    not F.accuracyCheck(75, 7, 6, scriptedRng({ 79 }), nil, nil, true))
end

do
  -- Through the engine: player Tackle at the Sand Veil foe in a sandstorm.
  -- Hit: accuracy, crit, damage, then the foe's miss (4 draws).
  local b = battle({ 75, 1, 0, MISS }, { foeAbility = SAND_VEIL, weather = "sandstorm" })
  local events = b:runTurn(MOVE, MOVE)
  check("Sand Veil in sand: 76 hits", find(events, "damage", "player") and b.rng.draws == 4, types(events))
  b = battle({ 76, MISS }, { foeAbility = SAND_VEIL, weather = "sandstorm" })
  events = b:runTurn(MOVE, MOVE)
  check("Sand Veil in sand: 77 misses (2 draws)", find(events, "miss", "player")
    and not find(events, "damage", "player") and b.rng.draws == 2, types(events))
  -- Other weathers and clear: 95.
  for _, kind in ipairs({ "rain", "sun", "hail", false }) do
    b = battle({ 76, 1, 0, MISS }, { foeAbility = SAND_VEIL, weather = kind or nil })
    events = b:runTurn(MOVE, MOVE)
    check("Sand Veil in " .. tostring(kind) .. ": 77 hits (95)", find(events, "damage", "player")
      and b.rng.draws == 4, types(events))
  end
  -- Cloud Nine / Air Lock (the attacker holds it): 95.
  for _, ab in ipairs({ CLOUD_NINE, AIR_LOCK }) do
    b = battle({ 76, 1, 0, MISS }, { foeAbility = SAND_VEIL, playerAbility = ab, weather = "sandstorm" })
    events = b:runTurn(MOVE, MOVE)
    check("Sand Veil under ability " .. ab .. ": 77 hits", find(events, "damage", "player")
      and b.rng.draws == 4, types(events))
  end
  -- The holder's own accuracy is not reduced.
  b = battle({ 76, 1, 0, MISS }, { playerAbility = SAND_VEIL, weather = "sandstorm" })
  events = b:runTurn(MOVE, MOVE)
  check("Sand Veil holder attacking: 77 hits", find(events, "damage", "player") and b.rng.draws == 4,
    types(events))
  -- The foe attacking a Sand Veil player: miss first, then 77 misses / 76 hits.
  b = battle({ MISS, 76 }, { playerAbility = SAND_VEIL, weather = "sandstorm" })
  events = b:runTurn(MOVE, MOVE)
  check("foe vs Sand Veil player: 77 misses (2 draws)", find(events, "miss", "foe") and b.rng.draws == 2,
    types(events))
  b = battle({ MISS, 75, 1, 0 }, { playerAbility = SAND_VEIL, weather = "sandstorm" })
  events = b:runTurn(MOVE, MOVE)
  check("foe vs Sand Veil player: 76 hits (4 draws)", find(events, "damage", "foe") and b.rng.draws == 4,
    types(events))
  -- Thunder in sand: 70 * 80 / 100 = 56. Hit: accuracy, crit, damage,
  -- seteffect (99: no paralysis), then the foe's miss.
  b = battle({ 55, 1, 0, 99, MISS }, { foeAbility = SAND_VEIL, weather = "sandstorm", playerMoves = { THUNDER } })
  events = b:runTurn(MOVE, MOVE)
  check("Thunder vs Sand Veil: 56 hits (5 draws)", find(events, "damage", "player") and b.rng.draws == 5,
    types(events))
  b = battle({ 56, MISS }, { foeAbility = SAND_VEIL, weather = "sandstorm", playerMoves = { THUNDER } })
  events = b:runTurn(MOVE, MOVE)
  check("Thunder vs Sand Veil: 57 misses (2 draws)", find(events, "miss", "player") and b.rng.draws == 2,
    types(events))
  -- A status move rolls the same threshold: Thunder Wave 100 -> 80.
  b = battle({ 80, MISS }, { foeAbility = SAND_VEIL, weather = "sandstorm", playerMoves = { THUNDER_WAVE } })
  events = b:runTurn(MOVE, MOVE)
  check("Thunder Wave vs Sand Veil: 81 misses", find(events, "miss", "player")
    and not S.isParalyzed(b.foe.status) and b.rng.draws == 2, types(events))
  b = battle({ 79, MISS }, { foeAbility = SAND_VEIL, weather = "sandstorm", playerMoves = { THUNDER_WAVE } })
  events = b:runTurn(MOVE, MOVE)
  check("Thunder Wave vs Sand Veil: 80 paralyzes", S.isParalyzed(b.foe.status), types(events))
end

---------------------------------------------------------------------------
-- Rain Dish
---------------------------------------------------------------------------
do
  -- 300/400 in rain: +400/16 = 25 after the weather text. 2 miss draws.
  local b = battle({ MISS, MISS }, { playerAbility = RAIN_DISH, playerCurrentHP = 300, weather = "rain" })
  local events = b:runTurn(MOVE, MOVE)
  local e, ei = find(events, "rainDish", "player")
  local _, ci = find(events, "weatherContinues")
  check("Rain Dish heals 25", e and e.amount == 25 and e.hpRemaining == 325 and b.player.hp == 325,
    types(events))
  check("Rain Dish after the weather text", ci and ei and ci < ei, types(events))
  check("Rain Dish: no draws (2)", b.rng.draws == 2, b.rng.draws)
  -- Full HP: nothing, no text.
  b = battle({ MISS, MISS }, { playerAbility = RAIN_DISH, weather = "rain" })
  events = b:runTurn(MOVE, MOVE)
  check("Rain Dish at full HP: no event", not find(events, "rainDish") and b.player.hp == 400
    and b.rng.draws == 2, types(events))
  -- Clamp: 390/400 heals 10.
  b = battle({ MISS, MISS }, { playerAbility = RAIN_DISH, playerCurrentHP = 390, weather = "rain" })
  events = b:runTurn(MOVE, MOVE)
  e = find(events, "rainDish", "player")
  check("Rain Dish clamps to maxHP (10)", e and e.amount == 10 and b.player.hp == 400, e and e.amount)
  -- Minimum 1: maxHP 15 -> 15/16 = 0 -> 1.
  b = battle({ MISS, MISS }, { playerAbility = RAIN_DISH, playerHP = 15, playerCurrentHP = 10, weather = "rain" })
  events = b:runTurn(MOVE, MOVE)
  e = find(events, "rainDish", "player")
  check("Rain Dish minimum 1", e and e.amount == 1 and b.player.hp == 11, e and e.amount)
  -- Odd maxHP: 47/16 = 2.
  b = battle({ MISS, MISS }, { playerAbility = RAIN_DISH, playerHP = 47, playerCurrentHP = 20, weather = "rain" })
  events = b:runTurn(MOVE, MOVE)
  e = find(events, "rainDish", "player")
  check("Rain Dish floor(47/16) = 2", e and e.amount == 2 and b.player.hp == 22, e and e.amount)
  -- The foe holds it.
  b = battle({ MISS, MISS }, { foeAbility = RAIN_DISH, foeCurrentHP = 100, weather = "rain" })
  events = b:runTurn(MOVE, MOVE)
  e = find(events, "rainDish", "foe")
  check("foe Rain Dish heals 25", e and e.amount == 25 and b.foe.hp == 125, types(events))
  -- Not in other weathers.
  for _, kind in ipairs({ "sun", "sandstorm", "hail", false }) do
    b = battle({ MISS, MISS }, { playerAbility = RAIN_DISH, playerCurrentHP = 300, weather = kind or nil })
    events = b:runTurn(MOVE, MOVE)
    check("no Rain Dish in " .. tostring(kind), not find(events, "rainDish") and b.rng.draws == 2,
      types(events))
  end
  -- Rain ending this turn: the weather case clears it before any battler
  -- case, so no heal.
  b = battle({ MISS, MISS }, { playerAbility = RAIN_DISH, playerCurrentHP = 300, weather = "rain", duration = 1 })
  events = b:runTurn(MOVE, MOVE)
  check("rain stopped this turn: no Rain Dish", find(events, "weatherEnded") and not find(events, "rainDish")
    and b.player.hp == 300, types(events))
  -- Rain set this turn: heals at this end of turn. Player Rain Dance
  -- (no draws), foe miss (1).
  b = battle({ MISS }, { playerAbility = RAIN_DISH, playerCurrentHP = 300, playerMoves = { RAIN_DANCE } })
  events = b:runTurn(MOVE, MOVE)
  check("same-turn Rain Dance: Rain Dish heals", find(events, "rainDish", "player") and b.player.hp == 325
    and b.rng.draws == 1, types(events))
end

do
  -- Cloud Nine / Air Lock on the foe suppress it.
  for _, ab in ipairs({ CLOUD_NINE, AIR_LOCK }) do
    local b = battle({ MISS, MISS }, { playerAbility = RAIN_DISH, playerCurrentHP = 300, foeAbility = ab,
      weather = "rain" })
    local events = b:runTurn(MOVE, MOVE)
    check("Rain Dish under ability " .. ab .. ": no heal, timer and text continue",
      not find(events, "rainDish") and find(events, "weatherContinues") and b.player.hp == 300
        and b.rng.draws == 2, types(events))
  end
  -- A Cloud Nine holder that faints earlier in the battler phase no longer
  -- suppresses (WEATHER_HAS_EFFECT is re-evaluated per battler). Foe
  -- faster (40), poisoned at 10 HP (50 lethal), replacement pending.
  local b = battle({ MISS, MISS }, { playerAbility = RAIN_DISH, playerCurrentHP = 300, foeAbility = CLOUD_NINE,
    foeSpeed = 40, foeStatus = S.POISON, foeCurrentHP = 10, weather = "rain",
    hasReplacement = function(side) return side == "foe" end })
  local events = b:runTurn(MOVE, MOVE)
  local _, fi = find(events, "faint", "foe")
  local e, ei = find(events, "rainDish", "player")
  check("Cloud Nine holder fainted first: Rain Dish heals afterwards", fi and e and fi < ei
    and b.player.hp == 325 and b.rng.draws == 2, types(events))
  -- Player faster: its Rain Dish runs while the holder still stands.
  b = battle({ MISS, MISS }, { playerAbility = RAIN_DISH, playerCurrentHP = 300, foeAbility = CLOUD_NINE,
    foeStatus = S.POISON, foeCurrentHP = 10, weather = "rain",
    hasReplacement = function(side) return side == "foe" end })
  events = b:runTurn(MOVE, MOVE)
  check("Cloud Nine holder faints after: no Rain Dish", find(events, "faint", "foe")
    and not find(events, "rainDish") and b.player.hp == 300 and b.rng.draws == 2, types(events))
end

do
  -- Order versus status damage: per battler, Rain Dish then poison
  -- (ENDTURN_ABILITIES before ENDTURN_POISON), battlers in ENDTURN_ORDER.
  local b = battle({ MISS, MISS }, with(POISONED, { playerAbility = RAIN_DISH, playerCurrentHP = 300,
    weather = "rain" }))
  local events = b:runTurn(MOVE, MOVE)
  local _, ci = find(events, "weatherContinues")
  local _, ri = find(events, "rainDish", "player")
  local _, pi = find(events, "statusDamage", "player")
  local _, fi = find(events, "statusDamage", "foe")
  check("player faster: text, Rain Dish, player poison, foe poison", ci and ri and pi and fi
    and ci < ri and ri < pi and pi < fi, types(events))
  check("heal then poison: 300 + 25 - 50 = 275", b.player.hp == 275, b.player.hp)
  -- Foe faster: the foe's poison comes before the player's Rain Dish.
  b = battle({ MISS, MISS }, with(POISONED, { playerAbility = RAIN_DISH, playerCurrentHP = 300,
    weather = "rain", foeSpeed = 40 }))
  events = b:runTurn(MOVE, MOVE)
  _, ri = find(events, "rainDish", "player")
  _, pi = find(events, "statusDamage", "player")
  _, fi = find(events, "statusDamage", "foe")
  check("foe faster: foe poison, Rain Dish, player poison", ri and pi and fi and fi < ri and ri < pi,
    types(events))
  -- Burn: at full HP there is no heal, only the burn (400/8 = 50); the
  -- next turn at 350 heals before the burn.
  b = battle({ MISS, MISS }, { playerAbility = RAIN_DISH, playerStatus = S.BURN, weather = "rain" })
  events = b:runTurn(MOVE, MOVE)
  check("full HP and burned: no heal, burn 50", not find(events, "rainDish") and b.player.hp == 350,
    types(events))
  b.rng = scriptedRng({ MISS, MISS })
  events = b:runTurn(MOVE, MOVE)
  _, ri = find(events, "rainDish", "player")
  _, pi = find(events, "statusDamage", "player")
  check("next turn at 350: heal 25 before the burn", ri and pi and ri < pi and b.player.hp == 325,
    types(events))
  -- Both hold it: ENDTURN_ORDER decides who heals first (tie draw at both
  -- points: 0 at turn start, 1 at end of turn -> foe first).
  b = battle({ 0, MISS, MISS, 1 }, { playerAbility = RAIN_DISH, foeAbility = RAIN_DISH, playerCurrentHP = 300,
    foeCurrentHP = 300, playerSpeed = 20, weather = "rain" })
  events = b:runTurn(MOVE, MOVE)
  check("both hold Rain Dish: end-of-turn draw 1 heals the foe first (4 draws)",
    firstOf(events, "rainDish") == "foe" and b.rng.draws == 4, types(events))
  -- Swift Swim's rain doubling decides a Rain Dish order: foe Swift Swim 15
  -- x2 = 30 > 20, so the foe's poison precedes the player's Rain Dish.
  b = battle({ MISS, MISS }, with(POISONED, { playerAbility = RAIN_DISH, playerCurrentHP = 300, playerSpeed = 20,
    foeAbility = SWIFT_SWIM, foeSpeed = 15, weather = "rain" }))
  events = b:runTurn(MOVE, MOVE)
  _, ri = find(events, "rainDish", "player")
  _, fi = find(events, "statusDamage", "foe")
  check("foe Swift Swim ticks before the player's Rain Dish", ri and fi and fi < ri and b.rng.draws == 2,
    types(events))
end

do
  -- A decided battle stops before the second battler's Rain Dish: the
  -- faster foe's lethal poison wins the battle.
  local b = battle({ MISS, MISS }, { playerAbility = RAIN_DISH, playerCurrentHP = 300, foeSpeed = 40,
    foeStatus = S.POISON, foeCurrentHP = 10, weather = "rain" })
  local events = b:runTurn(MOVE, MOVE)
  check("decided battle: no Rain Dish afterwards", b.outcome == "playerWon" and not find(events, "rainDish"),
    types(events))
  -- A 0-HP holder is skipped (direct phase call).
  b = battle({}, { playerAbility = RAIN_DISH, weather = "rain" })
  b.player.hp = 0
  events = {}
  b:resolveStatusEndTurn(events, { "player", "foe" })
  check("0-HP holder: no Rain Dish", #events == 0 and b.player.hp == 0, types(events))
end

do
  -- Rain Dish before the rampage tick (ENDTURN_ABILITIES before
  -- ENDTURN_THRASH). Poisoned Rain Dish player, Thrash; foe Splash (no
  -- draws). Turn 1: accuracy, crit, damage, seteffect, `& 1` (0: 2 turns).
  local b = battle({ 0, 1, 0, 0, 0 }, { playerAbility = RAIN_DISH, playerCurrentHP = 300,
    playerStatus = S.POISON, playerMoves = { THRASH }, foeMoves = { SPLASH }, weather = "rain" })
  local events = b:runTurn(MOVE, MOVE)
  check("Thrash turn 1: 5 draws, heal 25 then poison 50", b.rng.draws == 5 and b.player.hp == 275
    and b.player.rampageTurns == 1, b.rng.draws)
  -- Turn 2: the locked hit (4 draws), then Rain Dish, poison, and the
  -- fatigue confusion with its % 4 (2: 4 turns).
  b.rng = scriptedRng({ 0, 1, 0, 0, 2 })
  events = b:runTurn(MOVE, MOVE)
  local _, ri = find(events, "rainDish", "player")
  local _, pi = find(events, "statusDamage", "player")
  local _, ci = find(events, "fatigueConfusion", "player")
  check("Rain Dish, then poison, then the fatigue confusion", ri and pi and ci and ri < pi and pi < ci,
    types(events))
  check("turn 2: 5 draws, 275 + 25 - 50 = 250, confused 4", b.rng.draws == 5 and b.player.hp == 250
    and b.player.confusionTurns == 4, b.rng.draws)
end

---------------------------------------------------------------------------
-- Controller text
---------------------------------------------------------------------------
do
  local c = BattleSceneController.new({ engine = battle({}), playerName = "LOTAD", foeName = "RATTATA",
    moveName = function() return "TACKLE" end })
  local m = c:_eventMessages({ { type = "rainDish", side = "player", amount = 25, hpRemaining = 325 } })
  check("Rain Dish text then HP", m[1] and m[1].text == "LOTAD's RAIN DISH\nrestored its HP a little!"
    and m[2] and m[2].text == nil and m[2].hpSide == "player" and m[2].hp == 325, m[1] and m[1].text)

  -- Through the real engine.
  local b = battle({ MISS, MISS }, { playerAbility = RAIN_DISH, playerCurrentHP = 300, weather = "rain" })
  c = BattleSceneController.new({ engine = b, playerName = "LOTAD", foeName = "RATTATA",
    moveName = function() return "TACKLE" end })
  local events = b:runTurn(MOVE, MOVE)
  local texts = {}
  for _, e in ipairs(c:_eventMessages(events)) do if e.text then texts[#texts + 1] = e.text end end
  local n = #texts
  check("engine -> controller: rain text, then the Rain Dish text last",
    texts[n - 1] == "Rain continues to fall." and texts[n] == "LOTAD's RAIN DISH\nrestored its HP a little!",
    table.concat(texts, "|"))
end

print(("battle_weather_w3a_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
