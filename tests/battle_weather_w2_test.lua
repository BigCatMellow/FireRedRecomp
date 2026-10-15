-- Run: lua5.1 tests/battle_weather_w2_test.lua
--
-- Weather slice W2 (work/tasks/phase4-weather-w2.md). Oracles come from
-- pret/pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788:
--   * Thunder: AccuracyCalcHelper src/battle_script_commands.c:958-1001
--     (rain sure hit with no Random(), after the Dig/Dive miss, :993-998);
--     Cmd_accuracycheck :1062-1064 (sun: accuracy 50 before the stage ratio);
--   * Solar Beam: data/battle_scripts_1.s:1899-1914 (sun path: lock and
--     ppreduce before attackcanceler), :784-792 (TwoTurnMovesSecondTurn);
--     Cmd_ppreduce :1146-1152 (deducts only while pp > 0); attackcanceler's
--     0-PP check bypassed by MULTIPLETURNS :838-839; freeze does not cancel
--     the lock, paralysis/flinch/confusion self-hit do (src/battle_util.c
--     :1266-1525, data/battle_scripts_1.s:3695-3742); sleep is cancelled at
--     end of turn (src/battle_main.c:2941-2942); the frozen-then-select oracle
--     is the design review's F2 correction;
--   * Weather Ball: Cmd_setweatherballtype :9345-9364 (dmgMultiplier 2 and
--     the dynamic type, under WEATHER_HAS_EFFECT), Cmd_damagecalc :1209-1220
--     (dmgMultiplier multiplies CalculateBaseDamage's result, +2 included),
--     src/pokemon.c:2605-2637 (rain/sun 1.5 in the special branch);
--   * heals: data/battle_scripts_1.s:1726-1733, :2028-2042;
--     Cmd_recoverbasedonsunlight :8478-8501; texts src/battle_message.c:124-125;
--   * Cloud Nine/Air Lock: include/battle_util.h:49-50;
--   * AI: data/battle_ai_scripts.s:160-214 (no AI_CheckBadMove entry for
--     these effects), src/battle_ai_script_commands.c:981-982, :1205-1206
--     (the AI resets the dynamic type).
-- Every expected number below is worked from those formulas in the
-- comments, never read back from the engine.
package.path = package.path .. ";./?.lua"

local BattleEngine = require("src.core.BattleEngine")
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
local SOLAR_BEAM, THUNDER, WEATHER_BALL = 76, 87, 311
local MORNING_SUN, SYNTHESIS, MOONLIGHT = 234, 235, 236
local DIG, FLY, BITE = 91, 19, 44
local moves = {}
for id, m in pairs(Data.moves) do moves[id] = m end
moves[SANDSTORM] = rec(115, 0, Data.TYPE_ROCK, 0, 10, 0, 0x10, 0)
moves[RAIN_DANCE] = rec(136, 0, Data.TYPE_WATER, 0, 5, 0, 0x10, 0)
moves[SUNNY_DAY] = rec(137, 0, Data.TYPE_FIRE, 0, 5, 0, 0x10, 0)
moves[HAIL] = rec(164, 0, Data.TYPE_ICE, 0, 10, 0, 0x10, 0x02)
moves[SOLAR_BEAM] = rec(151, 120, Data.TYPE_GRASS, 100, 10, 0, 0, 0x32)
moves[THUNDER] = rec(152, 120, Data.TYPE_ELECTRIC, 70, 10, 30, 0, 0x12)
moves[WEATHER_BALL] = rec(203, 50, Data.TYPE_NORMAL, 100, 10, 0, 0, 0x32)
moves[MORNING_SUN] = rec(132, 0, Data.TYPE_NORMAL, 0, 5, 0, 0x10, 0x08)
moves[SYNTHESIS] = rec(133, 0, Data.TYPE_GRASS, 0, 5, 0, 0x10, 0x08)
moves[MOONLIGHT] = rec(134, 0, Data.TYPE_NORMAL, 0, 5, 0, 0x10, 0x08)
moves[DIG] = rec(155, 60, Data.TYPE_GROUND, 100, 10, 0, 0, 0x13)
moves[FLY] = rec(155, 70, Data.TYPE_FLYING, 95, 15, 0, 0, 0x13)
moves[BITE] = rec(31, 60, Data.TYPE_DARK, 100, 25, 30, 0, 0x33)

local WEATHER_MOVE = { rain = RAIN_DANCE, sun = SUNNY_DAY, sandstorm = SANDSTORM, hail = HAIL }
local KINDS = { "rain", "sun", "sandstorm", "hail" }
local CLOUD_NINE, AIR_LOCK = BattleEngine.ABILITY_CLOUD_NINE, BattleEngine.ABILITY_AIR_LOCK
local ABILITY_HUSTLE, ABILITY_THICK_FAT, ABILITY_TORRENT = 55, 47, 67
local ABILITY_WATER_ABSORB = 11
local T = Data

local function moveList(list, pp)
  local out = {}
  for i, id in ipairs(list) do out[i] = { move = id, pp = pp or 10 } end
  return out
end

-- Level 10 (level factor 2*10/5 + 2 = 6), defense/spDefense 20. Default:
-- player faster (30 vs 20), player Psychic (no STAB on any move used here
-- unless a test sets types), foe Normal, 400 HP so nothing faints.
local function battle(values, opts)
  opts = opts or {}
  local engine = BattleEngine.new({
    player = BattleEngine.makeBattler({ species = 1, level = 10,
      stats = { hp = opts.playerHP or 400, attack = opts.playerAttack or 20, defense = 20,
        speed = opts.playerSpeed or 30, spAttack = opts.playerSpAttack or 20, spDefense = 20 },
      types = opts.playerTypes or { T.TYPE_PSYCHIC, T.TYPE_PSYCHIC },
      status = opts.playerStatus, moves = moveList(opts.playerMoves or { Data.MOVE_TACKLE }, opts.playerPP) }),
    foe = BattleEngine.makeBattler({ species = 4, level = 10,
      stats = { hp = opts.foeHP or 400, attack = 20, defense = 20, speed = opts.foeSpeed or 20,
        spAttack = 20, spDefense = 20 },
      types = opts.foeTypes or { T.TYPE_NORMAL, T.TYPE_NORMAL },
      status = opts.foeStatus, moves = moveList(opts.foeMoves or { Data.MOVE_TACKLE }) }),
    moves = moves, typeChart = Data.typeChart, rng = scriptedRng(values),
  })
  engine.player.ability = opts.playerAbility or 0
  engine.foe.ability = opts.foeAbility or 0
  if opts.playerCurrentHP then engine.player.hp = opts.playerCurrentHP end
  if opts.weather then
    engine.weather = { kind = opts.weather, permanent = false }
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
local function dealt(events)
  local e = find(events, "damage", "player")
  return e and e.amount
end

---------------------------------------------------------------------------
-- Thunder (effect 152)
---------------------------------------------------------------------------
-- Damage when it hits: spAtk 20, power 120: 20*120*6/20 = 720, /50 = 14,
-- + 2 = 16 (Psychic user, Normal target, random draw 0 -> x100/100).
-- Draw order on a hit: accuracy (unless rain), crit, random, the 30%
-- paralysis roll (99 fails it). Then the foe's Tackle misses (one draw).
do
  -- Rain: a first value of 99 would miss a 70-accuracy roll; with no
  -- accuracy draw it is the crit roll (99 % 16 = 3, no crit).
  local b = battle({ 99, 0, 99, MISS }, { playerMoves = { THUNDER }, weather = "rain" })
  local events = b:runTurn(MOVE, MOVE)
  check("Thunder rain: sure hit", dealt(events) == 16 and not find(events, "miss", "player"), types(events))
  check("Thunder rain: no accuracy draw (crit, random, effect + foe miss = 4)", b.rng.draws == 4, b.rng.draws)
  check("Thunder rain: PP spent", b.player.moves[1].pp == 9)

  -- Clear: the same first value is the accuracy roll: 100 > 70 misses.
  b = battle({ 99, MISS }, { playerMoves = { THUNDER } })
  events = b:runTurn(MOVE, MOVE)
  check("Thunder clear: 99 misses (one draw)", find(events, "miss", "player") and b.rng.draws == 2, types(events))

  -- Rain: the paralysis roll is still drawn and can pass (0 <= 30). The
  -- paralyzed foe then draws its % 4 (1: acts) and misses.
  b = battle({ 1, 0, 0, 1, MISS }, { playerMoves = { THUNDER }, weather = "rain" })
  b:runTurn(MOVE, MOVE)
  check("Thunder rain: paralysis secondary still applies", S.isParalyzed(b.foe.status) and b.rng.draws == 5,
    b.rng.draws)

  -- Rain vs a Dig target: the underground miss comes first (no draws at
  -- all: Dig's charge and the miss draw nothing).
  b = battle({}, { playerMoves = { THUNDER }, foeMoves = { DIG }, foeSpeed = 40, weather = "rain" })
  events = b:runTurn(MOVE, MOVE)
  check("Thunder rain vs Dig: misses", find(events, "miss", "player") and not dealt(events), types(events))
  check("Thunder rain vs Dig: zero draws", b.rng.draws == 0, b.rng.draws)
  check("Thunder rain vs Dig: PP spent", b.player.moves[1].pp == 9)

  -- Rain vs a Fly target: Thunder ignores ON_AIR, so it is still a sure hit.
  b = battle({ 1, 0, 99 }, { playerMoves = { THUNDER }, foeMoves = { FLY }, foeSpeed = 40, weather = "rain" })
  events = b:runTurn(MOVE, MOVE)
  check("Thunder rain vs Fly: sure hit with 3 draws", dealt(events) == 16 and b.rng.draws == 3, b.rng.draws)
end

do
  -- Sun: accuracy 50. Roll r hits when r % 100 + 1 <= 50.
  local function sunThunder(first, opts)
    opts = opts or {}
    opts.playerMoves = { THUNDER }
    opts.weather = opts.weather or "sun"
    local values = { first, 1, 0, 99, MISS }
    if opts.misses then values = { first, MISS } end
    local b = battle(values, opts)
    local events = b:runTurn(MOVE, MOVE)
    return b, events
  end
  local b, events = sunThunder(49)
  check("Thunder sun: 49 + 1 = 50 hits", dealt(events) == 16 and b.rng.draws == 5, b.rng.draws)
  b, events = sunThunder(50, { misses = true })
  check("Thunder sun: 50 + 1 = 51 misses (one draw)", find(events, "miss", "player") and b.rng.draws == 2,
    types(events))
  b, events = sunThunder(50, { weather = "sandstorm" })
  check("Thunder sandstorm: 70 (51 hits)", dealt(events) ~= nil, types(events))
  b, events = sunThunder(69, { weather = "hail" })
  check("Thunder hail: 70 (70 hits)", dealt(events) ~= nil, types(events))
  b, events = sunThunder(70, { weather = "hail", misses = true })
  check("Thunder hail: 70 (71 misses)", find(events, "miss", "player") ~= nil, types(events))
  -- Sun's 50 goes through the stage ratio: +1 accuracy, 133*50/100 = 66.
  b = battle({ 65, 1, 0, 99, MISS }, { playerMoves = { THUNDER }, weather = "sun" })
  b.player.statStages.accuracy = 7
  events = b:runTurn(MOVE, MOVE)
  check("Thunder sun +1: 66 hits", dealt(events) ~= nil, types(events))
  b = battle({ 66, MISS }, { playerMoves = { THUNDER }, weather = "sun" })
  b.player.statStages.accuracy = 7
  events = b:runTurn(MOVE, MOVE)
  check("Thunder sun +1: 67 misses (50 replaced before the ratio)", find(events, "miss", "player") ~= nil,
    types(events))
end

do
  -- Cloud Nine / Air Lock: ordinary 70 in rain and in sun.
  for _, row in ipairs({ { "foe Cloud Nine", { foeAbility = CLOUD_NINE } },
      { "player Air Lock", { playerAbility = AIR_LOCK } },
      { "player Cloud Nine", { playerAbility = CLOUD_NINE } },
      { "foe Air Lock", { foeAbility = AIR_LOCK } } }) do
    local opts = row[2]
    opts.playerMoves = { THUNDER }
    opts.weather = "rain"
    local b = battle({ 70, MISS }, opts)
    local events = b:runTurn(MOVE, MOVE)
    check("Thunder rain, " .. row[1] .. ": rolls 70 (71 misses)", find(events, "miss", "player")
      and b.rng.draws == 2, types(events))
    opts.weather = "sun"
    b = battle({ 60, 1, 0, 99, MISS }, opts)
    events = b:runTurn(MOVE, MOVE)
    check("Thunder sun, " .. row[1] .. ": rolls 70 (61 hits)", dealt(events) == 16 and b.rng.draws == 5,
      types(events))
  end
  -- WEATHER_HAS_EFFECT is HP-gated: a 0-HP holder no longer suppresses.
  local b = battle({}, { playerMoves = { THUNDER }, weather = "rain", foeAbility = CLOUD_NINE })
  b.foe.hp = 0
  check("Thunder rain: a fainted Cloud Nine holder does not suppress (sure hit, 0 draws)",
    b:accuracyRoll(b.player, b.foe, moves[THUNDER], THUNDER) == true and b.rng.draws == 0, b.rng.draws)
end

do
  -- W1 interaction: rain set this turn by a faster foe, then Thunder is
  -- sure; rain stops at the end of the turn it reaches 0, and Thunder rolls
  -- again the next turn.
  local b = battle({ 99, 0, 99 }, { playerMoves = { THUNDER }, foeMoves = { RAIN_DANCE, Data.MOVE_TACKLE },
    foeSpeed = 40 })
  local events = b:runTurn(MOVE, MOVE)
  check("W1: Rain Dance then Thunder in the same turn is sure (3 draws)", dealt(events) == 16
    and b.rng.draws == 3, b.rng.draws)
  b = battle({ 1, 0, 99, MISS }, { playerMoves = { THUNDER }, weather = "rain", duration = 1 })
  events = b:runTurn(MOVE, MOVE)
  check("W1: last rain turn still sure, then the rain stops", dealt(events) == 16 and find(events, "weatherEnded")
    and b.rng.draws == 4, b.rng.draws)
  b.rng = scriptedRng({ 99, MISS })
  events = b:runTurn(MOVE, MOVE)
  check("W1: after the rain, Thunder draws accuracy again (99 misses)", find(events, "miss", "player")
    and b.rng.draws == 2, types(events))
end

---------------------------------------------------------------------------
-- Solar Beam (effect 151) sun path
---------------------------------------------------------------------------
-- Damage when it fires: spAtk 20, power 120 -> 14 + 2 = 16 (Psychic user,
-- Normal target; no halving in sun or clear weather).
do
  local b = battle({ 0, 1, 0, MISS }, { playerMoves = { SOLAR_BEAM }, weather = "sun" })
  local events = b:runTurn(MOVE, MOVE)
  check("Solar Beam sun: fires on turn 1", dealt(events) == 16 and not find(events, "chargeTurn"), types(events))
  check("Solar Beam sun: exactly one PP", b.player.moves[1].pp == 9, b.player.moves[1].pp)
  check("Solar Beam sun: hit draws on the selection turn (acc, crit, random + foe miss)", b.rng.draws == 4,
    b.rng.draws)
  check("Solar Beam sun: no lock left", not b.player.charging and b.player.lockedSlot == nil
    and not b:isLocked("player"))
  local _, ui = find(events, "useMove", "player")
  local _, di = find(events, "damage", "player")
  check("Solar Beam sun: useMove then the hit", ui and di and ui < di, types(events))

  -- Sunny Day by a faster foe makes the same turn's Solar Beam fire.
  b = battle({ 0, 1, 0 }, { playerMoves = { SOLAR_BEAM }, foeMoves = { SUNNY_DAY }, foeSpeed = 40 })
  events = b:runTurn(MOVE, MOVE)
  check("Solar Beam: sun set earlier this turn -> fires (3 draws, 1 PP)", dealt(events) == 16
    and b.rng.draws == 3 and b.player.moves[1].pp == 9, types(events))
end

do
  -- Paralysis cancels after the PP is spent and clears the lock. Speed 100
  -- (25 after the paralysis quarter) keeps the player first. Draws: the
  -- paralysis % 4 (0 = fully paralyzed), then the foe's miss.
  local b = battle({ 0, MISS }, { playerMoves = { SOLAR_BEAM }, weather = "sun", playerStatus = S.PARALYSIS,
    playerSpeed = 100 })
  local events = b:runTurn(MOVE, MOVE)
  check("Solar Beam sun + full paralysis: cancelled", find(events, "fullyParalyzed", "player")
    and not dealt(events), types(events))
  check("Solar Beam sun + full paralysis: PP already spent", b.player.moves[1].pp == 9, b.player.moves[1].pp)
  check("Solar Beam sun + full paralysis: lock cleared", not b.player.charging and not b:isLocked("player"))
  check("Solar Beam sun + full paralysis: 2 draws", b.rng.draws == 2, b.rng.draws)
  -- Contrast: clear weather, the canceller precedes the charge, no PP.
  b = battle({ 0, MISS }, { playerMoves = { SOLAR_BEAM }, playerStatus = S.PARALYSIS, playerSpeed = 100 })
  b:runTurn(MOVE, MOVE)
  check("Solar Beam clear + full paralysis: no PP (canceller first)", b.player.moves[1].pp == 10)

  -- Flinch: the faster foe's Bite (acc, crit, random, 30% roll 0 passes)
  -- flinches; the sun path has already spent the PP; the lock is cleared.
  b = battle({ 0, 1, 0, 0 }, { playerMoves = { SOLAR_BEAM }, foeMoves = { BITE }, foeSpeed = 40, weather = "sun" })
  events = b:runTurn(MOVE, MOVE)
  check("Solar Beam sun + flinch: cancelled, PP spent, lock cleared", find(events, "flinched", "player")
    and b.player.moves[1].pp == 9 and not b.player.charging and not b:isLocked("player"), types(events))
  check("Solar Beam sun + flinch: 4 draws (Bite only)", b.rng.draws == 4, b.rng.draws)

  -- Confusion self-hit: "is confused", & 1 = 0 hurts itself (then the
  -- self-hit's random draw); the PP is spent, the lock cleared.
  b = battle({ 0, 0, MISS }, { playerMoves = { SOLAR_BEAM }, weather = "sun" })
  b.player.confusionTurns = 3
  events = b:runTurn(MOVE, MOVE)
  check("Solar Beam sun + confusion self-hit: PP spent, lock cleared", find(events, "confusionSelfHit", "player")
    and b.player.moves[1].pp == 9 and not b.player.charging and not b:isLocked("player"), types(events))
  check("Solar Beam sun + confusion self-hit: 3 draws", b.rng.draws == 3, b.rng.draws)
end

do
  -- Sleep: the PP is spent and the lock set before "fast asleep"; the
  -- end-of-turn sleep cancel (src/battle_main.c:2941-2942) clears it. No
  -- sleep draw; only the foe's miss.
  local b = battle({ MISS }, { playerMoves = { SOLAR_BEAM }, weather = "sun", playerStatus = S.withSleepTurns(0, 3) })
  local events = b:runTurn(MOVE, MOVE)
  check("Solar Beam sun + sleep: fast asleep, PP spent", find(events, "fastAsleep", "player")
    and b.player.moves[1].pp == 9, types(events))
  check("Solar Beam sun + sleep: lock cancelled at end of turn", not b.player.charging
    and b.player.lockedSlot == nil and not b:isLocked("player"))
  check("Solar Beam sun + sleep: 1 draw", b.rng.draws == 1, b.rng.draws)
  -- Waking this turn (counter 1 -> 0): it fires with that one PP.
  b = battle({ 0, 1, 0, MISS }, { playerMoves = { SOLAR_BEAM }, weather = "sun", playerStatus = S.withSleepTurns(0, 1) })
  events = b:runTurn(MOVE, MOVE)
  check("Solar Beam sun + waking: fires, 1 PP, 4 draws", find(events, "wokeUp", "player") and dealt(events) == 16
    and b.player.moves[1].pp == 9 and b.rng.draws == 4, types(events))
end

do
  -- Review F2: frozen first, then Solar Beam selected in sun.
  -- Sun at duration 2: continues after turn 1, stops after turn 2.
  -- Each frozen turn draws the freeze % 5 (1 = stays frozen), then the
  -- foe's Tackle misses.
  local b = battle({ 1, MISS }, { playerMoves = { SOLAR_BEAM }, weather = "sun", duration = 2,
    playerStatus = S.FREEZE })
  local events = b:runTurn(MOVE, MOVE)
  check("F2 turn 1: frozen solid", find(events, "frozenSolid", "player") and not dealt(events), types(events))
  check("F2 turn 1: PP spent before the freeze check", b.player.moves[1].pp == 9, b.player.moves[1].pp)
  check("F2 turn 1: lock kept", b.player.charging and b.player.lockedSlot == 1 and b:isLocked("player"))
  check("F2 turn 1: 2 draws", b.rng.draws == 2, b.rng.draws)

  b.rng = scriptedRng({ 1, MISS })
  events = b:runTurn(MOVE, MOVE)
  check("F2 turn 2 (sun): locked, PP spent again", find(events, "frozenSolid", "player")
    and b.player.moves[1].pp == 8 and b:isLocked("player"), b.player.moves[1].pp)
  check("F2 turn 2: sun ends at this end of turn", find(events, "weatherEnded") and b.weather.kind == nil)
  check("F2 turn 2: 2 draws", b.rng.draws == 2, b.rng.draws)

  b.rng = scriptedRng({ 1, MISS })
  events = b:runTurn(MOVE, MOVE)
  check("F2 turn 3 (no sun): still frozen and locked, no PP", find(events, "frozenSolid", "player")
    and b.player.moves[1].pp == 8 and b:isLocked("player"), b.player.moves[1].pp)
  check("F2 turn 3: 2 draws", b.rng.draws == 2, b.rng.draws)

  -- Thaw (% 5 = 0): fires with no PP (NO_PPDEDUCT); acc, crit, random,
  -- then the foe's miss.
  b.rng = scriptedRng({ 0, 0, 1, 0, MISS })
  events = b:runTurn(MOVE, MOVE)
  check("F2 thaw turn: thawed and fires", find(events, "thawed", "player") and dealt(events) == 16, types(events))
  check("F2 thaw turn: no PP", b.player.moves[1].pp == 8, b.player.moves[1].pp)
  check("F2 thaw turn: lock cleared", not b.player.charging and not b:isLocked("player"))
  check("F2 thaw turn: 5 draws", b.rng.draws == 5, b.rng.draws)
end

do
  -- F2 variant: thawing while the sun lasts spends that turn's PP too.
  local b = battle({ 1, MISS }, { playerMoves = { SOLAR_BEAM }, weather = "sun", playerStatus = S.FREEZE })
  b:runTurn(MOVE, MOVE)
  b.rng = scriptedRng({ 0, 0, 1, 0, MISS })
  local events = b:runTurn(MOVE, MOVE)
  check("F2 sun thaw: fires, two PP in all, 5 draws", find(events, "thawed", "player") and dealt(events) == 16
    and b.player.moves[1].pp == 8 and b.rng.draws == 5, b.player.moves[1].pp)

  -- W1 interaction: frozen in clear weather, the faster foe sets sun, then
  -- the frozen player selects Solar Beam: the sun path spends the PP and
  -- locks; the freeze draw (1) keeps it frozen. 1 draw.
  b = battle({ 1 }, { playerMoves = { SOLAR_BEAM }, foeMoves = { SUNNY_DAY, Data.MOVE_TACKLE }, foeSpeed = 40,
    playerStatus = S.FREEZE })
  events = b:runTurn(MOVE, MOVE)
  check("F2 via Sunny Day: frozen, PP spent, locked, 1 draw", find(events, "frozenSolid", "player")
    and b.player.moves[1].pp == 9 and b:isLocked("player") and b.rng.draws == 1, types(events))
end

do
  -- Charged before the sun: turn 1 charges in clear (one PP); the slower
  -- foe's Sunny Day follows. Turn 2: the release takes the sun path and
  -- spends a second PP, then fires (acc, crit, random); the foe's Sunny Day
  -- fails in its own family.
  local b = battle({}, { playerMoves = { SOLAR_BEAM }, foeMoves = { SUNNY_DAY } })
  local t1 = b:runTurn(MOVE, MOVE)
  check("charged then sun: turn 1 charges with one PP, no draw", find(t1, "chargeTurn", "player")
    and b.player.moves[1].pp == 9 and b.rng.draws == 0, types(t1))
  b.rng = scriptedRng({ 0, 1, 0 })
  local t2 = b:runTurn(MOVE, MOVE)
  check("charged then sun: release fires for 16", dealt(t2) == 16, types(t2))
  check("charged then sun: second PP spent", b.player.moves[1].pp == 8, b.player.moves[1].pp)
  check("charged then sun: 3 draws", b.rng.draws == 3, b.rng.draws)
  -- Contrast: released in clear weather, no second PP.
  b = battle({ MISS }, { playerMoves = { SOLAR_BEAM } })
  b:runTurn(MOVE, MOVE)
  b.rng = scriptedRng({ 0, 1, 0, MISS })
  b:runTurn(MOVE, MOVE)
  check("charged, released in clear: one PP in all", b.player.moves[1].pp == 9, b.player.moves[1].pp)
  -- Charged with its last PP: the sun-path ppreduce spends nothing at 0
  -- and the live lock bypasses the 0-PP check, so it still fires.
  b = battle({}, { playerMoves = { SOLAR_BEAM }, foeMoves = { SUNNY_DAY }, playerPP = 1 })
  b:runTurn(MOVE, MOVE)
  b.rng = scriptedRng({ 0, 1, 0 })
  t2 = b:runTurn(MOVE, MOVE)
  check("charged at 0 PP then sun: fires, PP stays 0", dealt(t2) == 16 and b.player.moves[1].pp == 0
    and not find(t2, "noPP"), types(t2))
end

do
  -- Cloud Nine / Air Lock force the charge in sun (HP-gated
  -- jumpifabilitypresent): chargeTurn, one PP, no hit; the foe's miss only.
  for _, row in ipairs({ { "foe Cloud Nine", { foeAbility = CLOUD_NINE } },
      { "player Air Lock", { playerAbility = AIR_LOCK } } }) do
    local opts = row[2]
    opts.playerMoves = { SOLAR_BEAM }
    opts.weather = "sun"
    local b = battle({ MISS }, opts)
    local events = b:runTurn(MOVE, MOVE)
    check("Solar Beam sun, " .. row[1] .. ": charges", find(events, "chargeTurn", "player")
      and not dealt(events) and b.player.moves[1].pp == 9 and b:isLocked("player"), types(events))
    check("Solar Beam sun, " .. row[1] .. ": 1 draw", b.rng.draws == 1, b.rng.draws)
  end
  -- Rain/sand/hail: still charges (W1 halving on release is in battle_weather_test).
  for _, kind in ipairs({ "rain", "sandstorm", "hail" }) do
    local b = battle({ MISS }, { playerMoves = { SOLAR_BEAM }, weather = kind })
    local events = b:runTurn(MOVE, MOVE)
    check("Solar Beam " .. kind .. ": charges", find(events, "chargeTurn", "player") and not dealt(events),
      types(events))
  end
end

---------------------------------------------------------------------------
-- Weather Ball (effect 203)
---------------------------------------------------------------------------
-- spAtk/atk 20, power 50: 20*50*6/20 = 300, /50 = 6. Physical with
-- attack 40: 40*50*6/20 = 600, /50 = 12.
-- rain/sun: Water/Fire special 6 -> 15*6/10 = 9 -> +2 = 11 -> x2 = 22.
-- hail: Ice special 6 + 2 = 8 -> x2 = 16.
-- sandstorm: Rock physical (attack 40) 12 + 2 = 14 -> x2 = 28.
-- clear: Normal physical (attack 40) 12 + 2 = 14 (x1).
-- Psychic user: no STAB; Normal target: neutral; random draw 0.
local function weatherBall(weather, values, opts)
  opts = opts or {}
  opts.playerMoves = { WEATHER_BALL }
  opts.weather = weather
  opts.playerAttack = opts.playerAttack or 40
  local b = battle(values or { 0, 1, 0, MISS }, opts)
  local events = b:runTurn(MOVE, MOVE)
  return dealt(events), b, events
end

do
  local want = { rain = 22, sun = 22, hail = 16, sandstorm = 28 }
  for _, kind in ipairs(KINDS) do
    local amount, b = weatherBall(kind)
    check("Weather Ball " .. kind .. ": " .. want[kind], amount == want[kind], amount)
    check("Weather Ball " .. kind .. ": 3 draws + foe miss", b.rng.draws == 4, b.rng.draws)
  end
  local amount = weatherBall(nil)
  check("Weather Ball clear: Normal physical, x1: 14", amount == 14, amount)
  -- Formula witnesses: x2 before the +2 would give rain 20 and hail 14;
  -- dropping the rain boost would give (6+2)*2 = 16.
  -- Cloud Nine / Air Lock: Normal at base power, no x2, no rain term.
  for _, kind in ipairs(KINDS) do
    amount = weatherBall(kind, nil, { foeAbility = CLOUD_NINE })
    check("Weather Ball " .. kind .. " under Cloud Nine: Normal 14", amount == 14, amount)
    amount = weatherBall(kind, nil, { playerAbility = AIR_LOCK })
    check("Weather Ball " .. kind .. " under Air Lock: Normal 14", amount == 14, amount)
  end
  local _, b = weatherBall("rain")
  check("Weather Ball: the shared record is never mutated", moves[WEATHER_BALL].type == T.TYPE_NORMAL
    and moves[WEATHER_BALL].power == 50 and moves[WEATHER_BALL].weatherBallDoubled == nil
    and b.moves[WEATHER_BALL].type == T.TYPE_NORMAL)
end

do
  -- Rock in sandstorm is physical: burn halves the attack branch (12 -> 6,
  -- + 2 = 8, x2 = 16); Reflect halves it (16); Light Screen does not (28).
  local amount = weatherBall("sandstorm", nil, { playerStatus = S.BURN })
  check("Weather Ball sandstorm: burn halves (physical) -> 16", amount == 16, amount)
  local b = battle({ 0, 1, 0, MISS }, { playerMoves = { WEATHER_BALL }, weather = "sandstorm", playerAttack = 40 })
  b.sideStatus.foe.reflect, b.sideStatus.foe.reflectTimer = true, 5
  local events = b:runTurn(MOVE, MOVE)
  check("Weather Ball sandstorm: Reflect halves -> 16", dealt(events) == 16, dealt(events))
  b = battle({ 0, 1, 0, MISS }, { playerMoves = { WEATHER_BALL }, weather = "sandstorm", playerAttack = 40 })
  b.sideStatus.foe.lightScreen, b.sideStatus.foe.lightScreenTimer = true, 5
  events = b:runTurn(MOVE, MOVE)
  check("Weather Ball sandstorm: Light Screen ignored -> 28", dealt(events) == 28, dealt(events))
  -- Rain Water is special: Light Screen 6 -> 3, rain 15*3/10 = 4, + 2 = 6, x2 = 12.
  b = battle({ 0, 1, 0, MISS }, { playerMoves = { WEATHER_BALL }, weather = "rain", playerAttack = 40 })
  b.sideStatus.foe.lightScreen, b.sideStatus.foe.lightScreenTimer = true, 5
  events = b:runTurn(MOVE, MOVE)
  check("Weather Ball rain: Light Screen then rain then +2 then x2 -> 12", dealt(events) == 12, dealt(events))
  -- Burn does not touch the special Water version (22).
  amount = weatherBall("rain", nil, { playerStatus = S.BURN })
  check("Weather Ball rain: burn ignored (special) -> 22", amount == 22, amount)
end

do
  -- STAB and effectiveness on the dynamic type.
  -- Rain, Water user vs Fire target: 22 -> STAB 33 -> x2 = 66.
  local amount = weatherBall("rain", nil, { playerTypes = { T.TYPE_WATER, T.TYPE_WATER }, foeTypes = { T.TYPE_FIRE, T.TYPE_FIRE } })
  check("Weather Ball rain: Water STAB and super effective -> 66", amount == 66, amount)
  -- Sun, Fire user vs Grass target: 22 -> 33 -> 66.
  amount = weatherBall("sun", nil, { playerTypes = { T.TYPE_FIRE, T.TYPE_FIRE }, foeTypes = { T.TYPE_GRASS, T.TYPE_GRASS } })
  check("Weather Ball sun: Fire STAB and super effective -> 66", amount == 66, amount)
  -- Hail vs Grass: 16 -> 32. Sandstorm Rock vs Fire: 28 -> 56.
  amount = weatherBall("hail", nil, { foeTypes = { T.TYPE_GRASS, T.TYPE_GRASS } })
  check("Weather Ball hail: Ice super effective vs Grass -> 32", amount == 32, amount)
  amount = weatherBall("sandstorm", nil, { foeTypes = { T.TYPE_FIRE, T.TYPE_FIRE } })
  check("Weather Ball sandstorm: Rock super effective vs Fire -> 56", amount == 56, amount)
  -- Review F1: Rock, not Ground (both physical, both super effective vs
  -- Fire): a Flying target takes Rock x2 (56); Ground would not affect it.
  amount = weatherBall("sandstorm", nil, { foeTypes = { T.TYPE_FLYING, T.TYPE_FLYING } })
  check("Weather Ball sandstorm: Rock super effective vs Flying -> 56", amount == 56, amount)
  -- Sun Fire vs Water: 22 -> 11.
  amount = weatherBall("sun", nil, { foeTypes = { T.TYPE_WATER, T.TYPE_WATER } })
  check("Weather Ball sun: Fire resisted by Water -> 11", amount == 11, amount)
  -- A Normal user gets no STAB on the Water version (22), but does on the
  -- plain one (14 -> 21).
  amount = weatherBall("rain", nil, { playerTypes = { T.TYPE_NORMAL, T.TYPE_NORMAL } })
  check("Weather Ball rain: Normal user, no STAB -> 22", amount == 22, amount)
  amount = weatherBall(nil, nil, { playerTypes = { T.TYPE_NORMAL, T.TYPE_NORMAL } })
  check("Weather Ball clear: Normal user, STAB -> 21", amount == 21, amount)
  -- Ghost target: the Water version hits; the Normal one has no effect
  -- (the random draw is still taken: 3 draws + the foe's miss).
  amount = weatherBall("rain", nil, { foeTypes = { T.TYPE_GHOST, T.TYPE_GHOST } })
  check("Weather Ball rain vs Ghost: hits for 22", amount == 22, amount)
  local _, b, events = weatherBall("rain", nil, { foeTypes = { T.TYPE_GHOST, T.TYPE_GHOST }, foeAbility = CLOUD_NINE })
  check("Weather Ball rain + Cloud Nine vs Ghost: Normal, no effect", find(events, "noEffect", "player")
    and not dealt(events) and b.rng.draws == 4, types(events))
end

do
  -- Other readers of the dynamic type.
  -- Thick Fat halves spAttack against Fire: 10*50*6/20 = 150, /50 = 3,
  -- sun 15*3/10 = 4, + 2 = 6, x2 = 12.
  local amount = weatherBall("sun", nil, { foeAbility = ABILITY_THICK_FAT })
  check("Weather Ball sun vs Thick Fat -> 12", amount == 12, amount)
  -- Hail Ice vs Thick Fat: 3 + 2 = 5, x2 = 10.
  amount = weatherBall("hail", nil, { foeAbility = ABILITY_THICK_FAT })
  check("Weather Ball hail vs Thick Fat -> 10", amount == 10, amount)
  -- Torrent at hp <= maxHP/3 (400/3 = 133): power 75: 20*75*6/20 = 450,
  -- /50 = 9, rain 13, + 2 = 15, x2 = 30.
  amount = weatherBall("rain", nil, { playerAbility = ABILITY_TORRENT, playerCurrentHP = 133 })
  check("Weather Ball rain + Torrent pinch -> 30", amount == 30, amount)
  amount = weatherBall(nil, nil, { playerAbility = ABILITY_TORRENT, playerCurrentHP = 133 })
  check("Weather Ball clear + Torrent: Normal, no pinch -> 14", amount == 14, amount)
  -- Hustle: the Water version is special, so no x80/100 accuracy (85 + 1
  -- hits 100); the Normal and Rock versions are physical (calc 80: misses).
  local _, b, events = weatherBall("rain", { 85, 1, 0, MISS }, { playerAbility = ABILITY_HUSTLE })
  check("Weather Ball rain + Hustle: special, 86 hits", dealt(events) ~= nil, types(events))
  _, b, events = weatherBall(nil, { 85, MISS }, { playerAbility = ABILITY_HUSTLE })
  check("Weather Ball clear + Hustle: physical, 86 misses", find(events, "miss", "player") ~= nil, types(events))
  _, b, events = weatherBall("sandstorm", { 85, MISS }, { playerAbility = ABILITY_HUSTLE })
  check("Weather Ball sandstorm + Hustle: physical Rock, 86 misses", find(events, "miss", "player") ~= nil,
    types(events))
  -- A critical hit: 11 x2 (crit) x2 (Weather Ball) = 44 in rain.
  amount = weatherBall("rain", { 0, 0, 0, MISS })
  check("Weather Ball rain crit: 11 * 2 * 2 = 44", amount == 44, amount)
end

do
  -- Move-end defrost through currentMove: the Fire version thaws a frozen
  -- target; the Normal one (Cloud Nine) does not, and the frozen foe then
  -- draws its freeze % 5 (1 = stays frozen).
  local _, b, events = weatherBall("sun", { 0, 1, 0, MISS }, { foeStatus = S.FREEZE })
  check("Weather Ball sun: Fire thaws the frozen target", find(events, "defrostedByFire", "foe")
    and b.foe.status == 0, types(events))
  check("Weather Ball sun thaw: 4 draws (the foe then attacks)", b.rng.draws == 4, b.rng.draws)
  _, b, events = weatherBall("sun", { 0, 1, 0, 1 }, { foeStatus = S.FREEZE, foeAbility = CLOUD_NINE })
  check("Weather Ball sun + Cloud Nine: Normal, no thaw", not find(events, "defrostedByFire")
    and S.isFrozen(b.foe.status) and find(events, "frozenSolid", "foe"), types(events))
end

do
  -- W1 interaction: Weather Ball follows the weather set earlier this turn,
  -- and the sandstorm it then sits in still deals its end-of-turn tick.
  local b = battle({ 0, 1, 0 }, { playerMoves = { WEATHER_BALL }, playerAttack = 40,
    foeMoves = { SANDSTORM }, foeSpeed = 40 })
  local events = b:runTurn(MOVE, MOVE)
  check("Weather Ball after a same-turn Sandstorm: Rock 28", dealt(events) == 28, dealt(events))
  check("Weather Ball after a same-turn Sandstorm: 3 draws", b.rng.draws == 3, b.rng.draws)
  -- Cross-family overwrite (W1): Rain Dance by the faster foe replaces
  -- the sun, so this turn's Weather Ball is Water.
  b = battle({ 0, 1, 0 }, { playerMoves = { WEATHER_BALL }, weather = "sun",
    foeMoves = { RAIN_DANCE }, foeSpeed = 40, foeTypes = { T.TYPE_FIRE, T.TYPE_FIRE } })
  events = b:runTurn(MOVE, MOVE)
  check("Weather Ball after Rain Dance overwrote sun: Water vs Fire 44", dealt(events) == 44, dealt(events))
end

---------------------------------------------------------------------------
-- Morning Sun / Synthesis / Moonlight (effects 132-134)
---------------------------------------------------------------------------
-- maxHP 79, current 1: clear floor(79/2) = 39; sun floor(20*79/30) =
-- floor(1580/30) = 52 (2/3 is 52.67: floored, not rounded); rain,
-- sandstorm, hail floor(79/4) = 19. No RNG of their own.
do
  local want = { clear = 39, sun = 52, rain = 19, sandstorm = 19, hail = 19 }
  for _, id in ipairs({ MORNING_SUN, SYNTHESIS, MOONLIGHT }) do
    for _, kind in ipairs({ "clear", "sun", "rain", "sandstorm", "hail" }) do
      local b = battle({ MISS }, { playerMoves = { id }, playerHP = 79, playerCurrentHP = 1,
        weather = kind ~= "clear" and kind or nil })
      local events = b:runTurn(MOVE, MOVE)
      local e = find(events, "restoreHP", "player")
      -- Sandstorm/hail then tick 79/16 = 4 at end of turn.
      local tick = (kind == "sandstorm" or kind == "hail") and 4 or 0
      check(("heal %d in %s: +%d"):format(id, kind, want[kind]), e and e.amount == want[kind]
        and e.beforeHP == 1 and e.hpRemaining == 1 + want[kind] and b.player.hp == 1 + want[kind] - tick,
        e and e.amount)
      check(("heal %d in %s: 1 PP, no draw of its own"):format(id, kind), b.player.moves[1].pp == 9
        and b.rng.draws == 1, b.rng.draws)
    end
  end
end

do
  -- Clamp: 70/79 in sun requests 52 and gets 9.
  local b = battle({ MISS }, { playerMoves = { SYNTHESIS }, playerHP = 79, playerCurrentHP = 70, weather = "sun" })
  local events = b:runTurn(MOVE, MOVE)
  local e = find(events, "restoreHP", "player")
  check("heal clamps to maxHP (+9)", e and e.amount == 9 and b.player.hp == 79, e and e.amount)
  -- Minimum 1: maxHP 3 in rain: floor(3/4) = 0 -> 1. Clear: floor(3/2) = 1.
  b = battle({ MISS }, { playerMoves = { MOONLIGHT }, playerHP = 3, playerCurrentHP = 1, weather = "rain" })
  events = b:runTurn(MOVE, MOVE)
  e = find(events, "restoreHP", "player")
  check("heal minimum 1 (maxHP 3, rain)", e and e.amount == 1 and b.player.hp == 2, e and e.amount)
  -- Sun at maxHP 2: floor(40/30) = 1.
  b = battle({ MISS }, { playerMoves = { MORNING_SUN }, playerHP = 2, playerCurrentHP = 1, weather = "sun" })
  events = b:runTurn(MOVE, MOVE)
  e = find(events, "restoreHP", "player")
  check("heal sun at maxHP 2: floor(40/30) = 1", e and e.amount == 1, e and e.amount)
  -- Full HP: BattleScript_AlreadyAtFullHp, PP still spent (ppreduce comes
  -- first), no draw.
  b = battle({ MISS }, { playerMoves = { MORNING_SUN }, weather = "sun" })
  events = b:runTurn(MOVE, MOVE)
  check("heal at full HP: restoreHPFull, no heal", find(events, "restoreHPFull", "player")
    and not find(events, "restoreHP"), types(events))
  check("heal at full HP: PP spent, 1 draw (foe)", b.player.moves[1].pp == 9 and b.rng.draws == 1, b.rng.draws)
  -- No accuracy check: a semi-invulnerable foe does not make it miss.
  b = battle({}, { playerMoves = { SYNTHESIS }, playerHP = 79, playerCurrentHP = 1, foeMoves = { FLY },
    foeSpeed = 40 })
  events = b:runTurn(MOVE, MOVE)
  check("heal vs a Fly user: no accuracy check, heals 39, 0 draws", find(events, "restoreHP", "player")
    and b.player.hp == 40 and b.rng.draws == 0, types(events))
end

do
  -- Cloud Nine / Air Lock: 1/2 in any weather.
  for _, kind in ipairs(KINDS) do
    local b = battle({ MISS }, { playerMoves = { MOONLIGHT }, playerHP = 79, playerCurrentHP = 1,
      weather = kind, foeAbility = CLOUD_NINE })
    b:runTurn(MOVE, MOVE)
    check("heal in " .. kind .. " under Cloud Nine: 1/2 (39)", b.player.hp == 40, b.player.hp)
    b = battle({ MISS }, { playerMoves = { MOONLIGHT }, playerHP = 79, playerCurrentHP = 1,
      weather = kind, playerAbility = AIR_LOCK })
    b:runTurn(MOVE, MOVE)
    check("heal in " .. kind .. " under Air Lock: 1/2 (39)", b.player.hp == 40, b.player.hp)
  end
  -- W1 interaction: a faster foe's Sunny Day this turn gives 2/3; the
  -- sandstorm tick then lands at end of turn (79/16 = 4).
  local b = battle({}, { playerMoves = { SYNTHESIS }, playerHP = 79, playerCurrentHP = 1,
    foeMoves = { SUNNY_DAY }, foeSpeed = 40 })
  b:runTurn(MOVE, MOVE)
  check("heal after a same-turn Sunny Day: 2/3 (52)", b.player.hp == 53, b.player.hp)
  b = battle({ MISS }, { playerMoves = { SYNTHESIS }, playerHP = 79, playerCurrentHP = 1, weather = "sandstorm" })
  local events = b:runTurn(MOVE, MOVE)
  local _, hi = find(events, "restoreHP", "player")
  local _, wi = find(events, "weatherDamage", "player")
  check("heal in sandstorm: +19 then the end-of-turn tick of 4", b.player.hp == 1 + 19 - 4 and hi < wi,
    b.player.hp)
end

---------------------------------------------------------------------------
-- AI: no AI_CheckBadMove entry for these effects
---------------------------------------------------------------------------
do
  local user = { types = { 0, 0 }, statStages = {}, hp = 10, maxHP = 10, status = 0, ability = 0 }
  local function score(moveId, weather, targetTypes, targetAbility)
    local target = { types = targetTypes or { 0, 0 }, statStages = {}, hp = 10, maxHP = 10, status = 0,
      ability = targetAbility or 0 }
    return AICheckBadMove.score(user, target, moves[moveId], moveId, Data.typeChart, {}, weather)
  end
  for _, id in ipairs({ MORNING_SUN, SYNTHESIS, MOONLIGHT, THUNDER, WEATHER_BALL, SOLAR_BEAM }) do
    for _, kind in ipairs({ "rain", "sun", "sandstorm", "hail" }) do
      check(("AI %d in %s: no penalty"):format(id, kind), score(id, kind) == 0)
    end
    -- The weather rows' stale-result quirk does not reach these (no handler).
    check(("AI %d clear vs ability 1/2/3: no penalty"):format(id), score(id, nil, nil, 1) == 0
      and score(id, nil, nil, 2) == 0 and score(id, nil, nil, 3) == 0)
  end
  -- The AI sees Weather Ball's static Normal type: -10 vs Ghost even in rain,
  -- and no Water Absorb -12 in rain.
  check("AI Weather Ball rain vs Ghost: -10 (static Normal)", score(WEATHER_BALL, "rain", { 7, 7 }) == -10)
  check("AI Weather Ball rain vs Water Absorb: 0 (static Normal)",
    score(WEATHER_BALL, "rain", nil, ABILITY_WATER_ABSORB) == 0)
  -- Thunder keeps its ordinary type checks: Ground immune -10.
  check("AI Thunder rain vs Ground: -10", score(THUNDER, "rain", { 4, 4 }) == -10)
  -- Through TrainerAI: Synthesis 100 vs Tackle 100 tie, one choice draw.
  local b = battle({ 0 }, { foeMoves = { SYNTHESIS, Data.MOVE_TACKLE }, weather = "sun" })
  local slot = TrainerAI.choose(b, TrainerAI.AI_SCRIPT_CHECK_BAD_MOVE)
  check("TrainerAI: Synthesis selectable, tie broken by one draw", slot == 1 and b.rng.draws == 1, slot)
end

---------------------------------------------------------------------------
-- Controller texts through the real engine
---------------------------------------------------------------------------
do
  local b = battle({ MISS }, { playerMoves = { MOONLIGHT }, playerHP = 79, playerCurrentHP = 1 })
  local c = BattleSceneController.new({ engine = b, playerName = "CLEFAIRY", foeName = "RATTATA",
    moveName = function(id) return id == MOONLIGHT and "MOONLIGHT" or "TACKLE" end })
  local events = b:runTurn(MOVE, MOVE)
  local texts = {}
  for _, e in ipairs(c:_eventMessages(events)) do if e.text then texts[#texts + 1] = e.text end end
  local joined = table.concat(texts, "|")
  check("controller: heal texts", joined == table.concat({ "CLEFAIRY used MOONLIGHT!",
    "CLEFAIRY regained\nhealth!", "RATTATA used TACKLE!", "RATTATA's attack missed!" }, "|"), joined)
  b = battle({ MISS }, { playerMoves = { MOONLIGHT } })
  c = BattleSceneController.new({ engine = b, playerName = "CLEFAIRY", foeName = "RATTATA",
    moveName = function(id) return id == MOONLIGHT and "MOONLIGHT" or "TACKLE" end })
  events = b:runTurn(MOVE, MOVE)
  texts = {}
  for _, e in ipairs(c:_eventMessages(events)) do if e.text then texts[#texts + 1] = e.text end end
  joined = table.concat(texts, "|")
  check("controller: full-HP text", joined:find("CLEFAIRY's\nHP is full!", 1, true) ~= nil, joined)
  -- Solar Beam in sun prints no charge text.
  b = battle({ 0, 1, 0, MISS }, { playerMoves = { SOLAR_BEAM }, weather = "sun" })
  c = BattleSceneController.new({ engine = b, playerName = "ODDISH", foeName = "RATTATA",
    moveName = function(id) return id == SOLAR_BEAM and "SOLARBEAM" or "TACKLE" end })
  events = b:runTurn(MOVE, MOVE)
  texts = {}
  for _, e in ipairs(c:_eventMessages(events)) do if e.text then texts[#texts + 1] = e.text end end
  check("controller: Solar Beam in sun starts with the used text", texts[1] == "ODDISH used SOLARBEAM!"
    and not table.concat(texts, "|"):find("took in sunlight", 1, true), table.concat(texts, "|"))
end

print(("battle_weather_w2_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
