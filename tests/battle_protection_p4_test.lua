-- Run: lua5.1 tests/battle_protection_p4_test.lua
--
-- Protection slice P4 (work/tasks/phase4-protection-p4.md): Fake Out
-- (EFFECT_FAKE_OUT 158, move 252). Oracles come from pret/pokefirered
-- c75f352304d529f6ba92d4f74b9cf8b5c3810788:
--   * record src/data/battle_moves.h:3279-3290: power 40, Normal, accuracy
--     100, PP 10, chance 0, MOVE_TARGET_SELECTED, priority +1, flags
--     PROTECT_AFFECTED | MIRROR_MOVE_AFFECTED (0x12);
--   * BattleScript_EffectFakeOut data/battle_scripts_1.s:2044-2048:
--     attackcanceler, jumpifnotfirstturn
--     BattleScript_ButItFailedAtkStringPpReduce (:2050-2059: attackstring,
--     ppreduce, "But it failed!"), setmoveeffect MOVE_EFFECT_FLINCH |
--     MOVE_EFFECT_CERTAIN, goto BattleScript_EffectHit;
--   * Cmd_jumpifnotfirstturn src/battle_script_commands.c:6504-6512 (passes
--     iff isFirstTurn != 0);
--   * Cmd_seteffectwithchance :2774-2805: CERTAIN and no NO_EFFECT -> no
--     Random(); a no-effect hit falls to the `Random() % 100` arm (one
--     discarded draw);
--   * SetMoveEffect :2132-2146 (Shield Dust silent for byte 8 <= 9, a 0-HP
--     target returns) and the flinch case :2419-2439 (Inner Focus with
--     CERTAIN -> BattleScript_FlinchPrevention, data/battle_scripts_1.s
--     :4109-4113, "{B_EFF_NAME_WITH_PREFIX}'s {B_EFF_ABILITY}\nprevents
--     flinching!" src/battle_message.c:296; otherwise the bit is set only
--     when GetBattlerTurnOrderNum(target) > gCurrentTurnActionNumber);
--   * isFirstTurn: = 2 at battle start, switch-in and faint
--     (src/battle_main.c:2228, :2396, :2481); decremented if nonzero by
--     TurnValuesCleanUp(FALSE) (:3640-3641), once before turn 1 (:2909) and
--     after HandleFaintedMonActions at the end of every turn (:2964-2970);
--   * AI_CBM_FakeOut data/battle_ai_scripts.s:187, :510-513
--     (is_first_turn_for AI_USER; if_equal 0 -> -10), Cmd_is_first_turn_for
--     src/battle_ai_script_commands.c:1778-1790 (raw isFirstTurn).
-- Every expected number is worked from those formulas, never read back from
-- the engine.
package.path = package.path .. ";./?.lua"

local BattleEngine = require("src.core.BattleEngine")
local BattleSceneController = require("src.core.BattleSceneController")
local AICheckBadMove = require("src.core.AICheckBadMove")
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

local function rec(effect, power, type_, acc, pp, chance, target, priority, flags)
  return { effect = effect, power = power, type = type_, accuracy = acc, pp = pp,
    secondaryEffectChance = chance, target = target, priority = priority, flags = flags }
end

local T = Data
local FAKE_OUT, SPLASH, QUICK_ATTACK, TACKLE = 252, 150, Data.MOVE_QUICK_ATTACK, Data.MOVE_TACKLE
local moves = {}
for id, m in pairs(Data.moves) do moves[id] = m end
moves[FAKE_OUT] = rec(158, 40, T.TYPE_NORMAL, 100, 10, 0, 0, 1, 0x12) -- battle_moves.h:3279-3290
moves[SPLASH] = rec(85, 0, T.TYPE_NORMAL, 0, 40, 0, 0x10, 0, 0)
-- A 100%-accurate Tackle stand-in so the foe's hits draw exactly 3.
local BASH = 900
moves[BASH] = rec(0, 35, T.TYPE_NORMAL, 100, 35, 0, 0, 0, 0x33)

local MOVE_NAMES = { [FAKE_OUT] = "FAKE OUT", [SPLASH] = "SPLASH", [QUICK_ATTACK] = "QUICK ATTACK",
  [BASH] = "TACKLE", [TACKLE] = "TACKLE" }
local function moveName(id) return MOVE_NAMES[id] or ("MOVE " .. tostring(id)) end

