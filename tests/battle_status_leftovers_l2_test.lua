-- Run: lua5.1 tests/battle_status_leftovers_l2_test.lua
--
-- Status-leftovers slice L2 through the real engine: Rest (37), Focus
-- Energy (47) with its battle-only STATUS2_FOCUS_ENERGY volatile and the
-- `2 * FE` term of BattleEngine:critStageFor at every critcalc site, and
-- AI_CBM_FocusEnergy. Oracles from pret/pokefirered c75f352 (see
-- work/reports/phase4-status-leftovers-design-proposal.md). Neither script
-- draws any Random(); every draw counted below belongs to a canceller, the
-- other side's move or a damaging move.
package.path = package.path .. ";./?.lua"

local BattleEngine = require("src.core.BattleEngine")
local BattleSceneController = require("src.core.BattleSceneController")
local AICheckBadMove = require("src.core.AICheckBadMove")
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

-- src/data/battle_moves.h at the pin (:1511-1522 Focus Energy, :2031-2042
-- Rest); FLAG_SNATCH_AFFECTED = 0x08, MOVE_TARGET_USER = 0x10.
local MOVE_FOCUS_ENERGY, MOVE_REST = 116, 156
local MOVE_SLASH, MOVE_EXPLOSION, MOVE_TRIPLE_KICK, MOVE_BLAZE_KICK = 163, 153, 167, 299
local moves = {}
for id, m in pairs(Data.moves) do moves[id] = m end
moves[MOVE_FOCUS_ENERGY] = { effect = 47, power = 0, type = Data.TYPE_NORMAL, accuracy = 0, pp = 30,
  secondaryEffectChance = 0, target = 0x10, priority = 0, flags = 0x08 }
moves[MOVE_REST] = { effect = 37, power = 0, type = Data.TYPE_PSYCHIC, accuracy = 0, pp = 10,
  secondaryEffectChance = 0, target = 0x10, priority = 0, flags = 0x08 }
moves[MOVE_SLASH] = { effect = 43, power = 70, type = Data.TYPE_NORMAL, accuracy = 100, pp = 20,
  secondaryEffectChance = 0, target = 0, priority = 0, flags = 0x33 }
moves[MOVE_EXPLOSION] = { effect = 7, power = 250, type = Data.TYPE_NORMAL, accuracy = 100, pp = 5,
  secondaryEffectChance = 0, target = 0x08, priority = 0, flags = 0x12 }
moves[MOVE_TRIPLE_KICK] = { effect = 104, power = 10, type = Data.TYPE_FIGHTING, accuracy = 90, pp = 10,
  secondaryEffectChance = 0, target = 0, priority = 0, flags = 0x33 }
moves[MOVE_BLAZE_KICK] = { effect = 200, power = 85, type = Data.TYPE_FIRE, accuracy = 90, pp = 10,
  secondaryEffectChance = 10, target = 0, priority = 0, flags = 0x13 }

local function stats(hp, speed)
  return { hp = hp, attack = 20, defense = 20, speed = speed, spAttack = 20, spDefense = 20 }
end

-- Player is faster (20 vs 10). opts.playerMoves is a list of move ids.
local function battle(values, opts)
  opts = opts or {}
  local playerMoves = {}
  for i, id in ipairs(opts.playerMoves or { MOVE_REST }) do playerMoves[i] = { move = id, pp = 10 } end
  local engine = BattleEngine.new({
    player = BattleEngine.makeBattler({ species = 1, level = 10,
      stats = stats(opts.playerMaxHP or 40, 20), hp = opts.playerHP,
      types = opts.playerTypes or { Data.TYPE_NORMAL, Data.TYPE_NORMAL },
      status = opts.playerStatus,
      moves = playerMoves }),
    foe = BattleEngine.makeBattler({ species = 4, level = 10,
      stats = stats(opts.foeHP or 400, 10), hp = opts.foeCurrentHP,
      types = opts.foeTypes or { Data.TYPE_NORMAL, Data.TYPE_NORMAL },
      moves = { { move = opts.foeMove or Data.MOVE_TACKLE, pp = 10 } } }),
    moves = moves, typeChart = Data.typeChart, rng = scriptedRng(values),
    hasReplacement = opts.hasReplacement,
  })
  if opts.playerAbility then engine.player.ability = opts.playerAbility end
  return engine
