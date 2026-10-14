-- Run: lua5.1 tests/battle_status_leftovers_test.lua
--
-- Status-leftovers slice L1 through the real engine: the crit-stage helper
-- H1 (BattleEngine:critStageFor) at all four critcalc sites, Tri Attack's
-- `% 3` secondary (36), Twineedle's two hits and single trailing poison roll
-- (77) and Blaze Kick's crit stage and burn (200). Oracles from
-- pret/pokefirered c75f352 (see
-- work/reports/phase4-status-leftovers-design-proposal.md).
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

-- src/data/battle_moves.h at the pin (:536-547, :2096-2107, :3890-3901).
local MOVE_TWINEEDLE, MOVE_TRI_ATTACK, MOVE_BLAZE_KICK = 41, 161, 299
local MOVE_SLASH, MOVE_EXPLOSION, MOVE_TRIPLE_KICK = 163, 153, 167
local moves = {}
for id, m in pairs(Data.moves) do moves[id] = m end
moves[MOVE_TWINEEDLE] = { effect = 77, power = 25, type = Data.TYPE_BUG, accuracy = 100, pp = 20,
  secondaryEffectChance = 20, target = 0, priority = 0, flags = 0x12 }
moves[MOVE_TRI_ATTACK] = { effect = 36, power = 80, type = Data.TYPE_NORMAL, accuracy = 100, pp = 10,
  secondaryEffectChance = 20, target = 0, priority = 0, flags = 0x12 }
moves[MOVE_BLAZE_KICK] = { effect = 200, power = 85, type = Data.TYPE_FIRE, accuracy = 90, pp = 10,
  secondaryEffectChance = 10, target = 0, priority = 0, flags = 0x13 }
moves[MOVE_SLASH] = { effect = 43, power = 70, type = Data.TYPE_NORMAL, accuracy = 100, pp = 20,
  secondaryEffectChance = 0, target = 0, priority = 0, flags = 0x33 }
moves[MOVE_EXPLOSION] = { effect = 7, power = 250, type = Data.TYPE_NORMAL, accuracy = 100, pp = 5,
  secondaryEffectChance = 0, target = 0x08, priority = 0, flags = 0x12 }
moves[MOVE_TRIPLE_KICK] = { effect = 104, power = 10, type = Data.TYPE_FIGHTING, accuracy = 90, pp = 10,
  secondaryEffectChance = 0, target = 0, priority = 0, flags = 0x33 }
-- Synthetic effect-77 record (Normal type) to reach the otherwise
-- unreachable no-effect branch against a Ghost.
local MOVE_NORMAL_TWINEEDLE = 990
moves[MOVE_NORMAL_TWINEEDLE] = { effect = 77, power = 25, type = Data.TYPE_NORMAL, accuracy = 100,
  pp = 20, secondaryEffectChance = 20, target = 0, priority = 0, flags = 0x12 }

local function stats(hp, speed)
  return { hp = hp, attack = 20, defense = 20, speed = speed, spAttack = 20, spDefense = 20 }
end

-- Player is faster (20 vs 10).
local function battle(values, opts)
  opts = opts or {}
  local engine = BattleEngine.new({
    player = BattleEngine.makeBattler({ species = 1, level = 10,
      stats = stats(opts.playerHP or 40, 20),
      types = opts.playerTypes or { Data.TYPE_NORMAL, Data.TYPE_NORMAL },
      moves = { { move = opts.playerMove or Data.MOVE_TACKLE, pp = 10 } } }),
    foe = BattleEngine.makeBattler({ species = 4, level = 10,
      stats = stats(opts.foeHP or 400, 10),
      types = opts.foeTypes or { Data.TYPE_NORMAL, Data.TYPE_NORMAL },
      status = opts.foeStatus,
      moves = { { move = Data.MOVE_TACKLE, pp = 10 } } }),
    moves = moves, typeChart = Data.typeChart, rng = scriptedRng(values),
    hasReplacement = opts.hasReplacement,
  })
  if opts.foeAbility then engine.foe.ability = opts.foeAbility end
  if opts.foeCurrentHP then engine.foe.hp = opts.foeCurrentHP end
  return engine
