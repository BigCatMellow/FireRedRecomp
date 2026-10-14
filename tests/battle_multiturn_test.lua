-- Run: lua5.1 tests/battle_multiturn_test.lua
--
-- Locked multi-turn slice M1: recharge (Hyper Beam family) and two-turn
-- charge moves (Razor Wind, Sky Attack, Skull Bash, Solar Beam) through the
-- real engine and controller. Oracles from pret/pokefirered c75f352 (see
-- work/reports/phase4-multiturn-design-proposal.md).
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
local HYPER_BEAM, RAZOR_WIND, SKY_ATTACK, SKULL_BASH, SOLAR_BEAM = 63, 13, 143, 130, 76
local moves = {}
for id, m in pairs(Data.moves) do moves[id] = m end
moves[HYPER_BEAM] = rec(80, 150, Data.TYPE_NORMAL, 90, 5, 0, 0, 0x32)
moves[RAZOR_WIND] = rec(39, 80, Data.TYPE_NORMAL, 100, 10, 0, 0x08, 0x32)
moves[SKY_ATTACK] = rec(75, 140, Data.TYPE_FLYING, 90, 5, 30, 0, 0x32)
moves[SKULL_BASH] = rec(145, 100, Data.TYPE_NORMAL, 100, 15, 0, 0, 0x33)
moves[SOLAR_BEAM] = rec(151, 120, Data.TYPE_GRASS, 100, 10, 0, 0, 0x32)

local function stats(hp, speed)
  return { hp = hp, attack = 20, defense = 20, speed = speed, spAttack = 20, spDefense = 20 }
end

local function battle(values, opts)
  opts = opts or {}
  local engine = BattleEngine.new({
    player = BattleEngine.makeBattler({ species = 1, level = 10,
      stats = stats(opts.playerHP or 40, opts.playerSpeed or 20),
      types = { Data.TYPE_NORMAL, Data.TYPE_NORMAL }, status = opts.playerStatus,
      moves = { { move = opts.playerMove or Data.MOVE_TACKLE, pp = 10 },
        { move = Data.MOVE_TACKLE, pp = 10 } } }),
    foe = BattleEngine.makeBattler({ species = 4, level = 10,
      stats = stats(opts.foeHP or 400, opts.foeSpeed or 10),
      types = opts.foeTypes or { Data.TYPE_NORMAL, Data.TYPE_NORMAL },
      moves = { { move = opts.foeMove or Data.MOVE_TACKLE, pp = 10 } } }),
    moves = moves, typeChart = Data.typeChart, rng = scriptedRng(values),
    hasReplacement = opts.hasReplacement,
  })
  return engine
end

local MOVE = { action = "move", moveSlot = 1 }
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

---------------------------------------------------------------------------
-- Recharge (EFFECT_RECHARGE)
---------------------------------------------------------------------------
do
  -- Turn 1: Hyper Beam hits (acc, crit, random; CERTAIN -> no effect roll),
  -- foe misses.
  local b = battle({ 0, 1, 0, MISS, MISS }, { playerMove = HYPER_BEAM })
  local events = b:runTurn(MOVE, MOVE)
  check("Hyper Beam hit sets recharge without an effect roll", find(events, "damage", "player")
    and b.player.recharging and b.player.rechargeTimer == 2 and b.rng.draws == 4, b.rng.draws)
  check("the recharging player is locked for the next turn", b:isLocked("player"))
  -- Turn 2: whatever action is passed, the player must recharge (no PP,
  -- no draw); only the foe's Tackle draws.
  events = b:runTurn({ action = "run" }, MOVE)
  check("recharge turn: must recharge, no run, no PP", find(events, "mustRecharge", "player")
    and not find(events, "run") and not find(events, "useMove", "player")
    and b.player.moves[1].pp == 9 and b.rng.draws == 5, types(events))
  check("recharge ends after the canceller", not b.player.recharging and not b:isLocked("player"))
end

