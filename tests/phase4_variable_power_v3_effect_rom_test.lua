-- Accepted c75f352 source records; no extracted data is retained.
-- Variable-power slice V3: effect 117 EFFECT_ROLLOUT (Rollout, Ice Ball) and
-- effect 156 EFFECT_DEFENSE_CURL (Defense Curl).
package.path = package.path .. ";./?.lua"
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local path = os.getenv("POKEPORT_ROM")
if not path or path == "" then print("SKIP phase4_variable_power_v3_effect_rom_test (set POKEPORT_ROM)"); os.exit(0) end
assert(RomImporter.verify(path), "supported-ROM verification failed")
local f = assert(io.open(path, "rb"), "verified ROM could not be opened")
local rom = f:read("*a"); f:close()
local a = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves = BattleMove.parseTable(rom, a.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
rom = nil
-- src/data/battle_moves.h:2668-2679: Rollout 205 and :3916-3927: Ice Ball
-- 301, effect 117, power 30, Rock (5) / Ice (15), accuracy 90, PP 20,
-- chance 0, MOVE_TARGET_SELECTED, priority 0, flags FLAG_MAKES_CONTACT |
-- FLAG_PROTECT_AFFECTED | FLAG_MIRROR_MOVE_AFFECTED |
-- FLAG_KINGS_ROCK_AFFECTED = 0x01 | 0x02 | 0x10 | 0x20.
-- :1446-1457: Defense Curl 111, effect 156, power 0, Normal (0), accuracy 0,
-- PP 40, chance 0, MOVE_TARGET_USER (0x10), priority 0, flags
-- FLAG_SNATCH_AFFECTED = 0x08 (include/constants/pokemon.h:238-243).
local members = { [117] = { [205] = true, [301] = true }, [156] = { [111] = true } }
local counts = { [117] = 0, [156] = 0 }
for id=0,RomAddresses.COUNTS.MOVES_COUNT-1 do
  local family = members[moves[id].effect]
  if family then
    assert(family[id], "unexpected V3 family member")
    counts[moves[id].effect] = counts[moves[id].effect] + 1
  end
end
assert(counts[117] == 2 and counts[156] == 1, "V3 family membership count changed")
for id, t in pairs({ [205] = 5, [301] = 15 }) do
  local m = moves[id]
  assert(m.effect==117 and m.power==30 and m.type==t and m.accuracy==90 and m.pp==20
    and m.secondaryEffectChance==0 and m.target==0 and m.priority==0 and m.flags==0x33,
    "V3 Rollout-family source record mismatch")
end
local m = moves[111]
assert(m.effect==156 and m.power==0 and m.type==0 and m.accuracy==0 and m.pp==40
  and m.secondaryEffectChance==0 and m.target==0x10 and m.priority==0 and m.flags==0x08,
  "V3 Defense Curl source record mismatch")
print("phase4_variable_power_v3_effect_rom_test: 4 passed, 0 failed; exact 2-member and 1-member source families")
