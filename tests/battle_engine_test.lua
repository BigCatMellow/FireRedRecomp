-- Run: lua5.1 tests/battle_engine_test.lua
--   (optionally POKEPORT_ROM=/path/to/pokefirered.gba lua5.1 ...)
--
-- Covers the pure 1v1 direct-damage vertical slice and its one-way rules
-- event stream. Battle data is transcribed in battle_test_data.lua so the
-- core suite remains no-ROM; the optional final section cross-checks that
-- transcription against the verified retail ROM.
package.path = package.path .. ";./?.lua"
local BattleEngine = require("src.core.BattleEngine")
local PokemonStats = require("src.core.PokemonStats")
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

local zero = { hp = 0, attack = 0, defense = 0, speed = 0, spAttack = 0, spDefense = 0 }
local neutral = { attack = 0, defense = 0, speed = 0, spAttack = 0, spDefense = 0 }
local bulbaStats = PokemonStats.calculateAll(Data.BULBASAUR, 5, zero, zero, neutral)
local charStats = PokemonStats.calculateAll(Data.CHARMANDER, 5, zero, zero, neutral)

local function makeBattle(values, playerMoves, foeMoves, foeCatchRate)
  return BattleEngine.new({
    player = BattleEngine.makeBattler({ species = 1, level = 5, stats = bulbaStats, types = Data.BULBASAUR.types, moves = playerMoves }),
    foe = BattleEngine.makeBattler({ species = 4, catchRate = foeCatchRate, level = 5, stats = charStats, types = Data.CHARMANDER.types, moves = foeMoves }),
    moves = Data.moves, typeChart = Data.typeChart, rng = scriptedRng(values),
  })
end

check("real Lv5 Bulbasaur fixture stats are HP19/Atk9/Speed9", bulbaStats.hp == 19 and bulbaStats.attack == 9 and bulbaStats.speed == 9)
check("real Lv5 Charmander fixture stats are HP18/SpA11/Speed11", charStats.hp == 18 and charStats.spAttack == 11 and charStats.speed == 11)

-- Charmander is faster. Each successful attack takes accuracy/crit/random
-- draws. `0,1,0` means hit, no crit, 100% damage. Ember (EFFECT_BURN_HIT)
-- then takes its seteffectwithchance roll: 99 > 10 means no burn. Ember's real direct
-- damage is 14, Tackle's is 4 (Bulbasaur is not Normal-type).
local battle = makeBattle(
  { 0, 1, 0, 99, 0, 1, 0, 0, 1, 0 },
  { { move = Data.MOVE_TACKLE, pp = 35 } },
  { { move = Data.MOVE_EMBER, pp = 25 } }
)
local events = battle:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 })
check("faster foe uses Ember first", events[2].type == "useMove" and events[2].side == "foe")
check("Ember event reports real 14 damage", events[3].type == "damage" and events[3].amount == 14 and events[3].hpRemaining == 5, events[3] and events[3].amount)
check("player still gets its turn while alive", events[4].type == "useMove" and events[4].side == "player")
check("Tackle event reports real 4 damage", events[5].type == "damage" and events[5].amount == 4 and events[5].hpRemaining == 14, events[5] and events[5].amount)
check("both attacks used exactly seven RNG draws (Ember's burn roll)", battle.rng.draws == 7, battle.rng.draws)
check("PP is deducted from both successful moves", battle.player.moves[1].pp == 34 and battle.foe.moves[1].pp == 24)

events = battle:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 })
check("second Ember faints the player", events[3].type == "damage" and events[3].hpRemaining == 0 and events[4].type == "faint" and events[5].type == "battleEnd")
check("faint ends the 1v1 battle as playerLost", battle.outcome == "playerLost")
check("fainted player does not get a second action", #events == 5, #events)

-- Magnitude is the bounded effect-126 leaf: its nominal catalog power stays
-- one, while exactly one pre-accuracy roll selects an ephemeral power/level.
local magnitudeMoves = {}
for k, v in pairs(Data.moves) do magnitudeMoves[k] = v end
magnitudeMoves[222] = { effect=126, power=1, type=Data.TYPE_GROUND, accuracy=95,
  pp=30, secondaryEffectChance=0, target=0, priority=0, flags=0x12 }
local function magnitudeBattle(values, side)
  local playerMoves = { {move=222,pp=30} }
  local foeMoves = { {move=222,pp=30} }
  local b = BattleEngine.new({
    player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves=playerMoves}),
    foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves=foeMoves}),
    moves=magnitudeMoves,typeChart=Data.typeChart,rng=scriptedRng(values),
  })
  return b, side or BattleEngine.SIDE_PLAYER
end
local magnitudeTable = {
  {0,4,10},{4,4,10},{5,5,30},{14,5,30},{15,6,50},{34,6,50},
  {35,7,70},{64,7,70},{65,8,90},{84,8,90},{85,9,110},{94,9,110},{95,10,150},{99,10,150},
}
for _, row in ipairs(magnitudeTable) do
  local level, power = BattleEngine.magnitudeResultFromRoll(row[1])
  check(("Magnitude residue %d maps to literal level/power"):format(row[1]), level == row[2] and power == row[3])
end
local magnitudeBattleHit = magnitudeBattle({35,0,1,0})
events = {}; magnitudeBattleHit:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
check("Magnitude hit deducts one PP, preserves nominal power, and orders use/level/result",
  magnitudeBattleHit.player.moves[1].pp == 29 and magnitudeMoves[222].power == 1
    and events[1].type == "useMove" and events[2].type == "magnitude" and events[2].level == 7
    and events[3].type == "damage", events[3] and events[3].type)
check("ordinary Magnitude hit consumes strength, accuracy, critical, and damage draws", magnitudeBattleHit.rng.draws == 4, magnitudeBattleHit.rng.draws)
local magnitudeBattleMiss = magnitudeBattle({0,95})
events = {}; magnitudeBattleMiss:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
check("Magnitude miss retains PP and level event before miss with two draws",
  magnitudeBattleMiss.player.moves[1].pp == 29 and events[1].type == "useMove"
    and events[2].type == "magnitude" and events[3].type == "miss" and magnitudeBattleMiss.rng.draws == 2,
  magnitudeBattleMiss.rng.draws)
local magnitudeFoe = magnitudeBattle({95,0,1,0})
events = {}; magnitudeFoe:resolveMove(BattleEngine.SIDE_FOE,1,events)
check("Magnitude foe side retains the same singleton event and four-draw contract",
  events[1].side == "foe" and events[2].type == "magnitude" and events[2].side == "foe" and magnitudeFoe.rng.draws == 4,
  magnitudeFoe.rng.draws)
local magnitudeTutorial = magnitudeBattle({65,1,0})
magnitudeTutorial.firstBattle = true
events = {}; magnitudeTutorial:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
check("firstBattle player Magnitude bypasses accuracy but retains one strength/crit/damage draw each",
  events[2].type == "magnitude" and events[3].type == "damage" and magnitudeTutorial.rng.draws == 3,
  magnitudeTutorial.rng.draws)
local magnitudeNoEffect = magnitudeBattle({0,0,1,0})
magnitudeNoEffect.moves[222].type = Data.TYPE_ELECTRIC
magnitudeNoEffect.foe.types = {Data.TYPE_GROUND,Data.TYPE_GROUND}
events = {}; magnitudeNoEffect:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
check("Magnitude no-effect follows post-accuracy critical/damage draws after level event",
  events[1].type == "useMove" and events[2].type == "magnitude" and events[3].type == "noEffect"
    and magnitudeNoEffect.rng.draws == 4, magnitudeNoEffect.rng.draws)
local ordinaryAfterMagnitude = magnitudeBattle({0,1,0})
ordinaryAfterMagnitude.moves[222] = {effect=0,power=35,type=Data.TYPE_NORMAL,accuracy=95,pp=35,priority=0}
ordinaryAfterMagnitude.player.moves[1].move = 222
events = {}; ordinaryAfterMagnitude:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
check("non-126 path retains prior use/damage ordering and three draws",
  events[1].type == "useMove" and events[2].type == "damage" and ordinaryAfterMagnitude.rng.draws == 3,
  ordinaryAfterMagnitude.rng.draws)

-- Misses still consume PP, but neither crit nor random-damage RNG.
battle = makeBattle({ 95 }, { { move = Data.MOVE_TACKLE, pp = 1 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
events = battle:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 })
check("a 95-accuracy Tackle misses on real roll 96", events[3].type == "miss")
check("a miss still deducts PP", battle.foe.moves[1].pp == 0)
check("miss consumes only its accuracy RNG before the other action", battle.rng.draws >= 1)

-- Electric versus Ground confirms no-effect bypasses the random-damage
-- command after accuracy + crit. Add the synthetic direct-damage move to a
-- private copy so the real fixture remains a verbatim ROM transcription.
local moves = {}
for k, v in pairs(Data.moves) do moves[k] = v end
moves[999] = { power = 40, type = Data.TYPE_ELECTRIC, accuracy = 100, priority = 0 }
local groundFoe = BattleEngine.makeBattler({ species = 0, level = 5, stats = charStats, types = { Data.TYPE_GROUND, Data.TYPE_GROUND }, moves = { { move = Data.MOVE_TACKLE, pp = 1 } } })
local electricPlayer = BattleEngine.makeBattler({ species = 0, level = 5, stats = bulbaStats, types = { Data.TYPE_ELECTRIC, Data.TYPE_ELECTRIC }, moves = { { move = 999, pp = 1 } } })
battle = BattleEngine.new({ player = electricPlayer, foe = groundFoe, moves = moves, typeChart = Data.typeChart, rng = scriptedRng({ 0, 1 }) })
 battle.player.speed = 20
events = battle:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 })
check("type immunity emits noEffect and leaves HP unchanged", events[3].type == "noEffect" and battle.foe.hp == charStats.hp)
check("type immunity still consumes real random-damage RNG", battle.rng.draws == 6, battle.rng.draws)

-- Fixed-damage scripts share accuracy/PP/typecalc, but deliberately do not
-- call critcalc or adjustnormaldamage. Keep their test-only move records
-- private so battle_test_data.lua remains a verbatim retail transcription.
local fixedMoves = {}
for k, v in pairs(Data.moves) do fixedMoves[k] = v end
fixedMoves[990] = { effect = 41, power = 1, type = Data.TYPE_DRAGON, accuracy = 100, pp = 10, priority = 0 }
fixedMoves[991] = { effect = 87, power = 1, type = Data.TYPE_GHOST, accuracy = 100, pp = 15, priority = 0 }
fixedMoves[992] = { effect = 130, power = 1, type = Data.TYPE_NORMAL, accuracy = 90, pp = 20, priority = 0 }
local function fixedBattle(moveId, playerTypes, foeTypes, playerLevel, foeHP, values)
  return BattleEngine.new({
    player = BattleEngine.makeBattler({ species = 1, level = playerLevel or 5,
      stats = bulbaStats, types = playerTypes, moves = { { move = moveId, pp = fixedMoves[moveId].pp } } }),
    foe = BattleEngine.makeBattler({ species = 4, level = 5, stats = charStats,
      hp = foeHP, types = foeTypes, moves = { { move = Data.MOVE_TACKLE, pp = 1 } } }),
    moves = fixedMoves, typeChart = Data.typeChart, rng = scriptedRng(values or { 0 }),
  })
end

battle = fixedBattle(990, { Data.TYPE_DRAGON, Data.TYPE_DRAGON },
  { Data.TYPE_DRAGON, Data.TYPE_DRAGON }, 5, 99, { 0 })
events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Dragon Rage deals fixed 40 through a super-effective typecalc", events[2].type == "damage"
  and events[2].amount == 40 and events[2].hpRemaining == 59, events[2] and events[2].amount)
check("Dragon Rage suppresses effectiveness and skips crit/random RNG", events[2].superEffective == false
  and events[2].notVeryEffective == false and #events == 2 and battle.rng.draws == 1, battle.rng.draws)

battle = fixedBattle(991, { Data.TYPE_GHOST, Data.TYPE_GHOST },
  { Data.TYPE_PSYCHIC, Data.TYPE_PSYCHIC }, 37, 99, { 0 })
events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("level-damage effect uses attacker level, not stats or move power", events[2].type == "damage"
  and events[2].amount == 37 and events[2].hpRemaining == 62, events[2] and events[2].amount)
check("level-damage suppresses a super-effective presentation and skips crit/random RNG",
  events[2].superEffective == false and events[2].notVeryEffective == false and #events == 2 and battle.rng.draws == 1,
  battle.rng.draws)

battle = fixedBattle(992, { Data.TYPE_NORMAL, Data.TYPE_NORMAL },
  { Data.TYPE_ROCK, Data.TYPE_ROCK }, 5, 99, { 0 })
events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("SonicBoom deals fixed 20 through a not-very-effective typecalc", events[2].type == "damage"
  and events[2].amount == 20 and events[2].hpRemaining == 79, events[2] and events[2].amount)
check("SonicBoom suppresses not-very-effective presentation and skips crit/random RNG",
  events[2].superEffective == false and events[2].notVeryEffective == false and #events == 2 and battle.rng.draws == 1,
  battle.rng.draws)

battle = fixedBattle(992, { Data.TYPE_NORMAL, Data.TYPE_NORMAL },
  { Data.TYPE_GHOST, Data.TYPE_GHOST }, 5, nil, { 0 })
events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("SonicBoom type immunity blocks HP loss without crit/random RNG", events[2].type == "noEffect"
  and battle.foe.hp == charStats.hp and #events == 2 and battle.rng.draws == 1, battle.rng.draws)

battle = fixedBattle(992, { Data.TYPE_NORMAL, Data.TYPE_NORMAL },
  { Data.TYPE_FIRE, Data.TYPE_FIRE }, 5, nil, { 90 })
events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("fixed-damage miss spends PP but only accuracy RNG", events[2].type == "miss"
  and battle.player.moves[1].pp == 19 and battle.rng.draws == 1, battle.rng.draws)

battle = fixedBattle(992, { Data.TYPE_NORMAL, Data.TYPE_NORMAL },
  { Data.TYPE_FIRE, Data.TYPE_FIRE }, 5, 15, { 0 })
events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("fixed damage clamps through ordinary HP application", events[2].type == "damage"
  and events[2].amount == 15 and events[2].hpRemaining == 0, events[2] and events[2].amount)

-- EFFECT_ALWAYS_HIT uses the stock no-accuracy-roll branch. These private
-- records keep battle_test_data.lua a verbatim retail transcription.
local alwaysHitMoves = {}
for k, v in pairs(Data.moves) do alwaysHitMoves[k] = v end
alwaysHitMoves[993] = { effect = 17, power = 60, type = Data.TYPE_NORMAL, accuracy = 0, pp = 20, priority = 0 }
alwaysHitMoves[994] = { effect = 0, power = 60, type = Data.TYPE_NORMAL, accuracy = 0, pp = 20, priority = 0 }
local function alwaysHitBattle(moveId, foeTypes, foeHP, values)
  return BattleEngine.new({
    player = BattleEngine.makeBattler({ species = 1, level = 5, stats = bulbaStats,
      types = { Data.TYPE_NORMAL, Data.TYPE_NORMAL }, moves = { { move = moveId, pp = 20 } } }),
    foe = BattleEngine.makeBattler({ species = 4, level = 5, stats = charStats,
      hp = foeHP, types = foeTypes, moves = { { move = Data.MOVE_TACKLE, pp = 1 } } }),
    moves = alwaysHitMoves, typeChart = Data.typeChart, rng = scriptedRng(values),
  })
end

battle = alwaysHitBattle(993, { Data.TYPE_FIRE, Data.TYPE_FIRE }, 99, { 15, 0 })
events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("always-hit effect lands with zero accuracy and still deducts PP", events[1].type == "useMove"
  and events[2].type == "damage" and battle.player.moves[1].pp == 19, events[2] and events[2].type)
check("always-hit skips only accuracy RNG and retains crit/random rolls", #events == 2
  and battle.rng.draws == 2, battle.rng.draws)

battle = alwaysHitBattle(993, { Data.TYPE_FIRE, Data.TYPE_FIRE }, 99, { 0, 0 })
events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("always-hit preserves the ordinary critical branch", events[2].type == "critical"
  and events[3].type == "damage" and battle.rng.draws == 2, battle.rng.draws)

-- EFFECT_HIGH_CRITICAL keeps the ordinary hit pipeline but passes critcalc
-- stage 1 (1/8) instead of ordinary stage 0 (1/16). Private records keep the
-- shared retail transcription untouched. RNG values are accuracy, crit, random.
local highCritMoves = {}
for k, v in pairs(Data.moves) do highCritMoves[k] = v end
highCritMoves[995] = { effect = 43, power = 60, type = Data.TYPE_NORMAL, accuracy = 100, pp = 20, priority = 0 }
highCritMoves[996] = { effect = 0, power = 60, type = Data.TYPE_NORMAL, accuracy = 100, pp = 20, priority = 0 }
local function highCritBattle(moveId, values)
  return BattleEngine.new({
    player = BattleEngine.makeBattler({ species = 1, level = 5, stats = bulbaStats,
      types = { Data.TYPE_NORMAL, Data.TYPE_NORMAL }, moves = { { move = moveId, pp = 20 } } }),
    foe = BattleEngine.makeBattler({ species = 4, level = 5, stats = charStats,
      types = { Data.TYPE_FIRE, Data.TYPE_FIRE }, moves = { { move = Data.MOVE_TACKLE, pp = 1 } } }),
    moves = highCritMoves, typeChart = Data.typeChart, rng = scriptedRng(values),
  })
end

battle = highCritBattle(995, { 0, 8, 0 })
events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("high-critical stage one crits at the 1/8 boundary", events[2].type == "critical"
  and events[3].type == "damage" and battle.rng.draws == 3, battle.rng.draws)
check("high-critical keeps ordinary PP and random-damage paths", battle.player.moves[1].pp == 19
  and events[3].amount > 0, events[3] and events[3].amount)

battle = highCritBattle(996, { 0, 8, 0 })
events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("ordinary effect remains stage zero at the high-critical boundary", events[2].type == "damage"
  and battle.rng.draws == 3, events[2] and events[2].type)

-- EFFECT_FALSE_SWIPE runs the ordinary hit pipeline, then caps only a lethal
-- final damage result at target HP - 1. Private records preserve retail data.
local falseSwipeMoves = {}
for k, v in pairs(Data.moves) do falseSwipeMoves[k] = v end
falseSwipeMoves[997] = { effect = 101, power = 120, type = Data.TYPE_NORMAL, accuracy = 100, pp = 20, priority = 0 }
falseSwipeMoves[998] = { effect = 0, power = 120, type = Data.TYPE_NORMAL, accuracy = 100, pp = 20, priority = 0 }
local function falseSwipeBattle(moveId, foeTypes, foeHP, values)
  return BattleEngine.new({
    player = BattleEngine.makeBattler({ species = 1, level = 5, stats = bulbaStats,
      types = { Data.TYPE_NORMAL, Data.TYPE_NORMAL }, moves = { { move = moveId, pp = 20 } } }),
    foe = BattleEngine.makeBattler({ species = 4, level = 5, stats = charStats,
      hp = foeHP, types = foeTypes, moves = { { move = Data.MOVE_TACKLE, pp = 1 } } }),
    moves = falseSwipeMoves, typeChart = Data.typeChart, rng = scriptedRng(values),
  })
end

battle = falseSwipeBattle(997, { Data.TYPE_FIRE, Data.TYPE_FIRE }, 1, { 0, 15, 0 })
events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("False Swipe leaves a one-HP target at one HP", events[2].type == "damage"
  and events[2].amount == 0 and battle.foe.hp == 1 and battle.rng.draws == 3, events[2] and events[2].amount)
check("False Swipe retains PP and ordinary three-draw hit path", battle.player.moves[1].pp == 19, battle.player.moves[1].pp)

battle = falseSwipeBattle(997, { Data.TYPE_FIRE, Data.TYPE_FIRE }, 99, { 0, 15, 0 })
events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("False Swipe keeps nonlethal damage unchanged", events[2].type == "damage"
  and events[2].amount > 0 and battle.foe.hp < 99, events[2] and events[2].amount)

battle = falseSwipeBattle(997, { Data.TYPE_GHOST, Data.TYPE_GHOST }, 1, { 0, 15, 0 })
events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("False Swipe preserves type immunity", events[2].type == "noEffect"
  and battle.foe.hp == 1 and battle.rng.draws == 3, events[2] and events[2].type)

battle = falseSwipeBattle(998, { Data.TYPE_FIRE, Data.TYPE_FIRE }, 1, { 0, 15, 0 })
events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("ordinary move still faints a one-HP target", events[2].type == "damage"
  and events[2].amount == 1 and battle.foe.hp == 0, events[2] and events[2].amount)

battle = alwaysHitBattle(993, { Data.TYPE_GHOST, Data.TYPE_GHOST }, nil, { 0, 0 })
events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("always-hit preserves type immunity after its no-roll accuracy branch", events[2].type == "noEffect"
  and battle.foe.hp == charStats.hp and battle.rng.draws == 2, battle.rng.draws)

battle = alwaysHitBattle(993, { Data.TYPE_FIRE, Data.TYPE_FIRE }, 1, { 15, 0 })
events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("always-hit still clamps through ordinary HP application", events[2].type == "damage"
  and events[2].amount == 1 and events[2].hpRemaining == 0, events[2] and events[2].amount)

battle = alwaysHitBattle(994, { Data.TYPE_FIRE, Data.TYPE_FIRE }, nil, { 0 })
events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("non-effect-17 zero accuracy retains the ordinary miss behavior", events[2].type == "miss"
  and battle.player.moves[1].pp == 19 and battle.rng.draws == 1, battle.rng.draws)

-- EFFECT_VITAL_THROW shares the stock no-accuracy-roll command branch while
-- retaining a distinct effect id and the imported -1 move priority. Private
-- records preserve battle_test_data.lua as a verbatim retail transcription.
local vitalThrowMoves = {}
for k, v in pairs(Data.moves) do vitalThrowMoves[k] = v end
vitalThrowMoves[1001] = { effect = 78, power = 70, type = Data.TYPE_FIGHTING, accuracy = 100, pp = 10, priority = -1 }
vitalThrowMoves[1002] = { effect = 0, power = 70, type = Data.TYPE_FIGHTING, accuracy = 100, pp = 10, priority = -1 }
local function vitalThrowBattle(moveId, values)
  return BattleEngine.new({
    player = BattleEngine.makeBattler({ species = 1, level = 5, stats = bulbaStats,
      types = { Data.TYPE_FIGHTING, Data.TYPE_FIGHTING }, moves = { { move = moveId, pp = 10 } } }),
    foe = BattleEngine.makeBattler({ species = 4, level = 5, stats = charStats,
      types = { Data.TYPE_FIRE, Data.TYPE_FIRE }, moves = { { move = Data.MOVE_TACKLE, pp = 35 } } }),
    moves = vitalThrowMoves, typeChart = Data.typeChart, rng = scriptedRng(values),
  })
end

battle = vitalThrowBattle(1001, { 99, 0 })
battle.player.statStages.accuracy = 0
battle.foe.statStages.evasion = 12
events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Vital Throw bypasses modified accuracy and evasion stages", events[1].type == "useMove"
  and events[2].type == "damage" and battle.player.moves[1].pp == 9, events[2] and events[2].type)
check("Vital Throw skips only accuracy RNG and retains critical/random draws", battle.rng.draws == 2, battle.rng.draws)

battle = vitalThrowBattle(1002, { 99 })
battle.player.statStages.accuracy = 0
battle.foe.statStages.evasion = 12
events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("ordinary effect with Vital Throw fields still rolls and misses", events[2].type == "miss"
  and battle.player.moves[1].pp == 9 and battle.rng.draws == 1, events[2] and events[2].type)

battle = vitalThrowBattle(1001, { 0, 15, 0, 0, 15 })
battle.player.speed = 99
battle.foe.speed = 1
events = battle:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 })
check("Vital Throw priority minus one yields to a priority-zero move", events[2].type == "useMove"
  and events[2].side == BattleEngine.SIDE_FOE, events[2] and events[2].side)

