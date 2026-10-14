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
-- Implementation review round 1
---------------------------------------------------------------------------
do
  -- F1: a charge move whose last PP went on turn 1, then a faster foe
  -- puts the charger to sleep before turn 2: fast asleep (cancellers run
  -- first), no "no PP"; sleep counts down.
  moves[147] = { effect = 1, power = 0, type = Data.TYPE_GRASS, accuracy = 100, pp = 15,
    secondaryEffectChance = 0, target = 0, priority = 0, flags = 0x16 } -- Spore
  local b = battle({ MISS }, { playerMove = RAZOR_WIND })
  b.player.moves[1].pp = 1
  b:runTurn(MOVE, MOVE)
  check("turn 1 spent the last PP", b.player.moves[1].pp == 0 and b.player.charging)
  b.foe.moves[1] = { move = 147, pp = 15 }
  b.foe.speed = 30
  b.rng = scriptedRng({ 0, 3 })
  local events = b:runTurn(MOVE, MOVE)
  check("lock cancelled by sleep before turn 2: fast asleep, not no PP", find(events, "fastAsleep", "player")
    and not find(events, "noPP") and S.sleepTurns(b.player.status) == 4, types(events))
  -- With the lock cancelled and the battler able to act, the spent move
  -- reports no PP after the cancellers (no Struggle).
  local c = battle({ MISS }, { playerMove = RAZOR_WIND })
  c.player.moves[1].pp, c.player.moves[2].pp = 1, 0
  c:runTurn(MOVE, MOVE)
  c.lockedThisTurn = { player = true, foe = false }
  c.player.charging = false
  local ev = {}
  c:resolveMove("player", 1, ev)
  check("a cancelled lock with 0 PP: no PP after the cancellers, not Struggle", find(ev, "noPP")
    and not find(ev, "useMove"), types(ev))
end

do
  -- F3 M03: the recharge canceller precedes flinch.
  local b = battle({})
  b.player.recharging, b.player.rechargeTimer, b.player.lockedSlot = true, 1, 1
  b.player.flinched = true
  local ev = {}
  b:resolveMove("player", 1, ev)
  check("a flinched recharger must recharge (recharge before flinch)", find(ev, "mustRecharge")
    and not find(ev, "flinched"), types(ev))
  -- M24: applying freeze cancels a charge lock.
  local f = battle({ MISS }, { playerMove = RAZOR_WIND })
  f:runTurn(MOVE, MOVE)
  f:applySecondaryStatus("player", "freeze", false, {})
  check("freeze application cancels the charge lock", S.isFrozen(f.player.status) and not f.player.charging)
  -- M17: a locked foe's turn order follows its locked move, not a passed
  -- priority slot (Quick Attack +1 in slot 2).
  local q = battle({ MISS }, { foeMove = RAZOR_WIND })
  q.foe.moves[2] = { move = Data.MOVE_QUICK_ATTACK, pp = 30 }
  q:runTurn(MOVE, MOVE)
  q.rng = scriptedRng({ 0, 1, 0, 0, 1, 0 })
  local events = q:runTurn(MOVE, { action = "move", moveSlot = 2 })
  local pu = select(2, find(events, "useMove", "player"))
  local fu = find(events, "useMove", "foe")
  check("locked foe: its locked move and its speed order are used", fu and fu.move == RAZOR_WIND
    and pu < select(2, find(events, "useMove", "foe")), types(events))
  -- Capture/run branches: a recharging foe must recharge after a failed
  -- capture.
  local cb = battle({ 0, 1, 0, MISS }, { foeMove = HYPER_BEAM, foeSpeed = 30 })
  cb:runTurn(MOVE, MOVE)
  cb.foe.catchRate = 3
  cb.rng = scriptedRng({ 65535 })
  events = cb:runTurn({ action = "capture" }, MOVE)
  check("recharging foe after a failed capture: must recharge", find(events, "capture")
    and find(events, "mustRecharge", "foe"), types(events))
end

