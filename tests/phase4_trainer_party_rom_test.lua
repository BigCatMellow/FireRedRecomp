-- Run: POKEPORT_ROM=/path/to/pokefirered.gba lua5.1 tests/phase4_trainer_party_rom_test.lua
package.path = package.path .. ";./?.lua"

local BattleMove = require("import.BattleMove")
local Charmap = require("import.Charmap")
local LevelUpLearnset = require("import.LevelUpLearnset")
local Nature = require("import.Nature")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local SpeciesInfo = require("import.SpeciesInfo")
local Trainer = require("import.Trainer")
local TrainerParty = require("import.TrainerParty")
local Factory = require("src.core.TrainerPokemonFactory")
local Rng = require("src.core.Rng")

local path = os.getenv("POKEPORT_ROM")
if not path then print("SKIP phase4_trainer_party_rom_test (set POKEPORT_ROM)"); os.exit(0) end
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
local function generated(trainer, partyMon, species, moves, natures)
  local rawSpeciesName = rom:sub(addrs.gSpeciesNames + partyMon.species * 11 + 1,
    addrs.gSpeciesNames + partyMon.species * 11 + 10)
  return Factory.generate({trainer=trainer, partyMon=partyMon,
    speciesInfo=species[partyMon.species], speciesName=rawSpeciesName,
    learnset=LevelUpLearnset.resolve(rom, addrs.gLevelUpLearnsets, partyMon.species),
    battleMoves=moves, natures=natures, rng=Rng.new(1)})
end

local trainers = Trainer.parseTable(rom, addrs.gTrainers, RomAddresses.COUNTS.NUM_TRAINERS)
local species = SpeciesInfo.parseTable(rom, addrs.gSpeciesInfo, RomAddresses.COUNTS.NUM_SPECIES)
local moves = BattleMove.parseTable(rom, addrs.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
local natures = Nature.parseTable(rom, addrs.sNatureStatTable)

local ben, benMon = trainers[89], TrainerParty.resolve(trainers[89], rom)[0]
check("ROM default fixture is Youngster Ben's no-item/default-move Rattata",
  ben.partyFlags == 0 and Charmap.decode(ben.rawName) == "BEN"
    and benMon.species == 19 and benMon.lvl == 11 and benMon.moves == nil)
local benFoe = generated(ben, benMon, species, moves, natures)
check("default fixture retains ROM-derived level-up moves", #benFoe.moves == 3
  and benFoe.moves[1].move == 33 and benFoe.moves[1].pp == moves[33].pp
  and benFoe.moves[2].move == 39 and benFoe.moves[2].pp == moves[39].pp
  and benFoe.moves[3].move == 98 and benFoe.moves[3].pp == moves[98].pp)

local liam, liamMon = trainers[142], TrainerParty.resolve(trainers[142], rom)[0]
check("ROM custom fixture is Camper Liam's no-item/custom-move Geodude",
  liam.partyFlags == 1 and Charmap.decode(liam.rawName) == "LIAM"
    and liamMon.species == 74 and liamMon.lvl == 10
    and liamMon.moves[0] == 33 and liamMon.moves[1] == 111
    and liamMon.moves[2] == 0 and liamMon.moves[3] == 0)
local liamFoe = generated(liam, liamMon, species, moves, natures)
check("custom fixture copies ROM moves with exact catalog PP", #liamFoe.moves == 2
  and liamFoe.moves[1].move == 33 and liamFoe.moves[1].pp == moves[33].pp
  and liamFoe.moves[2].move == 111 and liamFoe.moves[2].pp == moves[111].pp)
local itemLayout = TrainerParty.resolve(trainers[317], rom)[0]
local itemOk, itemErr = pcall(generated, trainers[317], itemLayout, species, moves, natures)
check("ROM held-item layout is rejected loudly", not itemOk
  and tostring(itemErr):find("unsupported", 1, true) ~= nil, itemErr)

print(("phase4_trainer_party_rom_test: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
