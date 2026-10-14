-- Run: lua5.1 tests/battle_rampage_test.lua
--
-- Locked multi-turn slice M3: Rampage (EFFECT_RAMPAGE 27; Thrash, Petal
-- Dance, Outrage) through the real engine and controller, with exact RNG
-- draw counts. Oracles from pret/pokefirered c75f352 (see the M3 addendum
-- in work/reports/phase4-multiturn-design-proposal.md and the design review
-- work/reviews/2026-10-14-multiturn-m3-design-review.md).
package.path = package.path .. ";./?.lua"

local BattleEngine = require("src.core.BattleEngine")
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
local THRASH, PETAL_DANCE, OUTRAGE = 37, 80, 200
local SPLASH, DIG, HEADBUTT, HYPNOSIS = 150, 91, 29, 95
local moves = {}
for id, m in pairs(Data.moves) do moves[id] = m end
moves[THRASH] = rec(27, 90, Data.TYPE_NORMAL, 100, 20, 100, 0x04, 0x33)
moves[PETAL_DANCE] = rec(27, 70, Data.TYPE_GRASS, 100, 20, 100, 0x04, 0x33)
moves[OUTRAGE] = rec(27, 90, Data.TYPE_DRAGON, 100, 15, 100, 0x04, 0x33)
moves[SPLASH] = rec(85, 0, Data.TYPE_NORMAL, 0, 40, 0, 0x10, 0)
moves[DIG] = rec(155, 60, Data.TYPE_GROUND, 100, 10, 0, 0, 0x33)
moves[HEADBUTT] = rec(31, 70, Data.TYPE_NORMAL, 100, 15, 30, 0, 0x13)
moves[HYPNOSIS] = rec(1, 0, Data.TYPE_PSYCHIC, 60, 20, 0, 0, 0x16)

local function stats(hp, speed)
  return { hp = hp, attack = 20, defense = 20, speed = speed, spAttack = 20, spDefense = 20 }
end

-- The player (faster by default) uses a rampage move in slot 1; the foe's
-- slot 1 is Splash, which draws nothing, so every draw is the player's.
local function battle(values, opts)
  opts = opts or {}
  return BattleEngine.new({
    player = BattleEngine.makeBattler({ species = 1, level = 10,
      stats = stats(opts.playerHP or 200, opts.playerSpeed or 30),
      types = { Data.TYPE_NORMAL, Data.TYPE_NORMAL }, status = opts.playerStatus,
      moves = { { move = opts.playerMove or THRASH, pp = opts.pp or 20 },
        { move = Data.MOVE_TACKLE, pp = 10 } } }),
    foe = BattleEngine.makeBattler({ species = 4, level = 10,
      stats = stats(opts.foeHP or 400, opts.foeSpeed or 10),
      types = opts.foeTypes or { Data.TYPE_NORMAL, Data.TYPE_NORMAL },
      moves = { { move = opts.foeMove or SPLASH, pp = 10 },
        { move = opts.foeMove2 or SPLASH, pp = 10 } } }),
    moves = moves, typeChart = Data.typeChart, rng = scriptedRng(values),
    hasReplacement = opts.hasReplacement,
  })
end

local MOVE = { action = "move", moveSlot = 1 }
local GHOST = { Data.TYPE_GHOST, Data.TYPE_GHOST }
local MISS = 99
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
-- Hit draws: accuracy, crit (1: none), damage multiplier, seteffect %100.
local function hit() return { 0, 1, 0, 0 } end
local function turn(b, values, playerAction, foeAction)
  b.rng = scriptedRng(values)
  return b:runTurn(playerAction or MOVE, foeAction or MOVE)
end

---------------------------------------------------------------------------
-- Draws, lock length, PP
---------------------------------------------------------------------------
do
  -- Roll 0 -> 2 attacking turns.
  local b = battle({ 0, 1, 0, 0, 0 })
  local events = b:runTurn(MOVE, MOVE)
  check("turn 1: acc, crit, damage, seteffect, &1 (5 draws)", b.rng.draws == 5
    and find(events, "damage", "player") and find(events, "useMove", "player").move == THRASH, b.rng.draws)
  check("turn 1 spends PP and locks for 2 turns (1 left after the tick)",
    b.player.moves[1].pp == 19 and b.player.rampageTurns == 1 and b.player.lockedSlot == 1
      and b:isLocked("player"), b.player.rampageTurns)
  check("no fatigue text after turn 1", not find(events, "fatigueConfusion"))
  -- Locked: whatever action is passed, the rampage move is used.
  events = turn(b, { 0, 1, 0, 0, 2 }, { action = "run" })
  check("locked turn: no run, Thrash again, 4 draws + %4 at the end", not find(events, "run")
    and find(events, "useMove", "player").move == THRASH and b.rng.draws == 5, b.rng.draws)
  check("a locked hit spends no PP", b.player.moves[1].pp == 19)
  local f, fi = find(events, "fatigueConfusion", "player")
  local _, ti = find(events, "turnStart")
  check("2-turn lock ends with fatigue confusion (2 + 2%4 = 4 turns)", f and fi > ti
    and b.player.confusionTurns == 4 and b.player.rampageTurns == 0 and b.player.lockedSlot == nil
    and not b:isLocked("player") and not find(events, "confusionApplied"), types(events))
