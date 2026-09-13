-- Source-faithful constructor for the ordinary trainer-party Pokemon path
-- used by Oak's-lab rivals.  CreateNPCTrainerParty (src/battle_main.c)
-- gives each non-double trainer mon a fixed personality beginning at 0x88,
-- adds the byte sums of the compiled trainer name and species name in the
-- high bytes, scales the trainer-party IV byte to 0..31, and asks
-- CreateMonWithGenderNatureLetter for a random non-shiny OT id.  The three
-- lab rivals use the simplest no-item/default-moves layout.  This factory
-- also supports the other no-item layout, whose four source move slots are
-- already decoded by TrainerParty.  Held-item layouts remain deliberately
-- outside this constructor.

local PokemonStats = require("src.core.PokemonStats")
local WildPokemonFactory = require("src.core.WildPokemonFactory")

local TrainerPokemonFactory = {}

local function byteSumUntilEos(bytes)
  local total = 0
  for i = 1, #bytes do
    local value = string.byte(bytes, i)
    if value == 0xFF then break end
    total = total + value
  end
  return total
end

local function xor16(a, b)
  local result, place = 0, 1
  for _ = 1, 16 do
    if a % 2 ~= b % 2 then result = result + place end
    a, b, place = math.floor(a / 2), math.floor(b / 2), place * 2
  end
  return result
end

local function random32(rng)
  local low, high = rng:next16(), rng:next16()
  return low + high * 65536
end

local function randomNonShinyOtId(rng, personality)
  local personalityXor = xor16(personality % 65536, math.floor(personality / 65536))
  while true do
    local otId = random32(rng)
    local otXor = xor16(otId % 65536, math.floor(otId / 65536))
    if xor16(otXor, personalityXor) >= 8 then return otId end
  end
end

local function fixedIvs(value)
  local iv = math.floor(value * 31 / 255)
  return { hp=iv, attack=iv, defense=iv, speed=iv, spAttack=iv, spDefense=iv }
end

local function customMoveSlots(sourceMoves, movesTable)
  assert(type(sourceMoves) == "table",
    "custom-move trainer party row must provide four ROM move slots")
  local out = {}
  for sourceSlot = 0, 3 do
    local move = sourceMoves[sourceSlot]
    assert(type(move) == "number",
      ("custom-move trainer party row is missing ROM move slot %d"):format(sourceSlot))
    if move ~= 0 then
      local moveData = assert(movesTable[move],
        ("missing gBattleMoves entry %d for trainer custom move slot %d")
          :format(move, sourceSlot))
      out[#out + 1] = { move=move, pp=moveData.pp }
    end
  end
  return out
end

-- args: trainer (Trainer.parseRecord), partyMon (TrainerParty.resolve row),
-- speciesInfo, speciesName (raw charmap bytes), learnset, battleMoves,
-- natures, rng. Returns the same transient generated-mon shape consumed by
-- BattlePartyBridge.battlerFromGenerated.
function TrainerPokemonFactory.generate(args)
  assert(type(args) == "table", "TrainerPokemonFactory.generate expects options")
  local trainer = assert(args.trainer, "trainer record is required")
  local partyMon = assert(args.partyMon, "trainer party mon is required")
  local info = assert(args.speciesInfo, "species info is required")
  local speciesName = assert(args.speciesName, "raw species name is required")
  local movesTable = assert(args.battleMoves, "battle move table is required")
  local natures = assert(args.natures, "nature table is required")
  local rng = assert(args.rng, "shared RNG is required")

  assert(trainer.partyFlags == 0 or trainer.partyFlags == 1,
    ("trainer partyFlags %s is unsupported: held-item layouts and unknown layouts are excluded")
      :format(tostring(trainer.partyFlags)))
  assert(not trainer.doubleBattle, "bounded Oak-lab trainer constructor only supports singles")
  assert(not partyMon.heldItem,
    "no-item trainer-party constructor rejects held-item party rows")
  if trainer.partyFlags == 0 then
    assert(not partyMon.moves,
      "default-move trainer party row must not carry custom move slots")
  end

  local personality = (0x88
    + (byteSumUntilEos(trainer.rawName) + byteSumUntilEos(speciesName)) * 256)
    % 4294967296
  local otId = randomNonShinyOtId(rng, personality)
  local ivs = fixedIvs(partyMon.iv)
  local nature = personality % 25
  local moveSlots
  if trainer.partyFlags == 0 then
    local moves, pp = WildPokemonFactory.initialMoves(args.learnset, partyMon.lvl, movesTable)
    moveSlots = {}
    for i = 1, 4 do
      if (moves[i] or 0) ~= 0 then
        moveSlots[#moveSlots + 1] = { move=moves[i], pp=pp[i] or 0 }
      end
    end
  else
    moveSlots = customMoveSlots(partyMon.moves, movesTable)
  end
  local abilityNum = ((info.abilities or {})[2] or 0) ~= 0 and personality % 2 or 0
  local stats = PokemonStats.calculateAll(info, partyMon.lvl, ivs,
    {hp=0, attack=0, defense=0, speed=0, spAttack=0, spDefense=0},
    assert(natures[nature], ("missing nature row %d"):format(nature)))

  return {
    species=partyMon.species, level=partyMon.lvl, personality=personality,
    otId=otId, nature=nature, ivs=ivs, stats=stats, hp=stats.hp,
    types={info.types[1], info.types[2]}, moves=moveSlots,
    gender=WildPokemonFactory.genderFromPersonality(info.genderRatio, personality),
    abilityNum=abilityNum, ability=(info.abilities or {})[abilityNum + 1] or 0,
    status=0, catchRate=info.catchRate,
  }
end

TrainerPokemonFactory.byteSumUntilEos = byteSumUntilEos
TrainerPokemonFactory.randomNonShinyOtId = randomNonShinyOtId

return TrainerPokemonFactory
