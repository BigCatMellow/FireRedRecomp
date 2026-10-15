-- Run: lua5.1 tests/battle_residual_r2_test.lua
--
-- Residual slice R2 (work/tasks/phase4-residual-r2.md): the escape-prevention
-- core (BattleEngine:runBlocked/switchBlocked, the runTurn asserts, the
-- controller RUN and PARTY vetoes and the onVoluntarySwitchChoice wrapper,
-- review F4/F5), Ingrain (with its end-of-turn heal), Mean Look / Spider Web /
-- Block (cleared with clearHeldBy on the preventer's faint or switch), the AI
-- rows and the texts. Oracles come from pret/pokefirered
-- c75f352304d529f6ba92d4f74b9cf8b5c3810788:
--   * IsRunningFromBattleImpossible src/battle_main.c:3002-3058 (Run Away
--     SUCCESS first :3013-3016; ESCAPE_PREVENTION | WRAPPED or ROOTED ->
--     FORBIDDEN :3047-3052);
--   * HandleTurnActionSelectionState :3196-3200 (B_ACTION_SWITCH with those
--     bits -> PARTY_ACTION_CANT_SWITCH, no Run Away bypass) and :3239-3253
--     (the trainer-battle text first, then BattleScript_PrintCantEscape
--     FromBattle, a selection script: no turn, no RNG, no runTries);
--   * TrySwitchInPokemon src/party_menu.c:5960-5966 + gText_PkmnCantSwitchOut
--     src/strings.c:256 ("{active} can't be switched\nout!", stays in menu);
--   * Ingrain data/battle_scripts_1.s:2372-2380, Cmd_trysetroots
--     src/battle_script_commands.c:8933-8944; ENDTURN_INGRAIN
--     src/battle_util.c:760-773 (ROOTED, hp != maxHP, hp != 0,
--     max(1, maxHP/16)); BattleScript_IngrainTurnHeal bs1.s:3553-3560 (text,
--     then datahpupdate); the case order src/battle_util.c:720-742 (Ingrain
--     first, then Rain Dish, Leech Seed, poison);
--   * Mean Look bs1.s:1440-1453 (accuracycheck NO_ACC_CALC: no draw, a
--     semi-invulnerable target fails, bsc.c:1020-1025; already prevented ->
--     But it failed); MOVE_EFFECT_PREVENT_ESCAPE bsc.c:2673-2677;
--   * clearing: SwitchInClearSetData src/battle_main.c:2339-2343, :2365-2368;
--     FaintClearSetData :2441-2452;
--   * AI data/battle_ai_scripts.s:434-436 (AI_CBM_CantEscape), :554-556
--     (AI_CBM_Ingrain);
--   * texts src/battle_message.c:197, :234, :235, :333.
-- Every expected number is worked from those formulas in the comments, never
-- read back from the engine.
package.path = package.path .. ";./?.lua"

local BattleEngine = require("src.core.BattleEngine")
local BattleSceneController = require("src.core.BattleSceneController")
local AICheckBadMove = require("src.core.AICheckBadMove")
local InputState = require("src.core.InputState")
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
local SPIDER_WEB, MEAN_LOOK, BLOCK, INGRAIN = 169, 212, 335, 275
local LEECH_SEED, SPLASH = 73, 150
local moves = {}
for id, m in pairs(Data.moves) do moves[id] = m end
moves[SPIDER_WEB] = rec(106, 0, T.TYPE_BUG, 100, 10, 0, 0, 0x16)   -- :2200-2211
moves[MEAN_LOOK] = rec(106, 0, T.TYPE_NORMAL, 100, 5, 0, 0, 0x16)  -- :2759-2770
moves[BLOCK] = rec(106, 0, T.TYPE_NORMAL, 100, 5, 0, 0, 0x16)      -- :4358-4369
moves[INGRAIN] = rec(181, 0, T.TYPE_GRASS, 100, 20, 0, 0x10, 0x08) -- :3578-3589
moves[LEECH_SEED] = rec(84, 0, T.TYPE_GRASS, 90, 10, 0, 0, 0x16)
moves[SPLASH] = rec(85, 0, T.TYPE_NORMAL, 0, 40, 0, 0x10, 0)

local RAIN_DISH, RUN_AWAY = 44, 50 -- include/constants/abilities.h

local function moveList(list)
  local out = {}
  for i, id in ipairs(list) do out[i] = { move = id, pp = moves[id].pp } end
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

local function freshBattler(hp)
  return BattleEngine.makeBattler({ species = 7, level = 10,
    stats = { hp = hp or 400, attack = 20, defense = 20, speed = 30, spAttack = 20, spDefense = 20 },
    types = { T.TYPE_WATER, T.TYPE_WATER }, moves = moveList({ SPLASH }) })
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
local function press(controller, key)
  local input = InputState.new(); input:update(0); input:update(key)
  controller:processInput(input)
end
local function drain(c)
  local shown = {}
  while c.state == BattleSceneController.MESSAGES do
    shown[#shown + 1] = c:message()
    c:advanceMessage()
  end
  return shown
end
-- Only the end-of-turn per-battler residual events.
local RESIDUAL = { ingrainHeal = true, rainDish = true, leechSeedDrain = true, statusDamage = true,
  weatherDamage = true, faint = true, battleEnd = true, forcedSwitchNeeded = true }
local function residual(events)
  local out = {}
  for _, e in ipairs(events) do
    if RESIDUAL[e.type] then out[#out + 1] = e.type .. ":" .. tostring(e.side or e.outcome) end
  end
  return table.concat(out, ",")
end

---------------------------------------------------------------------------
-- Admission and defaults
---------------------------------------------------------------------------
do
  local e = battle()
  check("supportsMove admits Spider Web, Mean Look, Block and Ingrain",
    e:supportsMove(moves[SPIDER_WEB], SPIDER_WEB) and e:supportsMove(moves[MEAN_LOOK], MEAN_LOOK)
      and e:supportsMove(moves[BLOCK], BLOCK) and e:supportsMove(moves[INGRAIN], INGRAIN))
  check("a damaging or non-SELECTED Mean Look record is refused",
    not e:supportsMove(rec(106, 0, 0, 100, 5, 0, 0x10, 0), 9001))
  check("a non-USER Ingrain record is refused", not e:supportsMove(rec(181, 0, 12, 100, 20, 0, 0, 0), 9002))
  check("battle-only fields default false", e.player.rooted == false and e.player.escapePrevented == false)
  check("runBlocked/switchBlocked false by default",
    not e:runBlocked("player") and not e:switchBlocked("player") and not e:runBlocked("foe"))
end

---------------------------------------------------------------------------
-- Engine queries (IsRunningFromBattleImpossible / the switch selection test)
---------------------------------------------------------------------------
do
  local e = battle()
  e.player.rooted = true
  check("rooted blocks run and switch", e:runBlocked("player") and e:switchBlocked("player"))
  e.player.rooted = false
  e.player.escapePrevented = true
  check("escape prevention blocks run and switch", e:runBlocked("player") and e:switchBlocked("player"))
  e.player.escapePrevented = false
  e.player.wrapTurns = 3 -- residual R3's STATUS2_WRAPPED counter; the term lands in R2
  check("a wrap counter blocks run and switch", e:runBlocked("player") and e:switchBlocked("player"))
  e.player.wrapTurns = 0
  e.player.rooted, e.player.escapePrevented = true, true
  e.player.ability = RUN_AWAY
  check("Run Away bypasses the run veto (:3013-3016) but not the switch veto (:3198)",
    not e:runBlocked("player") and e:switchBlocked("player"))
  e.foe.rooted = true
  check("queries are per side", e:runBlocked("foe") and e:switchBlocked("foe"))
end

---------------------------------------------------------------------------
-- runTurn asserts (source never produces these actions)
---------------------------------------------------------------------------
do
  local e = battle({})
  e.player.rooted = true
  local ok = pcall(e.runTurn, e, { action = "run" }, MOVE)
  check("runTurn asserts on a blocked run", not ok)
  check("the asserted run changed nothing (turn, RNG, runTries)",
    e.turn == 0 and e.rng.draws == 0 and e.runTries == 0 and not e:isOver())
  ok = pcall(e.runTurn, e, { action = "switch", battler = freshBattler() }, MOVE)
  check("runTurn asserts on a blocked switch", not ok and e.turn == 0 and e.player.rooted)

  e = battle({})
  e.player.escapePrevented = true
  check("escape prevention: run and switch both assert",
    not pcall(e.runTurn, e, { action = "run" }, MOVE)
      and not pcall(e.runTurn, e, { action = "switch", battler = freshBattler() }, MOVE))
  check("a blocked player may still use a move", pcall(e.runTurn, e, MOVE, MOVE) and e.turn == 1)

  e = battle({})
  e.player.ability = RUN_AWAY
  e.player.rooted = true
  check("Run Away: a rooted holder's switch still asserts",
    not pcall(e.runTurn, e, { action = "switch", battler = freshBattler() }, MOVE))
end

---------------------------------------------------------------------------
-- Ingrain: the move
---------------------------------------------------------------------------
do
  local e = battle({}, { playerMoves = { INGRAIN } })
  local events = {}
  e:resolveMove("player", 1, events)
  check("Ingrain: rooted, no draw, PP 20 -> 19",
    e.player.rooted and e.rng.draws == 0 and e.player.moves[1].pp == 19)
  check("Ingrain: useMove then rootsPlanted", types(events) == "useMove,rootsPlanted"
    and events[2].side == "player", types(events))
  check("Ingrain text", joined(texts(e, events)) == "PLAYER used MOVE 275!|PLAYER planted its roots!",
    joined(texts(e, events)))
  events = {}
  e:resolveMove("player", 1, events)
  check("Ingrain repeat: But it failed, PP spent, no draw", types(events) == "useMove,moveFailed"
    and e.player.moves[1].pp == 18 and e.rng.draws == 0 and e.player.rooted, types(events))
  check("Ingrain vs a semi-invulnerable foe still works (USER target, no accuracycheck)", (function()
    local e2 = battle({}, { playerMoves = { INGRAIN } })
    e2.foe.semiInvulnerable = "air"
    local ev = {}
    e2:resolveMove("player", 1, ev)
    return e2.player.rooted and find(ev, "rootsPlanted") ~= nil and e2.rng.draws == 0
  end)())
end

---------------------------------------------------------------------------
-- Ingrain: end of turn (ENDTURN_INGRAIN, the first per-battler case)
---------------------------------------------------------------------------
do
  -- maxHP 400 -> max(1, 400/16) = 25. 300 -> 325.
  local e = battle({}, { playerCurrentHP = 300 })
  e.player.rooted = true
  local events = e:runTurn(MOVE, MOVE)
  local heal = find(events, "ingrainHeal", "player")
  check("Ingrain heal: 25 of 400, 0 draws", heal and heal.amount == 25 and heal.hpRemaining == 325
    and e.player.hp == 325 and e.rng.draws == 0)
  local shown = texts(e, events)
  check("Ingrain heal: text before the HP change", shown[#shown - 1] == "PLAYER absorbed\nnutrients with its roots!"
    and shown[#shown] == "[hp player 325]", joined(shown))

  -- Full HP: no heal, no text.
  e = battle({})
  e.player.rooted = true
  events = e:runTurn(MOVE, MOVE)
  check("Ingrain at full HP: nothing", not find(events, "ingrainHeal") and e.player.hp == 400)

  -- Clamp: 390/400 heals 10 (datahpupdate clamps at maxHP).
  e = battle({}, { playerCurrentHP = 390 })
  e.player.rooted = true
  events = e:runTurn(MOVE, MOVE)
  heal = find(events, "ingrainHeal", "player")
  check("Ingrain heal clamped at maxHP", heal and heal.amount == 10 and e.player.hp == 400)

  -- Minimum 1: maxHP 15 -> 15/16 = 0 -> 1.
  e = battle({}, { playerHP = 15, playerCurrentHP = 10 })
  e.player.rooted = true
  events = e:runTurn(MOVE, MOVE)
  heal = find(events, "ingrainHeal", "player")
  check("Ingrain heal minimum 1", heal and heal.amount == 1 and e.player.hp == 11)

  -- The foe heals too (no foe run/switch is modeled; only the heal shows).
  e = battle({}, { foeCurrentHP = 100 })
  e.foe.rooted = true
  events = e:runTurn(MOVE, MOVE)
  heal = find(events, "ingrainHeal", "foe")
  check("a rooted foe heals 25", heal and e.foe.hp == 125)
end

do
  -- Order on one battler: Ingrain < Rain Dish < Leech Seed < poison.
  -- Player 300/400 in rain with Rain Dish, seeded, poisoned:
  --   Ingrain +25 -> 325; Rain Dish max(1, 400/16) = 25 -> 350;
  --   Leech Seed max(1, 400/8) = 50 -> 300 (the full-HP foe heals 0);
  --   poison max(1, 400/8) = 50 -> 250.
  local e = battle({}, { playerCurrentHP = 300, playerAbility = RAIN_DISH,
    playerStatus = S.POISON })
  e.weather = { kind = "rain", permanent = true }
  e.player.rooted, e.player.seeded = true, true
  local events = e:runTurn(MOVE, MOVE)
  check("order: Ingrain, Rain Dish, Leech Seed, poison",
    residual(events) == "ingrainHeal:player,rainDish:player,leechSeedDrain:player,statusDamage:player",
    residual(events))
  local ih, rd = find(events, "ingrainHeal"), find(events, "rainDish")
  check("order: exact HP after each case", ih.hpRemaining == 325 and rd.hpRemaining == 350
    and find(events, "leechSeedDrain").hpRemaining == 300 and e.player.hp == 250 and e.rng.draws == 0)
  check("order texts: nutrients, RAIN DISH", (function()
    local shown = texts(e, events)
    local a, b
    for i, t in ipairs(shown) do
      if t == "PLAYER absorbed\nnutrients with its roots!" then a = i end
      if t == "PLAYER's RAIN DISH\nrestored its HP a little!" then b = i end
    end
    return a and b and a < b and shown[a + 1] == "[hp player 325]"
  end)())

  -- Rain Dish interplay: Ingrain tops the battler up (390 + 10 = 400), so
  -- Rain Dish (maxHP > hp) finds it full and does nothing.
  e = battle({}, { playerCurrentHP = 390, playerAbility = RAIN_DISH })
  e.weather = { kind = "rain", permanent = true }
  e.player.rooted = true
  events = e:runTurn(MOVE, MOVE)
  check("Ingrain fills the battler, so Rain Dish is silent",
    residual(events) == "ingrainHeal:player" and e.player.hp == 400, residual(events))

  -- Field cases first: sandstorm hits the Psychic player for 25 (300 -> 275)
  -- before its own Ingrain heal (275 -> 300).
  e = battle({}, { playerCurrentHP = 300 })
  e.weather = { kind = "sandstorm", permanent = true }
  e.player.rooted = true
  events = e:runTurn(MOVE, MOVE)
  check("sandstorm (field) precedes Ingrain",
    residual(events) == "weatherDamage:player,weatherDamage:foe,ingrainHeal:player"
      and find(events, "ingrainHeal").hpRemaining == 300, residual(events))

  -- Ingrain does not run the team check. The faster foe's seed drain KOs the
  -- foe (10 HP left, drain min(10, 50) = 10, the player heals 10 -> 310); the
  -- battle is decided only after the phase, so the player's Ingrain (+25 ->
  -- 335) and Rain Dish (+25 -> 360) still run before battleEnd.
  e = battle({}, { foeSpeed = 40, foeCurrentHP = 10, playerCurrentHP = 300, playerAbility = RAIN_DISH })
  e.weather = { kind = "rain", permanent = true }
  e.foe.seeded = true
  e.player.rooted = true
  events = e:runTurn(MOVE, MOVE)
  check("Ingrain and Rain Dish do not trigger the deferred team check",
    residual(events) == "leechSeedDrain:foe,faint:foe,ingrainHeal:player,rainDish:player,battleEnd:playerWon",
    residual(events))
  check("the HP sums through the deferred phase", e.player.hp == 360 and e.outcome == "playerWon")
end

---------------------------------------------------------------------------
-- Mean Look / Spider Web / Block: the move
---------------------------------------------------------------------------
do
  for _, id in ipairs({ MEAN_LOOK, SPIDER_WEB, BLOCK }) do
    local e = battle({}, { playerMoves = { id } })
    local events = {}
    e:resolveMove("player", 1, events)
    check(("move %d: target escape-prevented, no draw, PP spent"):format(id),
      e.foe.escapePrevented and e.rng.draws == 0 and e.player.moves[1].pp == moves[id].pp - 1
        and not e.player.escapePrevented)
    check(("move %d: useMove then escapePrevented"):format(id), types(events) == "useMove,escapePrevented"
      and events[2].side == "player" and events[2].target == "foe", types(events))
  end
  local e = battle({}, { playerMoves = { MEAN_LOOK } })
  local events = {}
  e:resolveMove("player", 1, events)
  check("Mean Look text names the target", texts(e, events)[2] == "FOE can't\nescape now!", texts(e, events)[2])
  events = {}
  e:resolveMove("player", 1, events)
  check("Mean Look repeat: But it failed, PP spent, no draw", types(events) == "useMove,moveFailed"
    and e.player.moves[1].pp == 3 and e.rng.draws == 0, types(events))

  for _, state in ipairs({ "air", "underground", "underwater" }) do
    e = battle({}, { playerMoves = { MEAN_LOOK } })
    e.foe.semiInvulnerable = state
    events = {}
    e:resolveMove("player", 1, events)
    check("Mean Look vs a semi-invulnerable (" .. state .. ") target: But it failed, no draw",
      types(events) == "useMove,moveFailed" and not e.foe.escapePrevented and e.rng.draws == 0
        and e.player.moves[1].pp == 4, types(events))
  end

  -- A rooted target is not escape-prevented: Mean Look still lands.
  e = battle({}, { playerMoves = { MEAN_LOOK } })
  e.foe.rooted = true
  events = {}
  e:resolveMove("player", 1, events)
  check("Mean Look on a rooted target still succeeds", e.foe.escapePrevented and find(events, "escapePrevented"))

  -- The foe's Mean Look traps the player through a whole turn.
  e = battle({}, { foeMoves = { MEAN_LOOK } })
  events = e:runTurn(MOVE, MOVE)
  check("the foe's Mean Look: the player can no longer run or switch",
    e.player.escapePrevented and e:runBlocked("player") and e:switchBlocked("player") and e.rng.draws == 0)
  check("the foe's Mean Look text", joined(texts(e, events)):find("PLAYER can't\nescape now!", 1, true) ~= nil,
    joined(texts(e, events)))
end

---------------------------------------------------------------------------
-- Mean Look: tied to the battler that applied it (clearHeldBy)
---------------------------------------------------------------------------
do
  -- The preventer (foe) faints at end of turn (1 HP, poison) with a
  -- replacement: FaintClearSetData clears the player's escape prevention.
  local e = battle({}, { foeCurrentHP = 1, foeStatus = S.POISON,
    hasReplacement = function(side) return side == "foe" end })
  e.player.escapePrevented = true
  e.foe.escapePrevented = true
  e.foe.rooted = true
  local events = e:runTurn(MOVE, MOVE)
  check("preventer faint: forced foe switch pending", find(events, "faint", "foe") ~= nil
    and e.awaitingForcedSwitch == "foe", types(events))
  check("preventer faint clears the player's escape prevention",
    not e.player.escapePrevented and not e:runBlocked("player") and not e:switchBlocked("player"))
  check("the fainted battler's own flags clear", not e.foe.escapePrevented and not e.foe.rooted)
  e:resolveForcedSwitch("foe", freshBattler())
  check("the foe's replacement is fresh, the player can run",
    not e.foe.escapePrevented and not e.foe.rooted and not e:runBlocked("player"))

  -- The player faints holding a lock on the foe: the foe's lock clears, and
  -- the forced replacement is never blocked.
  e = battle({}, { playerCurrentHP = 1, playerStatus = S.POISON,
    hasReplacement = function(side) return side == "player" end })
  e.player.rooted, e.player.escapePrevented = true, true
  e.foe.escapePrevented = true
  events = e:runTurn(MOVE, MOVE)
  check("player faint: own rooted/escape flags and the foe's lock all clear",
    e.awaitingForcedSwitch == "player" and not e.player.rooted and not e.player.escapePrevented
      and not e.foe.escapePrevented, types(events))
  check("player faint: switchBlocked is false for the forced replacement", not e:switchBlocked("player"))
  check("the forced replacement resolves", pcall(e.resolveForcedSwitch, e, "player", freshBattler())
    and e.awaitingForcedSwitch == nil and not e.player.rooted)

  -- The player (preventer) switches out voluntarily: SwitchInClearSetData
  -- clears the foe's escape prevention; the seed on the foe stays (R1).
  e = battle({})
  e.foe.escapePrevented = true
  e.foe.seeded = true
  local incoming = freshBattler()
  events = e:runTurn({ action = "switch", battler = incoming }, MOVE)
  check("preventer switch clears the foe's escape prevention",
    find(events, "switch", "player") ~= nil and not e.foe.escapePrevented and e.player == incoming)
  check("clearHeldBy does not clear the seed", e.foe.seeded)

  -- The trapped battler's own switch is the blocked one; another side's
  -- rooting does not block the player.
  e = battle({})
  e.foe.rooted = true
  e.foe.escapePrevented = true
  check("a trapped foe does not block the player's run or switch",
    not e:runBlocked("player") and not e:switchBlocked("player"))
  events = e:runTurn({ action = "switch", battler = freshBattler() }, MOVE)
  check("the foe's own rooting survives the player's switch", e.foe.rooted and not e.foe.escapePrevented)
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
  check("AI_CBM_CantEscape: free target 0", score(user, target, MEAN_LOOK) == 0)
  target.escapePrevented = true
  check("AI_CBM_CantEscape: escape-prevented target -10 (all three moves)",
    score(user, target, MEAN_LOOK) == -10 and score(user, target, SPIDER_WEB) == -10
      and score(user, target, BLOCK) == -10)
  local rootedTarget = mon(); rootedTarget.rooted = true
  check("AI_CBM_CantEscape does not test ROOTED", score(user, rootedTarget, MEAN_LOOK) == 0)
  local rootedUser = mon(); rootedUser.escapePrevented = true
  check("AI_CBM_CantEscape reads the target, not the user", score(rootedUser, mon(), MEAN_LOOK) == 0)

  check("AI_CBM_Ingrain: unrooted user 0", score(mon(), mon(), INGRAIN) == 0)
  local rooted = mon(); rooted.rooted = true
  check("AI_CBM_Ingrain: rooted user -10", score(rooted, mon(), INGRAIN) == -10)
  local rootedFoe = mon(); rootedFoe.rooted = true
  check("AI_CBM_Ingrain reads the user, not the target", score(mon(), rootedFoe, INGRAIN) == 0)

  -- TrainerAI reads the live battler tables (engine.foe/engine.player).
  local e = battle({}, { foeMoves = { INGRAIN } })
  e.player.escapePrevented = true
  e.foe.rooted = true
  check("the live engine battlers carry the flags the AI reads",
    AICheckBadMove.score(e.foe, e.player, moves[MEAN_LOOK], MEAN_LOOK, Data.typeChart, e.sideStatus) == -10
      and AICheckBadMove.score(e.foe, e.player, moves[INGRAIN], INGRAIN, Data.typeChart, e.sideStatus) == -10)
end

---------------------------------------------------------------------------
-- Controller: RUN veto (after the trainer check; no turn, no RNG)
---------------------------------------------------------------------------
local function controllerFor(e, opts)
  opts = opts or {}
  local c = BattleSceneController.new({ engine = e, playerName = "TANGELA", foeName = "GASTLY",
    introMessages = {}, runDisabledMessage = opts.runDisabledMessage,
    voluntarySwitchChoices = opts.voluntarySwitchChoices,
    onVoluntarySwitchChoice = opts.onVoluntarySwitchChoice,
    forcedSwitchChoices = opts.forcedSwitchChoices,
    onForcedSwitchChoice = opts.onForcedSwitchChoice })
  drain(c)
  return c
end

do
  for _, flag in ipairs({ "rooted", "escapePrevented" }) do
    local e = battle({})
    e[ "player" ][flag] = true
    local c = controllerFor(e)
    local draws = e.rng.draws
    press(c, InputState.DPAD_RIGHT)
    press(c, InputState.DPAD_DOWN)
    check("cursor on RUN", c.actionCursor == 3)
    press(c, InputState.A_BUTTON)
    check("wild RUN while " .. flag .. ": \"Can't escape!\"", c:message() == "Can't escape!", c:message())
    check("wild RUN while " .. flag .. ": no turn, no RNG, runTries unchanged",
      e.turn == 0 and e.rng.draws == draws and e.runTries == 0 and not e:isOver())
    local shown = drain(c)
    check("wild RUN veto: one message, back to ACTION", #shown == 1 and c.state == BattleSceneController.ACTION)
  end

  -- Not trapped: the ordinary run (the faster player escapes, no draw).
  local e = battle({})
  local c = controllerFor(e)
  c:_runTurn({ action = "run" })
  check("an untrapped wild RUN reaches the engine", e.turn == 1 and e.outcome == "ran"
    and c:message() == "Got away safely!", c:message())

  -- Trainer battle: the trainer text comes first (bm.c:3239-3245), and only it.
  e = battle({})
  e.player.rooted = true
  c = controllerFor(e, { runDisabledMessage = "No! There's no running\nfrom a TRAINER battle!" })
  c:_runTurn({ action = "run" })
  local shown = drain(c)
  check("trainer RUN while rooted: only the trainer text",
    joined(shown) == "No! There's no running\nfrom a TRAINER battle!" and e.turn == 0 and e.rng.draws == 0,
    joined(shown))
end

---------------------------------------------------------------------------
-- Controller: voluntary switch veto (menu and direct callback), forced
-- replacement still allowed
---------------------------------------------------------------------------
do
  local e = battle({})
  e.player.escapePrevented = true
  local legal = { { slot = 2, record = { id = "bench" }, name = "BENCH" } }
  local calls, forcedCalls = 0, 0
  local function voluntary(choice)
    calls = calls + 1
    return nil
  end
  local function forced(choice)
    forcedCalls = forcedCalls + 1
    return { "Go! BENCH!" }
  end
  local c = controllerFor(e, {
    voluntarySwitchChoices = function() return legal end,
    onVoluntarySwitchChoice = voluntary,
    forcedSwitchChoices = function() return legal end,
    onForcedSwitchChoice = forced,
  })
  press(c, InputState.DPAD_DOWN)
  check("cursor on POKEMON", c.actionCursor == 2)
  press(c, InputState.A_BUTTON)
  check("the PARTY menu still opens while trapped (bm.c:3198-3200)",
    c.state == BattleSceneController.PARTY and c.partyMode == "voluntary" and #c.partyChoices == 1)
  press(c, InputState.A_BUTTON)
  check("a trapped pick shows the source text", c:message() == "TANGELA can't be switched\nout!", c:message())
  check("the callback is not invoked; no turn, no RNG", calls == 0 and e.turn == 0 and e.rng.draws == 0)
  drain(c)
  check("the player stays in PARTY (voluntary)", c.state == BattleSceneController.PARTY
    and c.partyMode == "voluntary" and #c.partyChoices == 1)
  press(c, InputState.B_BUTTON)
  check("B still cancels to ACTION", c.state == BattleSceneController.ACTION and c.partyMode == nil
    and calls == 0 and e.turn == 0)

  -- Direct callback: the stored field is the wrapper.
  check("the stored voluntary callback is wrapped", c.onVoluntarySwitchChoice ~= voluntary)
  check("a direct wrapped call returns nil without invoking the owner's closure",
    c.onVoluntarySwitchChoice(legal[1]) == nil and calls == 0 and e.turn == 0)
  e.player.escapePrevented = false
  c.onVoluntarySwitchChoice(legal[1])
  check("an untrapped direct call reaches the owner's closure", calls == 1)

  -- The forced-replacement callback is never wrapped, and the PARTY A-press
  -- never vetoes it, even if switchBlocked were true.
  check("the forced callback is stored unwrapped", c.onForcedSwitchChoice == forced)
  e.switchBlocked = function() return true end
  c.partyMode = nil
  c:_setMessages({}, BattleSceneController.PARTY)
  check("forced PARTY entered", c.state == BattleSceneController.PARTY and c.partyMode == "forced")
  press(c, InputState.A_BUTTON)
  check("a forced replacement is not vetoed", forcedCalls == 1 and c:message() == "Go! BENCH!", c:message())
end

do
  -- A realistic forced replacement after a trapped player faints: the faint
  -- cleared the bits, the controller enters forced PARTY and the callback
  -- resolves the switch.
  local e = battle({}, { playerCurrentHP = 1, playerStatus = S.POISON,
    hasReplacement = function(side) return side == "player" end })
  e.player.escapePrevented, e.player.rooted = true, true
  local legal = { { slot = 2, record = { id = "bench" }, name = "BENCH" } }
  local c
  c = controllerFor(e, {
    forcedSwitchChoices = function() return legal end,
    onForcedSwitchChoice = function(choice)
      e:resolveForcedSwitch("player", freshBattler())
      c.playerName = "BENCH"
      return { "Go! BENCH!" }
    end,
  })
  c:_runTurn(MOVE)
  drain(c)
  check("trapped player faint -> forced PARTY", c.state == BattleSceneController.PARTY and c.partyMode == "forced")
  press(c, InputState.A_BUTTON)
  check("the forced replacement goes through", e.awaitingForcedSwitch == nil and c:message() == "Go! BENCH!"
    and not e:switchBlocked("player"), c:message())
end

---------------------------------------------------------------------------
-- Controller stubs without runBlocked/switchBlocked keep working (F5)
---------------------------------------------------------------------------
do
  local ran, switched = 0, 0
  local engine = { player = { hp = 12, moves = {} }, foe = { hp = 20 }, turn = 0 }
  function engine:isOver() return self.over == true end
  function engine:runTurn(action)
    if action.action == "run" then ran = ran + 1; self.over = true end
    return { { type = "run", side = "player", success = true } }
  end
  local c = BattleSceneController.new({ engine = engine, introMessages = {},
    onVoluntarySwitchChoice = function() switched = switched + 1 end,
    voluntarySwitchChoices = function() return { { slot = 2 } } end })
  check("stub engine: the wrapped callback still calls through", (function()
    c.onVoluntarySwitchChoice({ slot = 2 }); return switched == 1
  end)())
  c.state = BattleSceneController.PARTY
  c.partyMode = "voluntary"
  press(c, InputState.A_BUTTON)
  check("stub engine: the PARTY A-press calls through", switched == 2)
  c:_runTurn({ action = "run" })
  check("stub engine: RUN reaches runTurn", ran == 1 and c:message() == "Got away safely!", c:message())
end

print(("battle_residual_r2_test: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
