-- Deterministic wild-instance/capture-persistence coverage.
-- Run:
--   lua5.1 tests/wild_pokemon_factory_test.lua
--   POKEPORT_ROM=/path/to/pokefirered.gba lua5.1 tests/wild_pokemon_factory_test.lua
package.path = package.path .. ";./?.lua"

local BattleMove = require("import.BattleMove")
local BoxPokemonCodec = require("src.core.BoxPokemonCodec")
local LevelUpLearnset = require("import.LevelUpLearnset")
local Nature = require("import.Nature")
local PartyModel = require("src.core.PartyModel")
local PcBoxes = require("src.core.PcBoxes")
local Rng = require("src.core.Rng")
local RomAddresses = require("import.RomAddresses")
local RomImporter = require("import.RomImporter")
local SaveFileCodec = require("src.core.SaveFileCodec")
local SpeciesInfo = require("import.SpeciesInfo")
local WildPokemonFactory = require("src.core.WildPokemonFactory")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local function hex(bytes)
  return (bytes:gsub(".", function(c) return ("%02x"):format(string.byte(c)) end))
end

-- Exact sNatureStatTable from src/pokemon.c, indexed by personality%25.
local natureRows = {
  [0]={0,0,0,0,0}, {1,-1,0,0,0}, {1,0,-1,0,0}, {1,0,0,-1,0}, {1,0,0,0,-1},
  {-1,1,0,0,0}, {0,0,0,0,0}, {0,1,-1,0,0}, {0,1,0,-1,0}, {0,1,0,0,-1},
  {-1,0,1,0,0}, {0,-1,1,0,0}, {0,0,0,0,0}, {0,0,1,-1,0}, {0,0,1,0,-1},
  {-1,0,0,1,0}, {0,-1,0,1,0}, {0,0,-1,1,0}, {0,0,0,0,0}, {0,0,0,1,-1},
  {-1,0,0,0,1}, {0,-1,0,0,1}, {0,0,-1,0,1}, {0,0,0,-1,1}, {0,0,0,0,0},
}
local natures = {}
for i = 0, 24 do
  local row = natureRows[i]
  natures[i] = { attack=row[1], defense=row[2], speed=row[3], spAttack=row[4], spDefense=row[5] }
end

-- SPECIES_RATTATA, src/data/pokemon/species_info.h. Only fields consumed
-- by the constructor are included here.
local rattata = {
  baseHP=30, baseAttack=56, baseDefense=35, baseSpeed=72,
  baseSpAttack=25, baseSpDefense=35, types={0,0}, catchRate=255,
  genderRatio=127, friendship=70, growthRate=0, abilities={50,62},
}
local learnset = {
  {level=1, move=33}, {level=1, move=39}, {level=7, move=98},
  {level=13, move=158}, {level=20, move=116}, {level=27, move=228},
  {level=34, move=162}, {level=41, move=283},
}
local moves = {
  [33]={pp=35}, [39]={pp=30}, [98]={pp=30}, [158]={pp=15},
  [116]={pp=30}, [228]={pp=20}, [162]={pp=10}, [283]={pp=5},
}
-- Real gSpeciesNames bytes for RATTATA (10 stored bytes; the source table
-- has an eleventh padding byte). RED is the same charmap encoding emitted
-- by NewGameFlow.encodeName, truncated to BoxPokemon's seven OT bytes.
local rattataName = string.char(0xCC,0xBB,0xCE,0xCE,0xBB,0xCE,0xBB,0xFF,0,0)
local redName = string.char(0xCC,0xBF,0xBE,0xFF,0xFF,0xFF,0xFF)
local leafName = string.char(0xC6,0xBF,0xBB,0xC0,0xFF,0xFF,0xFF)
local trainer = { id=0x44332211, name=redName, gender=0 }

local function generate(seed, opts)
  opts = opts or {}
  local baseRng = Rng.new(seed)
  local countedRng = { draws=0 }
  function countedRng:next16()
    self.draws = self.draws + 1
    return baseRng:next16()
  end
  local generated = WildPokemonFactory.generate({
    species=19, level=opts.level or 3, speciesInfo=rattata,
    learnset=learnset, battleMoves=moves, natures=natures,
    rng=countedRng, speciesName=rattataName, trainer=trainer,
    metLocation=88,
  })
  return generated, countedRng
end

