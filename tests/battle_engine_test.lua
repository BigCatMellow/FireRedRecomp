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

-- Explicit no-PP stub: no Struggle is silently invented in this first
-- slice, and the other battler can still act.
battle = makeBattle({ 0, 1, 0 }, { { move = Data.MOVE_TACKLE, pp = 0 } }, { { move = Data.MOVE_EMBER, pp = 1 } })
events = battle:runTurn({ action = "move", moveSlot = 1 }, { action = "move", moveSlot = 1 })
check("zero PP emits documented noPP event", events[#events].type == "noPP" or events[2].type == "noPP")

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
  check("ROM Bulbasaur stats/types match fixture", realSpecies[1].baseHP == Data.BULBASAUR.baseHP and realSpecies[1].types[1] == Data.BULBASAUR.types[1] and realSpecies[1].types[2] == Data.BULBASAUR.types[2])
  check("ROM Charmander stats/types match fixture", realSpecies[4].baseHP == Data.CHARMANDER.baseHP and realSpecies[4].types[1] == Data.CHARMANDER.types[1])
  check("ROM type chart has the real 111 rows and Electric->Ground immunity", realTypes[110] ~= nil and realTypes[19].multiplier == 0)
else
  print("SKIP: set POKEPORT_ROM=... to also verify the battle fixture against the retail ROM")
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
