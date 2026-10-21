-- Accepted c75f352 source records; no extracted data is retained.
-- Variable-power slice V1: effect 122 EFFECT_PRESENT (Present).
package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path = os.getenv("POKEPORT_ROM")
if not path or path == "" then print("SKIP phase4_variable_power_v1_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
assert(RomImporter.verify(path), "supported-ROM verification failed")
local f = assert(io.open(path, "rb"), "verified ROM could not be opened")
local rom = f:read("*a"); f:close()
local a = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, a.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
rom = nil
-- src/data/battle_moves.h:2824-2835: Present 217, power 1, Normal (0),
-- accuracy 90, PP 15, chance 0, MOVE_TARGET_SELECTED, priority 0, flags
-- FLAG_PROTECT_AFFECTED | FLAG_MIRROR_MOVE_AFFECTED = 0x02 | 0x10
-- (include/constants/pokemon.h:238-243).
local count = 0
for id=0,RomAddresses.COUNTS.MOVES_COUNT-1 do
  if moves[id].effect == 122 then
    assert(id == 217, "unexpected V1 family member"); count = count + 1
  end
end
assert(count == 1, "V1 family membership count changed")
local m = moves[217]
assert(m.effect==122 and m.power==1 and m.type==0 and m.accuracy==90 and m.pp==15
  and m.secondaryEffectChance==0 and m.target==0 and m.priority==0 and m.flags==0x12,
  "V1 source record mismatch")
print("phase4_variable_power_v1_effect_rom_test: 2 passed, 0 failed; exact 1-member source family")
