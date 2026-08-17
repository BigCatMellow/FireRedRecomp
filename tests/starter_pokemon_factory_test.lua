-- Run:
--   POKEPORT_ROM=/path/to/pokefirered.gba lua5.1 tests/starter_pokemon_factory_test.lua
package.path = package.path .. ";./?.lua"

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local SpeciesInfo = require("import.SpeciesInfo")
local BattleMove = require("import.BattleMove")
local Nature = require("import.Nature")
local LevelUpLearnset = require("import.LevelUpLearnset")
local Charmap = require("import.Charmap")
local BoxPokemonCodec = require("src.core.BoxPokemonCodec")
local Factory = require("src.core.StarterPokemonFactory")

local romPath = os.getenv("POKEPORT_ROM")
if not romPath then print("SKIP starter_pokemon_factory_test (set POKEPORT_ROM)"); os.exit(0) end
local ok, info = RomImporter.verify(romPath)
if not ok then print("FAIL: ROM verification -- " .. tostring(info)); os.exit(1) end
local f = assert(io.open(romPath, "rb")); local rom = f:read("*a"); f:close()
local addrs = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
  end
end

local species = SpeciesInfo.parseTable(rom, addrs.gSpeciesInfo, RomAddresses.COUNTS.NUM_SPECIES)
local moves = BattleMove.parseTable(rom, addrs.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
local natures = Nature.parseTable(rom, addrs.sNatureStatTable)
local draws = { 0x1234, 0x5678, 0x7BDE, 0x1357 }
local drawIndex = 0
local rng = { next16=function()
  drawIndex = drawIndex + 1
  assert(draws[drawIndex], "factory consumed an unexpected extra Random() draw")
  return draws[drawIndex]
end }
local trainerName = string.char(0xCC,0xBF,0xBE,0xFF,0xFF,0xFF,0xFF) -- RED + EOS padding
local record = Factory.generate({
  species=1, speciesInfo=species[1],
  speciesName=rom:sub(addrs.gSpeciesNames + 12, addrs.gSpeciesNames + 21),
  learnset=LevelUpLearnset.resolve(rom, addrs.gLevelUpLearnsets, 1),
  battleMoves=moves, natures=natures, rng=rng,
  trainer={id=0xBEEF1234, name=trainerName, gender=0}, metLocation=0,
})
local decoded = BoxPokemonCodec.decode(record.box)

check("starter CreateMon consumes exactly four Random u16 draws", drawIndex == 4, drawIndex)
check("personality is Random32 low half then high half with no nature rejection",
  record.personality == 0x56781234, string.format("0x%08X", record.personality))
check("nature comes directly from personality modulo 25", record.nature == record.personality % 25)
check("first IV draw packs HP/Atk/Def five bits apiece",
  record.ivs.hp == 30 and record.ivs.attack == 30 and record.ivs.defense == 30)
check("second IV draw packs Speed/SpAtk/SpDef five bits apiece",
  record.ivs.speed == 23 and record.ivs.spAttack == 26 and record.ivs.spDefense == 4)
check("real level-5 Bulbasaur initial moves are Tackle and Growl at base PP",
  record.moves[1].move == 33 and record.moves[1].pp == moves[33].pp
    and record.moves[2].move == 45 and record.moves[2].pp == moves[45].pp)
check("record is a checksum-valid encrypted BoxPokemon", decoded.checksumValid)
check("starter is level 5, fully healed, status-free, and holds ITEM_NONE",
  record.level == 5 and record.hp == record.maxHP and record.status == 0
    and decoded.substructs[0].heldItem == 0)
check("OT, met level/location/game and Poke Ball fields match CreateBoxMon",
  decoded.otId == 0xBEEF1234 and decoded.otName == trainerName
    and decoded.substructs[3].metLevel == 5 and decoded.substructs[3].metLocation == 0
    and decoded.substructs[3].metGame == 4 and decoded.substructs[3].pokeball == 4)
check("nickname is the real ROM species name", Charmap.decode(decoded.nickname) == "BULBASAUR")

print(("starter_pokemon_factory_test: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
