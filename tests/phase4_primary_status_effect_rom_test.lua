-- Accepted c75f352 source records; no extracted data is retained.
-- Status slice S3: effects 1 Sleep, 33 Toxic, 66 Poison, 67 Paralyze,
-- 167 Will-O-Wisp.
package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path = os.getenv("POKEPORT_ROM")
if not path then print("SKIP phase4_primary_status_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
assert(RomImporter.verify(path), "supported-ROM verification failed")
local f = assert(io.open(path, "rb"), "verified ROM could not be opened")
local rom = f:read("*a"); f:close()
local a = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, a.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
rom = nil
-- id -> effect, type, accuracy, pp, secondaryEffectChance (src/data/battle_moves.h);
-- every member has power 0, target SELECTED (0), priority 0 and flags
-- PROTECT|MAGIC_COAT|MIRROR (0x16).
local expected = {
  [47]  = {1, 0, 55, 15, 0},     -- Sing
  [77]  = {66, 3, 75, 35, 0},    -- Poison Powder
  [78]  = {67, 12, 75, 30, 0},   -- Stun Spore
  [79]  = {1, 12, 75, 15, 0},    -- Sleep Powder
  [86]  = {67, 13, 100, 20, 0},  -- Thunder Wave
  [92]  = {33, 3, 85, 10, 100},  -- Toxic
  [95]  = {1, 14, 60, 20, 0},    -- Hypnosis
  [137] = {67, 0, 75, 30, 0},    -- Glare
  [139] = {66, 3, 55, 40, 0},    -- Poison Gas
  [142] = {1, 0, 75, 10, 0},     -- Lovely Kiss
  [147] = {1, 12, 100, 15, 0},   -- Spore
  [261] = {167, 10, 75, 15, 0},  -- Will-O-Wisp
  [320] = {1, 12, 55, 15, 0},    -- Grass Whistle
}
local effects = {[1]=true, [33]=true, [66]=true, [67]=true, [167]=true}
local count = 0
for id=0,RomAddresses.COUNTS.MOVES_COUNT-1 do
  if effects[moves[id].effect] then
    assert(expected[id], "unexpected primary-status family member"); count = count + 1
  end
end
assert(count == 13, "primary-status family membership count changed")
for id, e in pairs(expected) do
  local m = moves[id]
  assert(m.effect==e[1] and m.type==e[2] and m.accuracy==e[3] and m.pp==e[4]
    and m.secondaryEffectChance==e[5] and m.power==0 and m.target==0
    and m.priority==0 and m.flags==0x16, "primary-status source record mismatch")
end
print("phase4_primary_status_effect_rom_test: 2 passed, 0 failed; exact 13-member source families")
