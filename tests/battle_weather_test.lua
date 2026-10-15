-- Run: lua5.1 tests/battle_weather_test.lua
--
-- Weather slice W1 (work/tasks/phase4-weather-w1.md). Oracles come from
-- pret/pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788:
--   * moves: data/battle_scripts_1.s:1585-1590, :1740-1758, :2128-2133;
--     src/battle_script_commands.c:6399-6413, :7200-7214, :8381-8396,
--     :8664-8678 (no accuracycheck, no RNG; own family fails, permanent
--     included; otherwise the whole word is overwritten, duration 5);
--   * end of turn: src/battle_util.c:624-711 (shared counter; hail always
--     decrements), data/battle_scripts_1.s:3150-3198 (texts, damage loop),
--     src/battle_script_commands.c:7216-7268 (Cmd_weatherdamage);
--   * damage: src/pokemon.c:2605-2637 (special branch only, after Light
--     Screen, before +2; each step truncates);
--   * freeze in sun: src/battle_script_commands.c:2257-2265;
--   * Cloud Nine/Air Lock: include/battle_util.h:49-50,
--     src/battle_util.c:2325-2362;
--   * AI: data/battle_ai_scripts.s:455-458, :495-503, :526-529,
--     src/battle_ai_script_commands.c:1385-1397;
--   * texts: src/battle_message.c:156-157, :336-352.
-- Every expected number below is worked from those formulas in the
-- comments, never read back from the engine.
package.path = package.path .. ";./?.lua"

local BattleEngine = require("src.core.BattleEngine")
local BattleFormulas = require("src.core.BattleFormulas")
local BattleSceneController = require("src.core.BattleSceneController")
local AICheckBadMove = require("src.core.AICheckBadMove")
local TrainerAI = require("src.core.TrainerAI")
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
local SANDSTORM, RAIN_DANCE, SUNNY_DAY, HAIL = 201, 240, 241, 258
local SOLAR_BEAM, WATER_GUN, ICE_BEAM, TRI_ATTACK = 76, 55, 58, 161
local FLY, DIG, DIVE, BOUNCE = 19, 91, 291, 340
local moves = {}
for id, m in pairs(Data.moves) do moves[id] = m end
moves[SANDSTORM] = rec(115, 0, Data.TYPE_ROCK, 0, 10, 0, 0x10, 0)
moves[RAIN_DANCE] = rec(136, 0, Data.TYPE_WATER, 0, 5, 0, 0x10, 0)
moves[SUNNY_DAY] = rec(137, 0, Data.TYPE_FIRE, 0, 5, 0, 0x10, 0)
moves[HAIL] = rec(164, 0, Data.TYPE_ICE, 0, 10, 0, 0x10, 0x02)
moves[SOLAR_BEAM] = rec(151, 120, Data.TYPE_GRASS, 100, 10, 0, 0, 0x32)
moves[WATER_GUN] = rec(0, 40, Data.TYPE_WATER, 100, 25, 0, 0, 0x12)
moves[ICE_BEAM] = rec(5, 95, Data.TYPE_ICE, 100, 10, 10, 0, 0x12)
moves[TRI_ATTACK] = rec(36, 80, Data.TYPE_NORMAL, 100, 10, 20, 0, 0x12)
moves[FLY] = rec(155, 70, Data.TYPE_FLYING, 95, 15, 0, 0, 0x13)
moves[DIG] = rec(155, 60, Data.TYPE_GROUND, 100, 10, 0, 0, 0x13)
moves[DIVE] = rec(155, 60, Data.TYPE_WATER, 100, 10, 0, 0, 0x13)
moves[BOUNCE] = rec(155, 85, Data.TYPE_FLYING, 85, 5, 30, 0, 0x13)
-- Synthetic records (no real Water-type multi-hit, Triple Kick or
-- Explosion exists): they only pin that those call sites pass the weather.
local FX_DOUBLE, FX_TRIPLE, FX_BOOM = 901, 902, 903
moves[FX_DOUBLE] = rec(44, 40, Data.TYPE_WATER, 100, 10, 0, 0, 0)
moves[FX_TRIPLE] = rec(104, 10, Data.TYPE_WATER, 90, 10, 0, 0, 0)
moves[FX_BOOM] = rec(7, 250, Data.TYPE_WATER, 100, 5, 0, 0, 0)

local WEATHER_MOVE = { rain = RAIN_DANCE, sun = SUNNY_DAY, sandstorm = SANDSTORM, hail = HAIL }
local KINDS = { "rain", "sun", "sandstorm", "hail" }

local function stats(hp, speed, spAttack)
  return { hp = hp, attack = 20, defense = 20, speed = speed, spAttack = spAttack or 20, spDefense = 20 }
end
local function moveList(list)
  local out = {}
  for i, id in ipairs(list) do out[i] = { move = id, pp = 10 } end
  return out
end

