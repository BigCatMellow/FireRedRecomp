-- Run: lua5.1 tests/battle_variable_power_v3_test.lua
--
-- Variable-power slice V3 (work/tasks/phase4-variable-power-v3.md):
-- EFFECT_ROLLOUT (117, moves 205 Rollout and 301 Ice Ball) and
-- EFFECT_DEFENSE_CURL (156, move 111). Oracles come from pret/pokefirered
-- c75f352304d529f6ba92d4f74b9cf8b5c3810788:
--   * BattleScript_EffectRollout data/battle_scripts_1.s:1592-1602:
--     attackcanceler, attackstring, `jumpifstatus2 BS_ATTACKER,
--     STATUS2_MULTIPLETURNS, BattleScript_RolloutCheckAccuracy` (skips
--     ppreduce), ppreduce, accuracycheck BattleScript_RolloutHit (the hit and
--     the miss share the label), typecalc2, rolloutdamagecalculation, then
--     BattleScript_HitFromCritCalc (critcalc, damagecalc, typecalc,
--     adjustnormaldamage);
--   * Cmd_rolloutdamagecalculation src/battle_script_commands.c:8161-8193:
--     NO_EFFECT -> CancelMultiTurnMoves and MoveMissedPause; else the first
--     hit (MULTIPLETURNS clear) sets rolloutTimer 5, MULTIPLETURNS and
--     gLockedMoves; `--rolloutTimer`, at 0 MULTIPLETURNS clears; power =
--     record power doubled 4 - timer times; doubled again under
--     STATUS2_DEFENSE_CURL (:8189-8190);
--   * the protect step src/battle_script_commands.c:896-906 cancels for any
--     protected move not in IsTwoTurnsMove (:7821-7832), so a protected
--     locked turn reaches ppreduce (guarded at 0 PP, :1147); the 0-PP check
--     is bypassed under MULTIPLETURNS (:838-839);
--   * CancelMultiTurnMoves src/battle_util.c:203-214 (rolloutTimer = 0 at
--     :212) and its callers (flinch :1366, recharge :1354, full paralysis
--     bs1.s:3717, confusion self-hit bs1.s:3742, sleep/freeze applied
--     bsc.c:2173/:2269, the end-of-turn sleep cancel src/battle_main.c
--     :2941-2942);
--   * BattleScript_EffectDefenseCurl data/battle_scripts_1.s:2010-2021 and
--     Cmd_setdefensecurlbit bsc.c:8472-8476 (the bit is set before
--     statbuffchange, so at +6 too); STATUS2_DEFENSE_CURL
--     include/constants/battle.h:130, cleared at faint (bm.c:2441) and
--     switch-in (:2367).
-- Move records transcribed from src/data/battle_moves.h at the pin:
-- rec(effect, power, type, accuracy, pp, chance, target, priority, flags).
--
-- Damage oracle (src/pokemon.c CalculateBaseDamage): level 10 gives
-- 2*10/5+2 = 6; attack 20, defense 20 (Ice Ball is special: spAttack 20,
-- spDefense 20, same numbers):
--   floor(floor(20 * P * 6 / 20) / 50) + 2 = floor(6P / 50) + 2
--   P = 30 -> 3 + 2 = 5;    60 -> 7 + 2 = 9;    120 -> 14 + 2 = 16;
--   P = 240 -> 28 + 2 = 30; 480 -> 57 + 2 = 59; 960 -> 115 + 2 = 117.
-- The player is Psychic, the foe Water (Rollout) or Normal (Ice Ball, as Ice
-- is resisted by Water): no STAB, neutral. A hit draws accuracy, crit and
-- random (scripted 0, 1, 0: hit, no crit, 100%). Expected numbers are
-- worked here, never read back from the engine.
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
    values = values,
    next16 = function(self)
      self.draws = self.draws + 1
      return self.values[self.draws] or 0
    end,
  }
end

local function rec(effect, power, type_, acc, pp, chance, target, priority, flags)
  return { effect = effect, power = power, type = type_, accuracy = acc, pp = pp,
    secondaryEffectChance = chance, target = target, priority = priority, flags = flags }
end

