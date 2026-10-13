-- Accepted c75f352 source records; no extracted data is retained.
-- Effects 206/208/211/212 (Cosmic Power, Bulk Up, Calm Mind, Dragon Dance).
package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path = os.getenv("POKEPORT_ROM")
if not path then print("SKIP phase4_dual_stat_up_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
assert(RomImporter.verify(path), "supported-ROM verification failed")
local f = assert(io.open(path, "rb"), "verified ROM could not be opened")
local rom = f:read("*a"); f:close()
local a = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, a.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
rom = nil
-- move id -> {effect, type}; all: power 0, accuracy 0, pp 20, target USER,
-- priority 0, FLAG_SNATCH_AFFECTED only.
local expected = {[322]={206,14}, [339]={208,1}, [347]={211,14}, [349]={212,16}}
local effects = {[206]=true, [208]=true, [211]=true, [212]=true}
local count = 0
for id=1,RomAddresses.COUNTS.MOVES_COUNT-1 do
  if effects[moves[id].effect] then
    assert(expected[id], "unexpected dual-stat family member"); count = count + 1
  end
end
assert(count == 4, "dual-stat family membership count changed")
for id, e in pairs(expected) do
  local m = moves[id]
  assert(m.effect==e[1] and m.type==e[2] and m.power==0 and m.accuracy==0
    and m.pp==20 and m.secondaryEffectChance==0 and m.target==0x10
    and m.priority==0 and m.flags==0x08, "dual-stat source record mismatch")
end
print("phase4_dual_stat_up_effect_rom_test: 5 passed, 0 failed; exact four-member source families")