end

local function use(b, slot)
  local events = {}
  b:resolveMove(BattleEngine.SIDE_PLAYER, slot or 1, events)
  return events
end

local MOVE = { action = "move", moveSlot = 1 }
local MOVE2 = { action = "move", moveSlot = 2 }
local MISS = 99 -- Tackle (95 accuracy): 99 % 100 + 1 > 95
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
-- Admission
---------------------------------------------------------------------------
do
  local b = battle({})
  check("supportsMove admits Rest (156)", b:supportsMove(moves[MOVE_REST], MOVE_REST))
  check("supportsMove admits Focus Energy (116)", b:supportsMove(moves[MOVE_FOCUS_ENERGY], MOVE_FOCUS_ENERGY))
  check("supportsMove: effect 37 only for move 156", not b:supportsMove(moves[MOVE_REST], 999))
  local positive = {}
  for k, v in pairs(moves[MOVE_FOCUS_ENERGY]) do positive[k] = v end
  positive.target = 0
  check("supportsMove: effect 47 needs MOVE_TARGET_USER", not b:supportsMove(positive, MOVE_FOCUS_ENERGY))
  check("makeBattler starts with focusEnergy = false", b.player.focusEnergy == false and b.foe.focusEnergy == false)
end

---------------------------------------------------------------------------
-- Rest (37): BattleScript_EffectRest, bs1.s:735-759
---------------------------------------------------------------------------
do
  -- Success, unstatused: "went to sleep!", sleep 3, full heal, no RNG.
  local b = battle({}, { playerHP = 10 })
  local events = use(b)
  local rs, ri = find(events, "restSlept", "player")
  local rh, hi = find(events, "restoreHP", "player")
  check("Rest: restSlept (not statused) then restoreHP",
    rs and rs.statused == false and rh and ri < hi, types(events))
  check("Rest: restoreHP carries beforeHP 10, amount 30, hpRemaining 40",
    rh and rh.beforeHP == 10 and rh.amount == 30 and rh.hpRemaining == 40)
  check("Rest: status1 is exactly STATUS1_SLEEP_TURN(3)", b.player.status == 3, b.player.status)
  check("Rest: HP restored to max", b.player.hp == b.player.maxHP)
  check("Rest: one PP spent", b.player.moves[1].pp == 9)
  check("Rest: draws nothing", b.rng.draws == 0, b.rng.draws)
  check("Rest: event order useMove, restSlept, restoreHP", types(events) == "useMove,restSlept,restoreHP",
    types(events))
end

do
  -- "slept and became healthy!" for each status bit 3-7. Poison, burn and
  -- toxic draw nothing; paralysis draws its canceller `% 4` (1: acts).
  local cases = {
    { "poison", S.POISON, {}, 0 },
    { "burn", S.BURN, {}, 0 },
    { "paralysis", S.PARALYSIS, { 1 }, 1 },
    { "toxic (counter 5)", S.TOXIC_POISON + 5 * S.TOXIC_COUNTER_UNIT, {}, 0 },
    { "toxic (counter 15)", S.TOXIC_POISON + 15 * S.TOXIC_COUNTER_UNIT, {}, 0 },
  }
  for _, case in ipairs(cases) do
    local b = battle(case[3], { playerHP = 5, playerStatus = case[2] })
    local events = use(b)
    local rs = find(events, "restSlept", "player")
    check("Rest while " .. case[1] .. ": became healthy", rs and rs.statused == true, types(events))
    check("Rest while " .. case[1] .. ": status overwritten to sleep 3 (counter cleared)",
      b.player.status == 3 and S.toxicCounter(b.player.status) == 0, b.player.status)
    check("Rest while " .. case[1] .. ": full HP, draws " .. case[4],
      b.player.hp == b.player.maxHP and b.rng.draws == case[4], b.rng.draws)
  end
