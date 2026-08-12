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
local TrainerParty = require("import.TrainerParty")
local MapHeader = require("import.MapHeader")
local MapLayout = require("import.MapLayout")
local MapEvents = require("import.MapEvents")
local MapConnections = require("import.MapConnections")
local MapBorder = require("import.MapBorder")
local WildEncounters = require("import.WildEncounters")
local Nature = require("import.Nature")
local PointerStringTable = require("import.PointerStringTable")
local MapScripts = require("import.MapScripts")
local Tileset = require("import.Tileset")
local Lz77 = require("import.Lz77")
local GbaGraphics = require("import.GbaGraphics")

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

-- Real dialogue messages with control codes, PalletTown_Text_OakDontGoOut
-- and PalletTown_Text_PlayersHouse (addresses from pokefirered.map).
local oakMsg = Charmap.decode(data:sub(0x0817d72c - 0x08000000 + 1, 0x0817d72c - 0x08000000 + 40))
check("decodes a real message with a newline control code", oakMsg == "OAK: Hey! Wait!\nDon\226\128\153t go out!", oakMsg)
local houseMsg = Charmap.decode(data:sub(0x0817d87f - 0x08000000 + 1, 0x0817d87f - 0x08000000 + 20))
check("decodes {PLAYER} placeholder in real message text", houseMsg == "{PLAYER}\226\128\153s house", houseMsg)

-- PalletTown_RivalsHouse_Text_ThereYouGoAllDone: starts with FC 06 02
-- (FONT_NORMAL), and must decode correctly past it, not misalign.
local fontMsg = Charmap.decode(data:sub(0x0818d8fe - 0x08000000 + 1, 0x0818d8fe - 0x08000000 + 40))
check("FC control code (FONT) consumes exactly its param byte, text after decodes cleanly", fontMsg:sub(1, 9) == "{FC:06:02", fontMsg)
check("text right after the FC code decodes correctly (no misalignment)", fontMsg:find("STR_VAR_1} looks dreamily content", 1, true) ~= nil, fontMsg)

-- TRAINER_YOUNGSTER_BEN = 89
local trainers = Trainer.parseTable(data, addrs.gTrainers, 90)
local ben = trainers[89]
check("decodes trainer name BEN", Charmap.decode(ben.rawName) == "BEN", Charmap.decode(ben.rawName))
check("Ben's party size is 2", ben.partySize == 2, ben.partySize)
check("Ben's aiFlags is 0x1", ben.aiFlags == 1, ben.aiFlags)

local benParty = TrainerParty.resolve(ben, data)
check("Ben's party is Rattata/Ekans, both lvl 11", benParty[0].species == 19 and benParty[1].species == 23 and benParty[0].lvl == 11 and benParty[1].lvl == 11)

-- TRAINER_ELITE_FOUR_LORELEI = 410, ItemCustomMoves layout
local trainersFull = Trainer.parseTable(data, addrs.gTrainers, 411)
local lorelei = trainersFull[410]
local loreleiParty = TrainerParty.resolve(lorelei, data)
local dewgong = loreleiParty[0]
check("Lorelei's first mon is Dewgong lvl 52 iv 250", dewgong.species == 87 and dewgong.lvl == 52 and dewgong.iv == 250)
check("Dewgong's moves are Ice Beam/Surf/Hail/Safeguard", dewgong.moves[0] == 58 and dewgong.moves[1] == 57 and dewgong.moves[2] == 258 and dewgong.moves[3] == 219)

-- TRAINER_BLACK_BELT_KOICHI = 317 (ItemDefaultMoves layout), TRAINER_CAMPER_LIAM = 142 (NoItemCustomMoves layout)
local trainersWide = Trainer.parseTable(data, addrs.gTrainers, 318)
local koichi = trainersWide[317]
local koichiParty = TrainerParty.resolve(koichi, data)
check("Koichi's Hitmonlee has held item Black Belt", koichiParty[0].species == 106 and koichiParty[0].lvl == 37 and koichiParty[0].iv == 100 and koichiParty[0].heldItem == 207)

