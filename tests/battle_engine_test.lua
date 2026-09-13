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
-- draws. `0,1,0` means hit, no crit, 100% damage. Ember's real direct
-- damage is 14, Tackle's is 4 (Bulbasaur is not Normal-type).
local battle = makeBattle(
  { 0, 1, 0, 11, 0, 1, 0, 0, 1, 0, 11 },
  { { move = Data.MOVE_TACKLE, pp = 35 } },
  { { move = Data.MOVE_EMBER, pp = 25 } }
)
local events = battle:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 })
check("faster foe uses Ember first", events[2].type == "useMove" and events[2].side == "foe")
check("Ember event reports real 14 damage", events[3].type == "damage" and events[3].amount == 14 and events[3].hpRemaining == 5, events[3] and events[3].amount)
check("player still gets its turn while alive", events[4].type == "useMove" and events[4].side == "player")
check("Tackle event reports real 4 damage", events[5].type == "damage" and events[5].amount == 4 and events[5].hpRemaining == 14, events[5] and events[5].amount)
check("Ember's status chance adds its retail fourth RNG draw", battle.rng.draws == 7, battle.rng.draws)
check("PP is deducted from both successful moves", battle.player.moves[1].pp == 34 and battle.foe.moves[1].pp == 24)

events = battle:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 })
check("second Ember faints the player", events[3].type == "damage" and events[3].hpRemaining == 0 and events[4].type == "faint" and events[5].type == "battleEnd")
check("faint ends the 1v1 battle as playerLost", battle.outcome == "playerLost")
check("fainted player does not get a second action", #events == 5, #events)

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

-- A run action is hoisted ahead of any foe move. At equal-or-better speed
-- it succeeds with no RNG, so the foe never spends PP or attacks.
battle = makeBattle({}, { { move = Data.MOVE_TACKLE, pp = 1 } }, { { move = Data.MOVE_EMBER, pp = 1 } })
battle.player.speed = 20
events = battle:runTurn({ action = "run" }, { action = "move", moveSlot = 1 })
check("fast player run ends battle before foe action", events[2].type == "run" and events[2].success and #events == 3 and battle.outcome == "ran")
check("successful fast run consumes no RNG and no foe PP", battle.rng.draws == 0 and battle.foe.moves[1].pp == 1)

-- BattleScript_EffectTeleport is a no-accuracy status move: it spends PP
-- and ends a wild battle with the distinct B_OUTCOME_PLAYER_TELEPORTED
-- equivalent. Trainer callers provide canEscape=false, which instead
-- reaches BattleScript_ButItFailed after PP reduction.
local teleportMoves = {}
for k, v in pairs(Data.moves) do teleportMoves[k] = v end
teleportMoves[1000] = { power=0, type=Data.TYPE_PSYCHIC, accuracy=0, priority=0,
  effect=BattleEngine.EFFECT_TELEPORT }
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({ species=1, level=5, stats=bulbaStats,
    types=Data.BULBASAUR.types, moves={{move=1000,pp=2}} }),
  foe=BattleEngine.makeBattler({ species=4, level=5, stats=charStats,
    types=Data.CHARMANDER.types, moves={{move=Data.MOVE_TACKLE,pp=1}} }),
  moves=teleportMoves, typeChart=Data.typeChart, rng=scriptedRng({}),
})
battle.player.speed = 20
events = battle:runTurn({action="move",moveSlot=1}, {action="move",moveSlot=1})
check("Teleport spends PP and ends a wild battle before the foe acts",
  battle.player.moves[1].pp == 1 and battle.outcome == "teleported"
    and #events == 4 and events[3].type == "teleport" and events[4].type == "battleEnd", events)
check("Teleport uses no accuracy or escape RNG", battle.rng.draws == 0)
check("supportsMove accepts EFFECT_TELEPORT=153", battle:supportsMove(teleportMoves[1000]))

battle = BattleEngine.new({
  player=BattleEngine.makeBattler({ species=1, level=5, stats=bulbaStats,
    types=Data.BULBASAUR.types, moves={{move=1000,pp=2}} }),
  foe=BattleEngine.makeBattler({ species=4, level=5, stats=charStats,
    types=Data.CHARMANDER.types, moves={{move=Data.MOVE_TACKLE,pp=1}} }),
  moves=teleportMoves, typeChart=Data.typeChart, rng=scriptedRng({}), canEscape=false,
})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Teleport fails in trainer/escape-blocked battles after PP without RNG",
  battle.player.moves[1].pp == 1 and battle.outcome == nil and battle.rng.draws == 0
    and #events == 2 and events[2].type == "teleportFailed", events)

-- Mirror Move's source script picks the last move received, replaces the
-- active move, then restarts the copied move's script. The selected slot
-- remains Mirror Move, so only its PP is reduced.
local mirrorMoves = {}
for k, v in pairs(Data.moves) do mirrorMoves[k] = v end
mirrorMoves[BattleEngine.MOVE_MIRROR_MOVE] = { power=0, type=Data.TYPE_FLYING,
  accuracy=0, priority=0, effect=BattleEngine.EFFECT_MIRROR_MOVE }
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({ species=1, level=5, stats=bulbaStats,
    types=Data.BULBASAUR.types, moves={{move=BattleEngine.MOVE_MIRROR_MOVE,pp=2}} }),
  foe=BattleEngine.makeBattler({ species=4, level=5, stats=charStats,
    types=Data.CHARMANDER.types, moves={{move=Data.MOVE_TACKLE,pp=1}} }),
  moves=mirrorMoves, typeChart=Data.typeChart, rng=scriptedRng({0, 1, 0}),
})
battle.foe.lastMove = Data.MOVE_TACKLE
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Mirror Move restarts the target's known last move and spends its own PP",
  battle.player.moves[1].pp == 1 and battle.foe.hp < charStats.hp and battle.rng.draws == 3
    and events[1].move == BattleEngine.MOVE_MIRROR_MOVE and events[2].type == "mirrorMove"
    and events[3].type == "useMove" and events[3].move == Data.MOVE_TACKLE, events)
check("supportsMove accepts EFFECT_MIRROR_MOVE=9", battle:supportsMove(mirrorMoves[BattleEngine.MOVE_MIRROR_MOVE]))

battle.foe.lastMove = nil
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Mirror Move fails after spending PP when no copied move exists",
  battle.player.moves[1].pp == 0 and battle.rng.draws == 3
    and #events == 2 and events[2].type == "mirrorMoveFailed", events)

-- ModHooks exposes the canonical resolver as a narrow, opt-in extension
-- seam. The hook receives the engine and original resolver arguments, then
-- delegates exactly once; no hook means the engine's old direct path remains.
local ModHooks = require("src.core.ModHooks")
local battleHooks = ModHooks.new()
battleHooks:wrap("battle.resolveMove", {id="trace-mod"}, function(nextFn, engine, side, slot, out)
  out[#out + 1] = {type="modTrace", side=side}
  return nextFn(engine, side, slot, out)
end)
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({ species=1, level=5, stats=bulbaStats,
    types=Data.BULBASAUR.types, moves={{move=Data.MOVE_TACKLE,pp=1}} }),
  foe=BattleEngine.makeBattler({ species=4, level=5, stats=charStats,
    types=Data.CHARMANDER.types, moves={{move=Data.MOVE_TACKLE,pp=1}} }),
  moves=Data.moves, typeChart=Data.typeChart, rng=scriptedRng({0,1,0}), hooks=battleHooks,
})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("ModHooks can extend the live battle resolver without replacing it",
  events[1].type == "modTrace" and events[2].type == "useMove" and events[3].type == "damage", events)

-- A Poke Ball is a B_ACTION_USE_ITEM, which SetActionsAndBattlersTurnOrder
-- places before move actions. Seeded/scripted capture rules consume their
-- shake draws from the same global RNG stream as the ensuing foe attack.
-- At full HP and catch rate 45, catch value=15 and threshold=32767: draw 0
-- passes (one shake), draw 65535 fails, then the foe's hit consumes its real
-- accuracy/crit/damage draws 0,1,0.
battle = makeBattle(
  { 0, 65535, 0, 1, 0, 11 },
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

-- Haze (EFFECT_HAZE=25) runs Cmd_normalisebuffs: every stage for BOTH
-- battlers returns to DEFAULT_STAT_STAGE. Its real script has no accuracy
-- check, and it still succeeds/messages when both sides were already neutral.
do
  local moves = {}
  for k, v in pairs(Data.moves) do moves[k] = v end
  moves[998] = { effect=BattleEngine.EFFECT_HAZE, power=0, type=Data.TYPE_ICE,
    accuracy=0, pp=30, target=0, priority=0 }
  battle = makeBattle({}, { { move=998, pp=30 } }, { { move=Data.MOVE_TACKLE, pp=1 } })
  battle.moves = moves
  battle.player.statStages.attack, battle.player.statStages.accuracy = 12, 3
  battle.foe.statStages.defense, battle.foe.statStages.evasion = 1, 10
  local hazeEvents = {}
  battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, hazeEvents)
  check("Haze resets every player stage", battle.player.statStages.attack == 6 and battle.player.statStages.accuracy == 6)
  check("Haze resets every foe stage", battle.foe.statStages.defense == 6 and battle.foe.statStages.evasion == 6)
  check("Haze consumes PP but no accuracy RNG", battle.player.moves[1].pp == 29 and battle.rng.draws == 0, battle.rng.draws)
  check("Haze emits its distinct normalized-stages event", hazeEvents[2] and hazeEvents[2].type == "haze")
end

do
  local moves = {}
  for k, v in pairs(Data.moves) do moves[k] = v end
  moves[997] = { effect=46, power=0, type=Data.TYPE_ICE, accuracy=0, pp=30, target=0x10, priority=0 }
  battle = makeBattle({}, { { move=997, pp=30 } }, { { move=Data.MOVE_GROWL, pp=40 } })
  battle.moves = moves
  local mistEvents = {}
  battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, mistEvents)
  check("Mist starts a five-turn side timer without RNG", battle.sideStatus.player.mist and battle.sideStatus.player.mistTimer == 5 and battle.rng.draws == 0)
  local lowerEvents = {}
  battle:resolveMove(BattleEngine.SIDE_FOE, 1, lowerEvents)
  check("Mist prevents an opponent's stat reduction", battle.player.statStages.attack == 6 and lowerEvents[2].mist == true)
  local repeatEvents = {}
  battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, repeatEvents)
  check("re-casting Mist fails without refreshing its timer",
    repeatEvents[2].type == "sideStatusFailed" and battle.sideStatus.player.mistTimer == 5)
  for _ = 1, 5 do battle:decaySideTimers({}) end
  check("Mist expires after five continuing turns", not battle.sideStatus.player.mist and battle.sideStatus.player.mistTimer == 0)
end

-- EFFECT_FOCUS_ENERGY=47 sets STATUS2_FOCUS_ENERGY once, with no
-- accuracy check, then Cmd_critcalc turns it into critical-hit stage 2
-- (1/4 rather than the ordinary 1/16).
do
  local moves = {}
  for k, v in pairs(Data.moves) do moves[k] = v end
  moves[995] = { effect=47, power=0, type=Data.TYPE_NORMAL, accuracy=0, pp=30, target=0x10, priority=0 }
  battle = makeBattle({}, { { move=995, pp=30 } }, { { move=Data.MOVE_TACKLE, pp=1 } })
  battle.moves = moves
  local focusEvents = {}
  battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, focusEvents)
  check("Focus Energy sets its battler volatile state without RNG",
    battle.player.focusEnergy and battle.player.moves[1].pp == 29 and battle.rng.draws == 0)
  check("Focus Energy emits its distinct set event", focusEvents[2] and focusEvents[2].type == "focusEnergySet")
  local repeatEvents = {}
  battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, repeatEvents)
  check("re-casting Focus Energy fails without clearing or refreshing it",
    battle.player.focusEnergy and battle.player.moves[1].pp == 28
      and repeatEvents[2] and repeatEvents[2].type == "focusEnergyFailed")

  battle = makeBattle({ 0, 4, 0 }, { { move=Data.MOVE_TACKLE, pp=35 } }, { { move=Data.MOVE_TACKLE, pp=1 } })
  battle.player.focusEnergy = true
  local critEvents = {}
  battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, critEvents)
  check("Focus Energy raises the critical roll to real stage 2", critEvents[2] and critEvents[2].type == "critical")

  battle = makeBattle({ 0, 4, 0 }, { { move=Data.MOVE_TACKLE, pp=35 } }, { { move=Data.MOVE_TACKLE, pp=1 } })
  local normalCritEvents = {}
  battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, normalCritEvents)
  check("the same roll is not a base-stage critical hit", not (normalCritEvents[2] and normalCritEvents[2].type == "critical"))

  local highCritMoves = {}
  for k, v in pairs(Data.moves) do highCritMoves[k] = v end
  highCritMoves[992] = { effect=43, power=40, type=Data.TYPE_NORMAL, accuracy=100, pp=20, target=0, priority=0 }
  battle = makeBattle({ 0, 8, 0 }, { { move=992, pp=20 } }, { { move=Data.MOVE_TACKLE, pp=1 } })
  battle.moves = highCritMoves
  local highCritEvents = {}
  battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, highCritEvents)
  check("a high-critical effect adds the real one critical stage", highCritEvents[2] and highCritEvents[2].type == "critical")
  battle = makeBattle({ 0, 3, 0 }, { { move=992, pp=20 } }, { { move=Data.MOVE_TACKLE, pp=1 } })
  battle.moves = highCritMoves
  battle.player.focusEnergy = true
  local stackedCritEvents = {}
  battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, stackedCritEvents)
  check("Focus Energy and a high-critical move stack their real stages", stackedCritEvents[2] and stackedCritEvents[2].type == "critical")
end

-- Rain Dance/Sunny Day have no accuracy check. Cmd_setrain/Cmd_setsunny
-- replace unlike weather, fail only when their own weather is active, and
-- use one shared five-turn weatherDuration.
do
  local moves = {}
  for k, v in pairs(Data.moves) do moves[k] = v end
  moves[994] = { effect=136, power=0, type=Data.TYPE_WATER, accuracy=0, pp=5, target=0x10, priority=0 }
  moves[993] = { effect=137, power=0, type=Data.TYPE_FIRE, accuracy=0, pp=5, target=0x10, priority=0 }
  battle = makeBattle({}, { { move=994, pp=5 }, { move=993, pp=5 } }, { { move=Data.MOVE_TACKLE, pp=1 } })
  battle.moves = moves
  local rainEvents = {}
  battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, rainEvents)
  check("Rain Dance starts five-turn rain without accuracy RNG", battle.weather.kind == "rain" and battle.weather.timer == 5 and battle.rng.draws == 0)
  check("Rain Dance emits a weather-set event", rainEvents[2] and rainEvents[2].type == "weatherSet" and rainEvents[2].weather == "rain")
  local repeatEvents = {}
  battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, repeatEvents)
  check("Rain Dance fails without refreshing existing rain", battle.weather.timer == 5 and repeatEvents[2] and repeatEvents[2].type == "weatherFailed")
  local sunEvents = {}
  battle:resolveMove(BattleEngine.SIDE_PLAYER, 2, sunEvents)
  check("Sunny Day replaces rain with a fresh five-turn sun", battle.weather.kind == "sun" and battle.weather.timer == 5 and sunEvents[2] and sunEvents[2].type == "weatherSet")
  for _ = 1, 5 do battle:decaySideTimers({}) end
  check("temporary weather expires after five continuing turns", battle.weather.kind == nil and battle.weather.timer == 0)
