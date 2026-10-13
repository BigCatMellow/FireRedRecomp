-- Accepted c75f352 source records; no extracted data is retained.
package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path = os.getenv("POKEPORT_ROM")
if not path then print("SKIP phase4_recoil_if_miss_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
local ok = RomImporter.verify(path)
assert(ok, "supported-ROM verification failed")
local f = io.open(path, "rb")
assert(f, "verified ROM could not be opened")
local rom = f:read("*a"); f:close()
local a = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, a.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
local expected = {[26]={70,95,25}, [136]={85,90,20}}
local count = 0
for id=0,RomAddresses.COUNTS.MOVES_COUNT-1 do
  if moves[id].effect == 45 then
    assert(expected[id], "unexpected effect-45 member"); count=count+1
  end
end
assert(count==2, "effect-45 membership count changed")
for id, fields in pairs(expected) do
  local m=moves[id]
  assert(m.effect==45 and m.power==fields[1] and m.type==1
    and m.accuracy==fields[2] and m.pp==fields[3]
    and m.secondaryEffectChance==0 and m.target==0 and m.priority==0
    and m.flags==0x33, "effect-45 source record mismatch")
end
print("phase4_recoil_if_miss_effect_rom_test: 3 passed, 0 failed; exact two-member source family")
