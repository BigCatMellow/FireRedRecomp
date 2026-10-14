-- Accepted c75f352 source records; no extracted data is retained.
-- Multi-turn slice M1: effects 39 Razor Wind, 75 Sky Attack, 80 Recharge,
-- 145 Skull Bash, 151 Solar Beam.
package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path = os.getenv("POKEPORT_ROM")
if not path then print("SKIP phase4_multiturn_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
assert(RomImporter.verify(path), "supported-ROM verification failed")
local f = assert(io.open(path, "rb"), "verified ROM could not be opened")
local rom = f:read("*a"); f:close()
local a = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, a.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
rom = nil
-- id -> effect, power, type, accuracy, pp, secondaryEffectChance, target,
-- flags (src/data/battle_moves.h); every priority is 0.
local expected = {
  [13]  = {39, 80, 0, 100, 10, 0, 0x08, 0x32},    -- Razor Wind
  [63]  = {80, 150, 0, 90, 5, 0, 0x00, 0x32},     -- Hyper Beam
  [76]  = {151, 120, 12, 100, 10, 0, 0x00, 0x32}, -- Solar Beam
  [130] = {145, 100, 0, 100, 15, 0, 0x00, 0x33},  -- Skull Bash
  [143] = {75, 140, 2, 90, 5, 30, 0x00, 0x32},    -- Sky Attack
  [307] = {80, 150, 10, 90, 5, 0, 0x00, 0x32},    -- Blast Burn
  [308] = {80, 150, 11, 90, 5, 0, 0x00, 0x32},    -- Hydro Cannon
  [338] = {80, 150, 12, 90, 5, 0, 0x00, 0x32},    -- Frenzy Plant
}
local effects = {[39]=true, [75]=true, [80]=true, [145]=true, [151]=true}
local count = 0
for id=0,RomAddresses.COUNTS.MOVES_COUNT-1 do
  if effects[moves[id].effect] then
    assert(expected[id], "unexpected multi-turn family member"); count = count + 1
  end
end
assert(count == 8, "multi-turn family membership count changed")
for id, e in pairs(expected) do
  local m = moves[id]
  assert(m.effect==e[1] and m.power==e[2] and m.type==e[3] and m.accuracy==e[4]
    and m.pp==e[5] and m.secondaryEffectChance==e[6] and m.target==e[7]
    and m.flags==e[8] and m.priority==0, "multi-turn source record mismatch")
end
print("phase4_multiturn_effect_rom_test: 2 passed, 0 failed; exact 8-member source families")
