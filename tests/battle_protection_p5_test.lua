-- Run: lua5.1 tests/battle_protection_p5_test.lua
--
-- Protection slice P5 (work/tasks/phase4-protection-p5.md): Focus Punch
-- (EFFECT_FOCUS_PUNCH 170, move 264). Oracles come from pret/pokefirered
-- c75f352304d529f6ba92d4f74b9cf8b5c3810788:
--   * record src/data/battle_moves.h:3435-3446: power 150, Fighting,
--     accuracy 100, PP 20, chance 0, MOVE_TARGET_SELECTED, priority -3,
--     flags MAKES_CONTACT | PROTECT_AFFECTED (0x03);
--   * CheckFocusPunch_ClearVarsBeforeTurnStarts src/battle_main.c:3669-3702
--     (after selection and SetActionsAndBattlersTurnOrder, :3578-3579,
--     :3619-3620): skipped while HITMARKER_RUN; per battler in battler-id
--     order, gChosenMoveByBattler == MOVE_FOCUS_PUNCH, not STATUS1_SLEEP,
--     no Truant, not noValidMoves -> BattleScript_FocusPunchSetUp
--     (data/battle_scripts_1.s:3649-3655), "{B_ATK_NAME_WITH_PREFIX} is
--     tightening\nits focus!" (src/battle_message.c:224). No RNG;
--   * HITMARKER_RUN: set at B_ACTION_RUN's CASE_CHOSEN
--     (src/battle_main.c:3326-3328), cleared only at battle start (:2257);
--   * BattleScript_EffectFocusPunch data/battle_scripts_1.s:2255-2261:
--     attackcanceler, jumpifnodamage BattleScript_HitFromAccCheck
--     (src/battle_script_commands.c:8757-8763), ppreduce, "lost its\nfocus
--     and couldn't move!" (src/battle_message.c:254) -- no attackstring;
--   * Cmd_datahpupdate src/battle_script_commands.c:1822-1854: physicalDmg/
--     specialDmg = gHpDealt for non-passive HP loss, Pain Split excluded;
--     gProtectStructs is cleared by TurnValuesCleanUp(FALSE) every turn
--     (src/battle_main.c:3637-3639).
-- Every expected number is worked from those formulas, never read back from
-- the engine.
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

local function rec(effect, power, type_, acc, pp, chance, target, priority, flags)
  return { effect = effect, power = power, type = type_, accuracy = acc, pp = pp,
    secondaryEffectChance = chance, target = target, priority = priority, flags = flags }
end

local T = Data
local FOCUS_PUNCH, SPLASH, PAIN_SPLIT, FALSE_SWIPE, THRASH = 264, 150, 220, 206, 37
local TACKLE = Data.MOVE_TACKLE -- accuracy 95 (a 99 draw misses)
local moves = {}
for id, m in pairs(Data.moves) do moves[id] = m end
moves[FOCUS_PUNCH] = rec(170, 150, T.TYPE_FIGHTING, 100, 20, 0, 0, -3, 0x03) -- battle_moves.h:3435-3446
moves[SPLASH] = rec(85, 0, T.TYPE_NORMAL, 0, 40, 0, 0x10, 0, 0)
moves[PAIN_SPLIT] = rec(91, 0, T.TYPE_NORMAL, 100, 20, 0, 0, 0, 0x02)
moves[FALSE_SWIPE] = rec(101, 40, T.TYPE_NORMAL, 100, 40, 0, 0, 0, 0x33)
moves[THRASH] = rec(27, 90, T.TYPE_NORMAL, 100, 20, 100, 0x04, 0, 0x33)
local BASH = 900 -- a 100%-accurate Tackle stand-in: exactly 3 draws per hit
moves[BASH] = rec(0, 35, T.TYPE_NORMAL, 100, 35, 0, 0, 0, 0x33)

local MOVE_NAMES = { [FOCUS_PUNCH] = "FOCUS PUNCH", [SPLASH] = "SPLASH", [BASH] = "TACKLE" }
local function moveName(id) return MOVE_NAMES[id] or ("MOVE " .. tostring(id)) end

local function moveList(list)
  local out = {}
  for i, id in ipairs(list) do out[i] = { move = id, pp = moves[id].pp } end
  return out
end