-- Golden replay. Seed 30840 is independently covered by rng_test.lua
-- against the real LCG; these values lock the complete downstream draw
-- order (nature, rejection-loop personality, packed IVs) and BoxPokemon
-- serialization, rather than merely comparing the function with itself.
local mon, generationRng = generate(30840)
check("golden nature", mon.nature == 15, mon.nature)
check("golden personality", mon.personality == 4058462190, mon.personality)
check("golden rejection loop consumes exact RNG draws", generationRng.draws == 43, generationRng.draws)
check("golden IVs",
  mon.ivs.hp == 31 and mon.ivs.attack == 3 and mon.ivs.defense == 4
  and mon.ivs.speed == 5 and mon.ivs.spAttack == 7 and mon.ivs.spDefense == 0,
  ("%d/%d/%d/%d/%d/%d"):format(mon.ivs.hp,mon.ivs.attack,mon.ivs.defense,mon.ivs.speed,mon.ivs.spAttack,mon.ivs.spDefense))
check("golden nature/gender/ability derivations",
  mon.nature == mon.personality % 25 and mon.gender == WildPokemonFactory.MON_MALE
  and mon.abilityNum == mon.personality % 2 and mon.ability == 50)
check("level-3 Rattata gets its two legal source moves at base PP",
  #mon.moves == 2 and mon.moves[1].move == 33 and mon.moves[1].pp == 35
  and mon.moves[2].move == 39 and mon.moves[2].pp == 30)
check("golden calculated stats",
  mon.stats.hp == 15 and mon.stats.attack == 7 and mon.stats.defense == 7
  and mon.stats.speed == 9 and mon.stats.spAttack == 6 and mon.stats.spDefense == 7,
  ("%d/%d/%d/%d/%d/%d"):format(mon.stats.hp,mon.stats.attack,mon.stats.defense,mon.stats.speed,mon.stats.spAttack,mon.stats.spDefense))

local GOLDEN_BOX_HEX = "ee37e7f111223344ccbbcecebbcebbff00000202ccbfbeffffffff008d6f0000de15f3b5ff15d4b5dc0bd4b5ec15d4b5e415d4b5ff53d4b5ff15d4b5ff15d4b5ff15d4b5ff4dd7978085a6b5ff15d4b5"
check("golden encrypted BoxPokemon bytes", hex(mon.box) == GOLDEN_BOX_HEX, hex(mon.box))

local decoded = BoxPokemonCodec.decode(mon.box)
check("generated BoxPokemon checksum is valid", decoded.checksumValid)
check("generated BoxPokemon identity", decoded.personality == mon.personality and decoded.otId == trainer.id)
check("generated growth fields", decoded.substructs[0].species == 19
  and decoded.substructs[0].experience == 27 and decoded.substructs[0].friendship == 70)
check("generated misc fields", decoded.substructs[3].metLocation == 88
  and decoded.substructs[3].metLevel == 3 and decoded.substructs[3].metGame == 4
  and decoded.substructs[3].pokeball == 4)
check("BoxPokemon encode(decode(blob)) is byte-exact", BoxPokemonCodec.encode(decoded) == mon.box)

local opaqueFlagsBlob = mon.box:sub(1, 19) .. string.char(string.byte(mon.box, 20) + 0xA0) .. mon.box:sub(21)
local opaqueFlags = BoxPokemonCodec.decode(opaqueFlagsBlob)
check("BoxPokemon encode preserves opaque high flag bits",
  opaqueFlags.unusedFlags == 10 and BoxPokemonCodec.encode(opaqueFlags) == opaqueFlagsBlob)

local replay = generate(30840)
check("same seed replays byte-for-byte", replay.box == mon.box)
check("different seed changes generated identity", generate(30841).box ~= mon.box)

-- Overflow and duplicate behavior from GiveBoxMonInitialMoveset:
-- duplicate 22 is ignored; after six distinct legal moves only last four
-- survive in source order.
local overflowLearnset = {
  {level=1,move=11}, {level=1,move=22}, {level=2,move=22},
  {level=2,move=33}, {level=3,move=44}, {level=4,move=55}, {level=5,move=66},
}
local overflowMoves = {}
for _, id in ipairs({11,22,33,44,55,66}) do overflowMoves[id] = {pp=id % 40 + 1} end
local selected, selectedPp = WildPokemonFactory.initialMoves(overflowLearnset, 5, overflowMoves)
check("initial moves ignore duplicates and retain latest four",
  selected[1]==33 and selected[2]==44 and selected[3]==55 and selected[4]==66)
check("initial move PP follows retained move records",
  selectedPp[1]==overflowMoves[33].pp and selectedPp[4]==overflowMoves[66].pp)

check("gender ratio boundary is strict greater-than",
  WildPokemonFactory.genderFromPersonality(127, 126) == WildPokemonFactory.MON_FEMALE
  and WildPokemonFactory.genderFromPersonality(127, 127) == WildPokemonFactory.MON_MALE)
check("fixed all-female and genderless ratios stay special",
  WildPokemonFactory.genderFromPersonality(254, 255) == WildPokemonFactory.MON_FEMALE
  and WildPokemonFactory.genderFromPersonality(255, 0) == WildPokemonFactory.MON_GENDERLESS)
