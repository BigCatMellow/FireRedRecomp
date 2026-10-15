-- Run: lua5.1 tests/battle_residual_r1_test.lua
--
-- Residual slice R1 (work/tasks/phase4-residual-r1.md): Leech Seed (with
-- Liquid Ooze), Nightmare, both Curse paths, Rapid Spin's seed arm, the
-- extended per-battler end-of-turn order, the deferred team check (D2, with
-- review F1/F2), the AI rows and the controller texts. Oracles come from
-- pret/pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788:
--   * Leech Seed: data/battle_scripts_1.s:1153-1166 (ppreduce, then
--     accuracycheck whose miss pointer is BattleScript_DoLeechSeed);
--     Cmd_setseeded src/battle_script_commands.c:6436-6456 (miss or already
--     seeded -> "evaded"; Grass type1/type2 -> "It doesn't affect"; else
--     seed with the attacker slot); AccuracyCalcHelper :958-1001 (a
--     semi-invulnerable target misses with no draw);
--   * the drain: src/battle_util.c:789-804 (seeded, receiver slot hp != 0,
--     own hp != 0, max(1, maxHP/8)); BattleScript_LeechSeedTurnDrain
--     data/battle_scripts_1.s:3223-3243 (seeded HP, gHpDealt, Liquid Ooze
--     damages the receiver else heal, text after both, tryfaintmon seeded
--     then receiver, NO checkteamslost);
--   * DoTurnDmg :3676-3688 (tryfaintmon + checkteamslost on every tick);
--     BattleTurnPassed src/battle_main.c:2953-2965 (a set outcome stops the
--     phase); Cmd_checkteamslost src/battle_script_commands.c:3385-3420;
--   * Nightmare: data/battle_scripts_1.s:1455-1469 (no accuracycheck; already
--     nightmared / not asleep -> But it failed); end of turn
--     src/battle_util.c:841-860 (asleep max(1, maxHP/4), else silent clear);
--     the wake-up clear :1300;
--   * Curse: data/battle_scripts_1.s:1478-1526 (jumpiftype2 Ghost; non-Ghost
--     fails only at Speed -6, Attack +6, Defense +6; three ALLOW_PTR
--     statbuffchanges; Ghost NO_ACC_CALC_CHECK_LOCK_ON, cursetarget, HP,
--     text, tryfaintmon BS_ATTACKER); bsc.c:1020-1025, :8093-8108,
--     :6655-6824; end of turn src/battle_util.c:861-871;
--   * Rapid Spin: data/battle_scripts_1.s:1711-1713, :3441-3454;
--     Cmd_rapidspinfree bsc.c:8435-8469; Cmd_seteffectwithchance
--     bsc.c:2774-2805 (CERTAIN && !NO_EFFECT, else the `% 100` draw);
--   * end-of-turn case order src/battle_util.c:720-742;
--   * AI: data/battle_ai_scripts.s:237-240, :414-420, :438-441;
--   * texts src/battle_message.c:70, :159-161, :198-201, :212, :290.
-- Every expected number is worked from those formulas in the comments, never
-- read back from the engine.
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

local function rec(effect, power, type_, acc, pp, chance, target, flags)
  return { effect = effect, power = power, type = type_, accuracy = acc, pp = pp,
    secondaryEffectChance = chance, target = target, priority = 0, flags = flags }
end

local T = Data
-- src/data/battle_moves.h records at the pin.
local LEECH_SEED, NIGHTMARE, CURSE, RAPID_SPIN = 73, 171, 174, 229
local SPLASH, THRASH, TACKLE = 150, 37, Data.MOVE_TACKLE
local moves = {}
for id, m in pairs(Data.moves) do moves[id] = m end
moves[LEECH_SEED] = rec(84, 0, T.TYPE_GRASS, 90, 10, 0, 0, 0x16)     -- :952-963
moves[NIGHTMARE] = rec(107, 0, T.TYPE_GHOST, 100, 15, 0, 0, 0x12)    -- :2226-2237
moves[CURSE] = rec(109, 0, T.TYPE_MYSTERY, 0, 10, 0, 0, 0)           -- :2265-2276
moves[RAPID_SPIN] = rec(129, 20, T.TYPE_NORMAL, 100, 40, 0, 0, 0x33) -- :2980-2991
moves[SPLASH] = rec(85, 0, T.TYPE_NORMAL, 0, 40, 0, 0x10, 0)
moves[THRASH] = rec(27, 90, T.TYPE_NORMAL, 100, 20, 100, 0x04, 0x33)

local LIQUID_OOZE, RAIN_DISH = 64, 44 -- include/constants/abilities.h

local function moveList(list)
  local out = {}
  for i, id in ipairs(list) do out[i] = { move = id, pp = 10 } end
  return out
end

-- Level 10, attack/defense 20. Default: player faster (30 vs 20), player
-- Psychic, foe Normal, 400 HP, both using Splash (no RNG).
local function battle(values, opts)
  opts = opts or {}
  local engine = BattleEngine.new({
    player = BattleEngine.makeBattler({ species = 1, level = 10,
      stats = { hp = opts.playerHP or 400, attack = 20, defense = 20,
        speed = opts.playerSpeed or 30, spAttack = 20, spDefense = 20 },
      types = opts.playerTypes or { T.TYPE_PSYCHIC, T.TYPE_PSYCHIC },
      status = opts.playerStatus, moves = moveList(opts.playerMoves or { SPLASH }) }),
    foe = BattleEngine.makeBattler({ species = 19, level = 10,
      stats = { hp = opts.foeHP or 400, attack = 20, defense = 20, speed = opts.foeSpeed or 20,
        spAttack = 20, spDefense = 20 },
      types = opts.foeTypes or { T.TYPE_NORMAL, T.TYPE_NORMAL },
      status = opts.foeStatus, moves = moveList(opts.foeMoves or { SPLASH }) }),
    moves = moves, typeChart = Data.typeChart, rng = scriptedRng(values or {}),
    hasReplacement = opts.hasReplacement,
  })
  engine.player.ability = opts.playerAbility or 0
  engine.foe.ability = opts.foeAbility or 0
  if opts.playerCurrentHP then engine.player.hp = opts.playerCurrentHP end
  if opts.foeCurrentHP then engine.foe.hp = opts.foeCurrentHP end
  return engine