end

do
  battle = makeBattle({}, { { move=Data.MOVE_TACKLE, pp=1 } }, { { move=Data.MOVE_TACKLE, pp=1 } })
  battle.weather.kind, battle.weather.timer = "sandstorm", 5
  battle.foe.types = { Data.TYPE_GROUND, Data.TYPE_GROUND }
  local sandEvents = {}
  battle:decaySideTimers(sandEvents)
  check("Sandstorm deals real maxHP/16 minimum-one damage", battle.player.hp == battle.player.maxHP - 1 and battle.weather.timer == 4)
  check("Sandstorm leaves Ground-type battlers immune", battle.foe.hp == battle.foe.maxHP)
  check("Sandstorm emits a weather-damage event only for affected battlers", sandEvents[1] and sandEvents[1].type == "weatherDamage" and sandEvents[1].side == "player")

  battle.weather.kind, battle.weather.timer = "hail", 5
  battle.player.types = { Data.TYPE_ICE, Data.TYPE_ICE }
  local hailEvents = {}
  battle:decaySideTimers(hailEvents)
  check("Hail leaves Ice-type battlers immune and damages other battlers", battle.player.hp == battle.player.maxHP - 1 and battle.foe.hp == battle.foe.maxHP - 1)
  check("Hail emits its distinct weather-damage event", hailEvents[1] and hailEvents[1].type == "weatherDamage" and hailEvents[1].weather == "hail")
end

do
  local moves = {}
  for k, v in pairs(Data.moves) do moves[k] = v end
  moves[991] = { effect=152, power=40, type=Data.TYPE_ELECTRIC, accuracy=70, pp=10, target=0, priority=0 }
  battle = makeBattle({ 99, 1, 0 }, { { move=991, pp=10 } }, { { move=Data.MOVE_TACKLE, pp=1 } })
  battle.moves, battle.weather.kind = moves, "rain"
  local rainThunderEvents = {}
  battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, rainThunderEvents)
  check("rain makes Thunder hit without an accuracy RNG draw", rainThunderEvents[2] and rainThunderEvents[2].type ~= "miss" and battle.rng.draws == 2)
  battle = makeBattle({ 50 }, { { move=991, pp=10 } }, { { move=Data.MOVE_TACKLE, pp=1 } })
  battle.moves, battle.weather.kind = moves, "sun"
  local sunThunderEvents = {}
  battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, sunThunderEvents)
  check("sun changes Thunder to real 50% accuracy", sunThunderEvents[2] and sunThunderEvents[2].type == "miss" and battle.rng.draws == 1)
end

do
  local moves = {}
  for k, v in pairs(Data.moves) do moves[k] = v end
  moves[990] = { effect=111, power=0, type=Data.TYPE_NORMAL, accuracy=0, pp=10, target=0x10, priority=4, flags=0 }
  battle = makeBattle({ 0 }, { { move=990, pp=10 } }, { { move=Data.MOVE_TACKLE, pp=1 } })
  battle.moves, battle.player.speed = moves, 100
  local protectEvents = battle:runTurn({ action="move", moveSlot=1 }, { action="move", moveSlot=1 })
  check("Protect sets before the opposing action and blocks protect-affected damage", battle.player.hp == battle.player.maxHP and battle.foe.moves[1].pp == 1)
  local sawProtectSet, sawBlocked = false, false
  for _, event in ipairs(protectEvents) do
    if event.type == "protectSet" then sawProtectSet = true end
    if event.type == "protected" then sawBlocked = true end
  end
  check("Protect emits both setup and blocked-hit events", sawProtectSet and sawBlocked)
  check("Protect consumes exactly its one success-rate RNG draw", battle.rng.draws == 1, battle.rng.draws)
  battle.player.protected = true
  battle.player.moves[2] = { move=Data.MOVE_TACKLE, pp=1 }
  battle:runTurn({ action="move", moveSlot=2 }, { action="move", moveSlot=1 })
  check("Protect expires at the next turn boundary", not battle.player.protected)
end

do
  local moves = {}
  for k, v in pairs(Data.moves) do moves[k] = v end
  moves[989] = { effect=116, power=0, type=Data.TYPE_NORMAL, accuracy=0, pp=10, target=0x10, priority=4, flags=0 }
  battle = makeBattle({ 0, 0, 1, 0 }, { { move=989, pp=10 } }, { { move=Data.MOVE_TACKLE, pp=1 } })
  battle.moves, battle.player.speed, battle.player.hp = moves, 100, 1
  local endureEvents = battle:runTurn({ action="move", moveSlot=1 }, { action="move", moveSlot=1 })
  check("Endure prevents a direct lethal hit and leaves exactly one HP", battle.player.hp == 1 and battle.foe.moves[1].pp == 0)
  local sawEndureSet, sawEndured = false, false
  for _, event in ipairs(endureEvents) do
    if event.type == "endureSet" then sawEndureSet = true end
    if event.type == "endured" then sawEndured = true end
  end
  check("Endure emits its setup and survived-hit events", sawEndureSet and sawEndured)
  battle.player.endured = true
  battle.player.moves[2] = { move=Data.MOVE_TACKLE, pp=1 }
  battle:runTurn({ action="move", moveSlot=2 }, { action="move", moveSlot=1 })
  check("Endure expires at the next turn boundary", not battle.player.endured)
end

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

for _, stageCase in ipairs({
  { effect=63, stat="accuracy", delta=-2 },
}) do
  local stageMoves = {}
  for k, v in pairs(Data.moves) do stageMoves[k] = v end
  stageMoves[970] = {effect=stageCase.effect, power=0, type=Data.TYPE_NORMAL,
    accuracy=100, priority=0, target=stageCase.self and 0x10 or 0}
  battle = makeBattle({ 0 }, { { move=970, pp=1 } }, { { move=Data.MOVE_TACKLE, pp=1 } })
  battle.moves = stageMoves
  statEvents = {}
  battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
  local target = stageCase.self and battle.player or battle.foe
  check(("effect %d applies its canonical %s stage change"):format(stageCase.effect, stageCase.stat),
    target.statStages[stageCase.stat] == 6 + stageCase.delta)
