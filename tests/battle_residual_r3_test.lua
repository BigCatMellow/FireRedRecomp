-- Run: lua5.1 tests/battle_residual_r3_test.lua
--
-- Residual slice R3 (work/tasks/phase4-residual-r3.md): the six trapping
-- moves (EFFECT_TRAP 42: Bind, Wrap, Fire Spin, Clamp, Whirlpool, Sand
-- Tomb), the end-of-turn wrap damage and release, escape prevention through
-- the R2 queries, clearing on the wrapper's faint or switch (clearHeldBy),
-- Whirlpool against a Dive user (decision D6), Rapid Spin's wrap arm, the
-- (absent) AI rows and the texts. Oracles come from pret/pokefirered
-- c75f352304d529f6ba92d4f74b9cf8b5c3810788:
--   * BattleScript_EffectTrap data/battle_scripts_1.s:829-835 (Whirlpool vs
--     UNDERWATER: HITMARKER_IGNORE_UNDERWATER + sDMG_MULTIPLIER 2), then
--     BattleScript_EffectHit :239-270 (accuracycheck ... resultmessage,
--     seteffectwithchance, tryfaintmon BS_TARGET);
--   * Cmd_seteffectwithchance src/battle_script_commands.c:2774-2805
--     (`Random() % 100` is the first && operand: drawn on a landed and on a
--     no-effect hit; a miss jumps away earlier);
--   * SetMoveEffect :2132-2146 (a 0-HP target returns silently) and the
--     MOVE_EFFECT_WRAP case :2483-2506 (already WRAPPED -> nothing; else
--     STATUS2_WRAPPED_TURN((Random() & 3) + 3), wrappedMove, wrappedBy,
--     gWrappedStringIds by the gTrappingMoves index);
--   * gWrappedStringIds src/battle_message.c:1042-1050, gTrappingMoves
--     :1263-1271, texts :143-149, :211;
--   * ENDTURN_WRAP src/battle_util.c:872-903 (decrement; still wrapped ->
--     max(1, maxHP/16) via BattleScript_WrapTurnDmg bs1.s:3769-3773 and
--     DoTurnDmg :3681-3688 with its checkteamslost; reached 0 ->
--     BattleScript_WrapEnds :3775-3778, text only); the case order
--     src/battle_util.c:720-742 (... Nightmare, Curse, Wrap, Uproar, Thrash);
--   * clearing: SwitchInClearSetData src/battle_main.c:2371-2377,
--     FaintClearSetData :2449-2451 (the whole WRAPPED field is cleared);
--   * escape: IsRunningFromBattleImpossible :3047-3052, the switch selection
--     test :3198;
--   * Cmd_rapidspinfree src/battle_script_commands.c:8435-8469 (else-if:
--     WRAPPED first, then LEECHSEED), BattleScript_WrapFree bs1.s:3445-3449;
--   * AI: data/battle_ai_scripts.s AI_CheckBadMove has no EFFECT_TRAP or
--     EFFECT_RAPID_SPIN row (EFFECT_TRAP appears only in AI_CheckViability
--     :685; AI_Roaming :3227 tests STATUS2_WRAPPED, not the effect).
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
local BIND, WRAP, FIRE_SPIN, CLAMP, WHIRLPOOL, SAND_TOMB = 20, 35, 83, 128, 250, 328
local RAPID_SPIN, LEECH_SEED, SPLASH, THRASH, TACKLE = 229, 73, 150, 37, Data.MOVE_TACKLE
local moves = {}
for id, m in pairs(Data.moves) do moves[id] = m end
moves[BIND] = rec(42, 15, T.TYPE_NORMAL, 75, 20, 100, 0, 0x33)      -- :263-274
moves[WRAP] = rec(42, 15, T.TYPE_NORMAL, 85, 20, 100, 0, 0x33)      -- :458-469
moves[FIRE_SPIN] = rec(42, 15, T.TYPE_FIRE, 70, 15, 100, 0, 0x32)   -- :1082-1093
moves[CLAMP] = rec(42, 35, T.TYPE_WATER, 75, 10, 100, 0, 0x33)      -- :1667-1678
moves[WHIRLPOOL] = rec(42, 15, T.TYPE_WATER, 70, 15, 100, 0, 0x32)  -- :3253-3264
moves[SAND_TOMB] = rec(42, 15, T.TYPE_GROUND, 70, 15, 100, 0, 0x32) -- :4267-4278
moves[RAPID_SPIN] = rec(129, 20, T.TYPE_NORMAL, 100, 40, 0, 0, 0x33) -- :2980-2991
moves[LEECH_SEED] = rec(84, 0, T.TYPE_GRASS, 90, 10, 0, 0, 0x16)
moves[SPLASH] = rec(85, 0, T.TYPE_NORMAL, 0, 40, 0, 0x10, 0)
moves[THRASH] = rec(27, 90, T.TYPE_NORMAL, 100, 20, 100, 0x04, 0x33)

-- gMoveNames (src/data/text/move_names.h) for the B_BUFF1 texts.
local MOVE_NAMES = { [BIND] = "BIND", [WRAP] = "WRAP", [FIRE_SPIN] = "FIRE SPIN", [CLAMP] = "CLAMP",
  [WHIRLPOOL] = "WHIRLPOOL", [SAND_TOMB] = "SAND TOMB", [RAPID_SPIN] = "RAPID SPIN", [SPLASH] = "SPLASH" }