end

do
  -- Roll 1 -> 3 attacking turns (Petal Dance and Outrage share the path).
  for _, id in ipairs({ PETAL_DANCE, OUTRAGE, THRASH }) do
    local b = battle({ 0, 1, 0, 0, 1 }, { playerMove = id })
    b:runTurn(MOVE, MOVE)
    check("move " .. id .. ": roll 1 -> 2 left after turn 1", b.player.rampageTurns == 2, b.player.rampageTurns)
    local events = turn(b, hit())
    check("move " .. id .. ": turn 2 locked, 4 draws, no text", b.rng.draws == 4 and b.player.rampageTurns == 1
      and b:isLocked("player") and not find(events, "fatigueConfusion"), b.rng.draws)
    events = turn(b, { 0, 1, 0, 0, 0 })
    check("move " .. id .. ": turn 3 ends the lock with confusion (2 turns)", b.rng.draws == 5
      and find(events, "fatigueConfusion", "player") and b.player.confusionTurns == 2
      and not b:isLocked("player") and b.player.moves[1].pp == 19, b.rng.draws)
  end
end

do
  -- PP: a missed locked turn spends PP; at 0 PP the lock continues, a hit
  -- and a miss both spend nothing (no "no PP" text).
  local b = battle({ 0, 1, 0, 0, 1 }, { pp = 2 })
  b:runTurn(MOVE, MOVE)
  check("turn 1 spends PP", b.player.moves[1].pp == 1)
  b.foe.statStages.evasion = 12
  local events = turn(b, { MISS })
  check("a locked miss: 1 draw, PP spent, lock kept", find(events, "miss", "player") and b.rng.draws == 1
    and b.player.moves[1].pp == 0 and b.player.rampageTurns == 1 and b:isLocked("player"), types(events))
  events = turn(b, { MISS, 0 })
  check("a locked miss at 0 PP: no noPP, nothing spent, last turn still confuses",
    not find(events, "noPP") and find(events, "miss", "player") and b.player.moves[1].pp == 0
      and find(events, "fatigueConfusion", "player") and b.rng.draws == 2, types(events))

  b = battle({ 0, 1, 0, 0, 0 }, { pp = 1 })
  b:runTurn(MOVE, MOVE)
  events = turn(b, { 0, 1, 0, 0, 0 })
  check("a locked hit at 0 PP is used (0-PP check bypassed)", not find(events, "noPP")
    and find(events, "damage", "player") and b.player.moves[1].pp == 0, types(events))
end

do
  -- Turn 1 miss: PP spent, no lock, accuracy draw only.
  local b = battle({ MISS })
  b.foe.statStages.evasion = 12
  local events = b:runTurn(MOVE, MOVE)
  check("turn 1 miss: 1 draw, PP spent, no lock", find(events, "miss", "player") and b.rng.draws == 1
    and b.player.moves[1].pp == 19 and b.player.rampageTurns == 0 and not b:isLocked("player"), types(events))
end

---------------------------------------------------------------------------
-- Fatigue confusion gates
---------------------------------------------------------------------------
do
  local b = battle({ 0, 1, 0, 0, 0 })
  b.player.ability = BattleEngine.ABILITY_OWN_TEMPO
  b:runTurn(MOVE, MOVE)
  local events = turn(b, hit())
  check("Own Tempo: lock ends silently, no %4 draw", b.rng.draws == 4 and not find(events, "fatigueConfusion")
    and b.player.confusionTurns == 0 and not b:isLocked("player"), b.rng.draws)

  b = battle({ 0, 1, 0, 0, 0 })
  b:runTurn(MOVE, MOVE)
  b.player.confusionTurns = 5
  -- Confusion canceller: decrement, "is confused!", &1 (1: proceeds).
  events = turn(b, { 1, 0, 1, 0, 0 })
  check("already confused: canceller draw + hit, lock ends silently, no %4", b.rng.draws == 5
    and find(events, "confusedTurn", "player") and find(events, "damage", "player")
    and not find(events, "fatigueConfusion") and b.player.confusionTurns == 4
    and not b:isLocked("player"), b.rng.draws)