end

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
-- Dream Eater tests its target's sleep status before attackstring, PP, and
-- accuracy. A waking/asleep status is now canonical engine state, so this
-- effect can use the existing one-half drain path without a new subsystem.
battle = makeBattle({}, { { move = Data.MOVE_DREAM_EATER, pp = 15 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Dream Eater fails before PP and RNG when its target is awake",
  #statEvents == 2 and statEvents[2].type == "noEffect"
    and battle.player.moves[1].pp == 15 and battle.rng.draws == 0, statEvents)

battle = makeBattle({ 0, 1, 0 }, { { move = Data.MOVE_DREAM_EATER, pp = 15 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
battle.foe.status = 3
battle.player.hp = 5
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Dream Eater hits sleeping targets and heals one half of dealt damage",
  statEvents[2].type == "damage" and statEvents[3].type == "drain"
    and statEvents[3].kind == "dreamEater" and battle.player.moves[1].pp == 14
    and battle.player.hp == math.min(bulbaStats.hp, 5 + math.max(1, math.floor(statEvents[2].amount / 2))), statEvents)
check("Dream Eater on a sleeping target uses the ordinary three damage RNG draws", battle.rng.draws == 3)
check("supportsMove accepts EFFECT_DREAM_EATER=8 now that sleep is modeled",
  battle:supportsMove({ power = 100, effect = 8 }))

battle = makeBattle({}, { { move = Data.MOVE_SNORE, pp = 15 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Snore fails after PP but before accuracy when its user is awake",
  #statEvents == 2 and statEvents[2].type == "snoreFailed"
    and battle.player.moves[1].pp == 14 and battle.rng.draws == 0, statEvents)

battle = makeBattle({ 0, 1, 0, 0 }, { { move = Data.MOVE_SNORE, pp = 15 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
battle.player.status = 3
battle._actionIndex, battle._actionCount = 1, 2
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Snore remains usable while asleep and installs its 30% flinch effect",
  statEvents[2].type == "asleep" and statEvents[3].type == "damage"
    and statEvents[4].type == "flinch" and battle.player.moves[1].pp == 14, statEvents)

battle = makeBattle({ 0, 0 }, { { move = Data.MOVE_SWAGGER, pp = 15 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Swagger raises the target's Attack two stages then applies confusion",
  statEvents[2].type == "statChange" and statEvents[2].stat == "attack" and statEvents[2].stages == 2
    and statEvents[3].type == "confuse" and battle.foe.confusionTurns == 2 and battle.player.moves[1].pp == 14,
  statEvents)

battle = makeBattle({ 0, 0 }, { { move = Data.MOVE_FLATTER, pp = 15 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
battle.foe.confusionTurns = 2
battle.foe.statStages.spAttack = 12
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Flatter fails after PP when its target is already confused and at maximum Sp. Atk",
  #statEvents == 2 and statEvents[2].type == "confuseStatFailed" and battle.player.moves[1].pp == 14,
  statEvents)

battle = makeBattle({ 0 }, { { move = Data.MOVE_CONVERSION_2, pp = 30 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Conversion 2 fails after PP when the user has not taken a landed hit",
  #statEvents == 2 and statEvents[2].type == "conversionFailed" and battle.player.moves[1].pp == 29, statEvents)

battle = makeBattle({ 0 }, { { move = Data.MOVE_CONVERSION_2, pp = 30 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
battle.player.lastHitType = Data.TYPE_FIRE
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Conversion 2 samples a resisting type for the last landed hit",
  statEvents[2].type == "conversion" and battle.player.types[1] == Data.TYPE_FIRE
    and battle.player.types[2] == Data.TYPE_FIRE and battle.player.moves[1].pp == 29, statEvents)

battle = makeBattle({ 0 }, { { move = Data.MOVE_LOCK_ON, pp = 5 }, { move = Data.MOVE_TACKLE, pp = 35 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Lock-On marks its target for one following turn after end-turn decay",
  statEvents[2].type == "lockOn" and battle.foe.lockOnTurns == 2 and battle.player.moves[1].pp == 4, statEvents)
battle:finishTurn(statEvents)
check("Lock-On's source two-turn counter decays to its one-turn accuracy window", battle.foe.lockOnTurns == 1)
battle.player.statStages.accuracy, battle.foe.statStages.evasion = 0, 12
battle:resolveMove(BattleEngine.SIDE_PLAYER, 2, statEvents)
check("Lock-On suppresses the next accuracy roll", battle.rng.draws == 3 and statEvents[#statEvents].type == "damage", statEvents)

battle = makeBattle({}, { { move = Data.MOVE_NIGHTMARE, pp = 15 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Nightmare fails after PP without a sleeping target", #statEvents == 2 and statEvents[2].type == "nightmareFailed"
  and battle.player.moves[1].pp == 14, statEvents)

battle = makeBattle({}, { { move = Data.MOVE_NIGHTMARE, pp = 15 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
battle.foe.status = 3
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
local beforeNightmare = battle.foe.hp
battle:finishTurn(statEvents)
check("Nightmare marks sleeping targets and removes one quarter max HP at turn end",
  statEvents[2].type == "nightmare" and statEvents[3].type == "nightmareDamage"
    and battle.foe.hp == beforeNightmare - math.max(1, math.floor(charStats.hp / 4)), statEvents)

battle = makeBattle({}, { { move = Data.MOVE_CURSE, pp = 10 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("non-Ghost Curse lowers Speed and raises Attack and Defense", statEvents[2].stat == "speed"
  and statEvents[2].stages == -1 and statEvents[3].stat == "attack" and statEvents[3].stages == 1
  and statEvents[4].stat == "defense" and statEvents[4].stages == 1 and battle.player.moves[1].pp == 9, statEvents)

battle = makeBattle({}, { { move = Data.MOVE_CURSE, pp = 10 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
battle.player.types = { Data.TYPE_GHOST, Data.TYPE_GHOST }
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
local beforeCurse = battle.foe.hp
battle:finishTurn(statEvents)
check("Ghost Curse sacrifices half max HP, marks the target, and drains a quarter max HP each turn",
  statEvents[2].type == "curse" and statEvents[3].type == "curseSelfDamage" and statEvents[4].type == "curseDamage"
    and battle.foe.hp == beforeCurse - math.max(1, math.floor(charStats.hp / 4)), statEvents)

battle = makeBattle({}, { { move = Data.MOVE_MEAN_LOOK, pp = 5 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Mean Look marks its target as unable to escape", statEvents[2].type == "trapped"
  and battle.foe.trappedBy == "player" and battle.player.moves[1].pp == 4, statEvents)

local trappedReplacement = BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=Data.MOVE_TACKLE,pp=1}}})
battle.player.trappedBy = "foe"
events = battle:runTurn({action="switch",battler=trappedReplacement}, {action="move",moveSlot=1})
local trapSwitchFailed
for _, event in ipairs(events) do
  if event.type == "switchFailed" and event.trapped then trapSwitchFailed = true end
end
check("a trapped player cannot voluntarily switch", trapSwitchFailed and battle.player ~= trappedReplacement
  and battle.player.trappedBy == "foe", events)

battle = makeBattle({0}, { {move=Data.MOVE_FORESIGHT,pp=40} }, { {move=Data.MOVE_TACKLE,pp=1} })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Foresight marks its target and spends PP", statEvents[2].type == "foresight" and battle.foe.foresight
  and battle.player.moves[1].pp == 39, statEvents)

local ghost = BattleEngine.makeBattler({species=4,level=5,stats=charStats,types={Data.TYPE_GHOST,Data.TYPE_GHOST},moves={{move=Data.MOVE_TACKLE,pp=1}},foresight=true})
battle = BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types={Data.TYPE_NORMAL,Data.TYPE_NORMAL},moves={{move=Data.MOVE_TACKLE,pp=1}}}),foe=ghost,moves=Data.moves,typeChart=Data.typeChart,rng=scriptedRng({0,1,0})})
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Foresight lets Normal attacks affect Ghost targets", statEvents[2].type == "damage", statEvents)

battle = makeBattle({}, { {move=Data.MOVE_PERISH_SONG,pp=5} }, { {move=Data.MOVE_TACKLE,pp=1} })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Perish Song sets both active battlers to the source three-count", statEvents[2].type == "perishSong"
  and battle.player.perishTimer == 3 and battle.foe.perishTimer == 3 and battle.player.moves[1].pp == 4, statEvents)
battle:finishTurn(statEvents); battle:finishTurn(statEvents); battle:finishTurn(statEvents)
check("Perish Song counts down through three, two, and one", battle.player.perishTimer == 0 and battle.foe.perishTimer == 0, statEvents)
battle:finishTurn(statEvents)
check("Perish Song faints the first zero-count battler and ends this bounded 1v1 battle",
  battle.player.hp == 0 and battle.outcome == "playerLost", statEvents)

battle = makeBattle({}, { {move=Data.MOVE_SAFEGUARD,pp=25} }, { {move=Data.MOVE_TACKLE,pp=1} })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Safeguard starts a five-turn side timer without accuracy", statEvents[2].type == "sideStatusSet"
  and battle.sideStatus.player.safeguardTimer == 5 and battle.player.moves[1].pp == 24, statEvents)
battle.sideStatus.foe.safeguard, battle.foe.status = true, 0
local emberMoves = {}; for k,v in pairs(Data.moves) do emberMoves[k] = v end
battle.moves = emberMoves; battle.player.moves = {{move=Data.MOVE_EMBER,pp=25}}
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Safeguard blocks a landed secondary status effect", battle.foe.status == 0, statEvents)

battle = makeBattle({}, { {move=Data.MOVE_WISH,pp=10} }, { {move=Data.MOVE_TACKLE,pp=1} })
battle.player.hp = 1
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
battle:finishTurn(statEvents); battle:finishTurn(statEvents)
check("Wish heals the current battler by half maximum HP after two end turns",
  statEvents[2].type == "wish" and statEvents[#statEvents].type == "wishHeal"
    and battle.player.hp == math.min(bulbaStats.hp, 1 + math.max(1, math.floor(bulbaStats.hp / 2))), statEvents)

battle = makeBattle({0,1,0}, { {move=Data.MOVE_GRUDGE,pp=5} }, { {move=Data.MOVE_TACKLE,pp=35} })
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
battle.player.hp = 1; battle:resolveMove(BattleEngine.SIDE_FOE, 1, statEvents); battle:checkFaint(BattleEngine.SIDE_PLAYER, statEvents)
check("Grudge reduces the direct KO move's PP to zero", battle.foe.moves[1].pp == 0
  and statEvents[#statEvents - 1].type == "grudgePP", statEvents)

battle = makeBattle({0,1,0}, { {move=Data.MOVE_GRUDGE,pp=5} }, { {move=Data.MOVE_TACKLE,pp=35} })
battle.player.grudge, battle.player.status = true, 8
statEvents = {}
battle:applyDamage(BattleEngine.SIDE_FOE, BattleEngine.SIDE_PLAYER, battle.player, 1, {
  superEffective=false, notVeryEffective=false, moveType=0, moveSlot=1, moveId=Data.MOVE_TACKLE,
}, statEvents)
battle.player.hp = 1
battle:finishTurn(statEvents)
local residualGrudgeTriggered = false
for _, event in ipairs(statEvents) do
  if event.type == "grudgePP" then residualGrudgeTriggered = true end
end
check("Grudge ignores a later residual KO after a nonlethal hit", battle.foe.moves[1].pp == 35
  and not residualGrudgeTriggered, statEvents)

battle = makeBattle({0,1,0,1,0}, { {move=Data.MOVE_GRUDGE,pp=5} }, { {move=Data.MOVE_DOUBLE_KICK,pp=30} })
battle.player.grudge, battle.player.hp = true, 1
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_FOE, 1, statEvents)
check("Grudge reduces a multi-hit KO move's PP to zero", battle.foe.moves[1].pp == 0
  and statEvents[#statEvents - 1].type == "grudgePP", statEvents)

battle = makeBattle({0,1,0,0,1,0}, { {move=Data.MOVE_FAKE_OUT,pp=10} }, { {move=Data.MOVE_TACKLE,pp=35} })
statEvents = battle:runTurn({action="move",moveSlot=1}, {action="move",moveSlot=1})
local fakeOutFlinched = false
for _, event in ipairs(statEvents) do
  if event.type == "flinched" and event.side == BattleEngine.SIDE_FOE then fakeOutFlinched = true end
end
check("Fake Out works only on its user's first active turn and certainly flinches", fakeOutFlinched
  and battle.foe.moves[1].pp == 35 and not battle.player.firstTurn, statEvents)
battle.player.moves[1].pp = 10
statEvents = battle:runTurn({action="move",moveSlot=1}, {action="move",moveSlot=1})
check("Fake Out later fails after PP reduction without an accuracy roll", battle.player.moves[1].pp == 9
  and statEvents[3].type == "fakeOutFailed", statEvents)

battle = makeBattle({0,1}, { {move=Data.MOVE_FACADE,pp=20} }, { {move=Data.MOVE_TACKLE,pp=35} })
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
local facadeNormalDamage = statEvents[2].amount
battle = makeBattle({0,1}, { {move=Data.MOVE_FACADE,pp=20} }, { {move=Data.MOVE_TACKLE,pp=35} })
battle.player.status = 8; statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Facade doubles its damage while its user is statused", statEvents[2].amount > facadeNormalDamage,
  {normal=facadeNormalDamage, statused=statEvents[2].amount})

battle = makeBattle({0,1}, { {move=Data.MOVE_SMELLING_SALT,pp=10} }, { {move=Data.MOVE_TACKLE,pp=35} })
battle.foe.status = 64; statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Smelling Salt doubles against and then cures paralysis", battle.foe.status == 0
  and statEvents[#statEvents].type == "paralysisCured", statEvents)

battle = makeBattle({0,1,1,0}, { {move=Data.MOVE_TWISTER,pp=20} }, { {move=Data.MOVE_TACKLE,pp=35} })
battle.player.speed = 100
statEvents = battle:runTurn({action="move",moveSlot=1}, {action="move",moveSlot=1})
local twisterFlinched = false
for _, event in ipairs(statEvents) do
  if event.type == "flinched" and event.side == BattleEngine.SIDE_FOE then twisterFlinched = true end
end
check("Twister uses its retail post-hit 20% flinch effect", twisterFlinched and battle.foe.moves[1].pp == 35,
  statEvents)

battle = makeBattle({0,1,0,1,0,0}, { {move=Data.MOVE_TWINEEDLE,pp=20} }, { {move=Data.MOVE_TACKLE,pp=35} })
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
local twineedleHits = 0
for _, event in ipairs(statEvents) do
  if event.type == "damage" then twineedleHits = twineedleHits + 1 end
end
check("Twineedle makes two hits and one post-sequence poison roll", twineedleHits == 2
  and battle.foe.status == 8 and statEvents[#statEvents - 1].type == "poison", statEvents)

battle = makeBattle({0,1,0,0,2}, { {move=Data.MOVE_TRI_ATTACK,pp=10} }, { {move=Data.MOVE_TACKLE,pp=35} })
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Tri Attack rolls its effect chance then applies the selected burn/freeze/paralysis result", battle.foe.status == 64
  and statEvents[#statEvents].type == "paralyze", statEvents)

battle = makeBattle({0,1,0}, { {move=Data.MOVE_HYPER_BEAM,pp=5}, {move=Data.MOVE_TACKLE,pp=35} }, { {move=Data.MOVE_TACKLE,pp=35} })
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Hyper Beam sets a recharge state after its landed hit", battle.player.recharging
  and statEvents[#statEvents].type == "rechargeSet", statEvents)
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 2, statEvents)
check("Recharge consumes the next action without using the selected move's PP", not battle.player.recharging
  and battle.player.moves[2].pp == 35 and statEvents[1].type == "recharging", statEvents)

battle = makeBattle({0}, { {move=Data.MOVE_HYPER_BEAM,pp=5}, {move=Data.MOVE_TACKLE,pp=35} }, { {move=Data.MOVE_TACKLE,pp=35} })
battle.player.recharging, battle.player.rechargeMove = true, Data.MOVE_HYPER_BEAM
local replacement = BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=35}}})
statEvents = battle:runTurn({action="switch",battler=replacement}, {action="move",moveSlot=1})
local rechargeConsumed = false
for _, event in ipairs(statEvents) do
  if event.type == "recharging" then rechargeConsumed = true end
end
check("Recharge prevents a caller-requested voluntary switch", rechargeConsumed and battle.player.species == 1,
  statEvents)

battle = makeBattle({0,1,0,0,1,0,0,1,0}, { {move=Data.MOVE_TRIPLE_KICK,pp=10} }, { {move=Data.MOVE_TACKLE,pp=35} })
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
local tripleKickHits = 0
for _, event in ipairs(statEvents) do if event.type == "damage" then tripleKickHits = tripleKickHits + 1 end end
check("Triple Kick makes three separately accurate hits at growing power", tripleKickHits == 3
  and statEvents[#statEvents].type == "multiHit" and statEvents[#statEvents].hits == 3 and battle.rng.draws == 9,
  statEvents)

battle = makeBattle({}, { {move=Data.MOVE_MINIMIZE,pp=20} }, { {move=Data.MOVE_TACKLE,pp=35} })
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Minimize sets its marker and raises evasion one stage without accuracy RNG", battle.player.minimized
  and battle.player.statStages.evasion == 7 and battle.rng.draws == 0, statEvents)
battle = makeBattle({0,1,0}, { {move=Data.MOVE_STOMP,pp=20} }, { {move=Data.MOVE_TACKLE,pp=35} })
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
local stompNormalDamage = statEvents[2].amount
battle = makeBattle({0,1,0}, { {move=Data.MOVE_STOMP,pp=20} }, { {move=Data.MOVE_TACKLE,pp=35} })
battle.foe.minimized = true; statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Stomp-family effects double damage against a minimized target", statEvents[2].amount > stompNormalDamage,
  {normal=stompNormalDamage, minimized=statEvents[2].amount})

battle = makeBattle({0,1,0}, { {move=Data.MOVE_SKULL_BASH,pp=15}, {move=Data.MOVE_TACKLE,pp=35} }, { {move=Data.MOVE_TACKLE,pp=35} })
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Skull Bash charges, spends PP once, and raises Defense on its first turn", battle.player.skullBashMove == Data.MOVE_SKULL_BASH
  and battle.player.moves[1].pp == 14 and battle.player.statStages.defense == 7, statEvents)
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 2, statEvents)
check("Skull Bash forces its second-turn hit without spending another PP", battle.player.skullBashMove == nil
  and battle.player.moves[1].pp == 14 and statEvents[2].type == "damage", statEvents)

battle = makeBattle({0,1,0}, { {move=Data.MOVE_RAZOR_WIND,pp=10}, {move=Data.MOVE_TACKLE,pp=35} }, { {move=Data.MOVE_TACKLE,pp=35} })
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Razor Wind enters its reusable charge state after one PP", battle.player.twoTurnMove == Data.MOVE_RAZOR_WIND
  and battle.player.moves[1].pp == 9 and statEvents[2].type == "charging", statEvents)
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 2, statEvents)
check("Razor Wind forces its second-turn hit without further PP", battle.player.twoTurnMove == nil
  and battle.player.moves[1].pp == 9 and statEvents[2].type == "damage", statEvents)

battle = makeBattle({0,1,0}, { {move=Data.MOVE_SKY_ATTACK,pp=1}, {move=Data.MOVE_TACKLE,pp=35} }, { {move=Data.MOVE_TACKLE,pp=35} })
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Sky Attack can complete its forced second turn after spending its final PP", battle.player.twoTurnMove == Data.MOVE_SKY_ATTACK
  and battle.player.moves[1].pp == 0 and statEvents[2].type == "charging", statEvents)
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 2, statEvents)
check("Sky Attack resolves its forced hit instead of substituting Struggle at zero PP", battle.player.twoTurnMove == nil
  and battle.player.moves[1].pp == 0 and statEvents[2].type == "damage", statEvents)

battle = makeBattle({0,1,0}, { {move=Data.MOVE_SOLAR_BEAM,pp=1} }, { {move=Data.MOVE_TACKLE,pp=35} })
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Solar Beam uses the shared charge state outside sunlight", battle.player.twoTurnMove == Data.MOVE_SOLAR_BEAM
  and battle.player.moves[1].pp == 0 and statEvents[2].type == "charging", statEvents)
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Solar Beam completes from its forced state after final-PP charge", battle.player.twoTurnMove == nil
  and battle.player.moves[1].pp == 0 and statEvents[2].type == "damage", statEvents)

battle = makeBattle({0,1,0}, { {move=Data.MOVE_SOLAR_BEAM,pp=1} }, { {move=Data.MOVE_TACKLE,pp=35} })
battle.weather.kind, battle.weather.timer = "sun", 5
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Solar Beam attacks immediately in sunny weather", battle.player.twoTurnMove == nil
  and battle.player.moves[1].pp == 0 and statEvents[2].type == "damage", statEvents)

battle = makeBattle({0,1,0}, { {move=Data.MOVE_CHARGE,pp=1}, {move=Data.MOVE_THUNDER,pp=10} }, { {move=Data.MOVE_TACKLE,pp=35} })
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Charge stores its canonical two-turn boost state without accuracy RNG", battle.player.chargeTurns == 2
  and battle.player.moves[1].pp == 0 and statEvents[2].type == "chargeSet", statEvents)
battle:finishTurn(statEvents)
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 2, statEvents)
local chargedThunderDamage = statEvents[2].amount
battle:finishTurn(statEvents)
check("Charge doubles the next-turn Electric hit and expires at turn end", battle.player.chargeTurns == 0
  and chargedThunderDamage > 0, statEvents)

local uncharged = makeBattle({0,1,0}, { {move=Data.MOVE_THUNDER,pp=10} }, { {move=Data.MOVE_TACKLE,pp=35} })
statEvents = {}; uncharged:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Charge's Electric boost is materially stronger than the same uncharged hit", chargedThunderDamage > statEvents[2].amount,
  {charged=chargedThunderDamage, ordinary=statEvents[2].amount})

battle = makeBattle({}, { {move=Data.MOVE_MUD_SPORT,pp=2} }, { {move=Data.MOVE_TACKLE,pp=35} })
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Mud Sport stores an active-battler field state", battle.player.mudSport and statEvents[2].type == "sportSet", statEvents)
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Mud Sport fails when its source already has the canonical state", battle.player.moves[1].pp == 0
  and statEvents[2].type == "sportFailed", statEvents)

local sportBattle = makeBattle({0,1,0}, { {move=Data.MOVE_THUNDER,pp=10} }, { {move=Data.MOVE_TACKLE,pp=35} })
sportBattle.foe.mudSport = true
statEvents = {}; sportBattle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Either active Mud Sport source halves Electric damage", statEvents[2].amount < chargedThunderDamage,
  {mudSport=statEvents[2].amount, charged=chargedThunderDamage})

battle = makeBattle({}, { {move=Data.MOVE_WATER_SPORT,pp=1} }, { {move=Data.MOVE_TACKLE,pp=35} })
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Water Sport stores its independent active-battler field state", battle.player.waterSport
  and statEvents[2].type == "sportSet", statEvents)

battle = makeBattle({0,1,0}, { {move=Data.MOVE_FLY,pp=1}, {move=Data.MOVE_TACKLE,pp=35} }, { {move=Data.MOVE_TACKLE,pp=35} })
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Fly enters an air semi-invulnerable state after one PP", battle.player.semiInvulnerableMove == Data.MOVE_FLY
  and battle.player.semiInvulnerableKind == "air" and battle.player.moves[1].pp == 0
  and statEvents[2].type == "semiInvulnerableCharge", statEvents)
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_FOE, 1, statEvents)
check("Ordinary moves miss a semi-invulnerable target after PP reduction", battle.foe.moves[1].pp == 34
  and statEvents[2].type == "semiInvulnerableMiss", statEvents)
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 2, statEvents)
local flyLanded = false
for _, event in ipairs(statEvents) do flyLanded = flyLanded or event.type == "damage" end
check("Fly forces and completes its second-turn hit at zero remaining PP", battle.player.semiInvulnerableMove == nil
  and battle.player.moves[1].pp == 0 and flyLanded, statEvents)

battle = makeBattle({0,1,0}, { {move=Data.MOVE_GUST,pp=35} }, { {move=Data.MOVE_FLY,pp=1} })
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_FOE, 1, statEvents)
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Gust is a retail air-phase exception and lands against Fly", statEvents[2].type == "damage", statEvents)

battle = makeBattle({0}, { {move=Data.MOVE_FUTURE_SIGHT,pp=2} }, { {move=Data.MOVE_TACKLE,pp=35} })
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Future Sight stores target-owned delayed damage without an initial accuracy roll", battle.foe.futureAttack
  and battle.foe.futureAttack.turns == 3 and battle.player.moves[1].pp == 1
  and statEvents[2].type == "futureSightSet" and battle.rng.draws == 0, statEvents)
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Future Sight fails while the target already has a delayed attack", battle.player.moves[1].pp == 0
  and statEvents[2].type == "futureSightFailed", statEvents)
battle:finishTurn(statEvents); battle:finishTurn(statEvents)
check("Future Sight remains pending for its first two end turns", battle.foe.futureAttack
  and battle.foe.futureAttack.turns == 1, statEvents)
battle:finishTurn(statEvents)
local futureHit = false
for _, event in ipairs(statEvents) do futureHit = futureHit or event.type == "futureSightHit" end
check("Future Sight resolves on its third end turn with its own accuracy roll", not battle.foe.futureAttack
  and futureHit and battle.rng.draws == 1, statEvents)

battle = makeBattle({0,1,0,0}, { {move=Data.MOVE_UPROAR,pp=1}, {move=Data.MOVE_TACKLE,pp=35} }, { {move=Data.MOVE_TACKLE,pp=35} })
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Uproar locks its move for the retail two-to-five-turn duration after one PP", battle.player.uproarMove == Data.MOVE_UPROAR
  and battle.player.uproarTurns == 3 and battle.player.moves[1].pp == 0 and statEvents[2].type == "uproarSet", statEvents)
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 2, statEvents)
local uproarLanded = false
for _, event in ipairs(statEvents) do uproarLanded = uproarLanded or event.type == "damage" end
check("Uproar forces later uses without spending additional PP", battle.player.moves[1].pp == 0 and uproarLanded, statEvents)

battle.foe.status = 3; statEvents = {}; battle:finishTurn(statEvents)
local wokeInUproar = false
for _, event in ipairs(statEvents) do wokeInUproar = wokeInUproar or event.type == "uproarWake" end
check("An active Uproar wakes sleeping battlers at turn end", battle.foe.status == 0 and wokeInUproar, statEvents)

battle = makeBattle({}, { {move=Data.MOVE_STOCKPILE,pp=4}, {move=Data.MOVE_SPIT_UP,pp=1}, {move=Data.MOVE_SWALLOW,pp=1} }, { {move=Data.MOVE_TACKLE,pp=35} })
for i = 1, 3 do statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents) end
check("Stockpile counts to three without accuracy RNG", battle.player.stockpileCount == 3
  and battle.player.moves[1].pp == 1 and battle.rng.draws == 0 and statEvents[2].type == "stockpile", statEvents)
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Stockpile fails at its real three-count cap after PP reduction", battle.player.stockpileCount == 3
  and battle.player.moves[1].pp == 0 and statEvents[2].type == "stockpileFailed", statEvents)
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 2, statEvents)
local spitDamage = 0
for _, event in ipairs(statEvents) do if event.type == "damage" then spitDamage = event.amount end end
check("Spit Up consumes the stored count and uses multiplied base power", battle.player.stockpileCount == 0 and spitDamage > 0, statEvents)