local function moveName(id) return MOVE_NAMES[id] or ("MOVE " .. tostring(id)) end

local RUN_AWAY = 50 -- include/constants/abilities.h

local function moveList(list)
  local out = {}
  for i, id in ipairs(list) do out[i] = { move = id, pp = moves[id].pp } end
  return out
end

-- Level 10, attack/defense/spAttack/spDefense 20. Default: player faster
-- (30 vs 20), player Psychic, foe Normal, 400 HP, both using Splash (no RNG).
--
-- Damage oracle (CalculateBaseDamage, no STAB for the Psychic player, every
-- move here neutral against Normal, crit draw 1 -> no crit, random draw 0 ->
-- x100/100): floor(floor((2*10/5+2) * power * 20/20) / 50) + 2, i.e. power 15
-- -> floor(90/50)+2 = 3 and power 35 -> floor(210/50)+2 = 6. Whirlpool's
-- dmgMultiplier 2 against a Dive user doubles the base: 3 * 2 = 6.
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

local function freshBattler(hp, moveIds)
  return BattleEngine.makeBattler({ species = 7, level = 10,
    stats = { hp = hp or 400, attack = 20, defense = 20, speed = 30, spAttack = 20, spDefense = 20 },
    types = { T.TYPE_PSYCHIC, T.TYPE_PSYCHIC }, moves = moveList(moveIds or { SPLASH }) })
end

local MOVE = { action = "move", moveSlot = 1 }
local SLOT2 = { action = "move", moveSlot = 2 }
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
    introMessages = {}, moveName = moveName })
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

---------------------------------------------------------------------------
-- Admission and defaults
---------------------------------------------------------------------------
do
  local e = battle({})
  for _, id in ipairs({ BIND, WRAP, FIRE_SPIN, CLAMP, WHIRLPOOL, SAND_TOMB }) do
    check("trap move " .. id .. " admitted", e:supportsMove(moves[id], id))
  end
  check("constants", BattleEngine.EFFECT_TRAP == 42 and BattleEngine.MOVE_WHIRLPOOL == 250)
  check("wrap defaults: not wrapped", e.player.wrapTurns == 0 and e.player.wrapMove == nil
    and e.foe.wrapTurns == 0 and e.foe.wrapMove == nil)
end

