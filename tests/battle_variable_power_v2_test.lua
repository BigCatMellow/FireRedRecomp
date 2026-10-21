-- Run: lua5.1 tests/battle_variable_power_v2_test.lua
--
-- Variable-power slice V2 (work/tasks/phase4-variable-power-v2.md):
-- EFFECT_FURY_CUTTER (119, move 210). Oracles come from pret/pokefirered
-- c75f352304d529f6ba92d4f74b9cf8b5c3810788:
--   * BattleScript_EffectFuryCutter data/battle_scripts_1.s:1627-1639:
--     attackcanceler, attackstring, ppreduce, accuracycheck
--     BattleScript_FuryCutterHit (the hit and the miss share the label),
--     furycuttercalc, critcalc, damagecalc, typecalc, jumpifmovehadnoeffect
--     BattleScript_FuryCutterHit (back to the calc), adjustnormaldamage, hit;
--   * Cmd_furycuttercalc src/battle_script_commands.c:8205-8226: NO_EFFECT ->
--     counter 0 and MoveMissedPause; else `if (counter != 5) counter++`,
--     power = record power doubled counter-1 times;
--   * CancelMultiTurnMoves src/battle_util.c:203-214 (furyCutterCounter = 0
--     at :213) and its callers: flinch :1366, recharge :1354, full
--     paralysis bs1.s:3717, confusion self-hit bs1.s:3742, sleep/freeze
--     applied bsc.c:2173/:2269, the attackcanceler protect step for any
--     protected move bsc.c:896-906, the end-of-turn sleep cancel
--     src/battle_main.c:2941-2942 (needs MULTIPLETURNS) and the rampage
--     targetNotAffected cancel bu.c:958 (review F9);
--   * ClearFuryCutterDestinyBondGrudge bu.c:3041-3046, called by
--     HandleAction_UseItem before its item branch (src/battle_main.c
--     :4150-4157; review F5) and by a failed run (:4309-4311);
--   * the gDisableStructs clears at switch-in (:2382-2384) and faint
--     (:2457-2459). Nothing else writes the counter, so using a different
--     move does NOT reset it.
-- Move records transcribed from src/data/battle_moves.h at the pin:
-- rec(effect, power, type, accuracy, pp, chance, target, priority, flags).
--
-- Damage oracle (src/pokemon.c CalculateBaseDamage, physical Bug): level 10
-- gives 2*10/5+2 = 6; attack 20, defense 20:
--   floor(floor(20 * P * 6 / 20) / 50) + 2 = floor(6P / 50) + 2
--   P = 10 -> 1 + 2 = 3;  20 -> 2 + 2 = 4;  40 -> 4 + 2 = 6;
--   P = 80 -> 9 + 2 = 11; 160 -> 19 + 2 = 21.
-- The player is Psychic, the foe Water: Bug gets no STAB and is neutral
-- against Water (no Bug/Water row in gTypeEffectiveness). A hit draws
-- accuracy, crit and random (scripted 0, 1, 0: hit, no crit, 100%).
-- Expected numbers are worked here, never read back from the engine.
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

local FURY_CUTTER, TACKLE, SPLASH, HYPNOSIS, THRASH = 210, 33, 150, 95, 37
local moves = {}
for id, m in pairs(Data.moves) do moves[id] = m end
moves[FURY_CUTTER] = rec(119, 10, 6, 95, 20, 0, 0x00, 0, 0x33) -- battle_moves.h:2733
moves[SPLASH] = rec(85, 0, 0, 0, 40, 0, 0x10, 0, 0x00)         -- :1953
moves[HYPNOSIS] = rec(1, 0, 14, 60, 20, 0, 0x00, 0, 0x16)      -- :1238
moves[THRASH] = rec(27, 90, 0, 100, 20, 100, 0x04, 0, 0x33)    -- :484

local function newBattler(id, opts)
  opts = opts or {}
  local list = {}
  for i, m in ipairs(opts.moves or { FURY_CUTTER }) do list[i] = { move = m, pp = moves[m].pp } end
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
local MISS = { 99 } -- accuracy 95: 99 % 100 + 1 = 100 > 95