local liam = Trainer.parseTable(data, addrs.gTrainers, 143)[142]
local liamParty = TrainerParty.resolve(liam, data)
check("Liam's Geodude has Tackle/Defense Curl", liamParty[0].species == 74 and liamParty[0].lvl == 10 and liamParty[0].moves[0] == 33 and liamParty[0].moves[1] == 111)

-- MAP_PALLET_TOWN = group 3, num 0
local MAP_PALLET_TOWN = 3 * 256 + 0
local palletTown = MapHeader.resolve(data, addrs.gMapGroups, MAP_PALLET_TOWN)
check("Pallet Town's mapLayoutId is LAYOUT_PALLET_TOWN (78)", palletTown.mapLayoutId == 78, palletTown.mapLayoutId)
check("Pallet Town's regionMapSectionId is 88", palletTown.regionMapSectionId == 88, palletTown.regionMapSectionId)

local palletLayout = MapLayout.resolve(data, palletTown.mapLayoutPtr)
check("Pallet Town layout is 24x20", palletLayout.width == 24 and palletLayout.height == 20)
check("Pallet Town border is 2x2", palletLayout.borderWidth == 2 and palletLayout.borderHeight == 2)

local palletEvents = MapEvents.resolve(data, palletTown.eventsPtr)
check("Pallet Town has 3 object events, 3 warps, 3 coord events, 5 bg events",
  palletEvents.objectEvents[2] ~= nil and palletEvents.objectEvents[3] == nil
  and palletEvents.warps[2] ~= nil and palletEvents.warps[3] == nil
  and palletEvents.coordEvents[2] ~= nil and palletEvents.coordEvents[3] == nil
  and palletEvents.bgEvents[4] ~= nil and palletEvents.bgEvents[5] == nil)
check("Pallet Town's Sign Lady object event", palletEvents.objectEvents[0].x == 3 and palletEvents.objectEvents[0].y == 10 and palletEvents.objectEvents[0].movementRangeY == 4)
check("Pallet Town's warp 0 leads to the player's house (group 4)", palletEvents.warps[0].mapGroup == 4 and palletEvents.warps[0].mapNum == 0 and palletEvents.warps[0].warpId == 1)
check("Pallet Town's Oak trigger coord event", palletEvents.coordEvents[0].trigger == 0x4050)

local palletConns = MapConnections.resolve(data, palletTown.connectionsPtr)
check("Pallet Town has 2 connections", palletConns[0] ~= nil and palletConns[1] ~= nil and palletConns[2] == nil)
check("north connection leads to Route 1 (group 3 num 19)", palletConns[0].direction == MapConnections.CONNECTION_NORTH and palletConns[0].mapGroup == 3 and palletConns[0].mapNum == 19)
check("south connection leads to Route 21 North (group 3 num 39)", palletConns[1].direction == MapConnections.CONNECTION_SOUTH and palletConns[1].mapGroup == 3 and palletConns[1].mapNum == 39)

