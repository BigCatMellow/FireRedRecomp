-- Accepted c75f352 source records; no extracted data is retained.
-- Status-leftovers slice L1: effects 36 Tri Attack, 77 Twineedle,
-- 200 Blaze Kick.
package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path = os.getenv("POKEPORT_ROM")
if not path then print("SKIP phase4_status_leftovers_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
assert(RomImporter.verify(path), "supported-ROM verification failed")
local f = assert(io.open(path, "rb"), "verified ROM could not be opened")
local rom = f:read("*a"); f:close()
local a = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, a.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
rom = nil
-- id -> effect, power, type, accuracy, pp, secondaryEffectChance, target,
-- flags (src/data/battle_moves.h:536-547, 2096-2107, 3890-3901); every
-- priority is 0. Flags 0x12 = protect | mirror move; 0x13 adds contact.
local expected = {
  [41]  = {77, 25, 6, 100, 20, 20, 0x00, 0x12},   -- Twineedle (Bug)
  [161] = {36, 80, 0, 100, 10, 20, 0x00, 0x12},   -- Tri Attack (Normal)
  [299] = {200, 85, 10, 90, 10, 10, 0x00, 0x13},  -- Blaze Kick (Fire)
}
local effects = { [36] = true, [77] = true, [200] = true }
local count = 0
for id=0,RomAddresses.COUNTS.MOVES_COUNT-1 do
  if effects[moves[id].effect] then
    assert(expected[id] and expected[id][1] == moves[id].effect, "unexpected L1 family member")
    count = count + 1
  end
end
assert(count == 3, "L1 family membership count changed")
for id, e in pairs(expected) do
  local m = moves[id]
  assert(m.effect==e[1] and m.power==e[2] and m.type==e[3] and m.accuracy==e[4]
    and m.pp==e[5] and m.secondaryEffectChance==e[6] and m.target==e[7]
    and m.flags==e[8] and m.priority==0, "L1 source record mismatch")
end
print("phase4_status_leftovers_effect_rom_test: 2 passed, 0 failed; exact 3-member source families")
