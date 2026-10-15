-- Run: lua5.1 tests/battle_status_engine_test.lua
--
-- Status slice S1 (primary status1 conditions) through the real engine:
-- move-time cancellers and their RNG, burn/paralysis modifiers, Fire
-- defrost, end-of-turn damage and its faint handling, and faint clearing
-- status. Oracles from pret/pokefirered c75f352 (see
-- work/reports/phase4-status-conditions-design-proposal.md).
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

local MOVE_FLAME_WHEEL, MOVE_SNORE = 172, 173
local moves = {}
for id, m in pairs(Data.moves) do moves[id] = m end
-- src/data/battle_moves.h at the pin.
moves[MOVE_FLAME_WHEEL] = { effect = 125, power = 60, type = Data.TYPE_FIRE, accuracy = 100, pp = 25,
  secondaryEffectChance = 10, target = 0, priority = 0, flags = 0x13 }
moves[MOVE_SNORE] = { effect = 92, power = 40, type = Data.TYPE_NORMAL, accuracy = 100, pp = 15,
  secondaryEffectChance = 30, target = 0, priority = 0, flags = 0x12 }

local function stats(hp, speed)
  return { hp = hp, attack = 20, defense = 20, speed = speed, spAttack = 20, spDefense = 20 }
end

-- Player is faster (20 vs 10) unless a test overrides it.
local function battle(values, opts)
  opts = opts or {}
  local engine = BattleEngine.new({
    player = BattleEngine.makeBattler({ species = 1, level = 10,
      stats = stats(opts.playerHP or 40, opts.playerSpeed or 20),
      types = opts.playerTypes or { Data.TYPE_NORMAL, Data.TYPE_NORMAL },
      status = opts.playerStatus,
      moves = { { move = opts.playerMove or Data.MOVE_TACKLE, pp = 10 } } }),
    foe = BattleEngine.makeBattler({ species = 4, level = 10,
      stats = stats(opts.foeHP or 40, opts.foeSpeed or 10),
      types = opts.foeTypes or { Data.TYPE_NORMAL, Data.TYPE_NORMAL },
      status = opts.foeStatus,
      moves = { { move = opts.foeMove or Data.MOVE_TACKLE, pp = 10 } } }),
    moves = moves, typeChart = Data.typeChart, rng = scriptedRng(values),
    hasReplacement = opts.hasReplacement,
  })
  if opts.playerCurrentHP then engine.player.hp = opts.playerCurrentHP end
  if opts.foeCurrentHP then engine.foe.hp = opts.foeCurrentHP end
  return engine
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

-- A miss keeps HP unchanged so canceller tests read cleanly: accuracy draw
-- 99 misses a 95-accuracy Tackle.
local MISS = 99

---------------------------------------------------------------------------
-- Sleep (CANCELLER_ASLEEP, battle_util.c:1266-1308)
---------------------------------------------------------------------------
do
  local b = battle({ MISS }, { playerStatus = 2 })
  local events = b:runTurn(MOVE, MOVE)
  check("sleep 2: decrements to 1 and the move is not used",
    find(events, "fastAsleep", "player") and not find(events, "useMove", "player"), types(events))
  check("sleep 2: no PP spent while fast asleep", b.player.moves[1].pp == 10)
  check("sleep 2: counter now 1", b.player.status == 1, b.player.status)
  check("sleep canceller draws no RNG (only the foe's miss draw)", b.rng.draws == 1, b.rng.draws)
  local foeUse = select(2, find(events, "useMove", "foe"))
  local asleep = select(2, find(events, "fastAsleep", "player"))
  check("faster sleeper's canceller comes before the foe's move", asleep < foeUse)

  events = b:runTurn(MOVE, MOVE)
  local woke, wi = find(events, "wokeUp", "player")
  local used, ui = find(events, "useMove", "player")
  check("sleep 1: wakes and acts the same turn", woke and used and wi < ui, types(events))
  check("waking clears sleep", b.player.status == 0, b.player.status)
  check("waking turn spends PP", b.player.moves[1].pp == 9)
end

do
  local b = battle({ MISS, MISS }, { playerStatus = 1 })
  local events = b:runTurn(MOVE, MOVE)
  check("sleep counter 1 wakes and the move proceeds",
    find(events, "wokeUp") and find(events, "useMove", "player") and not find(events, "fastAsleep"),
    types(events))
end

do
  local b = battle({ MISS, MISS }, { playerStatus = 3, playerMove = MOVE_SNORE })
  local events = b:runTurn(MOVE, MOVE)
  local asleep, ai = find(events, "fastAsleep", "player")
  local used, ui = find(events, "useMove", "player")
  check("Snore is used while asleep, after its own fast-asleep text (bs1 :1253-1266)",
    asleep and used and ai < ui, types(events))
  check("Snore still decrements sleep", b.player.status == 2, b.player.status)
end

do
  -- Sleeping foe under auto-Struggle still runs the canceller.
  local b = battle({ MISS }, { foeStatus = 3 })
  b.foe.moves[1].pp = 0
  local events = b:runTurn(MOVE, MOVE)
  check("auto-Struggle user that is asleep is still cancelled",
    find(events, "fastAsleep", "foe") and not find(events, "useMove", "foe"), types(events))
end

---------------------------------------------------------------------------
-- Freeze (CANCELLER_FROZEN :1310-1333, CANCELLER_THAW :1513-1525)
---------------------------------------------------------------------------
do
  -- Draw 1: 1 % 5 ~= 0 stays frozen. Then the foe's miss draw.
  local b = battle({ 1, MISS }, { playerStatus = S.FREEZE })
  local events = b:runTurn(MOVE, MOVE)
  check("frozen: Random() % 5 nonzero keeps it frozen and cancels the move",
    find(events, "frozenSolid", "player") and not find(events, "useMove", "player"), types(events))
  check("frozen: no PP spent", b.player.moves[1].pp == 10)
  check("frozen: one draw for the freeze check", b.rng.draws == 2, b.rng.draws)
  check("frozen: still frozen", S.isFrozen(b.player.status))
end

do
  -- Draw 5: 5 % 5 == 0 thaws and acts; then the player's miss, then foe's.
  local b = battle({ 5, MISS, MISS }, { playerStatus = S.FREEZE })
  local events = b:runTurn(MOVE, MOVE)
  local thawed, ti = find(events, "thawed", "player")
  local used, ui = find(events, "useMove", "player")
  check("frozen: Random() % 5 == 0 thaws and the move proceeds", thawed and used and ti < ui, types(events))
  check("thaw clears freeze", b.player.status == 0, b.player.status)
  check("thaw path draws freeze + move + foe", b.rng.draws == 3, b.rng.draws)
end

do
  -- Thaw-hit user: the % 5 draw is still consumed; nonzero falls through
  -- to CANCELLER_THAW, which thaws with the "defrosted by" message.
  local b = battle({ 1, MISS, MISS }, { playerStatus = S.FREEZE, playerMove = MOVE_FLAME_WHEEL })
  local events = b:runTurn(MOVE, MOVE)
  local d, di = find(events, "defrostedByMove", "player")
  local used, ui = find(events, "useMove", "player")
  check("thaw-hit move thaws its frozen user before use", d and used and di < ui, types(events))
  check("thaw-hit event names the move", d and d.move == MOVE_FLAME_WHEEL)
  check("thaw-hit clears freeze", b.player.status == 0)
  check("thaw-hit with draw nonzero does not emit thawed/frozenSolid",
    not find(events, "thawed") and not find(events, "frozenSolid"))
end

do
  local b = battle({ 0, MISS, MISS }, { playerStatus = S.FREEZE, playerMove = MOVE_FLAME_WHEEL })
  local events = b:runTurn(MOVE, MOVE)
  check("thaw-hit with draw 0 uses the ordinary canceller thaw text",
    find(events, "thawed") and not find(events, "defrostedByMove"), types(events))
end

---------------------------------------------------------------------------
-- Paralysis (CANCELLER_PARALYSED :1439-1449, speed battle_main.c:3449)
---------------------------------------------------------------------------
do
  -- Paralyzed player speed 40 -> 10 == foe 10: a speed tie draw first.
  -- Tie draw 0 -> player first; paralysis draw 4 -> fully paralyzed.
  -- Weather W0: ENDTURN_ORDER re-runs GetWhoStrikesFirst(FALSE) on the
  -- same tie (src/battle_util.c:484-501, src/battle_main.c:3523), so a
  -- fourth draw (`Random() & 1`, 0 -> player first) follows the foe's miss.
  local b = battle({ 0, 4, MISS, 0 }, { playerStatus = S.PARALYSIS, playerSpeed = 40 })
  local events = b:runTurn(MOVE, MOVE)
  check("paralysis /4 creates a speed tie that consumes the tie draw (turn start and end of turn)",
    b.rng.draws == 4 and select(2, find(events, "fullyParalyzed", "player")) < select(2, find(events, "useMove", "foe")),
    types(events))
  check("Random() % 4 == 0 fully paralyzes without PP", find(events, "fullyParalyzed", "player")
    and not find(events, "useMove", "player") and b.player.moves[1].pp == 10)
  check("paralysis persists", S.isParalyzed(b.player.status))