battle = makeBattle({}, { {move=Data.MOVE_SWALLOW,pp=1} }, { {move=Data.MOVE_TACKLE,pp=35} })
battle.player.stockpileCount, battle.player.hp = 2, 1
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Swallow consumes two stockpiles to heal half max HP", battle.player.stockpileCount == 0
  and battle.player.hp == 10 and statEvents[2].type == "swallow", statEvents)

battle = makeBattle({0}, { {move=Data.MOVE_TAUNT,pp=2} }, { {move=Data.MOVE_GROWL,pp=40}, {move=Data.MOVE_TACKLE,pp=35} })
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Taunt lands after one accuracy roll and stores FireRed's two-turn restriction", battle.foe.tauntTurns == 2
  and battle.player.moves[1].pp == 1 and battle.rng.draws == 1 and statEvents[2].type == "tauntSet", statEvents)
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_FOE, 1, statEvents)
check("Taunt blocks selected zero-power moves without spending PP", battle.foe.moves[1].pp == 40
  and statEvents[1].type == "taunted", statEvents)
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_FOE, 2, statEvents)
local tauntedTackleLanded = false
for _, event in ipairs(statEvents) do tauntedTackleLanded = tauntedTackleLanded or event.type == "damage" end
check("Taunt leaves damaging moves available", battle.foe.moves[2].pp == 34 and tauntedTackleLanded, statEvents)
battle:finishTurn(statEvents); battle:finishTurn(statEvents)
check("Taunt expires through the shared end-turn timer phase", battle.foe.tauntTurns == 0
  and statEvents[#statEvents].type == "tauntEnded", statEvents)

battle = makeBattle({0, 1, 0}, { {move=Data.MOVE_TACKLE,pp=35} }, { {move=Data.MOVE_GROWL,pp=40} })
battle.foe.tauntTurns = 2
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_FOE, 1, statEvents)
check("Taunt makes an all-status move set auto-select Struggle", statEvents[1].type == "useMove"
  and statEvents[1].move == Data.MOVE_STRUGGLE and battle.foe.moves[1].pp == 40, statEvents)

battle = makeBattle({0}, { {move=Data.MOVE_TORMENT,pp=2} }, { {move=Data.MOVE_TACKLE,pp=35}, {move=Data.MOVE_EMBER,pp=25} })
battle.foe.lastMove = Data.MOVE_TACKLE
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Torment lands after accuracy and stores a switch-cleared volatile", battle.foe.tormented
  and battle.player.moves[1].pp == 1 and statEvents[2].type == "tormentSet", statEvents)
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_FOE, 1, statEvents)
check("Torment blocks repeating the immediately previous move without PP", battle.foe.moves[1].pp == 35
  and statEvents[1].type == "tormented", statEvents)
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_FOE, 2, statEvents)
local tormentAlternateLanded = false
for _, event in ipairs(statEvents) do tormentAlternateLanded = tormentAlternateLanded or event.type == "damage" end
check("Torment leaves a different move usable", battle.foe.moves[2].pp == 24 and tormentAlternateLanded, statEvents)

battle = makeBattle({0, 1, 0}, { {move=Data.MOVE_TACKLE,pp=35} }, { {move=Data.MOVE_GROWL,pp=40} })
battle.foe.tormented, battle.foe.lastMove = true, Data.MOVE_GROWL
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_FOE, 1, statEvents)
check("Torment makes a one-move repeated set auto-select Struggle", statEvents[1].type == "useMove"
  and statEvents[1].move == Data.MOVE_STRUGGLE and battle.foe.moves[1].pp == 40, statEvents)

battle = makeBattle({}, { {move=Data.MOVE_IMPRISON,pp=2}, {move=Data.MOVE_TACKLE,pp=35} }, { {move=Data.MOVE_TACKLE,pp=35}, {move=Data.MOVE_EMBER,pp=25} })
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Imprison succeeds without accuracy RNG only when active battlers share a move", battle.player.imprisoning
  and battle.player.moves[1].pp == 1 and battle.rng.draws == 0 and statEvents[2].type == "imprisonSet", statEvents)
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_FOE, 1, statEvents)
check("Imprison blocks a matching selected move without PP", battle.foe.moves[1].pp == 35
  and statEvents[1].type == "imprisoned", statEvents)
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_FOE, 2, statEvents)
local imprisonAlternateLanded = false
for _, event in ipairs(statEvents) do imprisonAlternateLanded = imprisonAlternateLanded or event.type == "damage" end
check("Imprison leaves nonmatching moves usable", battle.foe.moves[2].pp == 24 and imprisonAlternateLanded, statEvents)

battle = makeBattle({}, { {move=Data.MOVE_IMPRISON,pp=1}, {move=Data.MOVE_TACKLE,pp=35} }, { {move=Data.MOVE_EMBER,pp=25} })
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Imprison fails after PP reduction when no active move is shared", not battle.player.imprisoning
  and battle.player.moves[1].pp == 0 and statEvents[2].type == "imprisonFailed", statEvents)

battle = makeBattle({0, 1, 0}, { {move=Data.MOVE_TACKLE,pp=35} }, { {move=Data.MOVE_TACKLE,pp=35} })
battle.player.imprisoning = true
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_FOE, 1, statEvents)
check("Imprison makes an all-matching move set auto-select Struggle", statEvents[1].type == "useMove"
  and statEvents[1].move == Data.MOVE_STRUGGLE and battle.foe.moves[1].pp == 35, statEvents)

battle = makeBattle({0, 0}, { {move=Data.MOVE_ENCORE,pp=5} }, { {move=Data.MOVE_TACKLE,pp=35}, {move=Data.MOVE_EMBER,pp=25} })
battle.foe.lastMove = Data.MOVE_TACKLE
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Encore locks the target's last usable move for the real three-to-six turns", battle.foe.encoreMove == Data.MOVE_TACKLE
  and battle.foe.encoreTurns == 3 and battle.player.moves[1].pp == 4 and battle.rng.draws == 2
  and statEvents[2].type == "encoreSet", statEvents)
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_FOE, 2, statEvents)
check("Encore overrides the requested slot and spends PP only on its locked move", battle.foe.moves[1].pp == 34
  and battle.foe.moves[2].pp == 25 and statEvents[1].move == Data.MOVE_TACKLE, statEvents)
battle:finishTurn(statEvents); battle:finishTurn(statEvents); battle:finishTurn(statEvents)
check("Encore expires through the shared end-turn phase", battle.foe.encoreTurns == 0 and battle.foe.encoreMove == nil
  and statEvents[#statEvents].type == "encoreEnded", statEvents)

battle = makeBattle({0}, { {move=Data.MOVE_ENCORE,pp=1} }, { {move=Data.MOVE_TACKLE,pp=35} })
battle.foe.lastMove = Data.MOVE_ENCORE
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Encore fails after PP reduction when the target last used Encore", battle.player.moves[1].pp == 0
  and battle.foe.encoreTurns == 0 and statEvents[2].type == "encoreFailed", statEvents)

battle = makeBattle({0, 0}, { {move=Data.MOVE_DISABLE,pp=20} }, { {move=Data.MOVE_TACKLE,pp=35}, {move=Data.MOVE_EMBER,pp=25} })
battle.foe.lastMove = Data.MOVE_TACKLE
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Disable locks the target's last usable move for the real two-to-five turns", battle.foe.disabledMove == Data.MOVE_TACKLE
  and battle.foe.disabledTurns == 2 and battle.player.moves[1].pp == 19 and battle.rng.draws == 2
  and statEvents[2].type == "disableSet", statEvents)
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_FOE, 1, statEvents)
check("Disable blocks its selected move without PP", battle.foe.moves[1].pp == 35 and statEvents[1].type == "disabled", statEvents)
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_FOE, 2, statEvents)
local disableAlternateLanded = false
for _, event in ipairs(statEvents) do disableAlternateLanded = disableAlternateLanded or event.type == "damage" end
check("Disable leaves other moves usable", battle.foe.moves[2].pp == 24 and disableAlternateLanded, statEvents)
battle:finishTurn(statEvents); battle:finishTurn(statEvents)
check("Disable expires through the shared end-turn phase", battle.foe.disabledTurns == 0 and battle.foe.disabledMove == nil
  and statEvents[#statEvents].type == "disableEnded", statEvents)

battle = makeBattle({0}, { {move=Data.MOVE_DISABLE,pp=1} }, { {move=Data.MOVE_TACKLE,pp=35} })
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Disable fails after PP reduction without a target last move", battle.player.moves[1].pp == 0
  and battle.foe.disabledTurns == 0 and statEvents[2].type == "disableFailed", statEvents)

battle = makeBattle({0, 1, 0, 0}, { {move=Data.MOVE_POISON_FANG,pp=15} }, { {move=Data.MOVE_TACKLE,pp=35} })
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
local toxicFang = false
for _, event in ipairs(statEvents) do toxicFang = toxicFang or event.type == "toxic" end
check("Poison Fang uses its normal secondary chance to inflict Toxic", battle.foe.status == 128 and toxicFang, statEvents)

battle = makeBattle({0, 1, 0, 0}, { {move=Data.MOVE_POISON_TAIL,pp=25} }, { {move=Data.MOVE_TACKLE,pp=35} })
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
local poisonTail = false
for _, event in ipairs(statEvents) do poisonTail = poisonTail or event.type == "poison" end
check("Poison Tail uses its normal secondary chance to inflict poison", battle.foe.status == 8 and poisonTail, statEvents)

battle = makeBattle({0, 1, 0, 0}, { {move=Data.MOVE_TACKLE,pp=35} }, { {move=Data.MOVE_BLAZE_KICK,pp=10} })
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_FOE, 1, statEvents)
local blazeKickBurn = false
for _, event in ipairs(statEvents) do blazeKickBurn = blazeKickBurn or event.type == "burn" end
check("Blaze Kick uses its normal secondary chance to inflict burn", battle.player.status == 16 and blazeKickBurn, statEvents)