do
  -- F2/F6(d): the auto-run also follows a foe-replacement follow-up, and
  -- never fires while a forced switch is pending.
  local b = battle({ MISS, 0, 1, 0, MISS }, { playerMove = RAZOR_WIND })
  local followed = false
  local c = BattleSceneController.new({ engine = b, playerName = "A", foeName = "B",
    moveName = function() return "MOVE" end,
    onMessagesComplete = function()
      if followed then return nil end
      followed = true
      return { { text = "B sent out C!" } }
    end })
  c:_runTurn({ action = "move", moveSlot = 1 })
  while c.state == BattleSceneController.MESSAGES do c:advanceMessage() end
  check("locked player's turn auto-runs after a follow-up message", followed and b.turn == 2 and not b.player.charging,
    b.turn)
  local fb = battle({}, { playerMove = RAZOR_WIND })
  fb.player.charging, fb.player.lockedSlot = true, 1
  fb.awaitingForcedSwitch = "foe"
  local fc = BattleSceneController.new({ engine = fb, playerName = "A", foeName = "B",
    moveName = function() return "MOVE" end })
  check("no auto-run while a forced switch is pending", fc:_enterAction() == false)
end

---------------------------------------------------------------------------
-- Slice M2: semi-invulnerable moves
---------------------------------------------------------------------------
local FLY, DIG, DIVE, BOUNCE, GUST, THUNDER, EARTHQUAKE, SKY_UPPERCUT, SURF, TWISTER, SWIFT =
  19, 91, 291, 340, 16, 87, 89, 327, 57, 239, 129
moves[FLY] = rec(155, 70, Data.TYPE_FLYING, 95, 15, 0, 0, 0x33)
moves[DIG] = rec(155, 60, Data.TYPE_GROUND, 100, 10, 0, 0, 0x33)
moves[DIVE] = rec(155, 60, Data.TYPE_WATER, 100, 10, 0, 0, 0x33)
moves[BOUNCE] = rec(155, 85, Data.TYPE_FLYING, 85, 5, 30, 0, 0x33)
moves[GUST] = rec(149, 40, Data.TYPE_FLYING, 100, 35, 0, 0, 0x32)
moves[THUNDER] = rec(152, 120, Data.TYPE_ELECTRIC, 70, 10, 30, 0, 0x12)
moves[EARTHQUAKE] = rec(147, 100, Data.TYPE_GROUND, 100, 10, 0, 0x20, 0x32)
moves[SKY_UPPERCUT] = rec(207, 85, Data.TYPE_FIGHTING, 90, 15, 0, 0, 0x33)
moves[SURF] = rec(0, 95, Data.TYPE_WATER, 100, 15, 0, 0x08, 0x32)
moves[TWISTER] = rec(146, 40, Data.TYPE_DRAGON, 100, 20, 20, 0x08, 0x32)
moves[SWIFT] = rec(17, 60, Data.TYPE_NORMAL, 0, 20, 0, 0x08, 0x12)

do
  -- Fly: turn 1 text and ON_AIR; the slower foe's Tackle misses with no
  -- accuracy draw; turn 2 hits and the bit clears.
  local b = battle({}, { playerMove = FLY })
  local events = b:runTurn(MOVE, MOVE)
  check("Fly turn 1: flew up high, in the air", find(events, "chargeTurn").kind == "fly"
    and b.player.semiInvulnerable == "air", types(events))
  check("a move with accuracycheck misses the flier with no draw", find(events, "miss", "foe")
    and b.rng.draws == 0 and b.foe.moves[1].pp == 9, b.rng.draws)
  b.rng = scriptedRng({ 0, 1, 0, MISS })
  events = b:runTurn(MOVE, MOVE)
  check("Fly turn 2 hits and lands", find(events, "damage", "player") and b.player.semiInvulnerable == nil
    and b.player.moves[1].pp == 9, types(events))
end

do
  local function airborneFoe(foeMove)
    local b = battle({}, { foeMove = FLY, foeSpeed = 30, playerMove = foeMove })
    return b
  end
  -- Swift (ALWAYS_HIT) still misses a flier (helper before the short-circuit).
  local b = airborneFoe(SWIFT)
  local events = b:runTurn(MOVE, MOVE)
  check("Swift misses a flying foe", find(events, "miss", "player") and b.rng.draws == 0, types(events))
  -- Gust hits a flier with double damage; Sky Uppercut hits without.
  local plain = battle({ 0, 1, 0 }, { playerMove = GUST })
  local pev = {}
  plain:resolveMove("player", 1, pev)
  local base = find(pev, "damage", "player").amount
  b = airborneFoe(GUST)
  b.rng = scriptedRng({ 0, 1, 0 })
  events = b:runTurn(MOVE, MOVE)
  check("Gust doubles against a flier", find(events, "damage", "player")
    and find(events, "damage", "player").amount >= base * 2 - 1, types(events))
  b = airborneFoe(SKY_UPPERCUT)
  b.rng = scriptedRng({ 0, 1, 0 })
  events = b:runTurn(MOVE, MOVE)
  check("Sky Uppercut hits a flier", find(events, "damage", "player") ~= nil, types(events))
  b = airborneFoe(THUNDER)
  b.rng = scriptedRng({ 0, 1, 0, 99 })
  events = b:runTurn(MOVE, MOVE)
  check("Thunder hits a flier (paralysis roll drawn)", find(events, "damage", "player") and b.rng.draws == 4, types(events))
  b = airborneFoe(TWISTER)
  b.rng = scriptedRng({ 0, 1, 0, 99 })
  events = b:runTurn(MOVE, MOVE)
  check("Twister hits a flier", find(events, "damage", "player") ~= nil, types(events))
  b = airborneFoe(EARTHQUAKE)
  events = b:runTurn(MOVE, MOVE)
  check("Earthquake misses a flier", find(events, "miss", "player") ~= nil, types(events))
