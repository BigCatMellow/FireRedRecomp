-- Run: lua5.1 tests/battle_confusion_flinch_test.lua
--
-- Confusion/flinch slice C1 (status2) through the real engine: cancellers,
-- RNG order, the confusion self-hit, flinch clearing and faint clearing.
-- Oracles from pret/pokefirered c75f352 (see
-- work/reports/phase4-confusion-flinch-design-proposal.md).
package.path = package.path .. ";./?.lua"

local BattleEngine = require("src.core.BattleEngine")
local BattleFormulas = require("src.core.BattleFormulas")
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

local moves = {}
for id, m in pairs(Data.moves) do moves[id] = m end

local function stats(hp, speed)
  return { hp = hp, attack = 20, defense = 20, speed = speed, spAttack = 20, spDefense = 20 }
end

-- Player faster (20 vs 10) unless overridden.
local function battle(values, opts)
  opts = opts or {}
  local engine = BattleEngine.new({
    player = BattleEngine.makeBattler({ species = 1, level = 10,
      stats = stats(opts.playerHP or 40, opts.playerSpeed or 20),
      types = { Data.TYPE_NORMAL, Data.TYPE_NORMAL }, status = opts.playerStatus,
      moves = { { move = opts.playerMove or Data.MOVE_TACKLE, pp = 10 } } }),
    foe = BattleEngine.makeBattler({ species = 4, level = 10,
      stats = stats(opts.foeHP or 40, opts.foeSpeed or 10),
      types = { Data.TYPE_NORMAL, Data.TYPE_NORMAL }, status = opts.foeStatus,
      moves = { { move = opts.foeMove or Data.MOVE_TACKLE, pp = 10 } } }),
    moves = moves, typeChart = Data.typeChart, rng = scriptedRng(values),
    hasReplacement = opts.hasReplacement,
  })
  if opts.playerCurrentHP then engine.player.hp = opts.playerCurrentHP end
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

check("makeBattler starts with no confusion or flinch",
  battle({}).player.confusionTurns == 0 and battle({}).player.flinched == false)

---------------------------------------------------------------------------
-- Flinch canceller
---------------------------------------------------------------------------
do
  local b = battle({ MISS })
  b.player.flinched = true
  -- A flag set before the turn is cleared at turn start (source clears it
  -- between turns), so it never survives into the next turn.
  local events = b:runTurn(MOVE, MOVE)
  check("a flinch flag from a previous turn is cleared at turn start",
    not find(events, "flinched") and find(events, "useMove", "player"), types(events))

  b = battle({ MISS })
  local ev = {}
  b.foe.flinched = true
  b:resolveMove("foe", 1, ev)
  check("flinched battler: flinched text, no use, no PP, no draw", find(ev, "flinched", "foe")
    and not find(ev, "useMove") and b.foe.moves[1].pp == 10 and b.rng.draws == 0, types(ev))
  check("the flinch flag is consumed", b.foe.flinched == false)
end

do
  -- Flinch is checked after freeze: a frozen flinched battler draws the
  -- freeze roll first and stays frozen.
  local b = battle({ 1 }, { playerStatus = S.FREEZE })
  b.player.flinched = true
  local ev = {}
  b:resolveMove("player", 1, ev)
  check("freeze precedes flinch", find(ev, "frozenSolid") and not find(ev, "flinched")
    and b.player.flinched == true, types(ev))
  b = battle({}, { playerStatus = 2 })
  b.player.flinched = true
  ev = {}
  b:resolveMove("player", 1, ev)
  check("sleep precedes flinch", find(ev, "fastAsleep") and b.player.flinched == true, types(ev))
end

do
  local b = battle({ MISS, MISS })
  local events = b:runTurn(MOVE, MOVE)
  b.player.flinched = true
  b:resolveEndTurn(events, { "player", "foe" })
  check("the end-of-turn phase clears flinch", b.player.flinched == false)
end