end

do
  -- Freeze: the canceller stops a frozen user unless it thaws first, so a
  -- natural Rest never sees the bit. A thaw (`% 5` == 0) clears it first:
  -- "went to sleep!".
  local b = battle({ 0 }, { playerHP = 5, playerStatus = S.FREEZE })
  local events = use(b)
  local rs = find(events, "restSlept", "player")
  check("Rest after a canceller thaw: went to sleep (freeze already gone)",
    find(events, "thawed", "player") and rs and rs.statused == false and b.player.status == 3
      and b.rng.draws == 1, types(events))
  -- The trysetrest bit test itself, with the cancellers bypassed.
  b = battle({}, { playerHP = 5, playerStatus = S.FREEZE })
  b.resolveStatusCancellers = function() return false end
  events = use(b)
  rs = find(events, "restSlept", "player")
  check("Rest (cancellers bypassed) while frozen: became healthy, sleep 3",
    rs and rs.statused == true and b.player.status == 3 and b.rng.draws == 0, types(events))
end

do
  -- `status1 & (u8)~STATUS1_SLEEP` excludes the toxic counter (bits 8-11).
  local b = battle({}, { playerHP = 5, playerStatus = 2 * S.TOXIC_COUNTER_UNIT })
  local events = use(b)
  local rs = find(events, "restSlept", "player")
  check("Rest with a counter-only status1 word: went to sleep, counter cleared",
    rs and rs.statused == false and b.player.status == 3, types(events))
end

do
  -- Fail 1 (defensive): already asleep. CANCELLER_ASLEEP normally stops the
  -- user first, so bypass it to reach jumpifstatus STATUS1_SLEEP.
  local b = battle({}, { playerHP = 5, playerStatus = 2 })
  b.resolveStatusCancellers = function() return false end
  local events = use(b)
  local sa = find(events, "statusAlready", "player")
  check("Rest while asleep (defensive): statusAlready sleep, nothing else",
    sa and sa.kind == "sleep" and types(events) == "useMove,statusAlready", types(events))
  check("Rest while asleep: status, HP unchanged, PP spent, no draws",
    b.player.status == 2 and b.player.hp == 5 and b.player.moves[1].pp == 9 and b.rng.draws == 0)
  -- Without the bypass a sleeping user is fast asleep and spends no PP.
  b = battle({}, { playerHP = 5, playerStatus = 2 })
  events = use(b)
  check("Rest while asleep (real path): fast asleep, no PP spent",
    find(events, "fastAsleep", "player") and not find(events, "useMove")
      and b.player.moves[1].pp == 10 and b.player.status == 1, types(events))
end

do
  -- Fail 2: Insomnia / Vital Spirit on the user, before the HP check.
  for _, case in ipairs({ { "Insomnia", BattleEngine.ABILITY_INSOMNIA },
      { "Vital Spirit", BattleEngine.ABILITY_VITAL_SPIRIT } }) do
    for _, hp in ipairs({ 5, 40 }) do
      local b = battle({}, { playerHP = hp, playerAbility = case[2], playerStatus = S.POISON })
      local events = use(b)
      local sa = find(events, "stayedAwake", "player")
      check(("Rest with %s at %d HP: stayedAwake, nothing else"):format(case[1], hp),
        sa and sa.ability == case[2] and types(events) == "useMove,stayedAwake", types(events))
      check(("Rest with %s at %d HP: status, HP kept, PP spent, no draws"):format(case[1], hp),
        b.player.status == S.POISON and b.player.hp == hp and b.player.moves[1].pp == 9
          and b.rng.draws == 0)
    end
  end
