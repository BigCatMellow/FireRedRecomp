-- Resolves a Trainer record's `partyPtr` (see Trainer.lua) into actual
-- party Pokémon data: species/level/IV, plus held item and/or custom moves
-- depending on the trainer's partyFlags bits (pokefirered include/battle.h
-- union TrainerMonPtr / include/constants/trainers.h F_TRAINER_PARTY_*).
--
-- Each of the 4 layouts' raw field size doesn't divide evenly by 4, and
-- every other struct array in this ROM has turned out to be padded to a
-- 4-byte stride (see SpeciesInfo/BattleMove/Item/Trainer) -- so the same
-- rule is applied here. All 4 layouts are empirically confirmed against
-- real ROM data:
--   * NoItemDefaultMoves (partyFlags=0, stride 8): TRAINER_YOUNGSTER_BEN's
--     party decodes to RATTATA lvl 11 / EKANS lvl 11.
--   * NoItemCustomMoves (partyFlags=1, stride 16): TRAINER_CAMPER_LIAM's
--     first mon decodes to GEODUDE lvl 10, moves [TACKLE, DEFENSE_CURL,
--     NONE, NONE].
--   * ItemDefaultMoves (partyFlags=2, stride 8): TRAINER_BLACK_BELT_KOICHI's
--     first mon decodes to HITMONLEE lvl 37, iv 100, held item BLACK_BELT.
--   * ItemCustomMoves (partyFlags=3, stride 16): TRAINER_ELITE_FOUR_LORELEI's
--     first mon decodes to DEWGONG lvl 52, iv 250, held item NONE, moves
--     [ICE_BEAM, SURF, HAIL, SAFEGUARD].
-- All four match src/data/trainer_parties.h exactly.

local TrainerParty = {}

local F_TRAINER_PARTY_CUSTOM_MOVESET = 1
local F_TRAINER_PARTY_HELD_ITEM = 2

local byte = string.byte
local function u16le(record, offset0based)
  return byte(record, offset0based + 1) + byte(record, offset0based + 2) * 256
end

-- { stride, hasHeldItem, hasCustomMoves }, keyed by partyFlags (0-3).
local LAYOUTS = {
  [0] = { stride = 8, hasHeldItem = false, hasCustomMoves = false },  -- NoItemDefaultMoves (confirmed)
  [1] = { stride = 16, hasHeldItem = false, hasCustomMoves = true },  -- NoItemCustomMoves (confirmed)
  [2] = { stride = 8, hasHeldItem = true, hasCustomMoves = false },   -- ItemDefaultMoves (confirmed)
  [3] = { stride = 16, hasHeldItem = true, hasCustomMoves = true },   -- ItemCustomMoves (confirmed)
}

local function parseMon(record, layout)
  local mon = {
    iv = u16le(record, 0x00),
    lvl = byte(record, 0x03),
    species = u16le(record, 0x04),
  }
  local offset = 0x06
  if layout.hasHeldItem then
    mon.heldItem = u16le(record, offset)
    offset = offset + 2
  end
  if layout.hasCustomMoves then
    mon.moves = {}
    for i = 0, 3 do
      mon.moves[i] = u16le(record, offset + i * 2)
    end
  end
  return mon
end

-- trainer: a Trainer.parseRecord() result. data: full ROM bytes.
-- Returns a list of trainer.partySize parsed mon records.
function TrainerParty.resolve(trainer, data)
  local layout = LAYOUTS[trainer.partyFlags % 4]
  if not layout then
    error(("unrecognized partyFlags %d"):format(trainer.partyFlags))
  end

  local partyOffset = trainer.partyPtr - 0x08000000
  local out = {}
  for i = 0, trainer.partySize - 1 do
    local start = partyOffset + i * layout.stride
    local record = data:sub(start + 1, start + layout.stride)
    if #record < layout.stride then
      error(("trainer party read ran past end of data at index %d"):format(i))
    end
    out[i] = parseMon(record, layout)
  end
  return out
end

TrainerParty._LAYOUTS = LAYOUTS
TrainerParty.F_TRAINER_PARTY_CUSTOM_MOVESET = F_TRAINER_PARTY_CUSTOM_MOVESET
TrainerParty.F_TRAINER_PARTY_HELD_ITEM = F_TRAINER_PARTY_HELD_ITEM

return TrainerParty