local ROLLOUT, ICE_BALL, DEFENSE_CURL, TACKLE, SPLASH, HYPNOSIS = 205, 301, 111, 33, 150, 95
local FURY_CUTTER = 210
local moves = {}
for id, m in pairs(Data.moves) do moves[id] = m end
moves[ROLLOUT] = rec(117, 30, 5, 90, 20, 0, 0x00, 0, 0x33)     -- battle_moves.h:2668
moves[ICE_BALL] = rec(117, 30, 15, 90, 20, 0, 0x00, 0, 0x33)   -- :3916
moves[DEFENSE_CURL] = rec(156, 0, 0, 0, 40, 0, 0x10, 0, 0x08)  -- :1446
moves[SPLASH] = rec(85, 0, 0, 0, 40, 0, 0x10, 0, 0x00)         -- :1953
moves[HYPNOSIS] = rec(1, 0, 14, 60, 20, 0, 0x00, 0, 0x16)      -- :1238
moves[FURY_CUTTER] = rec(119, 10, 6, 95, 20, 0, 0x00, 0, 0x33) -- :2733

local function newBattler(id, opts)
  opts = opts or {}
  local list = {}
  for i, m in ipairs(opts.moves or { ROLLOUT }) do list[i] = { move = m, pp = moves[m].pp } end
  return BattleEngine.makeBattler({ species = id, level = 10,
    stats = { hp = opts.hp or 1000, attack = 20, defense = 20, speed = opts.speed or 20,
      spAttack = 20, spDefense = 20 },
    types = opts.types or { Data.TYPE_WATER, Data.TYPE_WATER }, moves = list })
end

local function battle(values, opts)
  opts = opts or {}
  local engine = BattleEngine.new({
    player = newBattler(1, { moves = opts.playerMoves, speed = opts.playerSpeed or 30,
      types = { Data.TYPE_PSYCHIC, Data.TYPE_PSYCHIC } }),
    foe = newBattler(19, { moves = opts.foeMoves or { SPLASH }, speed = opts.foeSpeed or 20,
      types = opts.foeTypes, hp = opts.foeHP }),
    moves = moves, typeChart = opts.typeChart or Data.typeChart, rng = scriptedRng(values or {}),
    hasReplacement = opts.hasReplacement,
  })
  engine.player.ability, engine.foe.ability = 0, 0
  return engine
end