end

do
  -- Fail 3: full HP -> "HP is full!", status kept.
  local b = battle({}, { playerStatus = S.BURN })
  local events = use(b)
  check("Rest at full HP while burned: restoreHPFull only, burn kept",
    types(events) == "useMove,restoreHPFull" and b.player.status == S.BURN
      and b.player.moves[1].pp == 9 and b.rng.draws == 0, types(events))
  b = battle({})
  events = use(b)
  check("Rest at full HP: restoreHPFull, still awake",
    types(events) == "useMove,restoreHPFull" and b.player.status == 0, types(events))
end

do
  -- Confusion (status2) is not cured. Confused canceller: `& 1` = 1 acts.
  local b = battle({ 1 }, { playerHP = 5 })
  b.player.confusionTurns = 3
  local events = use(b)
  check("Rest does not cure confusion",
    find(events, "restSlept") and b.player.confusionTurns == 2 and b.rng.draws == 1, types(events))
end

do
  -- Sleep length through runTurn: turn 1 Rest; turns 2 and 3 fast asleep;
  -- turn 4 the canceller wakes the user and it acts (Tackle in slot 2).
  -- The foe misses every turn: one accuracy draw each.
  local b = battle({ MISS, MISS, MISS, 0, 1, 0, MISS }, { playerHP = 5,
    playerMoves = { MOVE_REST, Data.MOVE_TACKLE } })
  local e1 = b:runTurn(MOVE, MOVE)
  check("Rest turn 1: slept, 1 draw (foe accuracy)", find(e1, "restSlept") and b.player.status == 3
    and b.rng.draws == 1, b.rng.draws)
  local e2 = b:runTurn(MOVE2, MOVE)
  check("Rest turn 2: fast asleep, 2 turns left", find(e2, "fastAsleep", "player")
    and not find(e2, "damage", "player") and b.player.status == 2 and b.rng.draws == 2, types(e2))
  local e3 = b:runTurn(MOVE2, MOVE)
  check("Rest turn 3: fast asleep, 1 turn left", find(e3, "fastAsleep", "player")
    and b.player.status == 1 and b.rng.draws == 3, types(e3))
  local e4 = b:runTurn(MOVE2, MOVE)
  local _, wi = find(e4, "wokeUp", "player")
  local _, di = find(e4, "damage", "player")
  check("Rest turn 4: wakes up and acts on the same turn", wi and di and wi < di and b.player.status == 0
    and not find(e4, "fastAsleep"), types(e4))
  check("Rest turn 4: 7 draws total (Tackle acc, crit, random; foe acc)", b.rng.draws == 7, b.rng.draws)
  check("Rest: PP 9 for Rest, 9 for Tackle (asleep turns spend none)",
    b.player.moves[1].pp == 9 and b.player.moves[2].pp == 9)
end

do
  -- A Rest user takes no poison damage at that turn's end.
  local b = battle({ MISS }, { playerHP = 20, playerStatus = S.POISON })
  local events = b:runTurn(MOVE, MOVE)
  check("Rest while poisoned: no end-of-turn poison damage",
    find(events, "restSlept") and not find(events, "statusDamage", "player")
      and b.player.hp == b.player.maxHP, types(events))
end

do
  -- AI/wild foes may now select Rest: a foe Rest resolves through runTurn.
  local b = battle({ 0, 1, 0 }, { playerMoves = { Data.MOVE_TACKLE }, foeMove = MOVE_REST })
  b.foe.hp = 100
  local events = b:runTurn(MOVE, MOVE)
  check("foe Rest resolves: slept and healed", find(events, "restSlept", "foe")
    and b.foe.status == 3 and b.foe.hp == b.foe.maxHP and b.rng.draws == 3, types(events))
end

