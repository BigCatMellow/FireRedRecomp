-- Run: lua5.1 tests/battle_end_turn_order_test.lua
--
-- Weather slice W0: the end-of-turn order is recomputed at ENDTURN_ORDER
-- (pret/pokefirered c75f352, src/battle_util.c:484-501) with
-- GetWhoStrikesFirst(player, foe, FALSE) (src/battle_main.c:3400-3530):
-- chosen-move priority (a non-move action is MOVE_NONE, priority 0,
-- :3478-3503), speed read now (stage, then paralysis /4, :3428-3452), and
-- one `Random() & 1` on an exact tie at equal priority (:3510, :3523). In
-- singles this is a single call, so at most one draw. Skipped with no draw
-- when either battler is at 0 HP (weather review F1). See
-- work/tasks/phase4-weather-w0.md.
package.path = package.path .. ";./?.lua"

local BattleEngine = require("src.core.BattleEngine")
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

local MOVE_THUNDER_WAVE = 86
local moves = {}
for id, m in pairs(Data.moves) do moves[id] = m end
-- src/data/battle_moves.h at the pin.
moves[MOVE_THUNDER_WAVE] = { effect = 67, power = 0, type = Data.TYPE_ELECTRIC, accuracy = 100, pp = 20,
  secondaryEffectChance = 0, target = 0, priority = 0, flags = 0x16 }

local function stats(hp, speed)
  return { hp = hp, attack = 20, defense = 20, speed = speed, spAttack = 20, spDefense = 20 }
end

local function moveList(list)
  local out = {}
  for i, id in ipairs(list) do out[i] = { move = id, pp = 10 } end
  return out
end

-- Both sides poisoned by default, so the order of the two statusDamage
-- events shows the end-of-turn order. HP 400 keeps every hit non-lethal.
local function battle(values, opts)
  opts = opts or {}
  local engine = BattleEngine.new({
    player = BattleEngine.makeBattler({ species = 1, level = 10,
      stats = stats(opts.playerHP or 400, opts.playerSpeed or 20),
      types = { Data.TYPE_NORMAL, Data.TYPE_NORMAL },
      status = opts.playerStatus == nil and S.POISON or opts.playerStatus,
      moves = moveList(opts.playerMoves or { Data.MOVE_TACKLE }) }),
    foe = BattleEngine.makeBattler({ species = 4, level = 10, catchRate = opts.catchRate,
      stats = stats(opts.foeHP or 400, opts.foeSpeed or 20),
      types = { Data.TYPE_NORMAL, Data.TYPE_NORMAL },
      status = opts.foeStatus == nil and S.POISON or opts.foeStatus,
      moves = moveList(opts.foeMoves or { Data.MOVE_TACKLE }) }),
    moves = moves, typeChart = Data.typeChart, rng = scriptedRng(values),
    hasReplacement = opts.hasReplacement,
  })
  if opts.playerCurrentHP then engine.player.hp = opts.playerCurrentHP end
  if opts.foeCurrentHP then engine.foe.hp = opts.foeCurrentHP end
  return engine
end

local function incoming(speed, hp)
  return BattleEngine.makeBattler({ species = 7, level = 10, stats = stats(hp or 400, speed),
    types = { Data.TYPE_NORMAL, Data.TYPE_NORMAL }, status = S.POISON,
    moves = moveList({ Data.MOVE_TACKLE }) })
end

local MOVE = { action = "move", moveSlot = 1 }
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
-- "player" or "foe": whose end-of-turn poison tick came first.
local function firstTick(events)
  local _, pi = find(events, "statusDamage", "player")
  local _, fi = find(events, "statusDamage", "foe")
  if not pi or not fi then return nil end
  return pi < fi and "player" or "foe"
end
local function firstUse(events)
  local _, pi = find(events, "useMove", "player")
  local _, fi = find(events, "useMove", "foe")
  if pi and fi then return pi < fi and "player" or "foe" end
  return pi and "player" or (fi and "foe") or nil
end

local MISS = 99 -- misses a 95-accuracy Tackle with one draw