end

-- Resolve only the player's move, so the draw count is exactly that move's.
local function use(move, values, opts)
  opts = opts or {}
  opts.playerMove = move
  local b = battle(values, opts)
  local events = {}
  b:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
  return b, events
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
local function count(events, t, side)
  local n = 0
  for _, e in ipairs(events) do
    if e.type == t and (side == nil or e.side == side) then n = n + 1 end
  end
  return n
end

---------------------------------------------------------------------------
-- H1: BattleEngine:critStageFor (Cmd_critcalc, bsc.c:1184-1194)
---------------------------------------------------------------------------
do
  local b = battle({})
  local stageOf = function(effect) return b:critStageFor(b.player, { effect = effect }) end
  check("H1: +1 for EFFECT_HIGH_CRITICAL (43)", stageOf(43) == 1)
  check("H1: +1 for EFFECT_SKY_ATTACK (75)", stageOf(75) == 1)
  check("H1: +1 for EFFECT_BLAZE_KICK (200)", stageOf(200) == 1)
  check("H1: +1 for EFFECT_POISON_TAIL (209)", stageOf(209) == 1)
  local others = true
  for effect = 0, 213 do
    if effect ~= 43 and effect ~= 75 and effect ~= 200 and effect ~= 209 and stageOf(effect) ~= 0 then
      others = false
    end
  end
  check("H1: every other effect is stage 0 (without Focus Energy)", others)
end

