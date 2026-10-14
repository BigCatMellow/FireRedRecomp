-- Run: lua5.1 tests/battle_multihit_tail_test.lua
--
-- Multi-hit tail follow-up (work/tasks/phase4-multihit-tail.md): the source
-- tail of BattleScript_MultiHitLoop / MultiHitPrintStrings / MultiHitEnd
-- (pret/pokefirered c75f352, data/battle_scripts_1.s:605-655, :838-846) for
-- EFFECT_MULTI_HIT (29) and EFFECT_DOUBLE_HIT (44), which Twineedle (77)
-- already followed:
--   * a KO on any hit breaks the loop; "Hit N time(s)!" (hits landed), then
--     the trailing seteffectwithchance, then tryfaintmon (the caller's faint
--     check, :653), then forcedSwitchNeeded when a replacement exists;
--   * MultiHitEnd's `Random() % 100` (:651; src/battle_script_commands.c
--     :2789, the first `&&` operand) is drawn on every landed path and on
--     the no-effect path, although 29/44 carry effect byte 0 (`setbyte
--     sMULTIHIT_EFFECT, 0`, :612, :845) and secondaryEffectChance 0;
--   * the effectiveness text is printed once, by MultiHitPrintStrings'
--     resultmessage (:644-645), just before the count (:649).
-- Per-hit RNG is (crit, random); crit value 1 = no crit, random 0 = 100%.
package.path = package.path .. ";./?.lua"

local BattleEngine = require("src.core.BattleEngine")
local BattleSceneController = require("src.core.BattleSceneController")
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

local MOVE_TWINEEDLE, MOVE_TRIPLE_KICK = 41, 167
local moves = {}
for id, m in pairs(Data.moves) do moves[id] = m end
-- src/data/battle_moves.h at the pin.
moves[MOVE_TWINEEDLE] = { effect = 77, power = 25, type = Data.TYPE_BUG, accuracy = 100, pp = 20,
  secondaryEffectChance = 20, target = 0, priority = 0, flags = 0x12 }
moves[MOVE_TRIPLE_KICK] = { effect = 104, power = 10, type = Data.TYPE_FIGHTING, accuracy = 90, pp = 10,
  secondaryEffectChance = 0, target = 0, priority = 0, flags = 0x33 }

local DOUBLE_KICK, FURY_ATTACK = Data.MOVE_DOUBLE_KICK, Data.MOVE_FURY_ATTACK
local NORMAL = { Data.TYPE_NORMAL, Data.TYPE_NORMAL }
local GHOST = { Data.TYPE_GHOST, Data.TYPE_GHOST }
local ROCK = { Data.TYPE_ROCK, Data.TYPE_ROCK }
local NO_STATUS_ROLL, PASSING_ROLL = 99, 0

local function stats(hp, speed)
  return { hp = hp, attack = 20, defense = 20, speed = speed, spAttack = 20, spDefense = 20 }
end

-- Player is faster (20 vs 10), so the player's move resolves first.
local function battle(values, opts)
  opts = opts or {}
  local engine = BattleEngine.new({
    player = BattleEngine.makeBattler({ species = 1, level = 10, stats = stats(40, 20),
      types = NORMAL, moves = { { move = opts.playerMove, pp = 10 } } }),
    foe = BattleEngine.makeBattler({ species = 4, level = 10, stats = stats(400, 10),
      types = opts.foeTypes or NORMAL, moves = { { move = Data.MOVE_TACKLE, pp = 10 } } }),
    moves = moves, typeChart = Data.typeChart, rng = scriptedRng(values),
    hasReplacement = opts.hasReplacement,
  })
  if opts.foeCurrentHP then engine.foe.hp = opts.foeCurrentHP end
  return engine
end

local function use(values, opts)
  local b = battle(values, opts)
  local events = {}
  b:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
  return b, events
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
local function count(events, t, side)
  local n = 0
  for _, e in ipairs(events) do
    if e.type == t and (side == nil or e.side == side) then n = n + 1 end
  end
  return n
