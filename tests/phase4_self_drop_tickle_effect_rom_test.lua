-- Accepted c75f352 source records; no extracted data is retained.
-- Effects 182 Superpower, 204 Overheat/Psycho Boost, 205 Tickle.
package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path = os.getenv("POKEPORT_ROM")
if not path then print("SKIP phase4_self_drop_tickle_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
assert(RomImporter.verify(path), "supported-ROM verification failed")
local f = assert(io.open(path, "rb"), "verified ROM could not be opened")
local rom = f:read("*a"); f:close()
local a = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, a.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
rom = nil
-- id -> effect, power, type, accuracy, pp, secondaryEffectChance, flags;
-- all target MOVE_TARGET_SELECTED (0), priority 0 (src/data/battle_moves.h).
local expected = {
  [276] = {182, 120, 1, 100, 5, 0, 0x13},   -- Superpower
  [315] = {204, 140, 10, 90, 5, 100, 0x33}, -- Overheat
  [354] = {204, 140, 14, 90, 5, 100, 0x32}, -- Psycho Boost
  [321] = {205, 0, 0, 100, 20, 0, 0x36},    -- Tickle
}
local effects = {[182]=true, [204]=true, [205]=true}
local count = 0
for id=0,RomAddresses.COUNTS.MOVES_COUNT-1 do
  if effects[moves[id].effect] then
    assert(expected[id], "unexpected self-drop/Tickle family member"); count = count + 1
  end
end
assert(count == 4, "self-drop/Tickle family membership count changed")
for id, e in pairs(expected) do
  local m = moves[id]
  assert(m.effect==e[1] and m.power==e[2] and m.type==e[3] and m.accuracy==e[4]
    and m.pp==e[5] and m.secondaryEffectChance==e[6] and m.flags==e[7]
    and m.target==0 and m.priority==0, "self-drop/Tickle source record mismatch")
end
print("phase4_self_drop_tickle_effect_rom_test: 5 passed, 0 failed; exact four-member source families")