-- 1. Defaults and the doubling sequence 10, 20, 40, 80, 160, 160.
do
  local e = battle()
  check("new battler counter 0", e.player.furyCutterCounter == 0 and e.foe.furyCutterCounter == 0)
  local expected = { 3, 4, 6, 11, 21, 21, 21 }
  local counters = { 1, 2, 3, 4, 5, 5, 5 }
  local hp = 1000
  for i = 1, #expected do
    local events, draws = use(e, "player", 1, HIT)
    local dmg = find(events, "damage")
    hp = hp - expected[i]
    check("hit " .. i .. ": damage " .. expected[i], dmg and dmg.amount == expected[i] and e.foe.hp == hp,
      dmg and dmg.amount)
    check("hit " .. i .. ": counter " .. counters[i], e.player.furyCutterCounter == counters[i],
      e.player.furyCutterCounter)
    check("hit " .. i .. ": 3 draws", draws == 3, draws)
  end
  check("7 hits spend 7 PP", e.player.moves[1].pp == 13)
  check("ROM record keeps power 10", moves[FURY_CUTTER].power == 10)
  check("the foe's counter is separate", e.foe.furyCutterCounter == 0)
  -- A crit at counter 1 -> 2 (power 20): 4 * 2 = 8.
  e = battle()
  use(e, "player", 1, HIT)
  local events = use(e, "player", 1, { 0, 0, 0 })
  check("crit at 20 power: 8", find(events, "critical") ~= nil and find(events, "damage").amount == 8)
end

-- 2. Misses reset: accuracy, protected, Fly, Dig.
do
  local e = battle()
  for _ = 1, 3 do use(e, "player", 1, HIT) end
  local events, draws = use(e, "player", 1, MISS)
  check("miss: counter 0", e.player.furyCutterCounter == 0)
  check("miss: 1 draw", draws == 1, draws)
  check("miss: events", sig(events) == "useMove:player,miss:player", sig(events))
  check("miss: PP spent", e.player.moves[1].pp == 16)
  events = use(e, "player", 1, HIT)
  check("after a miss: back to 10 (3 damage)", find(events, "damage").amount == 3
    and e.player.furyCutterCounter == 1)

  e = battle()
  for _ = 1, 3 do use(e, "player", 1, HIT) end
  e.foe.protected = true
  events, draws = use(e, "player", 1, HIT)
  check("protected: counter 0", e.player.furyCutterCounter == 0)
  check("protected: 0 draws", draws == 0, draws)
  check("protected: events", sig(events) == "useMove:player,protected:player", sig(events))
  check("protected: PP spent, no damage", e.player.moves[1].pp == 16 and e.foe.hp == 1000 - 3 - 4 - 6)
  e.foe.protected = false

  for _, state in ipairs({ "air", "underground" }) do
    e = battle()
    for _ = 1, 2 do use(e, "player", 1, HIT) end
    e.foe.semiInvulnerable = state
    events, draws = use(e, "player", 1, HIT)
    check(state .. ": counter 0", e.player.furyCutterCounter == 0)
    check(state .. ": 0 draws, missed", draws == 0 and sig(events) == "useMove:player,miss:player", draws)
    check(state .. ": PP spent", e.player.moves[1].pp == 17)
  end
end

-- 3. A no-effect hit (synthetic 0x row Bug -> Water; the real chart has no
-- Bug immunity): jumpifmovehadnoeffect loops back before adjustnormaldamage,
-- so accuracy and crit are drawn, the random multiplier is NOT, and the
-- counter resets.
do
  local chart = {}
  local n = 0
  while Data.typeChart[n] do chart[n] = Data.typeChart[n]; n = n + 1 end
  chart[n] = { attackingType = 6, defendingType = 11, multiplier = 0 }
  local e = battle(nil, { typeChart = chart, foeTypes = { Data.TYPE_FIRE, Data.TYPE_FIRE } })
  use(e, "player", 1, HIT)
  use(e, "player", 1, HIT)
  check("synthetic: two hits against Fire count 2", e.player.furyCutterCounter == 2)
  e.foe.types = { Data.TYPE_WATER, Data.TYPE_WATER }
  local events, draws = use(e, "player", 1, { 0, 1, 0 })
  check("no effect: counter 0", e.player.furyCutterCounter == 0)
  check("no effect: 2 draws (accuracy, crit; no random)", draws == 2, draws)
  check("no effect: events", sig(events) == "useMove:player,noEffect:player", sig(events))
