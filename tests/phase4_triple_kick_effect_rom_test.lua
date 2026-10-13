-- Accepted c75f352 source records; no extracted data is retained.
-- Effect 104 Triple Kick.
package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path = os.getenv("POKEPORT_ROM")
if not path then print("SKIP phase4_triple_kick_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
assert(RomImporter.verify(path), "supported-ROM verification failed")
local f = assert(io.open(path, "rb"), "verified ROM could not be opened")
local rom = f:read("*a"); f:close()
local a = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, a.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
rom = nil
local count = 0
for id=0,RomAddresses.COUNTS.MOVES_COUNT-1 do
  if moves[id].effect == 104 then
    assert(id == 167, "unexpected Triple Kick family member"); count = count + 1
  end
end
assert(count == 1, "Triple Kick family membership count changed")
-- src/data/battle_moves.h:2174: power 10, FIGHTING, accuracy 90, pp 10,
-- selected target, CONTACT|PROTECT|MIRROR|KINGS_ROCK.
local m = moves[167]
assert(m.effect==104 and m.power==10 and m.type==1 and m.accuracy==90 and m.pp==10
  and m.secondaryEffectChance==0 and m.target==0 and m.priority==0 and m.flags==0x33,
  "Triple Kick source record mismatch")
print("phase4_triple_kick_effect_rom_test: 2 passed, 0 failed; exact one-member source family")