battle = makeBattle({0, 0}, { {move=Data.MOVE_TEETER_DANCE,pp=20} }, { {move=Data.MOVE_TACKLE,pp=35} })
statEvents = {}; battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("Teeter Dance applies primary two-to-five-turn confusion to the sole foe", battle.foe.confusionTurns == 2
  and battle.player.moves[1].pp == 19 and battle.rng.draws == 2 and statEvents[2].type == "confuse", statEvents)

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
battle = makeBattle({ 0, 1, 0, 0, 1, 0 }, { { move = Data.MOVE_TACKLE, pp = 0 } }, { { move = Data.MOVE_EMBER, pp = 1 } })
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
battle = makeBattle({ 0, 1, 0, 11 },
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
battle = makeBattle({ 0, 1, 0, 0, 1, 0 },
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
-- (draws 1-3), then the boosted-evasion foe causes the player's Struggle
-- accuracy roll (draw 4) to miss.
battle = makeBattle({ 0, 1, 0, 11, 50 }, { { move = Data.MOVE_TACKLE, pp = 0 } }, { { move = Data.MOVE_EMBER, pp = 1 } })
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
battle = makeBattle({ 0, 1, 0, 0, 1, 0 }, { { move = Data.MOVE_TACKLE, pp = 0 } }, { { move = Data.MOVE_EMBER, pp = 1 } })
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
-- convention as the rest of this file).

-- EFFECT_DOUBLE_HIT (Double Kick): always exactly 2 hits, ZERO hit-count
-- RNG (real fixed `setmultihitcounter 2` arg) -- total draws = 1 accuracy +
-- 2*(crit+damage) = 5.
battle = makeBattle({ 0, 1, 0, 1, 0 }, { { move = Data.MOVE_DOUBLE_KICK, pp = 30 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
local dmgEvents = {}
for _, e in ipairs(statEvents) do
  if e.type == "damage" then dmgEvents[#dmgEvents + 1] = e end
end
check("Double Kick (EFFECT_DOUBLE_HIT) lands exactly 2 hits", #dmgEvents == 2, #dmgEvents)
check("Double Kick's trailing multiHit event reports 2 hits",
  statEvents[#statEvents].type == "multiHit" and statEvents[#statEvents].hits == 2, statEvents[#statEvents])
check("Double Kick consumes exactly 5 RNG draws (1 accuracy + 2*(crit+damage), zero hit-count RNG)",
  battle.rng.draws == 5, battle.rng.draws)

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
check("single-roll branch consumes exactly 8 draws (1 acc + 1 hitcount + 3*(crit+damage))",
  battle.rng.draws == 8, battle.rng.draws)

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
check("two-roll branch consumes exactly 13 draws (1 acc + 2 hitcount + 5*(crit+damage))",
  battle.rng.draws == 13, battle.rng.draws)

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
check("that two-roll branch consumes exactly 7 draws (1 acc + 2 hitcount + 2*(crit+damage))",
  battle.rng.draws == 7, battle.rng.draws)

-- Defender faints mid-sequence: the sequence stops the instant HP hits 0,
-- landing fewer hits than the rolled count. Fury Attack rolled for 3 hits
-- (single-roll branch, first=1), foe HP set to survive exactly one hit.
battle = makeBattle(
  { 0, 1, 1, 0, 1, 0, 1, 0 },
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
check("the sequence ends with the defender's faint, no further hits attempted",
  statEvents[#statEvents - 1].type == "faint" and statEvents[#statEvents - 1].side == BattleEngine.SIDE_FOE
    and statEvents[#statEvents].type == "battleEnd", statEvents)
check("a faint-terminated sequence emits no trailing multiHit summary event",
  statEvents[#statEvents].type ~= "multiHit" and statEvents[#statEvents - 1].type ~= "multiHit")
check("the mid-sequence faint also ends the battle as playerWon", battle.outcome == "playerWon")

-- Type-immune target: the entire sequence stops at zero hits, not "immune
-- hits skipped, others land." Confirmed only reachable on the first hit
-- since type doesn't change mid-sequence.
local multiHitMoves = {}
for k, v in pairs(Data.moves) do multiHitMoves[k] = v end
local groundFoeMulti = BattleEngine.makeBattler({ species = 0, level = 5, stats = charStats, types = { Data.TYPE_GROUND, Data.TYPE_GROUND }, moves = { { move = Data.MOVE_TACKLE, pp = 1 } } })
local electricPlayerMulti = BattleEngine.makeBattler({ species = 0, level = 5, stats = bulbaStats, types = { Data.TYPE_ELECTRIC, Data.TYPE_ELECTRIC }, moves = { { move = 996, pp = 1 } } })
multiHitMoves[996] = { effect = 29, power = 40, type = Data.TYPE_ELECTRIC, accuracy = 100, pp = 1,
                       secondaryEffectChance = 0, target = 0, priority = 0, flags = 0 }
battle = BattleEngine.new({ player = electricPlayerMulti, foe = groundFoeMulti, moves = multiHitMoves, typeChart = Data.typeChart, rng = scriptedRng({ 0, 1, 1 }) })
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("a type-immune multi-hit move emits a single noEffect and zero damage events",
  statEvents[2].type == "noEffect" and #statEvents == 2, statEvents)
check("no-effect stops before adjustnormaldamage's Random() call -- only accuracy+hitcount+crit consumed",
  battle.rng.draws == 3, battle.rng.draws)

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

-- Spikes (EFFECT_SPIKES=112): Cmd_trysetspikes targets the opposing side,
-- has no accuracy RNG, caps at three layers, and still spends PP on the
-- failed fourth use. Cmd_switchindataupdate then deals maxHP / 8, / 6, / 4
-- (minimum one) to a non-Flying switch-in.
local spikeMoves = {}
for k, v in pairs(Data.moves) do spikeMoves[k] = v end
spikeMoves[997] = { power = 0, type = 0, accuracy = 0, priority = 0, effect = BattleEngine.EFFECT_SPIKES }
battle = BattleEngine.new({
  player = BattleEngine.makeBattler({ species = 1, level = 5, stats = bulbaStats, types = Data.BULBASAUR.types, moves = { { move = 997, pp = 4 } } }),
  foe = BattleEngine.makeBattler({ species = 4, level = 5, stats = charStats, types = Data.CHARMANDER.types, moves = { { move = Data.MOVE_TACKLE, pp = 1 } } }),
  moves = spikeMoves, typeChart = Data.typeChart, rng = scriptedRng({}),
})
for _ = 1, 3 do
  statEvents = {}
  battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
end
check("Spikes accumulates three layers on the opposing side", battle.sideStatus.foe.spikes == 3)
check("Spikes has no accuracy check or other RNG", battle.rng.draws == 0, battle.rng.draws)
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("a fourth Spikes use fails but still deducts PP", statEvents[2].type == "spikesFailed" and battle.player.moves[1].pp == 0)
local spikedIncoming = BattleEngine.makeBattler({
  species = 99, level = 5, stats = charStats, types = Data.CHARMANDER.types, moves = { { move = Data.MOVE_TACKLE, pp = 1 } },
})
battle.sideStatus.player.spikes = 3
battle.player = spikedIncoming
statEvents = {}
battle:applySpikesOnSwitch(BattleEngine.SIDE_PLAYER, statEvents)
check("three Spikes layers deal real maxHP/4 switch-in damage", spikedIncoming.hp == 14 and statEvents[1].damage == 4, spikedIncoming.hp)
local flyingIncoming = BattleEngine.makeBattler({
  species = 99, level = 5, stats = charStats, types = { 2, 2 }, moves = { { move = Data.MOVE_TACKLE, pp = 1 } },
})
battle.sideStatus.player.spikes = 3
battle.player = flyingIncoming
statEvents = {}
battle:applySpikesOnSwitch(BattleEngine.SIDE_PLAYER, statEvents)
check("Flying switch-ins are immune to Spikes", flyingIncoming.hp == flyingIncoming.maxHP and #statEvents == 0)

-- Rapid Spin (EFFECT_RAPID_SPIN=129) is an ordinary damaging move whose
-- certain post-hit effect runs Cmd_rapidspinfree. With Wrap and Leech Seed
-- outside this engine, its applicable branch removes all own-side Spikes.
spikeMoves[996] = { power = 20, type = Data.TYPE_NORMAL, accuracy = 100, priority = 0, effect = BattleEngine.EFFECT_RAPID_SPIN }
battle = BattleEngine.new({
  player = BattleEngine.makeBattler({ species = 1, level = 5, stats = bulbaStats, types = Data.BULBASAUR.types, moves = { { move = 996, pp = 2 } } }),
  foe = BattleEngine.makeBattler({ species = 4, level = 5, stats = charStats, types = Data.CHARMANDER.types, moves = { { move = Data.MOVE_TACKLE, pp = 1 } } }),
  moves = spikeMoves, typeChart = Data.typeChart, rng = scriptedRng({ 0, 1, 0 }),
})
battle.sideStatus.player.spikes = 3
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("a landed Rapid Spin clears every own-side Spikes layer", battle.sideStatus.player.spikes == 0
  and statEvents[#statEvents].type == "spikesCleared")

local ghostFoe = BattleEngine.makeBattler({ species = 0, level = 5, stats = charStats,
  types = { Data.TYPE_GHOST, Data.TYPE_GHOST }, moves = { { move = Data.MOVE_TACKLE, pp = 1 } } })
battle = BattleEngine.new({
  player = BattleEngine.makeBattler({ species = 1, level = 5, stats = bulbaStats, types = Data.BULBASAUR.types, moves = { { move = 996, pp = 1 } } }),
  foe = ghostFoe, moves = spikeMoves, typeChart = Data.typeChart, rng = scriptedRng({ 0, 1, 0 }),
})
battle.sideStatus.player.spikes = 3
statEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, statEvents)
check("an immune Rapid Spin hit does not clear Spikes", battle.sideStatus.player.spikes == 3
  and statEvents[#statEvents].type == "noEffect")

-- Flail/Reversal (EFFECT_FLAIL=99) replace their imported base power of 1
-- before the ordinary hit script. A 1-HP user must therefore hit much
-- harder than the same healthy battler without changing accuracy/crit/RNG.
spikeMoves[995] = { power = 1, type = Data.TYPE_NORMAL, accuracy = 100, priority = 0, effect = BattleEngine.EFFECT_FLAIL }
local flailStats = { hp=48, attack=50, defense=50, speed=50, spAttack=50, spDefense=50 }
local function flailDamageAt(hp)
  local flailUser = BattleEngine.makeBattler({ species=1, level=50, stats=flailStats,
    types={Data.TYPE_NORMAL, Data.TYPE_NORMAL}, moves={{move=995, pp=1}} })
  flailUser.hp = hp
  local flailFoe = BattleEngine.makeBattler({ species=4, level=50, stats={hp=999,attack=50,defense=50,speed=10,spAttack=50,spDefense=50},
    types=Data.CHARMANDER.types, moves={{move=Data.MOVE_TACKLE,pp=1}} })
  local flailBattle = BattleEngine.new({player=flailUser, foe=flailFoe, moves=spikeMoves,
    typeChart=Data.typeChart, rng=scriptedRng({0, 1, 0})})
  local flailEvents = {}
  flailBattle:resolveMove(BattleEngine.SIDE_PLAYER, 1, flailEvents)
  for _, event in ipairs(flailEvents) do
    if event.type == "damage" then return event.amount end
  end
  return nil
end
check("Flail's dynamic base power makes a 1-HP user deal more damage than a healthy user",
  flailDamageAt(1) > flailDamageAt(48))

-- Voluntary switch action: real SetActionsAndBattlersTurnOrder hoists
-- B_ACTION_SWITCH ahead of any move (like capture/run already are), no
-- RNG of its own; the foe still attacks the same turn, against the
-- newly-switched-in battler. Real Cmd_switchindataupdate confirms an
-- ordinary switch-in starts with neutral stat stages regardless of what
-- the outgoing battler's stages were.
battle = makeBattle({ 0, 0, 0 }, { { move = Data.MOVE_GROWL, pp = 40 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
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
check("a switch consumes no RNG of its own (only the foe's ordinary attack draws)",
  battle.rng.draws == 3, battle.rng.draws)

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

-- Forced switch-ins run the same Spikes check as voluntary ones.
battle = makeBattle({}, { { move = Data.MOVE_TACKLE, pp = 1 } }, { { move = Data.MOVE_TACKLE, pp = 1 } })
battle.awaitingForcedSwitch = BattleEngine.SIDE_FOE
battle.sideStatus.foe.spikes = 3
forcedIncoming = BattleEngine.makeBattler({
  species = 4, level = 5, stats = charStats, types = Data.CHARMANDER.types,
  moves = { { move = Data.MOVE_TACKLE, pp = 1 } },
})
resolveEvents = battle:resolveForcedSwitch(BattleEngine.SIDE_FOE, forcedIncoming)
check("forced switch-ins take the same three-layer Spikes damage", forcedIncoming.hp == 14
  and resolveEvents[2].type == "spikesDamage" and resolveEvents[2].damage == 4, forcedIncoming.hp)

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

-- False Swipe is an ordinary damaging hit except its real datahpupdate
-- branch leaves a lethal target at one HP without setting Endure state.
local falseSwipeMoves = {}
for k, v in pairs(Data.moves) do falseSwipeMoves[k] = v end
falseSwipeMoves[994] = { power=200, type=Data.TYPE_NORMAL, accuracy=100, priority=0, effect=BattleEngine.EFFECT_FALSE_SWIPE }
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types={Data.TYPE_NORMAL,Data.TYPE_NORMAL},moves={{move=994,pp=1}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=falseSwipeMoves,typeChart=Data.typeChart,rng=scriptedRng({0,1,0}),
})
battle.foe.hp = 1
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("False Swipe leaves a lethal target at one HP without an Endure event", battle.foe.hp == 1
  and not battle.foe.endured and events[#events].type == "damage" and events[#events].amount == 0)

-- Recover/Soft-Boiled and Morning Sun/Synthesis/Moonlight are self-target,
-- no-accuracy heals. Their source amounts are half max HP normally, two
-- thirds in sun, and one quarter in any other active weather.
local healMoves = {}
for k, v in pairs(Data.moves) do healMoves[k] = v end
healMoves[993] = {power=0,type=Data.TYPE_NORMAL,accuracy=0,priority=0,effect=BattleEngine.EFFECT_RESTORE_HP}
healMoves[992] = {power=0,type=Data.TYPE_NORMAL,accuracy=0,priority=0,effect=BattleEngine.EFFECT_MORNING_SUN}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=993,pp=2},{move=992,pp=1}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=healMoves,typeChart=Data.typeChart,rng=scriptedRng({}),
})
battle.player.hp = 1
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Recover heals half max HP without RNG", battle.player.hp == 10 and battle.rng.draws == 0 and events[2].type == "heal")
battle.player.hp = 1
battle.weather.kind = "sun"
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 2, events)
check("Morning Sun heals two thirds max HP in sun", battle.player.hp == 13 and events[2].amount == 12)

-- Weather Ball becomes Water and doubles its power in rain, so against a
-- Fire target it must deal more damage than the same move in neutral weather.
local weatherBallMoves = {}
for k, v in pairs(Data.moves) do weatherBallMoves[k] = v end
weatherBallMoves[991] = {power=50,type=Data.TYPE_NORMAL,accuracy=100,priority=0,effect=BattleEngine.EFFECT_WEATHER_BALL}
local function weatherBallDamage(weather)
  local wb = BattleEngine.new({
    player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=991,pp=1}}}),
    foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
    moves=weatherBallMoves,typeChart=Data.typeChart,rng=scriptedRng({0,1,0}),
  })
  wb.weather.kind = weather
  local wbEvents = {}
  wb:resolveMove(BattleEngine.SIDE_PLAYER, 1, wbEvents)
  for _, event in ipairs(wbEvents) do if event.type == "damage" then return event.amount end end
end
check("Weather Ball becomes doubled Water damage in rain", weatherBallDamage("rain") > weatherBallDamage(nil))

local endeavorMoves = {}
for k, v in pairs(Data.moves) do endeavorMoves[k] = v end
endeavorMoves[990] = {power=1,type=Data.TYPE_NORMAL,accuracy=100,priority=0,effect=BattleEngine.EFFECT_ENDEAVOR}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=990,pp=2}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=endeavorMoves,typeChart=Data.typeChart,rng=scriptedRng({0}),
})
battle.player.hp, battle.foe.hp = 5, 14
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Endeavor reduces a healthier target to the user's HP", battle.foe.hp == 5)
battle.foe.hp = 5
events = {}
local endeavorDraws = battle.rng.draws
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Endeavor fails before accuracy when target is not healthier", events[2].type == "endeavorFailed" and battle.rng.draws == endeavorDraws)

local counterMoves = {}
for k, v in pairs(Data.moves) do counterMoves[k] = v end
counterMoves[988] = {power=1,type=Data.TYPE_FIGHTING,accuracy=100,priority=0,effect=BattleEngine.EFFECT_COUNTER}
counterMoves[989] = {power=1,type=Data.TYPE_PSYCHIC,accuracy=100,priority=0,effect=BattleEngine.EFFECT_MIRROR_COAT}
local function counterBattle(move)
  return BattleEngine.new({
    player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=move,pp=2}}}),
    foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
    moves=counterMoves,typeChart=Data.typeChart,rng=scriptedRng({0, 1, 0}),
  })
end
battle = counterBattle(988)
battle.player.physicalDamageThisTurn = {amount=4, side=BattleEngine.SIDE_FOE}
events = {}
local counterFoeHp = battle.foe.hp
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Counter returns double this-turn physical damage", battle.foe.hp == counterFoeHp - 8)
battle = counterBattle(989)
battle.player.specialDamageThisTurn = {amount=3, side=BattleEngine.SIDE_FOE}
events = {}
counterFoeHp = battle.foe.hp
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Mirror Coat returns double this-turn special damage", battle.foe.hp == counterFoeHp - 6)
battle = counterBattle(988)
events = {}
local counterDraws = battle.rng.draws
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Counter fails without a valid physical hit and spends neither PP nor RNG", events[2].type == "counterFailed" and battle.player.moves[1].pp == 2 and battle.rng.draws == counterDraws)

local ohkoMoves = {}
for k, v in pairs(Data.moves) do ohkoMoves[k] = v end
ohkoMoves[987] = {power=1,type=Data.TYPE_NORMAL,accuracy=30,priority=0,effect=BattleEngine.EFFECT_OHKO}
local function ohkoBattle(playerLevel, foeLevel, rolls)
  return BattleEngine.new({
    player=BattleEngine.makeBattler({species=1,level=playerLevel,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=987,pp=2}}}),
    foe=BattleEngine.makeBattler({species=4,level=foeLevel,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
    moves=ohkoMoves,typeChart=Data.typeChart,rng=scriptedRng(rolls),
  })
end
battle = ohkoBattle(6, 5, {0})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("OHKO move KOs a lower-level target on its level-adjusted roll", battle.foe.hp == 0 and battle.rng.draws == 1)
battle = ohkoBattle(5, 6, {0})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("OHKO move fails against a higher-level target after PP and its KO roll", events[2].type == "ohkoFailed" and battle.player.moves[1].pp == 1 and battle.foe.hp > 0 and battle.rng.draws == 1)

local explosionMoves = {}
for k, v in pairs(Data.moves) do explosionMoves[k] = v end
explosionMoves[986] = {power=1,type=Data.TYPE_NORMAL,accuracy=100,priority=1,effect=BattleEngine.EFFECT_EXPLOSION}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=986,pp=1}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=explosionMoves,typeChart=Data.typeChart,rng=scriptedRng({0, 1, 0}),
})
local explosionFoeHp = battle.foe.hp
events = battle:runTurn({moveSlot=1}, {moveSlot=1})
local sawExplosionSelfKO = false
for _, event in ipairs(events) do if event.type == "explosionSelfKO" then sawExplosionSelfKO = true end end
check("Explosion self-KOs after dealing damage", battle.player.hp == 0 and battle.outcome == "playerLost" and battle.foe.hp < explosionFoeHp and sawExplosionSelfKO)

local bideMoves = {}
for k, v in pairs(Data.moves) do bideMoves[k] = v end
bideMoves[985] = {power=0,type=Data.TYPE_NORMAL,accuracy=0,priority=0,effect=BattleEngine.EFFECT_BIDE}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=985,pp=2},{move=Data.MOVE_TACKLE,pp=2}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=2}}}),
  moves=bideMoves,typeChart=Data.typeChart,rng=scriptedRng({0, 1, 0, 0, 1, 0}),
})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
battle:resolveMove(BattleEngine.SIDE_FOE, 1, events)
local storedBideDamage, bideFoeHp = battle.player.bideDamage, battle.foe.hp
battle:resolveMove(BattleEngine.SIDE_PLAYER, 2, events)
battle:resolveMove(BattleEngine.SIDE_PLAYER, 2, events)
check("Bide stores two turns then releases double accumulated direct damage", storedBideDamage > 0 and battle.foe.hp == bideFoeHp - storedBideDamage * 2 and battle.player.bideTurns == 0)

