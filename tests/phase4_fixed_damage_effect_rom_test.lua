-- Run: POKEPORT_ROM=/path/to/verified/pokefirered.gba lua5.1 tests/phase4_fixed_damage_effect_rom_test.lua
--
-- Ground the fixed-damage effect ids and the live-eligible NIKOLAS fixture
-- directly in the supported FireRed US v1.0 ROM, then drive the pure engine
-- with that parsed SonicBoom record. No ROM content is written or retained.
package.path = package.path .. ";./?.lua"

local BattleEngine = require("src.core.BattleEngine")
local BattleMove = require("import.BattleMove")
local Charmap = require("import.Charmap")
local PokemonStats = require("src.core.PokemonStats")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local SpeciesInfo = require("import.SpeciesInfo")
local Trainer = require("import.Trainer")
local TrainerParty = require("import.TrainerParty")
local TypeChart = require("import.TypeChart")

local path = os.getenv("POKEPORT_ROM")
if not path then
  print("SKIP phase4_fixed_damage_effect_rom_test (set POKEPORT_ROM)")
  os.exit(0)
end

local ok, info = RomImporter.verify(path)
if not ok then
  print("FAIL: ROM verification -- " .. tostring(info))
  os.exit(1)
end
local f = assert(io.open(path, "rb"))
local rom = f:read("*a")
f:close()
local addrs = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
  end
end

local moves = BattleMove.parseTable(rom, addrs.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
local species = SpeciesInfo.parseTable(rom, addrs.gSpeciesInfo, RomAddresses.COUNTS.NUM_SPECIES)
local trainers = Trainer.parseTable(rom, addrs.gTrainers, RomAddresses.COUNTS.NUM_TRAINERS)
local typeChart = TypeChart.parseTable(rom, addrs.gTypeEffectiveness)

-- Exact current ROM records: Dragon Rage #82, Night Shade #101 and
-- Seismic Toss #69 share the requested effect families, while SonicBoom #49
-- is the runnable trainer fixture below.
check("ROM fixed-damage move records retain effect, power, accuracy and PP",
  moves[82].effect == 41 and moves[82].power == 1 and moves[82].type == 16
    and moves[82].accuracy == 100 and moves[82].pp == 10
    and moves[101].effect == 87 and moves[101].power == 1 and moves[101].type == 7
    and moves[101].accuracy == 100 and moves[101].pp == 15
    and moves[69].effect == 87 and moves[69].power == 1 and moves[69].type == 1
    and moves[69].accuracy == 100 and moves[69].pp == 20
    and moves[49].effect == 130 and moves[49].power == 1 and moves[49].type == 0
    and moves[49].accuracy == 90 and moves[49].pp == 20)

local nikolas = trainers[204]
local nikolasParty = TrainerParty.resolve(nikolas, rom)
local first, second = nikolasParty[0], nikolasParty[1]
check("ROM trainer #204 is NIKOLAS with two no-item custom-moves Voltorb",
  Charmap.decode(nikolas.rawName) == "NIKOLAS" and nikolas.partyFlags == 1
    and nikolas.partySize == 2 and first.species == 100 and first.lvl == 29
    and second.species == 100 and second.lvl == 29)
check("NIKOLAS custom move slots expose SonicBoom in both live-eligible foes",
  first.moves[0] == 209 and first.moves[1] == 49 and first.moves[2] == 103 and first.moves[3] == 268
    and second.moves[0] == 209 and second.moves[1] == 49 and second.moves[2] == 103 and second.moves[3] == 268)

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
local playerStats = PokemonStats.calculateAll(species[1], 29, zero, zero, neutral)
local foeStats = PokemonStats.calculateAll(species[100], 29, zero, zero, neutral)
local rng = scriptedRng({ 0 }) -- passes SonicBoom's 90% accuracy; a crit would follow if requested.
local battle = BattleEngine.new({
  player = BattleEngine.makeBattler({ species = 1, level = 29, stats = playerStats,
    types = species[1].types, moves = { { move = 33, pp = moves[33].pp } } }),
  foe = BattleEngine.makeBattler({ species = first.species, level = first.lvl, stats = foeStats,
    types = species[first.species].types, moves = { { move = first.moves[1], pp = moves[first.moves[1]].pp } } }),
  moves = moves, typeChart = typeChart, rng = rng,
})
local startHP = battle.player.hp
local events = {}
battle:resolveMove(BattleEngine.SIDE_FOE, 1, events)
check("parsed NIKOLAS SonicBoom record drives the engine for fixed 20 damage",
  events[1].type == "useMove" and events[1].move == 49 and events[2].type == "damage"
    and events[2].amount == 20 and battle.player.hp == startHP - 20, events[2] and events[2].amount)
check("parsed SonicBoom path uses only accuracy RNG and no effectiveness presentation",
  #events == 2 and rng.draws == 1 and events[2].superEffective == false and events[2].notVeryEffective == false,
  rng.draws)

print(("phase4_fixed_damage_effect_rom_test: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