---------------------------------------------------------------------------
-- Move-vs-move turns
---------------------------------------------------------------------------
do
  -- Plain speed: the faster foe goes first at both turn start and end of
  -- turn; no tie, no end-of-turn draw.
  local b = battle({ MISS, MISS }, { playerSpeed = 10, foeSpeed = 20 })
  local events = b:runTurn(MOVE, MOVE)
  check("faster foe moves first and ticks first", firstUse(events) == "foe" and firstTick(events) == "foe",
    types(events))
  check("no tie: two accuracy draws only", b.rng.draws == 2, b.rng.draws)
end

do
  -- The order is recomputed from speed *now*: the player is faster at turn
  -- start (25 vs 20) and moves first, the foe's String Shot (-1 stage,
  -- 25 * 10 / 15 = 16) makes it slower, so the foe ticks first. The turn's
  -- action order would have put the player first.
  local b = battle({ MISS, 0 }, { playerSpeed = 25, foeSpeed = 20, foeMoves = { Data.MOVE_STRING_SHOT } })
  local events = b:runTurn(MOVE, MOVE)
  check("speed drop mid-turn: player acted first", firstUse(events) == "player", types(events))
  check("speed drop mid-turn: faster foe ticks first at end of turn", b.player.statStages.speed == 5
    and firstTick(events) == "foe", types(events))
  check("speed drop mid-turn: Tackle miss + String Shot accuracy, no end-of-turn draw", b.rng.draws == 2,
    b.rng.draws)
end

do
  -- Paralysis applied mid-turn counts: player 40 vs foe 10 at turn start
  -- (no tie). Foe's Thunder Wave paralyzes the player: 40 / 4 = 10 == 10,
  -- so ENDTURN_ORDER ties and draws exactly one `Random() & 1`.
  local b = battle({ MISS, 0, 1 }, { playerSpeed = 40, foeSpeed = 10, playerStatus = 0,
    foeMoves = { MOVE_THUNDER_WAVE } })
  local events = b:runTurn(MOVE, MOVE)
  check("Thunder Wave paralyzed the player mid-turn", S.isParalyzed(b.player.status)
    and find(events, "statusApplied", "player"), types(events))
  check("mid-turn paralysis creates an end-of-turn tie: one extra draw", b.rng.draws == 3, b.rng.draws)
end

do
  -- Exact tie, both Tackle: turn start draws once, ENDTURN_ORDER draws once
  -- more. Turn-start draw 0 -> player first; end-of-turn draw 1 -> swapped,
  -- so the foe ticks first even though the player acted first.
  local b = battle({ 0, MISS, MISS, 1 })
  local events = b:runTurn(MOVE, MOVE)
  check("tie: player acted first (turn-start draw 0)", firstUse(events) == "player", types(events))
  check("tie: end-of-turn draw 1 puts the foe first", firstTick(events) == "foe", types(events))
  check("tie: exactly two tie draws plus two accuracy draws", b.rng.draws == 4, b.rng.draws)

  b = battle({ 1, MISS, MISS, 0 })
  events = b:runTurn(MOVE, MOVE)
  check("tie: foe acted first (turn-start draw 1)", firstUse(events) == "foe", types(events))
  check("tie: end-of-turn draw 0 keeps battler-id order, player first", firstTick(events) == "player",
    types(events))
  check("tie (reverse): exactly four draws", b.rng.draws == 4, b.rng.draws)
end

do
  -- Priority counts at end of turn (ignoreChosenMoves = FALSE): the slower
  -- player's Quick Attack (priority 1) beats the faster foe's Tackle at
  -- both points, with no tie draw. Quick Attack (accuracy 100) draws
  -- accuracy, crit, damage roll; Tackle misses.
  local b = battle({ 0, 1, 0, MISS }, { playerSpeed = 10, foeSpeed = 20,
    playerMoves = { Data.MOVE_QUICK_ATTACK } })
  local events = b:runTurn(MOVE, MOVE)
  check("priority: slower Quick Attack user acts and ticks first", firstUse(events) == "player"
    and firstTick(events) == "player", types(events))
  check("priority: four hit/miss draws, no end-of-turn draw", b.rng.draws == 4, b.rng.draws)

  -- Equal priority 1 on both sides at equal speed: the tie draw is taken in
  -- the nonzero-priority branch too (:3508-3511).
  b = battle({ 0, 0, 1, 0, 0, 1, 0, 1 }, { playerMoves = { Data.MOVE_QUICK_ATTACK },
    foeMoves = { Data.MOVE_QUICK_ATTACK } })
  events = b:runTurn(MOVE, MOVE)
  check("equal nonzero priority tie: end-of-turn draw 1 puts the foe first", firstTick(events) == "foe",
    types(events))
  check("equal nonzero priority tie: 2 tie draws + 2 x 3 hit draws", b.rng.draws == 8, b.rng.draws)
