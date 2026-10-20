-- Accepted c75f352 source records; no extracted data is retained.
-- Protection slice P4: effect 158 EFFECT_FAKE_OUT (Fake Out).
package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path = os.getenv("POKEPORT_ROM")
if not path or path == "" then print("SKIP phase4_protection_p4_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
assert(RomImporter.verify(path), "supported-ROM verification failed")
local f = assert(io.open(path, "rb"), "verified ROM could not be opened")
local rom = f:read("*a"); f:close()
local a = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, a.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
rom = nil
-- src/data/battle_moves.h:3279-3290: Fake Out 252, power 40, Normal (0),
-- accuracy 100, PP 10, chance 0, MOVE_TARGET_SELECTED, priority +1, flags
-- FLAG_PROTECT_AFFECTED | FLAG_MIRROR_MOVE_AFFECTED = 0x02 | 0x10
-- (include/constants/pokemon.h:239, :242).
local count = 0
for id=0,RomAddresses.COUNTS.MOVES_COUNT-1 do
  if moves[id].effect == 158 then
    assert(id == 252, "unexpected P4 family member"); count = count + 1
  end
end
assert(count == 1, "P4 family membership count changed")
local m = moves[252]
assert(m.effect==158 and m.power==40 and m.type==0 and m.accuracy==100 and m.pp==10
  and m.secondaryEffectChance==0 and m.target==0 and m.priority==1 and m.flags==0x12,
  "P4 source record mismatch")
print("phase4_protection_p4_effect_rom_test: 2 passed, 0 failed; exact 1-member source family")