end

do
  -- Paralyzed player speed 20 -> 5 < foe 10: foe moves first, no tie draw.
  local b = battle({ MISS, 1, MISS }, { playerStatus = S.PARALYSIS })
  local events = b:runTurn(MOVE, MOVE)
  local foeUse = select(2, find(events, "useMove", "foe"))
  local playerUse = select(2, find(events, "useMove", "player"))
  check("paralyzed faster battler now moves second", foeUse and playerUse and foeUse < playerUse, types(events))
  check("paralysis draw 1 lets the move proceed", playerUse ~= nil and not find(events, "fullyParalyzed"))
end

do
  -- Healthy equal speeds tie; paralysis on one side removes the tie draw.
  local b = battle({ MISS, 1, MISS }, { playerSpeed = 10, foeStatus = S.PARALYSIS })
  b:runTurn(MOVE, MOVE)
  check("paralysis removes a speed tie (no tie draw)", b.rng.draws == 3, b.rng.draws)
  local slow = BattleEngine.makeBattler({ species = 1, level = 10, stats = stats(40, 23),
    types = { 0, 0 }, status = S.PARALYSIS })
  check("effectiveSpeed floors after /4", BattleFormulas.effectiveSpeed(slow) == 5)
  slow.statStages.speed = 8
  check("paralysis /4 applies after the stat stage", BattleFormulas.effectiveSpeed(slow) == 11,
    BattleFormulas.effectiveSpeed(slow))
end

do
  -- Run odds use raw speed: a paralyzed player at 20 vs foe 10 still
  -- escapes without a draw.
  local b = battle({}, { playerStatus = S.PARALYSIS })
  local events = b:runTurn({ action = "run" }, MOVE)
  check("run odds ignore paralysis", find(events, "run").success and b.rng.draws == 0)
end

---------------------------------------------------------------------------
-- Burn (pokemon.c:2539-2541)
---------------------------------------------------------------------------
do
  local atk = BattleEngine.makeBattler({ species = 1, level = 50, stats = stats(100, 10), types = { 0, 0 } })
  atk.attack = 100
  local def = BattleEngine.makeBattler({ species = 1, level = 50, stats = stats(100, 10), types = { 0, 0 } })
  def.defense = 50
  local tackle = moves[Data.MOVE_TACKLE]
  local normal = BattleFormulas.calculateBaseDamage(atk, def, tackle, false, nil)
  atk.status = S.BURN
  local burned = BattleFormulas.calculateBaseDamage(atk, def, tackle, false, nil)
  -- 100*35*22/50/50 = 30; burn /2 = 15; +2 = 32 / 17.
  check("burn halves physical damage after /50 and before +2", normal == 32 and burned == 17,
    normal .. "/" .. burned)
  local crit = BattleFormulas.calculateBaseDamage(atk, def, tackle, true, nil)
  check("burn halving has no crit gate", crit == 17, crit)
  local reflected = BattleFormulas.calculateBaseDamage(atk, def, tackle, false, { reflect = true })
  check("burn then Reflect: 30 -> 15 -> 7, +2", reflected == 9, reflected)
  atk.ability = BattleFormulas.ABILITY_GUTS
  -- Guts: no burn halving and attack x150/100 while statused (pokemon.c
  -- :2488): 150*35*22/50/50 = 46, +2.
  check("Guts is exempt from burn halving and boosts attack while statused",
    BattleFormulas.calculateBaseDamage(atk, def, tackle, false, nil) == 48)
  atk.ability = 0
  local ember = moves[Data.MOVE_EMBER]
  local specialBurned = BattleFormulas.calculateBaseDamage(atk, def, ember, false, nil)
  atk.status = 0
  check("burn does not affect special damage",
    specialBurned == BattleFormulas.calculateBaseDamage(atk, def, ember, false, nil))
  atk.status = S.BURN
  atk.attack = 1
  def.defense = 400
  check("burned minimum damage still clamps to 1 then +2",
    BattleFormulas.calculateBaseDamage(atk, def, tackle, false, nil) == 3)
end

