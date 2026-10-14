-- Accepted c75f352 source records; no extracted data is retained.
-- Status-leftovers slice L2: effects 37 Rest, 47 Focus Energy.
package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path = os.getenv("POKEPORT_ROM")
if not path then print("SKIP phase4_status_leftovers_l2_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
assert(RomImporter.verify(path), "supported-ROM verification failed")
local f = assert(io.open(path, "rb"), "verified ROM could not be opened")
local rom = f:read("*a"); f:close()
local a = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, a.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
rom = nil
-- id -> effect, power, type, accuracy, pp, secondaryEffectChance, target,
-- flags (src/data/battle_moves.h:1511-1522, 2031-2042); every priority is 0.
-- Target 0x10 = MOVE_TARGET_USER; flags 0x08 = FLAG_SNATCH_AFFECTED.
local expected = {
  [116] = {47, 0, 0, 0, 30, 0, 0x10, 0x08},   -- Focus Energy (Normal)
  [156] = {37, 0, 14, 0, 10, 0, 0x10, 0x08},  -- Rest (Psychic)
}
local effects = { [37] = true, [47] = true }
local count = 0
for id=0,RomAddresses.COUNTS.MOVES_COUNT-1 do
  if effects[moves[id].effect] then
    assert(expected[id] and expected[id][1] == moves[id].effect, "unexpected L2 family member")
    count = count + 1
  end
end
assert(count == 2, "L2 family membership count changed")
for id, e in pairs(expected) do
  local m = moves[id]
  assert(m.effect==e[1] and m.power==e[2] and m.type==e[3] and m.accuracy==e[4]
    and m.pp==e[5] and m.secondaryEffectChance==e[6] and m.target==e[7]
    and m.flags==e[8] and m.priority==0, "L2 source record mismatch")
end
print("phase4_status_leftovers_l2_effect_rom_test: 2 passed, 0 failed; exact 2-member source families")
