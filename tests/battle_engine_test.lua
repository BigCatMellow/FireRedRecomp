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
  { 0, 1, 0, 0, 1, 0, 0, 1, 0 },
  { { move = Data.MOVE_TACKLE, pp = 35 } },
  { { move = Data.MOVE_EMBER, pp = 25 } }
)
local events = battle:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 })
check("faster foe uses Ember first", events[2].type == "useMove" and events[2].side == "foe")
check("Ember event reports real 14 damage", events[3].type == "damage" and events[3].amount == 14 and events[3].hpRemaining == 5, events[3] and events[3].amount)
check("player still gets its turn while alive", events[4].type == "useMove" and events[4].side == "player")
check("Tackle event reports real 4 damage", events[5].type == "damage" and events[5].amount == 4 and events[5].hpRemaining == 14, events[5] and events[5].amount)
check("both attacks used exactly six RNG draws", battle.rng.draws == 6, battle.rng.draws)
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

-- A Poke Ball is a B_ACTION_USE_ITEM, which SetActionsAndBattlersTurnOrder
-- places before move actions. Seeded/scripted capture rules consume their
-- shake draws from the same global RNG stream as the ensuing foe attack.
-- At full HP and catch rate 45, catch value=15 and threshold=32767: draw 0
-- passes (one shake), draw 65535 fails, then the foe's hit consumes its real
-- accuracy/crit/damage draws 0,1,0.
battle = makeBattle(
  { 0, 65535, 0, 1, 0 },
  { { move = Data.MOVE_TACKLE, pp = 1 } },
  { { move = Data.MOVE_EMBER, pp = 1 } },
  45
)
events = battle:runTurn({ action = "capture" }, { action = "move", moveSlot = 1 })
check("Poke Ball resolves before the foe move", events[2].type == "throwBall" and events[3].type == "capture")
check("failed capture exposes one source shake", events[3].success == false and events[3].shakes == 1, events[3].shakes)
check("foe attacks after failed capture", events[4].type == "useMove" and events[4].side == "foe")
check("capture failure and foe attack share exact RNG stream", battle.rng.draws == 5, battle.rng.draws)
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
battle = makeBattle({ 0, 1, 0 },
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
battle = makeBattle({ 0, 1, 0, 50 }, { { move = Data.MOVE_TACKLE, pp = 0 } }, { { move = Data.MOVE_EMBER, pp = 1 } })
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
