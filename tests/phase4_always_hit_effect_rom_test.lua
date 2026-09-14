-- Run: POKEPORT_ROM=/path/to/verified/pokefirered.gba lua5.1 tests/phase4_always_hit_effect_rom_test.lua
-- Verify the six retail EFFECT_ALWAYS_HIT records and drive parsed Swift
-- through the pure engine. No ROM content is written or retained.
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
  print("SKIP phase4_always_hit_effect_rom_test (set POKEPORT_ROM)")
  os.exit(0)
end
local ok, info = RomImporter.verify(path)
if not ok then
  print("FAIL: ROM verification -- " .. tostring(info))
  os.exit(1)
end
local f = assert(io.open(path, "rb")); local rom = f:read("*a"); f:close()
local addrs = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
  end
end
local moves = BattleMove.parseTable(rom, addrs.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
local species = SpeciesInfo.parseTable(rom, addrs.gSpeciesInfo, RomAddresses.COUNTS.NUM_SPECIES)
local typeChart = TypeChart.parseTable(rom, addrs.gTypeEffectiveness)
local ids = { 129, 185, 325, 332, 345, 351 }
local expectedPower = { [129] = 60, [185] = 60, [325] = 60, [332] = 60, [345] = 60, [351] = 60 }
local recordsExact = true
local effect17Count = 0
for id = 1, RomAddresses.COUNTS.MOVES_COUNT - 1 do
  if moves[id].effect == 17 and moves[id].power > 0 then effect17Count = effect17Count + 1 end
end
for _, id in ipairs(ids) do
  local move = moves[id]
  recordsExact = recordsExact and move.effect == 17 and move.power == expectedPower[id]
    and move.accuracy == 0
end
check("ROM has exactly the six selected positive-power accuracy-zero effect-17 records",
  recordsExact and effect17Count == #ids, effect17Count)

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
local rng = scriptedRng({ 15, 0 }) -- would miss at accuracy 0 if ordinary check ran.
local battle = BattleEngine.new({
  player = BattleEngine.makeBattler({ species = 1, level = 20, stats = playerStats,
    types = species[1].types, moves = { { move = 129, pp = moves[129].pp } } }),
  foe = BattleEngine.makeBattler({ species = 4, level = 20, stats = foeStats,
    types = species[4].types, moves = { { move = 33, pp = moves[33].pp } } }),
  moves = moves, typeChart = typeChart, rng = rng,
})
local events = {}
battle:resolveMove(BattleEngine.SIDE_PLAYER, 1, events)
check("parsed Swift bypasses accuracy and still consumes PP", events[1].type == "useMove"
  and events[1].move == 129 and events[2].type == "damage" and battle.player.moves[1].pp == moves[129].pp - 1,
  events[2] and events[2].type)
check("parsed Swift preserves crit/random stream but consumes no accuracy draw", rng.draws == 2, rng.draws)

print(("phase4_always_hit_effect_rom_test: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
