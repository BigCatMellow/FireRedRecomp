-- Parses FireRed's gSpeciesInfo table (struct SpeciesInfo, pokefirered
-- include/pokemon.h) out of raw ROM bytes. 28 bytes per record, National
-- Dex order starting at species index 0 (SPECIES_NONE).
--
-- This module does NOT know the table's ROM address. That address is a
-- property of the linked retail ROM, not of the decomp source tree as
-- checked out (addresses only exist after building pokefirered and reading
-- its .map, or from a verified symbol list for the retail build). Wiring up
-- a real address belongs to the importer's symbol-resolution step, tracked
-- as a Phase 1 follow-up — see PARITY_CONTRACT.md's behavior ledger.
--
-- Struct layout (pokefirered include/pokemon.h, struct SpeciesInfo):
--   0x00 baseHP            u8
--   0x01 baseAttack        u8
--   0x02 baseDefense       u8
--   0x03 baseSpeed         u8
--   0x04 baseSpAttack      u8
--   0x05 baseSpDefense     u8
--   0x06 types[2]          u8 u8
--   0x08 catchRate         u8
--   0x09 expYield          u8
--   0x0A evYield bitfield  u16 (2 bits each: HP,Atk,Def,Speed,SpAtk,SpDef)
--   0x0C itemCommon        u16 LE
--   0x0E itemRare          u16 LE
--   0x10 genderRatio       u8
--   0x11 eggCycles         u8
--   0x12 friendship        u8
--   0x13 growthRate        u8
--   0x14 eggGroups[2]      u8 u8
--   0x16 abilities[2]      u8 u8
--   0x18 safariZoneFleeRate u8
--   0x19 bodyColor:7, noFlip:1  u8
--   0x1A-0x1B padding to 28 bytes total
local RECORD_SIZE = 28

local SpeciesInfo = {}
SpeciesInfo.RECORD_SIZE = RECORD_SIZE

local byte = string.byte

local function u16le(data, offset)
  -- offset is 0-based into data; string indices are 1-based.
  return byte(data, offset + 1) + byte(data, offset + 2) * 256
end

-- record: a RECORD_SIZE-byte string for exactly one species.
function SpeciesInfo.parseRecord(record)
  assert(#record == RECORD_SIZE, ("species record must be %d bytes, got %d"):format(RECORD_SIZE, #record))

  local evBits = u16le(record, 0x0A)
  local bodyColorByte = byte(record, 0x1A)

  return {
    baseHP = byte(record, 0x01),
    baseAttack = byte(record, 0x02),
    baseDefense = byte(record, 0x03),
    baseSpeed = byte(record, 0x04),
    baseSpAttack = byte(record, 0x05),
    baseSpDefense = byte(record, 0x06),
    types = { byte(record, 0x07), byte(record, 0x08) },
    catchRate = byte(record, 0x09),
    expYield = byte(record, 0x0A),
    evYield = {
      hp = evBits % 4,
      attack = math.floor(evBits / 4) % 4,
      defense = math.floor(evBits / 16) % 4,
      speed = math.floor(evBits / 64) % 4,
      spAttack = math.floor(evBits / 256) % 4,
      spDefense = math.floor(evBits / 1024) % 4,
    },
    itemCommon = u16le(record, 0x0C),
    itemRare = u16le(record, 0x0E),
    genderRatio = byte(record, 0x11),
    eggCycles = byte(record, 0x12),
    friendship = byte(record, 0x13),
    growthRate = byte(record, 0x14),
    eggGroups = { byte(record, 0x15), byte(record, 0x16) },
    abilities = { byte(record, 0x17), byte(record, 0x18) },
    safariZoneFleeRate = byte(record, 0x19),
    bodyColor = bodyColorByte % 128,
    noFlip = math.floor(bodyColorByte / 128) % 2 == 1,
  }
end

-- data: full ROM bytes. tableOffset: 0-based byte offset of gSpeciesInfo[0]
-- within `data`. count: how many consecutive records to read.
function SpeciesInfo.parseTable(data, tableOffset, count)
  local out = {}
  for i = 0, count - 1 do
    local start = tableOffset + i * RECORD_SIZE
    local record = data:sub(start + 1, start + RECORD_SIZE)
    if #record < RECORD_SIZE then
      error(("species table read ran past end of data at index %d"):format(i))
    end
    out[i] = SpeciesInfo.parseRecord(record)
  end
  return out
end

return SpeciesInfo
