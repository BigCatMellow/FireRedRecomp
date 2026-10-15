-- Run: lua5.1 tests/battle_weather_w3b_test.lua
--
-- Weather slice W3b (work/tasks/phase4-weather-w3b.md). Oracles come from
-- pret/pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788:
--   * AbilityBattleEffects(ABILITYEFFECT_ON_SWITCHIN) src/battle_util.c
--     :1704-1815: Drizzle (:1748-1756) sets RAIN_PERMANENT|RAIN_TEMPORARY
--     unless RAIN_PERMANENT is set; Sand Stream (:1757-1765) and Drought
--     (:1766-1774) assign B_WEATHER_SANDSTORM / B_WEATHER_SUN (both bits)
--     unless their permanent bit is set. Whole-word assignment (overwrites
--     any other family), weatherDuration untouched, no WEATHER_HAS_EFFECT
--     test, no RNG. Cloud Nine/Air Lock (:1798-1813) only re-check Castform.
--   * TryDoEventsBeforeFirstTurn src/battle_main.c:2856-2927: order by
--     GetWhoStrikesFirst(.., TRUE) once (:2864-2872; the tie's Random() & 1
--     is deferred by design decision D3: ties go player first, no draw),
--     then ON_SWITCHIN fastest first (:2879-2887). The slower setter wins.
--   * Cmd_switchineffects src/battle_script_commands.c:4961-5010, reached by
--     BattleScript_ActionSwitch (data/battle_scripts_1.s:3046-3078, before
--     the foe's move) and BattleScript_HandleFaintedMon (:2824-2884, after
--     the send-out text).
--   * Texts src/battle_message.c:263, :284, :285 with gAbilityNames
--     (src/data/text/abilities.h:166, :209, :234); scripts
--     data/battle_scripts_1.s:3918-3924, :3946-3952, :4013-4019.
-- Every expected number below is worked from those rules in the comments,
-- never read back from the engine.
package.path = package.path .. ";./?.lua"

local BattleEngine = require("src.core.BattleEngine")
local BattleSceneController = require("src.core.BattleSceneController")
local TrainerBattleOrchestrator = require("src.core.TrainerBattleOrchestrator")
local InputState = require("src.core.InputState")
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
local RAIN_DANCE, SUNNY_DAY, SPLASH = 240, 241, 150
local moves = {}
for id, m in pairs(Data.moves) do moves[id] = m end
moves[RAIN_DANCE] = rec(136, 0, Data.TYPE_WATER, 0, 5, 0, 0x10, 0)
moves[SUNNY_DAY] = rec(137, 0, Data.TYPE_FIRE, 0, 5, 0, 0x10, 0)
moves[SPLASH] = rec(85, 0, Data.TYPE_NORMAL, 0, 40, 0, 0x10, 0)

-- include/constants/abilities.h
local DRIZZLE, CLOUD_NINE, SAND_STREAM, DROUGHT, AIR_LOCK = 2, 13, 45, 70, 77
local SWIFT_SWIM = 33
local T = Data
local P, F = "player", "foe"

local function moveList(list)
  local out = {}
  for i, id in ipairs(list) do out[i] = { move = id, pp = 10 } end
  return out
end

local function mon(opts)
  local b = BattleEngine.makeBattler({ species = opts.species or 1, level = 10,
    stats = { hp = opts.hp or 400, attack = 20, defense = 20, speed = opts.speed or 30,
      spAttack = 20, spDefense = 20 },
    types = opts.types or { T.TYPE_PSYCHIC, T.TYPE_PSYCHIC },
    status = opts.status, moves = moveList(opts.moves or { Data.MOVE_TACKLE }) })
  b.ability = opts.ability or 0
  if opts.currentHP then b.hp = opts.currentHP end
  return b
end

-- Default: player faster (30 vs 20), player Psychic, foe Normal, 400 HP.
local function battle(values, opts)
  opts = opts or {}
  local engine = BattleEngine.new({
    player = mon({ species = 1, hp = opts.playerHP, speed = opts.playerSpeed or 30,
      types = opts.playerTypes, status = opts.playerStatus, moves = opts.playerMoves,
      ability = opts.playerAbility, currentHP = opts.playerCurrentHP }),
    foe = mon({ species = 4, hp = opts.foeHP, speed = opts.foeSpeed or 20,
      types = opts.foeTypes or { T.TYPE_NORMAL, T.TYPE_NORMAL }, status = opts.foeStatus,
      moves = opts.foeMoves, ability = opts.foeAbility, currentHP = opts.foeCurrentHP }),
    moves = moves, typeChart = Data.typeChart, rng = scriptedRng(values),
    hasReplacement = opts.hasReplacement,
  })
  if opts.weather then
    engine.weather = { kind = opts.weather, permanent = opts.permanent == true }
    engine.weatherDuration = opts.duration or 5
  end
  return engine
