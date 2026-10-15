-- Accepted c75f352 source records; no extracted data is retained.
-- Residual slice R1: effects 84 Leech Seed, 107 Nightmare, 109 Curse and
-- 129 Rapid Spin (its seed arm).
package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path = os.getenv("POKEPORT_ROM")
if not path or path == "" then print("SKIP phase4_residual_r1_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
assert(RomImporter.verify(path), "supported-ROM verification failed")
local f = assert(io.open(path, "rb"), "verified ROM could not be opened")
local rom = f:read("*a"); f:close()
local a = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, a.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
rom = nil
-- id -> effect, power, type, accuracy, pp, secondaryEffectChance, target,
-- flags (src/data/battle_moves.h:952-963, :2226-2237, :2265-2276,
-- :2980-2991; FLAG_MAKES_CONTACT 0x01, PROTECT 0x02, MAGIC_COAT 0x04,
-- MIRROR_MOVE 0x10, KINGS_ROCK 0x20); every priority is 0.
local expected = {
  [73] = {84, 0, 12, 90, 10, 0, 0x00, 0x16},    -- Leech Seed (Grass)
  [171] = {107, 0, 7, 100, 15, 0, 0x00, 0x12},  -- Nightmare (Ghost)
  [174] = {109, 0, 9, 0, 10, 0, 0x00, 0x00},    -- Curse (Mystery)
  [229] = {129, 20, 0, 100, 40, 0, 0x00, 0x33}, -- Rapid Spin (Normal)
}
local effects = {[84]=true, [107]=true, [109]=true, [129]=true}
local count = 0
for id=0,RomAddresses.COUNTS.MOVES_COUNT-1 do
  if effects[moves[id].effect] then
    assert(expected[id], "unexpected R1 family member"); count = count + 1
  end
end
assert(count == 4, "R1 family membership count changed")
for id, e in pairs(expected) do
  local m = moves[id]
  assert(m.effect==e[1] and m.power==e[2] and m.type==e[3] and m.accuracy==e[4]
    and m.pp==e[5] and m.secondaryEffectChance==e[6] and m.target==e[7]
    and m.flags==e[8] and m.priority==0, "R1 source record mismatch")
end
print("phase4_residual_r1_effect_rom_test: 2 passed, 0 failed; exact 4-member source families")