-- Level 10, attack/defense 20. The player is Psychic, the foe Water.
-- Damage oracle (accuracy draw 0 -> hit, crit draw 1 -> no crit, random 0):
--   Focus Punch 150 vs Water (neutral, no STAB): floor(6*150/50) + 2 = 20.
--   BASH 35 vs Psychic (neutral, no STAB):       floor(6*35/50) + 2 = 6.
--   False Swipe 40 vs Psychic:                   floor(6*40/50) + 2 = 6.
local function battle(values, opts)
  opts = opts or {}
  local engine = BattleEngine.new({
    player = BattleEngine.makeBattler({ species = 1, level = 10,
      stats = { hp = opts.playerHP or 400, attack = 20, defense = 20,
        speed = opts.playerSpeed or 30, spAttack = 20, spDefense = 20 },
      types = opts.playerTypes or { T.TYPE_PSYCHIC, T.TYPE_PSYCHIC },
      status = opts.playerStatus, moves = moveList(opts.playerMoves or { FOCUS_PUNCH }) }),
    foe = BattleEngine.makeBattler({ species = 19, level = 10,
      stats = { hp = opts.foeHP or 400, attack = 20, defense = 20, speed = opts.foeSpeed or 20,
        spAttack = 20, spDefense = 20 },
      types = opts.foeTypes or { T.TYPE_WATER, T.TYPE_WATER },
      status = opts.foeStatus, moves = moveList(opts.foeMoves or { BASH }) }),
    moves = moves, typeChart = Data.typeChart, rng = scriptedRng(values or {}),
  })
  engine.player.ability = 0
  engine.foe.ability = 0
  if opts.playerCurrentHP then engine.player.hp = opts.playerCurrentHP end
  if opts.foeCurrentHP then engine.foe.hp = opts.foeCurrentHP end
  return engine
end

local MOVE = { action = "move", moveSlot = 1 }

