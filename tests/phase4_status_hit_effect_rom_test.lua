-- Accepted c75f352 source records; no extracted data is retained.
-- Status slice S2: effects 2 Poison Hit, 4 Burn Hit, 5 Freeze Hit,
-- 6 Paralyze Hit, 202 Poison Fang, 209 Poison Tail.
package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path = os.getenv("POKEPORT_ROM")
if not path then print("SKIP phase4_status_hit_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
assert(RomImporter.verify(path), "supported-ROM verification failed")
local f = assert(io.open(path, "rb"), "verified ROM could not be opened")
local rom = f:read("*a"); f:close()
local a = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, a.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
rom = nil
-- id -> effect, power, type, accuracy, pp, secondaryEffectChance, target,
-- flags (src/data/battle_moves.h); every priority is 0.
local expected = {
  [7]   = {4, 75, 10, 100, 15, 10, 0, 0x13},   -- Fire Punch
  [8]   = {5, 75, 15, 100, 15, 10, 0, 0x13},   -- Ice Punch
  [9]   = {6, 75, 13, 100, 15, 10, 0, 0x13},   -- Thunder Punch
  [34]  = {6, 85, 0, 100, 15, 30, 0, 0x13},    -- Body Slam
  [40]  = {2, 15, 3, 100, 35, 30, 0, 0x12},    -- Poison Sting
  [52]  = {4, 40, 10, 100, 25, 10, 0, 0x12},   -- Ember
  [53]  = {4, 95, 10, 100, 15, 10, 0, 0x12},   -- Flamethrower
  [58]  = {5, 95, 15, 100, 10, 10, 0, 0x12},   -- Ice Beam
  [59]  = {5, 120, 15, 70, 5, 10, 8, 0x12},    -- Blizzard
  [84]  = {6, 40, 13, 100, 30, 10, 0, 0x12},   -- Thunder Shock
  [85]  = {6, 95, 13, 100, 15, 10, 0, 0x12},   -- Thunderbolt
  [122] = {6, 20, 7, 100, 30, 30, 0, 0x13},    -- Lick
  [123] = {2, 20, 3, 70, 20, 40, 0, 0x12},     -- Smog
  [124] = {2, 65, 3, 100, 20, 30, 0, 0x12},    -- Sludge
  [126] = {4, 120, 10, 85, 5, 10, 0, 0x12},    -- Fire Blast
  [181] = {5, 40, 15, 100, 25, 10, 8, 0x12},   -- Powder Snow
  [188] = {2, 90, 3, 100, 10, 30, 0, 0x12},    -- Sludge Bomb
  [192] = {6, 100, 13, 50, 5, 100, 0, 0x12},   -- Zap Cannon
  [209] = {6, 65, 13, 100, 20, 30, 0, 0x13},   -- Spark
  [225] = {6, 60, 16, 100, 20, 30, 0, 0x32},   -- Dragon Breath
  [257] = {4, 100, 10, 90, 10, 10, 8, 0x12},   -- Heat Wave
  [305] = {202, 50, 3, 100, 15, 30, 0, 0x13},  -- Poison Fang
  [342] = {209, 50, 3, 100, 25, 10, 0, 0x33},  -- Poison Tail
}
local effects = {[2]=true, [4]=true, [5]=true, [6]=true, [202]=true, [209]=true}
local count = 0
for id=0,RomAddresses.COUNTS.MOVES_COUNT-1 do
  if effects[moves[id].effect] then
    assert(expected[id], "unexpected status-hit family member"); count = count + 1
  end
end
assert(count == 23, "status-hit family membership count changed")
for id, e in pairs(expected) do
  local m = moves[id]
  assert(m.effect==e[1] and m.power==e[2] and m.type==e[3] and m.accuracy==e[4]
    and m.pp==e[5] and m.secondaryEffectChance==e[6] and m.target==e[7]
    and m.flags==e[8] and m.priority==0, "status-hit source record mismatch")
end
print("phase4_status_hit_effect_rom_test: 2 passed, 0 failed; exact 23-member source families")