do
  local b = battle({ 95, MISS }, { playerMove = HYPER_BEAM })
  local events = b:runTurn(MOVE, MOVE)
  check("a missed Hyper Beam spends PP and does not recharge", find(events, "miss", "player")
    and not b.player.recharging and b.player.moves[1].pp == 9, types(events))
  b = battle({ 0, 1, 0, 99, MISS }, { playerMove = HYPER_BEAM, foeTypes = { Data.TYPE_GHOST, Data.TYPE_GHOST } })
  events = b:runTurn(MOVE, MOVE)
  check("Hyper Beam vs Ghost: no effect, roll drawn, no recharge", find(events, "noEffect")
    and not b.player.recharging and b.rng.draws == 5, b.rng.draws)
  b = battle({ 0, 1, 0 }, { playerMove = HYPER_BEAM, foeHP = 5, hasReplacement = function() return true end })
  events = b:runTurn(MOVE, MOVE)
  check("a KO still sets recharge", find(events, "faint", "foe") and b.player.recharging, types(events))
end

do
  -- A sleeping recharger stays asleep; the recharge lapses at the next
  -- turn start (timer 1 -> 0) and does not lock again.
  local b = battle({ 0, 1, 0, MISS }, { playerMove = HYPER_BEAM })
  b:runTurn(MOVE, MOVE)
  b.player.status = 3
  local events = b:runTurn(MOVE, MOVE)
  check("asleep recharger: fast asleep, recharge kept", find(events, "fastAsleep", "player")
    and not find(events, "mustRecharge") and b.player.recharging and b.player.rechargeTimer == 1, types(events))
  check("a timer-1 recharge no longer locks the next turn", not b:isLocked("player"))
  b.player.status = 0
  b.rng = scriptedRng({ MISS, MISS })
  events = b:runTurn({ action = "move", moveSlot = 2 }, MOVE)
  check("the recharge lapses at the turn start", not find(events, "mustRecharge")
    and find(events, "useMove", "player") and not b.player.recharging, types(events))
end

do
  -- The recharge canceller stops the chain: no confusion decrement or
  -- draw on the recharge turn; waking that turn prints, then must recharge.
  local b = battle({ 0, 1, 0, MISS, MISS }, { playerMove = HYPER_BEAM })
  b:runTurn(MOVE, MOVE)
  b.player.confusionTurns = 3
  local before = b.rng.draws
  local events = b:runTurn(MOVE, MOVE)
  check("recharge turn: no confusion tick or draw", find(events, "mustRecharge")
    and not find(events, "confusedTurn") and b.player.confusionTurns == 3 and b.rng.draws == before + 1, types(events))
  b = battle({ 0, 1, 0, MISS, MISS }, { playerMove = HYPER_BEAM })
  b:runTurn(MOVE, MOVE)
  b.player.status = 1
  events = b:runTurn(MOVE, MOVE)
  local w, wi = find(events, "wokeUp", "player")
  local r, ri = find(events, "mustRecharge", "player")
  check("waking on the recharge turn: woke up, then must recharge", w and r and wi < ri, types(events))
  -- A locked foe uses its locked move after a player switch (and turn
  -- order follows the locked move).
  local fb = battle({ 0, 1, 0, MISS }, { foeMove = HYPER_BEAM, foeSpeed = 30 })
  fb:runTurn(MOVE, MOVE)
  local incoming = BattleEngine.makeBattler({ species = 1, level = 10, stats = stats(40, 20),
    types = { 0, 0 }, moves = { { move = Data.MOVE_TACKLE, pp = 10 } } })
  events = fb:runTurn({ action = "switch", battler = incoming }, { action = "move", moveSlot = 1 })
  check("recharging foe after a player switch: must recharge", find(events, "switch")
    and find(events, "mustRecharge", "foe"), types(events))
end

do
  -- A charge lock survives the opponent's faint and hits the replacement.
  local b = battle({ MISS }, { playerMove = RAZOR_WIND, hasReplacement = function() return true end })
  b:runTurn(MOVE, MOVE)
  b.foe.hp = 0
  b:checkFaint("foe", {})
  b:resolveForcedSwitch("foe", BattleEngine.makeBattler({ species = 4, level = 10, stats = stats(400, 10),
    types = { 0, 0 }, moves = { { move = Data.MOVE_TACKLE, pp = 10 } } }))
  b.rng = scriptedRng({ 0, 1, 0, MISS })
  local events = b:runTurn(MOVE, MOVE)
  check("the charge lock hits the replacement", find(events, "useMove", "player").move == RAZOR_WIND
    and find(events, "damage", "player"), types(events))
