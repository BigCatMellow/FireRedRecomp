-- Run:
--   POKEPORT_ROM=/path/to/pokefirered.gba lua5.1 tests/early_story_rom_test.lua
package.path = package.path .. ";./?.lua"

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local MapHeader = require("import.MapHeader")
local MapEvents = require("import.MapEvents")
local Trainer = require("import.Trainer")
local TrainerParty = require("import.TrainerParty")
local SpeciesInfo = require("import.SpeciesInfo")
local BattleMove = require("import.BattleMove")
local Nature = require("import.Nature")
local LevelUpLearnset = require("import.LevelUpLearnset")
local Charmap = require("import.Charmap")
local EarlyStory = require("src.core.EarlyStory")
local TrainerFactory = require("src.core.TrainerPokemonFactory")
local Rng = require("src.core.Rng")

local path = os.getenv("POKEPORT_ROM")
if not path then print("SKIP early_story_rom_test (set POKEPORT_ROM)"); os.exit(0) end
local ok, info = RomImporter.verify(path)
if not ok then print("FAIL: ROM verification -- " .. tostring(info)); os.exit(1) end
local f = assert(io.open(path, "rb")); local rom = f:read("*a"); f:close()
local addrs = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
  end
end

local pallet = MapEvents.resolve(rom,
  MapHeader.resolve(rom, addrs.gMapGroups, EarlyStory.MAP_PALLET_TOWN).eventsPtr)
check("ROM has both Oak north-exit triggers at (12,1)/(13,1)",
  pallet.coordEvents[0].x == 12 and pallet.coordEvents[0].y == 1
    and pallet.coordEvents[1].x == 13 and pallet.coordEvents[1].y == 1)
check("ROM Oak triggers use VAR_MAP_SCENE_PALLET_TOWN_OAK == 0",
  pallet.coordEvents[0].trigger == EarlyStory.VAR_PALLET_OAK_SCENE
    and pallet.coordEvents[0].index == 0 and pallet.coordEvents[1].index == 0)

local lab = MapEvents.resolve(rom,
  MapHeader.resolve(rom, addrs.gMapGroups, EarlyStory.MAP_OAKS_LAB).eventsPtr)
check("ROM lab starter balls are local ids 5/6/7 at x 8/9/10, y 4",
  lab.objectEvents[4].localId == 5 and lab.objectEvents[4].x == 8 and lab.objectEvents[4].y == 4
    and lab.objectEvents[5].localId == 6 and lab.objectEvents[5].x == 9 and lab.objectEvents[5].y == 4
    and lab.objectEvents[6].localId == 7 and lab.objectEvents[6].x == 10 and lab.objectEvents[6].y == 4)
check("ROM starter balls carry the three authoritative hide-flag ids",
  lab.objectEvents[4].flagId == EarlyStory.FLAG_HIDE_BULBASAUR_BALL
    and lab.objectEvents[5].flagId == EarlyStory.FLAG_HIDE_SQUIRTLE_BALL
    and lab.objectEvents[6].flagId == EarlyStory.FLAG_HIDE_CHARMANDER_BALL)
check("each real ball has a distinct nonzero script pointer",
  lab.objectEvents[4].scriptPtr ~= 0 and lab.objectEvents[5].scriptPtr ~= 0
    and lab.objectEvents[6].scriptPtr ~= 0
    and lab.objectEvents[4].scriptPtr ~= lab.objectEvents[5].scriptPtr
    and lab.objectEvents[5].scriptPtr ~= lab.objectEvents[6].scriptPtr)
check("ROM lab has three scene-2 leave guards and three scene-3 rival triggers",
  lab.coordEvents[0].trigger == EarlyStory.VAR_OAKS_LAB_SCENE and lab.coordEvents[0].index == 2
    and lab.coordEvents[2].index == 2 and lab.coordEvents[3].index == 3
    and lab.coordEvents[5].trigger == EarlyStory.VAR_OAKS_LAB_SCENE and lab.coordEvents[5].index == 3)
check("all six lab gates occupy x 5..7 at y 8",
  lab.coordEvents[0].x == 5 and lab.coordEvents[1].x == 6 and lab.coordEvents[2].x == 7
    and lab.coordEvents[3].x == 5 and lab.coordEvents[4].x == 6 and lab.coordEvents[5].x == 7
    and lab.coordEvents[0].y == 8 and lab.coordEvents[5].y == 8)

local trainers = Trainer.parseTable(rom, addrs.gTrainers, RomAddresses.COUNTS.NUM_TRAINERS)
local species = SpeciesInfo.parseTable(rom, addrs.gSpeciesInfo, RomAddresses.COUNTS.NUM_SPECIES)
local moves = BattleMove.parseTable(rom, addrs.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
local natures = Nature.parseTable(rom, addrs.sNatureStatTable)
local rivalFixtures = {
  [326]={species=7,moves={33,39},personality=0x000A4188,nature=11,stats={19,9,9,9,10,11}},
  [327]={species=1,moves={33,45},personality=0x000AE388,nature=8,stats={19,9,9,9,9,11}},
  [328]={species=4,moves={10,45},personality=0x000B9188,nature=2,stats={18,11,9,9,11,10}},
}
for trainerId, expected in pairs(rivalFixtures) do
  local trainer = trainers[trainerId]
  local party = TrainerParty.resolve(trainer, rom)
  check(("ROM trainer %d is exact one-mon early-rival AI record"):format(trainerId),
    trainer.trainerClass == 81 and trainer.partyFlags == 0 and trainer.partySize == 1
      and trainer.aiFlags == 7 and not trainer.doubleBattle
      and Charmap.decode(trainer.rawName) == "TERRY")
  check(("ROM trainer %d has level-5 counter starter with IV byte 0"):format(trainerId),
    party[0].species == expected.species and party[0].lvl == 5 and party[0].iv == 0)
  local rawSpeciesName = rom:sub(addrs.gSpeciesNames + expected.species * 11 + 1,
    addrs.gSpeciesNames + expected.species * 11 + 10)
  local foe = TrainerFactory.generate({
    trainer=trainer, partyMon=party[0], speciesInfo=species[expected.species],
    speciesName=rawSpeciesName,
    learnset=LevelUpLearnset.resolve(rom, addrs.gLevelUpLearnsets, expected.species),
    battleMoves=moves, natures=natures, rng=Rng.new(1),
  })
  local expectedPersonality = (0x88
    + (TrainerFactory.byteSumUntilEos(trainer.rawName)
      + TrainerFactory.byteSumUntilEos(rawSpeciesName)) * 256) % 4294967296
  check(("trainer %d constructor uses source personality/fixed IV/default moves"):format(trainerId),
    foe.personality == expectedPersonality and foe.personality == expected.personality
      and foe.ivs.hp == 0 and foe.ivs.spDefense == 0
      and foe.moves[1].move == expected.moves[1] and foe.moves[2].move == expected.moves[2])
  check(("trainer %d nature and all six level-5 stats match retail data"):format(trainerId),
    foe.nature == expected.nature and foe.stats.hp == expected.stats[1]
      and foe.stats.attack == expected.stats[2] and foe.stats.defense == expected.stats[3]
      and foe.stats.speed == expected.stats[4] and foe.stats.spAttack == expected.stats[5]
      and foe.stats.spDefense == expected.stats[6],
    ("nature=%d stats=%d/%d/%d/%d/%d/%d"):format(foe.nature, foe.stats.hp,
      foe.stats.attack, foe.stats.defense, foe.stats.speed, foe.stats.spAttack, foe.stats.spDefense))
end

print(("early_story_rom_test: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