end

do
  -- Review F1: the tick runs after the rampager's own status damage.
  local b = battle({ 0, 1, 0, 0, 0 }, { playerStatus = S.POISON })
  b:runTurn(MOVE, MOVE)
  local events = turn(b, { 0, 1, 0, 0, 3 })
  local _, pi = find(events, "statusDamage", "player")
  local f, fi = find(events, "fatigueConfusion", "player")
  check("poisoned rampager: poison damage, then fatigue confusion (%4 = 3 -> 5 turns)",
    pi and f and pi < fi and b.rng.draws == 5 and b.player.confusionTurns == 5, types(events))
  -- Poison KO on the last turn: no fatigue text and no %4 draw.
  b = battle({ 0, 1, 0, 0, 0 }, { playerStatus = S.POISON, hasReplacement = function() return true end })
  b:runTurn(MOVE, MOVE)
  b.player.hp = 1
  events = turn(b, { 0, 1, 0, 0, 3 })
  check("poison KO on the last turn: faint, no fatigue, no %4", find(events, "faint", "player")
    and not find(events, "fatigueConfusion") and b.rng.draws == 4, types(events))
end

do
  -- Review F2: a cancelled rampage restarts after a thaw (PP, new roll).
  local b = battle({ 0, 1, 0, 0, 1 })
  b:runTurn(MOVE, MOVE)
  b.player.status = S.FREEZE
  b:cancelMultiTurnMoves(b.player)
  check("freeze cancels the rampage", not b:isLocked("player") and b.player.rampageTurns == 0)
  local events = turn(b, { 0, 0, 1, 0, 0, 0 })
  check("thawed: a fresh rampage (thaw, 5 hit draws, PP spent, roll 0)", find(events, "thawed", "player")
    and b.rng.draws == 6 and b.player.moves[1].pp == 18 and b.player.rampageTurns == 1, types(events))
  -- Snapping out of confusion on the last locked turn still confuses.
  b = battle({ 0, 1, 0, 0, 0 })
  b:runTurn(MOVE, MOVE)
  b.player.confusionTurns = 1
  events = turn(b, { 0, 1, 0, 0, 2 })
  local _, ei = find(events, "confusionEnded", "player")
  local f, fi = find(events, "fatigueConfusion", "player")
  check("snapped out on the last turn: fatigue confusion still applies", ei and f and ei < fi
    and b.player.confusionTurns == 4 and b.rng.draws == 5, types(events))
end