end

do
  -- Turn 1 stopped by a canceller: no PP, no lock.
  local b = battle({ 4, MISS }, { playerMove = RAZOR_WIND, playerStatus = S.PARALYSIS, playerSpeed = 80 })
  local events = b:runTurn(MOVE, MOVE)
  check("turn 1 cancelled: no charge, no PP", find(events, "fullyParalyzed") and not b.player.charging
    and b.player.moves[1].pp == 10, types(events))
end

---------------------------------------------------------------------------
-- Two-turn charge moves
---------------------------------------------------------------------------
do
  local b = battle({ MISS }, { playerMove = RAZOR_WIND })
  local events = b:runTurn(MOVE, MOVE)
  local c = find(events, "chargeTurn", "player")
  check("Razor Wind turn 1: charge text, no used text, PP spent, no draw", c and c.kind == "razorWind"
    and not find(events, "useMove", "player") and b.player.moves[1].pp == 9 and b.rng.draws == 1, types(events))
  check("the charging player is locked", b:isLocked("player") and b.player.charging)
  b.rng = scriptedRng({ 0, 1, 0, MISS })
  events = b:runTurn({ action = "move", moveSlot = 2 }, MOVE)
  check("Razor Wind turn 2: used, hits, no PP (chosen slot ignored)", find(events, "useMove", "player")
    and find(events, "useMove", "player").move == RAZOR_WIND and find(events, "damage", "player")
    and b.player.moves[1].pp == 9 and b.player.moves[2].pp == 10, types(events))
  check("the lock ends after turn 2", not b.player.charging and not b:isLocked("player"))
end

do
  local b = battle({ MISS }, { playerMove = SKULL_BASH })
  local events = b:runTurn(MOVE, MOVE)
  check("Skull Bash turn 1 raises DEF +1", find(events, "chargeTurn").kind == "skullBash"
    and b.player.statStages.defense == 7 and find(events, "statChange", "player"), types(events))
  b = battle({ MISS }, { playerMove = SKULL_BASH })
  b.player.statStages.defense = 12
  events = b:runTurn(MOVE, MOVE)
  check("Skull Bash at DEF +6: silent", not find(events, "statChange") and b.player.charging)
  b = battle({ MISS }, { playerMove = SOLAR_BEAM })
  events = b:runTurn(MOVE, MOVE)
  check("Solar Beam always charges (no weather)", find(events, "chargeTurn").kind == "solarBeam")
end

do
  -- Sky Attack turn 2: crit stage 1 (draw 8 crits) and a 30% flinch.
  local b = battle({ MISS }, { playerMove = SKY_ATTACK })
  b:runTurn(MOVE, MOVE)
  b.rng = scriptedRng({ 0, 8, 0, 30 })
  local events = b:runTurn(MOVE, MOVE)
  check("Sky Attack turn 2 uses crit stage 1", find(events, "critical", "player") ~= nil, types(events))
  check("Sky Attack turn 2 can flinch the slower foe", find(events, "flinched", "foe") ~= nil, types(events))
end