-- Spy on the helper at each site: it must be called once per critcalc with
-- the current move, and its stage must reach critRoll. Returning stage 1
-- makes draw 8 a crit (8 % 8 == 0) where stage 0 would not (8 % 16 ~= 0).
local function spy(b, stage)
  local calls = {}
  b.critStageFor = function(self, attacker, move)
    calls[#calls + 1] = { attacker = attacker, move = move }
    return stage
  end
  return calls
end

do
  -- Ordinary hit: acc, crit, random.
  local b = battle({ 0, 8, 0 }, { playerMove = Data.MOVE_TACKLE })
  local calls = spy(b, 1)
  local events = {}
  b:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
  check("H1 ordinary site: one call with the attacker and Tackle",
    #calls == 1 and calls[1].attacker == b.player and calls[1].move.effect == 0, #calls)
  check("H1 ordinary site: the stage reaches critRoll", find(events, "critical", "player") ~= nil, types(events))
  b = battle({ 0, 8, 0 }, { playerMove = Data.MOVE_TACKLE })
  events = {}
  b:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
  check("H1 ordinary site: unspied Tackle at stage 0 does not crit on 8", not find(events, "critical"))
end

do
  -- Explosion: crit, random before accuracy (EffectExplosion).
  local b = battle({ 8, 0, 0 }, { playerMove = MOVE_EXPLOSION, foeHP = 900 })
  local calls = spy(b, 1)
  local events = {}
  b:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
  check("H1 Explosion site: one call with Explosion",
    #calls == 1 and calls[1].move.effect == 7, #calls)
  check("H1 Explosion site: the stage reaches critRoll", find(events, "critical", "player") ~= nil, types(events))
  check("H1 Explosion site: Explosion itself stays at stage 0",
    BattleEngine.critStageFor(b, b.player, moves[MOVE_EXPLOSION]) == 0)
end

do
  -- resolveMultiHit (Double Kick): acc, then (crit, random) x 2.
  local b = battle({ 0, 8, 0, 8, 0 }, { playerMove = Data.MOVE_DOUBLE_KICK })
  local calls = spy(b, 1)
  local events = {}
  b:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
  check("H1 multi-hit site: one call per hit", #calls == 2 and calls[2].move.effect == 44, #calls)
  check("H1 multi-hit site: both hits crit at stage 1", count(events, "critical", "player") == 2, types(events))
end

do
  -- resolveTripleKick: (acc, crit, random) x 3.
  local b = battle({ 0, 8, 0, 0, 8, 0, 0, 8, 0 }, { playerMove = MOVE_TRIPLE_KICK })
  local calls = spy(b, 1)
  local events = {}
  b:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
  check("H1 Triple Kick site: one call per kick", #calls == 3 and calls[3].move.effect == 104, #calls)
  check("H1 Triple Kick site: every kick crits at stage 1", count(events, "critical", "player") == 3, types(events))
  check("H1 Triple Kick site: 9 draws", b.rng.draws == 9, b.rng.draws)
end

do
  -- Existing stage-1 users keep their behaviour through H1.
  local _, events = use(MOVE_SLASH, { 0, 8, 0 })
  check("Slash still crits at stage 1 via H1", find(events, "critical") ~= nil, types(events))
  _, events = use(MOVE_SLASH, { 0, 4, 0 })
  check("Slash stage 1 does not crit on 4 (4 % 8 ~= 0)", not find(events, "critical"))
end

---------------------------------------------------------------------------
-- Blaze Kick (200): BattleScript_EffectBurnHit plus one crit stage
---------------------------------------------------------------------------
do
  local b, events = use(MOVE_BLAZE_KICK, { 0, 8, 0, 99 })
  check("Blaze Kick crits on 8 (stage 1, % 8)", find(events, "critical", "player") ~= nil, types(events))
  check("Blaze Kick hit draws accuracy, crit, random, % 100", b.rng.draws == 4, b.rng.draws)
  _, events = use(MOVE_BLAZE_KICK, { 0, 4, 0, 99 })
  check("Blaze Kick does not crit on 4", not find(events, "critical"))
  _, events = use(MOVE_BLAZE_KICK, { 0, 24, 0, 99 })
  check("Blaze Kick crits on 24 (24 % 8 == 0)", find(events, "critical") ~= nil)
  _, events = use(Data.MOVE_EMBER, { 0, 8, 0, 99 })
  check("Ember (stage 0, % 16) does not crit on the same 8", not find(events, "critical"))
  _, events = use(Data.MOVE_EMBER, { 0, 16, 0, 99 })
  check("Ember crits on 16", find(events, "critical") ~= nil)
end

do
  local b, events = use(MOVE_BLAZE_KICK, { 0, 1, 0, 10 })
  local _, di = find(events, "damage", "player")
  local st, si = find(events, "statusApplied", "foe")
  check("Blaze Kick roll 10 <= 10 burns after the damage",
    st and st.kind == "burn" and di < si and S.isBurned(b.foe.status), types(events))
  check("Blaze Kick burn: 4 draws", b.rng.draws == 4, b.rng.draws)
  b, events = use(MOVE_BLAZE_KICK, { 0, 1, 0, 11 })
  check("Blaze Kick roll 11 does not burn", not find(events, "statusApplied") and b.foe.status == 0)
  check("Blaze Kick failed roll: still 4 draws", b.rng.draws == 4, b.rng.draws)
end

do
  local b, events = use(MOVE_BLAZE_KICK, { 0, 1, 0, 0 }, { foeTypes = { Data.TYPE_FIRE, Data.TYPE_FIRE } })
  check("Blaze Kick vs Fire type: silent, no burn", b.foe.status == 0
    and not find(events, "statusApplied") and not find(events, "statusPrevented") and b.rng.draws == 4)
  b, events = use(MOVE_BLAZE_KICK, { 0, 1, 0, 0 }, { foeAbility = BattleEngine.ABILITY_WATER_VEIL })
  check("Blaze Kick vs Water Veil: silent, no burn", b.foe.status == 0
    and not find(events, "statusPrevented") and b.rng.draws == 4)
  b, events = use(MOVE_BLAZE_KICK, { 0, 1, 0, 0 }, { foeAbility = BattleEngine.ABILITY_SHIELD_DUST })
  check("Blaze Kick vs Shield Dust: silent, no burn", b.foe.status == 0
    and not find(events, "statusPrevented") and b.rng.draws == 4)
  b, events = use(MOVE_BLAZE_KICK, { 0, 1, 0, 0 }, { foeStatus = S.PARALYSIS })
  check("Blaze Kick vs a statused target: unchanged", b.foe.status == S.PARALYSIS)
end

do
  -- Frozen target: no burn (already statused), then MOVEEND_DEFROST.
  local b, events = use(MOVE_BLAZE_KICK, { 0, 1, 0, 0 }, { foeStatus = S.FREEZE })
  local _, ri = find(events, "damage", "player")
  local _, fi = find(events, "defrostedByFire", "foe")
  check("Blaze Kick on a frozen foe: no burn, then defrost",
    not find(events, "statusApplied") and fi and ri < fi and b.foe.status == 0, types(events))
end

do
  -- Miss: accuracy only (BattleScript_PrintMoveMissed). 90 % 100 + 1 > 90.
  local b, events = use(MOVE_BLAZE_KICK, { 90 })
  check("Blaze Kick miss draws accuracy only", find(events, "miss") and b.rng.draws == 1
    and b.player.moves[1].pp == 9, b.rng.draws)
end

do
  -- KO: the roll is still drawn, SetMoveEffect returns at 0 HP.
  local b = battle({ 0, 1, 0, 0 }, { playerMove = MOVE_BLAZE_KICK, foeCurrentHP = 1 })
  local events = b:runTurn(MOVE, MOVE)
  check("Blaze Kick KO: roll drawn, no burn, faint", b.rng.draws == 4 and b.foe.status == 0
    and find(events, "faint", "foe") and not find(events, "statusApplied"), types(events))
end

---------------------------------------------------------------------------
-- Tri Attack (36): MOVE_EFFECT_TRI_ATTACK (bsc.c:2466-2475)
---------------------------------------------------------------------------
do
  local expect = { [0] = "burn", [1] = "freeze", [2] = "paralysis",
    [3] = "burn", [4] = "freeze", [5] = "paralysis", [65535] = "burn" }
  for draw, kind in pairs(expect) do
    local b, events = use(MOVE_TRI_ATTACK, { 0, 1, 0, 20, draw })
    local st = find(events, "statusApplied", "foe")
    check(("Tri Attack %% 3: draw %d -> %s"):format(draw, kind), st and st.kind == kind, types(events))
    check(("Tri Attack draw %d: 5 draws (acc, crit, random, %% 100, %% 3)"):format(draw),
      b.rng.draws == 5, b.rng.draws)
  end
  local b, events = use(MOVE_TRI_ATTACK, { 0, 1, 0, 0, 0 })
  local _, di = find(events, "damage", "player")
  local _, si = find(events, "statusApplied", "foe")
  check("Tri Attack status comes after the damage", di and si and di < si)
  check("Tri Attack burn sets the burn bit", S.isBurned(b.foe.status))
  b = use(MOVE_TRI_ATTACK, { 0, 1, 0, 0, 1 })
  check("Tri Attack freeze sets the freeze bit", S.isFrozen(b.foe.status))
  b = use(MOVE_TRI_ATTACK, { 0, 1, 0, 0, 2 })
  check("Tri Attack paralysis sets the paralysis bit", S.isParalyzed(b.foe.status))
end

do
  local b, events = use(MOVE_TRI_ATTACK, { 0, 1, 0, 21, 0 })
  check("Tri Attack roll 21 > 20: no status and no % 3 draw",
    not find(events, "statusApplied") and b.foe.status == 0 and b.rng.draws == 4, b.rng.draws)
  b, events = use(MOVE_TRI_ATTACK, { 0, 1, 0, 20, 0 })
  check("Tri Attack roll 20 <= 20 passes", find(events, "statusApplied") ~= nil)
end

do
  -- Outer gates: each exits silently with no % 3 draw.
  local b, events = use(MOVE_TRI_ATTACK, { 0, 1, 0, 0, 0 }, { foeStatus = S.PARALYSIS })
  check("Tri Attack vs statused target: no % 3, status kept",
    b.rng.draws == 4 and b.foe.status == S.PARALYSIS and not find(events, "statusApplied"), b.rng.draws)
  -- F2: the whole status1 word, toxic-counter bits included.
  b, events = use(MOVE_TRI_ATTACK, { 0, 1, 0, 0, 0 }, { foeStatus = S.TOXIC_COUNTER_UNIT })
  check("Tri Attack vs a counter-only status1 word: no % 3 (status ~= 0, not hasAny)",
    b.rng.draws == 4 and b.foe.status == S.TOXIC_COUNTER_UNIT, b.rng.draws)
  b, events = use(MOVE_TRI_ATTACK, { 0, 1, 0, 0, 0 }, { foeAbility = BattleEngine.ABILITY_SHIELD_DUST })
  check("Tri Attack vs Shield Dust: no % 3, silent",
    b.rng.draws == 4 and b.foe.status == 0 and not find(events, "statusPrevented"), b.rng.draws)
  b = battle({ 0, 1, 0, 0, 0 }, { playerMove = MOVE_TRI_ATTACK, foeCurrentHP = 1 })
  events = b:runTurn(MOVE, MOVE)
  check("Tri Attack KO: roll drawn, no % 3, faint follows",
    b.rng.draws == 4 and b.foe.status == 0 and find(events, "faint", "foe")
      and not find(events, "statusApplied"), b.rng.draws)
end

do
  -- Inner (recursive) failures: % 3 already drawn, then silent.
  local cases = {
    { "Fire type resists burn", 0, { foeTypes = { Data.TYPE_FIRE, Data.TYPE_FIRE } } },
    { "Water Veil resists burn", 0, { foeAbility = BattleEngine.ABILITY_WATER_VEIL } },
    { "Ice type resists freeze", 1, { foeTypes = { Data.TYPE_ICE, Data.TYPE_ICE } } },
    { "Magma Armor resists freeze", 1, { foeAbility = BattleEngine.ABILITY_MAGMA_ARMOR } },
    { "Limber resists paralysis", 2, { foeAbility = BattleEngine.ABILITY_LIMBER } },
  }
  for _, case in ipairs(cases) do
    local b, events = use(MOVE_TRI_ATTACK, { 0, 1, 0, 0, case[2] }, case[3])
    check("Tri Attack: " .. case[1] .. " silently after the % 3 draw",
      b.rng.draws == 5 and b.foe.status == 0 and not find(events, "statusApplied")
        and not find(events, "statusPrevented"), b.rng.draws)
  end
  local b = use(MOVE_TRI_ATTACK, { 0, 1, 0, 0, 1 }, { foeTypes = { Data.TYPE_FIRE, Data.TYPE_FIRE } })
  check("Tri Attack can freeze a Fire type", S.isFrozen(b.foe.status))
  b = use(MOVE_TRI_ATTACK, { 0, 1, 0, 0, 0 }, { foeTypes = { Data.TYPE_ICE, Data.TYPE_ICE } })
  check("Tri Attack can burn an Ice type", S.isBurned(b.foe.status))
  b = use(MOVE_TRI_ATTACK, { 0, 1, 0, 0, 2 }, { foeTypes = { Data.TYPE_ELECTRIC, Data.TYPE_ELECTRIC } })
  check("Tri Attack paralyzes an Electric type (Gen 3)", S.isParalyzed(b.foe.status))
  b = use(MOVE_TRI_ATTACK, { 0, 1, 0, 0, 2 }, { foeAbility = BattleEngine.ABILITY_IMMUNITY })
  check("Tri Attack ignores Immunity (no poison byte)", S.isParalyzed(b.foe.status))
end

do
  -- Freeze runs CancelMultiTurnMoves on the target (bsc.c:2257-2271).
  local b = battle({ 0, 1, 0, 0, 1 }, { playerMove = MOVE_TRI_ATTACK })
  b.foe.rampageTurns, b.foe.lockedSlot = 2, 1
  local events = {}
  b:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
  check("Tri Attack freeze cancels the target's rampage lock",
    S.isFrozen(b.foe.status) and b.foe.rampageTurns == 0 and b.foe.lockedSlot == nil)
end

do
  -- Ghost target: noEffect still draws % 100 (no % 3).
  local b, events = use(MOVE_TRI_ATTACK, { 0, 1, 0, 0, 0 }, { foeTypes = { Data.TYPE_GHOST, Data.TYPE_GHOST } })
  check("Tri Attack vs Ghost: noEffect, 4 draws (acc, crit, random, % 100)",
    find(events, "noEffect") and b.rng.draws == 4 and b.foe.status == 0, b.rng.draws)
  -- Miss: accuracy only. Accuracy stage -6 makes 99 miss a 100-accuracy move.
  b = battle({ MISS }, { playerMove = MOVE_TRI_ATTACK })
  b.player.statStages.accuracy = -6
  events = {}
  b:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
  check("Tri Attack miss draws accuracy only", find(events, "miss") and b.rng.draws == 1, b.rng.draws)
end

do
  -- Tri Attack is Normal: a frozen target is not thawed (and gets no % 3).
  local b, events = use(MOVE_TRI_ATTACK, { 0, 1, 0, 0, 0 }, { foeStatus = S.FREEZE })
  check("Tri Attack does not defrost a frozen target", S.isFrozen(b.foe.status)
    and not find(events, "defrostedByFire") and b.rng.draws == 4)
end

---------------------------------------------------------------------------
-- Twineedle (77): BattleScript_EffectTwineedle + BattleScript_MultiHitLoop
---------------------------------------------------------------------------
do
  local b, events = use(MOVE_TWINEEDLE, { 0, 1, 0, 1, 0, 20 })
  check("Twineedle lands two hits", count(events, "damage", "player") == 2, types(events))
  local mh, mi = find(events, "multiHit", "player")
  local st, si = find(events, "statusApplied", "foe")
  check("Twineedle: multiHit hits=2", mh and mh.hits == 2)
  check("Twineedle: one poison roll after the count", st and st.kind == "poison" and mi < si, types(events))
  check("Twineedle: 6 draws (acc, 2 x (crit, random), one % 100)", b.rng.draws == 6, b.rng.draws)
  check("Twineedle spends one PP", b.player.moves[1].pp == 9)
  b, events = use(MOVE_TWINEEDLE, { 0, 1, 0, 1, 0, 21 })
  check("Twineedle roll 21: no poison, still 6 draws",
    b.foe.status == 0 and not find(events, "statusApplied") and b.rng.draws == 6, b.rng.draws)
  check("Twineedle: no per-hit roll (exactly one % 100 per use)", count(events, "damage") == 2
    and b.rng.draws == 6)
end

do
  -- Per-hit crits use H1 stage 0 (16) independently.
  local _, events = use(MOVE_TWINEEDLE, { 0, 16, 0, 1, 0, 99 })
  check("Twineedle crit on hit 1 only", count(events, "critical", "player") == 1, types(events))
end

do
  -- KO on hit 1 through runTurn (F6): "Hit 1 time(s)!", the roll, then the
  -- faint (bs1.s:613-655). The roll passes but SetMoveEffect returns at 0 HP.
  local b = battle({ 0, 1, 0, 0 }, { playerMove = MOVE_TWINEEDLE, foeCurrentHP = 1 })
  local events = b:runTurn(MOVE, MOVE)
  local mh, mi = find(events, "multiHit", "player")
  local _, fi = find(events, "faint", "foe")
  check("Twineedle KO on hit 1: one damage event", count(events, "damage", "player") == 1, types(events))
  check("Twineedle KO on hit 1: multiHit hits=1 before the faint", mh and mh.hits == 1 and fi and mi < fi,
    types(events))
  check("Twineedle KO on hit 1: the roll is still drawn (4 draws), no status",
    b.rng.draws == 4 and b.foe.status == 0 and not find(events, "statusApplied"), b.rng.draws)
  check("Twineedle KO on hit 1: exactly one faint, battle won", count(events, "faint", "foe") == 1
    and b.outcome == "playerWon")
end

do
  -- KO on hit 2 through runTurn: both counts, the roll, then the faint.
  local probe = use(MOVE_TWINEEDLE, { 0, 1, 0, 1, 0, 99 })
  local perHit = (probe.foe.maxHP - probe.foe.hp) / 2
  local b = battle({ 0, 1, 0, 1, 0, 0 }, { playerMove = MOVE_TWINEEDLE, foeCurrentHP = perHit + 1 })
  local events = b:runTurn(MOVE, MOVE)
  local mh, mi = find(events, "multiHit", "player")
  local _, fi = find(events, "faint", "foe")
  check("Twineedle KO on hit 2: two hits, hits=2, then faint",
    count(events, "damage", "player") == 2 and mh and mh.hits == 2 and fi and mi < fi, types(events))
  check("Twineedle KO on hit 2: 6 draws, no status", b.rng.draws == 6 and b.foe.status == 0, b.rng.draws)
end

do
  -- KO with a replacement available: the count still precedes the faint
  -- and the forced switch.
  local b = battle({ 0, 1, 0, 0 }, { playerMove = MOVE_TWINEEDLE, foeCurrentHP = 1,
    hasReplacement = function() return true end })
  local events = b:runTurn(MOVE, MOVE)
  local _, mi = find(events, "multiHit", "player")
  local _, fi = find(events, "faint", "foe")
  local _, si = find(events, "forcedSwitchNeeded", "foe")
  check("Twineedle KO with a replacement: multiHit, faint, forcedSwitchNeeded",
    mi and fi and si and mi < fi and fi < si and not b:isOver(), types(events))
end

do
  local cases = {
    { "Shield Dust", { foeAbility = BattleEngine.ABILITY_SHIELD_DUST } },
    { "Immunity", { foeAbility = BattleEngine.ABILITY_IMMUNITY } },
    { "a Poison type", { foeTypes = { Data.TYPE_NORMAL, Data.TYPE_POISON } } },
    { "a Steel type", { foeTypes = { Data.TYPE_STEEL, Data.TYPE_STEEL } } },
  }
  for _, case in ipairs(cases) do
    local b, events = use(MOVE_TWINEEDLE, { 0, 1, 0, 1, 0, 0 }, case[2])
    check("Twineedle vs " .. case[1] .. ": silent, no poison, 6 draws",
      b.foe.status == 0 and not find(events, "statusApplied") and not find(events, "statusPrevented")
        and b.rng.draws == 6 and find(events, "multiHit"), b.rng.draws)
  end
  local b = use(MOVE_TWINEEDLE, { 0, 1, 0, 1, 0, 0 }, { foeStatus = S.BURN })
  check("Twineedle vs a statused target: unchanged", b.foe.status == S.BURN)
end

do
  -- Miss: accuracy only, PP spent, no roll (BattleScript_PrintMoveMissed).
  local b = battle({ MISS }, { playerMove = MOVE_TWINEEDLE })
  b.player.statStages.accuracy = -6
  local events = {}
  b:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
  check("Twineedle miss: accuracy only, PP spent", find(events, "miss") and b.rng.draws == 1
    and b.player.moves[1].pp == 9 and not find(events, "damage"), b.rng.draws)
end

do
  -- No-effect exit (unreachable for Bug; synthetic Normal record vs Ghost):
  -- acc, crit, then the trailing % 100 (no random, no count).
  local b, events = use(MOVE_NORMAL_TWINEEDLE, { 0, 1, 0 }, { foeTypes = { Data.TYPE_GHOST, Data.TYPE_GHOST } })
  check("effect 77 no-effect: noEffect, no multiHit, 3 draws",
    find(events, "noEffect") and not find(events, "multiHit") and b.rng.draws == 3, b.rng.draws)
end

do
  -- Poisoned by Twineedle: ticks at end of turn after the foe's move.
  local b = battle({ 0, 1, 0, 1, 0, 0, MISS }, { playerMove = MOVE_TWINEEDLE })
  local events = b:runTurn(MOVE, MOVE)
  local sd = find(events, "statusDamage", "foe")
  check("Twineedle poison ticks at end of turn", sd and sd.kind == "poison", types(events))
end

do
  -- Intentionally changed by the multi-hit tail follow-up (this asserted
  -- L1's "Double Kick keeps the older shape": in-loop faint, no multiHit,
  -- 3 draws). Double Kick now shares Twineedle's source tail
  -- (data/battle_scripts_1.s:613-655): the KO breaks the loop, "Hit 1
  -- time(s)!" follows, MultiHitEnd draws its `% 100` (:651; bsc.c:2789),
  -- and the faint is the caller's tryfaintmon (:653). Full coverage of 29/44
  -- is in tests/battle_multihit_tail_test.lua.
  local b = battle({ 0, 1, 0, 99 }, { playerMove = Data.MOVE_DOUBLE_KICK, foeCurrentHP = 1 })
  local events = {}
  b:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
  local mh = find(events, "multiHit", "player")
  check("Double Kick KO now uses the source tail (multiHit hits=1, no in-loop faint, 4 draws)",
    mh and mh.hits == 1 and not find(events, "faint") and b.rng.draws == 4, types(events))
end

---------------------------------------------------------------------------
-- Controller text order through the real engine
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

do
  local all = messages({ 0, 1, 0, 0 }, { playerMove = MOVE_TWINEEDLE, foeCurrentHP = 1 })
  local hit = all:find("Hit 1 time(s)!", 1, true)
  local fainted = all:find("fainted", 1, true)
  check("controller: Twineedle KO prints Hit 1 time(s)! before the faint", hit and fainted and hit < fainted, all)
  all = messages({ 0, 1, 0, 1, 0, 0, MISS }, { playerMove = MOVE_TWINEEDLE })
  hit = all:find("Hit 2 time(s)!", 1, true)
  local poisoned = all:find("poisoned", 1, true)
  check("controller: Twineedle prints the count, then the poison", hit and poisoned and hit < poisoned, all)
  -- Multi-hit tail follow-up (L1 review F1): Twineedle against a Grass
  -- target prints the effectiveness line ONCE, from MultiHitPrintStrings'
  -- resultmessage, just before the count (bs1.s:644-649); L1 printed it
  -- after each hit.
  all = messages({ 0, 1, 0, 1, 0, 99, MISS }, { playerMove = MOVE_TWINEEDLE,
    foeTypes = { Data.TYPE_GRASS, Data.TYPE_GRASS } })
  local _, superCount = all:gsub("It's super effective!", "")
  local super = all:find("It's super effective!", 1, true)
  hit = all:find("Hit 2 time(s)!", 1, true)
  check("controller: Twineedle vs Grass prints the effectiveness text once, just before the count",
    superCount == 1 and super and hit and super < hit
      and all:sub(super, hit - 1) == "It's super effective!|", all)
  all = messages({ 0, 1, 0, 0, 2, MISS, MISS }, { playerMove = MOVE_TRI_ATTACK })
  check("controller: Tri Attack paralysis text", all:find("paralyzed", 1, true) ~= nil, all)
  all = messages({ 0, 1, 0, 0, 1, MISS }, { playerMove = MOVE_TRI_ATTACK })
  check("controller: Tri Attack freeze text", all:find("frozen", 1, true) ~= nil, all)
  all = messages({ 0, 1, 0, 10, MISS }, { playerMove = MOVE_BLAZE_KICK })
  check("controller: Blaze Kick burn text", all:find("burned", 1, true) ~= nil, all)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