-- A run action is hoisted ahead of any foe move. At equal-or-better speed
-- it succeeds with no RNG, so the foe never spends PP or attacks.
battle = makeBattle({}, { { move = Data.MOVE_TACKLE, pp = 1 } }, { { move = Data.MOVE_EMBER, pp = 1 } })
battle.player.speed = 20
events = battle:runTurn({ action = "run" }, { action = "move", moveSlot = 1 })
check("fast player run ends battle before foe action", events[2].type == "run" and events[2].success and #events == 3 and battle.outcome == "ran")
check("successful fast run consumes no RNG and no foe PP", battle.rng.draws == 0 and battle.foe.moves[1].pp == 1)

-- A Poke Ball is a B_ACTION_USE_ITEM, which SetActionsAndBattlersTurnOrder
-- places before move actions. Seeded/scripted capture rules consume their
-- shake draws from the same global RNG stream as the ensuing foe attack.
-- At full HP and catch rate 45, catch value=15 and threshold=32767: draw 0
-- passes (one shake), draw 65535 fails, then the foe's hit consumes its real
-- accuracy/crit/damage draws 0,1,0 and Ember's burn roll 99.
battle = makeBattle(
  { 0, 65535, 0, 1, 0, 99 },
  { { move = Data.MOVE_TACKLE, pp = 1 } },
  { { move = Data.MOVE_EMBER, pp = 1 } },
  45
)
events = battle:runTurn({ action = "capture" }, { action = "move", moveSlot = 1 })
check("Poke Ball resolves before the foe move", events[2].type == "throwBall" and events[3].type == "capture")
check("failed capture exposes one source shake", events[3].success == false and events[3].shakes == 1, events[3].shakes)
check("foe attacks after failed capture", events[4].type == "useMove" and events[4].side == "foe")
check("capture failure and foe attack share exact RNG stream", battle.rng.draws == 6, battle.rng.draws)
check("failed capture does not end battle", battle.outcome == nil)

-- Four passing shake draws catch and end the battle before the foe can act.
-- Catch rate 190 at 1/18 HP gives catch value 182 and threshold 61680.
battle = makeBattle(
  { 0, 1, 2, 3 },
  { { move = Data.MOVE_TACKLE, pp = 1 } },
  { { move = Data.MOVE_EMBER, pp = 1 } },
  190
)
battle.foe.hp = 1
events = battle:runTurn({ action = "capture" }, { action = "move", moveSlot = 1 })
check("four passing capture checks end battle as caught",
  events[3].type == "capture" and events[3].success and events[3].shakes == 4 and battle.outcome == "caught")
check("successful capture emits caught battleEnd and no foe move",
  events[4].type == "battleEnd" and events[4].outcome == "caught" and #events == 4, #events)
check("successful capture consumes four draws and no foe PP", battle.rng.draws == 4 and battle.foe.moves[1].pp == 1)

-- The formula must never guess a species catch rate.
battle = makeBattle({}, { { move = Data.MOVE_TACKLE, pp = 1 } }, { { move = Data.MOVE_EMBER, pp = 1 } })
local captureOk = pcall(function()
  battle:runTurn({ action = "capture" }, { action = "move", moveSlot = 1 })
end)
check("capture without ROM-derived catch rate fails loudly", not captureOk)

-- TryRunFromBattle compares raw BattlePokemon.speed, not the stage-modified
-- speed used by turn order. A +6 stage must not turn this slower runner
-- into an automatic escape.
battle = makeBattle({ 64 }, { { move = Data.MOVE_TACKLE, pp = 1 } }, { { move = Data.MOVE_EMBER, pp = 1 } })
battle.player.speed = 10
battle.foe.speed = 20
battle.player.statStages.speed = 12
events = battle:runTurn({ action = "run" }, { action = "move", moveSlot = 1 })
check("run ignores speed stages and can fail from raw speed", events[2].type == "run" and not events[2].success and battle.runTries == 1)

-- Full real single-stat stage-change family (BattleEngine.STAT_STAGE_MOVES):
-- self-target UP/UP_2 effects (BattleScript_EffectStatUp) have NO
-- accuracycheck step and cannot miss; opponent-target DOWN/DOWN_2 effects
-- (BattleScript_EffectStatDown) still roll accuracycheck, exactly like
-- Growl/Tail Whip's existing real path. Isolated with resolveMove directly
-- (rather than runTurn) so each RNG-draw-count assertion below is exact.
-- Real move records: Swords Dance (EFFECT_ATTACK_UP_2, self), Agility
-- (EFFECT_SPEED_UP_2, self), Amnesia (EFFECT_SPECIAL_DEFENSE_UP_2, self),
-- Sand-Attack (EFFECT_ACCURACY_DOWN, opponent), Screech
-- (EFFECT_DEFENSE_DOWN_2, opponent), String Shot (EFFECT_SPEED_DOWN,
-- opponent).

-- Growl/Tail Whip regression check under the new table-driven dispatch.
battle = makeBattle({ 0 }, { { move = Data.MOVE_GROWL, pp = 40 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
local statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Growl still lowers the foe's Attack by 1 real stage (regression)",
  statEvents[2].type == "statChange" and statEvents[2].side == "foe" and statEvents[2].stat == "attack"
    and statEvents[2].stages == -1 and statEvents[2].stage == 5, statEvents[2])
check("Growl still consumes exactly one accuracy RNG draw (regression)", battle.rng.draws == 1, battle.rng.draws)

-- Self-target UP move: zero RNG consumed, cannot miss, raises the user's
-- own stat by the real stage count.
battle = makeBattle({}, { { move = Data.MOVE_SWORDS_DANCE, pp = 30 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Swords Dance raises the user's own Attack by 2 real stages",
  statEvents[2].type == "statChange" and statEvents[2].side == "player" and statEvents[2].stat == "attack"
    and statEvents[2].stages == 2 and statEvents[2].stage == 8, statEvents[2])
check("self-target stat-UP move consumes zero RNG (no real accuracycheck step)", battle.rng.draws == 0, battle.rng.draws)

battle = makeBattle({}, { { move = Data.MOVE_AGILITY, pp = 30 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Agility raises the user's own Speed by 2",
  statEvents[2].stat == "speed" and statEvents[2].stages == 2 and statEvents[2].stage == 8)
check("Agility also consumes zero RNG", battle.rng.draws == 0)

battle = makeBattle({}, { { move = Data.MOVE_AMNESIA, pp = 20 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Amnesia raises the user's own Sp. Defense by 2",
  statEvents[2].stat == "spDefense" and statEvents[2].stages == 2 and statEvents[2].stage == 8)

-- Opponent-target DOWN move: exactly one accuracy RNG draw is still
-- consumed on a hit, exactly like Growl/Tail Whip.
battle = makeBattle({ 0 }, { { move = Data.MOVE_SAND_ATTACK, pp = 15 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Sand-Attack lowers the foe's Accuracy by 1",
  statEvents[2].type == "statChange" and statEvents[2].side == "foe" and statEvents[2].stat == "accuracy"
    and statEvents[2].stages == -1 and statEvents[2].stage == 5)
check("opponent-target stat-DOWN move consumes exactly one accuracy RNG draw", battle.rng.draws == 1, battle.rng.draws)

battle = makeBattle({ 0 }, { { move = Data.MOVE_SCREECH, pp = 40 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Screech lowers the foe's Defense by 2 real stages",
  statEvents[2].stat == "defense" and statEvents[2].stages == -2 and statEvents[2].stage == 4)

battle = makeBattle({ 0 }, { { move = Data.MOVE_STRING_SHOT, pp = 40 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("String Shot lowers the foe's Speed by 1",
  statEvents[2].stat == "speed" and statEvents[2].stages == -1 and statEvents[2].stage == 5)

-- Boundary: already at MAX_STAT_STAGE (12) prevents a further UP move,
-- symmetric with the existing MIN-side Growl/Tail Whip behavior.
battle = makeBattle({}, { { move = Data.MOVE_SWORDS_DANCE, pp = 30 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
battle.player.statStages.attack = 12
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("stat-UP move already at MAX_STAT_STAGE is prevented, not silently clamped",
  statEvents[2].type == "statChange" and statEvents[2].stages == 0 and statEvents[2].prevented == true, statEvents[2])
check("prevented UP move still consumes zero RNG", battle.rng.draws == 0)

-- Boundary: already at MIN_STAT_STAGE (0) prevents a further DOWN move
-- (existing behavior, re-checked against the new table-driven dispatch).
battle = makeBattle({ 0 }, { { move = Data.MOVE_SAND_ATTACK, pp = 15 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
battle.foe.statStages.accuracy = 0
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("stat-DOWN move already at MIN_STAT_STAGE is prevented",
  statEvents[2].type == "statChange" and statEvents[2].stages == 0 and statEvents[2].prevented == true, statEvents[2])

-- A DOWN-family move can still miss (it does run accuracycheck); the miss
-- still deducts PP and consumes only its one accuracy draw.
battle = makeBattle({ 90 }, { { move = Data.MOVE_SCREECH, pp = 40 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("an 85-accuracy Screech misses on real roll 90", statEvents[2].type == "miss")
check("a missed stat-DOWN move still deducts PP", battle.player.moves[1].pp == 39)
check("a missed stat-DOWN move consumes exactly one RNG draw", battle.rng.draws == 1)

-- Real "_HIT" secondary-effect family (BattleEngine.HIT_VARIANT_STAT_
-- MOVES): an ordinary damaging move that, after the normal
-- accuracy/crit/damage/type pipeline, rolls a fresh
-- Random()%100<=secondaryEffectChance chance (Cmd_seteffectwithchance) to
-- also apply a 1-stage stat change. Real move records: Acid
-- (EFFECT_DEFENSE_DOWN_HIT, opponent, secondaryEffectChance=10), Psychic
-- (EFFECT_SPECIAL_DEFENSE_DOWN_HIT, opponent, chance=10), Metal Claw
-- (EFFECT_ATTACK_UP_HIT, self, chance=10), Steel Wing
-- (EFFECT_DEFENSE_UP_HIT, self, chance=10). Isolated with resolveMove
-- directly so each RNG-draw-count assertion is exact: a landed hit always
-- consumes accuracy(1) + crit(1) + damage-random-multiplier(1) +
-- seteffectwithchance(1) = 4 draws, regardless of whether the roll
-- succeeds.

-- Roll succeeds exactly at the real `<=percentChance` boundary (roll value
-- 10, chance 10): opponent-target DOWN_HIT lowers the foe's stat.
battle = makeBattle({ 0, 1, 0, 10 }, { { move = Data.MOVE_ACID, pp = 30 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Acid deals damage and, on a boundary-success roll, lowers the foe's Defense by 1",
  statEvents[2].type == "damage"
    and statEvents[3].type == "statChange" and statEvents[3].side == "foe"
    and statEvents[3].stat == "defense" and statEvents[3].stages == -1 and statEvents[3].stage == 5,
  statEvents[3])
check("a landed _HIT move consumes exactly four RNG draws (acc/crit/dmg/secondary)", battle.rng.draws == 4, battle.rng.draws)

-- Roll fails just past the boundary (roll value 11, chance 10): damage
-- still applies, no stat-change event, same four draws consumed.
battle = makeBattle({ 0, 1, 0, 11 }, { { move = Data.MOVE_ACID, pp = 30 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Acid still deals damage but a just-failed roll applies no stat change",
  statEvents[2].type == "damage" and #statEvents == 2, statEvents[3])
check("a failed secondary roll still consumes the same four RNG draws", battle.rng.draws == 4, battle.rng.draws)

-- Psychic: another opponent-target DOWN_HIT, different stat (Sp. Defense).
battle = makeBattle({ 0, 1, 0, 0 }, { { move = Data.MOVE_PSYCHIC, pp = 10 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Psychic on a successful roll lowers the foe's Sp. Defense by 1",
  statEvents[3].type == "statChange" and statEvents[3].side == "foe" and statEvents[3].stat == "spDefense"
    and statEvents[3].stages == -1 and statEvents[3].stage == 5, statEvents[3])

-- Metal Claw: self-target UP_HIT raises the user's own Attack.
battle = makeBattle({ 0, 1, 0, 0 }, { { move = Data.MOVE_METAL_CLAW, pp = 35 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Metal Claw on a successful roll raises the user's own Attack by 1",
  statEvents[3].type == "statChange" and statEvents[3].side == "player" and statEvents[3].stat == "attack"
    and statEvents[3].stages == 1 and statEvents[3].stage == 7, statEvents[3])

-- Steel Wing: self-target UP_HIT raises the user's own Defense.
battle = makeBattle({ 0, 1, 0, 0 }, { { move = Data.MOVE_STEEL_WING, pp = 25 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Steel Wing on a successful roll raises the user's own Defense by 1",
  statEvents[3].type == "statChange" and statEvents[3].side == "player" and statEvents[3].stat == "defense"
    and statEvents[3].stages == 1 and statEvents[3].stage == 7, statEvents[3])

-- A _HIT move can still miss (same accuracycheck as any damaging move); a
-- miss returns before ppreduce's later steps and never reaches
-- seteffectwithchance, consuming only its one accuracy draw.
battle = makeBattle({ 90 }, { { move = Data.MOVE_STEEL_WING, pp = 25 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("a 90-accuracy Steel Wing misses on real roll 91", statEvents[2].type == "miss")
check("a missed _HIT move consumes exactly one RNG draw and rolls no secondary chance",
  battle.rng.draws == 1, battle.rng.draws)

-- A 0x type-effectiveness hit still consumes the real seteffectwithchance
-- Random() call (it is the first operand of a short-circuiting C `&&`
-- chain and is NOT skipped by the no-effect check), but never applies the
-- effect -- verified here with secondaryEffectChance forced to 100 so a
-- skipped-vs-discarded roll would otherwise be unmistakable.
local hitVariantMoves = {}
for k, v in pairs(Data.moves) do hitVariantMoves[k] = v end
hitVariantMoves[997] = { effect = 68, power = 40, type = Data.TYPE_ELECTRIC, accuracy = 100, pp = 1,
                         secondaryEffectChance = 100, target = 0, priority = 0, flags = 0 }
local groundFoeHit = BattleEngine.makeBattler({ species = 0, level = 5, stats = charStats, types = { Data.TYPE_GROUND, Data.TYPE_GROUND }, moves = { { move = Data.MOVE_TACKLE, pp = 1 } } })
local electricPlayerHit = BattleEngine.makeBattler({ species = 0, level = 5, stats = bulbaStats, types = { Data.TYPE_ELECTRIC, Data.TYPE_ELECTRIC }, moves = { { move = 997, pp = 1 } } })
battle = BattleEngine.new({ player = electricPlayerHit, foe = groundFoeHit, moves = hitVariantMoves, typeChart = Data.typeChart, rng = scriptedRng({ 0, 1, 0, 0 }) })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("a type-immune _HIT move emits noEffect and applies no stat change even with a guaranteed-success chance",
  statEvents[2].type == "noEffect" and #statEvents == 2, statEvents[3])
check("no-effect still consumes all four real RNG draws, including the discarded secondary roll",
  battle.rng.draws == 4, battle.rng.draws)
check("no-effect _HIT move (EFFECT_ATTACK_DOWN_HIT) leaves the foe's Attack stage untouched",
  battle.foe.statStages.attack == 6, battle.foe.statStages.attack)

-- Boundary: user already at MAX_STAT_STAGE prevents a successful UP_HIT
-- roll from doing anything further, matching STAT_STAGE_MOVES's existing
-- boundary semantics -- still emitted as a prevented statChange event.
battle = makeBattle({ 0, 1, 0, 0 }, { { move = Data.MOVE_METAL_CLAW, pp = 35 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
battle.player.statStages.attack = 12
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Metal Claw's secondary effect at MAX_STAT_STAGE is prevented, not silently clamped",
  statEvents[3].type == "statChange" and statEvents[3].stages == 0 and statEvents[3].prevented == true, statEvents[3])

-- Boundary: opponent already at MIN_STAT_STAGE prevents a successful
-- DOWN_HIT roll.
battle = makeBattle({ 0, 1, 0, 0 }, { { move = Data.MOVE_ACID, pp = 30 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
battle.foe.statStages.defense = 0
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Acid's secondary effect at MIN_STAT_STAGE is prevented, not silently clamped",
  statEvents[3].type == "statChange" and statEvents[3].stages == 0 and statEvents[3].prevented == true, statEvents[3])

-- Real recoil family (BattleEngine.RECOIL_MOVES): EFFECT_RECOIL=48 (Take
-- Down, Submission, Struggle -- 25% recoil) and EFFECT_DOUBLE_EDGE=198
-- (Double-Edge -- 33% recoil). Real Cmd_seteffectsecondary's recoil cases
-- consume NO extra Random() call (MOVE_EFFECT_CERTAIN, not a chance roll),
-- so a landed hit consumes exactly the ordinary acc/crit/damage-multiplier
-- three draws -- one fewer than the _HIT family's four.
battle = makeBattle({ 0, 1, 0 }, { { move = Data.MOVE_TAKE_DOWN, pp = 20 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
local dealt = statEvents[2].amount
local expectedRecoil = math.floor(dealt / 4)
if expectedRecoil == 0 then expectedRecoil = 1 end
check("Take Down deals damage then docks the attacker 1/4 of the real dealt HP",
  statEvents[2].type == "damage"
    and statEvents[3].type == "recoil" and statEvents[3].side == "player"
    and statEvents[3].amount == expectedRecoil
    and statEvents[3].hpRemaining == bulbaStats.hp - expectedRecoil,
  statEvents[3])
check("a landed recoil move consumes exactly the ordinary three RNG draws (no extra roll)",
  battle.rng.draws == 3, battle.rng.draws)

battle = makeBattle({ 0, 1, 0 }, { { move = Data.MOVE_SUBMISSION, pp = 25 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
dealt = statEvents[2].amount
expectedRecoil = math.floor(dealt / 4)
if expectedRecoil == 0 then expectedRecoil = 1 end
check("Submission (also real EFFECT_RECOIL) docks the attacker the same 1/4 formula",
  statEvents[3].type == "recoil" and statEvents[3].amount == expectedRecoil, statEvents[3])

battle = makeBattle({ 0, 1, 0 }, { { move = Data.MOVE_DOUBLE_EDGE, pp = 15 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
dealt = statEvents[2].amount
expectedRecoil = math.floor(dealt / 3)
if expectedRecoil == 0 then expectedRecoil = 1 end
check("Double-Edge docks the attacker 1/3 of the real dealt HP (real EFFECT_DOUBLE_EDGE, separate id)",
  statEvents[3].type == "recoil" and statEvents[3].amount == expectedRecoil, statEvents[3])

-- Minimum-1 floor: clamp the defender to a tiny HP total so the real
-- already-clamped dealt-HP fraction floors to 0 and must be forced to 1,
-- exactly like real Cmd_seteffectsecondary's `if (gBattleMoveDamage == 0)
-- gBattleMoveDamage = 1`.
battle = makeBattle({ 0, 1, 0 }, { { move = Data.MOVE_TAKE_DOWN, pp = 20 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
battle.foe.hp = 2
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Take Down recoil floors to the real minimum of 1 when hpDealt/4 would round to 0",
  statEvents[2].amount == 2 and statEvents[3].amount == 1, statEvents[3])

battle = makeBattle({ 0, 1, 0 }, { { move = Data.MOVE_DOUBLE_EDGE, pp = 15 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
battle.foe.hp = 2
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Double-Edge recoil also floors to the real minimum of 1 (hpDealt/3 rounds to 0)",
  statEvents[2].amount == 2 and statEvents[3].amount == 1, statEvents[3])

-- Recoil never applies on a type-immune (no-effect) hit: real
-- Cmd_seteffectwithchance's MOVE_EFFECT_CERTAIN branch (how the recoil
-- family actually triggers) is explicitly gated on
-- `!(gMoveResultFlags & MOVE_RESULT_NO_EFFECT)`, and this is real-reachable
-- since Take Down/Double-Edge are Normal-type and Ghost is immune to Normal.
local recoilMoves = {}
for k, v in pairs(Data.moves) do recoilMoves[k] = v end
local ghostFoe = BattleEngine.makeBattler({ species = 0, level = 5, stats = charStats, types = { Data.TYPE_GHOST, Data.TYPE_GHOST }, moves = { { move = Data.MOVE_TACKLE, pp = 1 } } })
local normalAttacker = BattleEngine.makeBattler({ species = 0, level = 5, stats = bulbaStats, types = { Data.TYPE_NORMAL, Data.TYPE_NORMAL }, moves = { { move = Data.MOVE_TAKE_DOWN, pp = 20 } } })
battle = BattleEngine.new({ player = normalAttacker, foe = ghostFoe, moves = recoilMoves, typeChart = Data.typeChart, rng = scriptedRng({ 0, 1, 0 }) })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Take Down against a Ghost-type target emits noEffect and applies no recoil at all",
  statEvents[2].type == "noEffect" and #statEvents == 2, statEvents[3])
check("no-effect recoil consumes only the ordinary three RNG draws (no extra roll to skip)",
  battle.rng.draws == 3, battle.rng.draws)
check("no-effect recoil leaves the attacker's own HP untouched",
  battle.player.hp == bulbaStats.hp, battle.player.hp)

-- Real drain family (BattleEngine.DRAIN_MOVES): EFFECT_ABSORB=3 (Absorb,
-- Mega Drain, Giga Drain, Leech Life) heals the attacker 1/2 of the real
-- dealt HP, minimum 1, clamped at maxHP (real Cmd_datahpupdate's HP-goes-up
-- branch).
battle = makeBattle({ 0, 1, 0 }, { { move = Data.MOVE_ABSORB, pp = 20 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
battle.player.hp = 5
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
dealt = statEvents[2].amount
local expectedHeal = math.floor(dealt / 2)
if expectedHeal == 0 then expectedHeal = 1 end
check("Absorb deals damage then heals the attacker 1/2 of the real dealt HP",
  statEvents[3].type == "drain" and statEvents[3].side == "player"
    and statEvents[3].amount == expectedHeal
    and statEvents[3].hpRemaining == math.min(bulbaStats.hp, 5 + expectedHeal),
  statEvents[3])
check("a landed drain move also consumes exactly the ordinary three RNG draws", battle.rng.draws == 3)

-- Healing-clamp case: attacker missing only 1 HP, but the real dealt damage
-- is well over 2, so the naive 1/2 heal would push past maxHP -- must clamp
-- at maxHP exactly, matching this project's established heal-clamp pattern.
battle = makeBattle({ 0, 1, 0 }, { { move = Data.MOVE_ABSORB, pp = 20 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
battle.player.hp = bulbaStats.hp - 1
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Absorb's heal is clamped at the attacker's real maxHP, not overshot",
  statEvents[3].type == "drain" and battle.player.hp == bulbaStats.hp, battle.player.hp)

-- Minimum-1 floor for drain too.
battle = makeBattle({ 0, 1, 0 }, { { move = Data.MOVE_ABSORB, pp = 20 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
battle.foe.hp = 1
battle.player.hp = 5
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Absorb's heal floors to the real minimum of 1 when hpDealt/2 would round to 0",
  statEvents[2].amount == 1 and statEvents[3].amount == 1, statEvents[3])

-- Real attacker-faints-first ordering (verified against
-- BattleScript_MoveEffectRecoil/BattleScript_EffectAbsorb, both of which
-- run `tryfaintmon BS_ATTACKER` and RETURN before the calling script's
-- `tryfaintmon BS_TARGET`): a devastating recoil hit that both drops the
-- defender to 0 and recoils the attacker to 0 on the same swing must
-- resolve the attacker's own faint FIRST, deciding the real outcome even
-- though the defender also reaches 0 HP the same turn. Driven through
-- runTurn (not resolveMove directly) so the turn loop's own
-- faint-double-check guard is exercised too.
battle = makeBattle({ 0, 1, 0 }, { { move = Data.MOVE_TAKE_DOWN, pp = 20 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
battle.player.speed = 20 -- player strikes first
battle.player.hp = 1
battle.foe.hp = 1
events = battle:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 })
check("a lethal-both-ways recoil hit reports the attacker's own faint, not the defender's",
  events[3].type == "damage" and events[3].hpRemaining == 0
    and events[4].type == "recoil" and events[4].hpRemaining == 0
    and events[5].type == "faint" and events[5].side == "player"
    and events[6].type == "battleEnd" and events[6].outcome == "playerLost",
  events)
check("the real outcome is decided by the attacker's own faint (playerLost), not the defender's KO",
  battle.outcome == "playerLost")
check("the turn ends immediately after the attacker's own faint -- no duplicate defender faint event",
  #events == 6, #events)

-- supportsMove correctly rejects the real effect ids that the real
-- gBattleScriptsForMoveEffects table wires to BattleScript_EffectHit
-- instead of a stat-change script (see BattleEngine.lua's header note);
-- no real move uses any of these ids either.
check("supportsMove rejects EFFECT_SPEED_UP=12 (real id aliases to EffectHit)",
  not battle:supportsMove({ power = 0, effect = 12 }))
check("supportsMove rejects EFFECT_ACCURACY_UP_2=55 (real id aliases to EffectHit)",
  not battle:supportsMove({ power = 0, effect = 55 }))
check("supportsMove rejects EFFECT_EVASION_DOWN_2=64 (real id aliases to EffectHit)",
  not battle:supportsMove({ power = 0, effect = 64 }))
check("supportsMove still accepts EFFECT_ATTACK_UP_2=50 (Swords Dance's real effect)",
  battle:supportsMove({ power = 0, effect = 50 }))
-- EFFECT_DREAM_EATER=8 has power > 0 (it would otherwise pass the ordinary
-- damaging-move check) but real BattleScript_EffectDreamEater only works
-- against a sleeping target, a precondition this project doesn't model;
-- supportsMove must reject it explicitly rather than silently running it as
-- ordinary undrained damage.
check("supportsMove rejects EFFECT_DREAM_EATER=8 despite power > 0 (needs unmodeled sleep status)",
  not battle:supportsMove({ power = 100, effect = 8 }))

-- A zero-power status move is outside this direct-damage slice and must
-- fail loudly instead of being turned into accidental minimum damage.
local growlMoves = {}
for k, v in pairs(Data.moves) do growlMoves[k] = v end
growlMoves[Data.MOVE_GROWL] = { power = 0, type = Data.TYPE_NORMAL, accuracy = 100, priority = 0 }
battle = BattleEngine.new({
  player = BattleEngine.makeBattler({ species = 1, level = 5, stats = bulbaStats, types = Data.BULBASAUR.types, moves = { { move = Data.MOVE_GROWL, pp = 40 } } }),
  foe = BattleEngine.makeBattler({ species = 4, level = 5, stats = charStats, types = Data.CHARMANDER.types, moves = { { move = Data.MOVE_TACKLE, pp = 1 } } }),
  moves = growlMoves, typeChart = Data.typeChart, rng = scriptedRng({}),
})
local ok = pcall(function() battle:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 }) end)
check("unsupported zero-power move fails loudly", not ok)

-- Real AreAllMovesUnusable trigger: a battler with only ONE move slot at
-- 0 PP has ALL of its (one) move slots unusable, so real FireRed auto-
-- Struggles here rather than skipping the turn -- this is no longer the
-- old documented no-PP stub. `0,1,0` is Struggle's own accuracy/crit/
-- damage roll (hit, no crit, 100% multiplier); Struggle's real EFFECT_
-- RECOIL=48 damage/recoil math is exercised again below in more detail.
battle = makeBattle({ 0, 1, 0, 99, 0, 1, 0 }, { { move = Data.MOVE_TACKLE, pp = 0 } }, { { move = Data.MOVE_EMBER, pp = 1 } })
events = battle:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 })
local struggleUse
for _, e in ipairs(events) do
  if e.type == "useMove" and e.side == "player" then struggleUse = e end
end
check("a single 0-PP move slot auto-Struggles instead of the old noPP stub",
  struggleUse ~= nil and struggleUse.move == Data.MOVE_STRUGGLE)
check("Struggle's own slot PP is never touched by the auto-trigger",
  battle.player.moves[1].pp == 0)

-- Real defensive case: multiple move slots where only the SELECTED one is
-- at 0 PP while another slot still has PP. The real move-select menu would
-- never let a player submit this (a 0-PP move is greyed out while another
-- remains choosable), but this engine does no UI-level menu validation, so
-- it must not crash or fabricate an action -- confirmed from source
-- (AreAllMovesUnusable only fires when EVERY slot is unusable) that this
-- specific case is NOT an auto-Struggle trigger; the pre-existing no-op
-- {type="noPP"} path is correct here and is preserved unchanged.
battle = makeBattle({ 0, 1, 0, 99 },
  { { move = Data.MOVE_TACKLE, pp = 0 }, { move = Data.MOVE_EMBER, pp = 25 } },
  { { move = Data.MOVE_EMBER, pp = 1 } })
events = battle:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 })
check("selecting one empty slot while another still has PP still no-ops with noPP, not Struggle",
  (events[#events].type == "noPP" or events[2].type == "noPP")
  and battle.player.moves[1].pp == 0 and battle.player.moves[2].pp == 25)

-- All slots at 0 PP (multiple real move slots, all exhausted) auto-
-- Struggles regardless of which moveSlot the caller happens to request --
-- real AreAllMovesUnusable is a battler-wide precondition checked before
-- the requested slot is even looked at. Passing moveSlot=2 (itself a real,
-- empty, 0-PP slot) must still resolve Struggle's own real data
-- (self.moves[165]), not slot 2's move.
battle = makeBattle({ 0, 1, 0, 99, 0, 1, 0 },
  { { move = Data.MOVE_TACKLE, pp = 0 }, { move = Data.MOVE_EMBER, pp = 0 } },
  { { move = Data.MOVE_EMBER, pp = 1 } })
events = battle:runTurn({ action = "move", moveSlot = 2 }, { action = "move", moveSlot = 1 })
struggleUse = nil
for _, e in ipairs(events) do
  if e.type == "useMove" and e.side == "player" then struggleUse = e end
end
check("all move slots at 0 PP auto-Struggles even when moveSlot points at an empty slot",
  struggleUse ~= nil and struggleUse.move == Data.MOVE_STRUGGLE)
check("neither real move slot's PP changes when Struggle is auto-selected",
  battle.player.moves[1].pp == 0 and battle.player.moves[2].pp == 0)

-- Struggle is an ordinary accuracy-checked move (real accuracy=100, no
-- MOVE_STRUGGLE special case in Cmd_accuracycheck) -- it can miss like any
-- other move. With both battlers at neutral stat stages a real 100-
-- accuracy move mathematically cannot miss (calc=100, and roll%100+1 tops
-- out at 100), so raise the defender's evasion stage to real max (+6, real
-- MAX_STAT_STAGE=12) the same way a real Sand-Attack/Double Team sequence
-- would, dropping the effective hit ratio below 100 and making a miss
-- reachable via an ordinary roll -- confirming Struggle really runs
-- BattleFormulas.accuracyCheck with no special-casing, not a hidden
-- always-hit shortcut. Foe (faster) uses Ember first as a normal hit
-- (draws 1-3, burn roll draw 4), then the boosted-evasion foe causes the
-- player's Struggle accuracy roll (draw 5) to miss.
battle = makeBattle({ 0, 1, 0, 99, 50 }, { { move = Data.MOVE_TACKLE, pp = 0 } }, { { move = Data.MOVE_EMBER, pp = 1 } })
battle.foe.statStages.evasion = 12
events = battle:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 })
local playerMiss
for _, e in ipairs(events) do
  if e.type == "miss" and e.side == "player" then playerMiss = e end
end
check("Struggle runs the ordinary accuracy check and can miss",
  playerMiss ~= nil)
check("a missed Struggle still consumes no PP from any real slot",
  battle.player.moves[1].pp == 0)

-- Struggle deals damage and recoils the user via the already-implemented
-- EFFECT_RECOIL=48 path (BattleEngine.RECOIL_MOVES[48], divisor 4, min 1) --
-- this reuses the exact same recoil pipeline Take Down/Submission already
-- exercise above, so a passing assertion here is also a regression check
-- that recoil is still wired correctly for Struggle specifically.
battle = makeBattle({ 0, 1, 0, 99, 0, 1, 0 }, { { move = Data.MOVE_TACKLE, pp = 0 } }, { { move = Data.MOVE_EMBER, pp = 1 } })
events = battle:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 })
local dmgEvent, recoilEvent
for _, e in ipairs(events) do
  if e.type == "damage" and e.side == "player" then dmgEvent = e end
  if e.type == "recoil" and e.side == "player" then recoilEvent = e end
end
check("Struggle deals real damage", dmgEvent ~= nil and dmgEvent.amount > 0)
check("Struggle recoils the user via the existing RECOIL_MOVES[48] path",
  recoilEvent ~= nil and recoilEvent.amount == math.max(1, math.floor(dmgEvent.amount / 4)))

-- Real Cmd_typecalc special-cases MOVE_STRUGGLE to skip STAB/type-
-- effectiveness entirely: real Struggle hits a Ghost-type (normally
-- immune to Normal) for plain neutral, unblockable damage. Recoil is
-- still based on that real damage dealt, not on the fabricated-noEffect
-- zero the ordinary Normal-vs-Ghost type-chart row would otherwise give.
local ghostFoe = BattleEngine.makeBattler({ species = 0, level = 5, stats = charStats,
  types = { Data.TYPE_GHOST, Data.TYPE_GHOST }, moves = { { move = Data.MOVE_TACKLE, pp = 1 } } })
battle = BattleEngine.new({
  player = BattleEngine.makeBattler({ species = 1, level = 5, stats = bulbaStats, types = Data.BULBASAUR.types,
    moves = { { move = Data.MOVE_TACKLE, pp = 0 } } }),
  foe = ghostFoe, moves = Data.moves, typeChart = Data.typeChart, rng = scriptedRng({ 0, 1, 0, 0, 1, 0 }),
})
events = battle:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 })
local ghostDmgEvent
for _, e in ipairs(events) do
  if e.type == "damage" and e.side == "player" then ghostDmgEvent = e end
end
check("Struggle bypasses a real Ghost-type immunity to Normal",
  ghostDmgEvent ~= nil and ghostDmgEvent.amount > 0, ghostDmgEvent)

-- Real multi-hit family (BattleEngine.MULTI_HIT_MOVES / resolveMultiHit):
-- accuracy is checked exactly ONCE for the whole move (already covered by
-- every accuracyCheck test above), then each hit gets its own crit roll
-- and damage roll, no repeat accuracy. Isolated with resolveMove directly
-- so each RNG-draw-count assertion below is exact. Per-hit RNG shape is
-- `crit, damageMultiplier` (values `1, 0` = no crit, 100% damage, same
-- convention as the rest of this file). Every landed or no-effect sequence
-- then draws ONE trailing `% 100` (multi-hit tail follow-up): the
-- seteffectwithchance at BattleScript_MultiHitEnd (data/battle_scripts_1.s
-- :652) evaluates `Random() % 100` first (src/battle_script_commands.c
-- :2789) even though 29/44 carry effect byte 0 and chance 0. The draw
-- counts below were each raised by 1 on purpose for that roll.

-- EFFECT_DOUBLE_HIT (Double Kick): always exactly 2 hits, ZERO hit-count
-- RNG (real fixed `setmultihitcounter 2` arg) -- total draws = 1 accuracy +
-- 2*(crit+damage) + 1 trailing `% 100` = 6.
battle = makeBattle({ 0, 1, 0, 1, 0, 99 }, { { move = Data.MOVE_DOUBLE_KICK, pp = 30 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
local dmgEvents = {}
for _, e in ipairs(statEvents) do
  if e.type == "damage" then dmgEvents[#dmgEvents + 1] = e end
end
check("Double Kick (EFFECT_DOUBLE_HIT) lands exactly 2 hits", #dmgEvents == 2, #dmgEvents)
check("Double Kick's trailing multiHit event reports 2 hits",
  statEvents[#statEvents].type == "multiHit" and statEvents[#statEvents].hits == 2, statEvents[#statEvents])
-- Was 5 before the multi-hit tail follow-up; +1 for MultiHitEnd's
-- seteffectwithchance roll (bs1.s:652, bsc.c:2789).
check("Double Kick consumes exactly 6 RNG draws (1 accuracy + 2*(crit+damage) + 1 trailing % 100, zero hit-count RNG)",
  battle.rng.draws == 6, battle.rng.draws)

-- Bonemerang: the other real EFFECT_DOUBLE_HIT move, confirming no
-- per-move special-casing -- same fixed-2 behavior.
battle = makeBattle({ 0, 1, 0, 1, 0 }, { { move = Data.MOVE_BONEMERANG, pp = 10 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
dmgEvents = {}
for _, e in ipairs(statEvents) do
  if e.type == "damage" then dmgEvents[#dmgEvents + 1] = e end
end
check("Bonemerang (also EFFECT_DOUBLE_HIT) lands exactly 2 hits with no special-casing", #dmgEvents == 2, #dmgEvents)

-- EFFECT_MULTI_HIT, "1 extra roll" branch: first Random()&3 roll is 0 or 1,
-- giving a final count of 2 or 3 with exactly ONE hit-count Random() call.
-- Roll value 1 -> first&3=1 -> count = 1+2 = 3.
battle = makeBattle(
  { 0, 1, 1, 0, 1, 0, 1, 0 },
  { { move = Data.MOVE_DOUBLE_SLAP, pp = 10 } }, { { move = Data.MOVE_TACKLE, pp = 1 } }
)
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
dmgEvents = {}
for _, e in ipairs(statEvents) do
  if e.type == "damage" then dmgEvents[#dmgEvents + 1] = e end
end
check("Double Slap's single-roll branch (first roll 1) lands exactly 3 hits", #dmgEvents == 3, #dmgEvents)
-- Was 8; +1 for MultiHitEnd's seteffectwithchance roll (bs1.s:652).
check("single-roll branch consumes exactly 9 draws (1 acc + 1 hitcount + 3*(crit+damage) + 1 % 100)",
  battle.rng.draws == 9, battle.rng.draws)

-- EFFECT_MULTI_HIT, "2 extra rolls" branch: first roll is 2 or 3, so a
-- second roll picks the final count. First=3 (3&3=3>1), second=3
-- (3&3=3, +2 = 5) -> 5 hits, TWO hit-count Random() calls.
battle = makeBattle(
  { 0, 3, 3, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0 },
  { { move = Data.MOVE_FURY_ATTACK, pp = 20 } }, { { move = Data.MOVE_TACKLE, pp = 1 } }
)
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
dmgEvents = {}
for _, e in ipairs(statEvents) do
  if e.type == "damage" then dmgEvents[#dmgEvents + 1] = e end
end
check("Fury Attack's two-roll branch (first=3, second=3) lands exactly 5 hits", #dmgEvents == 5, #dmgEvents)
-- Was 13; +1 for MultiHitEnd's seteffectwithchance roll (bs1.s:652).
check("two-roll branch consumes exactly 14 draws (1 acc + 2 hitcount + 5*(crit+damage) + 1 % 100)",
  battle.rng.draws == 14, battle.rng.draws)

-- Same two-roll branch, other end: first=2, second=0 -> (0&3)+2 = 2 hits.
battle = makeBattle(
  { 0, 2, 0, 1, 0, 1, 0 },
  { { move = Data.MOVE_FURY_ATTACK, pp = 20 } }, { { move = Data.MOVE_TACKLE, pp = 1 } }
)
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
dmgEvents = {}
for _, e in ipairs(statEvents) do
  if e.type == "damage" then dmgEvents[#dmgEvents + 1] = e end
end
check("Fury Attack's two-roll branch (first=2, second=0) lands exactly 2 hits", #dmgEvents == 2, #dmgEvents)
-- Was 7 (design review F1 named this assertion); +1 for MultiHitEnd's
-- seteffectwithchance roll (bs1.s:652).
check("that two-roll branch consumes exactly 8 draws (1 acc + 2 hitcount + 2*(crit+damage) + 1 % 100)",
  battle.rng.draws == 8, battle.rng.draws)

-- Defender faints mid-sequence: the sequence stops the instant HP hits 0,
-- landing fewer hits than the rolled count. Fury Attack rolled for 3 hits
-- (single-roll branch, first=1), foe HP set to survive exactly one hit.
-- Multi-hit tail follow-up (intentional change): source breaks the loop at
-- `jumpifhasnohp BS_TARGET` -> BattleScript_MultiHitPrintStrings, prints
-- "Hit 1 time(s)!" (data/battle_scripts_1.s:615, :646-649), draws
-- MultiHitEnd's `% 100` (:652) and only then runs `tryfaintmon BS_TARGET`
-- (:653), which is the CALLER's faint check here. So resolveMove itself no
-- longer emits the faint; this test previously asserted the old in-loop
-- faint and "no trailing multiHit" shape.
battle = makeBattle(
  { 0, 1, 1, 0, 99 },
  { { move = Data.MOVE_FURY_ATTACK, pp = 20 } }, { { move = Data.MOVE_TACKLE, pp = 1 } }
)
battle.foe.hp = 1
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
dmgEvents = {}
for _, e in ipairs(statEvents) do
  if e.type == "damage" then dmgEvents[#dmgEvents + 1] = e end
end
check("a defender that faints mid-sequence lands only 1 hit, not the full rolled 3",
  #dmgEvents == 1 and dmgEvents[1].hpRemaining == 0, #dmgEvents)
check("a KO-terminated sequence still ends with multiHit hits=1 (bs1.s:646-649), not a faint",
  statEvents[#statEvents].type == "multiHit" and statEvents[#statEvents].hits == 1, statEvents[#statEvents])
local inMoveFaint = false
for _, e in ipairs(statEvents) do
  if e.type == "faint" then inMoveFaint = true end
end
check("resolveMultiHit emits no in-loop faint (tryfaintmon is after MultiHitEnd, bs1.s:653)", not inMoveFaint)
check("a KO-terminated Fury Attack draws acc + hitcount + (crit, random) + the trailing % 100 = 5",
  battle.rng.draws == 5, battle.rng.draws)
battle:checkFaint(BattleEngine.SIDE_FOE, statEvents)
check("the caller's faint check then emits the faint and ends the battle as playerWon",
  statEvents[#statEvents - 1].type == "faint" and statEvents[#statEvents - 1].side == BattleEngine.SIDE_FOE
    and statEvents[#statEvents].type == "battleEnd" and battle.outcome == "playerWon", statEvents)

-- Type-immune target: the entire sequence stops at zero hits, not "immune
-- hits skipped, others land." Confirmed only reachable on the first hit
-- since type doesn't change mid-sequence.
local multiHitMoves = {}
for k, v in pairs(Data.moves) do multiHitMoves[k] = v end
local groundFoeMulti = BattleEngine.makeBattler({ species = 0, level = 5, stats = charStats, types = { Data.TYPE_GROUND, Data.TYPE_GROUND }, moves = { { move = Data.MOVE_TACKLE, pp = 1 } } })
local electricPlayerMulti = BattleEngine.makeBattler({ species = 0, level = 5, stats = bulbaStats, types = { Data.TYPE_ELECTRIC, Data.TYPE_ELECTRIC }, moves = { { move = 996, pp = 1 } } })
multiHitMoves[996] = { effect = 29, power = 40, type = Data.TYPE_ELECTRIC, accuracy = 100, pp = 1,
                       secondaryEffectChance = 0, target = 0, priority = 0, flags = 0 }
battle = BattleEngine.new({ player = electricPlayerMulti, foe = groundFoeMulti, moves = multiHitMoves, typeChart = Data.typeChart, rng = scriptedRng({ 0, 1, 1, 0 }) })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("a type-immune multi-hit move emits a single noEffect and zero damage events",
  statEvents[2].type == "noEffect" and #statEvents == 2, statEvents)
-- Was 3 (accuracy+hitcount+crit); multi-hit tail follow-up adds the
-- trailing `% 100`: MultiHitNoMoreHits -> PrintStrings -> jumpifmovehadnoeffect
-- MultiHitEnd -> seteffectwithchance (bs1.s:624, :642-647, :652; bsc.c:2789).
check("no-effect stops before adjustnormaldamage's Random() call -- accuracy+hitcount+crit, then the trailing % 100",
  battle.rng.draws == 4, battle.rng.draws)

-- A miss never reaches setmultihitcounter at all (real script:
-- accuracycheck -> attackstring -> ppreduce -> setmultihitcounter -- the
-- accuracycheck branch on a miss jumps straight to
-- BattleScript_PrintMoveMissed, never falling through to ppreduce's
-- fallthrough into setmultihitcounter). Zero hits, PP still deducted,
-- exactly the ordinary single accuracy-roll RNG consumption.
battle = makeBattle({ 90 }, { { move = Data.MOVE_DOUBLE_SLAP, pp = 10 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("an 85-accuracy Double Slap misses on real roll 91", statEvents[2].type == "miss")
check("a missed multi-hit move deducts PP", battle.player.moves[1].pp == 9)
check("a missed multi-hit move never reaches setmultihitcounter -- exactly one RNG draw",
  battle.rng.draws == 1, battle.rng.draws)

-- Voluntary switch action: real SetActionsAndBattlersTurnOrder hoists
-- B_ACTION_SWITCH ahead of any move (like capture/run already are), no
-- RNG of its own; the foe still attacks the same turn, against the
-- newly-switched-in battler. Real Cmd_switchindataupdate confirms an
-- ordinary switch-in starts with neutral stat stages regardless of what
-- the outgoing battler's stages were.
battle = makeBattle({ 0, 0, 0, 0 }, { { move = Data.MOVE_GROWL, pp = 40 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
battle.foe.statStages.attack = 5 -- simulate a prior Growl already having landed
local incoming = BattleEngine.makeBattler({
  species = 99, level = 10, stats = charStats, types = Data.CHARMANDER.types,
  moves = { { move = Data.MOVE_TACKLE, pp = 5 } },
})
local switchEvents = battle:runTurn({ action = "switch", battler = incoming }, { action = "move", moveSlot = 1 })
check("switching swaps the active player battler", battle.player == incoming)
check("a switch emits its own event before the foe's move",
  switchEvents[2].type == "switch" and switchEvents[2].side == "player")
check("the incoming battler starts with neutral stat stages, not carried over from the outgoing one",
  incoming.statStages.attack == 6)
check("the foe still attacks the same turn, landing on the newly-switched-in battler",
  incoming.hp < incoming.maxHP)
-- Weather W0: the incoming battler (Charmander stats, speed 11) ties the
-- foe (11) and a switch is MOVE_NONE vs Tackle, both priority 0, so
-- ENDTURN_ORDER draws one `Random() & 1` (src/battle_util.c:484-501,
-- src/battle_main.c:3486-3496, :3523). The switch itself still draws none.
check("a switch consumes no RNG of its own (the foe's attack draws 3, then one end-of-turn tie draw)",
  battle.rng.draws == 4, battle.rng.draws)

-- The same recoil-outcome guard capture/run already rely on: a foe recoil
-- move that faints the foe itself right after a switch must not have its
-- outcome re-checked/overwritten by a stale player-faint recheck.
local recoilFoe = BattleEngine.makeBattler({
  species = 4, level = 5, stats = { hp = 1, attack = charStats.attack, defense = charStats.defense,
    speed = charStats.speed, spAttack = charStats.spAttack, spDefense = charStats.spDefense },
  types = Data.CHARMANDER.types, moves = { { move = Data.MOVE_TAKE_DOWN, pp = 5 } },
})
battle = BattleEngine.new({
  player = BattleEngine.makeBattler({ species = 1, level = 5, stats = bulbaStats, types = Data.BULBASAUR.types,
    moves = { { move = Data.MOVE_GROWL, pp = 40 } } }),
  foe = recoilFoe, moves = Data.moves, typeChart = Data.typeChart, rng = scriptedRng({ 0, 0, 0 }),
})
local incoming2 = BattleEngine.makeBattler({
  species = 99, level = 50, stats = { hp=200, attack=200, defense=200, speed=200, spAttack=200, spDefense=200 },
  types = Data.BULBASAUR.types, moves = { { move = Data.MOVE_TACKLE, pp = 5 } },
})
battle:runTurn({ action = "switch", battler = incoming2 }, { action = "move", moveSlot = 1 })
check("a foe recoil-faint after a switch still resolves to a real outcome, not a crash",
  battle.outcome == "playerWon")

-- Reflect / Light Screen (BattleEngine.SCREEN_MOVES, resolveScreenMove,
-- decaySideTimers; BattleFormulas.calculateBaseDamage's screen halving).
-- Real EFFECT_REFLECT=65 / EFFECT_LIGHT_SCREEN=35, self-target
-- (MOVE_TARGET_USER), no accuracycheck step -- same 0-RNG shape as
-- Swords Dance above.

-- Setting Reflect: 0 RNG, real 5-turn timer, real screenSet event.
battle = makeBattle({}, { { move = Data.MOVE_REFLECT, pp = 20 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Reflect sets the caster's own side status and a real 5-turn timer",
  statEvents[2].type == "screenSet" and statEvents[2].side == "player"
    and statEvents[2].screen == "reflect" and statEvents[2].turns == 5, statEvents[2])
check("Reflect is stored on the player's own sideStatus, real 5-turn timer",
  battle.sideStatus.player.reflect == true and battle.sideStatus.player.reflectTimer == 5)
check("self-target screen move consumes zero RNG (no real accuracycheck step)", battle.rng.draws == 0)

-- Setting Light Screen: same shape, different table key.
battle = makeBattle({}, { { move = Data.MOVE_LIGHT_SCREEN, pp = 30 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Light Screen sets the caster's own side status and a real 5-turn timer",
  statEvents[2].type == "screenSet" and statEvents[2].side == "player"
    and statEvents[2].screen == "lightScreen" and statEvents[2].turns == 5, statEvents[2])
check("Light Screen is stored on the player's own sideStatus, real 5-turn timer",
  battle.sideStatus.player.lightScreen == true and battle.sideStatus.player.lightScreenTimer == 5)

-- Real Cmd_setreflect: if the caster's own side already has the status,
-- it's a no-op failure -- no RNG, no state change, timer NOT refreshed.
battle = makeBattle({}, { { move = Data.MOVE_REFLECT, pp = 20 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
battle.sideStatus.player.reflectTimer = 3 -- simulate an already-decayed timer
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("casting Reflect while already active fails instead of refreshing it",
  statEvents[2].type == "screenFailed" and statEvents[2].side == "player" and statEvents[2].screen == "reflect",
  statEvents[2])
check("a failed Reflect cast does not reset the real timer",
  battle.sideStatus.player.reflectTimer == 3)
check("a failed Reflect cast still consumes zero RNG", battle.rng.draws == 0)

-- Physical hit against a Reflect-protected side takes real halved damage.
-- Hand-computed against BattleFormulas.calculateBaseDamage directly:
-- undefended Lv5 Bulbasaur Tackle on Lv5 Charmander is the real 4 (already
-- verified above); with the foe's own side Reflect-protected it's the real
-- halved 3 (2, halved from the real pre-clamp 2, stays 2, +2 == 4 without
-- Reflect; with Reflect the pre-clamp 2 halves to 1, +2 == 3).
battle = makeBattle({ 0, 1, 0 }, { { move = Data.MOVE_TACKLE, pp = 1 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
battle.sideStatus.foe.reflect = true
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("a Reflect-protected foe takes real halved Tackle damage (4 -> 3)",
  statEvents[2].type == "damage" and statEvents[2].amount == 3, statEvents[2])

-- Special hit against a Light-Screen-protected side takes real halved
-- damage. Undefended Lv5 Charmander Ember on Lv5 Bulbasaur is the real 14
-- (already verified in the very first test above -- Ember gets both real
-- STAB and Fire-vs-Grass super effectiveness against Bulbasaur, applied
-- AFTER calculateBaseDamage's own halving step). Light Screen halves the
-- pre-STAB/pre-type base from 5 to 3 (calculateBaseDamage's own halving,
-- matching the earlier direct BattleFormulas check); STAB then makes that
-- 3*15/10=4 (truncated), and the real Fire-vs-Grass 2x row then makes that
-- the real final 8.
battle = makeBattle({ 0, 1, 0 }, { { move = Data.MOVE_TACKLE, pp = 1 } }, { { move = Data.MOVE_EMBER, pp = 1 } })
battle.sideStatus.player.lightScreen = true
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_FOE, 1, statEvents)
check("a Light-Screen-protected player takes real halved Ember damage (14 -> 8)",
  statEvents[2].type == "damage" and statEvents[2].amount == 8, statEvents[2])

-- Light Screen does not affect a physical hit, and Reflect does not affect
-- a special hit -- each screen is real type-specific.
battle = makeBattle({ 0, 1, 0 }, { { move = Data.MOVE_TACKLE, pp = 1 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
battle.sideStatus.foe.lightScreen = true
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Light Screen does not halve a physical Tackle hit (stays real 4)",
  statEvents[2].amount == 4, statEvents[2])

battle = makeBattle({ 0, 1, 0 }, { { move = Data.MOVE_TACKLE, pp = 1 } }, { { move = Data.MOVE_EMBER, pp = 1 } })
battle.sideStatus.player.reflect = true
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_FOE, 1, statEvents)
check("Reflect does not halve a special Ember hit (stays real 14)",
  statEvents[2].amount == 14, statEvents[2])

-- A critical hit bypasses screens entirely (real `&& gCritMultiplier == 1`
-- gate). Force a crit (rng % 16 == 0) against a Reflect-protected foe and
-- confirm the resulting damage matches the ordinary (unhalved) crit
-- damage: real base-with-crit is still 4 (this fixture's neutral stat
-- stages mean the crit stat-ignoring branches don't change anything), x2
-- crit multiplier = 8, neutral type/STAB, 100% random multiplier = 8.
battle = makeBattle({ 0, 0, 0 }, { { move = Data.MOVE_TACKLE, pp = 1 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
battle.sideStatus.foe.reflect = true
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("a critical hit ignores Reflect entirely, dealing the real unhalved crit damage",
  statEvents[2].type == "critical" and statEvents[3].type == "damage" and statEvents[3].amount == 8,
  statEvents[3])

-- The minimum-1-after-halving edge case this task's clamp-ordering fix
-- exists for: a hand-built attacker/defender/move where the real pre-clamp
-- physical damage is exactly 1 (attack=2, power=1, level=100, factor
-- (2*100/5+2)=42, damage=2*1*42=84, defense=1, 84/1=84, 84/50=1). Without
-- Reflect that 1 is never clamped (1 ~= 0), returning the real 1+2=3.
-- WITH Reflect, halving 1 truncates to 0 -- the real clamp
-- `if (damage == 0) damage = 1` must still fire AFTER that halving,
-- clamping back up to 1, so the real final result is the SAME 1+2=3 --
-- not the wrong 0+2=2 a clamp-before-halve ordering bug would produce.
local BattleFormulas = require("src.core.BattleFormulas")
local edgeAttacker = { level = 100, attack = 2, defense = 1, spAttack = 2, spDefense = 1, statStages = {} }
local edgeDefender = { level = 100, attack = 1, defense = 1, spAttack = 1, spDefense = 1, statStages = {} }
local edgeMove = { power = 1, type = Data.TYPE_NORMAL }
check("real minimum-1 clamp still fires after Reflect halves a pre-clamp-1 hit to 0",
  BattleFormulas.calculateBaseDamage(edgeAttacker, edgeDefender, edgeMove, false, { reflect = true }) == 3,
  BattleFormulas.calculateBaseDamage(edgeAttacker, edgeDefender, edgeMove, false, { reflect = true }))
check("that same hit without Reflect is the identical real 3 (never needed the clamp)",
  BattleFormulas.calculateBaseDamage(edgeAttacker, edgeDefender, edgeMove, false, nil) == 3)

-- Real special-branch minimum-1 clamp does not exist at all, with or
-- without Light Screen -- confirmed still true after this task's change.
-- TYPE_MYSTERY forces 0 damage before the special branch even runs, so a
-- 0-power-equivalent special hit legitimately returns 0 + 2 = 2 (not
-- clamped to 1) whether or not Light Screen is active.
local mysteryMove = { power = 40, type = BattleFormulas.TYPE_MYSTERY }
check("the real special branch has no minimum-1 clamp, screened or not",
  BattleFormulas.calculateBaseDamage(edgeAttacker, edgeDefender, mysteryMove, false, { lightScreen = true }) == 2)

-- End-of-turn decay (BattleEngine:decaySideTimers, the first "end of turn"
-- phase this engine has): real ENDTURN_REFLECT ticks the timer down once
-- per completed turn, even a turn where the screen itself wasn't the move
-- used. Turn 1 sets Reflect (timer 5); real DoFieldEndTurnEffects
-- decrements it the SAME turn it was set (Cmd_setreflect runs mid-turn,
-- before the real end-of-turn phase), so it's already 4 right after turn
-- 1. Assert it's still active after 4 completed turns (timer counted down
-- to 1) and gone after the 5th (timer hits 0, real "wore off" -- ported as
-- {type="screenExpired"}).
battle = makeBattle(
  { 0, 0, 0, 0, 0, 0, 0, 0, 0 },
  { { move = Data.MOVE_REFLECT, pp = 20 }, { move = Data.MOVE_GROWL, pp = 40 } },
  { { move = Data.MOVE_GROWL, pp = 40 } }
)
battle:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 })
check("Reflect is active with the real timer already decayed to 4 after its own setting turn",
  battle.sideStatus.player.reflect == true and battle.sideStatus.player.reflectTimer == 4,
  battle.sideStatus.player.reflectTimer)
battle:runTurn({ action = "move", moveSlot = 2 }, { action = "move", moveSlot = 1 })
battle:runTurn({ action = "move", moveSlot = 2 }, { action = "move", moveSlot = 1 })
local turn4Events = battle:runTurn({ action = "move", moveSlot = 2 }, { action = "move", moveSlot = 1 })
check("Reflect is still active after 4 completed turns (real timer at 1)",
  battle.sideStatus.player.reflect == true and battle.sideStatus.player.reflectTimer == 1,
  battle.sideStatus.player.reflectTimer)
check("no screenExpired event fires before the real timer actually reaches 0", (function()
  for _, e in ipairs(turn4Events) do
    if e.type == "screenExpired" then return false end
  end
  return true
end)())
local turn5Events = battle:runTurn({ action = "move", moveSlot = 2 }, { action = "move", moveSlot = 1 })
check("Reflect is gone after the real 5th turn (timer hit 0)",
  battle.sideStatus.player.reflect == false and battle.sideStatus.player.reflectTimer == 0,
  battle.sideStatus.player.reflectTimer)
local expiredEvent
for _, e in ipairs(turn5Events) do
  if e.type == "screenExpired" then expiredEvent = e end
end
check("the real 5th-turn expiry emits a screenExpired event for the player's reflect",
  expiredEvent ~= nil and expiredEvent.side == "player" and expiredEvent.screen == "reflect", expiredEvent)

-- Forced switch-after-faint (checkFaint's caller-supplied hasReplacement
-- dispatch, BattleEngine:resolveForcedSwitch). Real BattleScript_
-- HandleFaintedMon's checkteamslost step (Cmd_checkteamslost, src/
-- battle_script_commands.c:3385) only sets gBattleOutcome once a whole
-- team's total HP is 0 -- not just because the one battler that fainted
-- has 0 HP -- so a fainted side with a caller-confirmed living replacement
-- must block on a forced switch instead of ending the battle. See
-- BattleEngine.lua's header forced-switch paragraph for the full real
-- control-flow citation trail (BattleTurnPassed -> HandleFaintedMonActions
-- -> BattleScript_HandleFaintedMon -> Cmd_openpartyscreen).
battle = makeBattle({ 0, 1, 0 }, { { move = Data.MOVE_TACKLE, pp = 35 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
battle.player.speed = 20 -- player strikes first
battle.foe.hp = 1
battle.hasReplacement = function(side) return side == BattleEngine.SIDE_FOE end
events = battle:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 })
check("a faint with an eligible replacement does NOT end the battle",
  battle.outcome == nil, battle.outcome)
check("a faint with an eligible replacement blocks on awaitingForcedSwitch instead",
  battle.awaitingForcedSwitch == BattleEngine.SIDE_FOE, battle.awaitingForcedSwitch)
local forcedFaintEvent, forcedSwitchEvent
for _, e in ipairs(events) do
  if e.type == "faint" then forcedFaintEvent = e end
  if e.type == "forcedSwitchNeeded" then forcedSwitchEvent = e end
end
check("a forcedSwitchNeeded event fires for the fainted side, not a battleEnd",
  forcedFaintEvent ~= nil and forcedFaintEvent.side == "foe"
    and forcedSwitchEvent ~= nil and forcedSwitchEvent.side == "foe", events)
check("runTurn refuses to start another turn while a forced switch is pending",
  not pcall(function() battle:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 }) end))

-- Regression check: an explicit hasReplacement(side) == false still ends
-- the battle exactly as this project's pre-existing (pre-forced-switch)
-- behavior always did -- no forcedSwitchNeeded event, real battleEnd fires.
battle = makeBattle({ 0, 1, 0 }, { { move = Data.MOVE_TACKLE, pp = 35 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
battle.player.speed = 20
battle.foe.hp = 1
battle.hasReplacement = function(side) return false end
events = battle:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 })
check("a faint with no eligible replacement still ends the battle as before",
  battle.outcome == "playerWon" and battle.awaitingForcedSwitch == nil, battle.outcome)
local sawForcedSwitchEvent = false
for _, e in ipairs(events) do
  if e.type == "forcedSwitchNeeded" then sawForcedSwitchEvent = true end
end
check("no forcedSwitchNeeded event fires when there is no eligible replacement",
  not sawForcedSwitchEvent)

-- Omitting hasReplacement entirely (the default, nil) must reproduce this
-- exact pre-existing behavior too -- zero risk of regressing any caller
-- that predates this feature. Already covered by every other faint test
-- above (none of them set hasReplacement), re-asserted here for clarity.
check("the default engine (no hasReplacement) still ends the battle on any faint",
  makeBattle({}, {}, {}).hasReplacement == nil)

-- resolveForcedSwitch supplies the caller-built replacement. Built via
-- BattleEngine.makeBattler exactly like any other switch-in (mirroring
-- BattlePartyBridge.battlerFromParty), so it already starts with real
-- neutral stat stages -- same real Cmd_switchindataupdate fact the
-- voluntary-switch test above already exercises.
battle = makeBattle({ 0, 1, 0 }, { { move = Data.MOVE_TACKLE, pp = 35 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
battle.player.speed = 20
battle.foe.hp = 1
battle.hasReplacement = function(side) return side == BattleEngine.SIDE_FOE end
battle:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 })
local forcedIncoming = BattleEngine.makeBattler({
  species = 4, level = 5, stats = charStats, types = Data.CHARMANDER.types,
  moves = { { move = Data.MOVE_TACKLE, pp = 10 } },
})
local resolveEvents = battle:resolveForcedSwitch(BattleEngine.SIDE_FOE, forcedIncoming)
check("resolveForcedSwitch swaps in the caller-supplied battler", battle.foe == forcedIncoming)
check("the incoming battler starts with real neutral stat stages",
  forcedIncoming.statStages.attack == 6, forcedIncoming.statStages.attack)
check("resolveForcedSwitch clears the pending forced-switch state",
  battle.awaitingForcedSwitch == nil)
check("resolveForcedSwitch emits its own event",
  resolveEvents[1].type == "forcedSwitchResolved" and resolveEvents[1].side == "foe", resolveEvents[1])
check("the battle is still not over -- resolveForcedSwitch supplies a replacement, it isn't a win",
  not battle:isOver())
check("runTurn works normally again once the forced switch is resolved",
  pcall(function() battle:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 }) end))

-- Real BattleTurnPassed (src/battle_main.c:2953) runs DoFieldEndTurnEffects
-- (Reflect/Light Screen decay) BEFORE HandleFaintedMonActions -- the
-- function that actually computes gBattleOutcome via checkteamslost -- so
-- `gBattleOutcome == 0` is still true, and screens still decay, on the very
-- turn a battler faints with a replacement pending. Only a turn that truly
-- ends the whole battle skips decay (already covered by the pre-existing
-- "fainted player does not get a second action" test above, which never
-- sees a screenExpired/timer change after battleEnd).
battle = makeBattle({ 0, 1, 0 }, { { move = Data.MOVE_TACKLE, pp = 35 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
battle.player.speed = 20
battle.foe.hp = 1
battle.sideStatus.player.reflect = true
battle.sideStatus.player.reflectTimer = 5
battle.hasReplacement = function(side) return side == BattleEngine.SIDE_FOE end
battle:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 })
check("Reflect still decays on a turn that ends in a pending forced switch (real gBattleOutcome stays 0)",
  battle.sideStatus.player.reflectTimer == 4, battle.sideStatus.player.reflectTimer)

-- Conservative edge case this project deliberately doesn't chase into real
-- hardware: EFFECT_RECOIL can faint the ATTACKER itself while the DEFENDER
-- is still alive and hasn't acted yet this turn. Rather than assume the
-- still-healthy defender gets to attack an unreplaced, same-turn-fainted
-- opponent, runTurn halts the rest of the turn the instant
-- awaitingForcedSwitch is set, exactly like it already does for isOver().
battle = makeBattle({ 0, 1, 0 }, { { move = Data.MOVE_TAKE_DOWN, pp = 20 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
battle.player.speed = 20 -- player strikes first
battle.player.hp = 1 -- any recoil faints the player
battle.hasReplacement = function(side) return side == BattleEngine.SIDE_PLAYER end
events = battle:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 })
check("a recoil-faint with a pending forced switch reports the player's own faint",
  battle.awaitingForcedSwitch == BattleEngine.SIDE_PLAYER, battle.awaitingForcedSwitch)
local foeActed = false
for _, e in ipairs(events) do
  if e.type == "useMove" and e.side == "foe" then foeActed = true end
end
check("the still-healthy foe does not get to act this same turn while the forced switch is pending",
  not foeActed, events)

-- Optional ROM check: exact real parser output equals the no-ROM fixture.
local romPath = os.getenv("POKEPORT_ROM")
-- EFFECT_ERUPTION (190): current HP scales the stored power before ordinary Hit.
check("Eruption real HP scaling uses floor and positive minimum", BattleEngine.eruptionPowerFromHP(100,100,150)==150
  and BattleEngine.eruptionPowerFromHP(50,100,150)==75 and BattleEngine.eruptionPowerFromHP(1,100,150)==1
  and BattleEngine.eruptionPowerFromHP(1,3,150)==50 and BattleEngine.eruptionPowerFromHP(1,4,150)==37)
local eruptionId, plain150Id = 992, 991
Data.moves[eruptionId] = { effect=190,power=150,type=0,accuracy=100,pp=5,secondaryEffectChance=0,target=0,priority=0,flags=0 }
Data.moves[plain150Id] = { effect=0,power=150,type=0,accuracy=100,pp=5,secondaryEffectChance=0,target=0,priority=0,flags=0 }
battle = makeBattle({0,1,0}, {{move=eruptionId,pp=5}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.player.hp = 1; events={}; battle:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
local eruptionDamage=events[2].amount
battle = makeBattle({0,1,0}, {{move=plain150Id,pp=5}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.player.hp = 1; events={}; battle:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
check("Eruption uses transient low-HP power while other 150-power moves stay unchanged", eruptionDamage < events[2].amount and Data.moves[eruptionId].power==150)
Data.moves[eruptionId]=nil; Data.moves[plain150Id]=nil
-- Both real effect-190 record shapes; target=both is retained in data but this
-- bounded engine resolves only its one opposing battler.
Data.moves[284]={effect=190,power=150,type=10,accuracy=100,pp=5,secondaryEffectChance=0,target=8,priority=0,flags=0}
Data.moves[323]={effect=190,power=150,type=11,accuracy=100,pp=5,secondaryEffectChance=0,target=8,priority=0,flags=0}
battle=makeBattle({0,1,0},{{move=284,pp=5}},{{move=Data.MOVE_TACKLE,pp=1}});battle.player.hp=1;events={};battle:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
check("parsed-shape Eruption #284 uses one-opponent ordinary dynamic Hit",events[1].move==284 and events[2].type=="damage" and battle.player.moves[1].pp==4 and battle.rng.draws==3)
battle=makeBattle({0,1,0},{{move=323,pp=5}},{{move=Data.MOVE_TACKLE,pp=1}});battle.player.hp=1;events={};battle:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
check("parsed-shape Water Spout #323 uses one-opponent ordinary dynamic Hit",events[1].move==323 and events[2].type=="damage" and battle.player.moves[1].pp==4 and battle.rng.draws==3)
local eruptionAccuracy=Data.moves[284].accuracy;Data.moves[284].accuracy=85
battle=makeBattle({99},{{move=284,pp=5}},{{move=Data.MOVE_TACKLE,pp=1}});events={};battle:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
check("Eruption miss preserves ordinary PP and no later RNG",events[#events].type=="miss" and battle.player.moves[1].pp==4 and battle.rng.draws==1)
Data.moves[284].accuracy=eruptionAccuracy
Data.moves[eruptionId]={effect=190,power=150,type=0,accuracy=100,pp=5,secondaryEffectChance=0,target=0,priority=0,flags=0}
battle=makeBattle({0,1,0},{{move=eruptionId,pp=5}},{{move=Data.MOVE_TACKLE,pp=1}});battle.foe.types={Data.TYPE_GHOST,Data.TYPE_GHOST};events={};battle:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
check("Eruption immunity preserves ordinary no-effect RNG path",events[#events].type=="noEffect" and battle.rng.draws==3)
Data.moves[eruptionId]=nil
battle=makeBattle({0,0,0},{{move=284,pp=5}},{{move=Data.MOVE_TACKLE,pp=1}});battle.player.hp=1;events={};battle:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
check("Eruption retains ordinary critical branch",events[2].type=="critical" and events[3].type=="damage" and battle.rng.draws==3)
battle=makeBattle({0,1,0},{{move=284,pp=5}},{{move=Data.MOVE_TACKLE,pp=1}});battle.player.hp=1;battle.player.speed=999;battle.foe.hp=1;events=battle:runTurn({action="move",moveSlot=1},{action="move",moveSlot=1})
local sawEruptionFaint=false
for _,event in ipairs(events) do sawEruptionFaint=sawEruptionFaint or(event.type=="faint" and event.side=="foe") end
check("Eruption retains shared lethal HP and faint handling",battle.foe.hp==0 and sawEruptionFaint)
Data.moves[284]=nil;Data.moves[323]=nil
-- EFFECT_PSYWAVE (88): post-typecalc rejection sampling replaces ordinary
-- crit/base/random damage. The stored move power is only the ROM placeholder.
check("Psywave accepted rolls use source floor percentages", BattleEngine.psywaveDamageFromLevel(5, scriptedRng({0})) == 2
  and BattleEngine.psywaveDamageFromLevel(5, scriptedRng({10})) == 7)
local psywaveId = 149
Data.moves[psywaveId]={effect=88,power=1,type=Data.TYPE_PSYCHIC,accuracy=80,pp=15,secondaryEffectChance=0,target=0,priority=0,flags=50}
battle=makeBattle({0,10},{{move=psywaveId,pp=15}},{{move=Data.MOVE_TACKLE,pp=1}});events={};battle:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
check("Psywave #149 uses post-accuracy high accepted sample without ordinary draws",events[2].type=="damage" and events[2].amount==7 and battle.player.moves[1].pp==14 and battle.rng.draws==2)
battle=makeBattle({0,15,0},{{move=psywaveId,pp=15}},{{move=Data.MOVE_TACKLE,pp=1}});events={};battle:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
check("Psywave retries rejected 11..15 samples",events[2].type=="damage" and events[2].amount==2 and battle.rng.draws==3)
local psywaveAccuracy=Data.moves[psywaveId].accuracy;Data.moves[psywaveId].accuracy=80
battle=makeBattle({99},{{move=psywaveId,pp=15}},{{move=Data.MOVE_TACKLE,pp=1}});events={};battle:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
check("Psywave miss preserves ordinary PP and skips sampling",events[#events].type=="miss" and battle.player.moves[1].pp==14 and battle.rng.draws==1)
Data.moves[psywaveId].accuracy=psywaveAccuracy
battle=makeBattle({0,15,10},{{move=psywaveId,pp=15}},{{move=Data.MOVE_TACKLE,pp=1}});battle.foe.types={Data.TYPE_DARK,Data.TYPE_DARK};events={};battle:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
check("Psywave immunity still consumes full post-typecalc sample",events[#events].type=="noEffect" and battle.player.moves[1].pp==14 and battle.rng.draws==3)
battle=makeBattle({0,10},{{move=psywaveId,pp=15}},{{move=Data.MOVE_TACKLE,pp=1}});battle.player.speed=999;battle.foe.hp=1;events=battle:runTurn({action="move",moveSlot=1},{action="move",moveSlot=1})
local sawPsywaveFaint=false
for _,event in ipairs(events) do sawPsywaveFaint=sawPsywaveFaint or(event.type=="faint" and event.side=="foe") end
check("Psywave retains shared lethal HP and faint handling",battle.foe.hp==0 and sawPsywaveFaint and battle.rng.draws==2)
Data.moves[psywaveId]=nil
-- EFFECT_OHKO (38): special accuracy command consumes no ordinary accuracy
-- roll; represented Cmd_tryKO consumes one roll before the level gate.
check("OHKO helper preserves strict boundary and lower-level draw", BattleEngine.ohkoSucceeds(5,5,30,scriptedRng({28}))
  and not BattleEngine.ohkoSucceeds(5,5,30,scriptedRng({29}))
  and not BattleEngine.ohkoSucceeds(4,5,30,scriptedRng({0}))
  and BattleEngine.ohkoSucceeds(6,5,30,scriptedRng({29})))
local ohkoId=12
Data.moves[ohkoId]={effect=38,power=1,type=Data.TYPE_NORMAL,accuracy=30,pp=5,secondaryEffectChance=0,target=0,priority=0,flags=19}
battle=makeBattle({28},{{move=ohkoId,pp=5}},{{move=Data.MOVE_TACKLE,pp=1}});events={};battle:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
check("OHKO equal-level success uses target current HP without ordinary draws",events[2].type=="damage" and events[2].amount==battle.foe.maxHP and battle.player.moves[1].pp==4 and battle.rng.draws==1)
battle=makeBattle({29},{{move=ohkoId,pp=5}},{{move=Data.MOVE_TACKLE,pp=1}});events={};battle:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
check("OHKO strict boundary misses after PP and one KO draw",events[#events].type=="miss" and battle.player.moves[1].pp==4 and battle.rng.draws==1)
battle=makeBattle({0},{{move=ohkoId,pp=5}},{{move=Data.MOVE_TACKLE,pp=1}});battle.player.level=4;events={};battle:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
check("OHKO lower-level failure still consumes its KO draw",events[#events].type=="miss" and battle.player.moves[1].pp==4 and battle.rng.draws==1)
battle=makeBattle({0},{{move=ohkoId,pp=5}},{{move=Data.MOVE_TACKLE,pp=1}});battle.foe.types={Data.TYPE_GHOST,Data.TYPE_GHOST};events={};battle:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
check("OHKO immunity branches before KO draw",events[#events].type=="noEffect" and battle.player.moves[1].pp==4 and battle.rng.draws==0)
battle=makeBattle({28},{{move=ohkoId,pp=5}},{{move=Data.MOVE_TACKLE,pp=1}});battle.player.speed=999;events=battle:runTurn({action="move",moveSlot=1},{action="move",moveSlot=1})
local sawOhkoFaint=false
for _,event in ipairs(events) do sawOhkoFaint=sawOhkoFaint or(event.type=="faint" and event.side=="foe") end
check("OHKO retains shared faint handling",battle.foe.hp==0 and sawOhkoFaint and battle.rng.draws==1)
Data.moves[ohkoId]=nil
-- EFFECT_FLAIL (99): transient dynamic base power comes from the real scaled
-- remaining-HP table before ordinary Hit, without changing stored move data.
check("Flail real scaled-HP power bands cover both sides of every transition",
  BattleEngine.flailPowerFromHP(1, 100) == 200 and BattleEngine.flailPowerFromHP(2, 48) == 150
    and BattleEngine.flailPowerFromHP(4, 48) == 150 and BattleEngine.flailPowerFromHP(5, 48) == 100
    and BattleEngine.flailPowerFromHP(9, 48) == 100 and BattleEngine.flailPowerFromHP(10, 48) == 80
    and BattleEngine.flailPowerFromHP(16, 48) == 80 and BattleEngine.flailPowerFromHP(17, 48) == 40
    and BattleEngine.flailPowerFromHP(32, 48) == 40 and BattleEngine.flailPowerFromHP(33, 48) == 20
    and BattleEngine.flailPowerFromHP(48, 48) == 20)
check("Flail positive scaled-HP underflow is promoted to one after integer floor",
  BattleEngine.flailPowerFromHP(1, 100) == 200 and BattleEngine.flailPowerFromHP(3, 100) == 200
    and BattleEngine.flailPowerFromHP(2, 20) == 150)
local flailId, plainPowerOneId = 994, 993
Data.moves[flailId] = { effect=99,power=1,type=0,accuracy=100,pp=15,secondaryEffectChance=0,target=0,priority=0,flags=0 }
Data.moves[plainPowerOneId] = { effect=0,power=1,type=0,accuracy=100,pp=15,secondaryEffectChance=0,target=0,priority=0,flags=0 }
battle = makeBattle({0,1,0}, {{move=flailId,pp=15}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.player.hp = 1; events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
local flailDamage = events[2].amount
battle = makeBattle({0,1,0}, {{move=plainPowerOneId,pp=15}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.player.hp = 1; events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Flail dynamic power is used while an ordinary stored-power-1 move remains ordinary",
  flailDamage > events[2].amount and Data.moves[flailId].power == 1)
Data.moves[flailId] = nil; Data.moves[plainPowerOneId] = nil
-- Exercise both actual fixture records through the effect path. Flail is
-- Normal; Reversal is Fighting, so the latter also confirms move type remains
-- the parsed record while only its transient power changes.
Data.moves[175] = { effect=99,power=1,type=0,accuracy=100,pp=15,secondaryEffectChance=0,target=0,priority=0,flags=0 }
Data.moves[179] = { effect=99,power=1,type=1,accuracy=100,pp=15,secondaryEffectChance=0,target=0,priority=0,flags=0 }
battle = makeBattle({0,1,0}, {{move=175,pp=Data.moves[175].pp}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.player.hp = 1; events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("parsed Flail #175 uses dynamic power and ordinary accuracy/crit/random/HP path",
  events[1].move == 175 and events[2].type == "damage" and battle.player.moves[1].pp == 14 and battle.rng.draws == 3)
battle = makeBattle({0,0,0}, {{move=175,pp=15}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.player.hp = 1; events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Flail retains the ordinary critical branch after dynamic power selection",
  events[2].type == "critical" and events[3].type == "damage" and battle.foe.hp < battle.foe.maxHP and battle.rng.draws == 3)
battle = makeBattle({0,1,0}, {{move=175,pp=15}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.player.hp = 1; battle.player.speed = 999; battle.foe.hp = 1; events = battle:runTurn({action="move",moveSlot=1}, {action="move",moveSlot=1})
local sawFlailFaint = false
for _, event in ipairs(events) do sawFlailFaint = sawFlailFaint or (event.type == "faint" and event.side == "foe") end
check("Flail retains shared lethal HP and faint handling", battle.foe.hp == 0 and sawFlailFaint)
battle = makeBattle({0,1,0}, {{move=179,pp=Data.moves[179].pp}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.player.hp = 1; events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("parsed Reversal #179 uses the same dynamic path with its own type record",
  events[1].move == 179 and events[2].type == "damage" and battle.player.moves[1].pp == 14 and battle.rng.draws == 3)
local flailAccuracy = Data.moves[175].accuracy
Data.moves[175].accuracy = 85
battle = makeBattle({99}, {{move=175,pp=15}}, {{move=Data.MOVE_TACKLE,pp=1}})
events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Flail miss stays on ordinary accuracy/PP path and consumes no later RNG", events[#events].type == "miss" and battle.player.moves[1].pp == 14 and battle.rng.draws == 1)
Data.moves[175].accuracy = flailAccuracy
battle = makeBattle({0,1,0}, {{move=175,pp=15}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.foe.types = { Data.TYPE_GHOST, Data.TYPE_GHOST }; events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Flail immunity preserves ordinary type/no-effect and RNG behavior", events[#events].type == "noEffect" and battle.foe.hp == battle.foe.maxHP and battle.rng.draws == 3)
Data.moves[175] = nil; Data.moves[179] = nil
-- EFFECT_SUPER_FANG (40): after shared accuracy/PP/type work it bypasses
-- ordinary crit/base/random damage and removes half the target's current HP.
local superFangId = 996
Data.moves[superFangId] = { effect=40,power=1,type=0,accuracy=90,pp=10,secondaryEffectChance=0,target=0,priority=0,flags=0 }
battle = makeBattle({0}, {{move=superFangId,pp=10}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.foe.hp = 9; events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Super Fang halves odd current HP (9 -> 5) with no crit/random draws", battle.foe.hp == 5 and battle.rng.draws == 1)
battle = makeBattle({0}, {{move=superFangId,pp=10}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.foe.hp = 10; events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Super Fang halves even current HP (10 -> 5)", battle.foe.hp == 5)
battle = makeBattle({0}, {{move=superFangId,pp=10}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.foe.hp = 1; events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Super Fang deals its real minimum one at 1 HP", battle.foe.hp == 0)
battle = makeBattle({99}, {{move=superFangId,pp=10}}, {{move=Data.MOVE_TACKLE,pp=1}})
events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Super Fang miss uses shared accuracy and still deducts PP", events[#events].type == "miss" and battle.player.moves[1].pp == 9 and battle.rng.draws == 1)
battle = makeBattle({0}, {{move=superFangId,pp=10}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.foe.types = { Data.TYPE_GHOST, Data.TYPE_GHOST }; events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Super Fang immunity is no-effect after accuracy with no formula RNG", battle.foe.hp == battle.foe.maxHP and events[#events].type == "noEffect" and battle.rng.draws == 1)
battle = makeBattle({0}, {{move=superFangId,pp=10}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.foe.hp = 10; battle.foe.types = { Data.TYPE_ROCK, Data.TYPE_ROCK }; events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Super Fang clears resisted-effectiveness presentation without changing half-current-HP damage",
  battle.foe.hp == 5 and events[2].superEffective == false and events[2].notVeryEffective == false, events[2])
local fixedId = 995
Data.moves[fixedId] = { effect=41,power=1,type=0,accuracy=100,pp=10,secondaryEffectChance=0,target=0,priority=0,flags=0 }
battle = makeBattle({0}, {{move=fixedId,pp=10}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.foe.hp = 100; events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Super Fang path does not alter existing Dragon Rage fixed 40 damage", battle.foe.hp == 60 and battle.rng.draws == 1)
Data.moves[fixedId] = nil
Data.moves[superFangId] = nil
-- EFFECT_ENDEAVOR (189): PP and the target-vs-attacker HP viability check
-- precede ordinary accuracy; a viable set-damage hit then bypasses crit/base/random.
local endeavorId = 283
Data.moves[endeavorId] = { effect=189,power=1,type=Data.TYPE_NORMAL,accuracy=80,pp=5,secondaryEffectChance=0,target=0,priority=0,flags=51 }
battle = makeBattle({0}, {{move=endeavorId,pp=5}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.player.hp = 10; battle.foe.hp = 10; events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
check("Endeavor equal-HP viability failure consumes PP but no accuracy RNG", events[2].type == "moveFailed" and battle.player.moves[1].pp == 4 and battle.rng.draws == 0)
battle = makeBattle({0}, {{move=endeavorId,pp=5}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.player.hp = 5; battle.foe.hp = 20; events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
local endeavorFainted = false
for _, event in ipairs(events) do endeavorFainted = endeavorFainted or event.type == "faint" end
check("Endeavor viable hit sets target HP to attacker HP without formula RNG or faint", battle.foe.hp == 5 and events[2].amount == 15 and battle.player.moves[1].pp == 4 and battle.rng.draws == 1 and not endeavorFainted)
battle = makeBattle({99}, {{move=endeavorId,pp=5}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.player.hp = 5; battle.foe.hp = 20; events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
check("Endeavor viable miss follows ordinary accuracy after PP", events[#events].type == "miss" and battle.player.moves[1].pp == 4 and battle.rng.draws == 1)
battle = makeBattle({0}, {{move=endeavorId,pp=5}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.player.hp = 5; battle.foe.hp = 20; battle.foe.types = {Data.TYPE_GHOST,Data.TYPE_GHOST}; events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
check("Endeavor immunity follows accuracy and leaves HP unchanged", events[#events].type == "noEffect" and battle.foe.hp == 20 and battle.player.moves[1].pp == 4 and battle.rng.draws == 1)
battle = makeBattle({0}, {{move=endeavorId,pp=5}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.player.hp = 5; battle.foe.hp = 20; battle.foe.types = {Data.TYPE_ROCK,Data.TYPE_ROCK}; events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
check("Endeavor clears nonzero effectiveness presentation", battle.foe.hp == 5 and events[2].superEffective == false and events[2].notVeryEffective == false, events[2])
Data.moves[endeavorId] = nil
-- EFFECT_PAIN_SPLIT (91): effect-specific zero-power admission, no accuracy
-- RNG, pre-mutation average, ordered own-max-clamped non-damage HP changes.
local painSplitId, unsupportedZeroId = 220, 997
Data.moves[painSplitId] = { effect=91,power=0,type=Data.TYPE_NORMAL,accuracy=100,pp=20,secondaryEffectChance=0,target=0,priority=0,flags=18 }
Data.moves[unsupportedZeroId] = { effect=92,power=0,type=Data.TYPE_NORMAL,accuracy=100,pp=20,secondaryEffectChance=0,target=0,priority=0,flags=0 }
battle = makeBattle({}, {{move=painSplitId,pp=20}}, {{move=Data.MOVE_TACKLE,pp=1}})
check("Pain Split #220 alone is admitted among otherwise unsupported zero-power moves",
  battle:supportsMove(Data.moves[painSplitId]) and not battle:supportsMove(Data.moves[unsupportedZeroId]))
battle.player.hp, battle.foe.hp = 5, 15; events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Pain Split lower attacker applies pre-mutation average to attacker then target with zero RNG",
  battle.player.hp == 10 and battle.foe.hp == 10 and battle.player.moves[1].pp == 19
  and battle.rng.draws == 0 and events[2].type == "painSplitHP" and events[2].side == "player"
  and events[2].beforeHP == 5 and events[2].hpRemaining == 10 and events[2].amount == 5
  and events[3].type == "painSplitHP" and events[3].side == "foe" and events[3].beforeHP == 15
  and events[3].hpRemaining == 10 and events[3].amount == -5 and events[4].type == "painSplit")
battle = makeBattle({}, {{move=painSplitId,pp=20}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.player.hp, battle.foe.hp = 15, 5; events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Pain Split higher attacker loses HP without ordinary critical or damage events",
  battle.player.hp == 10 and battle.foe.hp == 10 and battle.rng.draws == 0
  and events[2].amount == -5 and events[3].amount == 5 and events[4].type == "painSplit")
battle = makeBattle({}, {{move=painSplitId,pp=20}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.player.hp, battle.foe.hp = 5, 16; events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Pain Split floors odd pre-mutation sums", battle.player.hp == 10 and battle.foe.hp == 10)
battle = makeBattle({}, {{move=painSplitId,pp=20}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.player.hp, battle.foe.hp = 9, 9; events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Pain Split equal HP is successful sharing, not failure", battle.player.hp == 9 and battle.foe.hp == 9
  and events[2].amount == 0 and events[3].amount == 0 and events[4].type == "painSplit")
battle = makeBattle({}, {{move=painSplitId,pp=20}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.player.maxHP, battle.player.hp, battle.foe.hp = 8, 5, 15; events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Pain Split clamps the attacker to its own lower maximum and reports actual delta", battle.player.hp == 8
  and battle.foe.hp == 10 and events[2].amount == 3 and events[2].hpRemaining == 8)
battle = makeBattle({}, {{move=painSplitId,pp=20}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.player.hp, battle.foe.maxHP, battle.foe.hp = 15, 8, 5; events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
local painSplitFaint = false
for _, event in ipairs(events) do painSplitFaint = painSplitFaint or event.type == "faint" end
check("Pain Split clamps the target to its own lower maximum and never emits faint", battle.player.hp == 10
  and battle.foe.hp == 8 and events[3].amount == 3 and events[3].hpRemaining == 8 and not painSplitFaint)
Data.moves[painSplitId] = nil; Data.moves[unsupportedZeroId] = nil
-- EFFECT_EXPLOSION (7): PP/Damp/self-KO precede accuracy, while target then
-- attacker faint records are finalized together after the hit path.
local explosionId = 999
local ordinaryId = 998
Data.moves[explosionId] = { effect=7,power=250,type=0,accuracy=100,pp=5,secondaryEffectChance=0,target=0,priority=0,flags=0 }
Data.moves[ordinaryId] = { effect=0,power=250,type=0,accuracy=100,pp=5,secondaryEffectChance=0,target=0,priority=0,flags=0 }
local function damageFrom(events)
  for _, event in ipairs(events) do
    if event.type == "damage" then return event.amount end
  end
end
local ordinaryBattle = makeBattle({0,1,0}, {{move=ordinaryId,pp=5}}, {{move=Data.MOVE_TACKLE,pp=1}})
ordinaryBattle.foe.hp = 999
local ordinaryEvents = {}; ordinaryBattle:resolveMove(BattleEngine.SIDE_PLAYER, 1, ordinaryEvents)
local halfDefenseBattle = makeBattle({0,1,0}, {{move=explosionId,pp=5}}, {{move=Data.MOVE_TACKLE,pp=1}})
halfDefenseBattle.foe.hp = 999
local halfDefenseEvents = {}; halfDefenseBattle:resolveMove(BattleEngine.SIDE_PLAYER, 1, halfDefenseEvents)
check("Explosion's effect-specific half-defense damage exceeds the same ordinary physical move",
  damageFrom(halfDefenseEvents) > damageFrom(ordinaryEvents), { explosion=damageFrom(halfDefenseEvents), ordinary=damageFrom(ordinaryEvents) })
battle = makeBattle({0,1,0}, {{move=explosionId,pp=5}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.player.hp, battle.foe.hp = 19, 1
events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Explosion self-KOs after target damage and records target then attacker", battle.player.hp == 0 and battle.foe.hp == 0
  and events[#events-2].type == "faint" and events[#events-2].side == "foe"
  and events[#events-1].type == "faint" and events[#events-1].side == "player", events[#events-1] and events[#events-1].side)
check("Explosion halves defense and finishes a simultaneous exhaustion as draw", battle.outcome == "playerDrew" and battle.rng.draws == 3)
battle = makeBattle({}, {{move=explosionId,pp=5}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.player.ability = BattleEngine.ABILITY_DAMP; events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Damp cancels Explosion after PP but before self-KO or RNG", battle.player.hp == battle.player.maxHP
  and battle.player.moves[1].pp == 4 and battle.rng.draws == 0 and events[#events].type == "damp")
battle = makeBattle({}, {{move=explosionId,pp=5}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.foe.ability = BattleEngine.ABILITY_DAMP; events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("defender Damp also cancels Explosion before self-KO", battle.player.hp == battle.player.maxHP
  and battle.player.moves[1].pp == 4 and battle.rng.draws == 0 and events[#events].type == "damp")
Data.moves[explosionId].accuracy = 85
battle = makeBattle({1,0,0}, {{move=explosionId,pp=5}}, {{move=Data.MOVE_TACKLE,pp=1}})
events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
local sawCritical = false
for _, event in ipairs(events) do sawCritical = sawCritical or event.type == "critical" end
check("Explosion consumes crit then random before accuracy: [1,0,0] is a non-critical hit",
  not sawCritical and battle.foe.hp < battle.foe.maxHP and battle.rng.draws == 3, events)
battle = makeBattle({1,0,99}, {{move=explosionId,pp=5}}, {{move=Data.MOVE_TACKLE,pp=1}})
events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Explosion consumes crit then random before accuracy: [1,0,99] misses after both draws",
  events[#events-2].type == "miss" and battle.foe.hp == battle.foe.maxHP
    and battle.player.hp == 0 and battle.rng.draws == 3, events)
Data.moves[explosionId].accuracy = 0
battle = makeBattle({0,1,0}, {{move=explosionId,pp=5}}, {{move=Data.MOVE_TACKLE,pp=1}})
events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Explosion miss still consumes accuracy crit and damage RNG then faints user", battle.player.hp == 0
  and battle.foe.hp == battle.foe.maxHP and battle.rng.draws == 3 and battle.outcome == "playerLost")
Data.moves[explosionId].accuracy = 100
battle = makeBattle({0,1,0}, {{move=explosionId,pp=5}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.foe.types = { Data.TYPE_GHOST, Data.TYPE_GHOST }
events = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("an immunity still lets Explosion faint its user after normal RNG", battle.player.hp == 0
  and battle.foe.hp == battle.foe.maxHP and battle.rng.draws == 3 and battle.outcome == "playerLost")
Data.moves[explosionId] = nil
Data.moves[ordinaryId] = nil

-- EFFECT_RESTORE_HP (32) admits only the two source-locked zero-power USER
-- moves. It spends PP before full-HP viability and never consumes action RNG.
local recoverId, slackOffId = 105, 303
Data.moves[recoverId] = { effect=32,power=0,type=Data.TYPE_NORMAL,accuracy=0,pp=20,secondaryEffectChance=0,target=16,priority=0,flags=8 }
Data.moves[slackOffId] = { effect=32,power=0,type=Data.TYPE_NORMAL,accuracy=100,pp=10,secondaryEffectChance=0,target=16,priority=0,flags=8 }
battle = makeBattle({123}, {{move=recoverId,pp=20}}, {{move=Data.MOVE_TACKLE,pp=1}})
battle.player.maxHP=101; battle.player.hp=100; events={}; battle:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
check("Recover clamps a near-full odd-max self heal and reports actual gain", battle.player.hp == 101
  and battle.player.moves[1].pp == 19 and battle.rng.draws == 0 and events[2].type == "restoreHP"
  and events[2].side == "player" and events[2].beforeHP == 100 and events[2].hpRemaining == 101 and events[2].amount == 1)
battle = makeBattle({123}, {{move=Data.MOVE_TACKLE,pp=1}}, {{move=slackOffId,pp=10}})
battle.foe.maxHP=100; battle.foe.hp=1; events={}; battle:resolveMove(BattleEngine.SIDE_FOE,1,events)
check("Slack Off heals its own foe-side HP by floor half max without RNG", battle.foe.hp == 51
  and battle.foe.moves[1].pp == 9 and battle.player.hp == battle.player.maxHP and battle.rng.draws == 0
  and events[2].type == "restoreHP" and events[2].side == "foe" and events[2].amount == 50)
battle = makeBattle({123}, {{move=recoverId,pp=20}}, {{move=Data.MOVE_TACKLE,pp=1}})
events={}; battle:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
check("full HP spends one PP and emits restoreHPFull without a success event", battle.player.moves[1].pp == 19
  and battle.rng.draws == 0 and #events == 2 and events[1].type == "useMove" and events[2].type == "restoreHPFull")
battle = makeBattle({123}, {{move=recoverId,pp=0},{move=Data.MOVE_TACKLE,pp=1}}, {{move=Data.MOVE_TACKLE,pp=1}})
events={}; battle:resolveMove(BattleEngine.SIDE_PLAYER,1,events)
check("chosen zero-PP Recover preserves noPP behavior before healing", #events == 1 and events[1].type == "noPP"
  and battle.player.moves[1].pp == 0 and battle.player.hp == battle.player.maxHP and battle.rng.draws == 0)
check("Restore HP admission refuses absent or wrong IDs and malformed shapes", not battle:supportsMove(Data.moves[recoverId])
  and not battle:supportsMove(Data.moves[recoverId], 999) and not battle:supportsMove({effect=32,power=1,target=16}, recoverId)
  and not battle:supportsMove({effect=32,power=0,target=0}, recoverId) and battle:supportsMove(Data.moves[recoverId], recoverId)
  and battle:supportsMove(Data.moves[slackOffId], slackOffId))
Data.moves[recoverId] = nil
Data.moves[slackOffId] = nil

-- Effect 45 source-derived ordinary singles cases. Local fixtures leave the
-- shared test catalog untouched. Numeric oracles below are not obtained from
-- the implementation's damage helper.
do
  local moves = {
    [26]={effect=45,power=70,type=1,accuracy=95,pp=25,priority=0,target=0},
    [136]={effect=45,power=85,type=1,accuracy=90,pp=20,priority=0,target=0},
    [33]={effect=0,power=35,type=0,accuracy=95,pp=35,priority=0,target=0},
    [165]=Data.moves[165],
  }
  local chart = {
    [0]={attackingType=1,defendingType=0,multiplier=20},
    [1]={attackingType=1,defendingType=7,multiplier=0},
    [2]={attackingType=1,defendingType=6,multiplier=5},
  }
  local stats={hp=100,attack=40,defense=40,speed=20,spAttack=40,spDefense=40}
  local function setup(id, side, values)
    local b=BattleEngine.new({
      player=BattleEngine.makeBattler({species=1,level=20,stats=stats,types={10,10},moves={{move=33,pp=35}}}),
      foe=BattleEngine.makeBattler({species=4,level=20,stats=stats,types={10,10},moves={{move=33,pp=35}}}),
      moves=moves,typeChart=chart,rng=scriptedRng(values or {99,0,4321}),
    })
    local a=b:battler(side)
    local d=side=="player" and b.foe or b.player
    a.moves={{move=id,pp=moves[id].pp}}; a.types={1,1}; a.speed=30
    return b,a,d
  end
  local function resolve(b,side)
    local ev={}; b:resolveMove(side,1,ev); return ev
  end
  local function kinds(ev)
    local out={}; for _,e in ipairs(ev) do out[#out+1]=e.type end
    return table.concat(out,",")
  end
  for _,id in ipairs({26,136}) do
    for _,side in ipairs({"player","foe"}) do
      local b,a,d=setup(id,side)
      local ev=resolve(b,side)
      -- Lv20: (10*70/50)+2=16; STAB=24; half=12.
      -- Hi Jump Kick: 17+2=19; STAB floors to28; half=14.
      local amount=id==26 and 12 or 14
      check("effect45 literal crash "..id..side,kinds(ev)=="useMove,miss,crash"
        and ev[3].side==side and ev[3].amount==amount and ev[3].hpRemaining==100-amount
        and a.hp==100-amount and d.hp==100 and a.moves[1].pp==moves[id].pp-1)
      check("effect45 two draws then sentinel "..id..side,b.rng.draws==2 and b.rng:next16()==4321)
      for _,types in ipairs({{7,7},{7,0},{0,7}}) do
        b,a,d=setup(id,side,{99,4321}); d.types=types
        ev=resolve(b,side)
        check("effect45 immune result "..id..side..types[1],kinds(ev)=="useMove,noEffect"
          and a.hp==100 and d.hp==100 and a.moves[1].pp==moves[id].pp-1
          and b.rng.draws==1 and b.rng:next16()==4321)
      end
      b,a,d=setup(id,side,{0,1,0,4321}); ev=resolve(b,side)
      check("effect45 successful hit retained "..id..side,kinds(ev)=="useMove,damage"
        and a.hp==100 and d.hp==100-amount*2 and a.moves[1].pp==moves[id].pp-1
        and b.rng.draws==3 and b.rng:next16()==4321)
      b,a,d=setup(id,side,{0,1,0,4321}); d.types={7,7}; ev=resolve(b,side)
      check("effect45 successful-accuracy immunity retains hit draws "..id..side,
        kinds(ev)=="useMove,noEffect" and a.hp==100 and d.hp==100
        and b.rng.draws==3 and b.rng:next16()==4321)
      for _,replacement in ipairs({false,true}) do
        b,a,d=setup(id,side,{99,0,4321}); a.hp=1
        b.hasReplacement=function(s) return replacement and s==side end
        ev=b:runTurn({action="move",moveSlot=1},{action="move",moveSlot=1})
        check("effect45 fatal order "..id..side..tostring(replacement),
          kinds(ev)=="turnStart,useMove,miss,crash,faint,"..(replacement and "forcedSwitchNeeded" or "battleEnd")
          and a.hp==0 and ev[4].amount==1 and ev[5].side==side and d.hp==100
          and d.moves[1].pp==35 and a.moves[1].pp==moves[id].pp-1 and b.rng.draws==2)
        if replacement then
          check("effect45 pending refusal "..side, b.awaitingForcedSwitch==side and not b:isOver()
            and not pcall(function() b:runTurn({action="move",moveSlot=1},{action="move",moveSlot=1}) end))
          local incoming=BattleEngine.makeBattler({species=1,level=20,stats=stats,types={10,10},moves={{move=33,pp=35}}})
          incoming.speed=35
          local switched=b:resolveForcedSwitch(side,incoming)
          b.rng=scriptedRng({0,1,0,0,1,0})
          local later=b:runTurn({action="move",moveSlot=1},{action="move",moveSlot=1})
          check("effect45 replacement permits later turn "..side,
            switched[1].type=="forcedSwitchResolved" and b.awaitingForcedSwitch==nil
            and incoming.moves[1].pp==34 and #later>1)
        else
          check("effect45 fatal outcome "..side,b.outcome==(side=="player" and "playerLost" or "playerWon"))
        end
      end
    end
  end
  for _,row in ipairs({{7,100,3},{0,100,1},{1,100,1},{100,9,4},{10,10,5},{12,10,5},{8,10,4},{9,1,0}}) do
    check("effect45 arithmetic half/min/cap "..row[1]..":"..row[2],
      BattleEngine.recoilIfMissDamage(row[1],row[2])==row[3])
  end
  local b,a,d=setup(26,"player",{99,15,4321})
  a.statStages.attack=5; d.statStages.defense=7; d.types={0,0}; b.sideStatus.foe.reflect=true
  local ev=resolve(b,"player")
  -- atk26/def60: floor(floor(26*70*10/60)/50)=6; Reflect3,+2=5;
  -- STAB7, super14,85%=11,half5. This catches crit stage/screen bypass.
  check("effect45 source-order stages Reflect STAB type random",ev[3].amount==5 and b.rng.draws==2)
  b,a,d=setup(26,"player"); d.hp=2; a.maxHP=20; a.hp=20
  ev=resolve(b,"player")
  check("effect45 uses neither target current HP nor attacker max cap",ev[3].amount==12 and d.hp==2)
  b,a,d=setup(26,"player"); d.maxHP=9; ev=resolve(b,"player")
  check("effect45 odd target max cap",ev[3].amount==4)
  b,a,d=setup(26,"player",{0,0,0,99,0,4321})
  ev=resolve(b,"player"); local firstCrit=ev[2].type=="critical"
  ev=resolve(b,"player")
  check("effect45 previous critical cannot leak",firstCrit and ev[3].amount==12 and b.rng.draws==5 and b.rng:next16()==4321)
  for _,side in ipairs({"player","foe"}) do
    b,a,d=setup(26,side); b.firstBattle=true
    if side=="player" then b.tutorialPlayerDamageDone=true end
    ev=resolve(b,side)
    check("effect45 crash does not introduce tutorial state "..side,
      kinds(ev)=="useMove,miss,crash" and b.tutorialPlayerDamageDone==(side=="player") and b.rng.draws==2)
  end
  b,a,d=setup(26,"player",{1,0,4321}); b.firstBattle=true; ev=resolve(b,"player")
  check("effect45 firstBattle accuracy bypass and hit tip retained",kinds(ev)=="useMove,damage,tutorialTip"
    and b.tutorialPlayerDamageDone and b.rng.draws==2 and b.rng:next16()==4321)
  for _,row in ipairs({{999,45},{26,0},{26,48},{136,198}}) do
    local id,effect=row[1],row[2]; local original=moves[id]
    moves[id]={effect=effect,power=70,type=1,accuracy=95,pp=25,priority=0,target=0}
    b,a,d=setup(id,"player",{99,4321}); ev=resolve(b,"player")
    check("effect45 literal gate "..id..":"..effect,kinds(ev)=="useMove,miss" and a.hp==100 and b.rng.draws==1 and b.rng:next16()==4321)
    moves[id]=original
  end
  b,a,d=setup(26,"player",{4321}); a.moves={{move=26,pp=0},{move=33,pp=1}}; ev=resolve(b,"player")
  check("effect45 selected zero PP retained",kinds(ev)=="noPP" and a.hp==100 and b.rng.draws==0)
  b,a,d=setup(26,"player",{0,1,0}); a.moves[1].pp=0; ev=resolve(b,"player")
  check("effect45 empty PP still auto-Struggle",ev[1].move==165 and ev[3].type=="recoil" and a.moves[1].pp==0)
end

-- Two-stat self UP family. Stat pairs are literal from the c75f352 battle
-- scripts (setstatchanger order), not read from BattleEngine's table.
do
  local families = {
    {effect=206, move=322, stats={"defense","spDefense"}}, -- Cosmic Power
    {effect=208, move=339, stats={"attack","defense"}},    -- Bulk Up
    {effect=211, move=347, stats={"spAttack","spDefense"}}, -- Calm Mind
    {effect=212, move=349, stats={"attack","speed"}},      -- Dragon Dance
  }
  local stats={hp=100,attack=40,defense=40,speed=20,spAttack=40,spDefense=40}
  for _,f in ipairs(families) do
    local moves = {
      [f.move]={effect=f.effect,power=0,type=0,accuracy=0,pp=20,priority=0,target=0x10},
      [33]={effect=0,power=35,type=0,accuracy=95,pp=35,priority=0,target=0},
    }
    local function setup(side, values)
      local b=BattleEngine.new({
        player=BattleEngine.makeBattler({species=1,level=20,stats=stats,types={0,0},moves={{move=33,pp=35}}}),
        foe=BattleEngine.makeBattler({species=4,level=20,stats=stats,types={0,0},moves={{move=33,pp=35}}}),
        moves=moves,typeChart={},rng=scriptedRng(values or {4321}),
      })
      local a=b:battler(side)
      a.moves={{move=f.move,pp=20}}
      return b,a,(side=="player" and b.foe or b.player)
    end
    local s1,s2=f.stats[1],f.stats[2]
    for _,side in ipairs({"player","foe"}) do
      local tag=f.effect..side
      local b,a,d=setup(side)
      check("dualStat admitted "..tag,b:supportsMove(moves[f.move],f.move))
      local ev={}; b:resolveMove(side,1,ev)
      check("dualStat raises both in order "..tag,#ev==3 and ev[1].type=="useMove"
        and ev[2].type=="statChange" and ev[2].stat==s1 and ev[2].stages==1 and ev[2].stage==7 and ev[2].side==side
        and ev[3].type=="statChange" and ev[3].stat==s2 and ev[3].stages==1 and ev[3].stage==7
        and a.statStages[s1]==7 and a.statStages[s2]==7 and a.moves[1].pp==19)
      check("dualStat no RNG, defender untouched "..tag,b.rng.draws==0 and b.rng:next16()==4321
        and d.statStages[s1]==6 and d.statStages[s2]==6 and d.hp==100)
      b,a=setup(side); a.statStages[s1]=12
      ev={}; b:resolveMove(side,1,ev)
      check("dualStat first maxed skipped silently "..tag,#ev==2 and ev[2].type=="statChange" and ev[2].stat==s2 and ev[2].stage==7
        and a.statStages[s1]==12 and a.statStages[s2]==7)
      b,a=setup(side); a.statStages[s2]=12; a.statStages[s1]=11
      ev={}; b:resolveMove(side,1,ev)
      check("dualStat second maxed skipped silently "..tag,#ev==2 and ev[2].stat==s1 and ev[2].stage==12
        and a.statStages[s2]==12)
      b,a=setup(side); a.statStages[s1]=12; a.statStages[s2]=12
      ev={}; b:resolveMove(side,1,ev)
      check("dualStat both maxed fails, PP spent "..tag,#ev==2 and ev[2].type=="statsWontRise"
        and ev[2].side==side and a.moves[1].pp==19 and b.rng.draws==0)
    end
    local b=setup("player")
    local bad={effect=f.effect,power=0,type=0,accuracy=0,pp=20,priority=0,target=0}
    check("dualStat requires user target "..f.effect,not b:supportsMove(bad,f.move))
    bad={effect=f.effect,power=40,type=0,accuracy=100,pp=20,priority=0,target=0x10}
    check("dualStat requires zero power "..f.effect,not b:supportsMove(bad,f.move))
  end
end

-- Certain self-drop after a hit (Superpower ATK-1 then DEF-1; Overheat and
-- Psycho Boost SP.ATK-2), literal from c75f352 BattleScript_AtkDefDown /
-- BattleScript_SAtkDown2. RNG oracle: accuracy, crit, damage random only;
-- an immune hit additionally spends one seteffectwithchance Random().
do
  local families = {
    {move=276, rec={effect=182,power=120,type=1,accuracy=100,pp=5,secondaryEffectChance=0},
     drops={{"attack",-1},{"defense",-1}}},
    {move=315, rec={effect=204,power=140,type=10,accuracy=90,pp=5,secondaryEffectChance=100},
     drops={{"spAttack",-2}}},
    {move=354, rec={effect=204,power=140,type=14,accuracy=90,pp=5,secondaryEffectChance=100},
     drops={{"spAttack",-2}}},
  }
  local stats={hp=200,attack=40,defense=40,speed=20,spAttack=40,spDefense=40}
  for _,f in ipairs(families) do
    local r=f.rec
    local moves={
      [f.move]={effect=r.effect,power=r.power,type=r.type,accuracy=r.accuracy,pp=r.pp,
        secondaryEffectChance=r.secondaryEffectChance,priority=0,target=0},
      [33]={effect=0,power=35,type=0,accuracy=95,pp=35,priority=0,target=0},
    }
    -- Defender type 7 is immune to the move's type in this local chart.
    local chart={[0]={attackingType=r.type,defendingType=7,multiplier=0}}
    local function setup(side, values)
      local b=BattleEngine.new({
        player=BattleEngine.makeBattler({species=1,level=20,stats=stats,types={0,0},moves={{move=33,pp=35}}}),
        foe=BattleEngine.makeBattler({species=4,level=20,stats=stats,types={0,0},moves={{move=33,pp=35}}}),
        moves=moves,typeChart=chart,rng=scriptedRng(values or {0,1,0,4321}),
      })
      local a=b:battler(side)
      a.moves={{move=f.move,pp=r.pp}}; a.speed=30
      return b,a,(side=="player" and b.foe or b.player)
    end
    local function kinds(ev)
      local out={}; for _,e in ipairs(ev) do out[#out+1]=e.type end
      return table.concat(out,",")
    end
    local nd=#f.drops
    for _,side in ipairs({"player","foe"}) do
      local tag=f.move..side
      local b,a,d=setup(side)
      local ev={}; b:resolveMove(side,1,ev)
      local ok=kinds(ev)==("useMove,damage"..string.rep(",statChange",nd)) and d.hp<200
        and a.moves[1].pp==r.pp-1 and b.rng.draws==3 and b.rng:next16()==4321
      for i,drop in ipairs(f.drops) do
        local e=ev[2+i]
        ok=ok and e.side==side and e.stat==drop[1] and e.stages==drop[2] and e.stage==6+drop[2]
          and a.statStages[drop[1]]==6+drop[2]
      end
      check("selfDrop after hit, no RNG "..tag,ok and d.statStages.attack==6 and d.statStages.defense==6)
      b,a,d=setup(side); for _,drop in ipairs(f.drops) do a.statStages[drop[1]]=0 end
      ev={}; b:resolveMove(side,1,ev)
      check("selfDrop at -6 skipped silently "..tag,kinds(ev)=="useMove,damage" and b.rng.draws==3)
      if nd==1 then
        b,a=setup(side); a.statStages.spAttack=1
        ev={}; b:resolveMove(side,1,ev)
        check("selfDrop -2 clamps at -6 "..tag,ev[3].stages==-2 and ev[3].stage==0 and a.statStages.spAttack==0)
      else
        b,a=setup(side); a.statStages.attack=0
        ev={}; b:resolveMove(side,1,ev)
        check("selfDrop first at -6, second applies "..tag,kinds(ev)=="useMove,damage,statChange"
          and ev[3].stat=="defense" and a.statStages.defense==5)
      end
      b,a,d=setup(side,{0,1,0,0,4321}); d.types={7,7}
      ev={}; b:resolveMove(side,1,ev)
      check("selfDrop immune spends effect roll, no drop "..tag,kinds(ev)=="useMove,noEffect"
        and b.rng.draws==4 and b.rng:next16()==4321 and a.statStages.attack==6 and a.statStages.spAttack==6)
      b,a,d=setup(side,{99,4321}); d.statStages.evasion=12
      ev={}; b:resolveMove(side,1,ev)
      check("selfDrop miss, no drop "..tag,kinds(ev)=="useMove,miss" and b.rng.draws==1
        and a.statStages.attack==6 and a.statStages.spAttack==6 and a.moves[1].pp==r.pp-1)
      b,a,d=setup(side,{0,1,0,0,0,0,0,0}); d.hp=1
      b.hasReplacement=function() return false end
      ev=b:runTurn({action="move",moveSlot=1},{action="move",moveSlot=1})
      check("selfDrop applies before defender faint "..tag,
        kinds(ev)==("turnStart,useMove,damage"..string.rep(",statChange",nd)..",faint,battleEnd"))
    end
  end
end

-- Tickle: target ATK-1 then DEF-1 after accuracycheck; both at -6 fails
-- before accuracycheck (no RNG); a miss lowers nothing; one at -6 skipped.
do
  local moves={
    [321]={effect=205,power=0,type=0,accuracy=100,pp=20,priority=0,target=0},
    [33]={effect=0,power=35,type=0,accuracy=95,pp=35,priority=0,target=0},
  }
  local stats={hp=100,attack=40,defense=40,speed=20,spAttack=40,spDefense=40}
  local function setup(side, values)
    local b=BattleEngine.new({
      player=BattleEngine.makeBattler({species=1,level=20,stats=stats,types={0,0},moves={{move=33,pp=35}}}),
      foe=BattleEngine.makeBattler({species=4,level=20,stats=stats,types={7,7},moves={{move=33,pp=35}}}),
      moves=moves,typeChart={[0]={attackingType=0,defendingType=7,multiplier=0}},
      rng=scriptedRng(values or {0,4321}),
    })
    local a=b:battler(side)
    a.moves={{move=321,pp=20}}
    return b,a,(side=="player" and b.foe or b.player)
  end
  for _,side in ipairs({"player","foe"}) do
    local dside=side=="player" and "foe" or "player"
    local b,a,d=setup(side)
    check("tickle admitted "..side,b:supportsMove(moves[321],321))
    local ev={}; b:resolveMove(side,1,ev)
    check("tickle lowers target ATK then DEF, one RNG "..side,#ev==3
      and ev[2].type=="statChange" and ev[2].side==dside and ev[2].stat=="attack" and ev[2].stages==-1 and ev[2].stage==5
      and ev[3].stat=="defense" and ev[3].stage==5 and a.statStages.attack==6 and a.moves[1].pp==19
      and b.rng.draws==1 and b.rng:next16()==4321)
    b,a,d=setup(side); d.statStages.attack=0
    ev={}; b:resolveMove(side,1,ev)
    check("tickle ATK at -6 skipped, DEF lowered "..side,#ev==2 and ev[2].stat=="defense" and d.statStages.defense==5)
    b,a,d=setup(side); d.statStages.defense=0
    ev={}; b:resolveMove(side,1,ev)
    check("tickle DEF at -6 skipped, ATK lowered "..side,#ev==2 and ev[2].stat=="attack" and d.statStages.attack==5)
    b,a,d=setup(side,{4321}); d.statStages.attack=0; d.statStages.defense=0
    ev={}; b:resolveMove(side,1,ev)
    check("tickle both at -6 fails before accuracy "..side,#ev==2 and ev[2].type=="statsWontFall"
      and ev[2].side==dside and a.moves[1].pp==19 and b.rng.draws==0)
    b,a,d=setup(side,{99,4321}); d.statStages.evasion=12
    ev={}; b:resolveMove(side,1,ev)
    check("tickle miss lowers nothing "..side,#ev==2 and ev[2].type=="miss" and d.statStages.attack==6
      and d.statStages.defense==6 and a.moves[1].pp==19 and b.rng.draws==1)
  end
  local b,a,d=setup("player",{99,4321}); b.firstBattle=true
  local ev={}; b:resolveMove("player",1,ev)
  check("tickle first battle: accuracy bypassed, tip after first fall",#ev==4
    and ev[2].stat=="attack" and ev[3].type=="tutorialTip" and ev[3].kind=="stat"
    and ev[4].stat=="defense" and b.tutorialPlayerStatDone and b.rng.draws==0)
  ev={}; b:resolveMove("player",1,ev)
  check("tickle first battle: later use rolls accuracy, no tip",#ev==3 and ev[2].type=="statChange"
    and ev[3].type=="statChange" and b.rng.draws==1 and b.rng:next16()==4321)
  b=setup("player")
  check("tickle requires zero power",not b:supportsMove({effect=205,power=20,type=0,accuracy=100,pp=20,target=0},321))
  check("tickle requires selected target",not b:supportsMove({effect=205,power=0,type=0,accuracy=100,pp=20,target=0x10},321))
end

-- Batch 3 (c75f352): Splash, Haze, Belly Drum, Psych Up, Soft-Boiled/Milk
-- Drink. None has accuracycheck or Random(); oracles are literal from the
-- scripts and Cmd_normalisebuffs / Cmd_maxattackhalvehp / Cmd_copyfoestats /
-- Cmd_tryhealhalfhealth.
do
  local USER, SELECTED = 0x10, 0
  local moves={
    [150]={effect=85,power=0,type=0,accuracy=0,pp=40,priority=0,target=USER},  -- Splash
    [114]={effect=25,power=0,type=15,accuracy=0,pp=30,priority=0,target=USER}, -- Haze
    [187]={effect=142,power=0,type=0,accuracy=0,pp=10,priority=0,target=USER}, -- Belly Drum
    [244]={effect=143,power=0,type=0,accuracy=0,pp=10,priority=0,target=SELECTED}, -- Psych Up
    [135]={effect=157,power=0,type=0,accuracy=100,pp=10,priority=0,target=USER}, -- Soft-Boiled
    [208]={effect=157,power=0,type=0,accuracy=0,pp=10,priority=0,target=USER},   -- Milk Drink
    [33]={effect=0,power=35,type=0,accuracy=95,pp=35,priority=0,target=0},
  }
  local stats={hp=101,attack=40,defense=40,speed=20,spAttack=40,spDefense=40}
  local STATS={"attack","defense","speed","spAttack","spDefense","accuracy","evasion"}
  local function setup(side, id)
    local b=BattleEngine.new({
      player=BattleEngine.makeBattler({species=1,level=20,stats=stats,types={0,0},moves={{move=33,pp=35}}}),
      foe=BattleEngine.makeBattler({species=4,level=20,stats=stats,types={0,0},moves={{move=33,pp=35}}}),
      moves=moves,typeChart={},rng=scriptedRng({4321}),
    })
    local a=b:battler(side)
    a.moves={{move=id,pp=moves[id].pp}}
    return b,a,(side=="player" and b.foe or b.player)
  end
  local function resolve(b,side) local ev={}; b:resolveMove(side,1,ev); return ev end
  for _,side in ipairs({"player","foe"}) do
    local dside=side=="player" and "foe" or "player"
    for _,id in ipairs({150,114,187,244,135,208}) do
      local b=setup(side,id)
      check("batch3 admitted "..id..side,b:supportsMove(moves[id],id))
    end
    -- Splash
    local b,a,d=setup(side,150)
    local ev=resolve(b,side)
    check("splash nothing happens "..side,#ev==2 and ev[2].type=="splash" and a.moves[1].pp==39
      and a.hp==101 and b.rng.draws==0)
    -- Haze resets both battlers' seven stages
    b,a,d=setup(side,114)
    for i,stat in ipairs(STATS) do a.statStages[stat]=i; d.statStages[stat]=12-i end
    ev=resolve(b,side)
    local neutral=true
    for _,stat in ipairs(STATS) do neutral=neutral and a.statStages[stat]==6 and d.statStages[stat]==6 end
    check("haze resets all stages both sides "..side,#ev==2 and ev[2].type=="haze" and neutral
      and a.moves[1].pp==29 and b.rng.draws==0)
    -- Psych Up copies all seven target stages
    b,a,d=setup(side,244)
    for i,stat in ipairs(STATS) do d.statStages[stat]=i+2; a.statStages[stat]=12 end
    ev=resolve(b,side)
    local copied=true
    for i,stat in ipairs(STATS) do copied=copied and a.statStages[stat]==i+2 and d.statStages[stat]==i+2 end
    check("psych up copies target stages "..side,#ev==2 and ev[2].type=="psychUp" and ev[2].side==side
      and ev[2].target==dside and copied and a.moves[1].pp==9 and b.rng.draws==0)
    -- Belly Drum: maxHP 101 -> half 50; needs hp > 50 and ATK < +6
    b,a=setup(side,187)
    ev=resolve(b,side)
    check("belly drum maxes ATK, costs half max HP "..side,#ev==2 and ev[2].type=="bellyDrum"
      and ev[2].amount==50 and ev[2].hpRemaining==51 and a.hp==51 and a.statStages.attack==12
      and a.moves[1].pp==9 and b.rng.draws==0)
    b,a=setup(side,187); a.hp=51; a.statStages.attack=3
    ev=resolve(b,side)
    check("belly drum at hp just above half succeeds "..side,ev[2].type=="bellyDrum" and a.hp==1 and a.statStages.attack==12)
    b,a=setup(side,187); a.hp=50
    ev=resolve(b,side)
    check("belly drum fails at half HP "..side,#ev==2 and ev[2].type=="moveFailed" and a.hp==50
      and a.statStages.attack==6 and a.moves[1].pp==9)
    b,a=setup(side,187); a.statStages.attack=12
    ev=resolve(b,side)
    check("belly drum fails at ATK +6 "..side,ev[2].type=="moveFailed" and a.hp==101)
    b,a=setup(side,187); a.maxHP=1; a.hp=1
    ev=resolve(b,side)
    check("belly drum maxHP 1 uses 1 and fails "..side,ev[2].type=="moveFailed" and a.hp==1)
    -- Soft-Boiled / Milk Drink heal max(1, maxHP/2), clamped, fail at full
    for _,id in ipairs({135,208}) do
      b,a=setup(side,id); a.hp=20
      ev=resolve(b,side)
      check("softboiled heals half "..id..side,#ev==2 and ev[2].type=="restoreHP" and ev[2].amount==50
        and a.hp==70 and a.moves[1].pp==9 and b.rng.draws==0)
      b,a=setup(side,id); a.hp=90
      ev=resolve(b,side)
      check("softboiled clamps at max "..id..side,ev[2].amount==11 and a.hp==101)
      b,a=setup(side,id)
      ev=resolve(b,side)
      check("softboiled fails at full HP "..id..side,ev[2].type=="restoreHPFull" and a.hp==101 and a.moves[1].pp==9)
    end
  end
  local b=setup("player",150)
  check("softboiled literal ids only",not b:supportsMove(moves[135],136))
  check("psych up requires selected target",not b:supportsMove({effect=143,power=0,target=USER},244))
  check("softboiled requires user target",not b:supportsMove({effect=157,power=0,target=SELECTED},135))
  check("batch3 admission requires zero power",
    not b:supportsMove({effect=85,power=40,target=USER},150) and not b:supportsMove({effect=25,power=40,target=USER},114)
    and not b:supportsMove({effect=142,power=40,target=USER},187) and not b:supportsMove({effect=143,power=40,target=SELECTED},244)
    and not b:supportsMove({effect=157,power=40,target=USER},135))
  check("batch3 user-target moves reject selected target",
    not b:supportsMove({effect=85,power=0,target=SELECTED},150) and not b:supportsMove({effect=25,power=0,target=SELECTED},114)
    and not b:supportsMove({effect=142,power=0,target=SELECTED},187))
end

-- Batch 4 (c75f352): Brick Break removes both target screens before
-- critcalc/damagecalc; Ancient Power/Silver Wind 10% all-five +1 with a
-- "won't go higher" entry for any stat already at +6.
do
  local moves={
    [280]={effect=186,power=75,type=1,accuracy=100,pp=15,secondaryEffectChance=0,priority=0,target=0},
    [246]={effect=140,power=60,type=5,accuracy=100,pp=5,secondaryEffectChance=10,priority=0,target=0},
    [318]={effect=140,power=60,type=6,accuracy=100,pp=5,secondaryEffectChance=10,priority=0,target=0},
    [33]={effect=0,power=35,type=0,accuracy=95,pp=35,priority=0,target=0},
  }
  local chart={[0]={attackingType=1,defendingType=7,multiplier=0},
    [1]={attackingType=5,defendingType=7,multiplier=0},[2]={attackingType=6,defendingType=7,multiplier=0}}
  local stats={hp=200,attack=40,defense=40,speed=20,spAttack=40,spDefense=40}
  local function setup(side,id,values)
    local b=BattleEngine.new({
      player=BattleEngine.makeBattler({species=1,level=20,stats=stats,types={0,0},moves={{move=33,pp=35}}}),
      foe=BattleEngine.makeBattler({species=4,level=20,stats=stats,types={0,0},moves={{move=33,pp=35}}}),
      moves=moves,typeChart=chart,rng=scriptedRng(values),
    })
    local a=b:battler(side)
    a.moves={{move=id,pp=moves[id].pp}}
    return b,a,(side=="player" and b.foe or b.player)
  end
  local function kinds(ev)
    local out={}; for _,e in ipairs(ev) do out[#out+1]=e.type end
    return table.concat(out,",")
  end
  local function resolve(b,side) local ev={}; b:resolveMove(side,1,ev); return ev end
  for _,side in ipairs({"player","foe"}) do
    local dside=side=="player" and "foe" or "player"
    -- Lv20 40/40 power 75, no STAB: floor(40*75*10/40/50)+2 = 17;
    -- with Reflect kept it would be floor(15/2)+2 = 9.
    local b,a,d=setup(side,280,{0,1,0,4321})
    b.sideStatus[dside].reflect=true; b.sideStatus[dside].reflectTimer=3
    b.sideStatus[dside].lightScreen=true; b.sideStatus[dside].lightScreenTimer=2
    local ev=resolve(b,side)
    local st=b.sideStatus[dside]
    -- 3 draws matches the tracked plain-hit seteffectwithchance gap (source spends 4).
    check("brick break shatters screens before damage "..side,kinds(ev)=="useMove,wallShattered,damage"
      and ev[2].side==dside and ev[3].amount==17 and d.hp==183 and not st.reflect and st.reflectTimer==0
      and not st.lightScreen and st.lightScreenTimer==0 and b.rng.draws==3 and b.rng:next16()==4321)
    b,a,d=setup(side,280,{0,1,0,4321}); b.sideStatus[side].reflect=true; b.sideStatus[side].reflectTimer=4
    ev=resolve(b,side)
    check("brick break no target wall, own wall kept "..side,kinds(ev)=="useMove,damage" and ev[2].amount==17
      and b.sideStatus[side].reflect and b.sideStatus[side].reflectTimer==4)
    b,a,d=setup(side,280,{0,1,0,4321}); d.types={7,7}; b.sideStatus[dside].lightScreen=true; b.sideStatus[dside].lightScreenTimer=5
    ev=resolve(b,side)
    -- 3 draws: same tracked plain-hit seteffectwithchance gap (source spends 4).
    check("brick break immune target still shatters "..side,kinds(ev)=="useMove,wallShattered,noEffect"
      and not b.sideStatus[dside].lightScreen and d.hp==200 and b.rng.draws==3)
    b,a,d=setup(side,280,{99,4321}); d.statStages.evasion=12; b.sideStatus[dside].reflect=true; b.sideStatus[dside].reflectTimer=5
    ev=resolve(b,side)
    check("brick break miss keeps wall "..side,kinds(ev)=="useMove,miss" and b.sideStatus[dside].reflect
      and a.moves[1].pp==14)
    for _,id in ipairs({246,318}) do
      local tag=id..side
      local order={"attack","defense","speed","spAttack","spDefense"}
      b,a,d=setup(side,id,{0,1,0,10,4321})
      ev=resolve(b,side)
      local ok=kinds(ev)=="useMove,damage,statChange,statChange,statChange,statChange,statChange"
      for i,stat in ipairs(order) do
        ok=ok and ev[2+i].stat==stat and ev[2+i].side==side and ev[2+i].stages==1 and ev[2+i].stage==7 and a.statStages[stat]==7
      end
      check("all stats up on roll <= 10 "..tag,ok and b.rng.draws==4 and b.rng:next16()==4321)
      b,a=setup(side,id,{0,1,0,11,4321})
      ev=resolve(b,side)
      check("all stats up roll 11 fails "..tag,kinds(ev)=="useMove,damage" and a.statStages.attack==6
        and b.rng.draws==4 and b.rng:next16()==4321)
      b,a=setup(side,id,{0,1,0,0,4321}); a.statStages.speed=12
      ev=resolve(b,side)
      check("all stats up maxed stat prints won't-go-higher "..tag,#ev==7 and ev[5].stat=="speed"
        and ev[5].prevented==true and ev[6].stat=="spAttack" and ev[6].stage==7 and a.statStages.speed==12)
      b,a=setup(side,id,{0,1,0,0,4321}); for _,stat in ipairs(order) do a.statStages[stat]=12 end
      ev=resolve(b,side)
      check("all stats up all maxed silent "..tag,kinds(ev)=="useMove,damage" and b.rng.draws==4)
      -- bs1.s:3410: first four maxed but SP.DEF below +6 still runs all five.
      b,a=setup(side,id,{0,1,0,0,4321})
      for i=1,4 do a.statStages[order[i]]=12 end
      ev=resolve(b,side)
      local gateOk=#ev==7 and b.rng.draws==4
      for i=1,4 do gateOk=gateOk and ev[2+i].stat==order[i] and ev[2+i].prevented==true end
      check("all stats up gate checks SP.DEF clause "..tag,gateOk and ev[7].stat=="spDefense"
        and ev[7].stage==7 and a.statStages.spDefense==7)
      -- Boost precedes tryfaintmon BS_TARGET; SetMoveEffect guards the attacker's HP.
      b,a,d=setup(side,id,{0,1,0,0,0,0,0,0}); d.hp=1
      b.hasReplacement=function() return false end
      a.speed=30
      ev=b:runTurn({action="move",moveSlot=1},{action="move",moveSlot=1})
      check("all stats up applies on KO before faint "..tag,
        kinds(ev)=="turnStart,useMove,damage,statChange,statChange,statChange,statChange,statChange,faint,battleEnd"
        and a.statStages.attack==7)
      b,a,d=setup(side,id,{0,1,0,0,4321}); d.types={7,7}
      ev=resolve(b,side)
      check("all stats up immune spends roll, no raise "..tag,kinds(ev)=="useMove,noEffect"
        and b.rng.draws==4 and b.rng:next16()==4321 and a.statStages.attack==6)
    end
  end
end

-- Triple Kick (c75f352 EffectTripleKick): per-kick accuracy, power 10/20/30,
-- random roll before the no-effect stop. Lv20 40/40 no STAB: 4, 6, 8.
do
  local moves={
    [167]={effect=104,power=10,type=1,accuracy=90,pp=10,secondaryEffectChance=0,priority=0,target=0},
    [33]={effect=0,power=35,type=0,accuracy=95,pp=35,priority=0,target=0},
  }
  local chart={[0]={attackingType=1,defendingType=7,multiplier=0}}
  local stats={hp=200,attack=40,defense=40,speed=20,spAttack=40,spDefense=40}
  local function setup(side,values)
    local b=BattleEngine.new({
      player=BattleEngine.makeBattler({species=1,level=20,stats=stats,types={0,0},moves={{move=33,pp=35}}}),
      foe=BattleEngine.makeBattler({species=4,level=20,stats=stats,types={0,0},moves={{move=33,pp=35}}}),
      moves=moves,typeChart=chart,rng=scriptedRng(values),
    })
    local a=b:battler(side)
    a.moves={{move=167,pp=10}}; a.speed=30
    return b,a,(side=="player" and b.foe or b.player)
  end
  local function kinds(ev)
    local out={}; for _,e in ipairs(ev) do out[#out+1]=e.type end
    return table.concat(out,",")
  end
  local function resolve(b,side) local ev={}; b:resolveMove(side,1,ev); return ev end
  for _,side in ipairs({"player","foe"}) do
    -- Draw counts in this block match the tracked seteffectwithchance gap
    -- (source spends one more on every path, including a first-kick miss).
    local b,a,d=setup(side,{0,1,0,0,1,0,0,1,0,4321})
    local ev=resolve(b,side)
    check("triple kick three kicks 4/6/8 "..side,kinds(ev)=="useMove,damage,damage,damage,multiHit"
      and ev[2].amount==4 and ev[3].amount==6 and ev[4].amount==8 and ev[5].hits==3 and d.hp==182
      and a.moves[1].pp==9 and b.rng.draws==9 and b.rng:next16()==4321)
    b,a,d=setup(side,{0,1,0,99,4321})
    ev=resolve(b,side)
    check("triple kick second kick misses: count only, no miss text "..side,kinds(ev)=="useMove,damage,multiHit"
      and ev[3].hits==1 and b.rng.draws==4 and b.rng:next16()==4321)
    b,a,d=setup(side,{99,4321})
    ev=resolve(b,side)
    check("triple kick first kick misses "..side,kinds(ev)=="useMove,miss" and a.moves[1].pp==9
      and b.rng.draws==1 and d.hp==200)
    b,a,d=setup(side,{0,1,0,4321}); d.types={7,7}
    ev=resolve(b,side)
    check("triple kick immune spends damage roll then stops "..side,kinds(ev)=="useMove,noEffect"
      and b.rng.draws==3 and b.rng:next16()==4321)
    b,a,d=setup(side,{0,1,0,0,0,0,0,1,0,4321})
    ev=resolve(b,side)
    check("triple kick per-kick crit "..side,kinds(ev)=="useMove,damage,critical,damage,damage,multiHit"
      and ev[4].amount==12 and ev[5].amount==8)
    b,a,d=setup(side,{0,1,0,0,1,0,0,0,0,0,0,0}); d.hp=10
    b.hasReplacement=function() return false end
    ev=b:runTurn({action="move",moveSlot=1},{action="move",moveSlot=1})
    check("triple kick KO stops loop, count before faint "..side,
      kinds(ev)=="turnStart,useMove,damage,damage,multiHit,faint,battleEnd" and ev[5].hits==2 and d.hp==0)
    b,a,d=setup(side,{0,1,0,0,1,0,0,0,0,0,0,0}); d.hp=10
    b.hasReplacement=function(s2) return s2~=side end
    ev=b:runTurn({action="move",moveSlot=1},{action="move",moveSlot=1})
    check("triple kick KO with replacement pending "..side,
      kinds(ev)=="turnStart,useMove,damage,damage,multiHit,faint,forcedSwitchNeeded")
    -- Per-kick accuracy uses stages: 90 * 75/100 = 67 at evasion +1
    -- (bsc.c:1046-1061), so draw 66 hits and draw 67 misses on kick 2.
    b,a,d=setup(side,{66,1,0,67,4321}); d.statStages.evasion=7
    ev=resolve(b,side)
    check("triple kick per-kick evasion stage "..side,kinds(ev)=="useMove,damage,multiHit" and ev[3].hits==1
      and b.rng.draws==4 and b.rng:next16()==4321)
    b,a,d=setup(side,{66,1,0,67,4321}); a.statStages.accuracy=5
    ev=resolve(b,side)
    check("triple kick per-kick accuracy stage "..side,kinds(ev)=="useMove,damage,multiHit" and ev[3].hits==1)
    -- Reflect halves before +2 (pokemon.c): 1+2, 2+2, 3+2.
    b,a,d=setup(side,{0,1,0,0,1,0,0,1,0,4321})
    local dside=side=="player" and "foe" or "player"
    b.sideStatus[dside].reflect=true; b.sideStatus[dside].reflectTimer=5
    ev=resolve(b,side)
    check("triple kick Reflect per kick "..side,ev[2].amount==3 and ev[3].amount==4 and ev[4].amount==5)
  end
end

-- Batch 6 (c75f352): Conversion (Cmd_tryconversiontypechange) and Memento
-- (Cmd_trymemento / setatkhptozero / BattleScript_EffectMemento).
do
  local moves={
    [160]={effect=30,power=0,type=0,accuracy=0,pp=30,priority=0,target=0x10},  -- Conversion
    [262]={effect=168,power=0,type=17,accuracy=100,pp=10,priority=0,target=0}, -- Memento
    [52]={effect=4,power=40,type=10,accuracy=100,pp=25,priority=0,target=0},   -- Ember (fire)
    [33]={effect=0,power=35,type=0,accuracy=95,pp=35,priority=0,target=0},     -- Tackle
    [174]={effect=109,power=0,type=9,accuracy=0,pp=10,priority=0,target=0x10}, -- Curse (???)
    [44]={effect=31,power=60,type=17,accuracy=100,pp=25,priority=0,target=0},  -- Bite (dark)
  }
  local stats={hp=100,attack=40,defense=40,speed=20,spAttack=40,spDefense=40}
  local function setup(side,list,values)
    local b=BattleEngine.new({
      player=BattleEngine.makeBattler({species=1,level=20,stats=stats,types={0,0},moves={{move=33,pp=35}}}),
      foe=BattleEngine.makeBattler({species=4,level=20,stats=stats,types={0,0},moves={{move=33,pp=35}}}),
      moves=moves,typeChart={},rng=scriptedRng(values or {4321}),
    })
    local a=b:battler(side)
    a.moves={}
    for i,id in ipairs(list) do a.moves[i]={move=id,pp=moves[id].pp} end
    return b,a,(side=="player" and b.foe or b.player)
  end
  local function kinds(ev)
    local out={}; for _,e in ipairs(ev) do out[#out+1]=e.type end
    return table.concat(out,",")
  end
  local function resolve(b,side) local ev={}; b:resolveMove(side,1,ev); return ev end
  for _,side in ipairs({"player","foe"}) do
    local dside=side=="player" and "foe" or "player"
    -- Draws: 0 -> slot 0 (own NORMAL, redraw), 3 -> slot >= 2 (redraw), 1 -> FIRE.
    local b,a,d=setup(side,{160,52},{0,3,1,4321})
    check("conversion admitted "..side,b:supportsMove(moves[160],160))
    local ev=resolve(b,side)
    check("conversion rejection loop picks fire "..side,kinds(ev)=="useMove,conversion" and ev[2].newType==10
      and ev[2].side==side and a.types[1]==10 and a.types[2]==10 and a.moves[1].pp==29
      and b.rng.draws==3 and b.rng:next16()==4321)
    b,a=setup(side,{160,33})
    ev=resolve(b,side)
    check("conversion fails when all types own "..side,kinds(ev)=="useMove,moveFailed" and a.types[1]==0
      and a.moves[1].pp==29 and b.rng.draws==0)
    b,a=setup(side,{160,174},{1,0,4321}); a.types={7,7}
    ev=resolve(b,side)
    check("conversion curse reads ghost for ghost user "..side,ev[2].newType==0 and b.rng.draws==2)
    b,a=setup(side,{160,174})
    ev=resolve(b,side)
    check("conversion curse reads normal for non-ghost "..side,ev[2].type=="moveFailed" and b.rng.draws==0)
    -- Memento
    b,a,d=setup(side,{262})
    b.hasReplacement=function() return false end
    ev=resolve(b,side)
    check("memento admitted "..side,b:supportsMove(moves[262],262))
    check("memento faints user then drops target ATK/SPATK -2 "..side,
      kinds(ev):find("^useMove,mementoHP,statChange,statChange,faint")~=nil
      and ev[3].side==dside and ev[3].stat=="attack" and ev[3].stages==-2 and ev[3].stage==4
      and ev[4].stat=="spAttack" and ev[4].stage==4 and ev[5].side==side and a.hp==0 and d.hp==100
      and a.moves[1].pp==9 and b.rng.draws==0)
    -- Dual types: bsc.c:7023,7029-7030,7046,7052 check type2 too.
    b,a=setup(side,{160,174},{1,0,4321}); a.types={17,7}
    ev=resolve(b,side)
    check("conversion curse reads ghost via type2 "..side,ev[2].newType==0 and b.rng.draws==2)
    b,a=setup(side,{160,44}); a.types={0,17}
    ev=resolve(b,side)
    check("conversion own-type check uses type2 "..side,ev[2].type=="moveFailed" and b.rng.draws==0)
    b,a=setup(side,{160,44,52},{1,0,2,4321}); a.types={0,17}
    ev=resolve(b,side)
    check("conversion redraw rejects type2 "..side,ev[2].newType==10 and b.rng.draws==3)
    b,a,d=setup(side,{262}); d.statStages.attack=0; d.statStages.spAttack=0
    ev=resolve(b,side)
    check("memento fails at both minimum, user survives "..side,kinds(ev)=="useMove,moveFailed" and a.hp==100
      and a.moves[1].pp==9)
    b,a,d=setup(side,{262}); d.statStages.attack=0; d.statStages.spAttack=1
    b.hasReplacement=function() return false end
    ev=resolve(b,side)
    check("memento ATK at minimum skipped, SPATK clamps "..side,ev[3].stat=="spAttack" and ev[3].stages==-2
      and ev[3].stage==0 and ev[4].type=="faint" and a.hp==0)
  end
  -- Oak first battle: tip after the first defender stat fall, player only.
  local b,a,d=setup("player",{262}); b.firstBattle=true; b.hasReplacement=function() return false end
  local ev=resolve(b,"player")
  check("memento first-battle tip after first fall",ev[3].stat=="attack" and ev[4].type=="tutorialTip"
    and ev[4].kind=="stat" and ev[5].stat=="spAttack" and b.tutorialPlayerStatDone)
  b,a,d=setup("foe",{262}); b.firstBattle=true; b.hasReplacement=function() return false end
  ev=resolve(b,"foe")
  check("memento first-battle foe emits no tip",ev[4].type=="statChange" and not b.tutorialPlayerStatDone)
  b=setup("player",{160})
  check("conversion/memento admission gates",
    not b:supportsMove({effect=30,power=0,target=0},160) and not b:supportsMove({effect=30,power=40,target=0x10},160)
    and not b:supportsMove({effect=168,power=0,target=0x10},262) and not b:supportsMove({effect=168,power=40,target=0},262))
end

if romPath then
  local RomImporter = require("import.RomImporter")
  local RomAddresses = require("import.RomAddresses")
  local BattleMove = require("import.BattleMove")
  local SpeciesInfo = require("import.SpeciesInfo")
  local TypeChart = require("import.TypeChart")
  local addrs = RomAddresses[RomImporter._sha1HexOfFile(romPath)]
  local f = assert(io.open(romPath, "rb"))
  local data = f:read("*a")
  f:close()
  local realMoves = BattleMove.parseTable(data, addrs.gBattleMoves, 355)
  local realSpecies = SpeciesInfo.parseTable(data, addrs.gSpeciesInfo, 5)
  local realTypes = TypeChart.parseTable(data, addrs.gTypeEffectiveness)
  local function sameMove(a, b)
    return a.effect == b.effect and a.power == b.power and a.type == b.type
      and a.accuracy == b.accuracy and a.pp == b.pp
      and a.secondaryEffectChance == b.secondaryEffectChance and a.target == b.target
      and a.priority == b.priority and a.flags == b.flags
  end
  check("ROM Tackle record fully matches fixture", sameMove(realMoves[Data.MOVE_TACKLE], Data.moves[Data.MOVE_TACKLE]))
  check("ROM Ember record fully matches fixture", sameMove(realMoves[Data.MOVE_EMBER], Data.moves[Data.MOVE_EMBER]))
  check("ROM Quick Attack record fully matches fixture", sameMove(realMoves[Data.MOVE_QUICK_ATTACK], Data.moves[Data.MOVE_QUICK_ATTACK]))
  check("ROM Struggle record fully matches fixture", sameMove(realMoves[Data.MOVE_STRUGGLE], Data.moves[Data.MOVE_STRUGGLE]))
  check("ROM Bulbasaur stats/types match fixture", realSpecies[1].baseHP == Data.BULBASAUR.baseHP and realSpecies[1].types[1] == Data.BULBASAUR.types[1] and realSpecies[1].types[2] == Data.BULBASAUR.types[2])
  check("ROM Charmander stats/types match fixture", realSpecies[4].baseHP == Data.CHARMANDER.baseHP and realSpecies[4].types[1] == Data.CHARMANDER.types[1])
  check("ROM type chart has the real 111 rows and Electric->Ground immunity", realTypes[110] ~= nil and realTypes[19].multiplier == 0)
else
  print("SKIP: set POKEPORT_ROM=... to also verify the battle fixture against the retail ROM")
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