-- Default: player faster (30 vs 20), both Normal, 160 HP (tick 160/16 = 10).
local function battle(values, opts)
  opts = opts or {}
  local engine = BattleEngine.new({
    player = BattleEngine.makeBattler({ species = 1, level = 10,
      stats = stats(opts.playerHP or 160, opts.playerSpeed or 30, opts.playerSpAttack),
      types = opts.playerTypes or { Data.TYPE_NORMAL, Data.TYPE_NORMAL },
      status = opts.playerStatus, moves = moveList(opts.playerMoves or { Data.MOVE_TACKLE }) }),
    foe = BattleEngine.makeBattler({ species = 4, level = 10,
      stats = stats(opts.foeHP or 160, opts.foeSpeed or 20),
      types = opts.foeTypes or { Data.TYPE_NORMAL, Data.TYPE_NORMAL },
      status = opts.foeStatus, moves = moveList(opts.foeMoves or { Data.MOVE_TACKLE }) }),
    moves = moves, typeChart = Data.typeChart, rng = scriptedRng(values),
    hasReplacement = opts.hasReplacement,
  })
  engine.player.ability = opts.playerAbility or 0
  engine.foe.ability = opts.foeAbility or 0
  if opts.playerCurrentHP then engine.player.hp = opts.playerCurrentHP end
  if opts.foeCurrentHP then engine.foe.hp = opts.foeCurrentHP end
  if opts.weather then
    engine.weather = { kind = opts.weather, permanent = opts.permanent == true }
    engine.weatherDuration = opts.duration or 5
  end
  return engine
end

local MOVE = { action = "move", moveSlot = 1 }
local MOVE2 = { action = "move", moveSlot = 2 }
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
local function count(events, t, side)
  local n = 0
  for _, e in ipairs(events) do
    if e.type == t and (side == nil or e.side == side) then n = n + 1 end
  end
  return n
end

---------------------------------------------------------------------------
-- The four moves: success, failure, overwrite
---------------------------------------------------------------------------
for _, kind in ipairs(KINDS) do
  -- Player (faster) uses the move; the foe's Tackle misses (one draw).
  -- The move itself draws nothing.
  local b = battle({ MISS }, { playerMoves = { WEATHER_MOVE[kind] } })
  local events = b:runTurn(MOVE, MOVE)
  local set, si = find(events, "weatherSet", "player")
  local _, ui = find(events, "useMove", "player")
  check(kind .. ": move sets the weather after useMove", set and set.kind == kind and ui < si, types(events))
  check(kind .. ": one PP spent", b.player.moves[1].pp == 9, b.player.moves[1].pp)
  check(kind .. ": temporary, duration 5 then one end-of-turn decrement", b.weather.kind == kind
    and b.weather.permanent == false and b.weatherDuration == 4, b.weatherDuration)
  check(kind .. ": no draw of its own (only the foe's accuracy)", b.rng.draws == 1, b.rng.draws)
  check(kind .. ": no accuracy miss path", not find(events, "miss", "player"))

  -- Own family active (temporary): But it failed, PP still spent, timer
  -- untouched by the move (3 -> 2 at end of turn).
  b = battle({ MISS }, { playerMoves = { WEATHER_MOVE[kind] }, weather = kind, duration = 3 })
  events = b:runTurn(MOVE, MOVE)
  check(kind .. ": fails in its own family", find(events, "moveFailed", "player")
    and not find(events, "weatherSet"), types(events))
  check(kind .. ": failure spends PP, keeps the timer", b.player.moves[1].pp == 9 and b.weatherDuration == 2,
    b.weatherDuration)
  check(kind .. ": failure draws nothing", b.rng.draws == 1, b.rng.draws)

  -- Own family permanent bit set (ability weather, W3b): still fails.
  b = battle({ MISS }, { playerMoves = { WEATHER_MOVE[kind] }, weather = kind, permanent = true, duration = 0 })
  events = b:runTurn(MOVE, MOVE)
  check(kind .. ": fails against its own permanent family", find(events, "moveFailed", "player")
    and b.weather.permanent == true, types(events))
end

do
  -- Cross-family overwrite: rain at 2 turns left, Sunny Day -> sun for 5.
  local b = battle({ MISS }, { playerMoves = { SUNNY_DAY }, weather = "rain", duration = 2 })
  local events = b:runTurn(MOVE, MOVE)
  check("overwrite: Sunny Day replaces rain", find(events, "weatherSet").kind == "sun" and b.weather.kind == "sun")
  check("overwrite: duration reset to 5 (4 after this end of turn)", b.weatherDuration == 4, b.weatherDuration)
  check("overwrite: only the new family's text at end of turn", find(events, "weatherContinues").kind == "sun"
    and count(events, "weatherContinues") == 1, types(events))
  -- A permanent family is overwritten too (Sunny Day under Drizzle gives 5
  -- turns of temporary sun).
  b = battle({ MISS }, { playerMoves = { RAIN_DANCE }, weather = "sandstorm", permanent = true, duration = 0 })
  b:runTurn(MOVE, MOVE)
  check("overwrite: a permanent sandstorm becomes temporary rain", b.weather.kind == "rain"
    and b.weather.permanent == false and b.weatherDuration == 4)
end

do
  -- Both sides: foe's own Hail after the player's Rain Dance overwrites.
  local b = battle({}, { playerMoves = { RAIN_DANCE }, foeMoves = { HAIL } })
  local events = b:runTurn(MOVE, MOVE)
  check("same turn: second setter wins", b.weather.kind == "hail" and count(events, "weatherSet") == 2
    and b.weatherDuration == 4, types(events))
  check("same turn: no draws at all", b.rng.draws == 0, b.rng.draws)
