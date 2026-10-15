-- Accepted c75f352 source records; no extracted data is retained.
-- Weather slice W1: effects 115 Sandstorm, 136 Rain Dance, 137 Sunny Day,
-- 164 Hail, plus Solar Beam (move id 76, the CalculateBaseDamage halving).
package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path = os.getenv("POKEPORT_ROM")
if not path or path == "" then print("SKIP phase4_weather_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
assert(RomImporter.verify(path), "supported-ROM verification failed")
local f = assert(io.open(path, "rb"), "verified ROM could not be opened")
local rom = f:read("*a"); f:close()
local a = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, a.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
rom = nil
-- id -> effect, power, type, accuracy, pp, secondaryEffectChance, target,
-- flags (src/data/battle_moves.h:2616, :3123, :3136, :3357, :991); every
-- priority is 0.
local expected = {
  [201] = {115, 0, 5, 0, 10, 0, 0x10, 0x00},     -- Sandstorm
  [240] = {136, 0, 11, 0, 5, 0, 0x10, 0x00},     -- Rain Dance
  [241] = {137, 0, 10, 0, 5, 0, 0x10, 0x00},     -- Sunny Day
  [258] = {164, 0, 15, 0, 10, 0, 0x10, 0x02},    -- Hail
  [76] = {151, 120, 12, 100, 10, 0, 0x00, 0x32}, -- Solar Beam
}
local effects = {[115]=true, [136]=true, [137]=true, [164]=true, [151]=true}
local count = 0
for id=0,RomAddresses.COUNTS.MOVES_COUNT-1 do
  if effects[moves[id].effect] then
    assert(expected[id], "unexpected W1 family member"); count = count + 1
  end
end
assert(count == 5, "W1 family membership count changed")
for id, e in pairs(expected) do
  local m = moves[id]
  assert(m.effect==e[1] and m.power==e[2] and m.type==e[3] and m.accuracy==e[4]
    and m.pp==e[5] and m.secondaryEffectChance==e[6] and m.target==e[7]
    and m.flags==e[8] and m.priority==0, "W1 source record mismatch")
end
print("phase4_weather_effect_rom_test: 2 passed, 0 failed; exact 5-member source families")