local SHIELD_DUST, INNER_FOCUS = 19, 39 -- include/constants/abilities.h

local function moveList(list)
  local out = {}
  for i, id in ipairs(list) do out[i] = { move = id, pp = moves[id].pp } end
  return out
end

-- Level 10, attack/defense 20, both Psychic (Fake Out and BASH neutral, no
-- STAB). Damage oracle (CalculateBaseDamage; accuracy draw 0 -> hit, crit
-- draw 1 -> no crit (1 % 16 ~= 0), random draw 0 -> x100/100):
--   Fake Out power 40: floor(floor(6 * 40 * 20/20) / 50) + 2 = 4 + 2 = 6.
--   BASH power 35:      floor(210 / 50) + 2 = 4 + 2 = 6.
--   Quick Attack 40:    6.
local HIT = { 0, 1, 0 }
local function battle(values, opts)
  opts = opts or {}
  local engine = BattleEngine.new({
    player = BattleEngine.makeBattler({ species = 1, level = 10,
      stats = { hp = opts.playerHP or 400, attack = 20, defense = 20,
        speed = opts.playerSpeed or 30, spAttack = 20, spDefense = 20 },
      types = opts.playerTypes or { T.TYPE_PSYCHIC, T.TYPE_PSYCHIC },
      moves = moveList(opts.playerMoves or { FAKE_OUT }) }),
    foe = BattleEngine.makeBattler({ species = 19, level = 10,
      stats = { hp = opts.foeHP or 400, attack = 20, defense = 20, speed = opts.foeSpeed or 20,
        spAttack = 20, spDefense = 20 },
      types = opts.foeTypes or { T.TYPE_PSYCHIC, T.TYPE_PSYCHIC },
      moves = moveList(opts.foeMoves or { BASH }) }),
    moves = moves, typeChart = Data.typeChart, rng = scriptedRng(values or {}),
    hasReplacement = opts.hasReplacement,
  })
  engine.player.ability = opts.playerAbility or 0
  engine.foe.ability = opts.foeAbility or 0
  if opts.playerCurrentHP then engine.player.hp = opts.playerCurrentHP end
  if opts.foeCurrentHP then engine.foe.hp = opts.foeCurrentHP end
  return engine
end

local function freshBattler(moveIds, speed)
  return BattleEngine.makeBattler({ species = 7, level = 10,
    stats = { hp = 400, attack = 20, defense = 20, speed = speed or 30, spAttack = 20, spDefense = 20 },
    types = { T.TYPE_PSYCHIC, T.TYPE_PSYCHIC }, moves = moveList(moveIds or { FAKE_OUT }) })
end

local MOVE = { action = "move", moveSlot = 1 }