---------------------------------------------------------------------------
-- Ability stat and accuracy terms (pokemon.c:2437-2491; bsc.c:1069-1074)
---------------------------------------------------------------------------
do
  local function mk(ability, status)
    local b = BattleEngine.makeBattler({ species = 1, level = 50, stats = stats(100, 10), types = { 0, 0 } })
    b.attack, b.defense, b.spAttack, b.spDefense = 100, 50, 100, 50
    b.ability, b.status = ability, status or 0
    return b
  end
  local tackle, ember = moves[Data.MOVE_TACKLE], moves[Data.MOVE_EMBER]
  local base = BattleFormulas.calculateBaseDamage(mk(0), mk(0), tackle, false, nil)
  check("baseline physical damage is 32", base == 32, base)
  check("Guts without a status gives no boost",
    BattleFormulas.calculateBaseDamage(mk(BattleFormulas.ABILITY_GUTS), mk(0), tackle, false, nil) == 32)
  check("Guts with poison: attack 150 -> 48",
    BattleFormulas.calculateBaseDamage(mk(BattleFormulas.ABILITY_GUTS, S.POISON), mk(0), tackle, false, nil) == 48)
  check("Hustle: attack 150 -> 48",
    BattleFormulas.calculateBaseDamage(mk(BattleFormulas.ABILITY_HUSTLE), mk(0), tackle, false, nil) == 48)
  check("Huge Power: attack 200 -> 63",
    BattleFormulas.calculateBaseDamage(mk(BattleFormulas.ABILITY_HUGE_POWER), mk(0), tackle, false, nil) == 63)
  check("Pure Power matches Huge Power",
    BattleFormulas.calculateBaseDamage(mk(BattleFormulas.ABILITY_PURE_POWER), mk(0), tackle, false, nil) == 63)
  check("Marvel Scale with a status: defense 75 -> 22",
    BattleFormulas.calculateBaseDamage(mk(0), mk(BattleFormulas.ABILITY_MARVEL_SCALE, S.BURN), tackle, false, nil) == 22)
  check("Marvel Scale without a status gives no boost",
    BattleFormulas.calculateBaseDamage(mk(0), mk(BattleFormulas.ABILITY_MARVEL_SCALE), tackle, false, nil) == 32)
  local specialBase = BattleFormulas.calculateBaseDamage(mk(0), mk(0), ember, false, nil)
  check("Thick Fat halves spAttack against Fire", BattleFormulas.calculateBaseDamage(mk(0),
    mk(BattleFormulas.ABILITY_THICK_FAT), ember, false, nil) < specialBase)
  check("Thick Fat ignores a Normal move",
    BattleFormulas.calculateBaseDamage(mk(0), mk(BattleFormulas.ABILITY_THICK_FAT), tackle, false, nil) == 32)
  check("Hustle does not boost special attack",
    BattleFormulas.calculateBaseDamage(mk(BattleFormulas.ABILITY_HUSTLE), mk(0), ember, false, nil) == specialBase)

  -- Crit branches read the ability-adjusted stats (source uses the local
  -- attack/defense/spAttack after the ability terms).
  local hustle = mk(BattleFormulas.ABILITY_HUSTLE); hustle.statStages.attack = 5
  check("crit with a lowered attack stage uses the Hustle-adjusted attack",
    BattleFormulas.calculateBaseDamage(hustle, mk(0), tackle, true, nil) == 48)
  local marvel = mk(BattleFormulas.ABILITY_MARVEL_SCALE, S.BURN); marvel.statStages.defense = 7
  check("crit with a raised defense stage uses the Marvel Scale defense",
    BattleFormulas.calculateBaseDamage(mk(0), marvel, tackle, true, nil) == 22)
  local lowSp = mk(0); lowSp.statStages.spAttack = 5
  check("crit with a lowered spAttack stage uses the Thick Fat spAttack (Ember 37 -> 19)",
    BattleFormulas.calculateBaseDamage(lowSp, mk(BattleFormulas.ABILITY_THICK_FAT), ember, true, nil) == 19)
  check("Ember 37, and 19 against Thick Fat", specialBase == 37
    and BattleFormulas.calculateBaseDamage(mk(0), mk(BattleFormulas.ABILITY_THICK_FAT), ember, false, nil) == 19)
  local iceBeam = { effect = 5, power = 95, type = Data.TYPE_ICE, accuracy = 100, pp = 10,
    secondaryEffectChance = 10, target = 0, priority = 0, flags = 0x12 }
  check("Thick Fat halves spAttack against Ice (85 -> 43)",
    BattleFormulas.calculateBaseDamage(mk(0), mk(0), iceBeam, false, nil) == 85
      and BattleFormulas.calculateBaseDamage(mk(0), mk(BattleFormulas.ABILITY_THICK_FAT), iceBeam, false, nil) == 43)

  -- Explosion halves defense after Marvel Scale (pokemon.c:2505-2507):
  -- 51 -> 76 -> 38; 100*250*22/38/50 = 289, +2 = 291 (the reverse order
  -- would give 299).
  local explosion = { effect = 7, power = 250, type = Data.TYPE_NORMAL, accuracy = 100, pp = 5,
    secondaryEffectChance = 0, target = 8, priority = 0, flags = 0x32 }
  local scale = mk(BattleFormulas.ABILITY_MARVEL_SCALE, S.POISON); scale.defense = 51
  check("Explosion halves defense after Marvel Scale (291)",
    BattleFormulas.calculateBaseDamage(mk(0), scale, explosion, false, nil) == 291,
    BattleFormulas.calculateBaseDamage(mk(0), scale, explosion, false, nil))
  local plain = mk(0); plain.defense = 51
  check("Explosion alone halves defense (51 -> 25): 100*250*22/25/50 = 440, +2",
    BattleFormulas.calculateBaseDamage(mk(0), plain, explosion, false, nil) == 442)

  -- Pinch abilities (pokemon.c:2496-2503): matching type at hp <= maxHP/3.
  local blaze = mk(66); blaze.hp = 33
  check("Blaze at 33/100 HP: Ember power 60 -> 54", BattleFormulas.calculateBaseDamage(blaze, mk(0), ember, false, nil) == 54)
  blaze.hp = 34
  check("Blaze at 34/100 HP: no boost", BattleFormulas.calculateBaseDamage(blaze, mk(0), ember, false, nil) == 37)
  blaze.hp = 1
  check("Blaze does not boost a Normal move", BattleFormulas.calculateBaseDamage(blaze, mk(0), tackle, false, nil) == 32)
  local torrent = mk(67); torrent.hp = 10
  check("Torrent does not boost Fire", BattleFormulas.calculateBaseDamage(torrent, mk(0), ember, false, nil) == 37)
  local overgrow = mk(65); overgrow.hp = 10
  local vineWhip = { effect = 0, power = 35, type = Data.TYPE_GRASS, accuracy = 100, pp = 10,
    secondaryEffectChance = 0, target = 0, priority = 0, flags = 0x13 }
  check("Overgrow boosts a Grass move at low HP",
    BattleFormulas.calculateBaseDamage(overgrow, mk(0), vineWhip, false, nil)
      > BattleFormulas.calculateBaseDamage(mk(0), mk(0), vineWhip, false, nil))
  local swarm = mk(68); swarm.hp = 10
  local bugBite = { effect = 0, power = 35, type = Data.TYPE_BUG, accuracy = 100, pp = 10,
    secondaryEffectChance = 0, target = 0, priority = 0, flags = 0x13 }
  check("Swarm boosts a Bug move at low HP",
    BattleFormulas.calculateBaseDamage(swarm, mk(0), bugBite, false, nil)
      > BattleFormulas.calculateBaseDamage(mk(0), mk(0), bugBite, false, nil))
  local torrentHit = mk(67); torrentHit.hp = 10
  local waterGun = { effect = 0, power = 40, type = Data.TYPE_WATER, accuracy = 100, pp = 25,
    secondaryEffectChance = 0, target = 0, priority = 0, flags = 0x12 }
  check("Torrent boosts Water at low HP (37 -> 54)",
    BattleFormulas.calculateBaseDamage(torrentHit, mk(0), waterGun, false, nil) == 54)

  -- Accuracy: 75% move at neutral stages. Compound Eyes 75*130/100 = 97:
  -- draw 96 (roll 97) hits. Hustle on a physical move 75*80/100 = 60: draw
  -- 60 (roll 61) misses; a special move is unaffected.
  local function acc(a, ability, t) return BattleFormulas.accuracyCheck(75, 6, 6, scriptedRng({ a }), ability, t) end
  check("plain 75% misses on draw 75", not acc(75, 0, Data.TYPE_NORMAL) and acc(74, 0, Data.TYPE_NORMAL))
  check("Compound Eyes: 75 -> 97", acc(96, BattleFormulas.ABILITY_COMPOUND_EYES, Data.TYPE_GRASS)
    and not acc(97, BattleFormulas.ABILITY_COMPOUND_EYES, Data.TYPE_GRASS))
  check("Hustle on a physical move: 75 -> 60", acc(59, BattleFormulas.ABILITY_HUSTLE, Data.TYPE_NORMAL)
    and not acc(60, BattleFormulas.ABILITY_HUSTLE, Data.TYPE_NORMAL))
  check("Hustle leaves a special move at 75", acc(74, BattleFormulas.ABILITY_HUSTLE, Data.TYPE_FIRE))
  -- Every engine accuracy site passes the attacker's ability and move type.
  -- Foe evasion +6 makes the ratio 33/100: a 100% move needs roll <= 33,
  -- Compound Eyes 42.
  local function ceBattle(values, move)
    local eb = battle(values, { playerMove = move, foeHP = 400 })
    eb.player.ability = BattleFormulas.ABILITY_COMPOUND_EYES
    eb.foe.statStages.evasion = 12
    return eb, eb:runTurn(MOVE, MOVE)
  end
  moves[7] = explosion
  local _, ev = ceBattle({ 1, 0, 40 }, 7)
  check("Explosion accuracy uses Compound Eyes (crit, random, then roll 41)",
    find(ev, "damage", "player") ~= nil and not find(ev, "miss"), types(ev))
  moves[500] = { effect = 0, power = 40, type = Data.TYPE_NORMAL, accuracy = 100, pp = 10,
    secondaryEffectChance = 0, target = 0, priority = 0, flags = 0x13 }
  _, ev = ceBattle({ 40, 1, 0, MISS }, 500)
  check("ordinary hit accuracy uses Compound Eyes", find(ev, "damage", "player") ~= nil, types(ev))
  moves[167] = { effect = 104, power = 10, type = 1, accuracy = 90, pp = 10,
    secondaryEffectChance = 0, target = 0, priority = 0, flags = 0x33 } -- Triple Kick
  -- 90% at evasion +6: 90*33/100 = 29, Compound Eyes 37: roll 31 hits.
  _, ev = ceBattle({ 30, 1, 0, 99, MISS }, 167)
  check("Triple Kick per-kick accuracy uses Compound Eyes", find(ev, "damage", "player") ~= nil, types(ev))
  local hb = battle({ 80, MISS }, { playerMove = Data.MOVE_TACKLE, foeHP = 400 })
  hb.player.ability = BattleFormulas.ABILITY_HUSTLE
  ev = hb:runTurn(MOVE, MOVE)
  check("ordinary hit passes the move type for Hustle (Tackle 95 -> 76 misses roll 81)",
    find(ev, "miss", "player") ~= nil, types(ev))
  moves[7], moves[500], moves[167] = nil, nil, nil

  -- Through the engine: a Compound Eyes Hypnosis (60%) hits on draw 77.
  moves[95] = { effect = 1, power = 0, type = Data.TYPE_PSYCHIC, accuracy = 60, pp = 20,
    secondaryEffectChance = 0, target = 0, priority = 0, flags = 0x16 } -- Hypnosis
  local b = battle({ 77, 0, MISS }, { playerMove = 95 })
  b.player.ability = BattleFormulas.ABILITY_COMPOUND_EYES
  local events = b:runTurn(MOVE, MOVE)
  check("engine passes the attacker's ability to accuracy (Compound Eyes Hypnosis 60 -> 78)",
    find(events, "statusApplied", "foe") ~= nil, types(events))
end

---------------------------------------------------------------------------
-- Defrost by a Fire move (MOVEEND_DEFROST, bsc.c:4103-4116)
---------------------------------------------------------------------------
do
  -- Player Ember hits a frozen foe; the foe is defrosted at move end, so
  -- on its own turn it acts without a freeze check.
  local b = battle({ 0, 1, 0, 1, MISS }, { playerMove = Data.MOVE_EMBER, foeStatus = S.FREEZE, foeHP = 200 })
  local events = b:runTurn(MOVE, MOVE)
  local dmg, di = find(events, "damage", "player")
  local d, fi = find(events, "defrostedByFire", "foe")
  check("Fire damage to a frozen target defrosts it after the damage", dmg and d and di < fi, types(events))
  check("defrost clears freeze", b.foe.status == 0)
  check("defrosted foe acts normally (no freeze draw)", find(events, "useMove", "foe") ~= nil
    and not find(events, "frozenSolid"), types(events))