local okUnown, errUnown = pcall(function()
  WildPokemonFactory.generate({ species=201, level=5 })
end)
check("Unown is rejected rather than generated with wrong form", not okUnown and tostring(errUnown):find("Unown") ~= nil)

-- Capture bridge: used ball/current HP/status/current PP enter the exact
-- party record and GiveMonToPlayer-style OT rewrite updates the encrypted
-- checksum. The record then passes through PartyModel and SaveFileCodec.
local caught = WildPokemonFactory.capture(mon, {
  ball=3, hp=4, status=0x40,
  moveSlots={ {move=33,pp=31}, {move=39,pp=27} },
  trainer={id=0x88776655, name=leafName, gender=1},
})
local caughtBox = BoxPokemonCodec.decode(caught.box)
check("capture records ball and rewrites OT", caughtBox.substructs[3].pokeball == 3
  and caughtBox.otId == 0x88776655 and caughtBox.otName == leafName
  and caughtBox.substructs[3].otGender == 1 and caughtBox.checksumValid)
check("capture preserves current party battle state", caught.hp == 4 and caught.maxHP == 15
  and caught.status == 0x40 and caught.moves[1].pp == 31 and caught.moves[2].pp == 27)

local party = PartyModel.new()
check("captured record stores directly in PartyModel", party:add(caught) == 1 and party:get(1) == caught)
local sb1Bytes = SaveFileCodec.encodeSaveBlock1({playerPartyCount=1, playerParty={caught}}, 0)
local saved = SaveFileCodec.decodeSaveBlock1(sb1Bytes, 0).playerParty[1]
check("captured record round-trips through SaveFileCodec", saved.box == caught.box
  and saved.hp == 4 and saved.maxHP == 15 and saved.level == 3 and saved.status == 0x40)
check("saved captured BoxPokemon remains valid", BoxPokemonCodec.decode(saved.box).checksumValid)

local pcRecord = WildPokemonFactory.toPcRecord(caught, moves)
local pcBox = BoxPokemonCodec.decode(pcRecord.box)
check("PC conversion restores PP like SendMonToPC", pcBox.substructs[1].pp[1] == 35
  and pcBox.substructs[1].pp[2] == 30 and pcBox.checksumValid)
local pc = PcBoxes.new()
check("PC record stores directly in PcBoxes", pc:add(1, pcRecord) == 1 and pc:get(1,1).box == pcRecord.box)

-- Optional real-ROM fixture. The integration consumes the same verified
-- gLevelUpLearnsets address through RomAddresses as main.lua.
local romPath = os.getenv("POKEPORT_ROM")
if romPath then
  local verified, info = RomImporter.verify(romPath)
  check("ROM fixture verifies", verified == true, info)
  if verified then
    local sha1 = RomImporter._sha1HexOfFile(romPath)
    local addrs = RomAddresses[sha1]
    local f = assert(io.open(romPath, "rb"))
    local data = f:read("*a")
    f:close()
    local realSpecies = SpeciesInfo.parseTable(data, addrs.gSpeciesInfo, 20)[19]
    local realNatures = Nature.parseTable(data, addrs.sNatureStatTable)
    local realMoves = BattleMove.parseTable(data, addrs.gBattleMoves, 355)
    local realLearnset = LevelUpLearnset.resolve(data, addrs.gLevelUpLearnsets, 19)
    check("ROM Rattata learnset resolves all source entries", #realLearnset == 8
      and realLearnset[1].level == 1 and realLearnset[1].move == 33
      and realLearnset[2].move == 39 and realLearnset[8].level == 41 and realLearnset[8].move == 283)
    check("ROM Rattata fixture matches source fields", realSpecies.baseHP == 30
      and realSpecies.baseSpeed == 72 and realSpecies.genderRatio == 127
      and realSpecies.abilities[1] == 50 and realSpecies.abilities[2] == 62)
    local nameOff = addrs.gSpeciesNames + 19 * 11
    local realName = data:sub(nameOff + 1, nameOff + 10)
    local romMon = WildPokemonFactory.generate({
      species=19, level=3, speciesInfo=realSpecies, learnset=realLearnset,
      battleMoves=realMoves, natures=realNatures, rng=Rng.new(30840),
      speciesName=realName, trainer=trainer, metLocation=88,
    })
    check("ROM-backed generation matches golden identity/stats/moves",
      romMon.personality == mon.personality and romMon.nature == mon.nature
      and romMon.stats.hp == mon.stats.hp and romMon.stats.speed == mon.stats.speed
      and romMon.moves[1].move == 33 and romMon.moves[2].move == 39)
    check("ROM-backed nickname copies real gSpeciesNames bytes",
      BoxPokemonCodec.decode(romMon.box).nickname == realName)
  end
else
  print("SKIP: set POKEPORT_ROM=/path/to/verified/pokefirered.gba for ROM fixture")
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
