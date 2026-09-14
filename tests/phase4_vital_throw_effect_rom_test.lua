-- Run: POKEPORT_ROM=/path/to/verified/pokefirered.gba lua5.1 tests/phase4_vital_throw_effect_rom_test.lua
-- Verify Vital Throw's sole retail effect-78 record and drive it through the
-- pure engine. No ROM content is written or retained.
package.path = package.path .. ";./?.lua"

local BattleEngine = require("src.core.BattleEngine")
local BattleMove = require("import.BattleMove")
local PokemonStats = require("src.core.PokemonStats")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local SpeciesInfo = require("import.SpeciesInfo")
local TypeChart = require("import.TypeChart")

local path = os.getenv("POKEPORT_ROM")
if not path then
  print("SKIP phase4_vital_throw_effect_rom_test (set POKEPORT_ROM)")
  os.exit(0)
end
local ok, info = RomImporter.verify(path)
if not ok then
  print("FAIL: ROM verification -- " .. tostring(info))
  os.exit(1)
end
local f = assert(io.open(path, "rb")); local rom = f:read("*a"); f:close()
local addrs = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, addrs.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
local species = SpeciesInfo.parseTable(rom, addrs.gSpeciesInfo, RomAddresses.COUNTS.NUM_SPECIES)
local typeChart = TypeChart.parseTable(rom, addrs.gTypeEffectiveness)

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
  end
end
local count = 0
for id = 1, RomAddresses.COUNTS.MOVES_COUNT - 1 do
  if moves[id].effect == 78 and moves[id].power > 0 then count = count + 1 end
end
local move = moves[233]
check("ROM has only Vital Throw as a positive-power effect-78 record", count == 1
  and move.effect == 78 and move.power == 70 and move.accuracy == 100
  and move.pp == 10 and move.priority == -1, count)

local function scriptedRng(values)
  return { draws = 0, next16 = function(self)
    self.draws = self.draws + 1
    return values[self.draws] or 0
  end }
end
local zero = { hp = 0, attack = 0, defense = 0, speed = 0, spAttack = 0, spDefense = 0 }
local neutral = { attack = 0, defense = 0, speed = 0, spAttack = 0, spDefense = 0 }
local playerStats = PokemonStats.calculateAll(species[1], 20, zero, zero, neutral)
local foeStats = PokemonStats.calculateAll(species[4], 20, zero, zero, neutral)
local rng = scriptedRng({ 99, 0 }) -- would miss if the ordinary accuracy branch ran.
local battle = BattleEngine.new({
  player = BattleEngine.makeBattler({ species = 1, level = 20, stats = playerStats,
    types = species[1].types, moves = { { move = 233, pp = move.pp } } }),
  foe = BattleEngine.makeBattler({ species = 4, level = 20, stats = foeStats,
    types = species[4].types, moves = { { move = 33, pp = moves[33].pp } } }),
  moves = moves, typeChart = typeChart, rng = rng,
})
battle.player.statStages.accuracy = 0
battle.foe.statStages.evasion = 12
local events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("parsed Vital Throw bypasses accuracy and still consumes PP", events[1].type == "useMove"
  and events[1].move == 233 and events[2].type == "damage"
  and battle.player.moves[1].pp == move.pp - 1, events[2] and events[2].type)
check("parsed Vital Throw preserves crit/random stream but consumes no accuracy draw", rng.draws == 2, rng.draws)

print(("phase4_vital_throw_effect_rom_test: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
