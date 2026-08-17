-- Deterministic FireRed wild-Pokemon creation and capture persistence.
-- Pure Lua: callers inject the shared global Rng stream and already-parsed
-- ROM tables, so generation is replayable and has no filesystem/UI state.
--
-- Exact source behavior ported:
--
-- * src/wild_encounter.c GenerateWildMon (ordinary, non-Unown branch):
--     CreateMonWithNature(..., USE_RANDOM_IVS, Random() % NUM_NATURES)
-- * src/pokemon.c CreateMonWithNature/CreateMon/CreateBoxMon:
--     Random32() until personality%25 matches the rolled nature; two
--     Random() calls pack HP/Atk/Def then Speed/SpAtk/SpDef IVs; ability
--     slot is personality&1 only when a second ability exists; level exp,
--     friendship, met data, and initial moves are written to BoxPokemon.
-- * src/pokemon.c GiveBoxMonInitialMoveset/GiveMoveToBoxMon/
--     DeleteFirstMoveAndGiveMoveToBoxMon: legal moves up through the current
--     level are learned in table order, duplicates ignored, and overflow
--     forgets the oldest move, leaving the latest four at full base PP.
-- * src/pokemon.c CalculateMonStats and GetBoxMonGender: delegated to
--     PokemonStats and reproduced gender-ratio comparison respectively.
-- * src/battle_script_commands.c Cmd_handleballthrow/Cmd_givecaughtmon and
--     src/pokemon.c GiveMonToPlayer/SendMonToPC: capture records the used
--     ball and current party HP/status/PP; the player's OT fields are
--     rewritten on receipt. toPcRecord() restores PP before boxing, as the
--     real SendMonToPC does.
--
-- Deliberate omissions/boundaries:
--
-- * Unown uses a separate chamber/letter-constrained personality loop and
--   is rejected here instead of silently generating the wrong form.
-- * Held-item wild rolls, Pokérus, ribbons, shininess presentation, nick-
--   naming UI, Pokédex updates, bag consumption, mail, and PC save sectors
--   are outside this constructor. New records correctly initialize their
--   corresponding BoxPokemon fields to CreateBoxMon's zero/default values.
-- * Text is not transcoded. speciesName and trainer.name must already be
--   FireRed charmap bytes (10 and 7 stored bytes respectively).
-- * metLocation is injected because GetCurrentRegionMapSectionId() belongs
--   to overworld state. English/FireRed/Poké Ball defaults match the US
--   FireRed build (LANGUAGE_ENGLISH=2, VERSION_FIRE_RED=4, ITEM_POKE_BALL=4).

local BoxPokemonCodec = require("src.core.BoxPokemonCodec")
local ExperienceTable = require("src.core.ExperienceTable")
local PokemonStats = require("src.core.PokemonStats")

local WildPokemonFactory = {}

WildPokemonFactory.NUM_NATURES = 25
WildPokemonFactory.SPECIES_UNOWN = 201
WildPokemonFactory.SPECIES_SHEDINJA = 303
WildPokemonFactory.LANGUAGE_ENGLISH = 2
WildPokemonFactory.VERSION_FIRE_RED = 4
WildPokemonFactory.ITEM_POKE_BALL = 4
WildPokemonFactory.MAIL_NONE = 255
WildPokemonFactory.MON_MALE = 0
WildPokemonFactory.MON_FEMALE = 254
WildPokemonFactory.MON_GENDERLESS = 255

local function cloneArray(values, count)
  local out = {}
  for i = 1, count or #values do out[i] = values[i] end
  return out
end

local function copyIvs(ivs)
  return {
    hp = ivs.hp, attack = ivs.attack, defense = ivs.defense,
    speed = ivs.speed, spAttack = ivs.spAttack, spDefense = ivs.spDefense,
  }
end

local function zeroStats()
  return { hp = 0, attack = 0, defense = 0, speed = 0, spAttack = 0, spDefense = 0 }
end