end

do
  local b = battle({ 0, 1, 0, 1, MISS }, { foeStatus = S.FREEZE, foeHP = 200 })
  local events = b:runTurn(MOVE, MOVE)
  check("a non-Fire hit does not defrost", not find(events, "defrostedByFire") and S.isFrozen(b.foe.status))
end

do
  local b = battle({ 99, 1, MISS }, { playerMove = Data.MOVE_EMBER, foeStatus = S.FREEZE })
  b.player.statStages.accuracy = 0
  local events = b:runTurn(MOVE, MOVE)
  check("a missed Fire move does not defrost", find(events, "miss", "player")
    and not find(events, "defrostedByFire") and S.isFrozen(b.foe.status), types(events))
end

do
  local b = battle({ 0, 1, 0 }, { playerMove = Data.MOVE_EMBER, foeStatus = S.FREEZE, foeCurrentHP = 1 })
  local events = b:runTurn(MOVE, MOVE)
  check("a Fire KO does not defrost (target at 0 HP) and faint clears status",
    find(events, "faint", "foe") and not find(events, "defrostedByFire") and b.foe.status == 0, types(events))
end

---------------------------------------------------------------------------
-- End of turn (DoBattlerEndTurnEffects :805-841)
---------------------------------------------------------------------------
do
  -- Both miss; player poisoned (40 -> 5), foe burned (7 HP max -> min 1).
  local b = battle({ MISS, MISS }, { playerStatus = S.POISON, foeStatus = S.BURN, foeHP = 7 })
  local events = b:runTurn(MOVE, MOVE)
  local p, pi = find(events, "statusDamage", "player")
  local f, fi = find(events, "statusDamage", "foe")
  check("poison deals maxHP/8", p and p.kind == "poison" and p.amount == 5 and b.player.hp == 35, types(events))
  check("burn deals max(1, maxHP/8)", f and f.kind == "burn" and f.amount == 1 and b.foe.hp == 6)
  check("end-of-turn runs in turn order (faster player first)", pi < fi)
  check("status damage comes after both moves", pi > select(2, find(events, "useMove", "foe")))
end

do
  -- Foe faster: the foe ticks first.
  local b = battle({ MISS, MISS }, { playerStatus = S.POISON, foeStatus = S.POISON, foeSpeed = 30 })
  local events = b:runTurn(MOVE, MOVE)
  check("end-of-turn order follows the move order",
    select(2, find(events, "statusDamage", "foe")) < select(2, find(events, "statusDamage", "player")))
end

do
  -- Toxic: max(1, maxHP/16) * n with n incremented first, capped at 15.
  local b = battle({ MISS, MISS, MISS, MISS, MISS, MISS },
    { playerStatus = S.TOXIC_POISON, playerHP = 32, foeHP = 400 })
  local seen = {}
  for turn = 1, 3 do
    local events = b:runTurn(MOVE, MOVE)
    seen[turn] = find(events, "statusDamage", "player")
  end
  check("toxic deals 2, 4, 6 on a 32 HP battler",
    seen[1].amount == 2 and seen[2].amount == 4 and seen[3].amount == 6 and seen[1].kind == "toxic"
      and b.player.hp == 20)
  check("toxic counter lives on the battle copy", S.toxicCounter(b.player.status) == 3)
  local b2 = battle({ MISS, MISS }, { playerStatus = S.withToxicCounter(S.TOXIC_POISON, 14), playerHP = 15 })
  local e1 = b2:runTurn(MOVE, MOVE)
  local t1 = find(e1, "statusDamage", "player")
  check("toxic minimum 1 is applied before multiplying (15 HP, n=15)",
    t1 and t1.amount == 15 and b2.player.hp == 0, t1 and t1.amount)
  check("toxic faint ends the battle", b2.outcome == "playerLost")
end

do
  local b = battle({ MISS, MISS }, { playerStatus = S.withToxicCounter(S.TOXIC_POISON, 15), playerHP = 320, foeHP = 400 })
  local events = b:runTurn(MOVE, MOVE)
  local t = find(events, "statusDamage", "player")
  check("toxic counter stays at 15 (20 * 15 = 300)", t.amount == 300 and S.toxicCounter(b.player.status) == 15, t.amount)
end

do
  -- Poison faint ends the battle and stops the phase: faster foe faints
  -- first, so the poisoned player does not tick.
  local b = battle({ MISS, MISS }, { foeStatus = S.POISON, foeCurrentHP = 1, playerStatus = S.POISON, foeSpeed = 30 })
  local events = b:runTurn(MOVE, MOVE)
  check("end-of-turn faint can end the battle", b.outcome == "playerWon" and find(events, "faint", "foe"), types(events))
  check("a battle-deciding faint stops the remaining ticks",
    count(events, "statusDamage") == 1 and b.player.hp == 40, types(events))
  check("end-of-turn faint clears the fainted battler's status", b.foe.status == 0)
  local _, fi = find(events, "faint", "foe")
  local _, ei = find(events, "battleEnd")
  check("faint then battleEnd follow the tick", fi < ei)
end

do
  -- With a replacement, the foe's faint only queues a forced switch and the
  -- player still ticks.
  local b = battle({ MISS, MISS }, { foeStatus = S.POISON, foeCurrentHP = 1, playerStatus = S.POISON, foeSpeed = 30,
    hasReplacement = function(side) return side == "foe" end })
  local events = b:runTurn(MOVE, MOVE)
  check("forced-switch faint lets the remaining battler tick",
    find(events, "forcedSwitchNeeded", "foe") and count(events, "statusDamage") == 2 and not b:isOver(), types(events))
  check("pending forced switch recorded", b.awaitingForcedSwitch == "foe")
end

do
  -- A move KO with a pending forced switch: the surviving attacker still
  -- ticks (early-return site), the fainted battler is skipped.
  local b = battle({ 0, 1, 0 }, { playerStatus = S.BURN, foeCurrentHP = 1,
    hasReplacement = function() return true end })
  local events = b:runTurn(MOVE, MOVE)
  check("move-KO turn with a pending switch still runs end-of-turn",
    find(events, "forcedSwitchNeeded", "foe") and find(events, "statusDamage", "player")
      and not find(events, "statusDamage", "foe"), types(events))
end

do
  -- Battle-ending move KO: no end-of-turn damage.
  local b = battle({ 0, 1, 0 }, { playerStatus = S.BURN, foeCurrentHP = 1 })
  local events = b:runTurn(MOVE, MOVE)
  check("a battle-ending turn skips end-of-turn", b.outcome == "playerWon" and not find(events, "statusDamage"))
end

do
  -- Hoisted actions: switch, failed run and failed capture still tick,
  -- after the screen timers. Order is the ENDTURN_ORDER recompute (weather
  -- W0; src/battle_util.c:484-501): here the incoming battler (20) is
  -- faster than the foe (10), so it ticks first. The foe-faster and
  -- priority cases are in tests/battle_end_turn_order_test.lua.
  local b = battle({ MISS }, { playerStatus = S.POISON, foeStatus = S.POISON })
  local incoming = BattleEngine.makeBattler({ species = 1, level = 10, stats = stats(40, 20),
    types = { 0, 0 }, status = S.BURN, moves = { { move = Data.MOVE_TACKLE, pp = 10 } } })
  b.sideStatus.player.reflect, b.sideStatus.player.reflectTimer = true, 1
  local events = b:runTurn({ action = "switch", battler = incoming }, MOVE)
  local p, pi = find(events, "statusDamage", "player")
  local _, fi = find(events, "statusDamage", "foe")
  local _, si = find(events, "screenExpired")
  check("switch turn ticks the incoming battler's own status first", p and p.kind == "burn" and pi < fi, types(events))
  check("field (screen) end-turn effects come before battler effects", si < pi)

  local slow = battle({ 65535, MISS }, { playerSpeed = 5, playerStatus = S.POISON })
  events = slow:runTurn({ action = "run" }, MOVE)
  check("failed run turn still ticks", not find(events, "run").success and find(events, "statusDamage", "player"),
    types(events))
end

---------------------------------------------------------------------------
-- Review-driven coverage (work/reviews/2026-10-14-status-s1-review.md)
---------------------------------------------------------------------------
do
  -- Draw 2: 2 % 4 ~= 0 (a %2 check would wrongly paralyze).
  local b = battle({ MISS, 2, MISS }, { playerStatus = S.PARALYSIS })
  local events = b:runTurn(MOVE, MOVE)
  check("paralysis draw 2 does not fully paralyze", not find(events, "fullyParalyzed")
    and find(events, "useMove", "player"), types(events))
end

