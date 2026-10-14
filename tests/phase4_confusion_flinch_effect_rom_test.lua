-- Accepted c75f352 source records; no extracted data is retained.
-- Confusion/flinch slice C2: effects 31, 49, 76, 92, 118, 146, 150, 166, 199.
package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path = os.getenv("POKEPORT_ROM")
if not path then print("SKIP phase4_confusion_flinch_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
assert(RomImporter.verify(path), "supported-ROM verification failed")
local f = assert(io.open(path, "rb"), "verified ROM could not be opened")
local rom = f:read("*a"); f:close()
local a = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, a.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
rom = nil
-- id -> effect, power, type, accuracy, pp, secondaryEffectChance, target,
-- flags (src/data/battle_moves.h); every priority is 0.
local expected = {
  [23]  = {150, 65, 0, 100, 20, 30, 0x00, 0x13},  -- Stomp
  [27]  = {31, 60, 1, 85, 15, 30, 0x00, 0x33},    -- Rolling Kick
  [29]  = {31, 70, 0, 100, 15, 30, 0x00, 0x13},   -- Headbutt
  [44]  = {31, 60, 17, 100, 25, 30, 0x00, 0x13},  -- Bite
  [48]  = {49, 0, 0, 55, 20, 0, 0x00, 0x16},      -- Supersonic
  [60]  = {76, 65, 14, 100, 20, 10, 0x00, 0x12},  -- Psybeam
  [93]  = {76, 50, 14, 100, 25, 10, 0x00, 0x12},  -- Confusion
  [109] = {49, 0, 7, 100, 10, 0, 0x00, 0x16},     -- Confuse Ray
  [125] = {31, 65, 4, 85, 20, 10, 0x00, 0x12},    -- Bone Club
  [146] = {76, 70, 0, 100, 10, 20, 0x00, 0x13},   -- Dizzy Punch
  [157] = {31, 75, 5, 90, 10, 30, 0x08, 0x12},    -- Rock Slide
  [158] = {31, 80, 0, 90, 15, 10, 0x00, 0x13},    -- Hyper Fang
  [173] = {92, 40, 0, 100, 15, 30, 0x00, 0x32},   -- Snore
  [186] = {49, 0, 0, 75, 10, 0, 0x00, 0x16},      -- Sweet Kiss
  [207] = {118, 0, 0, 90, 15, 100, 0x00, 0x16},   -- Swagger
  [223] = {76, 100, 1, 50, 5, 100, 0x00, 0x13},   -- Dynamic Punch
  [239] = {146, 40, 16, 100, 20, 20, 0x08, 0x32}, -- Twister
  [260] = {166, 0, 17, 100, 15, 0, 0x00, 0x16},   -- Flatter
  [298] = {199, 0, 0, 100, 20, 0, 0x20, 0x02},    -- Teeter Dance
  [302] = {150, 60, 12, 100, 15, 30, 0x00, 0x13}, -- Needle Arm
  [310] = {150, 30, 7, 100, 15, 30, 0x00, 0x13},  -- Astonish
  [324] = {76, 75, 6, 100, 15, 10, 0x00, 0x32},   -- Signal Beam
  [326] = {150, 80, 14, 100, 30, 10, 0x00, 0x12}, -- Extrasensory
  [352] = {76, 60, 11, 100, 20, 20, 0x00, 0x32},  -- Water Pulse
}
local effects = {[31]=true, [49]=true, [76]=true, [92]=true, [118]=true,
  [146]=true, [150]=true, [166]=true, [199]=true}
local count = 0
for id=0,RomAddresses.COUNTS.MOVES_COUNT-1 do
  if effects[moves[id].effect] then
    assert(expected[id], "unexpected confusion/flinch family member"); count = count + 1
  end
end
assert(count == 24, "confusion/flinch family membership count changed")
for id, e in pairs(expected) do
  local m = moves[id]
  assert(m.effect==e[1] and m.power==e[2] and m.type==e[3] and m.accuracy==e[4]
    and m.pp==e[5] and m.secondaryEffectChance==e[6] and m.target==e[7]
    and m.flags==e[8] and m.priority==0, "confusion/flinch source record mismatch")
end
print("phase4_confusion_flinch_effect_rom_test: 2 passed, 0 failed; exact 24-member source families")