---------------------------------------------------------------------------
-- Focus Energy (47): BattleScript_EffectFocusEnergy, bs1.s:884-894
---------------------------------------------------------------------------
do
  local b = battle({}, { playerMoves = { MOVE_FOCUS_ENERGY } })
  local events = use(b)
  check("Focus Energy: sets the volatile and emits focusEnergy",
    b.player.focusEnergy == true and types(events) == "useMove,focusEnergy", types(events))
  check("Focus Energy: one PP, no draws", b.player.moves[1].pp == 9 and b.rng.draws == 0)
  events = use(b)
  check("Focus Energy again: But it failed!, still set",
    types(events) == "useMove,moveFailed" and b.player.focusEnergy == true, types(events))
  check("Focus Energy again: PP spent, no draws", b.player.moves[1].pp == 8 and b.rng.draws == 0)
end

do
  -- critStageFor = 2 * FE + base for every effect (critRoll clamps to 4).
  local b = battle({})
  b.player.focusEnergy = true
  local ok = true
  for effect = 0, 213 do
    local base = (effect == 43 or effect == 75 or effect == 200 or effect == 209) and 1 or 0
    if b:critStageFor(b.player, { effect = effect }) ~= 2 + base then ok = false end
  end
  check("H1 with Focus Energy: stage = 2 + base for every effect", ok)
  check("H1 with Focus Energy: the foe's own stage is unaffected",
    b:critStageFor(b.foe, { effect = 0 }) == 0)
end

-- Ordinary-hit site. Tackle: acc, crit, random.
local function hit(move, critDraw, fe, extra)
  local b = battle({ 0, critDraw, 0, extra or 99 }, { playerMoves = { move } })
  b.player.focusEnergy = fe
  local events = use(b)
  return find(events, "critical", "player") ~= nil, b
end

do
  check("Tackle + FE (stage 2, % 4) crits on 4", hit(Data.MOVE_TACKLE, 4, true))
  check("Tackle without FE (% 16) does not crit on 4", not hit(Data.MOVE_TACKLE, 4, false))
  check("Tackle + FE does not crit on 2", not hit(Data.MOVE_TACKLE, 2, true))
  check("Tackle + FE crits on 12 (12 % 4 == 0)", hit(Data.MOVE_TACKLE, 12, true))
  local _, b = hit(Data.MOVE_TACKLE, 4, true)
  check("Tackle + FE: still 3 draws", b.rng.draws == 3, b.rng.draws)
  check("Slash + FE (stage 3, % 3) crits on 3", hit(MOVE_SLASH, 3, true))
  check("Slash without FE (% 8) does not crit on 3", not hit(MOVE_SLASH, 3, false))
  check("Slash + FE does not crit on 4 (4 % 3 ~= 0)", not hit(MOVE_SLASH, 4, true))
  check("Slash + FE crits on 9", hit(MOVE_SLASH, 9, true))
  check("Blaze Kick + FE (stage 3, % 3) crits on 3", hit(MOVE_BLAZE_KICK, 3, true))
  check("Blaze Kick without FE (% 8) does not crit on 3", not hit(MOVE_BLAZE_KICK, 3, false))
  _, b = hit(MOVE_BLAZE_KICK, 3, true)
  check("Blaze Kick + FE: 4 draws (acc, crit, random, % 100)", b.rng.draws == 4, b.rng.draws)
end

do
  -- Explosion site: crit, random before accuracy.
  local b = battle({ 4, 0, 0 }, { playerMoves = { MOVE_EXPLOSION }, foeHP = 900 })
  b.player.focusEnergy = true
  local events = use(b)
  check("Explosion + FE crits on 4 (% 4)", find(events, "critical", "player") ~= nil, types(events))
  b = battle({ 4, 0, 0 }, { playerMoves = { MOVE_EXPLOSION }, foeHP = 900 })
  events = use(b)
  check("Explosion without FE does not crit on 4", not find(events, "critical"), types(events))
end