end

-- 4. A different move does NOT reset; any protected move does.
do
  local e = battle(nil, { playerMoves = { FURY_CUTTER, TACKLE } })
  use(e, "player", 1, HIT)
  use(e, "player", 2, HIT) -- Tackle
  check("Tackle keeps the counter at 1", e.player.furyCutterCounter == 1)
  local events = use(e, "player", 1, HIT)
  check("Fury Cutter after Tackle: 20 power (4)", find(events, "damage").amount == 4
    and e.player.furyCutterCounter == 2)
  -- Tackle that misses also keeps it (only furycuttercalc resets on a miss).
  use(e, "player", 2, { 99 })
  check("a missed Tackle keeps the counter", e.player.furyCutterCounter == 2)
  -- A protected Tackle resets it (attackcanceler's CancelMultiTurnMoves).
  e.foe.protected = true
  events = use(e, "player", 2, HIT)
  check("protected Tackle: protected text, counter 0", e.player.furyCutterCounter == 0
    and find(events, "protected") ~= nil)
  e.foe.protected = false
  events = use(e, "player", 1, HIT)
  check("after the protected Tackle: 10 power (3)", find(events, "damage").amount == 3)
end

-- 5. Cancellers (all through cancelMultiTurnMoves).
do
  local function primed()
    local e = battle()
    for _ = 1, 3 do use(e, "player", 1, HIT) end
    return e
  end
  local e = primed()
  e.player.flinched = true
  local events, draws = use(e, "player", 1, HIT)
  check("flinch: counter 0, no draw", e.player.furyCutterCounter == 0 and draws == 0
    and sig(events) == "flinched:player", sig(events))

  e = primed()
  e.player.status = S.PARALYSIS
  events, draws = use(e, "player", 1, { 0 }) -- Random() % 4 == 0: full paralysis
  check("full paralysis: counter 0", e.player.furyCutterCounter == 0
    and sig(events) == "fullyParalyzed:player" and draws == 1, sig(events))
  e = primed()
  e.player.status = S.PARALYSIS
  events = use(e, "player", 1, { 1, 0, 1, 0 }) -- not paralysed this turn
  check("paralysed but acting: counter 4 (80 power, 11)", e.player.furyCutterCounter == 4
    and find(events, "damage").amount == 11)

  e = primed()
  e.player.confusionTurns = 3
  events = use(e, "player", 1, { 0, 0 }) -- & 1 == 0: self-hit, then its random
  check("confusion self-hit: counter 0", e.player.furyCutterCounter == 0
    and find(events, "confusionSelfHit") ~= nil)
  e = primed()
  e.player.confusionTurns = 3
  events = use(e, "player", 1, { 1, 0, 1, 0 })
  check("confused but acting: counter 4", e.player.furyCutterCounter == 4 and find(events, "damage") ~= nil)

  e = primed()
  e.player.recharging, e.player.rechargeTimer = true, 2
  events = use(e, "player", 1, HIT)
  check("recharge canceller: counter 0", e.player.furyCutterCounter == 0
    and sig(events) == "mustRecharge:player", sig(events))

  -- Sleep applied by the foe's Hypnosis (accuracy 60: draw 0 hits; then
  -- the sleep-turn draw).
  e = battle(nil, { foeMoves = { HYPNOSIS } })
  for _ = 1, 3 do use(e, "player", 1, HIT) end
  events = use(e, "foe", 1, { 0, 2 })
  check("sleep applied: counter 0", S.isAsleep(e.player.status) and e.player.furyCutterCounter == 0)
  -- A missed Hypnosis keeps it.
  e = battle(nil, { foeMoves = { HYPNOSIS } })
  for _ = 1, 3 do use(e, "player", 1, HIT) end
  use(e, "foe", 1, { 99 })
  check("missed Hypnosis: counter kept", e.player.furyCutterCounter == 3)

  -- Freeze applied (applySecondaryStatus, the SetMoveEffect freeze case).
  e = primed()
  local ev = {}
  e.rng = scriptedRng({})
  check("freeze applied", e:applySecondaryStatus("player", "freeze", false, ev))
  check("freeze applied: counter 0", e.player.furyCutterCounter == 0)