end
local function concat(...)
  local out = {}
  for _, list in ipairs({ ... }) do
    for _, v in ipairs(list) do out[#out + 1] = v end
  end
  return out
end

-- Damage of one non-crit, 100%-random hit against a 400-HP Normal foe.
local function perHit(move, prefix)
  local b = use(concat(prefix, { 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, NO_STATUS_ROLL }), { playerMove = move })
  return b.foe.maxHP - b.foe.hp
end

-- Hit-count prefixes for Fury Attack (Cmd_setmultihitcounter's arg-0
-- branch, bsc.c:6857-6870): acc 0, then first&3 = 3 > 1 -> second&3 = 3 -> 5.
local DK_PREFIX = { 0 }          -- accuracy only (fixed 2 hits, no count RNG)
local FA5_PREFIX = { 0, 3, 3 }   -- accuracy, two count draws -> 5 hits

local dkTotal = perHit(DOUBLE_KICK, DK_PREFIX)
local dkHit = dkTotal / 2
local faTotal = perHit(FURY_ATTACK, FA5_PREFIX)
local faHit = faTotal / 5
check("probe: Double Kick hits are equal and nonzero", dkHit > 0 and dkHit == math.floor(dkHit), dkTotal)
check("probe: Fury Attack hits are equal and nonzero", faHit > 0 and faHit == math.floor(faHit), faTotal)

-- Builds the RNG list for `hits` landed hits plus the trailing roll.
local function rolls(prefix, hits, trailing)
  local list = concat(prefix)
  for _ = 1, hits do list[#list + 1] = 1; list[#list + 1] = 0 end
  list[#list + 1] = trailing
  return list
end

-- Asserts the full source-tail order of one KO turn through runTurn.
local function koCase(label, move, prefix, hpBefore, hitsLanded, rolledHits, replacement)
  local b = battle(rolls(prefix, hitsLanded, NO_STATUS_ROLL), { playerMove = move, foeCurrentHP = hpBefore,
    hasReplacement = replacement and function() return true end or nil })
  local events = b:runTurn(MOVE, MOVE)
  local mh, mi = find(events, "multiHit", "player")
  local _, fi = find(events, "faint", "foe")
  check(label .. ": " .. hitsLanded .. " damage event(s) of the rolled " .. rolledHits,
    count(events, "damage", "player") == hitsLanded, types(events))
  check(label .. ": multiHit hits=" .. hitsLanded .. " precedes the faint",
    mh and mh.hits == hitsLanded and fi and mi < fi, types(events))
  check(label .. ": exactly one faint", count(events, "faint", "foe") == 1, types(events))
  check(label .. ": draws = prefix + 2 per landed hit + 1 trailing % 100",
    b.rng.draws == #prefix + 2 * hitsLanded + 1, b.rng.draws)
  if replacement then
    local _, si = find(events, "forcedSwitchNeeded", "foe")
    check(label .. ": multiHit, faint, then forcedSwitchNeeded; battle not over",
      si and fi < si and not b:isOver() and b.awaitingForcedSwitch == BattleEngine.SIDE_FOE, types(events))
    check(label .. ": the foe does not act after the forced switch is queued",
      count(events, "damage", "foe") == 0, types(events))
  else
    local _, ei = find(events, "battleEnd")
    check(label .. ": battleEnd after the faint, playerWon", ei and fi < ei and b.outcome == "playerWon",
      types(events))
  end
  return b, events
end

---------------------------------------------------------------------------
-- Double Kick (44): fixed 2 hits.
---------------------------------------------------------------------------
koCase("Double Kick KO on hit 1", DOUBLE_KICK, DK_PREFIX, 1, 1, 2, false)
koCase("Double Kick KO on hit 1 with a replacement", DOUBLE_KICK, DK_PREFIX, 1, 1, 2, true)
-- Last hit: decrementmultihit reaches 0 -> goto MultiHitPrintStrings
-- (bs1.s:640-641), so the count still precedes tryfaintmon (:653).
koCase("Double Kick KO on the last hit (2)", DOUBLE_KICK, DK_PREFIX, dkHit + 1, 2, 2, false)
koCase("Double Kick KO on the last hit (2) with a replacement", DOUBLE_KICK, DK_PREFIX, dkHit + 1, 2, 2, true)

do
  -- Landed, no KO: 1 acc + 2 x (crit, random) + 1 trailing % 100 = 6. A
  -- passing roll (0 <= 0) applies nothing: the effect byte is 0 (bsc.c:2790).
  local b, events = use(rolls(DK_PREFIX, 2, PASSING_ROLL), { playerMove = DOUBLE_KICK })
  check("Double Kick, no KO: 6 draws, multiHit hits=2 last, no secondary event",
    b.rng.draws == 6 and events[#events].type == "multiHit" and events[#events].hits == 2
      and not find(events, "statusApplied") and not find(events, "statusPrevented"), types(events))
  check("Double Kick, no KO: the foe keeps its status and HP above 0", b.foe.status == 0 and b.foe.hp > 0)
end

do
  -- No effect (Fighting vs Ghost): acc, crit, then MultiHitNoMoreHits ->
  -- resultmessage -> jumpifmovehadnoeffect MultiHitEnd -> the % 100
  -- (bs1.s:624, :642-647, :651). No random (it is after the no-effect
  -- jump, :625), no count, no damage.
  local b, events = use({ 0, 1, NO_STATUS_ROLL }, { playerMove = DOUBLE_KICK, foeTypes = GHOST })
  check("Double Kick vs Ghost: noEffect only, 3 draws (acc, crit, % 100)",
    find(events, "noEffect", "player") and not find(events, "multiHit") and not find(events, "damage")
      and b.rng.draws == 3, b.rng.draws)
end

do
  -- Effectiveness rides on the multiHit event, not on each damage event.
  local _, events = use(rolls(DK_PREFIX, 2, NO_STATUS_ROLL), { playerMove = DOUBLE_KICK })
  local perHitFlags = false
  for _, e in ipairs(events) do
    if e.type == "damage" and (e.superEffective or e.notVeryEffective) then perHitFlags = true end
  end
  local mh = find(events, "multiHit", "player")
  check("Double Kick vs Normal: no per-hit effectiveness, superEffective on multiHit",
    not perHitFlags and mh and mh.superEffective == true and mh.notVeryEffective == false, types(events))
end

---------------------------------------------------------------------------
-- Fury Attack (29): rolled 5 hits (two count draws).
---------------------------------------------------------------------------
koCase("Fury Attack (5) KO on hit 1", FURY_ATTACK, FA5_PREFIX, 1, 1, 5, false)
koCase("Fury Attack (5) KO on hit 1 with a replacement", FURY_ATTACK, FA5_PREFIX, 1, 1, 5, true)
koCase("Fury Attack (5) KO on the middle hit (3)", FURY_ATTACK, FA5_PREFIX, 2 * faHit + 1, 3, 5, false)
koCase("Fury Attack (5) KO on the middle hit (3) with a replacement", FURY_ATTACK, FA5_PREFIX,
  2 * faHit + 1, 3, 5, true)
koCase("Fury Attack (5) KO on the last hit (5)", FURY_ATTACK, FA5_PREFIX, 4 * faHit + 1, 5, 5, false)
koCase("Fury Attack (5) KO on the last hit (5) with a replacement", FURY_ATTACK, FA5_PREFIX,
  4 * faHit + 1, 5, 5, true)
-- Single-count-draw branch (first&3 = 1 -> 3 hits): KO on its last hit.
koCase("Fury Attack (3) KO on the last hit (3)", FURY_ATTACK, { 0, 1 }, 2 * faHit + 1, 3, 3, false)

do
  local b, events = use(rolls(FA5_PREFIX, 5, PASSING_ROLL), { playerMove = FURY_ATTACK })
  check("Fury Attack (5), no KO: 14 draws, multiHit hits=5 last, no secondary event",
    b.rng.draws == 14 and events[#events].type == "multiHit" and events[#events].hits == 5
      and not find(events, "statusApplied"), types(events))
end

do
  -- No effect (Normal vs Ghost): acc, one count draw, crit, % 100.
  local b, events = use({ 0, 1, 1, NO_STATUS_ROLL }, { playerMove = FURY_ATTACK, foeTypes = GHOST })
  check("Fury Attack vs Ghost: noEffect only, 4 draws (acc, count, crit, % 100)",
    find(events, "noEffect", "player") and not find(events, "multiHit") and not find(events, "damage")
      and b.rng.draws == 4, b.rng.draws)
  -- Two count draws on the same path: 5 draws.
  b, events = use({ 0, 3, 3, 1, NO_STATUS_ROLL }, { playerMove = FURY_ATTACK, foeTypes = GHOST })
  check("Fury Attack vs Ghost (two count draws): 5 draws",
    find(events, "noEffect") and b.rng.draws == 5, b.rng.draws)
end

do
  -- Not very effective (Normal vs Rock) on the multiHit event only.
  local _, events = use(rolls(FA5_PREFIX, 5, NO_STATUS_ROLL), { playerMove = FURY_ATTACK, foeTypes = ROCK })
  local mh = find(events, "multiHit", "player")
  local perHitFlags = false
  for _, e in ipairs(events) do
    if e.type == "damage" and (e.superEffective or e.notVeryEffective) then perHitFlags = true end
  end
  check("Fury Attack vs Rock: notVeryEffective on multiHit only",
    not perHitFlags and mh and mh.notVeryEffective == true and mh.superEffective == false, types(events))
end

---------------------------------------------------------------------------
-- Controller text through the real engine.
---------------------------------------------------------------------------
local function messages(values, opts)
  local b = battle(values, opts)
  local ctrl = BattleSceneController.new({ engine = b, playerName = "PLAYER", foeName = "FOE",
    moveName = function() return "MOVE" end })
  ctrl:advanceMessage(); ctrl:advanceMessage()
  ctrl:_runTurn(MOVE)
  local out = {}
  for _, entry in ipairs(ctrl.messages) do if entry.text then out[#out + 1] = entry.text end end
  return table.concat(out, "|")
end
local function occurrences(text, needle)
  local n, at = 0, 1
  while true do
    local i = text:find(needle, at, true)
    if not i then return n end
    n, at = n + 1, i + 1
  end
end
local function pos(text, needle) return text:find(needle, 1, true) end

do
  -- Double Kick KO on hit 2 with a replacement: effectiveness once, then
  -- the count, then the faint, then the forced switch.
  local all = messages(rolls(DK_PREFIX, 2, NO_STATUS_ROLL), { playerMove = DOUBLE_KICK,
    foeCurrentHP = dkHit + 1, hasReplacement = function() return true end })
  local super, hit, fainted, switch = pos(all, "It's super effective!"), pos(all, "Hit 2 time(s)!"),
    pos(all, "fainted!"), pos(all, "must send out")
  check("controller: Double Kick prints the effectiveness text exactly once",
    occurrences(all, "It's super effective!") == 1, all)
  check("controller: Double Kick KO order is super effective, Hit 2, fainted, must send out",
    super and hit and fainted and switch and super < hit and hit < fainted and fainted < switch, all)
  check("controller: the effectiveness text is immediately before the count",
    super and hit and all:sub(super, hit - 1) == "It's super effective!|", all)
end

do
  -- Fury Attack KO on hit 1 without a replacement: "Hit 1 time(s)!" then
  -- the faint (the old shape printed only the faint).
  local all = messages(rolls(FA5_PREFIX, 1, NO_STATUS_ROLL), { playerMove = FURY_ATTACK, foeCurrentHP = 1 })
  local hit, fainted = pos(all, "Hit 1 time(s)!"), pos(all, "fainted!")
  check("controller: Fury Attack KO on hit 1 prints Hit 1 time(s)! before the faint",
    hit and fainted and hit < fainted, all)
  all = messages(rolls(FA5_PREFIX, 5, NO_STATUS_ROLL), { playerMove = FURY_ATTACK, foeTypes = ROCK })
  check("controller: Fury Attack vs Rock prints not very effective once, before Hit 5 time(s)!",
    occurrences(all, "It's not very effective...") == 1
      and pos(all, "It's not very effective...") < pos(all, "Hit 5 time(s)!"), all)
  all = messages({ 0, 1, 1, NO_STATUS_ROLL }, { playerMove = FURY_ATTACK, foeTypes = GHOST })
  check("controller: Fury Attack vs Ghost prints It doesn't affect, no count",
    pos(all, "It doesn't affect FOE...") and not pos(all, "time(s)!"), all)
end

---------------------------------------------------------------------------
-- Unaffected: Twineedle's RNG/event order and Triple Kick.
---------------------------------------------------------------------------
do
  -- Twineedle: unchanged 6 draws and order; only the effectiveness flags
  -- moved from the damage events to the multiHit event.
  local b, events = use({ 0, 1, 0, 1, 0, 20 }, { playerMove = MOVE_TWINEEDLE,
    foeTypes = { Data.TYPE_GRASS, Data.TYPE_GRASS } })
  local mh, mi = find(events, "multiHit", "player")
  local _, si = find(events, "statusApplied", "foe")
  check("Twineedle unchanged: 6 draws, count then poison",
    b.rng.draws == 6 and mh and mh.hits == 2 and si and mi < si, types(events))
  local perHitFlags = false
  for _, e in ipairs(events) do
    if e.type == "damage" and e.superEffective then perHitFlags = true end
  end
  check("Twineedle vs Grass: superEffective on multiHit, not per hit",
    not perHitFlags and mh.superEffective == true, types(events))
end

do
  -- Triple Kick has its own loop (resolveTripleKick) and is not changed:
  -- (acc, crit, random) x 3, no trailing roll (its tracked plain-hit gap,
  -- inventory row 104), effectiveness still on each kick's damage event.
  local b, events = use({ 0, 1, 0, 0, 1, 0, 0, 1, 0 }, { playerMove = MOVE_TRIPLE_KICK })
  local mh = find(events, "multiHit", "player")
  check("Triple Kick unchanged: 9 draws, hits=3", b.rng.draws == 9 and mh and mh.hits == 3, b.rng.draws)
  check("Triple Kick unchanged: per-kick superEffective on damage events, none on multiHit",
    count(events, "damage", "player") == 3 and events[2].type == "damage" and events[2].superEffective == true
      and not mh.superEffective, types(events))
  local b2 = battle({ 0, 1, 0 }, { playerMove = MOVE_TRIPLE_KICK, foeCurrentHP = 1 })
  local turn = b2:runTurn(MOVE, MOVE)
  local _, hi = find(turn, "multiHit", "player")
  local _, fi = find(turn, "faint", "foe")
  check("Triple Kick unchanged: KO on kick 1 prints the count before the faint, 3 draws",
    hi and fi and hi < fi and b2.rng.draws == 3, types(turn))
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
