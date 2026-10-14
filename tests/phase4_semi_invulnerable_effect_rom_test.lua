-- Accepted c75f352 source records; no extracted data is retained.
-- Multi-turn slice M2: effects 147 Earthquake, 149 Gust, 152 Thunder,
-- 155 Semi-Invulnerable, 207 Sky Uppercut.
package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path = os.getenv("POKEPORT_ROM")
if not path then print("SKIP phase4_semi_invulnerable_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
assert(RomImporter.verify(path), "supported-ROM verification failed")
local f = assert(io.open(path, "rb"), "verified ROM could not be opened")
local rom = f:read("*a"); f:close()
local a = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, a.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
rom = nil
-- id -> effect, power, type, accuracy, pp, secondaryEffectChance, target,
-- flags (src/data/battle_moves.h); every priority is 0.
local expected = {
  [16]  = {149, 40, 2, 100, 35, 0, 0x00, 0x32},   -- Gust
  [19]  = {155, 70, 2, 95, 15, 0, 0x00, 0x33},    -- Fly
  [87]  = {152, 120, 13, 70, 10, 30, 0x00, 0x12}, -- Thunder
  [89]  = {147, 100, 4, 100, 10, 0, 0x20, 0x32},  -- Earthquake
  [91]  = {155, 60, 4, 100, 10, 0, 0x00, 0x33},   -- Dig
  [291] = {155, 60, 11, 100, 10, 0, 0x00, 0x33},  -- Dive
  [327] = {207, 85, 1, 90, 15, 0, 0x00, 0x33},    -- Sky Uppercut
  [340] = {155, 85, 2, 85, 5, 30, 0x00, 0x33},    -- Bounce
}
local effects = {[147]=true, [149]=true, [152]=true, [155]=true, [207]=true}
local count = 0
for id=0,RomAddresses.COUNTS.MOVES_COUNT-1 do
  if effects[moves[id].effect] then
    assert(expected[id], "unexpected semi-invulnerable family member"); count = count + 1
  end
end
assert(count == 8, "semi-invulnerable family membership count changed")
for id, e in pairs(expected) do
  local m = moves[id]
  assert(m.effect==e[1] and m.power==e[2] and m.type==e[3] and m.accuracy==e[4]
    and m.pp==e[5] and m.secondaryEffectChance==e[6] and m.target==e[7]
    and m.flags==e[8] and m.priority==0, "semi-invulnerable source record mismatch")
end
print("phase4_semi_invulnerable_effect_rom_test: 2 passed, 0 failed; exact 8-member source families")