---------------------------------------------------------------------------
-- Confusion canceller
---------------------------------------------------------------------------
do
  -- 3 turns: decrement to 2, "is confused!", draw 1 (&1 nonzero) -> move
  -- proceeds; then the Tackle's three draws.
  local b = battle({ 1, 0, 1, 0 })
  b.player.confusionTurns = 3
  local ev = {}
  b:resolveMove("player", 1, ev)
  local c, ci = find(ev, "confusedTurn", "player")
  local u, ui = find(ev, "useMove", "player")
  check("confused: decrement first, is confused, &1 nonzero proceeds", c and u and ci < ui
    and b.player.confusionTurns == 2 and b.rng.draws == 4, types(ev))
end

do
  -- Draw 2 (&1 zero) -> self-hit: Pound-like power 40 against its own
  -- defense, then the random multiplier draw (0 -> x100%).
  local b = battle({ 2, 0 })
  b.player.confusionTurns = 3
  local ev = {}
  b:resolveMove("player", 1, ev)
  local hit = find(ev, "confusionSelfHit", "player")
  local expected = BattleFormulas.calculateBaseDamage(b.player, b.player,
    { power = 40, type = 0, effect = 0 }, false, nil)
  check("&1 zero: hurts itself (power 40, own stats), move not used", hit and not find(ev, "useMove")
    and hit.amount == expected and b.player.hp == 40 - expected and b.player.moves[1].pp == 10, types(ev))
  check("self-hit draws: confusion roll + random multiplier", b.rng.draws == 2, b.rng.draws)
  -- 20 atk / 20 def, level 10: floor(20*40*6/20/50) = 4, +2 = 6.
  check("self-hit damage oracle is 6", expected == 6, expected)
end

do
  -- The random multiplier still applies: draw 15 -> (100 - 15)%.
  local b = battle({ 2, 15 })
  b.player.confusionTurns = 2
  local ev = {}
  b:resolveMove("player", 1, ev)
  check("self-hit uses the random damage multiplier", find(ev, "confusionSelfHit").amount
    == BattleFormulas.applyRandomDamageMultiplier(6, scriptedRng({ 15 })), types(ev))
end

do
  -- Burn halves the self-hit; stat stages apply; screens do not.
  local b = battle({ 2, 0 }, { playerStatus = S.BURN })
  b.player.confusionTurns = 2
  b.player.attack = 100
  b.sideStatus.player.reflect = true
  local ev = {}
  b:resolveMove("player", 1, ev)
  -- 100*40*6/20/50 = 24, burn /2 = 12, +2 = 14 (Reflect ignored).
  check("self-hit: burn halves, Reflect ignored", find(ev, "confusionSelfHit").amount == 14,
    find(ev, "confusionSelfHit").amount)
  b = battle({ 2, 0 })
  b.player.confusionTurns = 2
  b.player.statStages.attack = 8 -- x2
  ev = {}
  b:resolveMove("player", 1, ev)
  -- 40*40*6/20/50 = 9, +2 = 11.
  check("self-hit uses the attack stage", find(ev, "confusionSelfHit").amount == 11,
    find(ev, "confusionSelfHit").amount)
end