end

---------------------------------------------------------------------------
-- Hoisted turns: switch, capture, run (player action is MOVE_NONE)
---------------------------------------------------------------------------
do
  -- Switch against a faster foe: foe first at end of turn, no draw. The
  -- old engine always ticked the player first on a hoisted turn.
  local b = battle({ MISS }, { foeSpeed = 30 })
  local events = b:runTurn({ action = "switch", battler = incoming(20) }, MOVE)
  check("switch vs faster foe: foe ticks first", firstTick(events) == "foe", types(events))
  check("switch vs faster foe: only the foe's accuracy draw", b.rng.draws == 1, b.rng.draws)

  -- The switched-in battler's speed is used: incoming 40 > foe 30.
  b = battle({ MISS }, { playerSpeed = 5, foeSpeed = 30 })
  events = b:runTurn({ action = "switch", battler = incoming(40) }, MOVE)
  check("switch: the incoming battler's speed decides (player first)", firstTick(events) == "player",
    types(events))
end

do
  -- Switch vs Quick Attack (the foe's chosen slot 2) at equal speed:
  -- MOVE_NONE priority 0 < 1, so the foe is first and no tie draw happens.
  local b = battle({ 0, 1, 0 }, { foeMoves = { Data.MOVE_TACKLE, Data.MOVE_QUICK_ATTACK } })
  local events = b:runTurn({ action = "switch", battler = incoming(20) }, { action = "move", moveSlot = 2 })
  check("switch vs Quick Attack: foe used Quick Attack", find(events, "useMove", "foe")
    and find(events, "useMove", "foe").move == Data.MOVE_QUICK_ATTACK, types(events))
  check("switch vs priority foe at equal speed: foe ticks first", firstTick(events) == "foe", types(events))
  check("switch vs priority foe: three hit draws, no tie draw", b.rng.draws == 3, b.rng.draws)
end

do
  -- Switch at equal speed vs Tackle: priority 0 both, so one `& 1` draw.
  local b = battle({ MISS, 1 })
  local events = b:runTurn({ action = "switch", battler = incoming(20) }, MOVE)
  check("switch tie: draw 1 puts the foe first", firstTick(events) == "foe", types(events))
  check("switch tie: foe accuracy + one tie draw", b.rng.draws == 2, b.rng.draws)
  b = battle({ MISS, 0 })
  events = b:runTurn({ action = "switch", battler = incoming(20) }, MOVE)
  check("switch tie: draw 0 keeps the player first", firstTick(events) == "player", types(events))
  check("switch tie (draw 0): two draws", b.rng.draws == 2, b.rng.draws)
end

do
  -- Failed capture (catchRate 3, first shake roll 65535 fails): faster foe
  -- ticks first; at equal speed one tie draw.
  local b = battle({ 65535, MISS }, { foeSpeed = 30, catchRate = 3 })
  local events = b:runTurn({ action = "capture" }, MOVE)
  check("failed capture vs faster foe: foe ticks first", find(events, "capture")
    and not find(events, "capture").success and firstTick(events) == "foe", types(events))
  check("failed capture vs faster foe: shake + accuracy draws only", b.rng.draws == 2, b.rng.draws)

  b = battle({ 65535, MISS, 1 }, { catchRate = 3 })
  events = b:runTurn({ action = "capture" }, MOVE)
  check("failed capture tie: draw 1 puts the foe first", firstTick(events) == "foe", types(events))
  check("failed capture tie: one extra draw", b.rng.draws == 3, b.rng.draws)
end

do
  -- Failed run (runner slower, `Random() & 0xFF` 255 fails): faster foe
  -- ticks first, no tie draw.
  local b = battle({ 65535, MISS }, { playerSpeed = 10, foeSpeed = 30 })
  local events = b:runTurn({ action = "run" }, MOVE)
  check("failed run vs faster foe: foe ticks first", find(events, "run")
    and not find(events, "run").success and firstTick(events) == "foe", types(events))
  check("failed run vs faster foe: run + accuracy draws only", b.rng.draws == 2, b.rng.draws)

  -- Run odds use the raw stat (player 10 < foe 40, so a run draw), but turn
  -- order uses paralysis: foe 40 / 4 = 10 ties the player at end of turn.
  -- Draws: run 65535 (fails), foe's paralysis canceller 1 (moves), Tackle
  -- miss, then exactly one end-of-turn tie draw.
  b = battle({ 65535, 1, MISS, 1 }, { playerSpeed = 10, foeSpeed = 40, foeStatus = S.PARALYSIS })
  events = b:runTurn({ action = "run" }, MOVE)
  check("failed run: paralysis tie at end of turn draws once", not find(events, "run").success
    and find(events, "useMove", "foe") and b.rng.draws == 4, b.rng.draws)
end

do
  -- Priority on the capture and run sites too (each passes the foe's chosen
  -- record). Capture vs Quick Attack at equal speed: foe first, no tie draw.
  local b = battle({ 65535, 0, 1, 0 }, { catchRate = 3, foeMoves = { Data.MOVE_QUICK_ATTACK } })
  local events = b:runTurn({ action = "capture" }, MOVE)
  check("failed capture vs Quick Attack: foe ticks first", firstTick(events) == "foe", types(events))
  check("failed capture vs Quick Attack: shake + three hit draws, no tie draw", b.rng.draws == 4, b.rng.draws)

  -- Run vs a Quick Attack foe at -6 speed (raw 30, staged 30 * 10 / 40 =
  -- 7 < player 10): run odds use the raw stat, so the run draws and fails
  -- (65535); turn order uses the staged stat, but priority 1 beats
  -- MOVE_NONE, so the slower foe still ticks first. Draws: run, then the
  -- three Quick Attack draws.
  b = battle({ 65535, 0, 1, 0 }, { playerSpeed = 10, foeSpeed = 30, foeMoves = { Data.MOVE_QUICK_ATTACK } })
  b.foe.statStages.speed = 0
  events = b:runTurn({ action = "run" }, MOVE)
  check("failed run vs slower Quick Attack foe: foe ticks first", not find(events, "run").success
    and firstTick(events) == "foe", types(events))
  check("failed run vs slower Quick Attack foe: four draws, no tie draw", b.rng.draws == 4, b.rng.draws)
end

---------------------------------------------------------------------------
-- 0-HP battler: no recompute, no draw (weather review F1, Known limit R2)
---------------------------------------------------------------------------
do
  -- Tied speeds. Turn-start draw 0 -> player first; Tackle KOs the 1-HP foe
  -- (accuracy 0, crit 1, roll 0); a replacement is pending, so end of turn
  -- still runs. No ENDTURN_ORDER draw: exactly four draws.
  local b = battle({ 0, 0, 1, 0 }, { foeCurrentHP = 1, hasReplacement = function(side) return side == "foe" end })
  local events = b:runTurn(MOVE, MOVE)
  check("0-HP foe: forced switch pending and the player still ticks",
    b.awaitingForcedSwitch == "foe" and find(events, "statusDamage", "player"), types(events))
  check("0-HP foe: no end-of-turn tie draw", b.rng.draws == 4, b.rng.draws)

  -- Hoisted: the foe's Tackle KOs a 1-HP switch-in at equal speed.
  b = battle({ 0, 1, 0 }, { hasReplacement = function(side) return side == "player" end })
  events = b:runTurn({ action = "switch", battler = incoming(20, 1) }, MOVE)
  check("0-HP switch-in: forced switch pending and the foe still ticks",
    b.awaitingForcedSwitch == "player" and find(events, "statusDamage", "foe"), types(events))
  check("0-HP switch-in: three hit draws, no end-of-turn tie draw", b.rng.draws == 3, b.rng.draws)
end

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