end

---------------------------------------------------------------------------
-- The 5-turn counter: 4 "continues", then "stopped"; 4 damage ticks
---------------------------------------------------------------------------
for _, kind in ipairs(KINDS) do
  -- Turn 1 sets; both sides then Tackle-miss. maxHP 160 -> tick 10.
  local b = battle({}, { playerMoves = { WEATHER_MOVE[kind], Data.MOVE_TACKLE }, foeHP = 400 })
  local continues, ended, ticks = 0, 0, 0
  local perTurn = {}
  for turn = 1, 6 do
    b.rng = scriptedRng({ MISS, MISS })
    local events = b:runTurn(turn == 1 and MOVE or MOVE2, MOVE)
    continues = continues + count(events, "weatherContinues")
    ended = ended + count(events, "weatherEnded")
    ticks = ticks + count(events, "weatherDamage", "player")
    perTurn[turn] = (find(events, "weatherContinues") and "C") or (find(events, "weatherEnded") and "E") or "-"
  end
  local pattern = table.concat(perTurn)
  check(kind .. ": continues on turns 1-4, stopped on turn 5, nothing on 6", pattern == "CCCCE-", pattern)
  check(kind .. ": exactly 4 continues and 1 end", continues == 4 and ended == 1)
  local expectTicks = (kind == "sandstorm" or kind == "hail") and 4 or 0
  check(kind .. ": damage ticks", ticks == expectTicks, ticks)
  check(kind .. ": weather cleared", b.weather.kind == nil and b.weatherDuration == 0)
  if expectTicks == 4 then
    check(kind .. ": 4 ticks of 10 on the player", b.player.hp == 160 - 40, b.player.hp)
  end
end

do
  -- The ending turn deals no damage and prints the end text.
  local b = battle({ MISS, MISS }, { weather = "sandstorm", duration = 1 })
  local events = b:runTurn(MOVE, MOVE)
  check("sandstorm subsides with no damage on its last turn", find(events, "weatherEnded")
    and not find(events, "weatherDamage") and b.player.hp == 160, types(events))
  b = battle({ MISS, MISS }, { weather = "hail", duration = 1 })
  events = b:runTurn(MOVE, MOVE)
  check("hail stops with no damage on its last turn", find(events, "weatherEnded")
    and not find(events, "weatherDamage"), types(events))
end

do
  -- Permanent rain/sun/sandstorm never decrement (W3b sets them); hail has
  -- no permanent form and src/battle_util.c:695 decrements unconditionally.
  for _, kind in ipairs({ "rain", "sun", "sandstorm" }) do
    local b = battle({ MISS, MISS }, { weather = kind, permanent = true, duration = 0 })
    local events = b:runTurn(MOVE, MOVE)
    check(kind .. ": permanent continues without decrementing", find(events, "weatherContinues")
      and b.weatherDuration == 0 and b.weather.kind == kind, b.weatherDuration)
  end
  local b = battle({ MISS, MISS }, { weather = "hail", permanent = true, duration = 2 })
  b:runTurn(MOVE, MOVE)
  check("hail decrements even with the permanent flag", b.weatherDuration == 1, b.weatherDuration)
end

---------------------------------------------------------------------------
-- Damage amount and exemptions
---------------------------------------------------------------------------
local function endTurnSand(kind, opts)
  opts = opts or {}
  opts.weather = kind
  local b = battle({ MISS, MISS }, opts)
  local events = b:runTurn(MOVE, MOVE)
  return b, events
end

do
  local b, events = endTurnSand("sandstorm", { playerHP = 15, foeHP = 33 })
  check("max(1, maxHP/16): 15 -> 1", find(events, "weatherDamage", "player").amount == 1 and b.player.hp == 14)
  check("33/16 truncates to 2", find(events, "weatherDamage", "foe").amount == 2 and b.foe.hp == 31)
  b, events = endTurnSand("hail", { playerHP = 160, playerCurrentHP = 3 })
  local e = find(events, "weatherDamage", "player")
  check("damage is clamped to the remaining HP and faints", e.amount == 3 and e.hpRemaining == 0
    and find(events, "faint", "player"), types(events))
end

