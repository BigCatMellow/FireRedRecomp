-- Accepted c75f352 source records; no extracted data is retained.
-- Weather slice W2: effects 132 Morning Sun, 133 Synthesis, 134 Moonlight,
-- 152 Thunder and 203 Weather Ball (Solar Beam, effect 151, is pinned by
-- phase4_weather_effect_rom_test).
package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path = os.getenv("POKEPORT_ROM")
if not path or path == "" then print("SKIP phase4_weather_w2_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
assert(RomImporter.verify(path), "supported-ROM verification failed")
local f = assert(io.open(path, "rb"), "verified ROM could not be opened")
local rom = f:read("*a"); f:close()
local a = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, a.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
rom = nil
-- id -> effect, power, type, accuracy, pp, secondaryEffectChance, target,
-- flags (src/data/battle_moves.h:1134, :3045, :3058, :3071, :4046); every
-- priority is 0.
local expected = {
  [87] = {152, 120, 13, 70, 10, 30, 0x00, 0x12},  -- Thunder
  [234] = {132, 0, 0, 0, 5, 0, 0x10, 0x08},       -- Morning Sun
  [235] = {133, 0, 12, 0, 5, 0, 0x10, 0x08},      -- Synthesis
  [236] = {134, 0, 0, 0, 5, 0, 0x10, 0x08},       -- Moonlight
  [311] = {203, 50, 0, 100, 10, 0, 0x00, 0x32},   -- Weather Ball
}
local effects = {[132]=true, [133]=true, [134]=true, [152]=true, [203]=true}
local count = 0
for id=0,RomAddresses.COUNTS.MOVES_COUNT-1 do
  if effects[moves[id].effect] then
    assert(expected[id], "unexpected W2 family member"); count = count + 1
  end
end
assert(count == 5, "W2 family membership count changed")
for id, e in pairs(expected) do
  local m = moves[id]
  assert(m.effect==e[1] and m.power==e[2] and m.type==e[3] and m.accuracy==e[4]
    and m.pp==e[5] and m.secondaryEffectChance==e[6] and m.target==e[7]
    and m.flags==e[8] and m.priority==0, "W2 source record mismatch")
end
print("phase4_weather_w2_effect_rom_test: 2 passed, 0 failed; exact 5-member source families")