do
  -- resolveMultiHit site (Double Kick): acc, (crit, random) x 2.
  local b = battle({ 0, 4, 0, 4, 0 }, { playerMoves = { Data.MOVE_DOUBLE_KICK } })
  b.player.focusEnergy = true
  local events = use(b)
  check("Double Kick + FE: both hits crit on 4", count(events, "critical", "player") == 2, types(events))
  b = battle({ 0, 4, 0, 4, 0 }, { playerMoves = { Data.MOVE_DOUBLE_KICK } })
  events = use(b)
  check("Double Kick without FE: no crit on 4", count(events, "critical") == 0, types(events))
end

do
  -- resolveTripleKick site: (acc, crit, random) x 3.
  local b = battle({ 0, 4, 0, 0, 4, 0, 0, 4, 0 }, { playerMoves = { MOVE_TRIPLE_KICK } })
  b.player.focusEnergy = true
  local events = use(b)
  check("Triple Kick + FE: every kick crits on 4", count(events, "critical", "player") == 3, types(events))
  check("Triple Kick + FE: 9 draws", b.rng.draws == 9, b.rng.draws)
end

do
  -- Through runTurn: Focus Energy on turn 1, the next Tackle crits on 4.
  local b = battle({ MISS, 0, 4, 0, MISS }, { playerMoves = { MOVE_FOCUS_ENERGY, Data.MOVE_TACKLE } })
  local e1 = b:runTurn(MOVE, MOVE)
  check("FE turn 1: pumped, 1 draw (foe accuracy)", find(e1, "focusEnergy", "player") and b.rng.draws == 1)
  local e2 = b:runTurn(MOVE2, MOVE)
  check("FE turn 2: Tackle crits on 4", find(e2, "critical", "player") ~= nil and b.rng.draws == 5, types(e2))
end

do
  -- Cleared on faint (FaintClearSetData zeroes status2), and a forced
  -- switch-in starts clear.
  local b = battle({ 0, 1, 0 }, { playerMoves = { MOVE_FOCUS_ENERGY }, playerHP = 1,
    hasReplacement = function() return true end })
  local fainted = b.player
  local events = b:runTurn(MOVE, MOVE)
  check("FE set, then the user faints: volatile cleared",
    find(events, "focusEnergy", "player") and find(events, "faint", "player")
      and fainted.focusEnergy == false, types(events))
  local replacement = BattleEngine.makeBattler({ species = 1, level = 10, stats = stats(40, 20),
    types = { Data.TYPE_NORMAL, Data.TYPE_NORMAL }, moves = { { move = Data.MOVE_TACKLE, pp = 10 } } })
  b:resolveForcedSwitch(BattleEngine.SIDE_PLAYER, replacement)
  check("forced switch-in starts without Focus Energy", b.player.focusEnergy == false)
end

do
  -- recordFaint clears it directly.
  local b = battle({})
  b.foe.focusEnergy = true
  b.foe.hp = 0
  b:beginFaintSequence()
  b:recordFaint(BattleEngine.SIDE_FOE, {})
  b.faintSequence = nil
  check("recordFaint clears focusEnergy", b.foe.focusEnergy == false)
end

do
  -- A voluntary switch replaces the battler: the switch-in is clear, and
  -- the outgoing battler's crits no longer apply to the active side.
  local b = battle({ MISS, MISS }, { playerMoves = { MOVE_FOCUS_ENERGY } })
  b:runTurn(MOVE, MOVE)
  check("FE set before the switch", b.player.focusEnergy == true)
  local incoming = BattleEngine.makeBattler({ species = 1, level = 10, stats = stats(40, 20),
    types = { Data.TYPE_NORMAL, Data.TYPE_NORMAL }, moves = { { move = Data.MOVE_TACKLE, pp = 10 } } })
  local events = b:runTurn({ action = "switch", battler = incoming }, MOVE)
  check("voluntary switch-in starts without Focus Energy",
    find(events, "switch", "player") and b.player == incoming and b.player.focusEnergy == false)