do
  local T = Data
  local sandImmune = {
    { "Rock in slot 1", { T.TYPE_ROCK, T.TYPE_NORMAL } }, { "Rock in slot 2", { T.TYPE_NORMAL, T.TYPE_ROCK } },
    { "Steel in slot 1", { T.TYPE_STEEL, T.TYPE_NORMAL } }, { "Steel in slot 2", { T.TYPE_NORMAL, T.TYPE_STEEL } },
    { "Ground in slot 1", { T.TYPE_GROUND, T.TYPE_NORMAL } }, { "Ground in slot 2", { T.TYPE_NORMAL, T.TYPE_GROUND } },
  }
  for _, row in ipairs(sandImmune) do
    local b, events = endTurnSand("sandstorm", { playerTypes = row[2] })
    check("sandstorm exempts " .. row[1], not find(events, "weatherDamage", "player")
      and find(events, "weatherDamage", "foe"), types(events))
    b, events = endTurnSand("hail", { playerTypes = row[2] })
    check("hail does not exempt " .. row[1], find(events, "weatherDamage", "player") ~= nil, types(events))
  end
  local b, events = endTurnSand("sandstorm", { playerAbility = BattleEngine.ABILITY_SAND_VEIL })
  check("Sand Veil exempts from sandstorm", not find(events, "weatherDamage", "player"), types(events))
  b, events = endTurnSand("hail", { playerAbility = BattleEngine.ABILITY_SAND_VEIL })
  check("Sand Veil does not exempt from hail (no Gen 3 hail ability)", find(events, "weatherDamage", "player") ~= nil)
  for _, row in ipairs({ { "slot 1", { T.TYPE_ICE, T.TYPE_NORMAL } }, { "slot 2", { T.TYPE_NORMAL, T.TYPE_ICE } } }) do
    b, events = endTurnSand("hail", { playerTypes = row[2] })
    check("hail exempts Ice in " .. row[1], not find(events, "weatherDamage", "player"), types(events))
    b, events = endTurnSand("sandstorm", { playerTypes = row[2] })
    check("sandstorm does not exempt Ice in " .. row[1], find(events, "weatherDamage", "player") ~= nil)
  end
end

do
  -- Semi-invulnerable through the real charge turn: the player (faster)
  -- charges; the foe's Tackle then misses it with no draw. Dig/Dive are
  -- exempt from both weathers; Fly/Bounce (ON_AIR) are not.
  for _, row in ipairs({ { "Dig", DIG, false }, { "Dive", DIVE, false }, { "Fly", FLY, true }, { "Bounce", BOUNCE, true } }) do
    for _, kind in ipairs({ "sandstorm", "hail" }) do
      local b = battle({}, { playerMoves = { row[2] }, weather = kind })
      local events = b:runTurn(MOVE, MOVE)
      local hit = find(events, "weatherDamage", "player") ~= nil
      check(row[1] .. " in " .. kind .. ": " .. (row[3] and "not exempt" or "exempt"),
        find(events, "chargeTurn", "player") and hit == row[3] and find(events, "weatherDamage", "foe"),
        types(events))
      check(row[1] .. " in " .. kind .. ": no draws (charge, semi-invulnerable miss)", b.rng.draws == 0,
        b.rng.draws)
    end
  end
end

---------------------------------------------------------------------------
-- Order: ENDTURN_ORDER (W0), screens, weather, then status
---------------------------------------------------------------------------
do
  -- Both poisoned: both weather ticks come before both poison ticks.
  local b = battle({ MISS, MISS }, { weather = "sandstorm", playerStatus = S.POISON, foeStatus = S.POISON })
  local events = b:runTurn(MOVE, MOVE)
  local _, c = find(events, "weatherContinues")
  local _, wp = find(events, "weatherDamage", "player")
  local _, wf = find(events, "weatherDamage", "foe")
  local _, sp = find(events, "statusDamage", "player")
  local _, sf = find(events, "statusDamage", "foe")
  check("text, then both weather ticks, then both poison ticks (faster player first)",
    c and wp and wf and sp and sf and c < wp and wp < wf and wf < sp and sp < sf, types(events))
  check("weather + poison totals: 10 + 20", b.player.hp == 160 - 10 - 20 and b.foe.hp == 160 - 10 - 20)
  check("no extra draws", b.rng.draws == 2, b.rng.draws)
end

do
  -- The faster foe ticks first (ENDTURN_ORDER, not player-first).
  local b = battle({ MISS, MISS }, { weather = "hail", playerSpeed = 10, foeSpeed = 20 })
  local events = b:runTurn(MOVE, MOVE)
  local _, wp = find(events, "weatherDamage", "player")
  local _, wf = find(events, "weatherDamage", "foe")
  check("faster foe takes hail first", wf < wp, types(events))
  -- Exact tie: turn-start draw, two accuracy draws, then the end-of-turn
  -- `Random() & 1` decides the weather loop order too.
  for _, draw in ipairs({ 0, 1 }) do
    b = battle({ 0, MISS, MISS, draw }, { weather = "sandstorm", playerSpeed = 20, foeSpeed = 20 })
    events = b:runTurn(MOVE, MOVE)
    _, wp = find(events, "weatherDamage", "player")
    _, wf = find(events, "weatherDamage", "foe")
    check("tie draw " .. draw .. " orders the weather loop", (draw == 0) == (wp < wf), types(events))
    check("tie: exactly one end-of-turn draw (4 total)", b.rng.draws == 4, b.rng.draws)
  end
end

do
  -- A Reflect wearing off (field case before weather) prints first.
  local b = battle({ MISS, MISS }, { weather = "rain" })
  b.sideStatus.player.reflect, b.sideStatus.player.reflectTimer = true, 1
  local events = b:runTurn(MOVE, MOVE)
  local _, ri = find(events, "screenExpired")
  local _, wi = find(events, "weatherContinues")
  check("screen expiry precedes the weather text", ri and wi and ri < wi, types(events))
end