---------------------------------------------------------------------------
-- The trap hit: every move, `% 100` then `& 3`, per-move text
---------------------------------------------------------------------------
do
  -- Draws: accuracy 0 (hit), crit 1 (no crit), damage random 0 (x100),
  -- the `% 100` roll (any value passes: <= 100), then `& 3`.
  -- gWrappedStringIds (msg.c:1042-1050) with DEF = FOE, ATK = PLAYER.
  local cases = {
    { BIND, 3, "FOE was squeezed by\nPLAYER's BIND!" },     -- :143
    { WRAP, 3, "FOE was WRAPPED by\nPLAYER!" },             -- :146
    { FIRE_SPIN, 3, "FOE was trapped\nin the vortex!" },    -- :144
    { CLAMP, 6, "PLAYER CLAMPED\nFOE!" },                   -- :147
    { WHIRLPOOL, 3, "FOE was trapped\nin the vortex!" },    -- :144
    { SAND_TOMB, 3, "FOE was trapped\nby SAND TOMB!" },     -- :145
  }
  for i, case in ipairs(cases) do
    local id, dmg, text = case[1], case[2], case[3]
    -- `& 3` draw i-1 -> (i-1) % 4 + 3 turns: 3, 4, 5, 6, 3, 4.
    local k = i - 1
    local e = battle({ 0, 1, 0, 99, k }, { playerMoves = { id } })
    local events = {}
    e:resolveMove("player", 1, events)
    local w = find(events, "wrapped")
    check(id .. ": damage, then wrapped", types(events) == "useMove,damage,wrapped", types(events))
    check(id .. ": exactly five draws", e.rng.draws == 5, e.rng.draws)
    check(id .. ": damage " .. dmg, find(events, "damage").amount == dmg and e.foe.hp == 400 - dmg,
      find(events, "damage").amount)
    check(id .. ": counter (k & 3) + 3 and wrapMove", e.foe.wrapTurns == (k % 4) + 3 and e.foe.wrapMove == id,
      e.foe.wrapTurns)
    check(id .. ": event fields", w and w.side == "foe" and w.by == "player" and w.move == id)
    check(id .. ": PP spent", e.player.moves[1].pp == moves[id].pp - 1)
    local t = texts(e, events)
    check(id .. ": text", t[3] == text, t[3])
  end

  -- The `& 3` roll: (Random() & 3) + 3 for representative 16-bit draws.
  for _, pair in ipairs({ { 0, 3 }, { 1, 4 }, { 2, 5 }, { 3, 6 }, { 4, 3 }, { 7, 6 }, { 0xFFFE, 5 }, { 0xFFFF, 6 } }) do
    local e = battle({ 0, 1, 0, 0, pair[1] }, { playerMoves = { WRAP } })
    e:resolveMove("player", 1, {})
    check("& 3 draw " .. pair[1] .. " -> " .. pair[2] .. " turns", e.foe.wrapTurns == pair[2], e.foe.wrapTurns)
  end

  -- The foe wraps the player: DEF = PLAYER, ATK = FOE.
  local e = battle({ 0, 1, 0, 0, 2 }, { foeMoves = { BIND } })
  local events = {}
  e:resolveMove("foe", 1, events)
  check("foe Bind wraps the player", e.player.wrapTurns == 5 and e.player.wrapMove == BIND and e.rng.draws == 5)
  check("foe Bind text", texts(e, events)[3] == "PLAYER was squeezed by\nFOE's BIND!", texts(e, events)[3])
  e = battle({ 0, 1, 0, 0, 0 }, { foeMoves = { CLAMP } })
  events = {}
  e:resolveMove("foe", 1, events)
  check("foe Clamp text (ATK first)", texts(e, events)[3] == "FOE CLAMPED\nPLAYER!", texts(e, events)[3])

  -- The wrapped text follows the effectiveness text (resultmessage precedes
  -- seteffectwithchance): Fire Spin vs a Grass foe is super effective.
  e = battle({ 0, 1, 0, 0, 0 }, { playerMoves = { FIRE_SPIN }, foeTypes = { T.TYPE_GRASS, T.TYPE_GRASS } })
  events = {}
  e:resolveMove("player", 1, events)
  local t = texts(e, events)
  check("effectiveness text, then the wrapped text",
    t[#t - 1] == "It's super effective!" and t[#t] == "FOE was trapped\nin the vortex!", joined(t))
end

---------------------------------------------------------------------------
-- Draw counts: immune target, miss, KO, already wrapped
---------------------------------------------------------------------------
do
  -- No-effect hit: acc, crit, damage random, then the discarded `% 100`
  -- (the && chain draws before testing MOVE_RESULT_NO_EFFECT): four draws,
  -- nothing set. Bind/Wrap vs Ghost; Sand Tomb vs Flying.
  for _, case in ipairs({ { BIND, T.TYPE_GHOST }, { WRAP, T.TYPE_GHOST }, { SAND_TOMB, T.TYPE_FLYING } }) do
    local e = battle({ 0, 1, 0, 0, 0 }, { playerMoves = { case[1] }, foeTypes = { case[2], case[2] } })
    local events = {}
    e:resolveMove("player", 1, events)
    check(case[1] .. " vs immune: noEffect, four draws, not wrapped",
      types(events) == "useMove,noEffect" and e.rng.draws == 4 and e.foe.wrapTurns == 0,
      types(events) .. " draws=" .. e.rng.draws)
  end

  -- Miss: one accuracy draw only. Bind acc 75: draw 80 -> 81 > 75.
  local e = battle({ 80 }, { playerMoves = { BIND } })
  local events = {}
  e:resolveMove("player", 1, events)
  check("miss: one draw, no wrap", types(events) == "useMove,miss" and e.rng.draws == 1 and e.foe.wrapTurns == 0,
    types(events) .. " draws=" .. e.rng.draws)
  -- Boundary: Bind draw 74 -> 75 <= 75 hits.
  e = battle({ 74, 1, 0, 0, 0 }, { playerMoves = { BIND } })
  e:resolveMove("player", 1, {})
  check("acc boundary hits and wraps", e.foe.wrapTurns == 3 and e.rng.draws == 5)

  -- KO on the trap hit: SetMoveEffect's 0-HP guard returns before `& 3`, so
  -- four draws; no wrapped event; the faint follows the hit.
  e = battle({ 0, 1, 0, 0, 0 }, { playerMoves = { WRAP }, foeCurrentHP = 2 })
  events = e:runTurn(MOVE, MOVE)
  check("KO: no wrapped event, faint then battleEnd",
    types(events) == "turnStart,useMove,damage,faint,battleEnd", types(events))
  check("KO: four draws (no & 3)", e.rng.draws == 4, e.rng.draws)
  check("KO: target not wrapped", e.foe.wrapTurns == 0 and e.foe.wrapMove == nil)

  -- Already wrapped: `% 100` drawn, then the WRAPPED test leaves it alone --
  -- no `& 3`, no text, wrapMove kept.
  e = battle({ 0, 1, 0, 0, 3 }, { playerMoves = { FIRE_SPIN } })
  e.foe.wrapTurns, e.foe.wrapMove = 2, WRAP
  events = {}
  e:resolveMove("player", 1, events)
  check("already wrapped: hit, four draws, no wrapped event",
    types(events) == "useMove,damage" and e.rng.draws == 4, types(events) .. " draws=" .. e.rng.draws)
  check("already wrapped: counter and move kept", e.foe.wrapTurns == 2 and e.foe.wrapMove == WRAP)
end

---------------------------------------------------------------------------
-- Semi-invulnerable targets and Whirlpool vs Dive (decision D6)
---------------------------------------------------------------------------
do
  -- AccuracyCalcHelper: an ON_AIR / UNDERGROUND / UNDERWATER target misses
  -- with no draw unless the move set the IGNORE hitmarker.
  for _, case in ipairs({ { WRAP, "air" }, { WRAP, "underground" }, { WRAP, "underwater" },
      { CLAMP, "underwater" }, { WHIRLPOOL, "air" }, { WHIRLPOOL, "underground" }, { SAND_TOMB, "underground" } }) do
    local e = battle({ 0, 1, 0, 0, 0 }, { playerMoves = { case[1] } })
    e.foe.semiInvulnerable = case[2]
    local events = {}
    e:resolveMove("player", 1, events)
    check(case[1] .. " vs " .. case[2] .. ": miss, no draws, no wrap",
      find(events, "damage") == nil and find(events, "wrapped") == nil and e.rng.draws == 0
        and e.foe.wrapTurns == 0 and e.foe.hp == 400, types(events) .. " draws=" .. e.rng.draws)
  end

  -- Whirlpool vs UNDERWATER: HITMARKER_IGNORE_UNDERWATER (the accuracy draw
  -- still happens) and dmgMultiplier 2: 3 * 2 = 6; then `% 100` and `& 3`.
  local e = battle({ 0, 1, 0, 0, 1 }, { playerMoves = { WHIRLPOOL } })
  e.foe.semiInvulnerable = "underwater"
  local events = {}
  e:resolveMove("player", 1, events)
  check("Whirlpool hits a Dive user", types(events) == "useMove,damage,wrapped", types(events))
  check("Whirlpool vs Dive: x2 damage (6)", find(events, "damage").amount == 6 and e.foe.hp == 394,
    find(events, "damage") and find(events, "damage").amount)
  check("Whirlpool vs Dive: five draws, wrapped 4 turns", e.rng.draws == 5 and e.foe.wrapTurns == 4
    and e.foe.semiInvulnerable == "underwater")
  -- The same Whirlpool against a surfaced target: 3.
  e = battle({ 0, 1, 0, 0, 1 }, { playerMoves = { WHIRLPOOL } })
  events = {}
  e:resolveMove("player", 1, events)
  check("Whirlpool vs a surfaced target: 3", find(events, "damage").amount == 3)
  -- Whirlpool vs Dive misses on the accuracy draw like any other hit:
  -- acc 70, draw 70 -> 71 > 70; one draw.
  e = battle({ 70 }, { playerMoves = { WHIRLPOOL } })
  e.foe.semiInvulnerable = "underwater"
  events = {}
  e:resolveMove("player", 1, events)
  check("Whirlpool vs Dive can still miss on the roll", types(events) == "useMove,miss" and e.rng.draws == 1,
    types(events) .. " draws=" .. e.rng.draws)

  -- Through the real Dive: the foe dives on turn 1 (no RNG for the charge
  -- turn); the faster player's Whirlpool on turn 2 hits it underwater for 6
  -- before the foe surfaces. Turn 1: the player's Whirlpool goes first and
  -- hits a surfaced foe (3); turn 2: 6.
  local DIVE = 291
  moves[DIVE] = rec(155, 60, T.TYPE_WATER, 100, 10, 0, 0, 0x33) -- :3786-3797
  e = battle({ 0, 1, 0, 0, 3, 0, 1, 0, 0 }, { playerMoves = { WHIRLPOOL }, foeMoves = { DIVE } })
  local t1 = e:runTurn(MOVE, MOVE)
  check("turn 1: foe charges Dive", e.foe.semiInvulnerable == "underwater" and find(t1, "chargeTurn", "foe") ~= nil,
    types(t1))
  check("turn 1: wrapped (6 turns), one tick at end of turn", e.foe.wrapTurns == 5
    and count(t1, "wrapDamage", "foe") == 1, types(t1))
  local t2 = e:runTurn(MOVE, MOVE)
  local dmg = nil
  for _, ev in ipairs(t2) do if ev.type == "damage" and ev.side == "player" then dmg = ev.amount end end
  check("turn 2: Whirlpool hits the underwater foe for 6 (already wrapped: no re-roll)", dmg == 6, dmg)
  -- HP: 400 - 3 - 25 (tick) - 6 - 25 (tick) = 341 before the foe's Dive
  -- hit lands on the player.
  check("turn 2: foe HP 341", e.foe.hp == 341, e.foe.hp)

  -- A semi-invulnerable wrapped battler still ticks (no exemption).
  e = battle({})
  e.foe.wrapTurns, e.foe.wrapMove = 3, WRAP
  e.foe.semiInvulnerable = "air"
  events = {}
  e:resolveStatusEndTurn(events, { "player", "foe" })
  check("a Fly user still takes the wrap tick", types(events) == "wrapDamage" and e.foe.hp == 375, types(events))
end

---------------------------------------------------------------------------
-- End of turn: ticks, release, texts
---------------------------------------------------------------------------
do
  -- Counter 3 (draw 0): two damage ticks of floor(400/16) = 25, then the
  -- release turn; nothing on the fourth turn.
  local e = battle({ 0, 1, 0, 0, 0 }, { playerMoves = { WRAP, SPLASH } })
  local t1 = e:runTurn(MOVE, MOVE)
  check("turn 1: hit, wrapped, one tick", types(t1) == "turnStart,useMove,damage,wrapped,useMove,splash,wrapDamage",
    types(t1))
  check("turn 1: counter 3 -> 2, HP 400 - 3 - 25 = 372", e.foe.wrapTurns == 2 and e.foe.hp == 372, e.foe.hp)
  local tx = texts(e, t1)
  check("turn 1 texts", tx[#tx - 1] == "FOE is hurt\nby WRAP!" and tx[#tx] == "[hp foe 372]", joined(tx))
  local t2 = e:runTurn(SLOT2, MOVE)
  check("turn 2: second tick", count(t2, "wrapDamage", "foe") == 1 and e.foe.wrapTurns == 1 and e.foe.hp == 347,
    e.foe.hp)
  local t3 = e:runTurn(SLOT2, MOVE)
  local ended = find(t3, "wrapEnded", "foe")
  check("turn 3: freed, no damage", ended and ended.move == WRAP and count(t3, "wrapDamage") == 0
    and e.foe.hp == 347 and e.foe.wrapTurns == 0 and e.foe.wrapMove == nil, types(t3))
  tx = texts(e, t3)
  check("release text", tx[#tx] == "FOE was freed\nfrom WRAP!", joined(tx))
  local t4 = e:runTurn(SLOT2, MOVE)
  check("turn 4: nothing", count(t4, "wrapDamage") == 0 and count(t4, "wrapEnded") == 0)
  check("RNG: five draws in total (Splash draws none)", e.rng.draws == 5, e.rng.draws)

  -- Counter 6 (draw 3): five ticks, then the release.
  e = battle({ 0, 1, 0, 0, 3 }, { playerMoves = { SAND_TOMB, SPLASH } })
  local ticks, release, turns = 0, 0, 0
  local action = MOVE
  for _ = 1, 7 do
    local ev = e:runTurn(action, MOVE)
    action = SLOT2
    turns = turns + 1
    ticks = ticks + count(ev, "wrapDamage", "foe")
    if find(ev, "wrapEnded", "foe") then release = turns end
  end
  check("counter 6: five ticks, released on turn 6", ticks == 5 and release == 6, ticks .. "/" .. release)
  check("counter 6: HP 400 - 3 - 5*25 = 272", e.foe.hp == 272, e.foe.hp)

  -- Minimum 1 and the HP clamp: maxHP 15 -> 15/16 = 0 -> 1.
  e = battle({}, { foeHP = 15 })
  e.foe.wrapTurns, e.foe.wrapMove = 4, CLAMP
  local events = {}
  e:resolveStatusEndTurn(events, { "player", "foe" })
  check("minimum 1", find(events, "wrapDamage").amount == 1 and e.foe.hp == 14)
  check("wrapDamage carries the move", find(events, "wrapDamage").move == CLAMP)
  check("tick text names the move", texts(e, events)[1] == "FOE is hurt\nby CLAMP!", texts(e, events)[1])

  -- The player wrapped: text with the player's name.
  e = battle({})
  e.player.wrapTurns, e.player.wrapMove = 1, FIRE_SPIN
  events = {}
  e:resolveStatusEndTurn(events, { "player", "foe" })
  check("player release text", joined(texts(e, events)) == "PLAYER was freed\nfrom FIRE SPIN!",
    joined(texts(e, events)))
end

---------------------------------------------------------------------------
-- End-of-turn order (bu.c:720-742) and the team check
---------------------------------------------------------------------------
do
  -- One battler: Ingrain < Leech Seed < poison < Nightmare < Curse < Wrap <
  -- rampage tick. maxHP 400 at 390: Ingrain +min(10, 25) = 400; seed -50 =
  -- 350; poison -50 = 300; Nightmare (asleep) -100 = 200; Curse -100 = 100;
  -- wrap -25 = 75.
  local e = battle({}, { foeCurrentHP = 390, foeStatus = S.POISON })
  local foe = e.foe
  foe.rooted, foe.seeded, foe.nightmare, foe.cursed = true, true, true, true
  foe.wrapTurns, foe.wrapMove = 3, WRAP
  foe.rampageTurns, foe.lockedSlot = 1, 1
  local events = {}
  e:resolveStatusEndTurn(events, { "foe", "player" })
  -- poison and sleep cannot coexist in status1; Nightmare's silent clear
  -- would fire, so give the asleep variant separately below.
  check("order: Ingrain, seed, poison, (awake: Nightmare cleared), Curse, wrap, rampage",
    types(events) == "ingrainHeal,leechSeedDrain,statusDamage,curseDamage,wrapDamage,fatigueConfusion",
    types(events))
  check("order: exact HP 400-50-50-100-25 = 175", foe.hp == 175, foe.hp)

  e = battle({}, { foeCurrentHP = 390, foeStatus = S.withSleepTurns(0, 3) })
  foe = e.foe
  foe.rooted, foe.seeded, foe.nightmare, foe.cursed = true, true, true, true
  foe.wrapTurns, foe.wrapMove = 3, WRAP
  events = {}
  e:resolveStatusEndTurn(events, { "foe", "player" })
  check("order: Ingrain, seed, Nightmare, Curse, wrap",
    types(events) == "ingrainHeal,leechSeedDrain,nightmareDamage,curseDamage,wrapDamage", types(events))
  check("order (asleep): exact HP 400-50-100-100-25 = 125", foe.hp == 125, foe.hp)
  local tx = texts(e, events)
  check("order texts: Curse text, HP, then the wrap text, HP",
    tx[#tx - 3] == "FOE is afflicted\nby the CURSE!" and tx[#tx - 1] == "FOE is hurt\nby WRAP!"
      and tx[#tx] == "[hp foe 125]", joined(tx))

  -- A fatal wrap tick ends the battle (DoTurnDmg's checkteamslost).
  e = battle({}, { foeCurrentHP = 20 })
  e.foe.wrapTurns, e.foe.wrapMove = 2, BIND
  events = {}
  e:resolveStatusEndTurn(events, { "player", "foe" })
  check("fatal wrap tick: faint, battleEnd", types(events) == "wrapDamage,faint,battleEnd"
    and e.outcome == "playerWon" and e.foe.hp == 0, types(events))

  -- A Leech Seed KO of the wrapper (no team check) runs tryfaintmon ->
  -- BattleScript_FaintAttacker -> cleareffectsonfaint -> FaintClearSetData
  -- (bs1.s:2801-2808, bsc.c:2930-2938, bm.c:2449-2451) at once, so the
  -- wrapped player's case finds no wrap: no tick, no release. In singles the
  -- only possible wrapper is the other battler, so a wrap tick or release
  -- can never follow a pending deferred KO. The player's rampage tick still
  -- runs; the post-loop finalize decides the battle.
  e = battle({ 0 }, { foeCurrentHP = 10 })
  e.foe.seeded = true
  e.player.wrapTurns, e.player.wrapMove = 3, WRAP
  e.player.rampageTurns, e.player.lockedSlot = 1, 1
  events = {}
  e:resolveStatusEndTurn(events, { "foe", "player" })
  check("seed KO of the wrapper clears the wrap before the player's case",
    types(events) == "leechSeedDrain,faint,fatigueConfusion,battleEnd" and e.outcome == "playerWon"
      and e.player.wrapTurns == 0 and e.player.hp == 400, types(events))
  check("exactly one foe faint", count(events, "faint", "foe") == 1)

  -- Wrap tick then Leech Seed order across battlers: the faster player
  -- (first in ENDTURN_ORDER) runs its whole list before the foe.
  e = battle({})
  e.player.wrapTurns, e.player.wrapMove = 3, WRAP
  e.foe.seeded = true
  events = e:runTurn(MOVE, MOVE)
  check("per battler: the player's wrap tick before the foe's seed drain",
    types(events) == "turnStart,useMove,splash,useMove,splash,wrapDamage,leechSeedDrain", types(events))
  -- seed drain heals the player 50 after the 25 tick: 400 - 25 + 25 = 400.
  check("player HP after tick then heal", e.player.hp == 400, e.player.hp)

  -- Both sides wrapped (each by the other) and both at 1 HP: the first
  -- battler's fatal tick decides the battle (and clears the other's wrap).
  e = battle({}, { playerCurrentHP = 1, foeCurrentHP = 1 })
  e.player.wrapTurns, e.player.wrapMove = 3, WRAP
  e.foe.wrapTurns, e.foe.wrapMove = 3, WRAP
  events = {}
  e:resolveStatusEndTurn(events, { "player", "foe" })
  check("first fatal tick decides; the foe never ticks",
    types(events) == "wrapDamage,faint,battleEnd" and e.outcome == "playerLost" and e.foe.hp == 1, types(events))
end

---------------------------------------------------------------------------
-- Escape prevention (R2's runBlocked/switchBlocked wrapTurns term)
---------------------------------------------------------------------------
do
  -- The foe wraps the player (counter 3): blocked through the two damage
  -- turns, free after the release turn.
  local e = battle({ 0, 1, 0, 0, 0 }, { foeMoves = { WRAP, SPLASH } })
  e:runTurn(MOVE, MOVE)
  check("wrapped player: run and switch blocked", e.player.wrapTurns == 2 and e:runBlocked("player")
    and e:switchBlocked("player"))
  check("wrapped player: runTurn asserts on run", not pcall(e.runTurn, e, { action = "run" }, SLOT2))
  check("wrapped player: runTurn asserts on switch",
    not pcall(e.runTurn, e, { action = "switch", battler = freshBattler() }, SLOT2))
  check("assert left no state change", e.turn == 1 and e.rng.draws == 5 and e.runTries == 0)
  e:runTurn(MOVE, SLOT2) -- Splash vs Splash: tick, counter 1
  check("still blocked at counter 1", e.player.wrapTurns == 1 and e:runBlocked("player"))
  local ev = e:runTurn(MOVE, SLOT2) -- release
  check("after the release: free", find(ev, "wrapEnded", "player") ~= nil and not e:runBlocked("player")
    and not e:switchBlocked("player"))

  -- Run Away bypasses the run veto, not the switch veto.
  e = battle({}, { playerAbility = RUN_AWAY })
  e.player.wrapTurns, e.player.wrapMove = 4, WRAP
  check("Run Away: run allowed, switch blocked", not e:runBlocked("player") and e:switchBlocked("player"))
  ev = e:runTurn({ action = "run" }, MOVE)
  check("Run Away: a wrapped holder flees with no draw", e.outcome == "ran" and e.rng.draws == 0,
    types(ev))

  -- The foe being wrapped never blocks the player.
  e = battle({})
  e.foe.wrapTurns = 4
  check("a wrapped foe does not block the player", not e:runBlocked("player") and not e:switchBlocked("player"))

  -- Controller: wild RUN while wrapped -> "Can't escape!", no turn, no RNG.
  e = battle({ 0, 1, 0, 0, 0 }, { foeMoves = { WRAP } })
  local c = BattleSceneController.new({ engine = e, playerName = "PIKACHU", foeName = "EKANS",
    introMessages = {}, moveName = moveName })
  drain(c)
  c:_runTurn(MOVE)
  local shown = drain(c)
  check("controller: the wrap texts through the real engine",
    joined(shown) == "PIKACHU used SPLASH!|But nothing happened!|EKANS used WRAP!|PIKACHU was WRAPPED by\nEKANS!"
      .. "|PIKACHU is hurt\nby WRAP!", joined(shown))
  local draws = e.rng.draws
  press(c, InputState.DPAD_RIGHT)
  press(c, InputState.DPAD_DOWN)
  press(c, InputState.A_BUTTON)
  check("controller: wrapped RUN -> \"Can't escape!\"", c:message() == "Can't escape!", c:message())
  check("controller: no turn, no RNG, runTries unchanged", e.turn == 1 and e.rng.draws == draws and e.runTries == 0)
  shown = drain(c)
  check("controller: one message, back to ACTION", #shown == 1 and c.state == BattleSceneController.ACTION)

  -- Controller: a voluntary PARTY pick while wrapped -> the switch text.
  local calls = 0
  local legal = { { slot = 2, record = { id = "bench" }, name = "BENCH" } }
  c = BattleSceneController.new({ engine = e, playerName = "PIKACHU", foeName = "EKANS", introMessages = {},
    voluntarySwitchChoices = function() return legal end,
    onVoluntarySwitchChoice = function() calls = calls + 1 end })
  drain(c)
  press(c, InputState.DPAD_DOWN)
  press(c, InputState.A_BUTTON)
  press(c, InputState.A_BUTTON)
  check("controller: wrapped PARTY pick -> can't be switched out",
    c:message() == "PIKACHU can't be switched\nout!" and calls == 0 and e.turn == 1, c:message())
end

---------------------------------------------------------------------------
-- Clearing: the wrapper faints or switches out (clearHeldBy)
---------------------------------------------------------------------------
do
  -- The wrapper (foe) faints mid-turn to the player's hit, with a
  -- replacement: FaintClearSetData clears the player's whole counter.
  local e = battle({ 0, 1, 0 }, { playerMoves = { TACKLE }, foeCurrentHP = 1,
    hasReplacement = function(side) return side == "foe" end })
  e.player.wrapTurns, e.player.wrapMove = 5, WRAP
  local events = e:runTurn(MOVE, MOVE)
  check("wrapper faint mid-turn: forced foe switch pending", e.awaitingForcedSwitch == "foe", types(events))
  check("wrapper faint clears the player's wrap", e.player.wrapTurns == 0 and e.player.wrapMove == nil
    and not e:runBlocked("player") and count(events, "wrapDamage") == 0, types(events))
  e:resolveForcedSwitch("foe", freshBattler())
  check("the replacement does not re-wrap", e.player.wrapTurns == 0 and e.foe.wrapTurns == 0)

  -- The wrapper (faster foe) faints at end of turn before the wrapped
  -- player's case: the player's tick never happens.
  e = battle({}, { foeSpeed = 40, foeCurrentHP = 1, foeStatus = S.POISON,
    hasReplacement = function(side) return side == "foe" end })
  e.player.wrapTurns, e.player.wrapMove = 3, WRAP
  events = e:runTurn(MOVE, MOVE)
  check("wrapper's end-of-turn faint: the player's wrap is gone before its case",
    find(events, "faint", "foe") ~= nil and count(events, "wrapDamage") == 0 and e.player.wrapTurns == 0
      and e.player.hp == 400, types(events))

  -- The wrapped player faints: its own counter clears; the forced
  -- replacement is never blocked.
  e = battle({}, { playerCurrentHP = 1, playerStatus = S.POISON,
    hasReplacement = function(side) return side == "player" end })
  e.player.wrapTurns, e.player.wrapMove = 4, BIND
  events = e:runTurn(MOVE, MOVE)
  check("wrapped player's faint clears its own counter", e.awaitingForcedSwitch == "player"
    and e.player.wrapTurns == 0 and e.player.wrapMove == nil and not e:switchBlocked("player"), types(events))
  check("the poison KO preceded any wrap tick", count(events, "wrapDamage") == 0)

  -- The wrapper (player) switches out voluntarily: SwitchInClearSetData
  -- clears the foe's whole counter (no turns carry over); no tick that turn.
  e = battle({})
  e.foe.wrapTurns, e.foe.wrapMove = 5, WRAP
  e.foe.seeded = true
  local incoming = freshBattler(400, { WRAP })
  events = e:runTurn({ action = "switch", battler = incoming }, MOVE)
  check("wrapper switch clears the foe's counter", e.foe.wrapTurns == 0 and e.foe.wrapMove == nil
    and count(events, "wrapDamage") == 0 and e.player == incoming, types(events))
  check("the seed survives the switch (R1)", e.foe.seeded)
  -- The incoming battler's Wrap re-rolls from scratch: five draws again.
  local before = e.rng.draws
  e.rng = scriptedRng({ 0, 1, 0, 0, 2 })
  e:runTurn(MOVE, MOVE)
  check("a fresh wrap after the switch re-rolls `& 3`", e.rng.draws == 5 and e.foe.wrapTurns == 5 - 1, e.rng.draws)
  check("no draws were spent by the switch turn", before == 0)
end

---------------------------------------------------------------------------
-- Rapid Spin, wrap arm (else-if before the seed: one cleanup per use)
---------------------------------------------------------------------------
do
  -- Landed hit, user wrapped and seeded: only the wrap is freed; three
  -- draws (acc, crit, damage; CERTAIN -> no `% 100`).
  local e = battle({ 0, 1, 0, 0, 1, 0 }, { playerMoves = { RAPID_SPIN } })
  e.player.wrapTurns, e.player.wrapMove = 4, WRAP
  e.player.seeded = true
  local events = {}
  e:resolveMove("player", 1, events)
  local fr = find(events, "wrapFreed")
  check("Rapid Spin frees the wrap only", types(events) == "useMove,damage,wrapFreed"
    and e.player.wrapTurns == 0 and e.player.wrapMove == nil and e.player.seeded, types(events))
  check("wrapFreed fields", fr and fr.side == "player" and fr.by == "foe" and fr.move == WRAP)
  check("Rapid Spin wrap arm: three draws", e.rng.draws == 3, e.rng.draws)
  check("got-free text", texts(e, events)[3] == "PLAYER got free of\nFOE's WRAP!", texts(e, events)[3])
  check("free to run afterwards", not e:runBlocked("player"))
  -- The next use sheds the seed.
  events = {}
  e:resolveMove("player", 1, events)
  check("second Rapid Spin sheds the seed", types(events) == "useMove,damage,leechSeedFreed"
    and not e.player.seeded and e.rng.draws == 6, types(events))

  -- On a KO: the wrap arm precedes tryfaintmon BS_TARGET.
  e = battle({ 0, 1, 0 }, { playerMoves = { RAPID_SPIN }, foeCurrentHP = 1 })
  e.player.wrapTurns, e.player.wrapMove = 2, FIRE_SPIN
  events = e:runTurn(MOVE, MOVE)
  check("Rapid Spin KO: freed before the faint",
    types(events) == "turnStart,useMove,damage,wrapFreed,faint,battleEnd", types(events))

  -- Against a Ghost: no effect, the discarded `% 100`, wrap kept.
  e = battle({ 0, 1, 0, 0 }, { playerMoves = { RAPID_SPIN }, foeTypes = { T.TYPE_GHOST, T.TYPE_GHOST } })
  e.player.wrapTurns, e.player.wrapMove = 3, WRAP
  events = {}
  e:resolveMove("player", 1, events)
  check("Rapid Spin vs Ghost: wrap kept, four draws", types(events) == "useMove,noEffect"
    and e.player.wrapTurns == 3 and e.rng.draws == 4, types(events))

  -- The foe's Rapid Spin frees the foe (names swap).
  e = battle({ 0, 1, 0 }, { foeMoves = { RAPID_SPIN } })
  e.foe.wrapTurns, e.foe.wrapMove = 3, CLAMP
  events = {}
  e:resolveMove("foe", 1, events)
  check("foe Rapid Spin text", texts(e, events)[3] == "FOE got free of\nPLAYER's CLAMP!", texts(e, events)[3])
end

---------------------------------------------------------------------------
-- AI (AI_CheckBadMove has no EFFECT_TRAP or EFFECT_RAPID_SPIN row)
---------------------------------------------------------------------------
do
  local e = battle({})
  e.player.wrapTurns, e.player.wrapMove = 3, WRAP
  e.foe.wrapTurns = 3
  for _, id in ipairs({ BIND, WRAP, FIRE_SPIN, CLAMP, WHIRLPOOL, SAND_TOMB }) do
    check("AI: trap move " .. id .. " vs an already-wrapped target scores 0",
      AICheckBadMove.score(e.foe, e.player, moves[id], id, Data.typeChart, e.sideStatus) == 0)
  end
  check("AI: Rapid Spin by a wrapped user scores 0",
    AICheckBadMove.score(e.foe, e.player, moves[RAPID_SPIN], RAPID_SPIN, Data.typeChart, e.sideStatus) == 0)
  -- The generic 0x-effectiveness rule still applies (AI_CheckBadMove :59).
  local ghost = battle({}, { playerTypes = { T.TYPE_GHOST, T.TYPE_GHOST } })
  check("AI: Wrap vs a Ghost is the generic -10",
    AICheckBadMove.score(ghost.foe, ghost.player, moves[WRAP], WRAP, Data.typeChart, ghost.sideStatus) == -10)
end

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
