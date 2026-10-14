-- Accepted c75f352 source records; no extracted data is retained.
-- Multi-turn slice M3: effect 27 Rampage (Thrash, Petal Dance, Outrage).
package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path = os.getenv("POKEPORT_ROM")
if not path then print("SKIP phase4_rampage_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
assert(RomImporter.verify(path), "supported-ROM verification failed")
local f = assert(io.open(path, "rb"), "verified ROM could not be opened")
local rom = f:read("*a"); f:close()
local a = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, a.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
rom = nil
-- id -> effect, power, type, accuracy, pp, secondaryEffectChance, target,
-- flags (src/data/battle_moves.h:484-495, 1043-1054, 2603-2614); every
-- priority is 0. Target 0x04 is MOVE_TARGET_RANDOM.
local expected = {
  [37]  = {27, 90, 0, 100, 20, 100, 0x04, 0x33},  -- Thrash
  [80]  = {27, 70, 12, 100, 20, 100, 0x04, 0x33}, -- Petal Dance
  [200] = {27, 90, 16, 100, 15, 100, 0x04, 0x33}, -- Outrage
}
local count = 0
for id=0,RomAddresses.COUNTS.MOVES_COUNT-1 do
  if moves[id].effect == 27 then
    assert(expected[id], "unexpected rampage family member"); count = count + 1
  end
end
assert(count == 3, "rampage family membership count changed")
for id, e in pairs(expected) do
  local m = moves[id]
  assert(m.effect==e[1] and m.power==e[2] and m.type==e[3] and m.accuracy==e[4]
    and m.pp==e[5] and m.secondaryEffectChance==e[6] and m.target==e[7]
    and m.flags==e[8] and m.priority==0, "rampage source record mismatch")
end
print("phase4_rampage_effect_rom_test: 2 passed, 0 failed; exact 3-member source family")