---------------------------------------------------------------------------
-- Faints inside the loop
---------------------------------------------------------------------------
do
  -- No replacements: the first battler's lethal tick decides the battle and
  -- the loop stops before the second battler (checkteamslost).
  local b = battle({ MISS, MISS }, { weather = "sandstorm", playerCurrentHP = 5, foeCurrentHP = 5,
    foeStatus = S.POISON })
  local events = b:runTurn(MOVE, MOVE)
  check("player faints first -> lost, foe untouched", b.outcome == "playerLost"
    and not find(events, "weatherDamage", "foe") and b.foe.hp == 5, types(events))
  check("decided battle skips the status phase", not find(events, "statusDamage"), types(events))
  b = battle({ MISS, MISS }, { weather = "sandstorm", playerCurrentHP = 5, foeCurrentHP = 5,
    playerSpeed = 10, foeSpeed = 20 })
  events = b:runTurn(MOVE, MOVE)
  check("foe faints first -> won, player untouched", b.outcome == "playerWon"
    and not find(events, "weatherDamage", "player") and b.player.hp == 5, types(events))
end

do
  -- A faint that only queues a replacement continues the loop.
  local b = battle({ MISS, MISS }, { weather = "hail", playerCurrentHP = 5,
    hasReplacement = function(side) return side == "player" end })
  local events = b:runTurn(MOVE, MOVE)
  check("replacement-pending faint continues the loop", find(events, "forcedSwitchNeeded", "player")
    and find(events, "weatherDamage", "foe") and b.outcome == nil, types(events))
end

do
  -- D4: a battler KO'd mid-turn (replacement pending) takes no weather tick;
  -- in source the replacement would take it (R2). Player Tackle: acc, crit,
  -- random; damage floor(floor(20*35*6/20)/50) = 4, +2 = 6, STAB 9 >= 5.
  local b = battle({ 0, 1, 0 }, { weather = "sandstorm", foeCurrentHP = 5,
    hasReplacement = function(side) return side == "foe" end })
  local events = b:runTurn(MOVE, MOVE)
  check("0-HP foe awaiting replacement takes no tick", find(events, "faint", "foe")
    and not find(events, "weatherDamage", "foe") and find(events, "weatherDamage", "player"), types(events))
  check("0-HP: no end-of-turn order draw (3 hit draws only)", b.rng.draws == 3, b.rng.draws)
end

---------------------------------------------------------------------------
-- Cloud Nine / Air Lock
---------------------------------------------------------------------------
for _, ab in ipairs({ { "Cloud Nine", BattleEngine.ABILITY_CLOUD_NINE }, { "Air Lock", BattleEngine.ABILITY_AIR_LOCK } }) do
  for _, holder in ipairs({ "player", "foe" }) do
    local opts = { weather = "sandstorm", duration = 3 }
    opts[holder .. "Ability"] = ab[2]
    local b, events = endTurnSand("sandstorm", opts)
    check(ab[1] .. " (" .. holder .. "): text and timer continue", find(events, "weatherContinues")
      and b.weatherDuration == 2, types(events))
    check(ab[1] .. " (" .. holder .. "): no damage to either side", not find(events, "weatherDamage"),
      types(events))
    check(ab[1] .. " (" .. holder .. "): activeWeather nil, kind kept", b:activeWeather() == nil
      and b.weather.kind == "sandstorm")
  end
end

do
  -- A fainted holder no longer suppresses (WEATHER_HAS_EFFECT is HP-gated):
  -- the KO'd Cloud Nine foe awaits its replacement; the player is hit.
  local b = battle({ 0, 1, 0 }, { weather = "sandstorm", foeCurrentHP = 5,
    foeAbility = BattleEngine.ABILITY_CLOUD_NINE, hasReplacement = function(side) return side == "foe" end })
  local events = b:runTurn(MOVE, MOVE)
  check("fainted Cloud Nine holder: weather has effect again", find(events, "weatherDamage", "player") ~= nil,
    types(events))
  -- R3: the two macros at their call sites. A 0-HP holder: gameplay checks
  -- see the weather, the damage block (WEATHER_HAS_EFFECT2, no HP test) does not.
  check("R3: activeWeather is HP-gated", b:activeWeather() == "sandstorm")
  check("R3: damageWeather ignores HP", b:damageWeather() == nil)
end

---------------------------------------------------------------------------
-- Damage terms (src/pokemon.c:2605-2637), formula level
---------------------------------------------------------------------------
-- Level 10, spDefense 20: base = floor(floor(spAtk * power * 6 / 20) / 50).
local function attackerWith(spAttack)
  return { level = 10, attack = 20, defense = 20, spAttack = spAttack, spDefense = 20, hp = 50, maxHP = 50,
    ability = 0, status = 0 }
end
local defender = { level = 10, attack = 20, defense = 20, spAttack = 20, spDefense = 20, hp = 50, maxHP = 50,
  ability = 0, status = 0 }
local waterGun, ember = moves[WATER_GUN], moves[Data.MOVE_EMBER]
local function dmg(spAttack, move, weather, moveId, screens)
  return BattleFormulas.calculateBaseDamage(attackerWith(spAttack), defender, move, false, screens, weather, moveId)
end

