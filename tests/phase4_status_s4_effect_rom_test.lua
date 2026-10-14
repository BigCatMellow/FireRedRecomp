-- Accepted c75f352 source records; no extracted data is retained.
-- Status slice S4: effects 125 Thaw Hit, 169 Facade, 171 Smelling Salt,
-- 193 Refresh.
package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path = os.getenv("POKEPORT_ROM")
if not path then print("SKIP phase4_status_s4_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
assert(RomImporter.verify(path), "supported-ROM verification failed")
local f = assert(io.open(path, "rb"), "verified ROM could not be opened")
local rom = f:read("*a"); f:close()
local a = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, a.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
rom = nil
-- id -> effect, power, type, accuracy, pp, secondaryEffectChance, target,
-- flags (src/data/battle_moves.h); every priority is 0.
local expected = {
  [172] = {125, 60, 10, 100, 25, 10, 0x00, 0x13},  -- Flame Wheel
  [221] = {125, 100, 10, 95, 5, 50, 0x00, 0x12},   -- Sacred Fire
  [263] = {169, 70, 0, 100, 20, 0, 0x00, 0x13},    -- Facade
  [265] = {171, 60, 0, 100, 10, 0, 0x00, 0x13},    -- Smelling Salt
  [287] = {193, 0, 0, 100, 20, 0, 0x10, 0x08},     -- Refresh
}
local effects = {[125]=true, [169]=true, [171]=true, [193]=true}
local count = 0
for id=0,RomAddresses.COUNTS.MOVES_COUNT-1 do
  if effects[moves[id].effect] then
    assert(expected[id], "unexpected S4 family member"); count = count + 1
  end
end
assert(count == 5, "S4 family membership count changed")
for id, e in pairs(expected) do
  local m = moves[id]
  assert(m.effect==e[1] and m.power==e[2] and m.type==e[3] and m.accuracy==e[4]
    and m.pp==e[5] and m.secondaryEffectChance==e[6] and m.target==e[7]
    and m.flags==e[8] and m.priority==0, "S4 source record mismatch")
end
print("phase4_status_s4_effect_rom_test: 2 passed, 0 failed; exact 5-member source families")