local function sig(events)
  local out = {}
  for _, e in ipairs(events) do out[#out + 1] = e.type .. (e.side and (":" .. e.side) or "") end
  return table.concat(out, ",")
end
local function find(events, kind)
  for _, e in ipairs(events) do if e.type == kind then return e end end
end
-- One resolveMove with its own fresh draws.
local function use(engine, side, slot, values)
  engine.rng = scriptedRng(values or { 0, 1, 0 })
  local events = {}
  engine:resolveMove(side or "player", slot or 1, events)
  return events, engine.rng.draws
end
local HIT = { 0, 1, 0 }
local MISS = { 99 } -- accuracy 90: 99 % 100 + 1 = 100 > 90
local POWER_DAMAGE = { 5, 9, 16, 30, 59 }
local CURL_DAMAGE = { 9, 16, 30, 59, 117 }

-- 1. Defaults and admission.
do
  local e = battle()
  check("new battler: rolloutTimer 0, defenseCurl false", e.player.rolloutTimer == 0
    and e.player.defenseCurl == false and e.foe.rolloutTimer == 0 and e.foe.defenseCurl == false)
  check("Rollout admitted", e:supportsMove(moves[ROLLOUT], ROLLOUT))
  check("Ice Ball admitted", e:supportsMove(moves[ICE_BALL], ICE_BALL))
  check("Defense Curl admitted", e:supportsMove(moves[DEFENSE_CURL], DEFENSE_CURL))
  check("Defense Curl needs MOVE_TARGET_USER",
    not e:supportsMove(rec(156, 0, 0, 0, 40, 0, 0x00, 0, 0x08), DEFENSE_CURL))
  check("a fresh battler is not locked", not e:isLocked("player"))
end

-- 2. The five-hit lock through real turns: 30, 60, 120, 240, 480; the lock
-- overrides the chosen action on turns 2-5; hit 1 spends 1 PP, hits 2-5
-- none; hit 5 releases the lock and the next turn uses the chosen move.
do
  for _, entry in ipairs({ { ROLLOUT, "Rollout", nil }, { ICE_BALL, "Ice Ball",
      { Data.TYPE_NORMAL, Data.TYPE_NORMAL } } }) do
    local id, label = entry[1], entry[2]
    local e = battle(nil, { playerMoves = { id, TACKLE }, foeTypes = entry[3] })
    local hp = 1000
    local timers = { 4, 3, 2, 1, 0 }
    for i = 1, 5 do
      e.rng = scriptedRng({ 0, 1, 0 })
      -- Turns 2-5 ask for Tackle: the lock replaces it.
      local events = e:runTurn({ action = "move", moveSlot = i == 1 and 1 or 2 },
        { action = "move", moveSlot = 1 })
      local use_ = find(events, "useMove")
      local dmg = find(events, "damage")
      hp = hp - POWER_DAMAGE[i]
      check(label .. " hit " .. i .. ": uses " .. id, use_ and use_.move == id, use_ and use_.move)
      check(label .. " hit " .. i .. ": damage " .. POWER_DAMAGE[i], dmg and dmg.amount == POWER_DAMAGE[i]
        and e.foe.hp == hp, dmg and dmg.amount)
      check(label .. " hit " .. i .. ": timer " .. timers[i], e.player.rolloutTimer == timers[i],
        e.player.rolloutTimer)
      check(label .. " hit " .. i .. ": 3 draws in the turn", e.rng.draws == 3, e.rng.draws)
      check(label .. " hit " .. i .. ": PP 19", e.player.moves[1].pp == 19, e.player.moves[1].pp)
      check(label .. " hit " .. i .. ": locked " .. tostring(i < 5), e:isLocked("player") == (i < 5)
        and (e.player.lockedSlot == (i < 5 and 1 or nil)))
    end
    e.rng = scriptedRng({ 0, 1, 0 })
    local events = e:runTurn({ action = "move", moveSlot = 2 }, { action = "move", moveSlot = 1 })
    check(label .. ": after hit 5 the chosen move runs (Tackle)", find(events, "useMove").move == TACKLE)
    e.rng = scriptedRng({ 0, 1, 0 })
    events = e:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 })
    check(label .. ": a new sequence restarts at 30 and spends PP", find(events, "damage").amount == 5
      and e.player.rolloutTimer == 4 and e.player.moves[1].pp == 18)
    check(label .. ": ROM record keeps power 30", moves[id].power == 30)
  end
end