end

-- 6. Item use and a failed run (ClearFuryCutterDestinyBondGrudge).
do
  local e = battle()
  for _ = 1, 3 do use(e, "player", 1, HIT) end
  e.foe.catchRate = 3
  e.rng = scriptedRng({ 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF })
  local events = e:runTurn({ action = "capture" }, { action = "move", moveSlot = 1 })
  local cap = find(events, "capture")
  check("failed capture: counter 0", cap and cap.success == false and e.player.furyCutterCounter == 0)
  check("failed capture: the foe still acts", find(events, "splash") ~= nil)
  -- The first shake check fails (0xFFFF >= threshold) and stops the loop.
  check("failed capture: 1 draw in the turn", e.rng.draws == 1, e.rng.draws)

  -- Failed run: player speed 30 < foe 200, so TryRunFromBattle draws once
  -- (0xFFFF fails the odds).
  e = battle(nil, { playerSpeed = 30, foeSpeed = 200 })
  e.player.speed = 30
  for _ = 1, 3 do use(e, "player", 1, HIT) end
  e.rng = scriptedRng({ 0xFFFF })
  events = e:runTurn({ action = "run" }, { action = "move", moveSlot = 1 })
  local run = find(events, "run")
  check("failed run: counter 0", run and run.success == false and e.player.furyCutterCounter == 0,
    run and tostring(run.success))
  check("failed run: 1 draw in the turn", e.rng.draws == 1, e.rng.draws)
  -- The foe's own counter is not touched by the player's item or run.
  e = battle(nil, { foeMoves = { FURY_CUTTER } })
  use(e, "foe", 1, HIT); use(e, "foe", 1, HIT)
  e.foe.catchRate = 3
  e.rng = scriptedRng({ 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0, 1, 0 })
  e:runTurn({ action = "capture" }, { action = "move", moveSlot = 1 })
  check("player's capture leaves the foe's counter (2 -> 3)", e.foe.furyCutterCounter == 3)
end

-- 7. Faint, switch-in, and the target's faint.
do
  local e = battle()
  for _ = 1, 3 do use(e, "player", 1, HIT) end
  e:beginFaintSequence()
  e.player.hp = 0
  e:recordFaint("player", {})
  check("faint: counter 0", e.player.furyCutterCounter == 0)

  -- Voluntary switch: the newcomer starts at 0; the foe's counter survives
  -- the player's switch and keeps doubling (2 -> 3: 40 power, 6).
  e = battle(nil, { foeMoves = { FURY_CUTTER } })
  for _ = 1, 3 do use(e, "player", 1, HIT) end
  use(e, "foe", 1, HIT); use(e, "foe", 1, HIT)
  local outgoing = e.player
  -- The newcomer is Water, so the foe's Bug move stays neutral.
  local incoming = newBattler(4)
  e.rng = scriptedRng({ 0, 1, 0 })
  local events = e:runTurn({ action = "switch", battler = incoming }, { action = "move", moveSlot = 1 })
  check("switch-in: the new battler starts at 0", e.player == incoming and e.player.furyCutterCounter == 0)
  check("switch-in: the foe's counter keeps doubling", e.foe.furyCutterCounter == 3
    and find(events, "damage").amount == 6)
  check("switch-in: the outgoing battler's state is not consulted", outgoing ~= e.player)

  -- The counter survives the target fainting and its replacement.
  e = battle(nil, { foeHP = 5, hasReplacement = function() return true end })
  use(e, "player", 1, HIT) -- 3 damage, 5 -> 2
  e.rng = scriptedRng({ 0, 1, 0 })
  e:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 }) -- 4 damage: KO
  check("target fainted, counter 2", e.foe.hp == 0 and e.player.furyCutterCounter == 2
    and e.awaitingForcedSwitch == "foe")
  e:resolveForcedSwitch("foe", newBattler(20, { moves = { SPLASH } }))
  events = use(e, "player", 1, HIT)
  check("replacement: next hit at 40 (6), counter 3", find(events, "damage").amount == 6
    and e.player.furyCutterCounter == 3)