local function types(events)
  local out = {}
  for _, e in ipairs(events) do out[#out + 1] = e.type end
  return table.concat(out, ",")
end
local function find(events, kind, side)
  for _, e in ipairs(events) do
    if e.type == kind and (side == nil or e.side == side) then return e end
  end
end

local function texts(engine, events)
  local c = BattleSceneController.new({ engine = engine, playerName = "PLAYER", foeName = "FOE",
    introMessages = {}, moveName = moveName })
  local out = {}
  for _, entry in ipairs(c:_eventMessages(events)) do
    out[#out + 1] = entry.text or ("[hp " .. entry.hpSide .. " " .. entry.hp .. "]")
  end
  return table.concat(out, "|")
end

---------------------------------------------------------------------------
-- Admission, constants, the counter's defaults
---------------------------------------------------------------------------
do
  check("EFFECT_FAKE_OUT constant", BattleEngine.EFFECT_FAKE_OUT == 158)
  local e = battle({})
  check("Fake Out admitted", e:supportsMove(moves[FAKE_OUT], FAKE_OUT))
  check("makeBattler: isFirstTurn 2 (entered this turn)", freshBattler().isFirstTurn == 2)
  check("new: both leads 1 before turn 1 (bm.c:2228 then :2909)",
    e.player.isFirstTurn == 1 and e.foe.isFirstTurn == 1)
end

---------------------------------------------------------------------------
-- Turn 1 succeeds with a certain flinch; turn 2 fails
---------------------------------------------------------------------------
do
  local e = battle({ 0, 1, 0 })
  local ev = e:runTurn(MOVE, MOVE)
  check("turn 1: useMove,damage, foe flinched, end of turn",
    types(ev) == "turnStart,useMove,damage,flinched", types(ev))
  check("turn 1: exactly 3 draws (accuracy, crit, random; CERTAIN flinch draws none)",
    e.rng.draws == 3, e.rng.draws)
  check("turn 1: 6 damage", e.foe.hp == 394, e.foe.hp)
  check("turn 1: the flinched battler is the foe", find(ev, "flinched").side == "foe")
  check("turn 1: PP 10 -> 9", e.player.moves[1].pp == 9)
  check("turn 1: the foe's PP untouched (flinch cancels before ppreduce)", e.foe.moves[1].pp == 35)
  check("end of turn 1: both counters 0", e.player.isFirstTurn == 0 and e.foe.isFirstTurn == 0)
  check("turn 1 texts", texts(e, ev) == "PLAYER used FAKE OUT!|[hp foe 394]|FOE flinched!", texts(e, ev))

  e.rng = scriptedRng({ 0, 1, 0 })
  ev = e:runTurn(MOVE, MOVE)
  check("turn 2: useMove,moveFailed then the foe's hit",
    types(ev) == "turnStart,useMove,moveFailed,useMove,damage", types(ev))
  check("turn 2: Fake Out fails before accuracycheck (0 draws; 3 for the foe's hit)",
    e.rng.draws == 3, e.rng.draws)
  check("turn 2: PP still spent (ppreduce on the fail path) 9 -> 8", e.player.moves[1].pp == 8)
  check("turn 2: no damage to the foe", e.foe.hp == 394)
  check("turn 2: the foe hits for 6", e.player.hp == 394, e.player.hp)
  check("turn 2 texts", texts(e, ev) == "PLAYER used FAKE OUT!|But it failed!|FOE used TACKLE!|[hp player 394]",
    texts(e, ev))

  e.rng = scriptedRng({ 0, 1, 0 })
  ev = e:runTurn(MOVE, MOVE)
  check("turn 3: still fails", types(ev) == "turnStart,useMove,moveFailed,useMove,damage", types(ev))
end

---------------------------------------------------------------------------
-- Priority +1: a faster foe still moves second and flinches
---------------------------------------------------------------------------
do
  local e = battle({ 0, 1, 0 }, { playerSpeed = 10, foeSpeed = 200 })
  local ev = e:runTurn(MOVE, MOVE)
  check("priority: the slower Fake Out user moves first (no speed-tie draw)",
    types(ev) == "turnStart,useMove,damage,flinched" and ev[2].side == "player" and e.rng.draws == 3,
    types(ev) .. " draws " .. e.rng.draws)
end

---------------------------------------------------------------------------
-- The flinch applies only to a target that has not acted yet
---------------------------------------------------------------------------
do
  -- Both use Fake Out (+1 each); the faster foe goes first and flinches the
  -- player, whose Fake Out is cancelled (no PP, no draws).
  local e = battle({ 0, 1, 0 }, { playerSpeed = 10, foeSpeed = 200, foeMoves = { FAKE_OUT } })
  local ev = e:runTurn(MOVE, MOVE)
  check("Fake Out vs Fake Out: the faster foe flinches the player",
    types(ev) == "turnStart,useMove,damage,flinched" and ev[2].side == "foe"
      and find(ev, "flinched").side == "player", types(ev))
  check("Fake Out vs Fake Out: 3 draws, the player's PP kept", e.rng.draws == 3 and e.player.moves[1].pp == 10)

  -- Quick Attack (+1) from a faster foe goes first; the player's Fake Out
  -- hits second and cannot flinch the foe, who has already acted.
  e = battle({ 0, 1, 0, 0, 1, 0 }, { playerSpeed = 10, foeSpeed = 200, foeMoves = { QUICK_ATTACK } })
  ev = e:runTurn(MOVE, MOVE)
  check("moving second: the hit lands, no flinch, no text",
    types(ev) == "turnStart,useMove,damage,useMove,damage" and ev[4].side == "player"
      and not e.foe.flinched, types(ev))
  check("moving second: 6 draws", e.rng.draws == 6, e.rng.draws)
end

---------------------------------------------------------------------------
-- Shield Dust and Inner Focus
---------------------------------------------------------------------------
do
  local e = battle({ 0, 1, 0, 0, 1, 0 }, { foeAbility = SHIELD_DUST })
  local ev = e:runTurn(MOVE, MOVE)
  check("Shield Dust: silent, no flinch, the foe acts",
    types(ev) == "turnStart,useMove,damage,useMove,damage", types(ev))
  check("Shield Dust: 6 draws", e.rng.draws == 6, e.rng.draws)

  e = battle({ 0, 1, 0, 0, 1, 0 }, { foeAbility = INNER_FOCUS })
  ev = e:runTurn(MOVE, MOVE)
  check("Inner Focus: flinchPrevented, then the foe acts",
    types(ev) == "turnStart,useMove,damage,flinchPrevented,useMove,damage", types(ev))
  local fp = find(ev, "flinchPrevented")
  check("Inner Focus: event names the target and ability 39", fp.side == "foe" and fp.ability == 39)
  check("Inner Focus: 6 draws (no draw for the certain effect)", e.rng.draws == 6, e.rng.draws)
  check("Inner Focus texts",
    texts(e, ev) == "PLAYER used FAKE OUT!|[hp foe 394]|FOE's INNER FOCUS\nprevents flinching!"
      .. "|FOE used TACKLE!|[hp player 394]", texts(e, ev))

  -- The Inner Focus test precedes the turn-order test (:2421 before :2435):
  -- the text prints even when Fake Out moves second.
  e = battle({ 0, 1, 0, 0, 1, 0 }, { playerSpeed = 10, foeSpeed = 200, foeMoves = { QUICK_ATTACK },
    foeAbility = INNER_FOCUS })
  ev = e:runTurn(MOVE, MOVE)
  check("Inner Focus text even when Fake Out moves second",
    types(ev) == "turnStart,useMove,damage,useMove,damage,flinchPrevented", types(ev))

  -- A non-certain flinch (Bite-family) against Inner Focus stays silent.
  local engine = battle({}, { foeAbility = INNER_FOCUS })
  local out = {}
  engine.flinchTargetPending = true
  engine:applySecondaryStatus2("foe", engine.foe, "flinch", out)
  check("non-certain flinch vs Inner Focus: silent (unchanged C2 behaviour)",
    #out == 0 and not engine.foe.flinched)
end

---------------------------------------------------------------------------
-- A Ghost target: no effect plus one discarded draw
---------------------------------------------------------------------------
do
  local e = battle({ 0, 1, 0, 0 }, { foeTypes = { T.TYPE_GHOST, T.TYPE_GHOST }, foeMoves = { SPLASH } })
  local ev = e:runTurn(MOVE, MOVE)
  check("Ghost: noEffect, no flinch, the foe acts",
    types(ev) == "turnStart,useMove,noEffect,useMove,splash", types(ev))
  check("Ghost: 4 draws (accuracy, crit, random, discarded % 100)", e.rng.draws == 4, e.rng.draws)
  check("Ghost: PP spent", e.player.moves[1].pp == 9)
end

---------------------------------------------------------------------------
-- A KO: no flinch, no Inner Focus text (SetMoveEffect's 0-HP guard)
---------------------------------------------------------------------------
do
  local e = battle({ 0, 1, 0 }, { foeCurrentHP = 5, foeAbility = INNER_FOCUS })
  local ev = e:runTurn(MOVE, MOVE)
  check("KO: damage, faint, battleEnd; no flinchPrevented",
    types(ev) == "turnStart,useMove,damage,faint,battleEnd", types(ev))
  check("KO: 3 draws", e.rng.draws == 3, e.rng.draws)
end

---------------------------------------------------------------------------
-- Switch-ins: voluntary (2, then 1 at the end of its entry turn) and forced
---------------------------------------------------------------------------
do
  -- Turn 1: the player switches; the incoming battler is fresh (2).
  local e = battle({}, { foeMoves = { SPLASH } })
  local bench = freshBattler({ FAKE_OUT })
  bench.isFirstTurn = 0 -- a reused table: SwitchInClearSetData still sets 2
  local ev = e:runTurn({ action = "switch", battler = bench }, MOVE)
  check("voluntary switch: switch then the foe's move", types(ev) == "turnStart,switch,useMove,splash", types(ev))
  check("voluntary switch: 1 after the entry turn's end", e.player.isFirstTurn == 1, e.player.isFirstTurn)
  e.rng = scriptedRng({ 0, 1, 0 })
  ev = e:runTurn(MOVE, MOVE)
  check("voluntary switch: Fake Out works on turn N+1",
    types(ev) == "turnStart,useMove,damage,flinched", types(ev))
  ev = e:runTurn(MOVE, MOVE)
  check("voluntary switch: fails on turn N+2", types(ev) == "turnStart,useMove,moveFailed,useMove,splash", types(ev))
end

do
  -- Turn 1: the foe knocks the 1-HP player out; the replacement arrives
  -- after the end of turn 1 and its first turn is turn 2.
  local e = battle({ 0, 1, 0 }, { playerCurrentHP = 1, playerMoves = { SPLASH }, foeSpeed = 200,
    hasReplacement = function() return true end })
  local ev = e:runTurn(MOVE, MOVE)
  check("forced: the player faints, replacement pending",
    types(ev) == "turnStart,useMove,damage,faint,forcedSwitchNeeded", types(ev))
  check("forced: the fainted battler holds 2 again (FaintClearSetData), then the end-of-turn decrement",
    e.player.isFirstTurn == 1, e.player.isFirstTurn)
  local replacement = freshBattler({ FAKE_OUT }, 10)
  e:resolveForcedSwitch("player", replacement)
  check("forced: the replacement starts at 1", e.player.isFirstTurn == 1, e.player.isFirstTurn)
  check("forced: the foe is at 0 after two decrements", e.foe.isFirstTurn == 0)
  e.rng = scriptedRng({ 0, 1, 0 })
  ev = e:runTurn(MOVE, MOVE)
  check("forced: Fake Out works on the replacement's first turn (N+1)",
    types(ev) == "turnStart,useMove,damage,flinched" and ev[2].side == "player", types(ev))
  e.rng = scriptedRng({ 0, 1, 0 })
  ev = e:runTurn(MOVE, MOVE)
  check("forced: fails on N+2", types(ev) == "turnStart,useMove,moveFailed,useMove,damage", types(ev))
end

do
  -- The foe side: the player knocks the foe out; its replacement's Fake Out
  -- works on the next turn.
  local e = battle({ 0, 1, 0 }, { playerMoves = { BASH }, foeCurrentHP = 1, foeMoves = { SPLASH },
    hasReplacement = function() return true end })
  local ev = e:runTurn(MOVE, MOVE)
  check("forced foe: faint and replacement pending",
    types(ev) == "turnStart,useMove,damage,faint,forcedSwitchNeeded", types(ev))
  local replacement = freshBattler({ FAKE_OUT }, 10)
  e:resolveForcedSwitch("foe", replacement)
  e.rng = scriptedRng({ 0, 1, 0 })
  ev = e:runTurn(MOVE, MOVE)
  check("forced foe: its Fake Out works and flinches the player",
    types(ev) == "turnStart,useMove,damage,flinched" and ev[2].side == "foe"
      and find(ev, "flinched").side == "player", types(ev))
end

do
  -- recordFaint resets the fainted battler's counter to 2.
  local e = battle({})
  e.player.isFirstTurn = 0
  e.player.hp = 0
  e:beginFaintSequence()
  e:recordFaint("player", {})
  check("recordFaint: isFirstTurn = 2 (bm.c:2481)", e.player.isFirstTurn == 2)
end

---------------------------------------------------------------------------
-- AI_CBM_FakeOut
---------------------------------------------------------------------------
do
  local e = battle({ 0, 1, 0 }, { foeMoves = { FAKE_OUT }, playerMoves = { SPLASH } })
  local score = function()
    return AICheckBadMove.score(e.foe, e.player, moves[FAKE_OUT], FAKE_OUT, e.typeChart, e.sideStatus)
  end
  check("AI: first turn (isFirstTurn 1) -> 0, no error", score() == 0, score())
  e:runTurn(MOVE, MOVE)
  check("AI: after turn 1 (isFirstTurn 0) -> -10", score() == -10, score())
  local ghost = battle({}, { playerTypes = { T.TYPE_GHOST, T.TYPE_GHOST } })
  check("AI: vs a Ghost the type check returns -10 first",
    AICheckBadMove.score(ghost.foe, ghost.player, moves[FAKE_OUT], FAKE_OUT, ghost.typeChart, ghost.sideStatus) == -10)
  check("AI: raw value 2 -> 0 (only 0 is penalised)",
    AICheckBadMove.score({ isFirstTurn = 2 }, e.player, moves[FAKE_OUT], FAKE_OUT, e.typeChart, e.sideStatus) == 0)
end

print(("battle_protection_p4_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
