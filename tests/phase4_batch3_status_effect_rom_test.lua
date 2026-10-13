-- Accepted c75f352 source records; no extracted data is retained.
-- Effects 25 Haze, 85 Splash, 142 Belly Drum, 143 Psych Up, 157 Softboiled.
package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path = os.getenv("POKEPORT_ROM")
if not path then print("SKIP phase4_batch3_status_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
assert(RomImporter.verify(path), "supported-ROM verification failed")
local f = assert(io.open(path, "rb"), "verified ROM could not be opened")
local rom = f:read("*a"); f:close()
local a = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, a.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
rom = nil
-- id -> effect, type, accuracy, pp, target, flags (src/data/battle_moves.h);
-- all power 0, secondaryEffectChance 0, priority 0.
local expected = {
  [114] = {25, 15, 0, 30, 0x10, 0x02},   -- Haze
  [150] = {85, 0, 0, 40, 0x10, 0x00},    -- Splash
  [187] = {142, 0, 0, 10, 0x10, 0x08},   -- Belly Drum
  [244] = {143, 0, 0, 10, 0x00, 0x08},   -- Psych Up
  [135] = {157, 0, 100, 10, 0x10, 0x18}, -- Soft-Boiled
  [208] = {157, 0, 0, 10, 0x10, 0x0A},   -- Milk Drink
}
local effects = {[25]=true, [85]=true, [142]=true, [143]=true, [157]=true}
local count = 0
for id=0,RomAddresses.COUNTS.MOVES_COUNT-1 do
  if effects[moves[id].effect] then
    assert(expected[id], "unexpected batch-3 family member"); count = count + 1
  end
end
assert(count == 6, "batch-3 family membership count changed")
for id, e in pairs(expected) do
  local m = moves[id]
  assert(m.effect==e[1] and m.type==e[2] and m.accuracy==e[3] and m.pp==e[4]
    and m.target==e[5] and m.flags==e[6] and m.power==0
    and m.secondaryEffectChance==0 and m.priority==0, "batch-3 source record mismatch")
end
print("phase4_batch3_status_effect_rom_test: 7 passed, 0 failed; exact six-member source families")