-- 3. Defense Curl: DEF +1, the bit, no draw; then 60 .. 960; +6 keeps the
-- bit and prints "won't go higher!".
do
  local e = battle(nil, { playerMoves = { DEFENSE_CURL, ROLLOUT } })
  local events, draws = use(e, "player", 1, {})
  check("Defense Curl: DEF +1 (stage 6 -> 7), bit set, 0 draws", e.player.statStages.defense == 7
    and e.player.defenseCurl == true and draws == 0, draws)
  check("Defense Curl: events", sig(events) == "useMove:player,statChange:player", sig(events))
  check("Defense Curl: PP spent", e.player.moves[1].pp == 39)
  -- Both family members (review F1); Ice Ball against a Normal foe.
  for _, entry in ipairs({ { ROLLOUT, "Rollout", nil }, { ICE_BALL, "Ice Ball",
      { Data.TYPE_NORMAL, Data.TYPE_NORMAL } } }) do
    local id, label = entry[1], entry[2]
    if id ~= ROLLOUT then
      e = battle(nil, { playerMoves = { DEFENSE_CURL, id }, foeTypes = entry[3] })
      use(e, "player", 1, {})
    end
    local hp = 1000
    for i = 1, 5 do
      events = use(e, "player", 2, HIT)
      hp = hp - CURL_DAMAGE[i]
      check(label .. " curled hit " .. i .. ": damage " .. CURL_DAMAGE[i],
        find(events, "damage").amount == CURL_DAMAGE[i] and e.foe.hp == hp, find(events, "damage").amount)
    end
    check(label .. ": the bit outlasts the sequence", e.player.defenseCurl == true
      and e.player.rolloutTimer == 0)
    check(label .. ": ROM record keeps power 30 after curled hits", moves[id].power == 30)
  end

  e = battle(nil, { playerMoves = { DEFENSE_CURL, ROLLOUT } })
  e.player.statStages.defense = 12 -- +6
  events, draws = use(e, "player", 1, {})
  local sc = find(events, "statChange")
  check("Defense Curl at +6: prevented, bit still set", sc and sc.prevented == true
    and e.player.defenseCurl == true and e.player.statStages.defense == 12 and draws == 0)
  local c = BattleSceneController.new({ engine = e, playerName = "PLAYER", foeName = "FOE",
    introMessages = {}, moveName = function() return "DEFENSE CURL" end })
  local out = {}
  for _, m in ipairs(c:_eventMessages(events)) do out[#out + 1] = m.text end
  check("Defense Curl at +6 text (same as effect 11)", table.concat(out, "|")
    == "PLAYER used DEFENSE CURL!|PLAYER's DEFENSE\nwon't go higher!", table.concat(out, "|"))
  events = use(e, "player", 2, HIT)
  check("curled at +6: first hit at 60 (9)", find(events, "damage").amount == 9)

  -- The foe's bit is its own.
  e = battle(nil, { foeMoves = { DEFENSE_CURL } })
  use(e, "foe", 1, {})
  check("foe's Defense Curl sets only the foe's bit", e.foe.defenseCurl and not e.player.defenseCurl)
  events = use(e, "player", 1, HIT)
  -- Foe DEF 20 at +1 = 30: floor(floor(20 * 30 * 6 / 30) / 50) + 2 = 4 (a
  -- doubled 60 would give floor(240 / 50) + 2 = 6).
  check("player's Rollout is not doubled by the foe's bit", find(events, "damage").amount == 4,
    find(events, "damage").amount)
end

-- 4. Cancel paths on a locked turn (after two hits, timer 3).
local function primed(opts)
  local e = battle(nil, opts)
  use(e, "player", 1, HIT)
  use(e, "player", 1, HIT)
  return e
end
local function unlocked(e)
  return e.player.rolloutTimer == 0 and e.player.lockedSlot == nil and not e:isLocked("player")
end
do
  -- Accuracy miss: 1 draw, "missed", no PP (MULTIPLETURNS still set at
  -- jumpifstatus2), lock cancelled, the next use restarts at 30.
  local e = primed()
  local events, draws = use(e, "player", 1, MISS)
  check("locked miss: cancelled", unlocked(e))
  check("locked miss: 1 draw, missed", draws == 1 and sig(events) == "useMove:player,miss:player", sig(events))
  check("locked miss: no PP spent", e.player.moves[1].pp == 19, e.player.moves[1].pp)
  events = use(e, "player", 1, HIT)
  check("after a locked miss: back to 30 (5), PP spent", find(events, "damage").amount == 5
    and e.player.moves[1].pp == 18 and e.player.rolloutTimer == 4)

  -- First-turn miss: PP spent, no lock.
  e = battle()
  events, draws = use(e, "player", 1, MISS)
  check("first-turn miss: PP spent, no lock", e.player.moves[1].pp == 19 and unlocked(e) and draws == 1)

  -- Protected locked turn (P1 gate): the protect step cancels first, so
  -- ppreduce runs: 1 PP, 0 draws, the protected text.
  e = primed()
  e.foe.protected = true
  events, draws = use(e, "player", 1, HIT)
  check("protected locked: cancelled", unlocked(e))
  check("protected locked: 0 draws, protected text", draws == 0
    and sig(events) == "useMove:player,protected:player", sig(events))
  check("protected locked: one PP spent", e.player.moves[1].pp == 18, e.player.moves[1].pp)
  check("protected locked: no damage", e.foe.hp == 1000 - 5 - 9)
  e.foe.protected = false
  events = use(e, "player", 1, HIT)
  check("after a protected turn: back to 30 (5)", find(events, "damage").amount == 5)

  -- Protected locked turn at 0 PP: the 0-PP check is bypassed (still
  -- locked at attackcanceler), and ppreduce spends nothing at 0 (:1147).
  e = primed()
  e.player.moves[1].pp = 0
  e.foe.protected = true
  events = use(e, "player", 1, HIT)
  check("protected locked at 0 PP: protected, PP stays 0", e.player.moves[1].pp == 0
    and find(events, "protected") ~= nil and unlocked(e), e.player.moves[1].pp)

  -- Protected first turn: PP spent, no lock.
  e = battle()
  e.foe.protected = true
  events, draws = use(e, "player", 1, HIT)
  check("protected first turn: PP spent, no lock, protected", e.player.moves[1].pp == 19
    and unlocked(e) and draws == 0 and find(events, "protected") ~= nil)

  -- Fly/Dig target: AccuracyCalcHelper misses with no draw; the lock is
  -- cancelled (a rampage keeps its lock here) and no PP is spent.
  for _, state in ipairs({ "air", "underground" }) do
    e = primed()
    e.foe.semiInvulnerable = state
    events, draws = use(e, "player", 1, HIT)
    check(state .. ": cancelled", unlocked(e))
    check(state .. ": 0 draws, missed", draws == 0 and sig(events) == "useMove:player,miss:player", draws)
    check(state .. ": no PP spent", e.player.moves[1].pp == 19)
  end

  -- A locked 0-PP slot still hits (MULTIPLETURNS bypasses the 0-PP check).
  e = primed()
  e.player.moves[1].pp = 0
  events = use(e, "player", 1, HIT)
  check("locked at 0 PP: hit 3 at 120 (16), PP stays 0", find(events, "damage")
    and find(events, "damage").amount == 16 and e.player.moves[1].pp == 0 and e.player.rolloutTimer == 2)
end

-- 5. A no-effect hit (synthetic 0x row Rock -> Water; the real chart has no
-- Rock or Ice immunity): typecalc2 precedes rolloutdamagecalculation, so
-- only the accuracy draw is spent; the lock is cancelled.
do
  local chart = {}
  local n = 0
  while Data.typeChart[n] do chart[n] = Data.typeChart[n]; n = n + 1 end
  chart[n] = { attackingType = 5, defendingType = 11, multiplier = 0 }
  local e = battle(nil, { typeChart = chart, foeTypes = { Data.TYPE_FIRE, Data.TYPE_FIRE } })
  use(e, "player", 1, HIT)
  use(e, "player", 1, HIT)
  check("synthetic: two hits against Fire lock (timer 3)", e.player.rolloutTimer == 3)
  e.foe.types = { Data.TYPE_WATER, Data.TYPE_WATER }
  local events, draws = use(e, "player", 1, HIT)
  check("no effect: cancelled", unlocked(e))
  check("no effect: 1 draw (accuracy; no crit, no random)", draws == 1, draws)
  check("no effect: events", sig(events) == "useMove:player,noEffect:player", sig(events))
  check("no effect (locked): no PP spent", e.player.moves[1].pp == 19)
end

-- 6. Cancellers (all through cancelMultiTurnMoves).
do
  local e = primed()
  e.player.flinched = true
  local events, draws = use(e, "player", 1, HIT)
  check("flinch: cancelled, no draw", unlocked(e) and draws == 0 and sig(events) == "flinched:player",
    sig(events))

  e = primed()
  e.player.status = S.PARALYSIS
  events, draws = use(e, "player", 1, { 0 })
  check("full paralysis: cancelled", unlocked(e) and sig(events) == "fullyParalyzed:player"
    and draws == 1, sig(events))
  e = primed()
  e.player.status = S.PARALYSIS
  events = use(e, "player", 1, { 1, 0, 1, 0 })
  check("paralysed but acting: hit 3 at 120 (16)", find(events, "damage").amount == 16
    and e.player.rolloutTimer == 2)

  e = primed()
  e.player.confusionTurns = 3
  events = use(e, "player", 1, { 0, 0 })
  check("confusion self-hit: cancelled", unlocked(e) and find(events, "confusionSelfHit") ~= nil)

  e = primed()
  e.player.recharging, e.player.rechargeTimer = true, 2
  events = use(e, "player", 1, HIT)
  check("recharge canceller: timer 0", e.player.rolloutTimer == 0
    and sig(events) == "mustRecharge:player", sig(events))

  -- Sleep applied by the foe's Hypnosis cancels at once.
  e = primed({ foeMoves = { HYPNOSIS } })
  use(e, "foe", 1, { 0, 2 })
  check("sleep applied: cancelled", S.isAsleep(e.player.status) and unlocked(e))
  -- A missed Hypnosis keeps the lock.
  e = primed({ foeMoves = { HYPNOSIS } })
  use(e, "foe", 1, { 99 })
  check("missed Hypnosis: lock kept", e.player.rolloutTimer == 3 and e:isLocked("player"))

  -- Freeze applied (the SetMoveEffect freeze case) cancels.
  e = primed()
  check("freeze applied", e:applySecondaryStatus("player", "freeze", false, {}))
  check("freeze applied: cancelled", unlocked(e))
  -- An existing freeze keeps the lock (CANCELLER_FROZEN does not cancel).
  e = primed()
  e.player.status = S.FREEZE
  events, draws = use(e, "player", 1, { 1 })
  check("already frozen: frozen solid, lock kept", sig(events) == "frozenSolid:player"
    and e.player.rolloutTimer == 3 and e:isLocked("player") and draws == 1, sig(events))

  -- An existing sleep keeps the lock through the canceller; the end-of-turn
  -- sleep cancel (MULTIPLETURNS) ends it.
  e = primed()
  e.player.status = S.withSleepTurns(0, 3)
  events = use(e, "player", 1, {})
  check("asleep: fast asleep, lock kept until end of turn", sig(events) == "fastAsleep:player"
    and e.player.rolloutTimer == 3)
  e.rng = scriptedRng({})
  e:resolveEndTurn({}, nil, nil)
  check("end-of-turn sleep cancel: cancelled", unlocked(e))

  -- Review F4: the lock is cancelled earlier in the same turn (a faster
  -- foe's freeze), then a thaw: bm.c:3989-3991 uses gLockedMoves only while
  -- MULTIPLETURNS is set, so the kept slot runs with no NO_PPDEDUCT and the
  -- 0-PP check applies (bsc.c:838-839). Draws: thaw % 5 == 0, accuracy,
  -- crit, random.
  e = primed()
  e.lockedThisTurn = { player = true, foe = false }
  e:applySecondaryStatus("player", "freeze", false, {})
  events = use(e, "player", 1, { 0, 0, 1, 0 })
  check("cancelled this turn, thawed: restarts at 30, spends PP",
    sig(events) == "thawed:player,useMove:player,damage:player" and find(events, "damage").amount == 5
    and e.player.moves[1].pp == 18 and e.player.rolloutTimer == 4, sig(events))
  e = primed()
  e.lockedThisTurn = { player = true, foe = false }
  e:applySecondaryStatus("player", "freeze", false, {})
  e.player.moves[1].pp = 0
  events = use(e, "player", 1, { 0 })
  check("cancelled this turn, thawed at 0 PP: no PP", sig(events) == "thawed:player,noPP:player"
    and e.player.moves[1].pp == 0 and unlocked(e), sig(events))

  -- Fury Cutter's counter and the Rollout lock share CancelMultiTurnMoves.
  e = battle(nil, { playerMoves = { FURY_CUTTER, ROLLOUT } })
  use(e, "player", 1, { 0, 1, 0 })
  use(e, "player", 2, HIT)
  e.player.flinched = true
  use(e, "player", 2, HIT)
  check("flinch clears both the Fury Cutter counter and the lock", e.player.furyCutterCounter == 0
    and unlocked(e))
end

-- 7. A protected locked turn through runTurn (P1), and the lock across
-- turns when the target faints.
do
  local e = battle(nil, { playerMoves = { ROLLOUT, TACKLE } })
  e.rng = scriptedRng({ 0, 1, 0 })
  e:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 })
  e.player.protected = false
  e.foe.protected = true -- as if the foe's Protect had landed this turn
  local events = {}
  e.rng = scriptedRng({})
  e:resolveMove("player", e.player.lockedSlot, events)
  check("runTurn-locked then protected: protected, PP 18, unlocked",
    find(events, "protected") ~= nil and e.player.moves[1].pp == 18 and unlocked(e))
  e.rng = scriptedRng({ 0, 1, 0 })
  events = e:runTurn({ action = "move", moveSlot = 2 }, { action = "move", moveSlot = 1 })
  check("the next turn offers the chosen move (Tackle) and protected is per turn",
    find(events, "useMove").move == TACKLE and find(events, "damage") ~= nil)

  -- The lock survives the target's faint and replacement.
  e = battle(nil, { foeHP = 10, hasReplacement = function() return true end })
  use(e, "player", 1, HIT) -- 5 damage, 10 -> 5
  e.rng = scriptedRng({ 0, 1, 0 })
  e:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 }) -- 9: KO
  check("target fainted, lock kept (timer 3)", e.foe.hp == 0 and e.player.rolloutTimer == 3
    and e.awaitingForcedSwitch == "foe" and e:isLocked("player"))
  e:resolveForcedSwitch("foe", newBattler(20, { moves = { SPLASH } }))
  e.rng = scriptedRng({ 0, 1, 0 })
  events = e:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 })
  check("replacement: hit 3 at 120 (16)", find(events, "damage").amount == 16
    and e.player.rolloutTimer == 2)