end

local function freshBattler(hp, types)
  return BattleEngine.makeBattler({ species = 7, level = 10,
    stats = { hp = hp or 400, attack = 20, defense = 20, speed = 30, spAttack = 20, spDefense = 20 },
    types = types or { T.TYPE_WATER, T.TYPE_WATER }, moves = moveList({ SPLASH }) })
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
local function texts(engine, events)
  local c = BattleSceneController.new({ engine = engine, playerName = "PLAYER", foeName = "FOE",
    introMessages = {} })
  local out = {}
  for _, entry in ipairs(c:_eventMessages(events)) do
    out[#out + 1] = entry.text or ("[hp " .. entry.hpSide .. " " .. entry.hp .. "]")
  end
  return out
end
local function joined(list) return table.concat(list, "|") end

---------------------------------------------------------------------------
-- Admission
---------------------------------------------------------------------------
do
  local e = battle()
  check("supportsMove admits Leech Seed, Nightmare and Curse",
    e:supportsMove(moves[LEECH_SEED], LEECH_SEED) and e:supportsMove(moves[NIGHTMARE], NIGHTMARE)
      and e:supportsMove(moves[CURSE], CURSE))
  check("the admission requires power 0 (no damaging member exists at the pin)",
    not e:supportsMove(rec(84, 10, 0, 100, 10, 0, 0, 0), 9001))
  check("a non-SELECTED zero-power Leech Seed record is refused",
    not e:supportsMove(rec(84, 0, 12, 90, 10, 0, 0x10, 0), 9002))
  check("battle-only fields default false",
    e.player.seeded == false and e.player.nightmare == false and e.player.cursed == false)
end

---------------------------------------------------------------------------
-- Leech Seed: the move
---------------------------------------------------------------------------
do
  -- Hit: one accuracy draw, (0 % 100) + 1 = 1 <= 90.
  local e = battle({ 0 }, { playerMoves = { LEECH_SEED } })
  local events = {}
  e:resolveMove("player", 1, events)
  check("Leech Seed hit: exactly one draw", e.rng.draws == 1, e.rng.draws)
  check("Leech Seed hit: useMove then seeded", types(events) == "useMove,leechSeed"
    and events[2].result == "seeded" and events[2].side == "player" and events[2].target == "foe",
    types(events))
  check("Leech Seed hit: the foe is seeded, PP 10 -> 9", e.foe.seeded and e.player.moves[1].pp == 9)
  check("seeded text names the target", joined(texts(e, events)) == "PLAYER used MOVE 73!|FOE was seeded!",
    joined(texts(e, events)))

  -- Miss: (90 % 100) + 1 = 91 > 90 -> "evaded", one draw, PP spent.
  e = battle({ 90 }, { playerMoves = { LEECH_SEED } })
  events = {}
  e:resolveMove("player", 1, events)
  check("Leech Seed miss: evaded, not the generic miss", events[2].type == "leechSeed"
    and events[2].result == "evaded" and not find(events, "miss"), types(events))
  check("Leech Seed miss: one draw, PP spent, not seeded",
    e.rng.draws == 1 and e.player.moves[1].pp == 9 and not e.foe.seeded)
  check("evaded text names the target", texts(e, events)[2] == "FOE evaded\nthe attack!", texts(e, events)[2])

  -- Already seeded: the accuracy draw hits, then setseeded's first test.
  e = battle({ 0 }, { playerMoves = { LEECH_SEED } })
  e.foe.seeded = true
  events = {}
  e:resolveMove("player", 1, events)
  check("already seeded: evaded after the one hitting draw",
    events[2].result == "evaded" and e.rng.draws == 1 and e.foe.seeded, types(events))

  -- Grass immunity: the draw is spent first.
  e = battle({ 0 }, { playerMoves = { LEECH_SEED }, foeTypes = { T.TYPE_POISON, T.TYPE_GRASS } })
  events = {}
  e:resolveMove("player", 1, events)
  check("Grass (type2) target: noEffect with the accuracy draw spent",
    events[2].result == "noEffect" and e.rng.draws == 1 and not e.foe.seeded, types(events))
  check("Grass text", texts(e, events)[2] == "It doesn't affect FOE...", texts(e, events)[2])
  e = battle({ 95 }, { playerMoves = { LEECH_SEED }, foeTypes = { T.TYPE_GRASS, T.TYPE_GRASS } })
  events = {}
  e:resolveMove("player", 1, events)
  check("a miss against a Grass target is evaded (MOVE_RESULT_NO_EFFECT tested first)",
    events[2].result == "evaded" and e.rng.draws == 1)

  -- Semi-invulnerable target: a miss with no draw.
  for _, state in ipairs({ "air", "underground", "underwater" }) do
    e = battle({ 0 }, { playerMoves = { LEECH_SEED } })
    e.foe.semiInvulnerable = state
    events = {}
    e:resolveMove("player", 1, events)
    check("semi-invulnerable (" .. state .. ") target: evaded with no draw",
      events[2].result == "evaded" and e.rng.draws == 0 and e.player.moves[1].pp == 9)
  end

  -- No typecalc: a Ghost target can be seeded.
  e = battle({ 0 }, { playerMoves = { LEECH_SEED }, foeTypes = { T.TYPE_GHOST, T.TYPE_GHOST } })
  events = {}
  e:resolveMove("player", 1, events)
  check("Ghost target is seeded", events[2].result == "seeded" and e.foe.seeded)
end

---------------------------------------------------------------------------
-- Leech Seed: the end-of-turn drain
---------------------------------------------------------------------------
do
  -- Full turn: player seeds (1 draw), foe Splash; the seed drains the same
  -- turn. Foe maxHP 80 -> max(1, 80/8) = 10; player 50/100 heals 10 -> 60.
  local e = battle({ 0 }, { playerMoves = { LEECH_SEED }, playerHP = 100, playerCurrentHP = 50, foeHP = 80 })
  local events = e:runTurn(MOVE, MOVE)
  local drain = find(events, "leechSeedDrain")
  check("drain on the turn the seed lands", drain and drain.side == "foe" and drain.receiver == "player")
  check("drain amount maxHP/8 = 10, heal 10", drain.amount == 10 and drain.hpRemaining == 70
    and drain.receiverAmount == 10 and drain.receiverHpRemaining == 60 and drain.ooze == false)
  check("turn draws: only the accuracy draw", e.rng.draws == 1, e.rng.draws)
  local t = texts(e, { drain })
  check("drain presentation: seeded HP, receiver HP, then the text",
    joined(t) == "[hp foe 70]|[hp player 60]|FOE's health is\nsapped by LEECH SEED!", joined(t))

  -- Minimum 1: maxHP 7 -> 7/8 = 0 -> 1.
  e = battle({}, { foeHP = 7, playerHP = 100, playerCurrentHP = 90 })
  e.foe.seeded = true
  events = e:runTurn(MOVE, MOVE)
  drain = find(events, "leechSeedDrain")
  check("drain minimum 1", drain.amount == 1 and drain.receiverAmount == 1 and e.player.hp == 91)

  -- Full-HP receiver: heal clamped to 0, text still printed.
  e = battle({}, { foeHP = 80 })
  e.foe.seeded = true
  events = e:runTurn(MOVE, MOVE)
  drain = find(events, "leechSeedDrain")
  check("receiver at full HP: heal 0, event (and text) still emitted",
    drain and drain.amount == 10 and drain.receiverAmount == 0 and e.player.hp == 400
      and texts(e, { drain })[3] == "FOE's health is\nsapped by LEECH SEED!")

  -- Clamp at the seeded battler's HP: 3 HP left, maxHP 80 -> loses 3, the
  -- receiver heals gHpDealt = 3.
  e = battle({}, { foeHP = 80, foeCurrentHP = 3, playerHP = 100, playerCurrentHP = 50,
    hasReplacement = function(side) return side == "foe" end })
  e.foe.seeded = true
  events = e:runTurn(MOVE, MOVE)
  drain = find(events, "leechSeedDrain")
  check("drain capped at the seeded battler's HP; heal = actual loss",
    drain.amount == 3 and drain.hpRemaining == 0 and drain.receiverAmount == 3 and e.player.hp == 53)
  check("seed KO with a foe replacement: faint, then forcedSwitchNeeded after the phase",
    types(events):find("leechSeedDrain,faint,forcedSwitchNeeded", 1, true) ~= nil
      and e.awaitingForcedSwitch == "foe" and not e:isOver(), types(events))

  -- The seeded battler switching out loses the seed (fresh battler).
  e = battle({}, { playerHP = 100 })
  e.player.seeded = true
  events = e:runTurn({ action = "switch", battler = freshBattler(100) }, MOVE)
  check("seeded player switches out: no drain", not find(events, "leechSeedDrain") and not e.player.seeded)
end

do
  -- Seeder-slot semantics: the player's seed on the foe heals whoever holds
  -- the player slot. Voluntary switch: the incoming battler gets the heal.
  local e = battle({}, { foeHP = 80 })
  e.foe.seeded = true
  local incoming = freshBattler(200)
  incoming.hp = 150
  local events = e:runTurn({ action = "switch", battler = incoming }, MOVE)
  local drain = find(events, "leechSeedDrain")
  check("after a voluntary switch the replacement receives the heal",
    drain and drain.receiver == "player" and drain.receiverAmount == 10 and incoming.hp == 160
      and e.foe.seeded)

  -- Forced replacement: the receiver slot at 0 HP skips the drain (the
  -- seed is untouched); the replacement then gets the heal.
  -- Foe faster Tackle (acc 0 hit, crit 1 no, damage roll 0) KOs a 1-HP
  -- player; player has a replacement.
  e = battle({ 0, 1, 0 }, { foeHP = 80, foeSpeed = 40, foeMoves = { TACKLE }, playerCurrentHP = 1,
    hasReplacement = function(side) return side == "player" end })
  e.foe.seeded = true
  events = e:runTurn(MOVE, MOVE)
  check("receiver slot at 0 HP (pending replacement): no drain, seed kept",
    find(events, "faint", "player") and not find(events, "leechSeedDrain") and e.foe.seeded
      and e.foe.hp == 80 and e.awaitingForcedSwitch == "player", types(events))
  local replacement = freshBattler(200)
  replacement.hp = 100
  e:resolveForcedSwitch("player", replacement)
  e.foe.moves[1].move = SPLASH
  events = e:runTurn(MOVE, MOVE)
  drain = find(events, "leechSeedDrain")
  check("the forced replacement receives the next drain",
    drain and drain.receiverAmount == 10 and replacement.hp == 110 and e.foe.hp == 70)
end

---------------------------------------------------------------------------
-- Liquid Ooze
---------------------------------------------------------------------------
do
  local e = battle({}, { foeHP = 80, foeAbility = LIQUID_OOZE, playerHP = 100 })
  e.foe.seeded = true
  local events = e:runTurn(MOVE, MOVE)
  local drain = find(events, "leechSeedDrain")
  check("Liquid Ooze: the receiver loses gHpDealt", drain.ooze == true and drain.amount == 10
    and drain.receiverAmount == 10 and e.player.hp == 90 and drain.receiverHpRemaining == 90)
  check("Liquid Ooze text after both HP entries",
    joined(texts(e, { drain })) == "[hp foe 70]|[hp player 90]|It sucked up the\nLIQUID OOZE!",
    joined(texts(e, { drain })))

  -- Ooze KOs both: foe 10 HP (loses 10 -> 0), player 4 HP (takes min(4, 10)).
  -- tryfaintmon seeded (foe) then receiver (player); no tick decides it, so
  -- the post-phase check gives a draw.
  e = battle({}, { foeHP = 80, foeCurrentHP = 10, foeAbility = LIQUID_OOZE, playerCurrentHP = 4 })
  e.foe.seeded = true
  events = e:runTurn(MOVE, MOVE)
  drain = find(events, "leechSeedDrain")
  local _, foeFaint = find(events, "faint", "foe")
  local _, playerFaint = find(events, "faint", "player")
  check("ooze double KO: receiver damage clamped to its HP", drain.receiverAmount == 4 and e.player.hp == 0)
  check("ooze double KO: seeded faints first, then the receiver, then a draw",
    foeFaint and playerFaint and foeFaint < playerFaint and e.outcome == "playerDrew"
      and events[#events].type == "battleEnd", types(events))
end

---------------------------------------------------------------------------
-- The deferred team check (D2, review F1/F2)
---------------------------------------------------------------------------
do
  -- Foe faster, so ENDTURN order is foe then player. The player's seed KOs
  -- the foe's last mon (10 HP, maxHP 80). The poisoned player (maxHP 400,
  -- 400/8 = 50) still ticks; that non-fatal tick's checkteamslost wins it.
  local e = battle({}, { foeHP = 80, foeCurrentHP = 10, foeSpeed = 40, playerStatus = S.POISON })
  e.foe.seeded = true
  local events = e:runTurn(MOVE, MOVE)
  check("seed KO does not end the battle at once; the player's poison tick follows",
    types(events) == "turnStart,useMove,splash,useMove,splash,leechSeedDrain,faint,statusDamage,battleEnd", types(events))
  -- The drain healed 0 (player at full HP), poison 50: 400 -> 350.
  check("the non-fatal tick decides playerWon", e.outcome == "playerWon" and e.player.hp == 350)
  check("exactly one foe faint event", count(events, "faint", "foe") == 1 and count(events, "faint") == 1)
  check("faint text once", select(2, joined(texts(e, events)):gsub("FOE fainted!", "")) == 1)

  -- Same, but the poison KOs the player: 40 HP, +10 from the drain, then
  -- 50 poison -> 0. Both teams empty -> checkteamslost ORs LOST and WON ->
  -- draw.
  e = battle({}, { foeHP = 80, foeCurrentHP = 10, foeSpeed = 40, playerStatus = S.POISON,
    playerCurrentHP = 40 })
  e.foe.seeded = true
  events = e:runTurn(MOVE, MOVE)
  check("seed KO then the player's fatal poison: playerDrew",
    types(events) == "turnStart,useMove,splash,useMove,splash,leechSeedDrain,faint,statusDamage,faint,battleEnd"
      and e.outcome == "playerDrew", types(events))
  check("draw: one faint per side", count(events, "faint", "foe") == 1 and count(events, "faint", "player") == 1)

  -- F1: the player survives its poison tick with Curse and a rampage
  -- pending. The battle is decided by the poison tick, so neither runs.
  e = battle({}, { foeHP = 80, foeCurrentHP = 10, foeSpeed = 40, playerStatus = S.POISON })
  e.foe.seeded = true
  e.player.cursed = true
  e.player.rampageTurns = 1
  e.player.lockedSlot = 1
  events = {}
  e:resolveStatusEndTurn(events, { "foe", "player" })
  check("F1: no Curse tick and no rampage tick after battleEnd",
    types(events) == "leechSeedDrain,faint,statusDamage,battleEnd" and e.player.hp == 350
      and e.player.rampageTurns == 1 and e.rng.draws == 0, types(events))

  -- Without a later damage tick the post-phase check decides it, and the
  -- player's whole list (Rain Dish, the rampage tick) still runs first.
  -- Rain: 400/16 = 25 heal from 300. Rampage 1 -> 0 -> fatigue confusion
  -- draws `% 4` (value 1 -> 3 turns).
  e = battle({ 1 }, { foeHP = 80, foeCurrentHP = 10, foeSpeed = 40, playerAbility = RAIN_DISH,
    playerCurrentHP = 300 })
  e.weather = { kind = "rain", permanent = true }
  e.foe.seeded = true
  e.player.rampageTurns = 1
  e.player.lockedSlot = 1
  events = {}
  e:resolveStatusEndTurn(events, { "foe", "player" })
  check("Rain Dish does not trigger the team check; the other list runs to the end",
    types(events) == "leechSeedDrain,faint,rainDish,fatigueConfusion,battleEnd"
      and e.outcome == "playerWon" and e.player.confusionTurns == 3 and e.rng.draws == 1, types(events))

  -- F2: a mid-turn foe faint (forced switch queued) followed by the
  -- player's non-fatal poison tick: no second foe faint event or text.
  -- Player Tackle: acc 0, crit 1 (no), damage 0; foe has 1 HP.
  e = battle({ 0, 1, 0 }, { playerMoves = { TACKLE }, foeCurrentHP = 1, playerStatus = S.POISON,
    hasReplacement = function(side) return side == "foe" end })
  events = e:runTurn(MOVE, MOVE)
  check("F2: mid-turn foe faint then the player's poison tick: one foe faint, one forced switch",
    count(events, "faint", "foe") == 1 and count(events, "forcedSwitchNeeded", "foe") == 1
      and find(events, "statusDamage", "player") and not e:isOver()
      and e.awaitingForcedSwitch == "foe", types(events))
  check("F2: \"fainted!\" printed once",
    select(2, joined(texts(e, events)):gsub("FOE fainted!", "")) == 1)

  -- F2: seed KO with a foe replacement, then a non-fatal player tick
  -- finalizes the open sequence once (one faint, one forcedSwitchNeeded);
  -- the battle continues and the player's later Curse tick still runs.
  e = battle({}, { foeHP = 80, foeCurrentHP = 10, foeSpeed = 40, playerStatus = S.POISON,
    hasReplacement = function(side) return side == "foe" end })
  e.foe.seeded = true
  e.player.cursed = true
  events = {}
  e:resolveStatusEndTurn(events, { "foe", "player" })
  check("seed KO + replacement: the tick finalizes once and the list continues",
    types(events) == "leechSeedDrain,faint,statusDamage,forcedSwitchNeeded,curseDamage"
      and count(events, "faint") == 1 and e.faintSequence == nil and not e:isOver(), types(events))

  -- Player first: the player's seed on the foe is irrelevant here; the
  -- foe's seed on the player KOs the player's last mon, then the foe's own
  -- burn (non-fatal) decides playerLost.
  e = battle({}, { playerHP = 80, playerCurrentHP = 10, foeStatus = S.BURN })
  e.player.seeded = true
  events = e:runTurn(MOVE, MOVE)
  check("seed KO of the player, then the foe's burn tick: playerLost",
    types(events) == "turnStart,useMove,splash,useMove,splash,leechSeedDrain,faint,statusDamage,battleEnd"
      and e.outcome == "playerLost", types(events))
end

---------------------------------------------------------------------------
-- Nightmare
---------------------------------------------------------------------------
do
  -- Awake target: But it failed, no draw, PP spent.
  local e = battle({}, { playerMoves = { NIGHTMARE } })
  local events = {}
  e:resolveMove("player", 1, events)
  check("Nightmare on an awake target fails with no draw",
    types(events) == "useMove,moveFailed" and e.rng.draws == 0 and e.player.moves[1].pp == 9
      and not e.foe.nightmare)

  -- Asleep Normal-type target: no accuracycheck, no typecalc.
  e = battle({}, { playerMoves = { NIGHTMARE }, foeStatus = S.withSleepTurns(0, 3) })
  e.foe.semiInvulnerable = nil
  events = {}
  e:resolveMove("player", 1, events)
  check("Nightmare on a sleeping Normal target works with no draw",
    types(events) == "useMove,nightmare" and e.foe.nightmare and e.rng.draws == 0)
  check("Nightmare text", texts(e, events)[2] == "FOE fell into\na NIGHTMARE!", texts(e, events)[2])

  -- Already nightmared: But it failed.
  events = {}
  e:resolveMove("player", 1, events)
  check("already nightmared fails", types(events) == "useMove,moveFailed" and e.foe.nightmare)

  -- End of turn while asleep: text, then max(1, 400/4) = 100.
  e = battle({}, { foeStatus = S.withSleepTurns(0, 3) })
  e.foe.nightmare = true
  events = {}
  e:resolveStatusEndTurn(events, { "player", "foe" })
  check("asleep: nightmareDamage maxHP/4", types(events) == "nightmareDamage"
    and events[1].amount == 100 and e.foe.hp == 300)
  check("nightmare tick text before HP",
    joined(texts(e, events)) == "FOE is locked\nin a NIGHTMARE!|[hp foe 300]", joined(texts(e, events)))
  e = battle({}, { foeHP = 3, foeStatus = S.withSleepTurns(0, 3) })
  e.foe.nightmare = true
  events = {}
  e:resolveStatusEndTurn(events, { "player", "foe" })
  check("nightmare minimum 1 (3/4 = 0)", events[1].amount == 1 and e.foe.hp == 2)

  -- Awake at end of turn: cleared silently.
  e = battle()
  e.foe.nightmare = true
  events = {}
  e:resolveStatusEndTurn(events, { "player", "foe" })
  check("awake: the flag clears silently", #events == 0 and not e.foe.nightmare)

  -- Lifecycle: the foe wakes (sleep counter 1 -> 0) when it moves; the wake
  -- clears the nightmare, so no tick at that turn's end.
  e = battle({}, { foeStatus = S.withSleepTurns(0, 1) })
  e.foe.nightmare = true
  events = e:runTurn(MOVE, MOVE)
  check("the wake-up clears Nightmare: no tick", find(events, "wokeUp", "foe")
    and not find(events, "nightmareDamage") and not e.foe.nightmare and e.foe.hp == 400, types(events))

  -- The canceller itself clears it (src/battle_util.c:1300), before any
  -- end-of-turn re-check.
  e = battle({}, { foeStatus = S.withSleepTurns(0, 1) })
  e.foe.nightmare = true
  events = {}
  e:resolveMove("foe", 1, events)
  check("the wake-up clears Nightmare inside the canceller",
    types(events) == "wokeUp,useMove,splash" and not e.foe.nightmare, types(events))

  -- Still asleep (counter 3 -> 2): the tick happens at turn end.
  e = battle({}, { foeStatus = S.withSleepTurns(0, 3) })
  e.foe.nightmare = true
  events = e:runTurn(MOVE, MOVE)
  check("still asleep: fast asleep, then the end-of-turn tick",
    types(events) == "turnStart,useMove,splash,fastAsleep,nightmareDamage", types(events))

  -- Cleared on faint (FaintClearSetData zeroes status2/status3).
  e = battle({}, { foeStatus = S.withSleepTurns(0, 3),
    hasReplacement = function(side) return side == "foe" end })
  e.foe.nightmare = true
  e.foe.cursed = true
  e.foe.seeded = true
  e.foe.hp = 0
  e:beginFaintSequence()
  e:recordFaint("foe", {})
  e:finalizeFaintSequence({})
  check("recordFaint clears seeded, nightmare and cursed",
    not e.foe.nightmare and not e.foe.cursed and not e.foe.seeded)
end

---------------------------------------------------------------------------
-- Curse, non-Ghost
---------------------------------------------------------------------------
do
  local e = battle({}, { playerMoves = { CURSE } })
  local events = {}
  e:resolveMove("player", 1, events)
  check("non-Ghost Curse: Speed -1, Attack +1, Defense +1 on the user, no draw",
    types(events) == "useMove,statChange,statChange,statChange" and e.rng.draws == 0
      and events[2].stat == "speed" and events[2].stages == -1 and events[2].side == "player"
      and events[3].stat == "attack" and events[3].stages == 1
      and events[4].stat == "defense" and events[4].stages == 1
      and e.player.statStages.speed == 5 and e.player.statStages.attack == 7
      and e.player.statStages.defense == 7 and e.player.moves[1].pp == 9)

  -- Fail matrix: only -6/+6/+6 fails.
  e = battle({}, { playerMoves = { CURSE } })
  e.player.statStages.speed, e.player.statStages.attack, e.player.statStages.defense = 0, 12, 12
  events = {}
  e:resolveMove("player", 1, events)
  check("non-Ghost Curse at -6/+6/+6 fails", types(events) == "useMove,moveFailed"
    and e.player.moves[1].pp == 9)

  -- -6/+6/+5: plays; the capped stats carry signed stages (review F7).
  e = battle({}, { playerMoves = { CURSE } })
  e.player.statStages.speed, e.player.statStages.attack, e.player.statStages.defense = 0, 12, 11
  events = {}
  e:resolveMove("player", 1, events)
  check("Curse at -6/+6/+5: two prevented events with signed stages, then Defense +1",
    events[2].prevented and events[2].stages == -1 and events[3].prevented and events[3].stages == 1
      and not events[4].prevented and events[4].stages == 1 and e.player.statStages.defense == 12
      and e.player.statStages.speed == 0 and e.player.statStages.attack == 12)
  check("Curse capped texts",
    joined(texts(e, events)) == "PLAYER used MOVE 174!|PLAYER's SPEED\nwon't go lower!|"
      .. "PLAYER's ATTACK\nwon't go higher!|PLAYER's DEFENSE\nrose!", joined(texts(e, events)))

  -- Each other cap combination plays (only the triple fails).
  for _, st in ipairs({ { 0, 12, 6 }, { 0, 6, 12 }, { 6, 12, 12 }, { 1, 12, 12 } }) do
    e = battle({}, { playerMoves = { CURSE } })
    e.player.statStages.speed, e.player.statStages.attack, e.player.statStages.defense = st[1], st[2], st[3]
    events = {}
    e:resolveMove("player", 1, events)
    check(("Curse at stages %d/%d/%d plays"):format(st[1], st[2], st[3]),
      types(events) == "useMove,statChange,statChange,statChange")
  end

  -- F3: no accuracycheck, so a target in mid-Fly/Dig is irrelevant.
  for _, state in ipairs({ "air", "underground" }) do
    e = battle({}, { playerMoves = { CURSE } })
    e.foe.semiInvulnerable = state
    events = {}
    e:resolveMove("player", 1, events)
    check("non-Ghost Curse vs a semi-invulnerable (" .. state .. ") target plays (F3)",
      types(events) == "useMove,statChange,statChange,statChange" and e.rng.draws == 0
        and not e.foe.cursed)
  end
end

---------------------------------------------------------------------------
-- Curse, Ghost
---------------------------------------------------------------------------
do
  -- maxHP 41 -> 41/2 = 20; HP 41 -> 21.
  local e = battle({}, { playerMoves = { CURSE }, playerTypes = { T.TYPE_GHOST, T.TYPE_POISON }, playerHP = 41 })
  local events = {}
  e:resolveMove("player", 1, events)
  check("Ghost Curse: curses the target, costs maxHP/2 (odd maxHP), no draw",
    types(events) == "useMove,curseLaid" and e.foe.cursed and e.player.hp == 21
      and events[2].amount == 20 and events[2].hpRemaining == 21 and e.rng.draws == 0
      and e.player.moves[1].pp == 9 and e.player.statStages.speed == 6)
  check("Ghost Curse presentation: HP, then the text",
    joined(texts(e, { events[2] })) == "[hp player 21]|PLAYER cut its own HP and\nlaid a CURSE on FOE!",
    joined(texts(e, { events[2] })))

  -- Ghost in type2 only.
  e = battle({}, { playerMoves = { CURSE }, playerTypes = { T.TYPE_POISON, T.TYPE_GHOST } })
  events = {}
  e:resolveMove("player", 1, events)
  check("Ghost in type2 takes the Ghost path", types(events) == "useMove,curseLaid")

  -- Already cursed: But it failed, no HP cost.
  e = battle({}, { playerMoves = { CURSE }, playerTypes = { T.TYPE_GHOST, T.TYPE_GHOST } })
  e.foe.cursed = true
  events = {}
  e:resolveMove("player", 1, events)
  check("Ghost Curse on a cursed target fails with no cost",
    types(events) == "useMove,moveFailed" and e.player.hp == 400 and e.player.moves[1].pp == 9)

  -- Semi-invulnerable target (F3, Ghost path only): But it failed, no draw.
  for _, state in ipairs({ "air", "underground", "underwater" }) do
    e = battle({}, { playerMoves = { CURSE }, playerTypes = { T.TYPE_GHOST, T.TYPE_GHOST } })
    e.foe.semiInvulnerable = state
    events = {}
    e:resolveMove("player", 1, events)
    check("Ghost Curse vs semi-invulnerable (" .. state .. "): But it failed, no draw, no cost",
      types(events) == "useMove,moveFailed" and e.rng.draws == 0 and e.player.hp == 400
        and not e.foe.cursed and e.player.moves[1].pp == 9)
  end

  -- 1 HP user: cost max(1, 400/2) clamped to 1 -> faints -> lost.
  e = battle({}, { playerMoves = { CURSE }, playerTypes = { T.TYPE_GHOST, T.TYPE_GHOST }, playerCurrentHP = 1 })
  events = e:runTurn(MOVE, MOVE)
  check("Ghost Curse self-KO loses the battle; the foe never moves",
    types(events) == "turnStart,useMove,curseLaid,faint,battleEnd" and e.outcome == "playerLost"
      and find(events, "curseLaid").amount == 1, types(events))
  -- maxHP 1: max(1, 0) = 1.
  e = battle({}, { playerMoves = { CURSE }, playerTypes = { T.TYPE_GHOST, T.TYPE_GHOST }, playerHP = 1 })
  events = {}
  e:resolveMove("player", 1, events)
  check("Ghost Curse at maxHP 1 costs 1", events[2].amount == 1 and e.player.hp == 0)

  -- End-of-turn tick: text, then max(1, 400/4) = 100.
  e = battle()
  e.foe.cursed = true
  events = {}
  e:resolveStatusEndTurn(events, { "player", "foe" })
  check("Curse tick maxHP/4", types(events) == "curseDamage" and events[1].amount == 100 and e.foe.hp == 300)
  check("Curse tick text before HP",
    joined(texts(e, events)) == "FOE is afflicted\nby the CURSE!|[hp foe 300]", joined(texts(e, events)))
  e = battle({}, { foeCurrentHP = 50 })
  e.foe.cursed = true
  events = {}
  e:resolveStatusEndTurn(events, { "player", "foe" })
  check("a fatal Curse tick ends the battle (tryfaintmon + checkteamslost)",
    types(events) == "curseDamage,faint,battleEnd" and e.outcome == "playerWon" and events[1].amount == 50)
end

---------------------------------------------------------------------------
-- End-of-turn order against weather, Rain Dish, status and rampage
---------------------------------------------------------------------------
do
  -- One battler (the foe): sandstorm damage (field) < Leech Seed < poison
  -- < Curse < rampage tick. Foe Normal (not exempt from sand). The
  -- player is Rock (exempt) to keep its list empty. Player first in order.
  local e = battle({ 2 }, { foeStatus = S.POISON, playerTypes = { T.TYPE_ROCK, T.TYPE_ROCK },
    playerHP = 100, playerCurrentHP = 50 })
  e.weather = { kind = "sandstorm", permanent = false }
  e.weatherDuration = 3
  e.foe.seeded = true
  e.foe.cursed = true
  e.foe.rampageTurns = 1
  e.foe.lockedSlot = 1
  local events = {}
  e:resolveEndTurn(events, nil, nil)
  check("order: weather < Leech Seed < poison < Curse < rampage",
    types(events) == "weatherContinues,weatherDamage,leechSeedDrain,statusDamage,curseDamage,fatigueConfusion",
    types(events))
  -- 400/16 = 25 sand, 400/8 = 50 seed, 50 poison, 100 curse: 400 -> 175.
  check("order: amounts", e.foe.hp == 175 and e.player.hp == 100 and e.foe.confusionTurns == 4)

  -- Rain Dish < Leech Seed on the same battler; Nightmare < Curse.
  e = battle({}, { foeStatus = S.withSleepTurns(0, 3), foeAbility = RAIN_DISH, foeCurrentHP = 300 })
  e.weather = { kind = "rain", permanent = true }
  e.foe.seeded = true
  e.foe.nightmare = true
  e.foe.cursed = true
  events = {}
  e:resolveStatusEndTurn(events, { "player", "foe" })
  check("order: Rain Dish < Leech Seed < Nightmare < Curse",
    types(events) == "rainDish,leechSeedDrain,nightmareDamage,curseDamage", types(events))

  -- One battler's whole list before the next: player (first) seeded and
  -- cursed, foe seeded and cursed.
  e = battle({}, {})
  e.player.seeded, e.player.cursed, e.foe.seeded, e.foe.cursed = true, true, true, true
  events = {}
  e:resolveStatusEndTurn(events, { "player", "foe" })
  local sides = {}
  for _, ev in ipairs(events) do sides[#sides + 1] = ev.type .. ":" .. ev.side end
  check("per-battler lists run in ENDTURN order, one whole list at a time",
    table.concat(sides, ",") == "leechSeedDrain:player,curseDamage:player,leechSeedDrain:foe,curseDamage:foe",
    table.concat(sides, ","))

  -- Semi-invulnerable battlers still tick.
  e = battle({})
  e.foe.cursed = true
  e.foe.semiInvulnerable = "underground"
  events = {}
  e:resolveStatusEndTurn(events, { "player", "foe" })
  check("a Dig user still takes the Curse tick", types(events) == "curseDamage")
end

---------------------------------------------------------------------------
-- Rapid Spin, seed arm
---------------------------------------------------------------------------
do
  -- Landed hit: acc 0, crit 1 (no crit), damage roll 0; no fourth draw.
  local e = battle({ 0, 1, 0, 0 }, { playerMoves = { RAPID_SPIN } })
  e.player.seeded = true
  local events = {}
  e:resolveMove("player", 1, events)
  check("Rapid Spin frees the seed with no secondary draw",
    types(events) == "useMove,damage,leechSeedFreed" and e.rng.draws == 3 and not e.player.seeded,
    types(events) .. " draws=" .. e.rng.draws)
  check("shed text", texts(e, events)[3] == "PLAYER shed\nLEECH SEED!", texts(e, events)[3])

  -- On a KO: the cleanup precedes tryfaintmon BS_TARGET.
  e = battle({ 0, 1, 0 }, { playerMoves = { RAPID_SPIN }, foeCurrentHP = 1 })
  e.player.seeded = true
  events = e:runTurn(MOVE, MOVE)
  check("Rapid Spin KO: shed before the faint", types(events) == "turnStart,useMove,damage,leechSeedFreed,faint,battleEnd",
    types(events))

  -- Not seeded: nothing extra.
  e = battle({ 0, 1, 0 }, { playerMoves = { RAPID_SPIN } })
  events = {}
  e:resolveMove("player", 1, events)
  check("Rapid Spin without a seed: plain hit, three draws", types(events) == "useMove,damage" and e.rng.draws == 3)

  -- Against a Ghost: no effect; acc, crit, damage random, then the
  -- discarded `% 100` (CERTAIN && !NO_EFFECT fails) -- four draws; the seed
  -- stays.
  e = battle({ 0, 1, 0, 0, 77 }, { playerMoves = { RAPID_SPIN }, foeTypes = { T.TYPE_GHOST, T.TYPE_GHOST } })
  e.player.seeded = true
  events = {}
  e:resolveMove("player", 1, events)
  check("Rapid Spin vs Ghost: noEffect, four draws, seed kept",
    types(events) == "useMove,noEffect" and e.rng.draws == 4 and e.player.seeded, e.rng.draws)

  -- Miss: one draw, seed kept. Rapid Spin acc 100: draw 99 -> 100 <= 100
  -- hits, so lower the user's accuracy stage to force a miss: stage 0
  -- (-6) ratio 33/100 -> 33; draw 50 -> 51 > 33.
  e = battle({ 50 }, { playerMoves = { RAPID_SPIN } })
  e.player.statStages.accuracy = 0
  e.player.seeded = true
  events = {}
  e:resolveMove("player", 1, events)
  check("Rapid Spin miss: one draw, seed kept", types(events) == "useMove,miss" and e.rng.draws == 1
    and e.player.seeded)
end

---------------------------------------------------------------------------
-- AI rows (AI_CheckBadMove)
---------------------------------------------------------------------------
do
  local function mon(t)
    return { level = 10, hp = 30, maxHP = 30, types = t or { T.TYPE_NORMAL, T.TYPE_NORMAL }, ability = 0,
      status = 0, statStages = { attack = 6, defense = 6, speed = 6, spAttack = 6, spDefense = 6,
        accuracy = 6, evasion = 6 } }
  end
  local sideStatus = { player = { reflect = false, lightScreen = false }, foe = { reflect = false, lightScreen = false } }
  local function score(user, target, id)
    return AICheckBadMove.score(user, target, moves[id], id, Data.typeChart, sideStatus)
  end
  local user, target = mon(), mon()
  check("AI_CBM_LeechSeed: plain target 0", score(user, target, LEECH_SEED) == 0)
  target.seeded = true
  check("AI_CBM_LeechSeed: already seeded -10", score(user, target, LEECH_SEED) == -10)
  check("AI_CBM_LeechSeed: Grass type2 -10", score(user, mon({ T.TYPE_POISON, T.TYPE_GRASS }), LEECH_SEED) == -10)

  local asleep = mon(); asleep.status = S.withSleepTurns(0, 2)
  check("AI_CBM_Nightmare: asleep 0, awake -8",
    score(user, asleep, NIGHTMARE) == 0 and score(user, mon(), NIGHTMARE) == -8)
  asleep.nightmare = true
  local awakeNightmare = mon(); awakeNightmare.nightmare = true
  check("AI_CBM_Nightmare: already nightmared -10 (before the sleep test)",
    score(user, asleep, NIGHTMARE) == -10 and score(user, awakeNightmare, NIGHTMARE) == -10)

  local ghost = mon({ T.TYPE_GHOST, T.TYPE_GHOST })
  check("AI_CBM_Curse: neutral 0", score(ghost, target, CURSE) == 0)
  ghost.statStages.defense = 12
  check("AI_CBM_Curse: Defense +6 -8, no Ghost test", score(ghost, target, CURSE) == -8)
  ghost.statStages.attack = 12
  check("AI_CBM_Curse: Attack +6 -10 shadows -8", score(ghost, target, CURSE) == -10)

  -- TrainerAI reads the live battler tables (engine.foe/engine.player).
  local e = battle({}, {})
  e.player.seeded = true
  check("the live engine battler carries the flag the AI reads",
    AICheckBadMove.score(e.foe, e.player, moves[LEECH_SEED], LEECH_SEED, Data.typeChart, e.sideStatus) == -10)
end

---------------------------------------------------------------------------
-- Controller through the real engine
---------------------------------------------------------------------------
do
  local e = battle({ 0 }, { playerMoves = { LEECH_SEED }, foeHP = 80, playerHP = 100, playerCurrentHP = 50 })
  local c = BattleSceneController.new({ engine = e, playerName = "BULBASAUR", foeName = "RATTATA",
    introMessages = {}, moveName = function(id) return id == LEECH_SEED and "LEECH SEED" or "SPLASH" end })
  c:_runTurn(MOVE)
  local shown = {}
  while c.state == BattleSceneController.MESSAGES do
    shown[#shown + 1] = c:message()
    c:advanceMessage()
  end
  check("controller: Leech Seed turn texts in order",
    table.concat(shown, "|") == "BULBASAUR used LEECH SEED!|RATTATA was seeded!|RATTATA used SPLASH!|"
      .. "But nothing happened!|RATTATA's health is\nsapped by LEECH SEED!", table.concat(shown, "|"))
  check("controller: HP bars follow the drain", c.displayedHP.foe == 70 and c.displayedHP.player == 60)
end

print(("battle_residual_r1_test: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