local function fixedBytes(value, size, field)
  assert(type(value) == "string", field .. " must be raw FireRed charmap bytes")
  assert(#value >= size, ("%s must contain at least %d bytes"):format(field, size))
  return value:sub(1, size)
end

local function trainerIdNumber(value)
  if type(value) == "number" then return value % 4294967296 end
  assert(type(value) == "string" and #value >= 4,
    "trainer.id must be a u32 or at least four little-endian bytes")
  return string.byte(value, 1) + string.byte(value, 2) * 256
    + string.byte(value, 3) * 65536 + string.byte(value, 4) * 16777216
end

local function normalizedTrainer(trainer)
  trainer = assert(trainer, "trainer identity is required")
  return {
    id = trainerIdNumber(assert(trainer.id, "trainer.id is required")),
    name = fixedBytes(trainer.name, 7, "trainer.name"),
    gender = assert(trainer.gender, "trainer.gender is required") % 2,
  }
end

-- random.h's Random32() macro is Random() | (Random() << 16): the low-half
-- draw occurs first. Keep this helper public for fixture/replay audits.
function WildPokemonFactory.random32(rng)
  local low = rng:next16()
  local high = rng:next16()
  return low + high * 65536
end

function WildPokemonFactory.genderFromPersonality(genderRatio, personality)
  if genderRatio == WildPokemonFactory.MON_MALE
      or genderRatio == WildPokemonFactory.MON_FEMALE
      or genderRatio == WildPokemonFactory.MON_GENDERLESS then
    return genderRatio
  end
  if genderRatio > (personality % 256) then
    return WildPokemonFactory.MON_FEMALE
  end
  return WildPokemonFactory.MON_MALE
end

-- Port of GiveBoxMonInitialMoveset. Returns parallel 1-indexed move/PP
-- arrays, each exactly four entries (unused slots are zero).
function WildPokemonFactory.initialMoves(learnset, level, battleMoves)
  local moves, pp = { 0, 0, 0, 0 }, { 0, 0, 0, 0 }
  local count = 0
  for _, entry in ipairs(learnset or {}) do
    if entry.level > level then break end
    local duplicate = false
    for i = 1, count do
      if moves[i] == entry.move then duplicate = true break end
    end
    if not duplicate then
      local moveData = assert(battleMoves[entry.move],
        ("missing gBattleMoves entry %d"):format(entry.move))
      if count < 4 then
        count = count + 1
        moves[count], pp[count] = entry.move, moveData.pp
      else
        moves[1], moves[2], moves[3] = moves[2], moves[3], moves[4]
        pp[1], pp[2], pp[3] = pp[2], pp[3], pp[4]
        moves[4], pp[4] = entry.move, moveData.pp
      end
    end
  end
  return moves, pp
end

local function battleMoveSlots(moves, pp)
  local out = {}
  for i = 1, 4 do
    if (moves[i] or 0) ~= 0 then
      out[#out + 1] = { move = moves[i], pp = pp[i] or 0 }
    end
  end
  return out
end

local function buildBoxData(args)
  return {
    personality = args.personality,
    otId = args.trainer.id,
    nickname = args.nickname,
    language = args.language,
    isBadEgg = false,
    hasSpecies = args.species ~= 0,
    isEgg = false,
    blockBoxRS = false,
    unusedFlags = 0,
    otName = args.trainer.name,
    markings = 0,
    unknown = 0,
    substructs = {
      [0] = {
        species = args.species, heldItem = 0, experience = args.experience,
        ppBonuses = 0, friendship = args.friendship, filler = 0,
      },
      [1] = { moves = cloneArray(args.moves, 4), pp = cloneArray(args.pp, 4) },
      [2] = {
        hpEV = 0, attackEV = 0, defenseEV = 0, speedEV = 0,
        spAttackEV = 0, spDefenseEV = 0, cool = 0, beauty = 0,
        cute = 0, smart = 0, tough = 0, sheen = 0,
      },
      [3] = {
        pokerus = 0, metLocation = args.metLocation, metLevel = args.level,
        metGame = args.metGame, pokeball = args.pokeball,
        otGender = args.trainer.gender, ivs = copyIvs(args.ivs),
        isEgg = false, abilityNum = args.abilityNum,
        ribbonBytes = string.rep("\0", 4),
      },
    },
  }
end

-- args:
--   species, level, speciesInfo, learnset, battleMoves, natures, rng
--   speciesName (raw charmap bytes), trainer={id,name,gender}, metLocation
-- Optional: language, metGame, pokeball. Returns an immutable-by-convention
-- generated instance plus a real 80-byte encrypted `box` blob.
function WildPokemonFactory.generate(args)
  assert(type(args) == "table", "WildPokemonFactory.generate expects options")
  local species = assert(args.species, "species is required")
  local level = assert(args.level, "level is required")
  assert(level >= 1 and level <= 100, "level must be 1..100")
  if species == WildPokemonFactory.SPECIES_UNOWN then
    error("ordinary wild generation does not cover Unown's chamber/letter personality loop")
  end
  local speciesInfo = assert(args.speciesInfo, "speciesInfo is required")
  local battleMoves = assert(args.battleMoves, "battleMoves table is required")
  local natures = assert(args.natures, "nature table is required")
  local rng = assert(args.rng, "shared RNG is required")
  local trainer = normalizedTrainer(args.trainer)
  local nickname = fixedBytes(args.speciesName, 10, "speciesName")

  -- GenerateWildMon rolls the desired nature before CreateMonWithNature's
  -- rejection loop. This draw order must share the encounter/global RNG.
  local rolledNature = rng:next16() % WildPokemonFactory.NUM_NATURES
  local personality
  repeat
    personality = WildPokemonFactory.random32(rng)
  until personality % WildPokemonFactory.NUM_NATURES == rolledNature

  -- CreateBoxMon's USE_RANDOM_IVS branch: HP/Atk/Def from one Random(),
  -- Speed/SpAtk/SpDef from the next, five bits apiece.
  local firstIvs = rng:next16()
  local secondIvs = rng:next16()
  local ivs = {
    hp = firstIvs % 32,
    attack = math.floor(firstIvs / 32) % 32,
    defense = math.floor(firstIvs / 1024) % 32,
    speed = secondIvs % 32,
    spAttack = math.floor(secondIvs / 32) % 32,
    spDefense = math.floor(secondIvs / 1024) % 32,
  }
  local abilityNum = ((speciesInfo.abilities or {})[2] or 0) ~= 0
    and personality % 2 or 0
  local moves, pp = WildPokemonFactory.initialMoves(args.learnset, level, battleMoves)
  local evs = zeroStats()
  local natureRow = assert(natures[rolledNature],
    ("missing nature row %d"):format(rolledNature))
  local stats = PokemonStats.calculateAll(speciesInfo, level, ivs, evs, natureRow)
  if species == WildPokemonFactory.SPECIES_SHEDINJA then stats.hp = 1 end
  local experience = ExperienceTable.expForLevel(speciesInfo.growthRate, level)
  local boxData = buildBoxData({
    personality = personality, trainer = trainer, nickname = nickname,
    language = args.language or WildPokemonFactory.LANGUAGE_ENGLISH,
    species = species, experience = experience,
    friendship = speciesInfo.friendship, moves = moves, pp = pp,
    metLocation = assert(args.metLocation, "metLocation is required"),
    level = level, metGame = args.metGame or WildPokemonFactory.VERSION_FIRE_RED,
    pokeball = args.pokeball or WildPokemonFactory.ITEM_POKE_BALL,
    ivs = ivs, abilityNum = abilityNum,
  })
  local box = BoxPokemonCodec.encode(boxData)

  return {
    species = species, level = level, personality = personality,
    nature = rolledNature,
    gender = WildPokemonFactory.genderFromPersonality(speciesInfo.genderRatio, personality),
    abilityNum = abilityNum, ability = (speciesInfo.abilities or {})[abilityNum + 1] or 0,
    ivs = ivs, evs = evs, stats = stats,
    types = cloneArray(speciesInfo.types or {}, 2), catchRate = speciesInfo.catchRate,
    moves = battleMoveSlots(moves, pp),
    boxData = boxData, box = box,
    status = 0, hp = stats.hp, maxHP = stats.hp,
  }
end

local function copyBoxData(data)
  local out = {
    personality = data.personality, otId = data.otId, nickname = data.nickname,
    language = data.language, isBadEgg = data.isBadEgg,
    hasSpecies = data.hasSpecies, isEgg = data.isEgg,
    blockBoxRS = data.blockBoxRS, unusedFlags = data.unusedFlags,
    otName = data.otName,
    markings = data.markings, unknown = data.unknown, substructs = {},
  }
  local g, a, e, m = data.substructs[0], data.substructs[1], data.substructs[2], data.substructs[3]
  out.substructs[0] = {
    species = g.species, heldItem = g.heldItem, experience = g.experience,
    ppBonuses = g.ppBonuses, friendship = g.friendship, filler = g.filler,
  }
  out.substructs[1] = { moves = cloneArray(a.moves, 4), pp = cloneArray(a.pp, 4) }
  out.substructs[2] = {
    hpEV=e.hpEV, attackEV=e.attackEV, defenseEV=e.defenseEV, speedEV=e.speedEV,
    spAttackEV=e.spAttackEV, spDefenseEV=e.spDefenseEV, cool=e.cool,
    beauty=e.beauty, cute=e.cute, smart=e.smart, tough=e.tough, sheen=e.sheen,
  }
  out.substructs[3] = {
    pokerus=m.pokerus, metLocation=m.metLocation, metLevel=m.metLevel,
    metGame=m.metGame, pokeball=m.pokeball, otGender=m.otGender,
    ivs=copyIvs(m.ivs), isEgg=m.isEgg, abilityNum=m.abilityNum,
    ribbonBytes=m.ribbonBytes,
  }
  return out
end

local function persistentRecord(instance, boxData, hp, status)
  local stats = instance.stats
  return {
    -- Exact SaveFileCodec struct Pokemon fields:
    box = BoxPokemonCodec.encode(boxData),
    status = status or 0,
    level = instance.level,
    mail = WildPokemonFactory.MAIL_NONE,
    hp = hp,
    maxHP = stats.hp,
    attack = stats.attack,
    defense = stats.defense,
    speed = stats.speed,
    spAttack = stats.spAttack,
    spDefense = stats.spDefense,
    -- Useful decoded metadata ignored harmlessly by SaveFileCodec and
    -- accepted by PartyModel/PcBoxes' duck-typed slots.
    species = instance.species,
    personality = instance.personality,
    nature = instance.nature,
    gender = instance.gender,
    abilityNum = instance.abilityNum,
    ivs = copyIvs(instance.ivs),
    moves = battleMoveSlots(boxData.substructs[1].moves, boxData.substructs[1].pp),
    boxData = boxData,
  }
end

-- Converts the generated enemy into the persistent struct-Pokemon shape
-- expected by SaveFileCodec and storable directly in PartyModel.
-- capture.moveSlots may be BattleEngine's ordered {move,pp} list; omitted
-- slots retain the generated enemy-party PP. `ball` is the real item id.
function WildPokemonFactory.capture(instance, capture)
  capture = capture or {}
  local boxData = copyBoxData(assert(instance.boxData, "generated instance is required"))
  local trainer = capture.trainer and normalizedTrainer(capture.trainer) or nil
  if trainer then
    -- GiveMonToPlayer rewrites these three OT fields before party/PC routing.
    boxData.otId, boxData.otName = trainer.id, trainer.name
    boxData.substructs[3].otGender = trainer.gender
  end
  boxData.substructs[3].pokeball = assert(capture.ball, "capturing ball item id is required")
  if capture.moveSlots then
    for i = 1, 4 do
      local slot = capture.moveSlots[i]
      if slot then
        boxData.substructs[1].moves[i] = slot.move or 0
        boxData.substructs[1].pp[i] = slot.pp or 0
      end
    end
  end
  local hp = capture.hp
  if hp == nil then hp = instance.hp end
  hp = math.max(0, math.min(instance.stats.hp, hp))
  return persistentRecord(instance, boxData, hp, capture.status or instance.status or 0)
end

-- Real SendMonToPC calls MonRestorePP before copying only the 80-byte box.
-- Returns a PcBoxes-friendly record with a restored, checksummed box blob.
function WildPokemonFactory.toPcRecord(caught, battleMoves)
  assert(caught and caught.boxData, "captured persistent record is required")
  local boxData = copyBoxData(caught.boxData)
  for i = 1, 4 do
    local move = boxData.substructs[1].moves[i] or 0
    if move == 0 then
      boxData.substructs[1].pp[i] = 0
    else
      boxData.substructs[1].pp[i] = assert(battleMoves[move],
        ("missing gBattleMoves entry %d"):format(move)).pp
    end
  end
  return {
    box = BoxPokemonCodec.encode(boxData), boxData = boxData,
    species = caught.species, personality = caught.personality,
    nature = caught.nature, gender = caught.gender,
    abilityNum = caught.abilityNum, ivs = copyIvs(caught.ivs),
    moves = battleMoveSlots(boxData.substructs[1].moves, boxData.substructs[1].pp),
  }
end

return WildPokemonFactory