end

-- 8. Faint and switch-in clear the timer and the bit.
do
  local e = battle(nil, { playerMoves = { DEFENSE_CURL, ROLLOUT } })
  use(e, "player", 1, {})
  use(e, "player", 2, HIT)
  e:beginFaintSequence()
  e.player.hp = 0
  e:recordFaint("player", {})
  check("faint: timer 0, bit cleared, unlocked", e.player.rolloutTimer == 0
    and e.player.defenseCurl == false and e.player.lockedSlot == nil)

  -- The foe curls and rolls; the player's voluntary switch-in starts clear
  -- and the foe keeps its lock and bit (hit 2 curled: 120, 16).
  e = battle(nil, { foeMoves = { DEFENSE_CURL, ROLLOUT }, playerMoves = { DEFENSE_CURL } })
  use(e, "player", 1, {})
  use(e, "foe", 1, {})
  use(e, "foe", 2, HIT)
  local incoming = newBattler(4, { types = { Data.TYPE_PSYCHIC, Data.TYPE_PSYCHIC } })
  e.rng = scriptedRng({ 0, 1, 0 })
  local events = e:runTurn({ action = "switch", battler = incoming }, { action = "move", moveSlot = 1 })
  check("switch-in: fresh battler clear", e.player == incoming and e.player.rolloutTimer == 0
    and e.player.defenseCurl == false)
  check("switch-in: the foe's locked curled hit 2 at 120 (16)", find(events, "damage")
    and find(events, "damage").amount == 16 and e.foe.rolloutTimer == 3, find(events, "damage")
    and find(events, "damage").amount)