do
  -- Failed capture turn still ticks (hoisted site).
  local values = {}
  for i = 1, 12 do values[i] = 65535 end
  local b = battle(values, { playerStatus = S.POISON, foeHP = 400 })
  b.foe.catchRate = 3
  local events = b:runTurn({ action = "capture" }, MOVE)
  check("failed capture turn still ticks", find(events, "capture") and not find(events, "capture").success
    and find(events, "statusDamage", "player"), types(events))
end

do
  -- Attacker-faint early return (recoil KO with a replacement) still runs
  -- the end-of-turn phase for the other battler.
  local b = battle({ 0, 1, 0 }, { playerMove = Data.MOVE_DOUBLE_EDGE, playerCurrentHP = 1,
    foeHP = 400, foeStatus = S.POISON, hasReplacement = function(side) return side == "player" end })
  local events = b:runTurn(MOVE, MOVE)
  check("recoil self-KO with a pending switch still ticks the foe",
    find(events, "forcedSwitchNeeded", "player") and find(events, "statusDamage", "foe")
      and not find(events, "useMove", "foe"), types(events))
end

do
  -- 0-HP battlers are skipped even if a status word were present.
  local b = battle({}, { foeStatus = S.POISON })
  b.foe.hp = 0
  local events = {}
  b:resolveStatusEndTurn(events, { "player", "foe" })
  check("end-of-turn skips a battler at 0 HP", #events == 0, types(events))
end

do
  -- F1: a battle-deciding end-of-turn faint clears a forced switch queued
  -- earlier in the turn. Player (last Pokemon, poisoned, 1 HP) KOs a foe
  -- that has a replacement, then faints to poison.
  local b = battle({ 0, 1, 0 }, { playerStatus = S.POISON, playerCurrentHP = 1, foeCurrentHP = 1,
    hasReplacement = function(side) return side == "foe" end })
  local events = b:runTurn(MOVE, MOVE)
  check("player loss by poison after a foe KO ends the battle", b.outcome == "playerLost", types(events))
  check("decided battle leaves no forced switch pending",
    b.awaitingForcedSwitch == nil and #b.pendingForcedSwitches == 0, tostring(b.awaitingForcedSwitch))
end

do
  -- F2: separate faint sequences queue the player's switch first.
  local b = battle({ 0, 1, 0 }, { playerStatus = S.POISON, playerCurrentHP = 1, foeCurrentHP = 1,
    hasReplacement = function() return true end })
  local events = b:runTurn(MOVE, MOVE)
  check("move KO then poison KO queue both switches",
    count(events, "forcedSwitchNeeded") == 2 and not b:isOver(), types(events))
  check("player's forced switch comes first (battler id order)",
    b.pendingForcedSwitches[1] == "player" and b.pendingForcedSwitches[2] == "foe"
      and b.awaitingForcedSwitch == "player")
  local replacement = BattleEngine.makeBattler({ species = 1, level = 10, stats = stats(40, 20),
    types = { 0, 0 }, moves = { { move = Data.MOVE_TACKLE, pp = 10 } } })
  b:resolveForcedSwitch("player", replacement)
  check("foe switch follows the player's", b.awaitingForcedSwitch == "foe")
end

---------------------------------------------------------------------------
-- Slice S2: status on hit (seteffectwithchance -> SetMoveEffect)
---------------------------------------------------------------------------
-- src/data/battle_moves.h records at the pin.
local MOVE_POISON_STING, MOVE_THUNDER_SHOCK, MOVE_ICE_BEAM = 40, 84, 58
local MOVE_ZAP_CANNON, MOVE_POISON_FANG, MOVE_POISON_TAIL = 192, 305, 342
local PF = 0x13 -- contact/protect/mirror flags; not read by the engine
moves[MOVE_POISON_STING] = { effect = 2, power = 15, type = Data.TYPE_POISON, accuracy = 100, pp = 35,
  secondaryEffectChance = 30, target = 0, priority = 0, flags = PF }
moves[MOVE_THUNDER_SHOCK] = { effect = 6, power = 40, type = Data.TYPE_ELECTRIC, accuracy = 100, pp = 30,
  secondaryEffectChance = 10, target = 0, priority = 0, flags = PF }
moves[MOVE_ICE_BEAM] = { effect = 5, power = 95, type = Data.TYPE_ICE, accuracy = 100, pp = 10,
  secondaryEffectChance = 10, target = 0, priority = 0, flags = PF }
moves[MOVE_ZAP_CANNON] = { effect = 6, power = 100, type = Data.TYPE_ELECTRIC, accuracy = 50, pp = 5,
  secondaryEffectChance = 100, target = 0, priority = 0, flags = PF }
moves[MOVE_POISON_FANG] = { effect = 202, power = 50, type = Data.TYPE_POISON, accuracy = 100, pp = 15,
  secondaryEffectChance = 30, target = 0, priority = 0, flags = PF }
moves[MOVE_POISON_TAIL] = { effect = 209, power = 50, type = Data.TYPE_POISON, accuracy = 100, pp = 25,
  secondaryEffectChance = 10, target = 0, priority = 0, flags = PF }

-- One player hit, then the foe misses: acc 0, crit 1, random 0, effect roll.
local function hitWith(move, roll, opts)
  opts = opts or {}
  opts.playerMove = move
  opts.foeHP = opts.foeHP or 400
  local b = battle({ 0, 1, 0, roll, MISS }, opts)
  if opts.foeAbility then b.foe.ability = opts.foeAbility end
  local events = b:runTurn(MOVE, MOVE)
  return b, events
end

do
  local b, events = hitWith(Data.MOVE_EMBER, 10)
  local dmg, di = find(events, "damage", "player")
  local st, si = find(events, "statusApplied", "foe")
  check("Ember roll 10 <= 10 burns after the damage", st and st.kind == "burn" and di < si, types(events))
  check("burn is set on the target", S.isBurned(b.foe.status))
  check("newly burned foe ticks at end of turn", find(events, "statusDamage", "foe")
    and find(events, "statusDamage", "foe").kind == "burn")
  check("effect roll is one draw between damage and the foe's move", b.rng.draws == 5, b.rng.draws)
  b, events = hitWith(Data.MOVE_EMBER, 11)
  check("Ember roll 11 does not burn", not find(events, "statusApplied") and b.foe.status == 0)
end

do
  local b, events = hitWith(Data.MOVE_EMBER, 0, { foeTypes = { Data.TYPE_FIRE, Data.TYPE_FIRE } })
  check("Fire-type target is silently immune to burn", not find(events, "statusApplied")
    and not find(events, "statusPrevented") and b.foe.status == 0)
  check("immune target still consumes the roll", b.rng.draws == 5, b.rng.draws)
  b, events = hitWith(Data.MOVE_EMBER, 0, { foeStatus = S.PARALYSIS })
  check("already-statused target is silently unchanged", not find(events, "statusApplied")
    and b.foe.status == S.PARALYSIS)
end

do
  local b, events = hitWith(Data.MOVE_EMBER, 0, { foeCurrentHP = 1 })
  check("a KO hit applies no status (target at 0 HP)", find(events, "faint", "foe")
    and not find(events, "statusApplied") and b.foe.status == 0, types(events))
  check("the KO hit still consumed its roll", b.rng.draws == 4, b.rng.draws)
end

do
  -- Thunder Shock vs Ground: noEffect still draws the effect roll; the
  -- foe's miss is draw 5.
  local b, events = hitWith(MOVE_THUNDER_SHOCK, 0, { foeTypes = { Data.TYPE_GROUND, Data.TYPE_GROUND } })
  check("no-effect hit consumes the effect roll", find(events, "noEffect") and b.rng.draws == 5
    and b.foe.status == 0, b.rng.draws)
  b, events = hitWith(MOVE_THUNDER_SHOCK, 0, { foeTypes = { Data.TYPE_ELECTRIC, Data.TYPE_ELECTRIC } })
  check("Electric type is paralyzed by Thunder Shock (Gen 3)", find(events, "statusApplied")
    and S.isParalyzed(b.foe.status))
end

do
  local b, events = hitWith(MOVE_POISON_STING, 0)
  check("Poison Sting poisons", find(events, "statusApplied").kind == "poison" and S.isPoisoned(b.foe.status))
  b, events = hitWith(MOVE_POISON_STING, 0, { foeTypes = { Data.TYPE_STEEL, Data.TYPE_STEEL } })
  check("Steel target: Poison Sting has no effect and no status", b.foe.status == 0)
  b, events = hitWith(MOVE_POISON_STING, 0, { foeTypes = { Data.TYPE_NORMAL, Data.TYPE_POISON } })
  check("Poison target is immune to poison", b.foe.status == 0 and not find(events, "statusApplied"))
end

do
  local b, events = hitWith(MOVE_POISON_FANG, 30)
  check("Poison Fang badly poisons with counter then ticking 1", find(events, "statusApplied").kind == "toxic"
    and S.isBadlyPoisoned(b.foe.status) and S.toxicCounter(b.foe.status) == 1
    and find(events, "statusDamage", "foe").amount == math.max(1, math.floor(400 / 16)), types(events))
  b, events = hitWith(MOVE_POISON_FANG, 31)
  check("Poison Fang roll 31 misses its 30% chance", b.foe.status == 0)
end

do
  -- Poison Tail adds one crit stage: draw 8 (8 % 8 == 0) crits, while the
  -- same draw does not crit an ordinary hit (8 % 16 ~= 0).
  local b = battle({ 0, 8, 0, 99, MISS }, { playerMove = MOVE_POISON_TAIL, foeHP = 400 })
  local events = b:runTurn(MOVE, MOVE)
  check("Poison Tail uses crit stage 1", find(events, "critical", "player") ~= nil, types(events))
  b = battle({ 0, 8, 0, 99, MISS }, { playerMove = MOVE_POISON_STING, foeHP = 400 })
  events = b:runTurn(MOVE, MOVE)
  check("Poison Sting stays at crit stage 0", not find(events, "critical"), types(events))
  b, events = hitWith(MOVE_POISON_TAIL, 10)
  check("Poison Tail poisons on its 10% roll", find(events, "statusApplied").kind == "poison")
end

do
  local b, events = hitWith(MOVE_ICE_BEAM, 0)
  check("Ice Beam freezes", find(events, "statusApplied").kind == "freeze" and S.isFrozen(b.foe.status))
  b, events = hitWith(MOVE_ICE_BEAM, 0, { foeTypes = { Data.TYPE_ICE, Data.TYPE_ICE } })
  check("Ice type cannot be frozen", b.foe.status == 0)
  b, events = hitWith(MOVE_ICE_BEAM, 0, { foeAbility = BattleEngine.ABILITY_MAGMA_ARMOR })
  check("Magma Armor silently prevents freezing", b.foe.status == 0 and not find(events, "statusPrevented"))
  -- The frozen foe then takes a Fire hit: no burn (already statused), then
  -- the move-end defrost.
  b = battle({ 0, 1, 0, 0, MISS }, { playerMove = Data.MOVE_EMBER, foeStatus = S.FREEZE, foeHP = 400 })
  events = b:runTurn(MOVE, MOVE)
  check("Ember on a frozen foe: no burn, then defrost", not find(events, "statusApplied")
    and find(events, "defrostedByFire") and b.foe.status == 0, types(events))
end

do
  local b, events = hitWith(MOVE_POISON_STING, 0, { foeAbility = BattleEngine.ABILITY_SHIELD_DUST })
  check("Shield Dust blocks the secondary status", b.foe.status == 0 and not find(events, "statusPrevented"))
  b, events = hitWith(MOVE_POISON_STING, 0, { foeAbility = BattleEngine.ABILITY_IMMUNITY })
  check("Immunity silently blocks a non-certain poison", b.foe.status == 0 and not find(events, "statusPrevented"))
  b, events = hitWith(MOVE_POISON_FANG, 0, { foeAbility = BattleEngine.ABILITY_IMMUNITY })
  check("Immunity silently blocks Poison Fang's toxic", b.foe.status == 0 and not find(events, "statusPrevented"))
  b, events = hitWith(Data.MOVE_EMBER, 0, { foeAbility = BattleEngine.ABILITY_WATER_VEIL })
  check("Water Veil silently blocks a non-certain burn", b.foe.status == 0 and not find(events, "statusPrevented"))
  b, events = hitWith(MOVE_THUNDER_SHOCK, 0, { foeAbility = BattleEngine.ABILITY_LIMBER })
  check("Limber silently blocks a non-certain paralysis", b.foe.status == 0 and not find(events, "statusPrevented"))
end

do
  -- Zap Cannon (100%): the roll is still drawn (Random() % 100 <= 100),
  -- then SetMoveEffect runs with MOVE_EFFECT_CERTAIN.
  local b, events = hitWith(MOVE_ZAP_CANNON, 99)
  -- Draws: 4 for the hit, then the now-paralyzed foe's canceller draw
  -- (99 % 4 ~= 0), then its Tackle's three.
  check("Zap Cannon paralyzes on any roll", S.isParalyzed(b.foe.status) and b.rng.draws == 8, b.rng.draws)
  b, events = hitWith(MOVE_ZAP_CANNON, 99, { foeAbility = BattleEngine.ABILITY_LIMBER })
  local p = find(events, "statusPrevented", "foe")
  check("certain paralysis vs Limber reports the ability", p and p.kind == "paralysis"
    and p.ability == BattleEngine.ABILITY_LIMBER and b.foe.status == 0, types(events))
  b, events = hitWith(MOVE_ZAP_CANNON, 99, { foeAbility = BattleEngine.ABILITY_SHIELD_DUST })
  check("Shield Dust blocks even a certain secondary status", b.foe.status == 0
    and not find(events, "statusPrevented"))
end

do
  -- The engine's Poke Ball uses the foe's status: catch rate 45 at full HP
  -- gives catch value 15 (threshold 32767) healthy, 22 (threshold 36157)
  -- burned. Draw 34000 passes only the burned threshold.
  local b = battle({ 34000, 65535, MISS }, { foeStatus = S.BURN, foeHP = 400 })
  b.foe.catchRate = 45
  local events = b:runTurn({ action = "capture" }, MOVE)
  check("engine capture reads the foe's status (one shake only when burned)",
    find(events, "capture") and find(events, "capture").shakes == 1, types(events))
  b = battle({ 34000, MISS }, { foeHP = 400 })
  b.foe.catchRate = 45
  events = b:runTurn({ action = "capture" }, MOVE)
  check("the same draw fails at once against a healthy foe", find(events, "capture").shakes == 0)
end

---------------------------------------------------------------------------
-- Slice S3: primary status moves
---------------------------------------------------------------------------
local MOVE_SPORE, MOVE_HYPNOSIS, MOVE_POISON_POWDER, MOVE_THUNDER_WAVE = 147, 95, 77, 86
local MOVE_GLARE, MOVE_TOXIC, MOVE_WILL_O_WISP = 137, 92, 261
local SF = 0x16 -- protect/magic coat/mirror flags; not read by the engine
local function statusMove(effect, type_, accuracy, pp, chance)
  return { effect = effect, power = 0, type = type_, accuracy = accuracy, pp = pp,
    secondaryEffectChance = chance or 0, target = 0, priority = 0, flags = SF }
end
moves[MOVE_SPORE] = statusMove(1, Data.TYPE_GRASS, 100, 15)
moves[MOVE_HYPNOSIS] = statusMove(1, Data.TYPE_PSYCHIC, 60, 20)
moves[MOVE_POISON_POWDER] = statusMove(66, Data.TYPE_POISON, 75, 35)
moves[MOVE_THUNDER_WAVE] = statusMove(67, Data.TYPE_ELECTRIC, 100, 20)
moves[MOVE_GLARE] = statusMove(67, Data.TYPE_NORMAL, 75, 30)
moves[MOVE_TOXIC] = statusMove(33, Data.TYPE_POISON, 85, 10, 100)
moves[MOVE_WILL_O_WISP] = statusMove(167, Data.TYPE_FIRE, 75, 15)

-- Player uses a status move; the foe then misses (unless it is cancelled).
local function useStatus(move, values, opts)
  opts = opts or {}
  opts.playerMove = move
  local b = battle(values, opts)
  if opts.foeAbility then b.foe.ability = opts.foeAbility end
  local events = b:runTurn(MOVE, MOVE)
  return b, events
end

do
  check("primary status moves are admitted", BattleEngine.new and
    battle({}):supportsMove(moves[MOVE_SPORE], MOVE_SPORE)
    and battle({}):supportsMove(moves[MOVE_WILL_O_WISP], MOVE_WILL_O_WISP))
  local hit = {}
  for k, v in pairs(moves[MOVE_SPORE]) do hit[k] = v end
  hit.target = 0x10
  check("a self-targeted record is not admitted", not battle({}):supportsMove(hit, MOVE_SPORE))
end

do
  -- Spore: accuracy draw 0 hits, sleep draw 3 -> 5 turns; the sleeping foe
  -- is then fast asleep (counter 4) without drawing.
  local b, events = useStatus(MOVE_SPORE, { 0, 3 })
  local st, si = find(events, "statusApplied", "foe")
  check("Spore puts the target to sleep for (Random() & 3) + 2 turns",
    st and st.kind == "sleep" and S.sleepTurns(b.foe.status) == 4, types(events))
  check("Spore spends PP", b.player.moves[1].pp == 9)
  check("the slept foe is fast asleep the same turn", find(events, "fastAsleep", "foe")
    and select(2, find(events, "fastAsleep", "foe")) > si)
  check("Spore draws accuracy then duration only", b.rng.draws == 2, b.rng.draws)
end

do
  local b, events = useStatus(MOVE_SPORE, { MISS }, { foeStatus = 2 })
  check("already asleep: statusAlready, no accuracy draw", find(events, "statusAlready", "foe")
    and find(events, "statusAlready", "foe").kind == "sleep" and b.player.moves[1].pp == 9, types(events))
  b, events = useStatus(MOVE_SPORE, { MISS }, { foeAbility = BattleEngine.ABILITY_INSOMNIA })
  local w = find(events, "stayedAwake", "foe")
  check("Insomnia: stayed awake, no status", w and w.ability == BattleEngine.ABILITY_INSOMNIA
    and b.foe.status == 0, types(events))
  b, events = useStatus(MOVE_SPORE, { MISS }, { foeAbility = BattleEngine.ABILITY_INSOMNIA, foeStatus = 2 })
  check("already asleep precedes Insomnia", find(events, "statusAlready", "foe")
    and not find(events, "stayedAwake"), types(events))
  b, events = useStatus(MOVE_SPORE, { MISS }, { foeAbility = BattleEngine.ABILITY_VITAL_SPIRIT })
  check("Vital Spirit: stayed awake", find(events, "stayedAwake", "foe") ~= nil)
  b, events = useStatus(MOVE_SPORE, { MISS }, { foeStatus = S.BURN })
  check("other status: But it failed! (no accuracy draw; only the foe's)", find(events, "moveFailed", "player")
    and b.foe.status == S.BURN and b.rng.draws == 1, types(events))
  b, events = useStatus(MOVE_HYPNOSIS, { 60, MISS })
  check("Hypnosis misses on draw 60 (60% accuracy)", find(events, "miss", "player") and b.foe.status == 0
    and b.player.moves[1].pp == 9, types(events))
end

do
  local b, events = useStatus(MOVE_POISON_POWDER, { 0, MISS })
  check("Poison Powder poisons", find(events, "statusApplied", "foe").kind == "poison" and S.isPoisoned(b.foe.status))
  b, events = useStatus(MOVE_POISON_POWDER, { MISS }, { foeAbility = BattleEngine.ABILITY_IMMUNITY,
    foeTypes = { Data.TYPE_POISON, Data.TYPE_POISON }, foeStatus = S.POISON })
  check("poison checks Immunity first", find(events, "statusPrevented", "foe")
    and find(events, "statusPrevented", "foe").ability == BattleEngine.ABILITY_IMMUNITY, types(events))
  b, events = useStatus(MOVE_POISON_POWDER, { MISS }, { foeStatus = S.TOXIC_POISON,
    foeTypes = { Data.TYPE_STEEL, Data.TYPE_STEEL } })
  check("already badly poisoned counts as already poisoned (before type)",
    find(events, "statusAlready", "foe") and find(events, "statusAlready", "foe").kind == "poison", types(events))
  b, events = useStatus(MOVE_POISON_POWDER, { MISS }, { foeTypes = { Data.TYPE_STEEL, Data.TYPE_STEEL }, foeStatus = S.BURN })
  check("Steel type: It doesn't affect (before the any-status failure)", find(events, "noEffect")
    and not find(events, "moveFailed"), types(events))
  b, events = useStatus(MOVE_POISON_POWDER, { MISS }, { foeStatus = S.PARALYSIS })
  check("poison vs another status: But it failed!", find(events, "moveFailed"))
end

do
  local b, events = useStatus(MOVE_THUNDER_WAVE, { 0, 1, MISS })
  check("Thunder Wave paralyzes", S.isParalyzed(b.foe.status) and find(events, "statusApplied", "foe"), types(events))
  b, events = useStatus(MOVE_THUNDER_WAVE, { MISS }, { foeTypes = { Data.TYPE_GROUND, Data.TYPE_GROUND } })
  check("Thunder Wave vs Ground: It doesn't affect, no accuracy draw", find(events, "noEffect")
    and b.rng.draws == 1 and b.foe.status == 0, types(events))
  b, events = useStatus(MOVE_THUNDER_WAVE, { MISS }, { foeTypes = { Data.TYPE_GROUND, Data.TYPE_GROUND },
    foeStatus = S.PARALYSIS })
  check("typecalc immunity precedes already-paralyzed", find(events, "noEffect") and not find(events, "statusAlready"))
  b, events = useStatus(MOVE_GLARE, { MISS }, { foeTypes = { Data.TYPE_GHOST, Data.TYPE_GHOST } })
  check("Glare (Normal) vs Ghost: It doesn't affect", find(events, "noEffect") ~= nil)
  b, events = useStatus(MOVE_THUNDER_WAVE, { MISS }, { foeStatus = S.PARALYSIS })
  check("already paralyzed", find(events, "statusAlready", "foe").kind == "paralysis")
  b, events = useStatus(MOVE_THUNDER_WAVE, { MISS }, { foeAbility = BattleEngine.ABILITY_LIMBER,
    foeTypes = { Data.TYPE_GROUND, Data.TYPE_GROUND } })
  check("Limber precedes typecalc and always prints", find(events, "statusPrevented", "foe")
    and not find(events, "noEffect"), types(events))
  b, events = useStatus(MOVE_THUNDER_WAVE, { 0, 1, MISS }, { foeTypes = { Data.TYPE_ELECTRIC, Data.TYPE_ELECTRIC } })
  check("Electric type can be paralyzed by Thunder Wave", S.isParalyzed(b.foe.status))
end

do
  local b, events = useStatus(MOVE_TOXIC, { 84, MISS })
  check("Toxic hits on draw 84 (85%) and badly poisons", find(events, "statusApplied", "foe").kind == "toxic"
    and S.isBadlyPoisoned(b.foe.status), types(events))
  b, events = useStatus(MOVE_TOXIC, { 85, MISS })
  check("Toxic misses on draw 85", find(events, "miss", "player") and b.foe.status == 0)
  b, events = useStatus(MOVE_TOXIC, { MISS }, { foeTypes = { Data.TYPE_POISON, Data.TYPE_POISON }, foeStatus = S.BURN })
  check("Toxic: other status fails before the type check", find(events, "moveFailed")
    and not find(events, "noEffect"), types(events))
  b, events = useStatus(MOVE_TOXIC, { MISS }, { foeTypes = { Data.TYPE_POISON, Data.TYPE_POISON } })
  check("Toxic vs healthy Poison type: It doesn't affect", find(events, "noEffect") ~= nil)
  b, events = useStatus(MOVE_TOXIC, { MISS }, { foeStatus = S.POISON })
  check("Toxic vs poisoned: already poisoned", find(events, "statusAlready", "foe").kind == "toxic")
  b, events = useStatus(MOVE_TOXIC, { MISS }, { foeAbility = BattleEngine.ABILITY_IMMUNITY })
  check("Toxic vs Immunity: prevented", find(events, "statusPrevented", "foe") ~= nil)
  b, events = useStatus(MOVE_TOXIC, { MISS }, { foeAbility = BattleEngine.ABILITY_IMMUNITY, foeStatus = S.POISON })
  check("Toxic: Immunity precedes already poisoned", find(events, "statusPrevented", "foe")
    and not find(events, "statusAlready"), types(events))
end

do
  local b, events = useStatus(MOVE_WILL_O_WISP, { 0, MISS })
  check("Will-O-Wisp burns", S.isBurned(b.foe.status) and find(events, "statusApplied", "foe").kind == "burn")
  b, events = useStatus(MOVE_WILL_O_WISP, { MISS }, { foeStatus = S.BURN, foeTypes = { Data.TYPE_FIRE, Data.TYPE_FIRE } })
  check("already burned precedes Fire type", find(events, "statusAlready", "foe")
    and find(events, "statusAlready", "foe").kind == "burn")
  b, events = useStatus(MOVE_WILL_O_WISP, { MISS }, { foeTypes = { Data.TYPE_FIRE, Data.TYPE_FIRE },
    foeAbility = BattleEngine.ABILITY_WATER_VEIL })
  check("Fire type precedes Water Veil", find(events, "noEffect") and not find(events, "statusPrevented"))
  b, events = useStatus(MOVE_WILL_O_WISP, { MISS }, { foeAbility = BattleEngine.ABILITY_WATER_VEIL, foeStatus = S.POISON })
  check("Water Veil precedes the any-status failure", find(events, "statusPrevented", "foe")
    and not find(events, "moveFailed"), types(events))
end

do
  -- The foe AI can use a status move on the player, and the player then
  -- ticks/cancels through S1.
  local b = battle({ 0, MISS, 0 }, { foeMove = MOVE_POISON_POWDER, foeSpeed = 30 })
  local events = b:runTurn(MOVE, MOVE)
  check("foe Poison Powder poisons the player, who ticks at end of turn",
    S.isPoisoned(b.player.status) and find(events, "statusDamage", "player"), types(events))
end

---------------------------------------------------------------------------
-- Slice S4: thaw-hit burn, Facade, Smelling Salt, Refresh
---------------------------------------------------------------------------
local MOVE_FACADE, MOVE_SMELLINGSALT, MOVE_REFRESH, MOVE_SACRED_FIRE = 263, 265, 287, 221
moves[MOVE_FACADE] = { effect = 169, power = 70, type = Data.TYPE_NORMAL, accuracy = 100, pp = 20,
  secondaryEffectChance = 0, target = 0, priority = 0, flags = 0x13 }
moves[MOVE_SMELLINGSALT] = { effect = 171, power = 60, type = Data.TYPE_NORMAL, accuracy = 100, pp = 10,
  secondaryEffectChance = 0, target = 0, priority = 0, flags = 0x13 }
moves[MOVE_REFRESH] = { effect = 193, power = 0, type = Data.TYPE_NORMAL, accuracy = 100, pp = 20,
  secondaryEffectChance = 0, target = 0x10, priority = 0, flags = 0x08 }
moves[MOVE_SACRED_FIRE] = { effect = 125, power = 100, type = Data.TYPE_FIRE, accuracy = 95, pp = 5,
  secondaryEffectChance = 50, target = 0, priority = 0, flags = 0x12 }

local function damageOf(events, side)
  local e = find(events, "damage", side)
  return e and e.amount
end

do
  -- Thaw-hit moves carry a burn chance: Flame Wheel 10%, Sacred Fire 50%.
  local b, events = hitWith(MOVE_FLAME_WHEEL, 10)
  check("Flame Wheel burns on roll 10", find(events, "statusApplied", "foe")
    and find(events, "statusApplied", "foe").kind == "burn", types(events))
  b, events = hitWith(MOVE_SACRED_FIRE, 50)
  check("Sacred Fire burns on roll 50", S.isBurned(b.foe.status))
  b, events = hitWith(MOVE_SACRED_FIRE, 51)
  check("Sacred Fire roll 51 does not burn", b.foe.status == 0)
end

do
  -- Facade doubles while the user is poisoned/burned/paralyzed/badly
  -- poisoned; burn halving still applies inside the base damage.
  -- The player's Facade alone (resolveMove), so turn order cannot shift
  -- the draws; a paralyzed user first takes its canceller draw (1).
  local function facade(status)
    local values = status == S.PARALYSIS and { 1, 0, 1, 0 } or { 0, 1, 0 }
    local fb = battle(values, { playerMove = MOVE_FACADE, playerStatus = status, foeHP = 400 })
    local ev = {}
    fb:resolveMove("player", 1, ev)
    return damageOf(ev, "player")
  end
  local plain, poisoned, paralyzed = facade(0), facade(S.POISON), facade(S.PARALYSIS)
  local toxic, burned, asleep = facade(S.TOXIC_POISON), facade(S.BURN), facade(1)
  check("Facade doubles while poisoned/paralyzed/badly poisoned",
    poisoned == plain * 2 and paralyzed == plain * 2 and toxic == plain * 2, plain .. "/" .. poisoned)
  check("Facade after waking from a 1-turn sleep is not doubled", asleep == plain, asleep)
  local atk = BattleEngine.makeBattler({ species = 1, level = 10, stats = stats(40, 20), types = { 0, 0 } })
  local def = BattleEngine.makeBattler({ species = 1, level = 10, stats = stats(400, 10), types = { 0, 0 } })
  atk.status = S.BURN
  local halvedBase = BattleFormulas.calculateBaseDamage(atk, def, moves[MOVE_FACADE], false, nil)
  check("burned Facade: halved base, then doubled (STAB x1.5 for the Normal user)",
    burned == math.floor(halvedBase * 2 * 15 / 10), burned .. " vs base " .. halvedBase)
end

do
  local plain = damageOf(select(2, hitWith(MOVE_SMELLINGSALT, 99)), "player")
  local b = battle({ 0, 1, 0, MISS }, { playerMove = MOVE_SMELLINGSALT, foeHP = 400, foeStatus = S.PARALYSIS })
  local events = b:runTurn(MOVE, MOVE)
  local dmg, di = find(events, "damage", "player")
  local healed, hi = find(events, "paralysisHealed", "foe")
  -- dmgMultiplier doubles the base before STAB: floor(2B * 15/10).
  local base = BattleFormulas.calculateBaseDamage(b.player, b.foe, moves[MOVE_SMELLINGSALT], false, nil)
  check("Smelling Salt doubles against a paralyzed target (before STAB)",
    plain == math.floor(base * 15 / 10) and dmg.amount == math.floor(base * 2 * 15 / 10), dmg.amount .. "/" .. plain)
  -- Draws: hit 3 + the healed foe's Tackle accuracy (no paralysis draw).
  check("Smelling Salt then heals the paralysis without a roll", healed and di < hi and b.foe.status == 0
    and b.rng.draws == 4, b.rng.draws)
  b = battle({ 0, 1, 0, MISS }, { playerMove = MOVE_SMELLINGSALT, foeHP = 400 })
  events = b:runTurn(MOVE, MOVE)
  check("Smelling Salt vs a healthy target: no heal, no roll", not find(events, "paralysisHealed")
    and b.rng.draws == 4, b.rng.draws)
  b = battle({ 0, 1, 0, 99, MISS }, { playerMove = MOVE_SMELLINGSALT,
    foeTypes = { Data.TYPE_GHOST, Data.TYPE_GHOST }, foeStatus = S.PARALYSIS })
  events = b:runTurn(MOVE, MOVE)
  check("Smelling Salt vs Ghost: no effect, paralysis stays",
    find(events, "noEffect") and S.isParalyzed(b.foe.status), types(events))
  b = battle({ 0, 1, 0, 99 }, { playerMove = MOVE_SMELLINGSALT,
    foeTypes = { Data.TYPE_GHOST, Data.TYPE_GHOST }, foeStatus = S.PARALYSIS })
  local ghostEvents = {}
  b:resolveMove("player", 1, ghostEvents)
  check("Smelling Salt vs Ghost draws the effect roll (4 draws)", b.rng.draws == 4, b.rng.draws)
  b = battle({ 0, 1, 0 }, { playerMove = MOVE_SMELLINGSALT, foeCurrentHP = 1, foeStatus = S.PARALYSIS })
  events = b:runTurn(MOVE, MOVE)
  check("Smelling Salt KO: no heal message (faint clears status)", not find(events, "paralysisHealed")
    and find(events, "faint", "foe"), types(events))
end

do
  check("Refresh is admitted only as a self-target move", battle({}):supportsMove(moves[MOVE_REFRESH], MOVE_REFRESH))
  for _, st in ipairs({ S.POISON, S.BURN, S.PARALYSIS, S.TOXIC_POISON + 4 * 256 }) do
    -- A paralyzed user is slower (foe misses first) and takes its
    -- canceller draw (1 % 4 ~= 0).
    local values = st == S.PARALYSIS and { MISS, 1 } or { MISS }
    local b = battle(values, { playerMove = MOVE_REFRESH, playerStatus = st })
    local events = b:runTurn(MOVE, MOVE)
    check("Refresh cures status " .. st, find(events, "statusCured", "player") and b.player.status == 0
      and b.player.moves[1].pp == 9 and b.rng.draws == #values, types(events))
  end
  local b = battle({ MISS }, { playerMove = MOVE_REFRESH, playerStatus = 2 })
  local events = b:runTurn(MOVE, MOVE)
  check("a sleeping Refresh user is cancelled before Refresh runs", find(events, "fastAsleep", "player")
    and b.player.status == 1, types(events))
  b = battle({ MISS }, { playerMove = MOVE_REFRESH, playerStatus = S.FREEZE })
  b.rng = scriptedRng({ 1, MISS })
  events = b:runTurn(MOVE, MOVE)
  check("frozen Refresh user stays frozen (canceller)", find(events, "frozenSolid", "player"))
  b = battle({ MISS }, { playerMove = MOVE_REFRESH })
  events = b:runTurn(MOVE, MOVE)
  check("Refresh with no status: But it failed!", find(events, "moveFailed", "player")
    and b.player.moves[1].pp == 9, types(events))
end

---------------------------------------------------------------------------
-- Status-free battles keep their RNG sequence
---------------------------------------------------------------------------
do
  local b = battle({ 0, 1, 0, 0, 1, 0 })
  local events = b:runTurn(MOVE, MOVE)
  check("status-free turn draws exactly the two moves' draws", b.rng.draws == 6, b.rng.draws)
  check("status-free turn has no status events", not find(events, "statusDamage")
    and not find(events, "fastAsleep") and not find(events, "frozenSolid"))
  check("makeBattler defaults status to 0", b.player.status == 0 and b.foe.status == 0)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