do
  -- Explosion quirk: a confused Self-Destruct user's self-hit halves its
  -- defense (CalculateBaseDamage reads gCurrentMove's effect).
  moves[120] = { effect = 7, power = 200, type = Data.TYPE_NORMAL, accuracy = 100, pp = 5,
    secondaryEffectChance = 0, target = 8, priority = 0, flags = 0x32 }
  local b = battle({ 2, 0 }, { playerMove = 120, playerHP = 100 })
  b.player.confusionTurns = 2
  b.player.attack = 100
  local ev = {}
  b:resolveMove("player", 1, ev)
  -- 100*40*6/10/50 = 48, +2 = 50.
  check("confused Self-Destruct user halves its own defense in the self-hit",
    find(ev, "confusionSelfHit").amount == 50 and b.player.hp > 0, find(ev, "confusionSelfHit").amount)
  moves[120] = nil
end

do
  -- Reaching 0: snapped out, the move proceeds without a confusion draw.
  local b = battle({ 0, 1, 0 })
  b.player.confusionTurns = 1
  local ev = {}
  b:resolveMove("player", 1, ev)
  local e, ei = find(ev, "confusionEnded", "player")
  local u, ui = find(ev, "useMove", "player")
  check("1 turn left: snapped out, then the move (no confusion draw)", e and u and ei < ui
    and not find(ev, "confusedTurn") and b.player.confusionTurns == 0 and b.rng.draws == 3, types(ev))
end

do
  -- Paralysis still runs after a confused battler proceeds: confusion draw 1
  -- then paralysis draw 4 (full paralysis).
  local b = battle({ 1, 4 }, { playerStatus = S.PARALYSIS })
  b.player.confusionTurns = 3
  local ev = {}
  b:resolveMove("player", 1, ev)
  local c, ci = find(ev, "confusedTurn")
  local p, pi = find(ev, "fullyParalyzed")
  check("confusion then paralysis (both draws)", c and p and ci < pi and b.rng.draws == 2, types(ev))
  b = battle({ 0, 1, 0 }, { playerStatus = S.PARALYSIS })
  b.player.confusionTurns = 1
  b.rng = scriptedRng({ 1, 0, 1, 0 })
  ev = {}
  b:resolveMove("player", 1, ev)
  check("snapped out then the paralysis check still runs", find(ev, "confusionEnded")
    and find(ev, "useMove") and b.rng.draws == 4, types(ev))
  -- A self-hit stops before paralysis (no paralysis draw).
  b = battle({ 2, 0 }, { playerStatus = S.PARALYSIS })
  b.player.confusionTurns = 3
  ev = {}
  b:resolveMove("player", 1, ev)
  check("self-hit ends the cancellers (no paralysis draw)", b.rng.draws == 2 and not find(ev, "fullyParalyzed"))
end

do
  -- Flinch precedes confusion: no confusion decrement when flinched.
  local b = battle({})
  b.player.flinched = true
  b.player.confusionTurns = 3
  local ev = {}
  b:resolveMove("player", 1, ev)
  check("flinch precedes confusion", find(ev, "flinched") and b.player.confusionTurns == 3 and b.rng.draws == 0)
end

do
  -- A self-hit KO ends the battle through the attacker faint path; status2
  -- is cleared on faint.
  local b = battle({ 2, 0 }, { playerCurrentHP = 3 })
  b.player.confusionTurns = 3
  local events = b:runTurn(MOVE, MOVE)
  check("self-hit KO faints the confused battler and ends the battle",
    find(events, "faint", "player") and b.outcome == "playerLost" and not find(events, "useMove", "foe"), types(events))
  check("faint clears confusion", b.player.confusionTurns == 0)
  -- With a replacement, the pending switch stops the turn as for recoil.
  b = battle({ 2, 0 }, { playerCurrentHP = 3, hasReplacement = function() return true end })
  b.player.confusionTurns = 3
  events = b:runTurn(MOVE, MOVE)
  check("self-hit KO with a replacement queues a forced switch",
    find(events, "forcedSwitchNeeded", "player") and b.awaitingForcedSwitch == "player", types(events))
end

do
  -- Confusion persists across turns until it runs out.
  local b = battle({ 1, 0, 1, 0, MISS, 1, 0, 1, 0, MISS, 0, 1, 0, MISS })
  b.player.confusionTurns = 3
  b:runTurn(MOVE, MOVE)
  check("turn 1 leaves 2", b.player.confusionTurns == 2)
  b:runTurn(MOVE, MOVE)
  check("turn 2 leaves 1", b.player.confusionTurns == 1)
  local events = b:runTurn(MOVE, MOVE)
  check("turn 3 snaps out", find(events, "confusionEnded", "player") and b.player.confusionTurns == 0, types(events))
end

---------------------------------------------------------------------------
-- Interplay with status1 cancellers (design review F2/F7/F8)
---------------------------------------------------------------------------
moves[173] = { effect = 92, power = 40, type = Data.TYPE_NORMAL, accuracy = 100, pp = 15,
  secondaryEffectChance = 30, target = 0, priority = 0, flags = 0x12 } -- Snore
do
  -- Confusion does not tick while the battler stays asleep or frozen.
  local b = battle({}, { playerStatus = 3 })
  b.player.confusionTurns = 3
  local ev = {}
  b:resolveMove("player", 1, ev)
  check("asleep (non-Snore): confusion does not tick", find(ev, "fastAsleep") and b.player.confusionTurns == 3)
  b = battle({ 1 }, { playerStatus = S.FREEZE })
  b.player.confusionTurns = 3
  ev = {}
  b:resolveMove("player", 1, ev)
  check("frozen: confusion does not tick", find(ev, "frozenSolid") and b.player.confusionTurns == 3)
  -- Waking continues into the confusion check.
  b = battle({ 1, 0, 1, 0 }, { playerStatus = 1 })
  b.player.confusionTurns = 3
  ev = {}
  b:resolveMove("player", 1, ev)
  local w, wi = find(ev, "wokeUp")
  local c, ci = find(ev, "confusedTurn")
  check("waking continues into the confusion check", w and c and wi < ci and find(ev, "useMove"), types(ev))
  -- Thawing continues into the flinch check.
  b = battle({ 0 }, { playerStatus = S.FREEZE })
  b.player.flinched = true
  ev = {}
  b:resolveMove("player", 1, ev)
  check("thawing continues into the flinch check", find(ev, "thawed") and find(ev, "flinched")
    and not find(ev, "useMove"), types(ev))
end

do
  -- Snore's "fast asleep" comes after the flinch/confusion cancellers.
  local b = battle({}, { playerStatus = 3, playerMove = 173 })
  b.player.flinched = true
  local ev = {}
  b:resolveMove("player", 1, ev)
  check("flinched sleeping Snore user: only flinched", find(ev, "flinched") and not find(ev, "fastAsleep"), types(ev))
  b = battle({ 1, 0, 1, 0 }, { playerStatus = 3, playerMove = 173 })
  b.player.confusionTurns = 3
  ev = {}
  b:resolveMove("player", 1, ev)
  local c, ci = find(ev, "confusedTurn")
  local f, fi = find(ev, "fastAsleep")
  local u, ui = find(ev, "useMove")
  check("confused sleeping Snore user: is confused, fast asleep, then Snore", c and f and u and ci < fi and fi < ui,
    types(ev))
  b = battle({ 2, 0 }, { playerStatus = 3, playerMove = 173 })
  b.player.confusionTurns = 3
  ev = {}
  b:resolveMove("player", 1, ev)
  check("Snore user that hurts itself prints no fast asleep", find(ev, "confusionSelfHit")
    and not find(ev, "fastAsleep"), types(ev))
end

do
  -- Self-hit KO with a replacement halts the turn (recoil-KO policy) and
  -- the end-of-turn phase still runs for the other battler.
  local b = battle({ 2, 0 }, { playerCurrentHP = 3, foeStatus = S.POISON,
    hasReplacement = function() return true end })
  b.player.confusionTurns = 3
  local events = b:runTurn(MOVE, MOVE)
  check("self-hit KO with a replacement: foe does not act, end-of-turn still runs",
    not find(events, "useMove", "foe") and find(events, "statusDamage", "foe"), types(events))
end

do
  -- Status-free, confusion-free battles keep their draw count.
  local b = battle({ 0, 1, 0, 0, 1, 0 })
  b:runTurn(MOVE, MOVE)
  check("no confusion: no extra draws", b.rng.draws == 6, b.rng.draws)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