end

---------------------------------------------------------------------------
-- AI_CBM_FocusEnergy (data/battle_ai_scripts.s:386-388)
---------------------------------------------------------------------------
do
  local b = battle({})
  local fe = moves[MOVE_FOCUS_ENERGY]
  check("AI: Focus Energy not yet set -> 0",
    AICheckBadMove.score(b.foe, b.player, fe, MOVE_FOCUS_ENERGY, b.typeChart, {}) == 0)
  b.foe.focusEnergy = true
  check("AI: Focus Energy already set -> -10",
    AICheckBadMove.score(b.foe, b.player, fe, MOVE_FOCUS_ENERGY, b.typeChart, {}) == -10)
  b.player.focusEnergy = true
  b.foe.focusEnergy = false
  check("AI: reads AI_USER, not the target",
    AICheckBadMove.score(b.foe, b.player, fe, MOVE_FOCUS_ENERGY, b.typeChart, {}) == 0)
  check("AI: Rest has no CheckBadMove entry -> 0",
    AICheckBadMove.score(b.foe, b.player, moves[MOVE_REST], MOVE_REST, b.typeChart, {}) == 0)
end

do
  -- Through the engine: after a foe Focus Energy the AI term applies.
  local b = battle({ 0, 1, 0 }, { playerMoves = { Data.MOVE_TACKLE }, foeMove = MOVE_FOCUS_ENERGY })
  b:runTurn(MOVE, MOVE)
  check("AI: after the foe's Focus Energy the term is -10", b.foe.focusEnergy
    and AICheckBadMove.score(b.foe, b.player, moves[MOVE_FOCUS_ENERGY], MOVE_FOCUS_ENERGY,
      b.typeChart, {}) == -10)
end

---------------------------------------------------------------------------
-- Controller text through the real engine
---------------------------------------------------------------------------
local function messages(b, actions)
  local ctrl = BattleSceneController.new({ engine = b, playerName = "PLAYER", foeName = "FOE",
    moveName = function() return "MOVE" end })
  ctrl:advanceMessage(); ctrl:advanceMessage()
  local out = {}
  for _, action in ipairs(actions) do
    ctrl:_runTurn(action)
    for _, entry in ipairs(ctrl.messages) do if entry.text then out[#out + 1] = entry.text end end
  end
  return table.concat(out, "|")
end

do
  local all = messages(battle({ MISS }, { playerHP = 5 }), { MOVE })
  local slept = all:find("PLAYER went\nto sleep!", 1, true)
  local healed = all:find("PLAYER regained\nhealth!", 1, true)
  check("controller: Rest went to sleep, then regained health", slept and healed and slept < healed, all)
  all = messages(battle({ MISS }, { playerHP = 5, playerStatus = S.POISON }), { MOVE })
  slept = all:find("PLAYER slept and\nbecame healthy!", 1, true)
  healed = all:find("PLAYER regained\nhealth!", 1, true)
  check("controller: Rest slept and became healthy, then regained health",
    slept and healed and slept < healed, all)
  all = messages(battle({ MISS }, { playerAbility = BattleEngine.ABILITY_INSOMNIA, playerHP = 5 }), { MOVE })
  check("controller: Rest with Insomnia", all:find("PLAYER stayed awake\nusing its INSOMNIA!", 1, true) ~= nil,
    all)
  all = messages(battle({ MISS }), { MOVE })
  check("controller: Rest at full HP", all:find("PLAYER's\nHP is full!", 1, true) ~= nil, all)
  all = messages(battle({ MISS, MISS }, { playerMoves = { MOVE_FOCUS_ENERGY } }), { MOVE, MOVE })
  local pumped = all:find("PLAYER is getting\npumped!", 1, true)
  local failedAt = all:find("But it failed!", 1, true)
  check("controller: Focus Energy pumped, then But it failed!", pumped and failedAt and pumped < failedAt, all)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