do
  -- spAttack 22: floor(5280/20) = 264, /50 = 5.
  check("clear Water: 5 + 2", dmg(22, waterGun, nil) == 7)
  check("rain Water: 15*5/10 = 7 (truncated), + 2", dmg(22, waterGun, "rain") == 9)
  check("sun Water: 5/2 = 2, + 2", dmg(22, waterGun, "sun") == 4)
  check("rain Fire: 5/2 = 2, + 2", dmg(22, ember, "rain") == 4)
  check("sun Fire: 7, + 2", dmg(22, ember, "sun") == 9)
  check("sandstorm/hail leave Fire/Water alone", dmg(22, waterGun, "sandstorm") == 7
    and dmg(22, ember, "hail") == 7)
  -- spAttack 5: floor(1200/20) = 60, /50 = 1; rain Fire 1/2 = 0, then +2
  -- (no minimum-1 clamp in the special branch).
  check("rain-halved Fire reaches 0 then + 2", dmg(5, ember, "rain") == 2 and dmg(5, ember, nil) == 3)
  -- After Light Screen: spAttack 30: floor(7200/20) = 360, /50 = 7;
  -- Light Screen 3, rain 15*3/10 = 4, + 2 = 6 (rain before the screen
  -- would give 10 -> 5 -> 7).
  check("weather term comes after Light Screen", dmg(30, waterGun, "rain", nil, { lightScreen = true }) == 6)
  -- Physical moves never see weather.
  local tackle = moves[Data.MOVE_TACKLE]
  check("physical move unaffected", dmg(22, tackle, "rain") == dmg(22, tackle, nil)
    and dmg(22, tackle, "sun") == dmg(22, tackle, nil))
end

do
  -- Solar Beam: spAttack 20, power 120: floor(14400/20) = 720, /50 = 14.
  local beam = moves[SOLAR_BEAM]
  check("Solar Beam clear: 16", dmg(20, beam, nil, SOLAR_BEAM) == 16)
  for _, kind in ipairs({ "rain", "sandstorm", "hail" }) do
    check("Solar Beam halved in " .. kind .. ": 7 + 2", dmg(20, beam, kind, SOLAR_BEAM) == 9)
  end
  check("Solar Beam not halved in sun", dmg(20, beam, "sun", SOLAR_BEAM) == 16)
  check("halving keys on the move id, not the effect", dmg(20, beam, "rain", nil) == 16)
end

---------------------------------------------------------------------------
-- Damage terms through the engine (each call site)
---------------------------------------------------------------------------
do
  -- Ordinary hit: Water Gun, acc 0, crit 1 (no crit), random 0 (x100/100);
  -- player Normal (no STAB), foe Normal (neutral). base 4 (spAtk 20,
  -- power 40: 4800/20 = 240, /50 = 4); rain 6 + 2 = 8; clear 6.
  local function waterGunHit(weather, opts)
    opts = opts or {}
    opts.playerMoves = { WATER_GUN }
    opts.weather = weather
    opts.foeHP = 400
    local b = battle({ 0, 1, 0, MISS }, opts)
    local events = b:runTurn(MOVE, MOVE)
    return find(events, "damage", "player").amount, b
  end
  check("engine: rain Water Gun 8", (waterGunHit("rain")) == 8)
  check("engine: clear Water Gun 6", (waterGunHit(nil)) == 6)
  check("engine: sun Water Gun 4", (waterGunHit("sun")) == 4)
  check("engine: Cloud Nine (foe) removes the rain term", (waterGunHit("rain",
    { foeAbility = BattleEngine.ABILITY_CLOUD_NINE })) == 6)
  check("engine: Air Lock (player) removes the rain term", (waterGunHit("rain",
    { playerAbility = BattleEngine.ABILITY_AIR_LOCK })) == 6)
  local _, b = waterGunHit("rain")
  check("engine: weather adds no draw (3 hit + 1 miss)", b.rng.draws == 4, b.rng.draws)
end

do
  -- Multi-hit site (synthetic Water Double Kick shape): acc, then (crit,
  -- random) x 2. Each hit 8 in rain (as above) vs 6 clear.
  for _, row in ipairs({ { "rain", 16 }, { nil, 12 } }) do
    local b = battle({ 0, 1, 0, 1, 0, MISS }, { playerMoves = { FX_DOUBLE }, weather = row[1], foeHP = 400 })
    b:runTurn(MOVE, MOVE)
    check("multi-hit site passes the weather (" .. tostring(row[1]) .. ")", 400 - b.foe.hp == row[2], 400 - b.foe.hp)
  end
  -- Triple Kick site (synthetic Water): (acc, crit, random) x 3, powers
  -- 10/20/30 -> base 1/2/3 (60/50, 120/50, 180/50); rain 1/3/4 -> 3+5+6 = 14;
  -- clear 3+4+5 = 12.
  for _, row in ipairs({ { "rain", 14 }, { nil, 12 } }) do
    local b = battle({ 0, 1, 0, 0, 1, 0, 0, 1, 0, MISS }, { playerMoves = { FX_TRIPLE }, weather = row[1], foeHP = 400 })
    b:runTurn(MOVE, MOVE)
    check("Triple Kick site passes the weather (" .. tostring(row[1]) .. ")", 400 - b.foe.hp == row[2], 400 - b.foe.hp)
  end
  -- Explosion site (synthetic Water): crit, random, acc. Special branch uses
  -- spDefense (the halving is on defense): 20*250*6/20 = 1500, /50 = 30;
  -- rain 45 + 2 = 47; clear 32.
  for _, row in ipairs({ { "rain", 47 }, { nil, 32 } }) do
    local b = battle({ 1, 0, 0 }, { playerMoves = { FX_BOOM }, weather = row[1], foeHP = 400 })
    b:runTurn(MOVE, MOVE)
    check("Explosion site passes the weather (" .. tostring(row[1]) .. ")", 400 - b.foe.hp == row[2], 400 - b.foe.hp)
  end