local presentMoves = {}
for k, v in pairs(Data.moves) do presentMoves[k] = v end
presentMoves[984] = {power=1,type=Data.TYPE_NORMAL,accuracy=100,priority=0,effect=BattleEngine.EFFECT_PRESENT}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=984,pp=1}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=presentMoves,typeChart=Data.typeChart,rng=scriptedRng({0, 204}),
})
battle.foe.hp = 1
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Present's upper byte range heals one quarter target max HP", battle.foe.hp == math.min(battle.foe.maxHP, 1 + math.floor(battle.foe.maxHP / 4)) and events[2].type == "presentHeal")

local furyMoves = {}
for k, v in pairs(Data.moves) do furyMoves[k] = v end
furyMoves[983] = {power=10,type=Data.TYPE_NORMAL,accuracy=100,priority=0,effect=119}
local function furyDamage(count)
  local fb = BattleEngine.new({
    player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=983,pp=5}}}),
    foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
    moves=furyMoves,typeChart=Data.typeChart,rng=scriptedRng({0,1,0,0,1,0,0,1,0}),
  })
  local before = fb.foe.hp
  for _ = 1, count do fb:resolveMove(BattleEngine.SIDE_PLAYER, 1, {}) end
  return before - fb.foe.hp
end
check("Fury Cutter doubles its base power on consecutive hits", furyDamage(2) > furyDamage(1))

local rolloutMoves = {}
for k, v in pairs(Data.moves) do rolloutMoves[k] = v end
rolloutMoves[982] = {power=30,type=Data.TYPE_NORMAL,accuracy=100,priority=0,effect=117}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=982,pp=5},{move=Data.MOVE_TACKLE,pp=5}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=rolloutMoves,typeChart=Data.typeChart,rng=scriptedRng({0,1,0,0,1,0}),
})
local rolloutFoeHp = battle.foe.hp
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, {})
local firstRolloutDamage = rolloutFoeHp - battle.foe.hp
rolloutFoeHp = battle.foe.hp
battle:resolveMove(BattleEngine.SIDE_PLAYER, 2, {})
check("Rollout locks its move and doubles on the next hit", battle.foe.hp < rolloutFoeHp - firstRolloutDamage and battle.player.rolloutTurns == 3)

local rageMoves = {}
for k, v in pairs(Data.moves) do rageMoves[k] = v end
rageMoves[981] = {power=20,type=Data.TYPE_NORMAL,accuracy=100,priority=0,effect=81}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=981,pp=1}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=rageMoves,typeChart=Data.typeChart,rng=scriptedRng({0,1,0,0,1,0}),
})
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, {})
local rageAttack = battle.player.statStages.attack
battle:resolveMove(BattleEngine.SIDE_FOE, 1, {})
check("Rage raises Attack when its user takes direct damage", battle.player.rageActive and battle.player.statStages.attack == rageAttack + 1)
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, {})
battle.player.moves[1].move = Data.MOVE_TACKLE
battle.player.moves[1].pp = 1
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, {})
check("Rage ends when its user selects another move", not battle.player.rageActive)

local rageMissMoves = {}
for k, v in pairs(Data.moves) do rageMissMoves[k] = v end
rageMissMoves[981] = {power=20,type=Data.TYPE_NORMAL,accuracy=1,priority=0,effect=BattleEngine.EFFECT_RAGE}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=981,pp=1}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=rageMissMoves,typeChart=Data.typeChart,rng=scriptedRng({99}),
})
battle.player.rageActive = true
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, {})
check("A missed Rage ends its existing Rage state", not battle.player.rageActive)

local rampageMoves = {}
for k, v in pairs(Data.moves) do rampageMoves[k] = v end
rampageMoves[969] = {power=1,type=Data.TYPE_NORMAL,accuracy=100,priority=0,effect=BattleEngine.EFFECT_RAMPAGE}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=969,pp=2},{move=Data.MOVE_TACKLE,pp=1}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=2}}}),
  moves=rampageMoves,typeChart=Data.typeChart,rng=scriptedRng({0,0,0,0,0,0,0,0}),
})
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, {})
local rampagePP = battle.player.moves[1].pp
battle:finishTurn({})
battle:resolveMove(BattleEngine.SIDE_PLAYER, 2, {})
local rampageEvents = {}
battle:finishTurn(rampageEvents)
check("Rampage locks its move, spends PP once, then confuses its user", rampagePP == 1
  and battle.player.moves[1].pp == 1 and battle.player.rampageTurns == 0
  and battle.player.confusionTurns >= 2 and rampageEvents[#rampageEvents].type == "rampageConfuse")

local trapMoves = {}
for k, v in pairs(Data.moves) do trapMoves[k] = v end
trapMoves[968] = {power=1,type=Data.TYPE_NORMAL,accuracy=100,priority=0,effect=BattleEngine.EFFECT_TRAP}
trapMoves[967] = {power=1,type=Data.TYPE_NORMAL,accuracy=100,priority=0,effect=BattleEngine.EFFECT_RAPID_SPIN}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=968,pp=1}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=trapMoves,typeChart=Data.typeChart,rng=scriptedRng({0,0,0,0}),
})
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, {})
local trapEvents, trapHp = {}, battle.foe.hp
battle:finishTurn(trapEvents)
check("Trapping moves set a 3–6 turn target volatile and deal 1/16 residual", battle.foe.trappedTurns == 2
  and battle.foe.trappedBy == BattleEngine.SIDE_PLAYER and battle.foe.hp < trapHp
  and trapEvents[1].type == "trapDamage")

battle.player.trappedTurns, battle.player.trappedBy, battle.player.trappedMove = 3, BattleEngine.SIDE_FOE, 968
battle.player.moves[1] = {move=967, pp=1}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, {})
check("Rapid Spin clears the user's trapping state after a landed hit", battle.player.trappedTurns == 0
  and battle.player.trappedBy == nil and battle.player.trappedMove == nil)

local destinyMoves = {}
for k, v in pairs(Data.moves) do destinyMoves[k] = v end
destinyMoves[966] = {power=0,type=Data.TYPE_GHOST,accuracy=0,priority=0,effect=BattleEngine.EFFECT_DESTINY_BOND}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=966,pp=1}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=destinyMoves,typeChart=Data.typeChart,rng=scriptedRng({0,0,0}),
})
battle.player.hp, battle.player.speed = 1, 100
events = battle:runTurn({moveSlot=1}, {moveSlot=1})
local sawDestinyKO = false
for _, event in ipairs(events) do if event.type == "destinyBondKO" then sawDestinyKO = true end end
check("Destiny Bond KOs the direct opposing attacker when its user faints", battle.foe.hp == 0
  and battle.outcome == "playerWon" and sawDestinyKO)

local mimicMoves = {}
for k, v in pairs(Data.moves) do mimicMoves[k] = v end
mimicMoves[965] = {power=0,type=Data.TYPE_NORMAL,accuracy=0,priority=0,effect=BattleEngine.EFFECT_MIMIC}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=965,pp=1}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=mimicMoves,typeChart=Data.typeChart,rng=scriptedRng({0,0,0}),
})
battle:resolveMove(BattleEngine.SIDE_FOE, 1, {})
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, {})
check("Mimic copies the target's last eligible move with up to five PP", battle.player.moves[1].move == Data.MOVE_TACKLE
  and battle.player.moves[1].pp == 5)

local sketchMoves = {}
for k, v in pairs(Data.moves) do sketchMoves[k] = v end
sketchMoves[966] = {power=0,type=Data.TYPE_NORMAL,accuracy=0,priority=0,effect=BattleEngine.EFFECT_SKETCH}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=966,pp=1}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=sketchMoves,typeChart=Data.typeChart,rng=scriptedRng({0,0,0}),
})
battle:resolveMove(BattleEngine.SIDE_FOE, 1, {})
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, {})
check("Sketch permanently copies the target's last move at its full PP", battle.player.moves[1].move == Data.MOVE_TACKLE
  and battle.player.moves[1].pp == Data.moves[Data.MOVE_TACKLE].pp
  and battle.player.permanentMoveChanges[1] == Data.MOVE_TACKLE)

battle.player.transformed = true
battle.player.moves[1] = {move=966,pp=1}
local sketchEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, sketchEvents)
check("Sketch fails after Transform without replacing its move", battle.player.moves[1].move == 966
  and sketchEvents[#sketchEvents].type == "sketchFailed")

local attractMoves = {}
for k, v in pairs(Data.moves) do attractMoves[k] = v end
attractMoves[967] = {power=0,type=Data.TYPE_NORMAL,accuracy=100,priority=0,effect=BattleEngine.EFFECT_ATTRACT}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,gender=0,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=967,pp=1}}}),
  foe=BattleEngine.makeBattler({species=4,gender=1,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=attractMoves,typeChart=Data.typeChart,rng=scriptedRng({0}),
})
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, {})
local attractEvents = {}
battle:resolveMove(BattleEngine.SIDE_FOE, 1, attractEvents)
local sawInfatuated, sawLoveImmobility = false, false
for _, event in ipairs(attractEvents) do
  if event.type == "infatuated" then sawInfatuated = true end
  if event.type == "loveImmobility" then sawLoveImmobility = true end
end
check("Attract infatuates an opposite-gender target and has a 50% action gate",
  battle.foe.infatuatedBy == BattleEngine.SIDE_PLAYER and sawInfatuated and sawLoveImmobility)

battle.player.gender, battle.foe.gender, battle.foe.infatuatedBy = 255, 1, nil
battle.player.moves[1].pp = 1
local genderlessAttractEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, genderlessAttractEvents)
check("Attract rejects a genderless user", genderlessAttractEvents[#genderlessAttractEvents].type == "attractFailed")

local camouflageMoves = {}
for k, v in pairs(Data.moves) do camouflageMoves[k] = v end
camouflageMoves[968] = {power=0,type=Data.TYPE_NORMAL,accuracy=0,priority=0,effect=BattleEngine.EFFECT_CAMOUFLAGE}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types={Data.TYPE_NORMAL,Data.TYPE_NORMAL},moves={{move=968,pp=2}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=camouflageMoves,typeChart=Data.typeChart,rng=scriptedRng({}),battleTerrain=2,
})
local camouflageEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, camouflageEvents)
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, camouflageEvents)
check("Camouflage uses terrain type and fails when already that type", battle.player.types[1] == Data.TYPE_GROUND
  and battle.player.types[2] == Data.TYPE_GROUND and battle.player.moves[1].pp == 0
  and camouflageEvents[#camouflageEvents].type == "camouflageFailed")

naturePowerMoves = {}
for k, v in pairs(Data.moves) do naturePowerMoves[k] = v end
naturePowerMoves[969] = {power=0,type=Data.TYPE_NORMAL,accuracy=0,priority=0,effect=BattleEngine.EFFECT_NATURE_POWER}
naturePowerMoves[129] = {power=60,type=Data.TYPE_NORMAL,accuracy=100,priority=0,effect=0}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=969,pp=2}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=naturePowerMoves,typeChart=Data.typeChart,rng=scriptedRng({0,1,0}),battleTerrain=9,
})
naturePowerEvents = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, naturePowerEvents)
sawNaturePower = false
for _, event in ipairs(naturePowerEvents) do
  if event.type == "naturePower" and event.move == 129 then sawNaturePower = true end
end
check("Nature Power calls the terrain move and spends only its own PP", battle.player.moves[1].pp == 1
  and battle.foe.hp < charStats.hp and sawNaturePower, battle.player.moves[1].pp .. "/" .. battle.foe.hp .. "/" .. tostring(sawNaturePower) .. "/" .. tostring(naturePowerEvents[1] and naturePowerEvents[1].type) .. "/" .. tostring(naturePowerEvents[2] and naturePowerEvents[2].type))

