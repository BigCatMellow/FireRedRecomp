-- Accepted c75f352 source records; no extracted data is retained.
-- Residual slice R2: effects 106 Mean Look / Spider Web / Block and
-- 181 Ingrain.
package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path = os.getenv("POKEPORT_ROM")
if not path or path == "" then print("SKIP phase4_residual_r2_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
assert(RomImporter.verify(path), "supported-ROM verification failed")
local f = assert(io.open(path, "rb"), "verified ROM could not be opened")
local rom = f:read("*a"); f:close()
local a = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, a.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
rom = nil
-- id -> effect, power, type, accuracy, pp, secondaryEffectChance, target,
-- flags (src/data/battle_moves.h:2200-2211, :2759-2770, :4358-4369,
-- :3578-3589; FLAG_PROTECT_AFFECTED 0x02, MAGIC_COAT 0x04, SNATCH 0x08,
-- MIRROR_MOVE 0x10, include/constants/pokemon.h); every priority is 0.
local expected = {
  [169] = {106, 0, 6, 100, 10, 0, 0x00, 0x16},  -- Spider Web (Bug)
  [212] = {106, 0, 0, 100, 5, 0, 0x00, 0x16},   -- Mean Look (Normal)
  [335] = {106, 0, 0, 100, 5, 0, 0x00, 0x16},   -- Block (Normal)
  [275] = {181, 0, 12, 100, 20, 0, 0x10, 0x08}, -- Ingrain (Grass, MOVE_TARGET_USER)
}
local effects = {[106]=true, [181]=true}
local count = 0
for id=0,RomAddresses.COUNTS.MOVES_COUNT-1 do
  if effects[moves[id].effect] then
    assert(expected[id], "unexpected R2 family member"); count = count + 1
  end
end
assert(count == 4, "R2 family membership count changed")
for id, e in pairs(expected) do
  local m = moves[id]
  assert(m.effect==e[1] and m.power==e[2] and m.type==e[3] and m.accuracy==e[4]
    and m.pp==e[5] and m.secondaryEffectChance==e[6] and m.target==e[7]
    and m.flags==e[8] and m.priority==0, "R2 source record mismatch")
end
print("phase4_residual_r2_effect_rom_test: 2 passed, 0 failed; exact 4-member source families")
