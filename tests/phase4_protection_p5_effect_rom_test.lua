-- Accepted c75f352 source records; no extracted data is retained.
-- Protection slice P5: effect 170 EFFECT_FOCUS_PUNCH (Focus Punch).
package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path = os.getenv("POKEPORT_ROM")
if not path or path == "" then print("SKIP phase4_protection_p5_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
assert(RomImporter.verify(path), "supported-ROM verification failed")
local f = assert(io.open(path, "rb"), "verified ROM could not be opened")
local rom = f:read("*a"); f:close()
local a = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, a.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
rom = nil
-- src/data/battle_moves.h:3435-3446: Focus Punch 264, power 150, Fighting
-- (1), accuracy 100, PP 20, chance 0, MOVE_TARGET_SELECTED, priority -3,
-- flags FLAG_MAKES_CONTACT | FLAG_PROTECT_AFFECTED = 0x01 | 0x02
-- (include/constants/pokemon.h:238-239).
local count = 0
for id=0,RomAddresses.COUNTS.MOVES_COUNT-1 do
  if moves[id].effect == 170 then
    assert(id == 264, "unexpected P5 family member"); count = count + 1
  end
end
assert(count == 1, "P5 family membership count changed")
local m = moves[264]
assert(m.effect==170 and m.power==150 and m.type==1 and m.accuracy==100 and m.pp==20
  and m.secondaryEffectChance==0 and m.target==0 and m.priority==-3 and m.flags==0x03,
  "P5 source record mismatch")
print("phase4_protection_p5_effect_rom_test: 2 passed, 0 failed; exact 1-member source family")
