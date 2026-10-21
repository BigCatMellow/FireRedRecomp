-- Run: lua5.1 tests/battle_variable_power_v1_test.lua
--
-- Variable-power slice V1 (work/tasks/phase4-variable-power-v1.md):
-- EFFECT_PRESENT (122, move 217). Oracles come from pret/pokefirered
-- c75f352304d529f6ba92d4f74b9cf8b5c3810788:
--   * BattleScript_EffectPresent data/battle_scripts_1.s:1660-1666:
--     attackcanceler, accuracycheck BattleScript_PrintMoveMissed,
--     attackstring, ppreduce, typecalc, presentdamagecalculation;
--   * Cmd_presentdamagecalculation src/battle_script_commands.c:8238-8264:
--     rand = Random() & 0xFF; < 102 -> 40, < 178 -> 80, < 204 -> 120, then
--     BattleScript_HitFromCritCalc; otherwise damage = -(maxHP / 4, min 1);
--     full HP -> BattleScript_AlreadyAtFullHp, else clear
--     MOVE_RESULT_DOESNT_AFFECT_FOE and BattleScript_PresentHealTarget;
--   * BattleScript_PresentHealTarget bs1.s:2028-2036 (heal clamped at maxHP
--     by datahpupdate, "regained\nhealth!", src/battle_message.c:124) and
--     BattleScript_AlreadyAtFullHp bs1.s:2038-2042 ("'s\nHP is full!",
--     :125); both name B_DEF_NAME, the target;
--   * AccuracyCalcHelper bsc.c:1040-1043: a Fly/Dig target misses before
--     Random() (review F7);
--   * accuracycheck's protect re-test (protection slice P1): no draw.
-- Move record transcribed from src/data/battle_moves.h:2824-2835 at the pin:
-- Present, EFFECT_PRESENT, power 1, Normal, accuracy 90, PP 15, chance 0,
-- MOVE_TARGET_SELECTED, priority 0, FLAG_PROTECT_AFFECTED |
-- FLAG_MIRROR_MOVE_AFFECTED = 0x02 | 0x10 = 0x12.
--
-- Damage oracle (src/pokemon.c CalculateBaseDamage, physical Normal): level
-- 10 gives 2*10/5+2 = 6; attack 20, defense 20:
--   floor(floor(20 * P * 6 / 20) / 50) + 2 = floor(6P / 50) + 2
--   P = 40 -> 4 + 2 = 6;  P = 80 -> 9 + 2 = 11;  P = 120 -> 14 + 2 = 16.
-- A crit doubles after the base (P = 40 -> 12). The random multiplier is
-- 100 - (rand % 16) percent, floored: draw 15 on P = 120 -> 16*85/100 = 13.
-- The player is Psychic and the foe Water: no STAB, neutral. Expected numbers
-- are worked here, never read back from the engine.
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

local PRESENT, TACKLE, SPLASH = 217, 33, 150
local moves = {}
for id, m in pairs(Data.moves) do moves[id] = m end
moves[PRESENT] = rec(122, 1, 0, 90, 15, 0, 0x00, 0, 0x12) -- battle_moves.h:2824
moves[SPLASH] = rec(85, 0, 0, 0, 40, 0, 0x10, 0, 0x00)    -- battle_moves.h:1953

local function battle(values, opts)
  opts = opts or {}
  local engine = BattleEngine.new({
    player = BattleEngine.makeBattler({ species = 1, level = 10,
      stats = { hp = opts.playerHP or 400, attack = 20, defense = 20,
        speed = opts.playerSpeed or 30, spAttack = 20, spDefense = 20 },
      types = opts.playerTypes or { Data.TYPE_PSYCHIC, Data.TYPE_PSYCHIC },
      moves = { { move = opts.playerMove or PRESENT, pp = opts.playerPP or 15 } } }),
    foe = BattleEngine.makeBattler({ species = 19, level = 10,
      stats = { hp = opts.foeHP or 400, attack = 20, defense = 20, speed = opts.foeSpeed or 20,
        spAttack = 20, spDefense = 20 },
      types = opts.foeTypes or { Data.TYPE_WATER, Data.TYPE_WATER },
      moves = { { move = opts.foeMove or SPLASH, pp = 15 } } }),
    moves = moves, typeChart = Data.typeChart, rng = scriptedRng(values or {}),
  })
  engine.player.ability, engine.foe.ability = 0, 0
  if opts.playerCurrentHP then engine.player.hp = opts.playerCurrentHP end
  if opts.foeCurrentHP then engine.foe.hp = opts.foeCurrentHP end
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
local function resolve(engine, side)
  local events = {}
  engine:resolveMove(side or "player", 1, events)
  return events
