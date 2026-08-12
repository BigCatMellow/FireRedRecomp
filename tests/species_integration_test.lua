-- Integration test: parses species, move, and type-chart tables out of a
-- real FireRed(US) v1.0 ROM and checks known values. This is the only test
-- file that touches a real ROM, so it's opt-in and skips cleanly when one
-- isn't available (a fresh checkout has no ROM -- see README's no-ROM
-- contribution rule).
--
-- Run: POKEPORT_ROM=/path/to/pokefirered.gba lua5.1 tests/species_integration_test.lua
package.path = package.path .. ";./?.lua"

local romPath = os.getenv("POKEPORT_ROM")
if not romPath then
  print("SKIP: set POKEPORT_ROM=/path/to/verified/pokefirered.gba to run this test")
  os.exit(0)
end

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local SpeciesInfo = require("import.SpeciesInfo")
local BattleMove = require("import.BattleMove")
local TypeChart = require("import.TypeChart")
local Item = require("import.Item")
local AbilityNames = require("import.AbilityNames")
local Charmap = require("import.Charmap")
local Trainer = require("import.Trainer")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local ok, info = RomImporter.verify(romPath)
check("ROM verifies", ok == true, info)
if not ok then
  print(("%d passed, %d failed"):format(passed, failed))
  os.exit(1)
end

local sha1 = RomImporter._sha1HexOfFile(romPath)

local addrs = RomAddresses[sha1]
check("known symbol addresses for this ROM", addrs ~= nil)

local f = io.open(romPath, "rb")
local data = f:read("*a")
f:close()

local species = SpeciesInfo.parseTable(data, addrs.gSpeciesInfo, 5)

-- SPECIES_NONE=0, BULBASAUR=1, IVYSAUR=2, VENUSAUR=3, CHARMANDER=4
check("Bulbasaur baseHP", species[1].baseHP == 45, species[1].baseHP)
check("Bulbasaur baseAttack", species[1].baseAttack == 49, species[1].baseAttack)
check("Bulbasaur types (Grass/Poison)", species[1].types[1] == 12 and species[1].types[2] == 3)
check("Venusaur baseHP", species[3].baseHP == 80, species[3].baseHP)
check("Charmander baseSpeed", species[4].baseSpeed == 65, species[4].baseSpeed)

-- MOVE_NONE=0, MOVE_POUND=1, MOVE_KARATE_CHOP=2
local moves = BattleMove.parseTable(data, addrs.gBattleMoves, 3)
check("Pound power", moves[1].power == 40, moves[1].power)
check("Pound accuracy", moves[1].accuracy == 100, moves[1].accuracy)
check("Pound pp", moves[1].pp == 35, moves[1].pp)
check("Karate Chop is high-crit (effect 43)", moves[2].effect == 43, moves[2].effect)
check("Karate Chop is Fighting-type", moves[2].type == 1, moves[2].type)

local typeChart = TypeChart.parseTable(data, addrs.gTypeEffectiveness)
check("type chart has rows and ends with ENDTABLE (not overrun)", #typeChart > 100, #typeChart)
-- First row per src/battle_main.c: Normal vs Rock, not very effective.
check("first type chart row is Normal/Rock not-very-effective", typeChart[0].multiplier == TypeChart.MUL_NOT_EFFECTIVE, typeChart[0] and typeChart[0].multiplier)

-- ITEM_NONE=0, ITEM_MASTER_BALL=1, ITEM_ULTRA_BALL=2
local items = Item.parseTable(data, addrs.gItems, 3)
check("Master Ball itemId/price/pocket", items[1].itemId == 1 and items[1].price == 0 and items[1].pocket == 3)
check("Ultra Ball price", items[2].price == 1200, items[2].price)

-- ABILITY_NONE=0, ABILITY_STENCH=1
local abilityNames = AbilityNames.parseTable(data, addrs.gAbilityNames, 2)
check("ABILITY_NONE is the 7-byte dash placeholder", #abilityNames[0] == 7, #abilityNames[0])
check("ABILITY_STENCH is 6 bytes (right length for STENCH)", #abilityNames[1] == 6, #abilityNames[1])
check("ABILITY_STENCH decodes via Charmap too", Charmap.decode(abilityNames[1]) == "STENCH", Charmap.decode(abilityNames[1]))

-- Full text decode, straight from ROM bytes to real English names.
check("decodes BULBASAUR", Charmap.decodeAt(data, addrs.gSpeciesNames, 11, 1) == "BULBASAUR", Charmap.decodeAt(data, addrs.gSpeciesNames, 11, 1))
check("decodes CHARMANDER", Charmap.decodeAt(data, addrs.gSpeciesNames, 11, 4) == "CHARMANDER", Charmap.decodeAt(data, addrs.gSpeciesNames, 11, 4))
check("decodes MASTER BALL item name", Charmap.decode(items[1].rawName) == "MASTER BALL", Charmap.decode(items[1].rawName))

-- TRAINER_YOUNGSTER_BEN = 89
local trainers = Trainer.parseTable(data, addrs.gTrainers, 90)
local ben = trainers[89]
check("decodes trainer name BEN", Charmap.decode(ben.rawName) == "BEN", Charmap.decode(ben.rawName))
check("Ben's party size is 2", ben.partySize == 2, ben.partySize)
check("Ben's aiFlags is 0x1", ben.aiFlags == 1, ben.aiFlags)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