end

-- 9. Controller: no menu for a locked player; no AI for a locked foe.
do
  local values = {}
  for i = 1, 5 do values[#values + 1] = 0; values[#values + 1] = 1; values[#values + 1] = 0 end
  local b = battle(values)
  local aiCalls = 0
  local c = BattleSceneController.new({ engine = b, playerName = "A", foeName = "B",
    moveName = function() return "MOVE" end,
    chooseFoeMove = function() aiCalls = aiCalls + 1; return 1 end })
  c:_runTurn({ action = "move", moveSlot = 1 })
  check("turn 1 locked the player", b:isLocked("player") and aiCalls == 1)
  local guard = 0
  while c.state == BattleSceneController.MESSAGES and guard < 200 do
    c:advanceMessage(); guard = guard + 1
  end
  check("a rolling player gets no menu: five turns ran", b.turn == 5 and not b:isLocked("player")
    and aiCalls == 5 and b.rng.draws == 15 and c.state == BattleSceneController.ACTION, b.turn)

  local fb = battle(nil, { foeMoves = { ROLLOUT }, foeSpeed = 50, playerMoves = { SPLASH } })
  local foeCalls = 0
  local fc = BattleSceneController.new({ engine = fb, playerName = "A", foeName = "B",
    moveName = function() return "MOVE" end,
    chooseFoeMove = function() foeCalls = foeCalls + 1; return 1 end })
  fb.rng = scriptedRng({ 0, 1, 0 })
  fc:_runTurn({ action = "move", moveSlot = 1 })
  check("the foe started rolling", fb:isLocked("foe") and foeCalls == 1)
  fb.rng = scriptedRng({ 0, 1, 0 })
  fc:_runTurn({ action = "move", moveSlot = 1 })
  check("a rolling foe runs no AI (3 draws)", foeCalls == 1 and fb.foe.rolloutTimer == 3
    and fb.rng.draws == 3, foeCalls)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