local function types(events)
  local out = {}
  for _, e in ipairs(events) do out[#out + 1] = e.type .. (e.side and (":" .. e.side) or "") end
  return table.concat(out, ",")
end
local function count(events, kind)
  local n = 0
  for _, e in ipairs(events) do if e.type == kind then n = n + 1 end end
  return n
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
-- Admission, constants, defaults
---------------------------------------------------------------------------
do
  check("constants", BattleEngine.EFFECT_FOCUS_PUNCH == 170 and BattleEngine.MOVE_FOCUS_PUNCH == 264)
  local e = battle({})
  check("Focus Punch admitted", e:supportsMove(moves[FOCUS_PUNCH], FOCUS_PUNCH))
  check("defaults: tookMoveDamage false, runAttempted false",
    e.player.tookMoveDamage == false and e.foe.tookMoveDamage == false and e.runAttempted == false)
end

---------------------------------------------------------------------------
-- Lost focus: the foe's hit lands first (priority -3)
---------------------------------------------------------------------------
do
  local e = battle({ 0, 1, 0 }, { playerSpeed = 200 })
  local ev = e:runTurn(MOVE, MOVE)
  check("lost focus: setup first, the foe hits, focusLost with no useMove",
    types(ev) == "turnStart,focusPunchSetup:player,useMove:foe,damage:foe,focusLost:player", types(ev))
  check("lost focus: 3 draws (the foe's hit only)", e.rng.draws == 3, e.rng.draws)
  check("lost focus: PP spent 20 -> 19", e.player.moves[1].pp == 19)
  check("lost focus: no damage to the foe", e.foe.hp == 400)
  check("lost focus: the player took 6", e.player.hp == 394, e.player.hp)
  check("lost focus texts",
    texts(e, ev) == "PLAYER is tightening\nits focus!|FOE used TACKLE!|[hp player 394]"
      .. "|PLAYER lost its\nfocus and couldn't move!", texts(e, ev))

  -- Damage taken last turn does not count: the record is per turn.
  e.rng = scriptedRng({ 0, 1, 0 })
  e.foe.moves[1] = { move = SPLASH, pp = 40 }
  ev = e:runTurn(MOVE, MOVE)
  check("next turn: the record was reset, Focus Punch hits",
    types(ev) == "turnStart,focusPunchSetup:player,useMove:foe,splash,useMove:player,damage:player", types(ev))
  check("next turn: 20 damage, 3 draws", e.foe.hp == 380 and e.rng.draws == 3, e.foe.hp .. " " .. e.rng.draws)
end

---------------------------------------------------------------------------
-- Focus kept: no hit, a miss, a no-effect hit, Pain Split, a 0-HP hit
---------------------------------------------------------------------------
do
  local e = battle({ 0, 1, 0 }, { foeMoves = { SPLASH } })
  local ev = e:runTurn(MOVE, MOVE)
  check("no hit: setup, Splash, Focus Punch hits for 20",
    types(ev) == "turnStart,focusPunchSetup:player,useMove:foe,splash,useMove:player,damage:player"
      and e.foe.hp == 380 and e.rng.draws == 3, types(ev))

  -- Tackle (accuracy 95): draw 99 -> 99 % 100 + 1 = 100 > 95, a miss.
  e = battle({ 99, 0, 1, 0 }, { foeMoves = { TACKLE } })
  ev = e:runTurn(MOVE, MOVE)
  check("miss: focus kept",
    types(ev) == "turnStart,focusPunchSetup:player,useMove:foe,miss:foe,useMove:player,damage:player"
      and e.rng.draws == 4, types(ev))

  -- A Normal hit against a Ghost player: no effect, no HP loss.
  e = battle({ 0, 1, 0, 0, 1, 0 }, { playerTypes = { T.TYPE_GHOST, T.TYPE_GHOST } })
  ev = e:runTurn(MOVE, MOVE)
  check("no-effect hit: focus kept",
    types(ev) == "turnStart,focusPunchSetup:player,useMove:foe,noEffect:foe,useMove:player,damage:player"
      and e.rng.draws == 6, types(ev))

  -- Pain Split: average floor((400 + 100) / 2) = 250, the player loses
  -- 150, but Pain Split is excluded from the record.
  e = battle({ 0, 1, 0 }, { foeMoves = { PAIN_SPLIT }, foeCurrentHP = 100 })
  ev = e:runTurn(MOVE, MOVE)
  check("Pain Split: HP lost, focus kept",
    e.player.hp == 250 and count(ev, "focusLost") == 0 and count(ev, "damage") == 1
      and e.foe.hp == 230, types(ev) .. " " .. e.player.hp .. " " .. e.foe.hp)
  check("Pain Split: 3 draws (Focus Punch only)", e.rng.draws == 3, e.rng.draws)

  -- False Swipe against a 1-HP Focus Punch user: hp - 1 = 0 damage, gHpDealt
  -- 0, nothing recorded.
  e = battle({ 0, 1, 0, 0, 1, 0 }, { foeMoves = { FALSE_SWIPE }, playerCurrentHP = 1 })
  ev = e:runTurn(MOVE, MOVE)
  check("0-damage False Swipe: focus kept",
    types(ev) == "turnStart,focusPunchSetup:player,useMove:foe,damage:foe,useMove:player,damage:player"
      and e.player.hp == 1 and ev[4].amount == 0 and e.rng.draws == 6, types(ev))
end

---------------------------------------------------------------------------
-- Both use Focus Punch: battler-id order for the texts, turn order for the
-- hits
---------------------------------------------------------------------------
do
  local e = battle({ 0, 1, 0 }, { playerSpeed = 30, foeSpeed = 20, foeMoves = { FOCUS_PUNCH } })
  local ev = e:runTurn(MOVE, MOVE)
  check("both, player faster: texts player then foe; the player hits; the foe loses focus",
    types(ev) == "turnStart,focusPunchSetup:player,focusPunchSetup:foe,useMove:player,damage:player,focusLost:foe",
    types(ev))
  check("both, player faster: 3 draws, foe PP spent", e.rng.draws == 3 and e.foe.moves[1].pp == 19)

  -- Foe faster: Fighting vs Psychic is x0.5 -> floor(20 * 5 / 10) = 10.
  e = battle({ 0, 1, 0 }, { playerSpeed = 10, foeSpeed = 200, foeMoves = { FOCUS_PUNCH } })
  ev = e:runTurn(MOVE, MOVE)
  check("both, foe faster: texts still player first (battler-id order)",
    types(ev) == "turnStart,focusPunchSetup:player,focusPunchSetup:foe,useMove:foe,damage:foe,focusLost:player",
    types(ev))
  check("both, foe faster: 10 damage", e.player.hp == 390, e.player.hp)
end

---------------------------------------------------------------------------
-- No setup text: asleep, locked (recharging), Struggle
---------------------------------------------------------------------------
do
  -- Asleep with 3 turns: no text; the canceller decrements to 2.
  local e = battle({ 0, 1, 0 }, { playerStatus = S.withSleepTurns(0, 3) })
  local ev = e:runTurn(MOVE, MOVE)
  check("asleep: no text, fastAsleep",
    types(ev) == "turnStart,useMove:foe,damage:foe,fastAsleep:player", types(ev))

  -- Asleep with 1 turn: asleep at the hook (no text), wakes up at the
  -- canceller, then loses focus because the foe's hit landed.
  e = battle({ 0, 1, 0 }, { playerStatus = S.withSleepTurns(0, 1) })
  ev = e:runTurn(MOVE, MOVE)
  check("waking this turn: no text, wokeUp, then focusLost",
    types(ev) == "turnStart,useMove:foe,damage:foe,wokeUp:player,focusLost:player", types(ev))

  -- Recharging: the side skips selection (chosen move MOVE_NONE).
  e = battle({}, { foeMoves = { SPLASH } })
  e.player.recharging, e.player.rechargeTimer, e.player.lockedSlot = true, 2, 1
  ev = e:runTurn(MOVE, MOVE)
  check("locked: no text", count(ev, "focusPunchSetup") == 0 and count(ev, "mustRecharge") == 1, types(ev))

  -- A locked Thrash with Focus Punch in another slot: the action is the
  -- locked move.
  e = battle({ 0, 1, 0, 0 }, { playerMoves = { THRASH, FOCUS_PUNCH }, foeMoves = { SPLASH } })
  e.player.rampageTurns, e.player.lockedSlot = 2, 1
  ev = e:runTurn({ action = "move", moveSlot = 2 }, MOVE)
  check("locked rampage: no text", count(ev, "focusPunchSetup") == 0, types(ev))

  -- Every slot at 0 PP: noValidMoves, Struggle.
  e = battle({ 0, 1, 0 }, { foeMoves = { SPLASH } })
  e.player.moves[1].pp = 0
  ev = e:runTurn(MOVE, MOVE)
  check("Struggle: no text", count(ev, "focusPunchSetup") == 0 and ev[4] and ev[4].move == 165, types(ev))
end

---------------------------------------------------------------------------
-- The text ignores freeze, paralysis and confusion
---------------------------------------------------------------------------
do
  -- Frozen: freeze draw 1 (1 % 5 ~= 0) keeps it frozen.
  local e = battle({ 1 }, { playerStatus = S.FREEZE, foeMoves = { SPLASH } })
  local ev = e:runTurn(MOVE, MOVE)
  check("frozen: text, then frozenSolid",
    types(ev) == "turnStart,focusPunchSetup:player,useMove:foe,splash,frozenSolid:player", types(ev))

  -- Paralyzed: draw 1 (1 % 4 ~= 0), the move proceeds.
  e = battle({ 1, 0, 1, 0 }, { playerStatus = S.PARALYSIS, foeMoves = { SPLASH } })
  ev = e:runTurn(MOVE, MOVE)
  check("paralyzed: text, Focus Punch hits",
    types(ev) == "turnStart,focusPunchSetup:player,useMove:foe,splash,useMove:player,damage:player"
      and e.rng.draws == 4, types(ev))

  -- Confused: still confused after the decrement, `& 1` draw 1 proceeds.
  e = battle({ 1, 0, 1, 0 }, { foeMoves = { SPLASH } })
  e.player.confusionTurns = 3
  ev = e:runTurn(MOVE, MOVE)
  check("confused: text, confusedTurn, Focus Punch hits",
    types(ev) == "turnStart,focusPunchSetup:player,useMove:foe,splash,confusedTurn:player,useMove:player,damage:player",
    types(ev))
end

---------------------------------------------------------------------------
-- The text precedes a switch; the user then moves after the foe's switch
-- target arrives (the foe's Focus Punch hits the incoming battler)
---------------------------------------------------------------------------
do
  local e = battle({ 0, 1, 0 }, { playerMoves = { SPLASH }, foeMoves = { FOCUS_PUNCH } })
  local bench = BattleEngine.makeBattler({ species = 7, level = 10,
    stats = { hp = 400, attack = 20, defense = 20, speed = 30, spAttack = 20, spDefense = 20 },
    types = { T.TYPE_NORMAL, T.TYPE_NORMAL }, moves = moveList({ SPLASH }) })
  local ev = e:runTurn({ action = "switch", battler = bench }, MOVE)
  -- Fighting vs Normal x2: 20 * 2 = 40.
  check("switch turn: the foe's text precedes the switch, its Focus Punch hits",
    types(ev) == "turnStart,focusPunchSetup:foe,switch:player,useMove:foe,damage:foe" and bench.hp == 360,
    types(ev) .. " " .. bench.hp)
end

---------------------------------------------------------------------------
-- The run latch (decision D4): a failed run silences every later setup
---------------------------------------------------------------------------
do
  -- Player speed 10 vs 200: speedVar = floor(10 * 128 / 200) = 6; draw 255
  -- -> 255 & 0xFF = 255 >= 6, the run fails. The foe's Focus Punch then
  -- hits the player: Fighting vs Psychic x0.5 = 10.
  local e = battle({ 255, 0, 1, 0 }, { playerSpeed = 10, foeSpeed = 200, playerMoves = { FOCUS_PUNCH },
    foeMoves = { FOCUS_PUNCH } })
  local ev = e:runTurn({ action = "run" }, MOVE)
  check("run turn: no text for the foe's Focus Punch (HITMARKER_RUN set at selection)",
    types(ev) == "turnStart,run:player,useMove:foe,damage:foe" and e.runAttempted == true, types(ev))
  check("run turn: 4 draws", e.rng.draws == 4, e.rng.draws)

  e.rng = scriptedRng({ 0, 1, 0 })
  ev = e:runTurn(MOVE, MOVE)
  check("after a failed run: no text for either side, Focus Punch still works",
    types(ev) == "turnStart,useMove:foe,damage:foe,focusLost:player", types(ev))
  e.rng = scriptedRng({ 0, 1, 0 })
  ev = e:runTurn(MOVE, MOVE)
  check("still silenced two turns later", count(ev, "focusPunchSetup") == 0, types(ev))
end

---------------------------------------------------------------------------
-- The record: applyDamage only, opposing battler only, nonzero only;
-- recordFaint clears it
---------------------------------------------------------------------------
do
  local e = battle({})
  local out = {}
  e:applyDamage("foe", "player", e.player, 0, {}, out)
  check("record: 0 damage records nothing", e.player.tookMoveDamage == false)
  e:applyDamage("foe", "player", e.player, 3, {}, out)
  check("record: nonzero damage from the other side", e.player.tookMoveDamage == true)
  e:applyDamage("player", "player", e.player, 3, {}, out)
  e.foe.tookMoveDamage = false
  e:applyDamage("player", "player", e.foe, 3, {}, out)
  check("record: same-side application records nothing", e.foe.tookMoveDamage == false)
  e.player.hp = 0
  e:beginFaintSequence()
  e:recordFaint("player", {})
  check("recordFaint clears the record (FaintClearSetData)", e.player.tookMoveDamage == false)
end

---------------------------------------------------------------------------
-- Controller: the setup text heads the turn's messages (_runTurn)
---------------------------------------------------------------------------
do
  local e = battle({ 0, 1, 0 })
  local c = BattleSceneController.new({ engine = e, playerName = "PIKACHU", foeName = "EKANS",
    introMessages = {}, moveName = moveName })
  while c.state == BattleSceneController.MESSAGES do c:advanceMessage() end
  c:_runTurn(MOVE)
  local shown = {}
  while c.state == BattleSceneController.MESSAGES do
    shown[#shown + 1] = c:message()
    c:advanceMessage()
  end
  check("controller: setup first, the foe's move, lost focus with no used line",
    table.concat(shown, "|") == "PIKACHU is tightening\nits focus!|EKANS used TACKLE!"
      .. "|PIKACHU lost its\nfocus and couldn't move!", table.concat(shown, "|"))
end

print(("battle_protection_p5_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