---------------------------------------------------------------------------
-- No effect, immune miss, semi-invulnerable miss
---------------------------------------------------------------------------
do
  -- Turn 1 into a Ghost: no-effect hit still draws seteffect; PP, no lock.
  local b = battle({ 0, 1, 0, 0 }, { foeTypes = GHOST })
  local events = b:runTurn(MOVE, MOVE)
  check("turn 1 no-effect: 4 draws (incl. seteffect), PP spent, no lock", find(events, "noEffect", "player")
    and b.rng.draws == 4 and b.player.moves[1].pp == 19 and b.player.rampageTurns == 0, b.rng.draws)

  -- Locked no-effect hit, on what would be the last turn: cancelled, no
  -- confusion, no %4 draw.
  b = battle({ 0, 1, 0, 0, 0 })
  b:runTurn(MOVE, MOVE)
  b.foe.types = GHOST
  events = turn(b, hit())
  check("locked no-effect hit: 4 draws, cancelled with no confusion", find(events, "noEffect", "player")
    and b.rng.draws == 4 and not find(events, "fatigueConfusion") and b.player.confusionTurns == 0
    and b.player.rampageTurns == 0 and b.player.lockedSlot == nil and not b:isLocked("player"), b.rng.draws)

  -- Locked no-effect hit with turns left: also cancelled.
  b = battle({ 0, 1, 0, 0, 1 })
  b:runTurn(MOVE, MOVE)
  b.foe.types = GHOST
  turn(b, hit())
  check("locked no-effect hit mid-lock: cancelled", not b:isLocked("player") and b.player.rampageTurns == 0)
  b.foe.types = { Data.TYPE_NORMAL, Data.TYPE_NORMAL }
  events = turn(b, { 0, 1, 0, 0, 0 })
  check("the next Thrash starts a new rampage (PP, new roll)", b.player.moves[1].pp == 18
    and b.rng.draws == 5 and b.player.rampageTurns == 1, b.rng.draws)

  -- Missed roll against an immune target: "It doesn't affect", PP, cancel.
  b = battle({ 0, 1, 0, 0, 1 })
  b:runTurn(MOVE, MOVE)
  b.foe.types = GHOST
  b.foe.statStages.evasion = 12
  events = turn(b, { MISS })
  check("locked miss vs an immune target: noEffect, 1 draw, PP, cancelled", find(events, "noEffect", "player")
    and not find(events, "miss") and b.rng.draws == 1 and b.player.moves[1].pp == 18
    and not b:isLocked("player") and not find(events, "fatigueConfusion"), types(events))

  -- F1: a semi-invulnerable Ghost (Dig) makes the locked Thrash miss with
  -- no draw and plain "missed"; the lock continues and the last turn
  -- still confuses.
  b = battle({ 0, 1, 0, 0, 0 }, { foeTypes = GHOST, foeMove2 = DIG })
  b.foe.types = { Data.TYPE_NORMAL, Data.TYPE_NORMAL }
  b:runTurn(MOVE, MOVE)
  b.foe.types = GHOST
  b.foe.speed = 50
  events = turn(b, { 3 }, MOVE, { action = "move", moveSlot = 2 })
  local dig, di = find(events, "chargeTurn", "foe")
  local miss, mi = find(events, "miss", "player")
  check("semi-invulnerable Ghost: plain miss, no accuracy draw, PP spent", dig and miss and di < mi
    and not find(events, "noEffect") and b.player.moves[1].pp == 18, types(events))
  check("semi-invulnerable miss keeps the lock to its natural end (only the %4 draw)",
    find(events, "fatigueConfusion", "player") and b.rng.draws == 1 and b.player.confusionTurns == 5
      and not b:isLocked("player"), b.rng.draws)
end

---------------------------------------------------------------------------
-- Cancellers end the lock with no confusion
---------------------------------------------------------------------------
do
  -- Full paralysis (%4 == 0).
  local b = battle({ 0, 1, 0, 0, 1 })
  b:runTurn(MOVE, MOVE)
  b.player.status = S.PARALYSIS
  b.player.speed = 200
  local events = turn(b, { 0 })
  check("full paralysis cancels: 1 draw, no confusion", find(events, "fullyParalyzed", "player")
    and b.rng.draws == 1 and not b:isLocked("player") and b.player.rampageTurns == 0
    and not find(events, "fatigueConfusion"), types(events))
  check("paralysis: no PP spent", b.player.moves[1].pp == 19)

  -- Flinch from a faster Headbutt (acc, crit, damage, seteffect 0 <= 30).
  b = battle({ 0, 1, 0, 0, 0 }, { foeMove2 = HEADBUTT })
  b:runTurn(MOVE, MOVE)
  b.foe.speed = 50
  events = turn(b, { 0, 1, 0, 0 }, MOVE, { action = "move", moveSlot = 2 })
  check("flinch cancels on the last turn: no confusion, no %4", find(events, "flinched", "player")
    and b.rng.draws == 4 and not b:isLocked("player") and b.player.confusionTurns == 0
    and not find(events, "fatigueConfusion"), types(events))

  -- Confusion self-hit (&1 == 0, then the self-hit damage multiplier).
  b = battle({ 0, 1, 0, 0, 1 })
  b:runTurn(MOVE, MOVE)
  b.player.confusionTurns = 4
  events = turn(b, { 0, 0 })
  check("confusion self-hit cancels: 2 draws, no fatigue", find(events, "confusionSelfHit", "player")
    and b.rng.draws == 2 and not b:isLocked("player") and not find(events, "fatigueConfusion"), types(events))

  -- Sleep from a faster Hypnosis (acc, sleep turns): the lock is cancelled
  -- when sleep is applied; the locked action then sleeps.
  b = battle({ 0, 1, 0, 0, 1 }, { foeMove2 = HYPNOSIS })
  b:runTurn(MOVE, MOVE)
  b.foe.speed = 50
  events = turn(b, { 0, 2 }, MOVE, { action = "move", moveSlot = 2 })
  local slept, si = find(events, "statusApplied", "player")
  local asleep, ai = find(events, "fastAsleep", "player")
  check("sleep applied cancels: fast asleep, 2 draws, no confusion", slept and asleep and si < ai
    and b.rng.draws == 2 and not b:isLocked("player") and b.player.rampageTurns == 0
    and not find(events, "fatigueConfusion") and b.player.moves[1].pp == 19, types(events))

  -- A sleeping rampager is cancelled at end of turn (battle_main.c:2941).
  b = battle({ 0, 1, 0, 0, 1 })
  b:runTurn(MOVE, MOVE)
  b.player.status = S.withSleepTurns(0, 1)
  b.rng = scriptedRng({})
  b:resolveEndTurn({}, { "player", "foe" })
  check("end-of-turn sleep cancel clears the rampage", b.player.rampageTurns == 0 and not b:isLocked("player"))