end

do
  -- Dig: Earthquake doubles; Gust misses. Dive: Surf doubles.
  local b = battle({}, { foeMove = DIG, foeSpeed = 30, playerMove = EARTHQUAKE })
  b.rng = scriptedRng({ 0, 1, 0 })
  local events = b:runTurn(MOVE, MOVE)
  check("Earthquake hits a digger", b.foe.semiInvulnerable == "underground" and find(events, "damage", "player"),
    types(events))
  b = battle({}, { foeMove = DIG, foeSpeed = 30, playerMove = GUST })
  events = b:runTurn(MOVE, MOVE)
  check("Gust misses a digger", find(events, "miss", "player") ~= nil)
  b = battle({}, { foeMove = DIVE, foeSpeed = 30, playerMove = SURF })
  b.rng = scriptedRng({ 0, 1, 0 })
  events = b:runTurn(MOVE, MOVE)
  check("Surf hits a diver", b.foe.semiInvulnerable == "underwater" and find(events, "damage", "player"), types(events))
  b = battle({}, { foeMove = DIVE, foeSpeed = 30 })
  events = b:runTurn(MOVE, MOVE)
  check("Tackle misses a diver", find(events, "miss", "player") ~= nil)
end

do
  -- Bounce turn 2: 30% paralysis.
  local b = battle({}, { playerMove = BOUNCE })
  b:runTurn(MOVE, MOVE)
  b.rng = scriptedRng({ 0, 1, 0, 30, MISS })
  local events = b:runTurn(MOVE, MOVE)
  check("Bounce turn 2 paralyzes on roll 30", find(events, "statusApplied", "foe")
    and S.isParalyzed(b.foe.status), types(events))
end

do
  -- Cancel clears the bit: a fully paralyzed flier lands.
  local b = battle({}, { playerMove = FLY, playerStatus = S.PARALYSIS, playerSpeed = 80 })
  b.rng = scriptedRng({ 1 })
  b:runTurn(MOVE, MOVE)
  check("flier set up", b.player.semiInvulnerable == "air")
  b.rng = scriptedRng({ 0, 0, 1, 0 })
  local events = b:runTurn(MOVE, MOVE)
  check("full paralysis on turn 2 cancels and lands", find(events, "fullyParalyzed")
    and b.player.semiInvulnerable == nil and find(events, "damage", "foe"), types(events))
  -- Status end-of-turn damage still reaches a flier.
  local p = battle({}, { playerMove = FLY, playerStatus = S.POISON })
  events = p:runTurn(MOVE, MOVE)
  check("poison still ticks while flying", find(events, "statusDamage", "player") ~= nil)
  -- Faint clears it.
  p.player.hp = 0
  p:checkFaint("player", {})
  check("faint clears the semi-invulnerable bit", p.player.semiInvulnerable == nil)
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
    { type = "chargeTurn", side = "player", kind = "fly" },
    { type = "chargeTurn", side = "foe", kind = "dig" },
    { type = "chargeTurn", side = "player", kind = "dive" },
    { type = "chargeTurn", side = "foe", kind = "bounce" },
  })
  check("charge and recharge texts (battle_message.c:135-138,185)",
    m[1].text == "A whipped\nup a whirlwind!" and m[2].text == "B took\nin sunlight!"
      and m[3].text == "A lowered\nits head!" and m[4].text == "B is glowing!"
      and m[5].text == "A must\nrecharge!", m[1].text)
  check("semi-invulnerable texts (battle_message.c:139-142)", m[6].text == "A flew\nup high!"
    and m[7].text == "B dug a hole!" and m[8].text == "A hid\nunderwater!" and m[9].text == "B sprang up!", m[6].text)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