end

local MOVE = { action = "move", moveSlot = 1 }
local MISS = 99 -- 99 % 100 + 1 = 100 > 95: misses a Tackle with one draw
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
local function count(events, t)
  local n = 0
  for _, e in ipairs(events) do if e.type == t then n = n + 1 end end
  return n
end
local function weatherIs(engine, kind, permanent)
  return engine.weather.kind == kind and engine.weather.permanent == permanent
end
local function texts(controller)
  local out = {}
  for _, entry in ipairs(controller.messages) do
    if entry.text then out[#out + 1] = entry.text end
  end
  return out
end
local function press(controller, key)
  local input = InputState.new()
  input:update(0)
  input:update(key)
  controller:processInput(input)
end

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------
check("ability ids", BattleEngine.ABILITY_DRIZZLE == 2 and BattleEngine.ABILITY_SAND_STREAM == 45
  and BattleEngine.ABILITY_DROUGHT == 70)
check("ability -> family", BattleEngine.SWITCH_IN_WEATHER_ABILITIES[2] == "rain"
  and BattleEngine.SWITCH_IN_WEATHER_ABILITIES[45] == "sandstorm"
  and BattleEngine.SWITCH_IN_WEATHER_ABILITIES[70] == "sun"
  and BattleEngine.SWITCH_IN_WEATHER_ABILITIES[13] == nil
  and BattleEngine.SWITCH_IN_WEATHER_ABILITIES[77] == nil)

-- ---------------------------------------------------------------------------
-- resolveSwitchInAbility
-- ---------------------------------------------------------------------------
for _, case in ipairs({ { DRIZZLE, "rain" }, { SAND_STREAM, "sandstorm" }, { DROUGHT, "sun" } }) do
  local ability, kind = case[1], case[2]
  local e = battle({}, { playerAbility = ability })
  local events = {}
  e:resolveSwitchInAbility(P, events)
  check(kind .. ": sets permanent weather from clear", weatherIs(e, kind, true))
  check(kind .. ": one event with side/ability/kind", #events == 1 and events[1].type == "weatherAbility"
    and events[1].side == P and events[1].ability == ability and events[1].kind == kind)
  check(kind .. ": duration untouched (0)", e.weatherDuration == 0)
  check(kind .. ": no RNG", e.rng.draws == 0)

  -- Same family already permanent: nothing happens, nothing is printed.
  e = battle({}, { foeAbility = ability, weather = kind, permanent = true, duration = 2 })
  events = {}
  e:resolveSwitchInAbility(F, events)
  check(kind .. ": same family permanent is skipped silently", #events == 0
    and weatherIs(e, kind, true) and e.weatherDuration == 2)

  -- Same family temporary (from the move): converted to permanent, with text.
  e = battle({}, { foeAbility = ability, weather = kind, duration = 3 })
  events = {}
  e:resolveSwitchInAbility(F, events)
  check(kind .. ": temporary same family converted, announced", #events == 1
    and events[1].side == F and weatherIs(e, kind, true))
  check(kind .. ": conversion leaves the counter at 3", e.weatherDuration == 3)
end

-- Overwriting: every other family, temporary or permanent, hail included.
for _, case in ipairs({
  { DRIZZLE, "rain", "sun", false }, { DRIZZLE, "rain", "sandstorm", true },
  { DRIZZLE, "rain", "hail", false }, { SAND_STREAM, "sandstorm", "rain", true },
  { SAND_STREAM, "sandstorm", "rain", false }, { DROUGHT, "sun", "sandstorm", true },
  { DROUGHT, "sun", "hail", false },
}) do
  local e = battle({}, { playerAbility = case[1], weather = case[3], permanent = case[4], duration = 4 })
  local events = {}
  e:resolveSwitchInAbility(P, events)
  check(("%s overwrites %s %s"):format(case[2], case[4] and "permanent" or "temporary", case[3]),
    #events == 1 and weatherIs(e, case[2], true) and e.weatherDuration == 4)
end

-- No weather ability: nothing, including Cloud Nine and Air Lock.
for _, ability in ipairs({ 0, CLOUD_NINE, AIR_LOCK, SWIFT_SWIM }) do
  local e = battle({}, { playerAbility = ability, weather = "rain", duration = 3 })
  local events = {}
  e:resolveSwitchInAbility(P, events)
  check("ability " .. ability .. " emits nothing and keeps the weather", #events == 0
    and weatherIs(e, "rain", false) and e.weatherDuration == 3 and e.rng.draws == 0)
end

-- No Cloud Nine gate on the setter: the weather is set and announced.
do
  local e = battle({}, { playerAbility = DRIZZLE, foeAbility = CLOUD_NINE })
  local events = {}
  e:resolveSwitchInAbility(P, events)
  check("Drizzle under foe Cloud Nine still sets and announces", #events == 1
    and weatherIs(e, "rain", true))
  check("...but the weather has no effect", e:activeWeather() == nil)
end

-- ---------------------------------------------------------------------------
-- Battle start
-- ---------------------------------------------------------------------------
do
  -- Player 30 > foe 20: player Drizzle first, then foe Sand Stream; the
  -- slower setter runs last and its sandstorm stays.
  local e = battle({}, { playerAbility = DRIZZLE, foeAbility = SAND_STREAM })
  local events = e:resolveBattleStart()
  check("start: faster player first", #events == 2 and events[1].side == P and events[1].kind == "rain"
    and events[2].side == F and events[2].kind == "sandstorm")
  check("start: slower setter wins", weatherIs(e, "sandstorm", true))
  check("start: no draws", e.rng.draws == 0)
  check("start: flag set", e.battleStartResolved == true)
  check("start: second call refused", not pcall(function() e:resolveBattleStart() end))

  -- Foe faster: foe Sand Stream first, then player Drizzle; rain stays.
  e = battle({}, { playerAbility = DRIZZLE, foeAbility = SAND_STREAM, playerSpeed = 20, foeSpeed = 30 })
  events = e:resolveBattleStart()
  check("start: faster foe first", #events == 2 and events[1].side == F and events[2].side == P)
  check("start: player's rain stays", weatherIs(e, "rain", true) and e.rng.draws == 0)

  -- Paralysis counts (effectiveSpeed /4): player 100 -> 25 < foe 30.
  e = battle({}, { playerAbility = DROUGHT, foeAbility = DRIZZLE, playerSpeed = 100, foeSpeed = 30,
    playerStatus = S.PARALYSIS })
  events = e:resolveBattleStart()
  check("start: paralysed player 25 is slower than 30", events[1].side == F and events[2].side == P
    and weatherIs(e, "sun", true))

  -- Two Drizzles: the faster announces, the slower finds RAIN_PERMANENT set.
  e = battle({}, { playerAbility = DRIZZLE, foeAbility = DRIZZLE, playerSpeed = 10, foeSpeed = 40 })
  events = e:resolveBattleStart()
  check("start: same family twice, only the faster announces", #events == 1 and events[1].side == F)

  -- One setter, either side.
  e = battle({}, { foeAbility = DROUGHT })
  events = e:resolveBattleStart()
  check("start: lone foe Drought", #events == 1 and events[1].side == F and weatherIs(e, "sun", true))

  -- No setter: no events, no draws, weather clear.
  e = battle({}, { playerAbility = CLOUD_NINE, foeAbility = AIR_LOCK, playerSpeed = 20, foeSpeed = 20 })
  events = e:resolveBattleStart()
  check("start: no setter, tied speeds: nothing and no draw", #events == 0 and e.rng.draws == 0
    and e.weather.kind == nil)
end

-- D3: a speed tie goes player first through the named helper, no draw.
do
  local e = battle({ 1, 1, 1 }, { playerAbility = DROUGHT, foeAbility = DRIZZLE,
    playerSpeed = 25, foeSpeed = 25 })
  local order = e:breakBattleStartSpeedTie()
  check("D3 helper: player first", order[1] == P and order[2] == F)
  check("D3 helper: battleStartOrder uses it on a tie", e:battleStartOrder()[1] == P)
  local events = e:resolveBattleStart()
  check("D3: tie, player Drought then foe Drizzle (rain stays)", #events == 2
    and events[1].side == P and events[2].side == F and weatherIs(e, "rain", true))
  check("D3: no tie draw (a source draw of 1 would put the foe first)", e.rng.draws == 0)
  -- A paralysed 100 (-> 25) ties a clean 25: still player first.
  e = battle({ 1 }, { playerAbility = SAND_STREAM, foeAbility = DROUGHT, playerSpeed = 100,
    foeSpeed = 25, playerStatus = S.PARALYSIS })
  events = e:resolveBattleStart()
  check("D3: paralysis-made tie is player first", events[1].side == P and weatherIs(e, "sun", true)
    and e.rng.draws == 0)
  -- The helper is the single tie point: overriding it flips the order.
  e = battle({}, { playerAbility = DROUGHT, foeAbility = DRIZZLE, playerSpeed = 25, foeSpeed = 25 })
  e.breakBattleStartSpeedTie = function() return { F, P } end
  events = e:resolveBattleStart()
  check("D3: the helper alone decides the tie", events[1].side == F and weatherIs(e, "sun", true))
end

-- Overworld battle weather stand-in: unreachable ids refuse, others no-op.
do
  for _, id in ipairs({ 3, 5, 8, 12, 13 }) do
    local e = battle({})
    check("overworld weather " .. id .. " is refused", not pcall(function() e:resolveBattleStart(id) end))
  end
  for _, id in ipairs({ 0, 2, 6, 11 }) do
    local e = battle({})
    local events = e:resolveBattleStart(id)
    check("overworld weather " .. id .. " is a no-op", #events == 0 and e.weather.kind == nil)
  end
end

-- Tyranitar Sand Stream vs a Kyogre Drizzle lead. Kyogre (Water, 400 HP)
-- faster 110 vs Tyranitar (Rock/Dark) 81: Drizzle first, Sand Stream last,
-- permanent sandstorm. Every end of turn: "The sandstorm rages." (no
-- decrement), Kyogre takes max(1, 400/16) = 25, Tyranitar (Rock) exempt.
-- Splash has no accuracycheck; speeds differ: 0 draws per turn.
do
  local e = battle({}, { playerAbility = DRIZZLE, playerSpeed = 110, playerTypes = { T.TYPE_WATER, T.TYPE_WATER },
    foeAbility = SAND_STREAM, foeSpeed = 81, foeTypes = { T.TYPE_ROCK, T.TYPE_DARK },
    playerMoves = { SPLASH }, foeMoves = { SPLASH } })
  local events = e:resolveBattleStart()
  check("Kyogre vs Tyranitar: Drizzle then Sand Stream", types(events) == "weatherAbility,weatherAbility"
    and events[1].kind == "rain" and events[2].kind == "sandstorm")
  check("Kyogre vs Tyranitar: sandstorm permanent", weatherIs(e, "sandstorm", true) and e.weatherDuration == 0)
  local ok = true
  for turn = 1, 6 do
    local ev = e:runTurn(MOVE, MOVE)
    local cont = find(ev, "weatherContinues")
    local dmg = find(ev, "weatherDamage", P)
    if not (cont and cont.kind == "sandstorm" and dmg and dmg.amount == 25
        and dmg.hpRemaining == 400 - 25 * turn and not find(ev, "weatherDamage", F)
        and not find(ev, "weatherEnded")) then
      ok = false
    end
  end
  check("Kyogre vs Tyranitar: six turns of rage, 25 each, Tyranitar exempt", ok)
  check("Kyogre vs Tyranitar: still permanent, counter untouched", weatherIs(e, "sandstorm", true)
    and e.weatherDuration == 0 and e.rng.draws == 0)

  -- Reversed speeds: Tyranitar faster, Kyogre's rain stays and never stops.
  e = battle({}, { playerAbility = DRIZZLE, playerSpeed = 60, foeAbility = SAND_STREAM, foeSpeed = 81,
    playerMoves = { SPLASH }, foeMoves = { SPLASH } })
  events = e:resolveBattleStart()
  check("Tyranitar faster: Sand Stream then Drizzle", events[1].side == F and events[2].side == P
    and weatherIs(e, "rain", true))
  for _ = 1, 6 do events = e:runTurn(MOVE, MOVE) end
  check("permanent rain still continues after six turns", find(events, "weatherContinues")
    and find(events, "weatherContinues").kind == "rain" and weatherIs(e, "rain", true))
end

-- Cloud Nine / Air Lock lead against a setter: set and announced, no effect;
-- the end-of-turn text continues (DoFieldEndTurnEffects has no ability
-- test) and sandstorm deals no damage (Cmd_weatherdamage needs
-- WEATHER_HAS_EFFECT).
do
  local e = battle({}, { playerAbility = SAND_STREAM, foeAbility = CLOUD_NINE,
    playerMoves = { SPLASH }, foeMoves = { SPLASH } })
  local events = e:resolveBattleStart()
  check("Sand Stream vs Cloud Nine: announced", #events == 1 and events[1].side == P
    and weatherIs(e, "sandstorm", true) and e:activeWeather() == nil)
  events = e:runTurn(MOVE, MOVE)
  check("Sand Stream vs Cloud Nine: rages, no damage", find(events, "weatherContinues")
    and count(events, "weatherDamage") == 0)
  e = battle({}, { playerAbility = AIR_LOCK, foeAbility = DRIZZLE, foeSpeed = 40 })
  events = e:resolveBattleStart()
  check("Air Lock vs Drizzle: only the Drizzle event", #events == 1 and events[1].side == F
    and e:activeWeather() == nil)
end

-- ---------------------------------------------------------------------------
-- Voluntary switch
-- ---------------------------------------------------------------------------
do
  -- Clear weather; the incoming Drizzle holder announces before the foe's
  -- Tackle, which misses with one draw. End of turn: player switch (no
  -- move) vs foe Tackle priority 0, speeds 30 vs 20: no tie draw. Rain
  -- continues (permanent, no decrement). Total 1 draw.
  local e = battle({ MISS })
  local incoming = mon({ species = 7, speed = 30, ability = DRIZZLE })
  local events = e:runTurn({ action = "switch", battler = incoming }, MOVE)
  check("switch: event order", types(events) == "turnStart,switch,weatherAbility,useMove,miss,weatherContinues",
    types(events))
  local ab = find(events, "weatherAbility")
  check("switch: incoming player's Drizzle", ab and ab.side == P and ab.ability == DRIZZLE and ab.kind == "rain")
  check("switch: permanent rain, 1 draw", weatherIs(e, "rain", true) and e.rng.draws == 1)

  -- The foe's move already sees the weather: Rain Dance now fails.
  e = battle({}, { foeMoves = { RAIN_DANCE } })
  events = e:runTurn({ action = "switch", battler = mon({ ability = DRIZZLE }) }, MOVE)
  check("switch: foe's Rain Dance after Drizzle fails", find(events, "moveFailed", F)
    and weatherIs(e, "rain", true) and e.rng.draws == 0)

  -- Same family permanent: nothing. Overwrites a temporary sun (duration 3
  -- left alone, and not decremented at the end of turn because permanent).
  e = battle({ MISS }, { weather = "rain", permanent = true, duration = 0 })
  events = e:runTurn({ action = "switch", battler = mon({ ability = DRIZZLE }) }, MOVE)
  check("switch: permanent rain, Drizzle silent", count(events, "weatherAbility") == 0
    and types(events) == "turnStart,switch,useMove,miss,weatherContinues")
  e = battle({ MISS }, { weather = "sun", duration = 3 })
  events = e:runTurn({ action = "switch", battler = mon({ ability = SAND_STREAM }) }, MOVE)
  check("switch: Sand Stream overwrites temporary sun", weatherIs(e, "sandstorm", true)
    and e.weatherDuration == 3 and find(events, "weatherContinues").kind == "sandstorm")
  -- Then the foe's Sunny Day overwrites the permanent sandstorm with a
  -- temporary sun and a fresh 5 (W1 move rule); 4 continues, then faded.
  e.foe.moves = moveList({ SUNNY_DAY })
  events = e:runTurn(MOVE, MOVE)
  check("Sunny Day replaces the permanent sandstorm", find(events, "weatherSet", F)
    and weatherIs(e, "sun", false) and e.weatherDuration == 4)
  -- A Cloud Nine incoming emits nothing.
  e = battle({ MISS }, { weather = "rain", duration = 3 })
  events = e:runTurn({ action = "switch", battler = mon({ ability = CLOUD_NINE }) }, MOVE)
  check("switch: Cloud Nine incoming emits nothing", count(events, "weatherAbility") == 0
    and weatherIs(e, "rain", false) and e.weatherDuration == 2)
end

-- ---------------------------------------------------------------------------
-- Forced replacement after a faint
-- ---------------------------------------------------------------------------
local function faintAndQueue(e, side)
  local events = {}
  e:battler(side).hp = 0
  e:beginFaintSequence(); e:recordFaint(side, events); e:finalizeFaintSequence(events)
  return events
end

do
  local e = battle({}, { hasReplacement = function() return true end })
  faintAndQueue(e, P)
  local events = e:resolveForcedSwitch(P, mon({ ability = DRIZZLE }))
  check("forced: resolved then the replacement's Drizzle", types(events) == "forcedSwitchResolved,weatherAbility"
    and events[2].side == P and weatherIs(e, "rain", true) and e.rng.draws == 0)
  local taken = e:takeForcedSwitchEvents()
  check("forced: queue holds the same events", #taken == 2 and taken[1].type == "forcedSwitchResolved"
    and taken[2].type == "weatherAbility")
  check("forced: queue drained", #e:takeForcedSwitchEvents() == 0)

  -- Foe Tyranitar replacement over a temporary rain: converted? No:
  -- different family, overwritten with permanent sandstorm.
  e = battle({}, { hasReplacement = function() return true end, weather = "rain", duration = 2 })
  faintAndQueue(e, F)
  events = e:resolveForcedSwitch(F, mon({ ability = SAND_STREAM, types = { T.TYPE_ROCK, T.TYPE_DARK } }))
  check("forced foe: Sand Stream overwrites rain", events[2] and events[2].side == F
    and weatherIs(e, "sandstorm", true) and e.weatherDuration == 2)

  -- No ability: only the resolution event.
  e = battle({}, { hasReplacement = function() return true end })
  faintAndQueue(e, F)
  events = e:resolveForcedSwitch(F, mon({}))
  check("forced: plain replacement, one event", types(events) == "forcedSwitchResolved")

  -- Both sides queued: each replacement's ability in resolution order, so
  -- the second resolved (foe Drought) stays.
  e = battle({}, { hasReplacement = function() return true end })
  local ev = {}
  e.player.hp, e.foe.hp = 0, 0
  e:beginFaintSequence(); e:recordFaint(P, ev); e:recordFaint(F, ev); e:finalizeFaintSequence(ev)
  e:resolveForcedSwitch(P, mon({ ability = DRIZZLE }))
  e:resolveForcedSwitch(F, mon({ ability = DROUGHT }))
  taken = e:takeForcedSwitchEvents()
  check("forced both: queue accumulates in order", types(taken)
    == "forcedSwitchResolved,weatherAbility,forcedSwitchResolved,weatherAbility"
    and taken[2].side == P and taken[4].side == F and weatherIs(e, "sun", true))

  -- runTurn forgets anything left unpresented.
  e = battle({ MISS, MISS }, { hasReplacement = function() return true end })
  faintAndQueue(e, F)
  e:resolveForcedSwitch(F, mon({ ability = DROUGHT }))
  e:runTurn(MOVE, MOVE)
  check("runTurn clears the forced-switch queue", #e:takeForcedSwitchEvents() == 0)

  -- Through a real faint: foe 30 outspeeds player 20 at 1 HP. Draws:
  -- accuracy 0 (hit), crit 1 (1 % 16 ~= 0), damage roll 0 = 3; the player
  -- faints, the turn ends with no order draw (0-HP rule).
  e = battle({ 0, 1, 0 }, { playerSpeed = 20, foeSpeed = 30, playerCurrentHP = 1,
    hasReplacement = function(side) return side == P end })
  events = e:runTurn(MOVE, MOVE)
  check("real faint queues the player's replacement", e.awaitingForcedSwitch == P
    and find(events, "forcedSwitchNeeded", P) and e.rng.draws == 3)
  events = e:resolveForcedSwitch(P, mon({ ability = DROUGHT }))
  check("real faint: replacement's Drought", events[2] and events[2].kind == "sun" and weatherIs(e, "sun", true))
end

-- ---------------------------------------------------------------------------
-- Controller texts and order
-- ---------------------------------------------------------------------------
do
  local c = BattleSceneController.new({ engine = battle({}), playerName = "KYOGRE", foeName = "GROUDON" })
  local entries = c:_eventMessages({
    { type = "weatherAbility", side = P, ability = DRIZZLE, kind = "rain" },
    { type = "weatherAbility", side = F, ability = SAND_STREAM, kind = "sandstorm" },
    { type = "weatherAbility", side = F, ability = DROUGHT, kind = "sun" },
  })
  check("text: Drizzle", entries[1].text == "KYOGRE's DRIZZLE\nmade it rain!", entries[1].text)
  check("text: Sand Stream", entries[2].text == "GROUDON's SAND STREAM\nwhipped up a sandstorm!", entries[2].text)
  check("text: Drought", entries[3].text == "GROUDON's DROUGHT\nintensified the sun's rays!", entries[3].text)
  check("text: no HP entries", #entries == 3)
end

-- Battle start through the controller: intro, then the leads fastest first.
do
  local e = battle({}, { playerAbility = DRIZZLE, foeAbility = SAND_STREAM, playerSpeed = 110, foeSpeed = 81 })
  local c = BattleSceneController.new({ engine = e, playerName = "KYOGRE", foeName = "TYRANITAR" })
  local t = texts(c)
  check("controller start: intro then both abilities", #t == 4 and t[1] == "Wild TYRANITAR appeared!"
    and t[2] == "Go! KYOGRE!" and t[3] == "KYOGRE's DRIZZLE\nmade it rain!"
    and t[4] == "TYRANITAR's SAND STREAM\nwhipped up a sandstorm!", table.concat(t, " | "))
  check("controller start: engine resolved, sandstorm, no draws", e.battleStartResolved
    and weatherIs(e, "sandstorm", true) and e.rng.draws == 0)
  for _ = 1, 3 do c:advanceMessage() end
  check("controller start: still on the last ability text", c.state == BattleSceneController.MESSAGES
    and c:message() == "TYRANITAR's SAND STREAM\nwhipped up a sandstorm!")
  c:advanceMessage()
  check("controller start: then ACTION", c.state == BattleSceneController.ACTION)

  -- Custom (trainer-style) intro: abilities follow the last intro line.
  e = battle({}, { foeAbility = DROUGHT })
  c = BattleSceneController.new({ engine = e, playerName = "A", foeName = "B",
    introMessages = { "T would like to battle!", "T sent out B!", "Go! A!" } })
  t = texts(c)
  check("controller start: after a trainer intro", #t == 4 and t[3] == "Go! A!"
    and t[4] == "B's DROUGHT\nintensified the sun's rays!")

  -- No setter (every current wild/Oak/rival lead): the intro only, no draw.
  e = battle({}, { playerAbility = CLOUD_NINE, foeAbility = 0, playerSpeed = 20, foeSpeed = 20 })
  c = BattleSceneController.new({ engine = e, playerName = "A", foeName = "B" })
  t = texts(c)
  check("controller start: no setter keeps the intro unchanged", #t == 2 and t[1] == "Wild B appeared!"
    and t[2] == "Go! A!" and e.rng.draws == 0 and e.battleStartResolved)

  -- An engine that already played a turn is not restarted.
  e = battle({ MISS, MISS }, { foeAbility = DROUGHT })
  e:runTurn(MOVE, MOVE)
  c = BattleSceneController.new({ engine = e, introMessages = {} })
  check("controller start: skipped after turn 1", not e.battleStartResolved and e.weather.kind == nil
    and c.state == BattleSceneController.ACTION)

  -- Oak's first battle: firstBattle engine, starters have no weather ability.
  e = BattleEngine.new({ player = mon({ ability = 65 }), foe = mon({ species = 4, ability = 66 }),
    moves = moves, typeChart = Data.typeChart, rng = scriptedRng({}), firstBattle = true })
  c = BattleSceneController.new({ engine = e, introMessages = { "OAK: one", "OAK: two" } })
  t = texts(c)
  check("controller start: Oak tutorial intro unchanged", #t == 2 and t[2] == "OAK: two" and e.rng.draws == 0)
end

-- Voluntary switch through the controller (the main.lua trainer callback
-- shape: it runs the switch turn itself and returns nil).
do
  local e = battle({ MISS })
  local incoming = mon({ species = 7, ability = DRIZZLE })
  local c
  c = BattleSceneController.new({ engine = e, playerName = "A", foeName = "B", introMessages = {},
    voluntarySwitchChoices = function() return { { slot = 2, name = "KYOGRE" } } end,
    onVoluntarySwitchChoice = function()
      c.playerName = "KYOGRE"
      c:_runTurn({ action = "switch", battler = incoming })
      return nil
    end,
    moveName = function() return "TACKLE" end,
  })
  c.actionCursor = 2
  press(c, InputState.A_BUTTON) -- POKEMON
  check("voluntary: selector open", c.state == BattleSceneController.PARTY)
  press(c, InputState.A_BUTTON)
  local t = texts(c)
  check("voluntary: switch, Drizzle, then the foe's move", t[1] == "KYOGRE switched Pokemon!"
    and t[2] == "KYOGRE's DRIZZLE\nmade it rain!" and t[3] == "B used TACKLE!"
    and t[4] == "B's attack missed!" and t[5] == "Rain continues to fall.", table.concat(t, " | "))
end

-- Forced player replacement through the controller. The callback ignores
-- resolveForcedSwitch's return value, as main.lua does; the controller
-- still presents the replacement's ability after the callback's send-out.
do
  local e = battle({ 0, 1, 0 }, { playerSpeed = 20, foeSpeed = 30, playerCurrentHP = 1,
    hasReplacement = function(side) return side == P end })
  local legal = { { slot = 2, name = "KYOGRE" } }
  local c
  c = BattleSceneController.new({ engine = e, playerName = "A", foeName = "B", introMessages = {},
    moveName = function() return "TACKLE" end,
    forcedSwitchChoices = function() return legal end,
    onForcedSwitchChoice = function(choice)
      e:resolveForcedSwitch(P, mon({ species = 7, ability = DRIZZLE }))
      c.playerName = choice.name
      return { "A, come back!\nGo! KYOGRE!" }
    end,
  })
  c:_runTurn(MOVE)
  local t = texts(c)
  check("forced controller: faint messages first", t[1] == "B used TACKLE!" and t[2] == "A fainted!"
    and t[3] == "A must send out\na new POKEMON!", table.concat(t, " | "))
  while c.state == BattleSceneController.MESSAGES do c:advanceMessage() end
  check("forced controller: PARTY", c.state == BattleSceneController.PARTY)
  press(c, InputState.A_BUTTON)
  t = texts(c)
  check("forced controller: send-out then Drizzle", #t == 2 and t[1] == "A, come back!\nGo! KYOGRE!"
    and t[2] == "KYOGRE's DRIZZLE\nmade it rain!", table.concat(t, " | "))
  check("forced controller: queue drained, rain", #e:takeForcedSwitchEvents() == 0 and weatherIs(e, "rain", true))
  c:advanceMessage(); c:advanceMessage()
  check("forced controller: then ACTION", c.state == BattleSceneController.ACTION)
end

-- Forced foe replacement through TrainerBattleOrchestrator and
-- onMessagesComplete (the main.lua trainer shape; the orchestrator ignores
-- resolveForcedSwitch's return value).
do
  local e = battle({ 0, 1, 0 }, { playerSpeed = 30, foeSpeed = 20, foeCurrentHP = 1,
    hasReplacement = function(side) return side == F end })
  local tyranitar = mon({ species = 248, ability = SAND_STREAM, types = { T.TYPE_ROCK, T.TYPE_DARK } })
  local orch = TrainerBattleOrchestrator.new({ foes = { e.foe, tyranitar }, toBattler = function(f) return f end })
  local c
  c = BattleSceneController.new({ engine = e, playerName = "A", foeName = "B", introMessages = {},
    moveName = function() return "TACKLE" end,
    onMessagesComplete = function()
      if e.awaitingForcedSwitch ~= F then return nil end
      orch:resolveFoeReplacement(e)
      c.foeName = "TYRANITAR"
      return { "T sent out TYRANITAR!" }
    end,
  })
  c:_runTurn(MOVE)
  local t = texts(c)
  check("forced foe controller: faint first", t[1] == "A used TACKLE!" and t[2] == "B fainted!"
    and t[3] == "B must send out\na new POKEMON!", table.concat(t, " | "))
  while c:message() ~= "B must send out\na new POKEMON!" do c:advanceMessage() end
  c:advanceMessage()
  t = texts(c)
  check("forced foe controller: send-out then Sand Stream", #t == 2 and t[1] == "T sent out TYRANITAR!"
    and t[2] == "TYRANITAR's SAND STREAM\nwhipped up a sandstorm!", table.concat(t, " | "))
  check("forced foe controller: sandstorm permanent, 3 draws", weatherIs(e, "sandstorm", true) and e.rng.draws == 3)
  c:advanceMessage(); c:advanceMessage()
  check("forced foe controller: then ACTION", c.state == BattleSceneController.ACTION)
end

print(("battle_weather_w3b_test: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