local primaryTileset = Tileset.resolve(data, palletLayout.primaryTilesetPtr)
check("primary tileset is compressed", primaryTileset.isCompressed == true)
local tileBytesOffset = primaryTileset.tilesPtr - 0x08000000
local decompressedTiles, lzErr = Lz77.decompress(data, tileBytesOffset + 1)
check("primary tileset decompresses", decompressedTiles ~= nil, lzErr)
check("decompresses to a whole number of 32-byte tiles (640)", #decompressedTiles % 32 == 0 and #decompressedTiles / 32 == 640, decompressedTiles and #decompressedTiles / 32)
local palette0 = GbaGraphics.decodePalette(data, primaryTileset.palettesPtr - 0x08000000)
check("palette 0 has 16 colors, not all identical (real image data)", (function()
  local firstColor = palette0[0]
  for i = 1, 15 do
    if palette0[i].r ~= firstColor.r or palette0[i].g ~= firstColor.g or palette0[i].b ~= firstColor.b then
      return true
    end
  end
  return false
end)())

local palletBorder = MapBorder.resolve(data, palletLayout.borderPtr, palletLayout.borderWidth, palletLayout.borderHeight)
check("Pallet Town border is {28,29,20,21}", palletBorder[0] == 28 and palletBorder[1] == 29 and palletBorder[2] == 20 and palletBorder[3] == 21)

-- MAP_ROUTE1 = group 3, num 19
local route1Header = WildEncounters.findHeader(data, addrs.gWildMonHeaders, 3, 19)
check("finds Route 1's wild encounter header", route1Header ~= nil)
local route1Land = WildEncounters.resolveInfo(data, route1Header.landMonsInfoPtr, 12)
check("Route 1 encounter rate is 21", route1Land.encounterRate == 21, route1Land.encounterRate)
check("Route 1's wild mons are Pidgey/Rattata at the right levels", (function()
  local expected = {
    {3,3,16}, {3,3,19}, {3,3,16}, {3,3,19}, {2,2,16}, {2,2,19},
    {3,3,16}, {3,3,19}, {4,4,16}, {4,4,19}, {5,5,16}, {4,4,19},
  }
  for i = 0, 11 do
    local e = expected[i + 1]
    local m = route1Land.mons[i]
    if m.minLevel ~= e[1] or m.maxLevel ~= e[2] or m.species ~= e[3] then return false end
  end
  return true
end)())

local natures = Nature.parseTable(data, addrs.sNatureStatTable)
check("MODEST nature is -atk +spAtk", natures[15].attack == -1 and natures[15].spAttack == 1)
check("QUIRKY nature (last, index 24) is neutral", natures[24].attack == 0 and natures[24].defense == 0 and natures[24].speed == 0 and natures[24].spAttack == 0 and natures[24].spDefense == 0)

-- MAP_CELADON_CITY = group 3, num 6; its object event 12 is a clone
local celadonHeader = MapHeader.resolve(data, addrs.gMapGroups, 3 * 256 + 6)
local celadonEvents = MapEvents.resolve(data, celadonHeader.eventsPtr)
local cloneEvent = celadonEvents.objectEvents[12]
check("Celadon City's clone object event decodes correctly", cloneEvent ~= nil and cloneEvent.kind == 255)
check("clone x/y decode as signed (-7, 21)", cloneEvent.x == -7 and cloneEvent.y == 21, cloneEvent and cloneEvent.x)
check("clone target is MAP_ROUTE16 (group 3, num 34)", cloneEvent.targetMapGroup == 3 and cloneEvent.targetMapNum == 34)

check("ABILITY_STENCH description decodes exactly, including accented e", PointerStringTable.resolveAt(data, addrs.gAbilityDescriptionPointers, 1, 60) == "Helps repel wild POKéMON.")
check("ABILITY_NONE description", PointerStringTable.resolveAt(data, addrs.gAbilityDescriptionPointers, 0, 60) == "No special ability.")
check("nature names decode correctly", PointerStringTable.resolveAt(data, addrs.gNatureNamePointers, 0, 20) == "HARDY" and PointerStringTable.resolveAt(data, addrs.gNatureNamePointers, 3, 20) == "ADAMANT")

local palletScripts = MapScripts.resolve(data, palletTown.mapScriptsPtr)
check("Pallet Town has 2 map script hooks", palletScripts[1] ~= nil and palletScripts[2] == nil)
check("hook 0 is ON_TRANSITION", palletScripts[0].type == MapScripts.ON_TRANSITION)
check("hook 1 is ON_FRAME_TABLE with a resolved sub-table matching VAR_MAP_SCENE_PALLET_TOWN_OAK", palletScripts[1].type == MapScripts.ON_FRAME_TABLE and palletScripts[1].varTable[0].var == 0x4050 and palletScripts[1].varTable[0].compare == 2)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