end

do
  -- Solar Beam release turn. Turn 1: the player charges (no draw), the foe
  -- sets the weather (no draw). Turn 2: release (acc, crit, random); the
  -- foe's weather move fails (own family). base 14 -> rain/sand/hail 7 + 2
  -- = 9, clear 16 (no STAB: player Normal; neutral vs Normal).
  for _, row in ipairs({ { "rain", 9 }, { "sandstorm", 9 }, { "hail", 9 }, { "sun", 16 } }) do
    local b = battle({}, { playerMoves = { SOLAR_BEAM }, foeMoves = { WEATHER_MOVE[row[1]] }, foeHP = 400 })
    local t1 = b:runTurn(MOVE, MOVE)
    b.rng = scriptedRng({ 0, 1, 0 })
    local t2 = b:runTurn(MOVE, MOVE)
    local hit = find(t2, "damage", "player")
    check("Solar Beam release in " .. row[1] .. " deals " .. row[2], find(t1, "chargeTurn", "player")
      and hit and hit.amount == row[2], hit and hit.amount)
    check("Solar Beam release in " .. row[1] .. ": three draws", b.rng.draws == 3, b.rng.draws)
  end
  -- (Sun's charge/PP path is W2: in source a charged Solar Beam released in
  -- sun also spends a second PP; only the damage is asserted here.)
end

---------------------------------------------------------------------------
-- Freeze blocked in sun
---------------------------------------------------------------------------
do
  -- Ice Beam: acc 0, crit 1, random 0, effect roll 0 (<= 10 passes), foe miss.
  local function iceBeam(weather, opts)
    opts = opts or {}
    opts.playerMoves = { ICE_BEAM }
    opts.weather = weather
    opts.foeHP = 400
    local b = battle({ 0, 1, 0, 0, MISS }, opts)
    local events = b:runTurn(MOVE, MOVE)
    return b, events
  end
  local b, events = iceBeam("sun")
  check("sun: passing freeze roll freezes nothing", b.foe.status == 0 and not find(events, "statusApplied"),
    types(events))
  check("sun: the roll is still drawn (5 draws)", b.rng.draws == 5, b.rng.draws)
  b, events = iceBeam(nil)
  check("clear: the same roll freezes", S.isFrozen(b.foe.status) and b.rng.draws == 5)
  b, events = iceBeam("rain")
  check("rain: freezes", S.isFrozen(b.foe.status))
  b, events = iceBeam("sun", { foeAbility = BattleEngine.ABILITY_CLOUD_NINE })
  check("sun under Cloud Nine: freezes", S.isFrozen(b.foe.status))
  -- Tri Attack: acc, crit, random, % 100 roll (0 <= 20), % 3 = 1 -> freeze.
  b = battle({ 0, 1, 0, 0, 1, MISS }, { playerMoves = { TRI_ATTACK }, weather = "sun", foeHP = 400 })
  events = b:runTurn(MOVE, MOVE)
  check("sun: Tri Attack's freeze pick fails silently after both draws", b.foe.status == 0
    and b.rng.draws == 6, b.rng.draws)
  b = battle({ 0, 1, 0, 0, 1, MISS }, { playerMoves = { TRI_ATTACK }, foeHP = 400 })
  b:runTurn(MOVE, MOVE)
  check("clear: the same Tri Attack draws freeze", S.isFrozen(b.foe.status))
end

---------------------------------------------------------------------------
-- AI_CheckBadMove rows
---------------------------------------------------------------------------
do
  local user = { types = { 0, 0 }, statStages = {}, hp = 10, maxHP = 10, status = 0, ability = 0 }
  local function score(moveId, weather, targetAbility)
    local target = { types = { 0, 0 }, statStages = {}, hp = 10, maxHP = 10, status = 0, ability = targetAbility }
    return AICheckBadMove.score(user, target, moves[moveId], moveId, Data.typeChart, {}, weather)
  end
  for _, own in ipairs(KINDS) do
    for _, w in ipairs(KINDS) do
      local want = (own == w) and -8 or 0
      check(("AI %s under %s: %d"):format(own, w, want), score(WEATHER_MOVE[own], w, 1) == want)
    end
  end
  -- Stale funcResult in clear weather: the target's ability id.
  -- Rain Dance vs Stench (1), Sandstorm vs Drizzle (2), Hail vs Speed Boost (3),
  -- Sunny Day vs 0 (fixture-only).
  check("AI clear: Rain Dance vs ability 1 -> -8", score(RAIN_DANCE, nil, 1) == -8)
  check("AI clear: Sandstorm vs ability 2 -> -8", score(SANDSTORM, nil, 2) == -8)
  check("AI clear: Hail vs ability 3 -> -8", score(HAIL, nil, 3) == -8)
  check("AI clear: Sunny Day vs ability 0 -> -8", score(SUNNY_DAY, nil, 0) == -8)
  check("AI clear: Rain Dance vs ability 0 -> 0", score(RAIN_DANCE, nil, 0) == 0)
  check("AI clear: Sunny Day vs ability 1 -> 0", score(SUNNY_DAY, nil, 1) == 0)
  check("AI clear: Hail vs ability 2 -> 0", score(HAIL, nil, 2) == 0)
  check("AI clear: other ability ids never match", score(SANDSTORM, nil, 13) == 0)
  check("AI: active weather overrides the stale ability", score(SANDSTORM, "rain", 2) == 0)