end

-- 8. Review F9: the two remaining cancelMultiTurnMoves callers.
do
  -- End-of-turn sleep cancel (needs MULTIPLETURNS: a live rampage here).
  local e = battle()
  for _ = 1, 3 do use(e, "player", 1, HIT) end
  e.player.status = S.withSleepTurns(0, 2)
  e.player.rampageTurns, e.player.lockedSlot = 2, 1
  e.rng = scriptedRng({})
  e:resolveEndTurn({}, nil, nil)
  check("end-turn sleep cancel (locked): counter 0", e.player.furyCutterCounter == 0
    and e.player.rampageTurns == 0)
  -- Asleep but not locked: source's cancel needs MULTIPLETURNS; kept.
  e = battle()
  for _ = 1, 3 do use(e, "player", 1, HIT) end
  e.player.status = S.withSleepTurns(0, 2)
  e.rng = scriptedRng({})
  e:resolveEndTurn({}, nil, nil)
  check("end-turn sleep (not locked): counter kept", e.player.furyCutterCounter == 3)

  -- Rampage targetNotAffected cancel (bu.c:958) through real turns: Fury
  -- Cutter (counter 1), Thrash turn 1 locks, Thrash turn 2 into a Ghost
  -- (noEffect, targetNotAffected) -> end-of-turn cancel -> counter 0.
  e = battle(nil, { playerMoves = { FURY_CUTTER, THRASH } })
  use(e, "player", 1, HIT)
  -- Thrash turn 1 (rampage slice): accuracy, crit, random, the
  -- seteffectwithchance % 100 and the THRASH `& 1` turn draw = 5; the foe's
  -- Splash and the end-of-turn order (speed 30 vs 20) draw nothing.
  e.rng = scriptedRng({ 0, 1, 0, 0, 0 })
  e:runTurn({ action = "move", moveSlot = 2 }, { action = "move", moveSlot = 1 })
  check("Thrash turn 1: 5 draws, locked, counter kept 1", e.rng.draws == 5
    and (e.player.rampageTurns or 0) > 0 and e.player.furyCutterCounter == 1, e.rng.draws)
  -- Locked turn into a Ghost (the locked slot replaces the chosen one):
  -- accuracy, crit, random and the discarded % 100 = 4; the cancel leaves
  -- no fatigue % 4 draw.
  e.foe.types = { Data.TYPE_GHOST, Data.TYPE_GHOST }
  e.rng = scriptedRng({ 0, 1, 0, 0 })
  local events = e:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 })
  check("Thrash into a Ghost: noEffect, 4 draws", find(events, "noEffect") ~= nil and e.rng.draws == 4,
    e.rng.draws)
  check("rampage targetNotAffected cancel: counter 0", e.player.furyCutterCounter == 0
    and e.player.rampageTurns == 0)
end

-- 9. The foe's Fury Cutter, and a controller text.
do
  local e = battle(nil, { foeMoves = { FURY_CUTTER } })
  local events = use(e, "foe", 1, HIT)
  use(e, "foe", 1, HIT)
  check("foe counts its own hits", e.foe.furyCutterCounter == 2 and e.player.furyCutterCounter == 0)
  local c = BattleSceneController.new({ engine = e, playerName = "PLAYER", foeName = "FOE",
    introMessages = {}, moveName = function() return "FURY CUTTER" end })
  local out = {}
  for _, entry in ipairs(c:_eventMessages(events)) do
    out[#out + 1] = entry.text or ("[hp " .. entry.hpSide .. " " .. entry.hp .. "]")
  end
  -- Bug against the Psychic player is x2 (gTypeEffectiveness BUG vs
  -- PSYCHIC): 3 * 20 / 10 = 6, so 1000 -> 994.
  check("text: an ordinary hit", table.concat(out, "|")
    == "FOE used FURY CUTTER!|[hp player 994]|It's super effective!",
    table.concat(out, "|"))
end

check("Fury Cutter admitted", BattleEngine.supportsMove(battle(), moves[FURY_CUTTER], FURY_CUTTER))

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
