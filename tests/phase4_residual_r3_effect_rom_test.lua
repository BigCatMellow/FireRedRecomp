-- Accepted c75f352 source records; no extracted data is retained.
-- Residual slice R3: effect 42 EFFECT_TRAP (Bind, Wrap, Fire Spin, Clamp,
-- Whirlpool, Sand Tomb).
package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path = os.getenv("POKEPORT_ROM")
if not path or path == "" then print("SKIP phase4_residual_r3_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
assert(RomImporter.verify(path), "supported-ROM verification failed")
local f = assert(io.open(path, "rb"), "verified ROM could not be opened")
local rom = f:read("*a"); f:close()
local a = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, a.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
rom = nil
-- id -> effect, power, type, accuracy, pp, secondaryEffectChance, target,
-- flags (src/data/battle_moves.h:263-274, :458-469, :1082-1093,
-- :1667-1678, :3253-3264, :4267-4278; FLAG_MAKES_CONTACT 0x01,
-- PROTECT_AFFECTED 0x02, MIRROR_MOVE_AFFECTED 0x10, KINGS_ROCK_AFFECTED
-- 0x20, include/constants/pokemon.h); every priority is 0, every target
-- MOVE_TARGET_SELECTED.
local expected = {
  [20] = {42, 15, 0, 75, 20, 100, 0x00, 0x33},   -- Bind (Normal)
  [35] = {42, 15, 0, 85, 20, 100, 0x00, 0x33},   -- Wrap (Normal)
  [83] = {42, 15, 10, 70, 15, 100, 0x00, 0x32},  -- Fire Spin (Fire)
  [128] = {42, 35, 11, 75, 10, 100, 0x00, 0x33}, -- Clamp (Water)
  [250] = {42, 15, 11, 70, 15, 100, 0x00, 0x32}, -- Whirlpool (Water)
  [328] = {42, 15, 4, 70, 15, 100, 0x00, 0x32},  -- Sand Tomb (Ground)
}
local count = 0
for id=0,RomAddresses.COUNTS.MOVES_COUNT-1 do
  if moves[id].effect == 42 then
    assert(expected[id], "unexpected R3 family member"); count = count + 1
  end
end
assert(count == 6, "R3 family membership count changed")
for id, e in pairs(expected) do
  local m = moves[id]
  assert(m.effect==e[1] and m.power==e[2] and m.type==e[3] and m.accuracy==e[4]
    and m.pp==e[5] and m.secondaryEffectChance==e[6] and m.target==e[7]
    and m.flags==e[8] and m.priority==0, "R3 source record mismatch")
end
print("phase4_residual_r3_effect_rom_test: 2 passed, 0 failed; exact 6-member source family")