end
local function texts(engine, events)
  local c = BattleSceneController.new({ engine = engine, playerName = "PLAYER", foeName = "FOE",
    introMessages = {}, moveName = function(id) return id == PRESENT and "PRESENT" or "MOVE" end })
  local out = {}
  for _, entry in ipairs(c:_eventMessages(events)) do
    out[#out + 1] = entry.text or ("[hp " .. entry.hpSide .. " " .. entry.hp .. "]")
  end
  return table.concat(out, "|")
end

-- 1. The roll helper: every boundary of the source thresholds.
local cases = { {0, 40}, {101, 40}, {102, 80}, {177, 80}, {178, 120}, {203, 120} }
for _, c in ipairs(cases) do
  check("presentPowerFromRoll(" .. c[1] .. ") == " .. c[2], BattleEngine.presentPowerFromRoll(c[1]) == c[2])
end
check("presentPowerFromRoll(204) is the heal branch", BattleEngine.presentPowerFromRoll(204) == nil)
check("presentPowerFromRoll(255) is the heal branch", BattleEngine.presentPowerFromRoll(255) == nil)
check("presentPowerFromRoll rejects a non-byte", not pcall(BattleEngine.presentPowerFromRoll, 256))

-- 2. Review F8: rolls 101, 102, 177, 178, 203, 204 select 40, 80, 80, 120,
-- 120, heal. Draws: accuracy 0 (hit), the roll, crit 1 (no crit), random 0
-- (100%). The roll is drawn as a u16 and masked: 0x100 + r tests the `& 0xFF`.
local rollCases = {
  { 101, 6 }, { 102, 11 }, { 177, 11 }, { 178, 16 }, { 203, 16 },
}
for _, c in ipairs(rollCases) do
  local e = battle({ 0, 0x100 + c[1], 1, 0 })
  local events = resolve(e)
  local dmg = find(events, "damage")
  check("roll " .. c[1] .. ": damage " .. c[2], dmg and dmg.amount == c[2] and e.foe.hp == 400 - c[2],
    dmg and dmg.amount)
  check("roll " .. c[1] .. ": 4 draws (acc, roll, crit, random)", e.rng.draws == 4, e.rng.draws)
  check("roll " .. c[1] .. ": events", sig(events) == "useMove:player,damage:player", sig(events))
  check("roll " .. c[1] .. ": 1 PP spent", e.player.moves[1].pp == 14)
end
do
  -- Roll 204 against a damaged foe: heal maxHP/4 = 100 (200 -> 300), 2
  -- draws, no crit/random.
  local e = battle({ 0, 0x100 + 204, 1, 0 }, { foeCurrentHP = 200 })
  local events = resolve(e)
  local heal = find(events, "restoreHP")
  check("roll 204: heals the target by maxHP/4", heal and heal.side == "foe" and heal.beforeHP == 200
    and heal.hpRemaining == 300 and heal.amount == 100 and e.foe.hp == 300)
  check("roll 204: 2 draws (acc, roll)", e.rng.draws == 2, e.rng.draws)
  check("roll 204: events", sig(events) == "useMove:player,restoreHP:foe", sig(events))
  check("roll 204: player HP untouched", e.player.hp == 400)
  check("roll 204: 1 PP spent", e.player.moves[1].pp == 14)
  check("roll 204: not move damage", e.foe.tookMoveDamage == false)
end
do
  local e = battle({ 0, 255, 1, 0 }, { foeCurrentHP = 1 })
  resolve(e)
  check("roll 255: heal branch too", e.foe.hp == 101 and e.rng.draws == 2)
end

-- 3. Damage branch details.
do
  -- Crit (draw 0 on crit): 6 * 2 = 12.
  local e = battle({ 0, 0, 0, 0 })
  local events = resolve(e)
  check("crit: 40 power doubled to 12", find(events, "damage").amount == 12
    and sig(events) == "useMove:player,critical:player,damage:player", sig(events))
  check("crit: 4 draws", e.rng.draws == 4)
  -- Random 15 at 120: 16 * 85 / 100 = 13.
  e = battle({ 0, 200, 1, 15 })
  events = resolve(e)
  check("random 85% at 120: 13", find(events, "damage").amount == 13)
  -- The shared record keeps power 1 (local copy only; the AI reads it).
  check("ROM record power unchanged", moves[PRESENT].power == 1)
  -- Ghost target, damage branch: crit and random still drawn, noEffect.
  e = battle({ 0, 50, 1, 0 }, { foeTypes = { Data.TYPE_GHOST, Data.TYPE_GHOST } })
  events = resolve(e)
  check("ghost damage branch: noEffect", sig(events) == "useMove:player,noEffect:player", sig(events))
  check("ghost damage branch: 4 draws", e.rng.draws == 4, e.rng.draws)
  check("ghost damage branch: no HP change", e.foe.hp == 400)
end

-- 4. Heal branch details.
do
  -- A Ghost target IS healed (DOESNT_AFFECT_FOE cleared).
  local e = battle({ 0, 230 }, { foeTypes = { Data.TYPE_GHOST, Data.TYPE_GHOST }, foeCurrentHP = 100 })
  local events = resolve(e)
  check("ghost heal branch: healed", e.foe.hp == 200 and sig(events) == "useMove:player,restoreHP:foe",
    sig(events))
  check("ghost heal branch: 2 draws", e.rng.draws == 2)
  -- Clamp at maxHP: 350 + 100 -> 400, amount 50.
  e = battle({ 0, 210 }, { foeCurrentHP = 350 })
  events = resolve(e)
  local heal = find(events, "restoreHP")
  check("heal clamps at maxHP", e.foe.hp == 400 and heal.amount == 50 and heal.hpRemaining == 400)
  -- maxHP 3: 3/4 = 0 -> 1.
  e = battle({ 0, 210 }, { foeHP = 3, foeCurrentHP = 1 })
  events = resolve(e)
  check("heal minimum 1 (maxHP 3)", e.foe.hp == 2 and find(events, "restoreHP").amount == 1)
  -- maxHP 7: 7/4 = 1.
  e = battle({ 0, 210 }, { foeHP = 7, foeCurrentHP = 2 })
  resolve(e)
  check("heal floor(7/4) = 1", e.foe.hp == 3)
  -- Full HP: "HP is full!", 2 draws, nothing changes.
  e = battle({ 0, 204 })
  events = resolve(e)
  check("full HP: restoreHPFull on the target",
    sig(events) == "useMove:player,restoreHPFull:foe" and e.foe.hp == 400, sig(events))
  check("full HP: 2 draws, PP spent", e.rng.draws == 2 and e.player.moves[1].pp == 14)
  -- The foe's Present heals the PLAYER.
  e = battle({ 0, 240 }, { foeMove = PRESENT, playerCurrentHP = 40 })
  events = resolve(e, "foe")
  check("foe's Present heals the player", e.player.hp == 140 and find(events, "restoreHP").side == "player"
    and e.foe.hp == 400)
  -- A frozen target healed by Present stays frozen (no move damage, Normal).
  e = battle({ 0, 240 }, { foeCurrentHP = 100 })
  e.foe.status = S.FREEZE
  resolve(e)
  check("heal does not thaw", S.isFrozen(e.foe.status) and e.foe.hp == 200)
end

-- 5. Miss, protected and semi-invulnerable targets.
do
  -- Accuracy 90: draw 99 -> 100 > 90, miss. One draw, PP spent.
  local e = battle({ 99, 0, 0, 0 })
  local events = resolve(e)
  check("miss: 1 draw", e.rng.draws == 1, e.rng.draws)
  check("miss: events", sig(events) == "useMove:player,miss:player", sig(events))
  check("miss: PP spent", e.player.moves[1].pp == 14)
  -- Draw 89 -> 90 > 90 is false: hit (the roll then follows).
  e = battle({ 89, 0, 1, 0 })
  resolve(e)
  check("accuracy boundary 90 hits", e.rng.draws == 4 and e.foe.hp == 394)
  -- Review F7: a Fly target misses before Random(): 0 draws, PP spent.
  e = battle({ 0, 0, 0, 0 })
  e.foe.semiInvulnerable = "air"
  events = resolve(e)
  check("fly target: 0 draws", e.rng.draws == 0, e.rng.draws)
  check("fly target: miss", sig(events) == "useMove:player,miss:player", sig(events))
  check("fly target: PP spent", e.player.moves[1].pp == 14)
  e = battle({ 0, 0, 0, 0 })
  e.foe.semiInvulnerable = "underground"
  events = resolve(e)
  check("dig target: 0 draws, miss", e.rng.draws == 0 and sig(events) == "useMove:player,miss:player")
  -- Protected: 0 draws, the protected text, PP spent.
  e = battle({ 0, 210, 0, 0 }, { foeCurrentHP = 100 })
  e.foe.protected = true
  events = resolve(e)
  check("protected: 0 draws", e.rng.draws == 0, e.rng.draws)
  check("protected: events", sig(events) == "useMove:player,protected:player", sig(events))
  check("protected: no heal, PP spent", e.foe.hp == 100 and e.player.moves[1].pp == 14)
end

-- 6. Controller texts name the TARGET.
do
  local e = battle({ 0, 230 }, { foeCurrentHP = 100 })
  local events = resolve(e)
  check("text: heal names the target", texts(e, events) == "PLAYER used PRESENT!|[hp foe 200]|FOE regained\nhealth!",
    texts(e, events))
  e = battle({ 0, 230 })
  events = resolve(e)
  check("text: full HP names the target", texts(e, events) == "PLAYER used PRESENT!|FOE's\nHP is full!",
    texts(e, events))
  e = battle({ 0, 230 }, { foeMove = PRESENT, playerCurrentHP = 50 })
  events = resolve(e, "foe")
  check("text: foe's heal names the player",
    texts(e, events) == "FOE used PRESENT!|[hp player 150]|PLAYER regained\nhealth!", texts(e, events))
end

-- 7. Through runTurn: total draw counts of a whole turn. The player (speed
-- 30) moves first; the foe uses Splash (no draws). Heal turn: acc + roll = 2.
do
  local e = battle({ 0, 220 }, { foeCurrentHP = 100 })
  local events = e:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 })
  check("runTurn heal: 2 draws in the turn", e.rng.draws == 2, e.rng.draws)
  check("runTurn heal: foe healed then splashes", e.foe.hp == 200 and find(events, "splash") ~= nil)
  e = battle({ 0, 0, 1, 0 })
  events = e:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 })
  check("runTurn damage: 4 draws in the turn", e.rng.draws == 4, e.rng.draws)
  check("runTurn damage: foe took 6", e.foe.hp == 394)
  -- Oak's first-battle damage flag is not advanced by a heal. The
  -- FIRST_BATTLE controller skips the player's first accuracy draw, so the
  -- roll is the only draw.
  e = battle({ 220 }, { foeCurrentHP = 100 })
  e.firstBattle = true
  e:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 })
  check("first battle: heal does not set the damage tutorial flag",
    not e.tutorialPlayerDamageDone and e.foe.hp == 200 and e.rng.draws == 1, e.rng.draws)
end

-- 8. The admission predicate is unchanged (positive-power fallback).
check("Present admitted", BattleEngine.supportsMove(battle(), moves[PRESENT], PRESENT))

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