local sleepTalkMoves = {}
for k, v in pairs(Data.moves) do sleepTalkMoves[k] = v end
sleepTalkMoves[BattleEngine.MOVE_SLEEP_TALK] = {power=0,type=Data.TYPE_NORMAL,accuracy=0,priority=0,effect=BattleEngine.EFFECT_SLEEP_TALK}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,status=2,
    moves={{move=BattleEngine.MOVE_SLEEP_TALK,pp=2},{move=Data.MOVE_TACKLE,pp=0}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=sleepTalkMoves,typeChart=Data.typeChart,rng=scriptedRng({1,0,1,0}),
})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
local sawSleepTalk = false
for _, event in ipairs(events) do
  if event.type == "sleepTalk" and event.move == Data.MOVE_TACKLE then sawSleepTalk = true end
end
check("Sleep Talk calls an eligible zero-PP move while asleep and spends only its own PP",
  battle.player.moves[1].pp == 1 and battle.player.moves[2].pp == 0 and battle.foe.hp < charStats.hp
    and sawSleepTalk)

battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=BattleEngine.MOVE_SLEEP_TALK,pp=1}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=sleepTalkMoves,typeChart=Data.typeChart,rng=scriptedRng({}),
})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Sleep Talk awake failure still spends its own PP", battle.player.moves[1].pp == 0
  and events[#events].type == "sleepTalkFailed" and events[#events].reason == "awake")

local crashMoves = {}
for k, v in pairs(Data.moves) do crashMoves[k] = v end
crashMoves[980] = {power=100,type=Data.TYPE_FIGHTING,accuracy=0,priority=0,effect=45}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=980,pp=1}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=crashMoves,typeChart=Data.typeChart,rng=scriptedRng({0, 0}),
})
local crashHp = battle.player.hp
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
local sawCrash = false
for _, event in ipairs(events) do if event.type == "recoil" then sawCrash = true end end
check("Recoil-if-miss moves crash into the user after a non-immune miss", battle.player.hp < crashHp and sawCrash)

local spiteMoves = {}
for k, v in pairs(Data.moves) do spiteMoves[k] = v end
spiteMoves[979] = {power=0,type=Data.TYPE_GHOST,accuracy=100,priority=0,effect=BattleEngine.EFFECT_SPITE}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=979,pp=1}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=6}}}),
  moves=spiteMoves,typeChart=Data.typeChart,rng=scriptedRng({0, 0}),
})
battle.foe.lastMove = Data.MOVE_TACKLE
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Spite removes 2-5 PP from the foe's last used move", battle.foe.moves[1].pp == 4 and events[2].type == "spite")

local splashMoves = {}
for k, v in pairs(Data.moves) do splashMoves[k] = v end
splashMoves[978] = {power=0,type=Data.TYPE_NORMAL,accuracy=0,priority=0,effect=BattleEngine.EFFECT_SPLASH}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=978,pp=1}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=splashMoves,typeChart=Data.typeChart,rng=scriptedRng({}),
})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Splash consumes PP and reports its no-effect result", battle.player.moves[1].pp == 0 and events[2].type == "splash")

local conversionMoves = {}
for k, v in pairs(Data.moves) do conversionMoves[k] = v end
conversionMoves[977] = {power=0,type=Data.TYPE_NORMAL,accuracy=0,priority=0,effect=BattleEngine.EFFECT_CONVERSION}
conversionMoves[976] = {power=20,type=Data.TYPE_FIRE,accuracy=100,priority=0,effect=0}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=977,pp=1},{move=976,pp=1}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=conversionMoves,typeChart=Data.typeChart,rng=scriptedRng({1}),
})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Conversion changes to a different known move type", battle.player.types[1] == Data.TYPE_FIRE and battle.player.types[2] == Data.TYPE_FIRE and events[2].type == "conversion")

local mementoMoves = {}
for k, v in pairs(Data.moves) do mementoMoves[k] = v end
mementoMoves[975] = {power=0,type=Data.TYPE_DARK,accuracy=100,priority=0,effect=BattleEngine.EFFECT_MEMENTO,flags=2}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=975,pp=1}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=mementoMoves,typeChart=Data.typeChart,rng=scriptedRng({}),
})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Memento sacrifices its user and lowers the target's Attack and Sp. Atk by two stages", battle.player.hp == 0 and battle.foe.statStages.attack == 4 and battle.foe.statStages.spAttack == 4 and events[2].type == "mementoSelfKO" and battle.player.moves[1].pp == 0)

battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=975,pp=1}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=mementoMoves,typeChart=Data.typeChart,rng=scriptedRng({}),
})
battle.foe.statStages.attack, battle.foe.statStages.spAttack = 0, 0
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Memento fails without self-KO when both target stats are already minimum", battle.player.hp == bulbaStats.hp and events[2].type == "mementoFailed" and battle.player.moves[1].pp == 0)

local weatherHealMoves = {}
for k, v in pairs(Data.moves) do weatherHealMoves[k] = v end
weatherHealMoves[974] = {power=0,type=Data.TYPE_GRASS,accuracy=0,priority=0,effect=BattleEngine.EFFECT_SYNTHESIS}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,hp=1,types=Data.BULBASAUR.types,moves={{move=974,pp=1}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=weatherHealMoves,typeChart=Data.typeChart,rng=scriptedRng({}),
})
battle.weather.kind = "sun"
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Synthesis shares Morning Sun's weather-scaled healing", battle.player.hp == 13 and events[2].type == "heal")

local allStatsMoves = {}
for k, v in pairs(Data.moves) do allStatsMoves[k] = v end
allStatsMoves[973] = {power=20,type=Data.TYPE_ROCK,accuracy=100,priority=0,effect=140,secondaryEffectChance=100}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=973,pp=1}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=allStatsMoves,typeChart=Data.typeChart,rng=scriptedRng({0, 1, 0, 0}),
})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("All-stats-up hits raise every non-HP stat after a successful secondary roll", battle.player.statStages.attack == 7 and battle.player.statStages.defense == 7 and battle.player.statStages.speed == 7 and battle.player.statStages.spAttack == 7 and battle.player.statStages.spDefense == 7)

local alwaysHitMoves = {}
for k, v in pairs(Data.moves) do alwaysHitMoves[k] = v end
alwaysHitMoves[972] = {power=60,type=Data.TYPE_NORMAL,accuracy=0,priority=0,effect=BattleEngine.EFFECT_ALWAYS_HIT}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=972,pp=1}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=alwaysHitMoves,typeChart=Data.typeChart,rng=scriptedRng({1, 0}),
})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Always-hit moves bypass accuracy and consume only crit plus damage RNG", battle.foe.hp < charStats.hp and battle.rng.draws == 2)

local friendshipMoves = {}
for k, v in pairs(Data.moves) do friendshipMoves[k] = v end
friendshipMoves[971] = {power=1,type=Data.TYPE_NORMAL,accuracy=100,priority=0,effect=BattleEngine.EFFECT_RETURN}
friendshipMoves[970] = {power=1,type=Data.TYPE_NORMAL,accuracy=100,priority=0,effect=BattleEngine.EFFECT_FRUSTRATION}
local function friendshipDamage(move, friendship)
  local localBattle = BattleEngine.new({
    player=BattleEngine.makeBattler({species=1,level=5,friendship=friendship,stats=bulbaStats,types={Data.TYPE_NORMAL,Data.TYPE_NORMAL},moves={{move=move,pp=1}}}),
    foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
    moves=friendshipMoves,typeChart=Data.typeChart,rng=scriptedRng({0, 1, 0}),
  })
  local localEvents = {}
  localBattle:resolveMove(BattleEngine.SIDE_PLAYER, 1, localEvents)
  return charStats.hp - localBattle.foe.hp
end
check("Return and Frustration derive reciprocal retail base power from friendship", friendshipDamage(971, 255) > friendshipDamage(971, 0) and friendshipDamage(970, 0) > friendshipDamage(970, 255))

local hiddenPowerMoves = {}
for k, v in pairs(Data.moves) do hiddenPowerMoves[k] = v end
hiddenPowerMoves[969] = {power=1,type=Data.TYPE_NORMAL,accuracy=100,priority=0,effect=BattleEngine.EFFECT_HIDDEN_POWER}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,ivs={hp=31,attack=31,defense=31,speed=31,spAttack=31,spDefense=31},stats=bulbaStats,types={Data.TYPE_NORMAL,Data.TYPE_NORMAL},moves={{move=969,pp=1}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types={Data.TYPE_PSYCHIC,Data.TYPE_PSYCHIC},moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=hiddenPowerMoves,typeChart=Data.typeChart,rng=scriptedRng({0, 1, 0}),
})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Hidden Power derives Dark type and 70 power from all-31 IVs", events[2].superEffective and events[2].amount > 1)

local curlMoves = {}
for k, v in pairs(Data.moves) do curlMoves[k] = v end
curlMoves[968] = {power=0,type=Data.TYPE_NORMAL,accuracy=0,priority=0,effect=BattleEngine.EFFECT_DEFENSE_CURL}
curlMoves[967] = {power=20,type=Data.TYPE_ROCK,accuracy=100,priority=0,effect=117}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=968,pp=1},{move=967,pp=1}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats={hp=99,attack=9,defense=9,speed=11,spAttack=11,spDefense=10},types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=curlMoves,typeChart=Data.typeChart,rng=scriptedRng({0, 1, 0, 0, 1, 0}),
})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
local curled = battle.player.defenseCurled and battle.player.statStages.defense == 7
battle:resolveMove(BattleEngine.SIDE_PLAYER, 2, events)
check("Defense Curl raises Defense and doubles the following Rollout base power", curled and events[#events].amount > 8)

local softboiledMoves = {}
for k, v in pairs(Data.moves) do softboiledMoves[k] = v end
softboiledMoves[966] = {power=0,type=Data.TYPE_NORMAL,accuracy=0,priority=0,effect=BattleEngine.EFFECT_SOFTBOILED}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,hp=1,types=Data.BULBASAUR.types,moves={{move=966,pp=1}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=softboiledMoves,typeChart=Data.typeChart,rng=scriptedRng({}),
})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Softboiled uses the retail half-max-HP battle heal", battle.player.hp == 10 and events[2].type == "heal")

local sleepMoves = {}
for k, v in pairs(Data.moves) do sleepMoves[k] = v end
sleepMoves[967] = {power=0,type=Data.TYPE_PSYCHIC,accuracy=100,priority=0,effect=BattleEngine.EFFECT_SLEEP}
battle = BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=967,pp=1}}}), foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}), moves=sleepMoves,typeChart=Data.typeChart,rng=scriptedRng({0, 3, 0, 1, 1})})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Sleep stores its retail two-to-five-turn counter in the Gen III status word", battle.foe.status == 5 and events[2].type == "sleep")

events = {}
battle:resolveMove(BattleEngine.SIDE_FOE, 1, events)
check("Sleeping battlers decrement their counter and do not spend PP", battle.foe.status == 4 and battle.foe.moves[1].pp == 1 and events[2].type == "asleep")

battle.foe.status = 1
events = {}
battle:resolveMove(BattleEngine.SIDE_FOE, 1, events)
check("A battler that wakes this turn proceeds with its selected move", battle.foe.status == 0 and battle.foe.moves[1].pp == 0 and events[2].type == "wokeUp")

local restMoves = {}
for k, v in pairs(Data.moves) do restMoves[k] = v end
restMoves[953] = {power=0,type=Data.TYPE_PSYCHIC,accuracy=0,priority=0,effect=BattleEngine.EFFECT_REST}
battle = BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,hp=4,status=8,types=Data.BULBASAUR.types,moves={{move=953,pp=1}}}), foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}), moves=restMoves,typeChart=Data.typeChart,rng=scriptedRng({})})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Rest fully heals, clears status, and applies fixed three-turn sleep", battle.player.hp == battle.player.maxHP and battle.player.status == 3 and battle.player.moves[1].pp == 0 and events[2].type == "rest")

battle.player.hp = battle.player.maxHP
battle.player.status = 0
battle.player.moves[1].pp = 1
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Rest fails at full HP after PP reduction", battle.player.moves[1].pp == 0 and events[2].type == "restFailed")

local yawnMoves = {}
for k, v in pairs(Data.moves) do yawnMoves[k] = v end
yawnMoves[952] = {power=0,type=Data.TYPE_NORMAL,accuracy=100,priority=0,effect=BattleEngine.EFFECT_YAWN}
battle = BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=952,pp=1}}}), foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}), moves=yawnMoves,typeChart=Data.typeChart,rng=scriptedRng({3})})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
local yawning = battle.foe.yawnTurns == 2 and battle.player.moves[1].pp == 0 and events[2].type == "yawn"
battle:finishTurn(events)
local firstYawnTurn = battle.foe.yawnTurns == 1 and battle.foe.status == 0
battle:finishTurn(events)
check("Yawn delays sleep one end turn then applies canonical two-to-five-turn sleep", yawning and firstYawnTurn and battle.foe.yawnTurns == 0 and battle.foe.status == 5 and events[#events].type == "yawnSleep")

local leechSeedMoves = {}
for k, v in pairs(Data.moves) do leechSeedMoves[k] = v end
leechSeedMoves[951] = {power=0,type=Data.TYPE_GRASS,accuracy=100,priority=0,effect=BattleEngine.EFFECT_LEECH_SEED}
battle = BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,hp=10,types=Data.BULBASAUR.types,moves={{move=951,pp=1}}}), foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}), moves=leechSeedMoves,typeChart=Data.typeChart,rng=scriptedRng({0})})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
local seeded = battle.foe.leechSeededBy == BattleEngine.SIDE_PLAYER and events[2].type == "leechSeed"
battle:finishTurn(events)
check("Leech Seed drains one eighth target max HP and heals its seeder by actual damage", seeded and battle.foe.hp == charStats.hp - 2 and battle.player.hp == 12 and events[#events].type == "leechSeedDrain")

local ingrainMoves = {}
for k, v in pairs(Data.moves) do ingrainMoves[k] = v end
ingrainMoves[949] = {power=0,type=Data.TYPE_GRASS,accuracy=0,priority=0,effect=BattleEngine.EFFECT_INGRAIN}
battle = BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,hp=1,types=Data.BULBASAUR.types,moves={{move=949,pp=1}}}), foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}), moves=ingrainMoves,typeChart=Data.typeChart,rng=scriptedRng({})})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
local ingrained = battle.player.rooted and battle.player.moves[1].pp == 0 and events[2].type == "ingrain"
battle:finishTurn(events)
check("Ingrain roots its user and heals one sixteenth max HP each turn", ingrained and battle.player.hp == 2 and events[#events].type == "ingrainHeal")

local replacement = BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}})
events = battle:runTurn({action="switch",battler=replacement}, {action="move",moveSlot=1})
check("Rooted battlers cannot voluntarily switch", battle.player.species == 1 and events[2].type == "switchFailed")

