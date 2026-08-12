-- Parses FireRed's gTrainers table (struct Trainer, pokefirered
-- include/battle.h). The struct's own comments already give exact byte
-- offsets, unlike SpeciesInfo/BattleMove/Item -- but the *overall* record
-- size still isn't in the header (that only comes from array-element
-- stride, i.e. real linked data), so it was confirmed the same way as
-- everything else here: decoding real ROM bytes and checking known values.
-- TRAINER_YOUNGSTER_BEN (index 89) decodes to name="BEN", partySize=2,
-- matching pokefirered src/data/trainers.h exactly.
--
-- Struct layout (pokefirered include/battle.h, struct Trainer):
--   0x00 partyFlags              u8
--   0x01 trainerClass            u8
--   0x02 encounterMusic_gender   u8 (low bits: music; high bit: gender)
--   0x03 trainerPic              u8
--   0x04 trainerName[12]         u8[12] -- charmap-encoded
--   0x10 items[4]                u16[4] LE -- MAX_TRAINER_ITEMS
--   0x18 doubleBattle            u8 (bool8)
--   0x19-0x1B padding (align aiFlags to 4)
--   0x1C aiFlags                 u32 LE
--   0x20 partySize               u8
--   0x21-0x23 padding (align party to 4)
--   0x24 party                   u32 LE pointer (union TrainerMonPtr, kept
--                                 raw -- format depends on partyFlags bits
--                                 F_TRAINER_PARTY_CUSTOM_MOVESET /
--                                 F_TRAINER_PARTY_HELD_ITEM; resolving the
--                                 pointed-to party data is separate work)
--   record size: 0x28 = 40 bytes
local RECORD_SIZE = 40

local Trainer = {}
Trainer.RECORD_SIZE = RECORD_SIZE

local byte = string.byte

local function u16le(record, offset0based)
  return byte(record, offset0based + 1) + byte(record, offset0based + 2) * 256
end

local function u32le(record, offset0based)
  return byte(record, offset0based + 1)
    + byte(record, offset0based + 2) * 256
    + byte(record, offset0based + 3) * 65536
    + byte(record, offset0based + 4) * 16777216
end

function Trainer.parseRecord(record)
  assert(#record == RECORD_SIZE, ("trainer record must be %d bytes, got %d"):format(RECORD_SIZE, #record))

  local encounterMusicGender = byte(record, 0x03)
  local items = {}
  for i = 0, 3 do
    items[i] = u16le(record, 0x10 + i * 2)
  end

  return {
    partyFlags = byte(record, 0x01),
    trainerClass = byte(record, 0x02),
    encounterMusic = encounterMusicGender % 128,
    isFemale = math.floor(encounterMusicGender / 128) % 2 == 1,
    trainerPic = byte(record, 0x04),
    rawName = record:sub(5, 16),
    items = items,
    doubleBattle = byte(record, 0x19) ~= 0,
    aiFlags = u32le(record, 0x1C),
    partySize = byte(record, 0x21),
    partyPtr = u32le(record, 0x24),
  }
end

function Trainer.parseTable(data, tableOffset, count)
  local out = {}
  for i = 0, count - 1 do
    local start = tableOffset + i * RECORD_SIZE
    local record = data:sub(start + 1, start + RECORD_SIZE)
    if #record < RECORD_SIZE then
      error(("trainer table read ran past end of data at index %d"):format(i))
    end
    out[i] = Trainer.parseRecord(record)
  end
  return out
end

return Trainer
