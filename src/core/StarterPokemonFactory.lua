-- Deterministic implementation of the Pokemon created by FireRed's
-- `givemon PLAYER_STARTER_SPECIES, 5` in Oak's lab.
--
-- This is deliberately separate from WildPokemonFactory. A wild Pokemon is
-- created by GenerateWildMon, which first rolls a desired nature and then
-- rejection-samples personalities until one has that nature. The starter
-- path instead runs:
--
--   PalletTown_ProfessorOaksLab_EventScript_ChoseStarter (map script)
--     -> ScrCmd_givemon (src/scrcmd.c)
--     -> ScriptGiveMon(species, 5, ITEM_NONE, ...) (src/script_pokemon_util.c)
--     -> CreateMon(mon, species, 5, USE_RANDOM_IVS, FALSE, 0,
--                  OT_ID_PLAYER_ID, 0) (src/pokemon.c)
--
-- Consequently it consumes exactly four Random() u16 values: low/high
-- personality halves, then HP/Atk/Def IVs and Speed/SpAtk/SpDef IVs. Nature
-- is personality % 25; there is no nature draw or personality rejection.
-- ScriptGiveMon also registers the species as seen/caught. That save-state
-- side effect belongs to EarlyStory; this module owns only construction of
-- the exact save-compatible struct Pokemon record.

local BoxPokemonCodec = require("src.core.BoxPokemonCodec")
local ExperienceTable = require("src.core.ExperienceTable")
local PokemonStats = require("src.core.PokemonStats")
local WildPokemonFactory = require("src.core.WildPokemonFactory")

local StarterPokemonFactory = {}

StarterPokemonFactory.LEVEL = 5
StarterPokemonFactory.ITEM_NONE = 0
StarterPokemonFactory.ITEM_POKE_BALL = 4
StarterPokemonFactory.LANGUAGE_ENGLISH = 2
StarterPokemonFactory.VERSION_FIRE_RED = 4
StarterPokemonFactory.MAIL_NONE = 255

local function fixedBytes(value, size, field)
  assert(type(value) == "string" and #value >= size,
    ("%s must contain at least %d raw FireRed charmap bytes"):format(field, size))
  return value:sub(1, size)
end

local function trainerIdNumber(value)
  if type(value) == "number" then return value % 4294967296 end
  assert(type(value) == "string" and #value >= 4,
    "trainer.id must be a u32 or at least four little-endian bytes")
  return string.byte(value, 1) + string.byte(value, 2) * 256
    + string.byte(value, 3) * 65536 + string.byte(value, 4) * 16777216
end

local function clone(values, count)
  local out = {}
  for i = 1, count do out[i] = values[i] or 0 end
  return out
end

local function copyIvs(ivs)
  return {
    hp=ivs.hp, attack=ivs.attack, defense=ivs.defense,
    speed=ivs.speed, spAttack=ivs.spAttack, spDefense=ivs.spDefense,
  }
end

local function battleMoveSlots(moves, pp)
  local out = {}
  for i = 1, 4 do
    if (moves[i] or 0) ~= 0 then out[#out + 1] = { move=moves[i], pp=pp[i] or 0 } end
  end
  return out
end

function StarterPokemonFactory.random32(rng)
  local low = rng:next16()
  local high = rng:next16()
  return low + high * 65536
end

-- args: species, speciesInfo, speciesName (10 raw bytes), learnset,
-- battleMoves, natures, rng, trainer={id,name(7 raw bytes),gender},
-- metLocation. Optional level/language/metGame/pokeball/heldItem exist for
-- focused source fixtures; Oak's actual script uses their defaults here.
function StarterPokemonFactory.generate(args)
  assert(type(args) == "table", "StarterPokemonFactory.generate expects options")
  local species = assert(args.species, "species is required")
  local level = args.level or StarterPokemonFactory.LEVEL
  local info = assert(args.speciesInfo, "speciesInfo is required")
  local movesTable = assert(args.battleMoves, "battleMoves table is required")
  local natures = assert(args.natures, "nature table is required")
  local rng = assert(args.rng, "shared RNG is required")
  local trainerArg = assert(args.trainer, "trainer identity is required")
  local trainer = {
    id=trainerIdNumber(assert(trainerArg.id, "trainer.id is required")),
    name=fixedBytes(trainerArg.name, 7, "trainer.name"),
    gender=assert(trainerArg.gender, "trainer.gender is required") % 2,
  }

  local personality = StarterPokemonFactory.random32(rng)
  local firstIvs, secondIvs = rng:next16(), rng:next16()
  local ivs = {
    hp=firstIvs % 32,
    attack=math.floor(firstIvs / 32) % 32,
    defense=math.floor(firstIvs / 1024) % 32,
    speed=secondIvs % 32,
    spAttack=math.floor(secondIvs / 32) % 32,
    spDefense=math.floor(secondIvs / 1024) % 32,
  }
  local nature = personality % 25
  local abilityNum = ((info.abilities or {})[2] or 0) ~= 0 and personality % 2 or 0
  local moves, pp = WildPokemonFactory.initialMoves(args.learnset, level, movesTable)
  local stats = PokemonStats.calculateAll(info, level, ivs,
    {hp=0, attack=0, defense=0, speed=0, spAttack=0, spDefense=0},
    assert(natures[nature], ("missing nature row %d"):format(nature)))
  local nickname = fixedBytes(args.speciesName, 10, "speciesName")

  local boxData = {
    personality=personality, otId=trainer.id, nickname=nickname,
    language=args.language or StarterPokemonFactory.LANGUAGE_ENGLISH,
    isBadEgg=false, hasSpecies=true, isEgg=false, blockBoxRS=false,
    unusedFlags=0, otName=trainer.name, markings=0, unknown=0,
    substructs={
      [0]={
        species=species, heldItem=args.heldItem or StarterPokemonFactory.ITEM_NONE,
        experience=ExperienceTable.expForLevel(info.growthRate, level),
        ppBonuses=0, friendship=info.friendship, filler=0,
      },
      [1]={ moves=clone(moves, 4), pp=clone(pp, 4) },
      [2]={
        hpEV=0, attackEV=0, defenseEV=0, speedEV=0,
        spAttackEV=0, spDefenseEV=0, cool=0, beauty=0, cute=0,
        smart=0, tough=0, sheen=0,
      },
      [3]={
        pokerus=0, metLocation=assert(args.metLocation, "metLocation is required"),
        metLevel=level, metGame=args.metGame or StarterPokemonFactory.VERSION_FIRE_RED,
        pokeball=args.pokeball or StarterPokemonFactory.ITEM_POKE_BALL,
        otGender=trainer.gender, ivs=copyIvs(ivs), isEgg=false,
        abilityNum=abilityNum, ribbonBytes=string.rep("\0", 4),
      },
    },
  }

  local record = {
    box=BoxPokemonCodec.encode(boxData), status=0, level=level,
    mail=StarterPokemonFactory.MAIL_NONE, hp=stats.hp, maxHP=stats.hp,
    attack=stats.attack, defense=stats.defense, speed=stats.speed,
    spAttack=stats.spAttack, spDefense=stats.spDefense,
    species=species, personality=personality, nature=nature,
    gender=WildPokemonFactory.genderFromPersonality(info.genderRatio, personality),
    abilityNum=abilityNum, ivs=copyIvs(ivs),
    moves=battleMoveSlots(moves, pp), boxData=boxData,
  }
  return record
end

return StarterPokemonFactory