local refreshMoves = {}
for k, v in pairs(Data.moves) do refreshMoves[k] = v end
refreshMoves[950] = {power=0,type=Data.TYPE_NORMAL,accuracy=0,priority=0,effect=BattleEngine.EFFECT_REFRESH}
battle = BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,status=128 + 512,types=Data.BULBASAUR.types,moves={{move=950,pp=1}}}), foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}), moves=refreshMoves,typeChart=Data.typeChart,rng=scriptedRng({})})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Refresh clears poison, burn, paralysis, and Toxic's embedded counter", battle.player.status == 0 and battle.player.moves[1].pp == 0 and events[2].type == "refresh")

battle.player.moves[1].pp = 1
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Refresh fails without a curable nonvolatile status after PP reduction", battle.player.moves[1].pp == 0 and events[2].type == "refreshFailed")

local confuseMoves = {}
for k, v in pairs(Data.moves) do confuseMoves[k] = v end
confuseMoves[956] = {power=0,type=Data.TYPE_NORMAL,accuracy=100,priority=0,effect=BattleEngine.EFFECT_CONFUSE}
battle = BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=956,pp=1}}}), foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}), moves=confuseMoves,typeChart=Data.typeChart,rng=scriptedRng({0, 3, 0, 1})})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Confuse stores its retail two-to-five-turn volatile counter", battle.foe.confusionTurns == 5 and events[2].type == "confuse")

battle.foe.confusionTurns = 2
events = {}
battle:resolveMove(BattleEngine.SIDE_FOE, 1, events)
check("Confusion can self-hit after decrementing and without spending PP", battle.foe.confusionTurns == 1 and battle.foe.moves[1].pp == 1 and events[2].type == "confusionSelfHit" and events[2].amount > 0)

battle.foe.confusionTurns = 1
events = {}
battle:resolveMove(BattleEngine.SIDE_FOE, 1, events)
check("A battler snapping out of confusion proceeds normally", battle.foe.confusionTurns == 0 and battle.foe.moves[1].pp == 0 and events[2].type == "snappedOut")

confuseMoves[955] = {power=40,type=Data.TYPE_NORMAL,accuracy=100,priority=0,effect=BattleEngine.EFFECT_CONFUSE_HIT,secondaryEffectChance=100}
battle = BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=955,pp=1}}}), foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}), moves=confuseMoves,typeChart=Data.typeChart,rng=scriptedRng({0, 1, 1, 0, 3})})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Confuse-hit moves apply their post-hit chance effect", battle.foe.confusionTurns == 5 and events[#events].type == "confuse")

local flinchMoves = {}
for k, v in pairs(Data.moves) do flinchMoves[k] = v end
flinchMoves[954] = {power=40,type=Data.TYPE_DARK,accuracy=100,priority=0,effect=BattleEngine.EFFECT_FLINCH_HIT,secondaryEffectChance=100}
battle = BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}), foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=954,pp=1}}}), moves=flinchMoves,typeChart=Data.typeChart,rng=scriptedRng({0, 1, 1, 0})})
events = battle:runTurn({action="move",moveSlot=1}, {action="move",moveSlot=1})
local playerFlinched = false
for _, event in ipairs(events) do playerFlinched = playerFlinched or event.type == "flinched" and event.side == BattleEngine.SIDE_PLAYER end
check("A faster flinch-hit move cancels the target's pending action without PP", battle.player.moves[1].pp == 1 and playerFlinched)

battle = BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=954,pp=1}}}), foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}), moves=flinchMoves,typeChart=Data.typeChart,rng=scriptedRng({0, 1, 1, 0})})
events = battle:runTurn({action="move",moveSlot=1}, {action="move",moveSlot=1})
local foeFlinched = false
for _, event in ipairs(events) do foeFlinched = foeFlinched or event.type == "flinched" end
check("Flinch does not carry into a target that already acted this turn", battle.foe.moves[1].pp == 0 and not foeFlinched)

local poisonMoves = {}
for k, v in pairs(Data.moves) do poisonMoves[k] = v end
poisonMoves[965] = {power=0,type=Data.TYPE_POISON,accuracy=100,priority=0,effect=BattleEngine.EFFECT_POISON}
battle = BattleEngine.new({
  player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=965,pp=1}}}),
  foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}),
  moves=poisonMoves,typeChart=Data.typeChart,rng=scriptedRng({0}),
})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
local poisoned = battle.foe.status == 8 and events[2].type == "poison"
battle:finishTurn(events)
check("Poison sets the Gen III status bit and removes one eighth max HP at turn end", poisoned and battle.foe.hp == charStats.hp - 2 and events[#events].type == "poisonDamage")

local paralyzed = BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={}})
paralyzed.status = 64
check("Paralysis quarters effective Speed for turn ordering", BattleFormulas.effectiveSpeed(paralyzed) == math.floor(bulbaStats.speed / 4))

paralyzed.moves = {{move=Data.MOVE_TACKLE, pp=1}}
battle = BattleEngine.new({player=paralyzed, foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}), moves=Data.moves,typeChart=Data.typeChart,rng=scriptedRng({0})})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Full paralysis cancels before PP deduction", events[2].type == "fullyParalyzed" and battle.player.moves[1].pp == 1)

local paralyzeMoves = {}
for k, v in pairs(Data.moves) do paralyzeMoves[k] = v end
paralyzeMoves[964] = {power=0,type=Data.TYPE_NORMAL,accuracy=100,priority=0,effect=BattleEngine.EFFECT_PARALYZE}
battle = BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=964,pp=1}}}), foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}), moves=paralyzeMoves,typeChart=Data.typeChart,rng=scriptedRng({0})})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Paralyze sets the Gen III paralysis status bit", battle.foe.status == 64 and events[2].type == "paralyze")

paralyzeMoves[961] = {power=0,type=Data.TYPE_ELECTRIC,accuracy=100,priority=0,effect=BattleEngine.EFFECT_PARALYZE}
battle = BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=961,pp=1}}}), foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types={Data.TYPE_GROUND},moves={{move=Data.MOVE_TACKLE,pp=1}}}), moves=paralyzeMoves,typeChart=Data.typeChart,rng=scriptedRng({})})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Paralyze honors Ground's Electric immunity after PP deduction", battle.foe.status == 0 and battle.player.moves[1].pp == 0 and events[2].type == "noEffect")

local burnMoves = {}
for k, v in pairs(Data.moves) do burnMoves[k] = v end
burnMoves[963] = {power=0,type=Data.TYPE_FIRE,accuracy=100,priority=0,effect=BattleEngine.EFFECT_WILL_O_WISP}
battle = BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=963,pp=1}}}), foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.BULBASAUR.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}), moves=burnMoves,typeChart=Data.typeChart,rng=scriptedRng({0})})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
local burned = battle.foe.status == 16 and events[2].type == "burn"
battle:finishTurn(events)
check("Will-O-Wisp applies burn and burn deals one eighth max HP at turn end", burned and battle.foe.hp == charStats.hp - 2 and events[#events].type == "burnDamage")

local statusHitMoves = {}
for k, v in pairs(Data.moves) do statusHitMoves[k] = v end
statusHitMoves[959] = {power=40,type=Data.TYPE_POISON,accuracy=100,priority=0,effect=BattleEngine.EFFECT_POISON_HIT,secondaryEffectChance=100}
battle = BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=959,pp=1}}}), foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}), moves=statusHitMoves,typeChart=Data.typeChart,rng=scriptedRng({0, 1, 1, 0})})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Poison-hit moves use their normal post-hit secondary roll", battle.foe.status == 8 and events[#events].type == "poison")

statusHitMoves[958] = {power=40,type=Data.TYPE_FIRE,accuracy=100,priority=0,effect=BattleEngine.EFFECT_BURN_HIT,secondaryEffectChance=100}
battle = BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=958,pp=1}}}), foe=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}), moves=statusHitMoves,typeChart=Data.typeChart,rng=scriptedRng({0, 1, 1, 0})})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Burn-hit moves use their normal post-hit secondary roll", battle.foe.status == 16 and events[#events].type == "burn")

statusHitMoves[957] = {power=40,type=Data.TYPE_ELECTRIC,accuracy=100,priority=0,effect=BattleEngine.EFFECT_PARALYZE_HIT,secondaryEffectChance=100}
battle = BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=957,pp=1}}}), foe=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}), moves=statusHitMoves,typeChart=Data.typeChart,rng=scriptedRng({0, 1, 1, 0})})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Paralyze-hit moves use their normal post-hit secondary roll", battle.foe.status == 64 and events[#events].type == "paralyze")

local toxicMoves = {}
for k, v in pairs(Data.moves) do toxicMoves[k] = v end
toxicMoves[962] = {power=0,type=Data.TYPE_POISON,accuracy=100,priority=0,effect=BattleEngine.EFFECT_TOXIC}
battle = BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=962,pp=1}}}), foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}), moves=toxicMoves,typeChart=Data.typeChart,rng=scriptedRng({0})})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
battle:finishTurn(events)
local firstToxicDamage = charStats.hp - battle.foe.hp
battle:finishTurn(events)
check("Toxic starts at one sixteenth max HP and escalates each turn", firstToxicDamage == 1 and charStats.hp - battle.foe.hp == 3 and events[#events].counter == 2)

local freezeMoves = {}
for k, v in pairs(Data.moves) do freezeMoves[k] = v end
freezeMoves[960] = {power=40,type=Data.TYPE_ICE,accuracy=100,priority=0,effect=BattleEngine.EFFECT_FREEZE_HIT,secondaryEffectChance=100}
battle = BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=960,pp=1}}}), foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}), moves=freezeMoves,typeChart=Data.typeChart,rng=scriptedRng({0, 1, 1, 0})})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Freeze-hit moves apply freeze after an effective landed hit", battle.foe.status == 32 and events[#events].type == "freeze")

battle.foe.moves = {{move=Data.MOVE_TACKLE,pp=1}}
events = {}
battle:resolveMove(BattleEngine.SIDE_FOE, 1, events)
check("Frozen battlers thaw on the retail 20% roll before moving", battle.foe.status == 0 and battle.foe.moves[1].pp == 0 and events[2].type == "thawed")

-- Substitute owns a separate quarter-max-HP decoy. Incoming damage drains
-- that pool first and cannot spill through on the same hit; a modded move
-- may explicitly bypass it with the declarative ignoresSubstitute flag.
local substituteMoves = {}
for k, v in pairs(Data.moves) do substituteMoves[k] = v end
substituteMoves[956] = {power=0,type=Data.TYPE_NORMAL,accuracy=100,priority=0,effect=BattleEngine.EFFECT_SUBSTITUTE}
battle = BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=956,pp=1}}}), foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}), moves=substituteMoves,typeChart=Data.typeChart,rng=scriptedRng({})})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Substitute costs exactly one quarter max HP and creates matching decoy HP", battle.player.hp == 15 and battle.player.substituteHP == 4 and events[2].type == "substituteSet")
events = {}
battle:resolveMove(BattleEngine.SIDE_FOE, 1, events)
check("damage to Substitute never spills into the user's HP on its breaking hit", battle.player.hp == 15 and battle.player.substituteHP == 0 and events[3].type == "substituteDamage" and events[4].type == "substituteBroken")

substituteMoves[955] = {power=40,type=Data.TYPE_NORMAL,accuracy=100,priority=0,ignoresSubstitute=true}
battle = BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,substituteHP=4,moves={{move=Data.MOVE_TACKLE,pp=1}}}), foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=955,pp=1}}}), moves=substituteMoves,typeChart=Data.typeChart,rng=scriptedRng({0,1,0})})
events = {}
battle:resolveMove(BattleEngine.SIDE_FOE, 1, events)
check("ignoresSubstitute is a data-driven bypass hook for modded moves", battle.player.hp < bulbaStats.hp and battle.player.substituteHP == 4 and events[#events].type == "damage")

battle = BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,hp=4,moves={{move=956,pp=1}}}), foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}), moves=substituteMoves,typeChart=Data.typeChart,rng=scriptedRng({})})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Substitute fails at or below its quarter-max-HP cost", battle.player.hp == 4 and battle.player.substituteHP == 0 and events[2].type == "substituteFailed")

battle = BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=Data.MOVE_GROWL,pp=1}}}), foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,substituteHP=4,moves={{move=Data.MOVE_TACKLE,pp=1}}}), moves=substituteMoves,typeChart=Data.typeChart,rng=scriptedRng({0})})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Substitute blocks a target stat-stage move after its normal accuracy and PP steps", battle.foe.statStages.attack == 6 and battle.player.moves[1].pp == 0 and events[2].type == "substituteBlocked")

substituteMoves[954] = {power=0,type=Data.TYPE_POISON,accuracy=100,priority=0,effect=BattleEngine.EFFECT_POISON}
battle = BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=954,pp=1}}}), foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,substituteHP=4,moves={{move=Data.MOVE_TACKLE,pp=1}}}), moves=substituteMoves,typeChart=Data.typeChart,rng=scriptedRng({0})})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Substitute blocks target primary status moves", battle.foe.status == 0 and events[2].type == "substituteBlocked")

substituteMoves[953] = {power=40,type=Data.TYPE_POISON,accuracy=100,priority=0,effect=BattleEngine.EFFECT_POISON_HIT,secondaryEffectChance=100}
battle = BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=953,pp=1}}}), foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,substituteHP=20,moves={{move=Data.MOVE_TACKLE,pp=1}}}), moves=substituteMoves,typeChart=Data.typeChart,rng=scriptedRng({0,1,0,0})})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Substitute absorbs a damaging move's secondary status effect too", battle.foe.status == 0 and battle.foe.substituteHP < 20)

substituteMoves[952] = {power=0,type=Data.TYPE_NORMAL,accuracy=100,priority=0,effect=BattleEngine.EFFECT_TRANSFORM}
battle = BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=952,pp=1}}}), foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}), moves=substituteMoves,typeChart=Data.typeChart,rng=scriptedRng({})})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Transform copies the target's active battle stats, types, and species while retaining user HP and level", battle.player.transformed and battle.player.species == 4 and battle.player.attack == battle.foe.attack and battle.player.types[1] == battle.foe.types[1] and battle.player.hp == bulbaStats.hp and battle.player.level == 5 and events[2].type == "transform")
check("Transform copies target moves at the real capped five PP", battle.player.moves[1].move == Data.MOVE_TACKLE and battle.player.moves[1].pp == 5)

battle.foe.transformed = true
battle.player.moves = {{move=952,pp=1}}
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Transform fails against an already-transformed target after PP reduction", battle.player.moves[1].pp == 0 and events[2].type == "transformFailed")

substituteMoves[951] = {power=40,type=Data.TYPE_NORMAL,accuracy=100,priority=0,effect=BattleEngine.EFFECT_PAY_DAY}
battle = BattleEngine.new({player=BattleEngine.makeBattler({species=1,level=5,stats=bulbaStats,types=Data.BULBASAUR.types,moves={{move=951,pp=2}}}), foe=BattleEngine.makeBattler({species=4,level=5,stats=charStats,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=1}}}), moves=substituteMoves,typeChart=Data.typeChart,rng=scriptedRng({0,1,0})})
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Pay Day accrues five times the player's level before the hit path", battle.paydayMoney == 25 and events[1].type == "payDaySet")
battle.paydayMoney = 0xFFF0
events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("Pay Day's real u16 overflow behavior saturates at 0xFFFF", battle.paydayMoney == 0xFFFF)

-- Optional ROM check: exact real parser output equals the no-ROM fixture.
local romPath = os.getenv("POKEPORT_ROM")
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