end

---------------------------------------------------------------------------
-- KO on turn 1; the lock continues into the replacement
---------------------------------------------------------------------------
do
  local b = battle({ 0, 1, 0, 0, 1 }, { foeHP = 5, hasReplacement = function() return true end })
  local events = b:runTurn(MOVE, MOVE)
  check("a turn-1 KO still locks (5 draws)", find(events, "faint", "foe") and b.rng.draws == 5
    and b.player.rampageTurns > 0 and b:isLocked("player"), types(events))
  b:resolveForcedSwitch("foe", BattleEngine.makeBattler({ species = 4, level = 10, stats = stats(400, 10),
    types = { 0, 0 }, moves = { { move = SPLASH, pp = 10 } } }))
  events = turn(b, hit())
  check("the rampage continues into the replacement (no PP, 4 draws)", find(events, "useMove", "player").move == THRASH
    and find(events, "damage", "player") and b.rng.draws == 4 and b.player.moves[1].pp == 19, types(events))
end

do
  -- Faint clears the rampage; switch-in builds a fresh battler.
  local b = battle({ 0, 1, 0, 0, 1 })
  b:runTurn(MOVE, MOVE)
  b.player.hp = 0
  b:checkFaint("player", {})
  check("faint clears the rampage", b.player.rampageTurns == 0 and b.player.lockedSlot == nil)
  local fresh = BattleEngine.makeBattler({ species = 1, level = 10, stats = stats(40, 20),
    types = { 0, 0 }, moves = { { move = THRASH, pp = 10 } } })
  check("a fresh battler is not rampaging", fresh.rampageTurns == 0 and fresh.targetNotAffected == false)
end

---------------------------------------------------------------------------
-- Controller: no menu or AI for a locked side; the text
---------------------------------------------------------------------------
do
  local b = battle({ 0, 1, 0, 0, 0, 0, 1, 0, 0, 0 })
  local aiCalls = 0
  local c = BattleSceneController.new({ engine = b, playerName = "A", foeName = "B",
    moveName = function() return "MOVE" end,
    chooseFoeMove = function() aiCalls = aiCalls + 1; return 1 end })
  c:_runTurn({ action = "move", moveSlot = 1 })
  check("turn 1 ran and the AI was asked once", aiCalls == 1 and b:isLocked("player"))
  while c.state == BattleSceneController.MESSAGES do c:advanceMessage() end
  check("a rampaging player gets no menu: turn 2 ran automatically", b.turn == 2 and aiCalls == 2
    and not b:isLocked("player") and b.player.confusionTurns == 2, b.turn)

  local fb = battle({ 0, 1, 0, 0, 0 }, { foeMove = THRASH, foeSpeed = 50, playerMove = SPLASH })
  local foeCalls = 0
  local fc = BattleSceneController.new({ engine = fb, playerName = "A", foeName = "B",
    moveName = function() return "MOVE" end,
    chooseFoeMove = function() foeCalls = foeCalls + 1; return 1 end })
  fc:_runTurn({ action = "move", moveSlot = 1 })
  check("the foe started rampaging", fb:isLocked("foe") and foeCalls == 1)
  fb.rng = scriptedRng({ 0, 1, 0, 0, 0 })
  fc:_runTurn({ action = "move", moveSlot = 1 })
  check("a rampaging foe runs no AI", foeCalls == 1 and not fb:isLocked("foe")
    and fb.foe.confusionTurns == 2 and fb.rng.draws == 5, foeCalls)

  local m = c:_eventMessages({
    { type = "fatigueConfusion", side = "player" },
    { type = "fatigueConfusion", side = "foe" },
  })
  check("fatigue text (battle_message.c:177)", m[1].text == "A became\nconfused due to fatigue!"
    and m[2].text == "B became\nconfused due to fatigue!", m[1].text)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