end

do
  -- Through TrainerAI (CHECK_BAD_MOVE): Rain Dance 92 vs Tackle 100 picks
  -- Tackle with one choice draw; get_weather ignores Cloud Nine.
  local function choose(weather, playerAbility)
    local b = battle({ 0 }, { foeMoves = { RAIN_DANCE, Data.MOVE_TACKLE }, weather = weather,
      playerAbility = playerAbility })
    return TrainerAI.choose(b, TrainerAI.AI_SCRIPT_CHECK_BAD_MOVE), b
  end
  check("TrainerAI: in rain the foe avoids Rain Dance", (choose("rain", 0)) == 2)
  check("TrainerAI: Cloud Nine does not hide the weather from the AI",
    (choose("rain", BattleEngine.ABILITY_CLOUD_NINE)) == 2)
  check("TrainerAI: clear weather vs a Stench target avoids Rain Dance", (choose(nil, 1)) == 2)
  local slot, b = choose(nil, 0)
  check("TrainerAI: clear weather vs ability 0, tie broken by the draw", slot == 1 and b.rng.draws == 1, slot)
end

---------------------------------------------------------------------------
-- Controller texts
---------------------------------------------------------------------------
do
  local b = battle({}, {})
  local c = BattleSceneController.new({ engine = b, playerName = "BULBASAUR", foeName = "CHARMANDER",
    moveName = function() return "MOVE" end })
  local m = c:_eventMessages({
    { type = "weatherSet", side = "player", kind = "rain" },
    { type = "weatherSet", side = "player", kind = "sandstorm" },
    { type = "weatherSet", side = "foe", kind = "sun" },
    { type = "weatherSet", side = "foe", kind = "hail" },
    { type = "weatherContinues", kind = "rain" },
    { type = "weatherContinues", kind = "sandstorm" },
    { type = "weatherContinues", kind = "sun" },
    { type = "weatherContinues", kind = "hail" },
    { type = "weatherEnded", kind = "rain" },
    { type = "weatherEnded", kind = "sandstorm" },
    { type = "weatherEnded", kind = "sun" },
    { type = "weatherEnded", kind = "hail" },
  })
  local want = {
    "It started to rain!", "A sandstorm brewed!", "The sunlight got bright!", "It started to hail!",
    "Rain continues to fall.", "The sandstorm rages.", "The sunlight is strong.", "Hail continues to fall.",
    "The rain stopped.", "The sandstorm subsided.", "The sunlight faded.", "The hail stopped.",
  }
  for i, text in ipairs(want) do
    check("text " .. i .. ": " .. text, m[i] and m[i].text == text, m[i] and m[i].text)
  end
  m = c:_eventMessages({
    { type = "weatherDamage", side = "player", kind = "sandstorm", amount = 10, hpRemaining = 150 },
    { type = "weatherDamage", side = "foe", kind = "hail", amount = 10, hpRemaining = 140 },
  })
  check("sandstorm damage text then HP", m[1].text == "BULBASAUR is buffeted\nby the sandstorm!"
    and m[2].text == nil and m[2].hpSide == "player" and m[2].hp == 150, m[1].text)
  check("hail damage text then HP", m[3].text == "CHARMANDER is pelted\nby HAIL!"
    and m[4].hpSide == "foe" and m[4].hp == 140, m[3].text)
end

do
  -- Through the real engine: Sandstorm, foe miss, end-of-turn text, both ticks.
  local b = battle({ MISS }, { playerMoves = { SANDSTORM } })
  local c = BattleSceneController.new({ engine = b, playerName = "BULBASAUR", foeName = "CHARMANDER",
    moveName = function(id) return id == SANDSTORM and "SANDSTORM" or "TACKLE" end })
  local events = b:runTurn(MOVE, MOVE)
  local texts = {}
  for _, e in ipairs(c:_eventMessages(events)) do if e.text then texts[#texts + 1] = e.text end end
  local joined = table.concat(texts, "|")
  check("engine -> controller order", joined == table.concat({
    "BULBASAUR used SANDSTORM!", "A sandstorm brewed!", "CHARMANDER used TACKLE!",
    "CHARMANDER's attack missed!", "The sandstorm rages.", "BULBASAUR is buffeted\nby the sandstorm!",
    "CHARMANDER is buffeted\nby the sandstorm!" }, "|"), joined)
  -- The failure path reuses "But it failed!".
  b = battle({ MISS }, { playerMoves = { SANDSTORM }, weather = "sandstorm" })
  events = b:runTurn(MOVE, MOVE)
  local m = c:_eventMessages(events)
  check("engine failure -> But it failed!", m[2] and m[2].text == "But it failed!", m[2] and m[2].text)
end

print(("battle_weather_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