do
  -- Cancellers on turn 2 cancel the lock: full paralysis, flinch,
  -- confusion self-hit; freeze keeps it; a sleeping charger loses it at
  -- end of turn.
  local function charged(status)
    local b = battle({ MISS }, { playerMove = RAZOR_WIND })
    b:runTurn(MOVE, MOVE)
    b.player.status = status or 0
    return b
  end
  local b = charged(S.PARALYSIS)
  b.player.speed = 80 -- stays first after the paralysis /4
  b.rng = scriptedRng({ 4, MISS })
  local events = b:runTurn(MOVE, MOVE)
  check("full paralysis on turn 2 cancels the lock", find(events, "fullyParalyzed")
    and not b.player.charging and not b:isLocked("player"), types(events))
  b = charged()
  b.player.confusionTurns = 3
  b.rng = scriptedRng({ 2, 0, MISS })
  events = b:runTurn(MOVE, MOVE)
  check("a confusion self-hit cancels the lock", find(events, "confusionSelfHit") and not b.player.charging, types(events))
  b = charged(S.FREEZE)
  b.rng = scriptedRng({ 1, MISS })
  events = b:runTurn(MOVE, MOVE)
  check("freeze keeps the lock", find(events, "frozenSolid") and b.player.charging and b:isLocked("player"), types(events))
  b = charged(3)
  b.rng = scriptedRng({ MISS })
  events = b:runTurn(MOVE, MOVE)
  check("a sleeping charger loses the lock at end of turn", find(events, "fastAsleep") and not b.player.charging)
  -- Flinch (set directly as the canceller input).
  b = charged()
  local ev = {}
  b.player.flinched = true
  b:resolveMove("player", 1, ev)
  check("flinch on turn 2 cancels the lock", find(ev, "flinched") and not b.player.charging)
end

do
  -- Turn 2 still fires when every slot is now at 0 PP (no Struggle).
  local b = battle({ MISS }, { playerMove = RAZOR_WIND })
  b:runTurn(MOVE, MOVE)
  b.player.moves[1].pp, b.player.moves[2].pp = 0, 0
  b.rng = scriptedRng({ 0, 1, 0, MISS })
  local events = b:runTurn(MOVE, MOVE)
  check("locked turn 2 is used even with every slot at 0 PP", find(events, "useMove", "player").move == RAZOR_WIND,
    types(events))
end

do
  -- Faint clears the lock.
  local b = battle({ MISS }, { playerMove = RAZOR_WIND })
  b:runTurn(MOVE, MOVE)
  b.player.hp = 0
  b:checkFaint("player", {})
  check("faint clears the charge lock", not b.player.charging and b.player.lockedSlot == nil)
end

---------------------------------------------------------------------------
-- Controller: no menu or AI for a locked side
---------------------------------------------------------------------------
do
  local b = battle({ MISS, 0, 1, 0, MISS }, { playerMove = RAZOR_WIND })
  local aiCalls = 0
  local c = BattleSceneController.new({ engine = b, playerName = "A", foeName = "B",
    moveName = function() return "MOVE" end,
    chooseFoeMove = function() aiCalls = aiCalls + 1; return 1 end })
  c:_runTurn({ action = "move", moveSlot = 1 })
  check("turn 1 runs and the AI was asked once", aiCalls == 1 and b.player.charging)
  while c.state == BattleSceneController.MESSAGES do c:advanceMessage() end
  check("a locked player gets no menu: turn 2 ran automatically", b.turn == 2 and not b.player.charging
    and aiCalls == 2, b.turn)

  local fb = battle({ MISS, MISS }, { foeMove = RAZOR_WIND, foeSpeed = 30 })
  local foeCalls = 0
  local fc = BattleSceneController.new({ engine = fb, playerName = "A", foeName = "B",
    moveName = function() return "MOVE" end,
    chooseFoeMove = function() foeCalls = foeCalls + 1; return 1 end })
  fc:_runTurn({ action = "move", moveSlot = 1 })
  check("the foe started charging", fb.foe.charging and foeCalls == 1)
  fb.rng = scriptedRng({ 0, 1, 0, MISS })
  fc:_runTurn({ action = "move", moveSlot = 1 })
  check("a locked foe runs no AI (no extra AI call)", foeCalls == 1 and not fb.foe.charging, foeCalls)

  local m = c:_eventMessages({
    { type = "chargeTurn", side = "player", kind = "razorWind" },
    { type = "chargeTurn", side = "foe", kind = "solarBeam" },
    { type = "chargeTurn", side = "player", kind = "skullBash" },
    { type = "chargeTurn", side = "foe", kind = "skyAttack" },
    { type = "mustRecharge", side = "player" },
  })
  check("charge and recharge texts (battle_message.c:135-138,185)",
    m[1].text == "A whipped\nup a whirlwind!" and m[2].text == "B took\nin sunlight!"
      and m[3].text == "A lowered\nits head!" and m[4].text == "B is glowing!"
      and m[5].text == "A must\nrecharge!", m[1].text)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
