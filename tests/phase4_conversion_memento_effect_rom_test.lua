-- Accepted c75f352 source records; no extracted data is retained.
-- Effects 30 Conversion and 168 Memento.
package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path = os.getenv("POKEPORT_ROM")
if not path then print("SKIP phase4_conversion_memento_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
assert(RomImporter.verify(path), "supported-ROM verification failed")
local f = assert(io.open(path, "rb"), "verified ROM could not be opened")
local rom = f:read("*a"); f:close()
local a = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, a.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
rom = nil
-- id -> effect, type, accuracy, pp, target, flags (src/data/battle_moves.h:2083,3409);
-- both power 0, secondaryEffectChance 0, priority 0.
local expected = {
  [160] = {30, 0, 0, 30, 0x10, 0x00},     -- Conversion
  [262] = {168, 17, 100, 10, 0x00, 0x12}, -- Memento (PROTECT|MIRROR)
}
local effects = {[30]=true, [168]=true}
local count = 0
for id=0,RomAddresses.COUNTS.MOVES_COUNT-1 do
  if effects[moves[id].effect] then
    assert(expected[id], "unexpected batch-6 family member"); count = count + 1
  end
end
assert(count == 2, "batch-6 family membership count changed")
for id, e in pairs(expected) do
  local m = moves[id]
  assert(m.effect==e[1] and m.type==e[2] and m.accuracy==e[3] and m.pp==e[4]
    and m.target==e[5] and m.flags==e[6] and m.power==0
    and m.secondaryEffectChance==0 and m.priority==0, "batch-6 source record mismatch")
end
print("phase4_conversion_memento_effect_rom_test: 3 passed, 0 failed; exact two-member source families")
