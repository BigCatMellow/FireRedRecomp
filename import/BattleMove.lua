-- Parses FireRed's gBattleMoves table (struct BattleMove, pokefirered
-- include/pokemon.h).
--
-- The struct's field list is 9 bytes (all u8/s8), but the real ROM record
-- is 12 bytes: agbcc pads struct-array elements to a 4-byte multiple even
-- when every member is byte-sized. Confirmed against real ROM data --
-- MOVE_POUND (index 1) and MOVE_KARATE_CHOP (index 2) decode correctly at
-- a 12-byte stride and NOT at a 9-byte stride. Don't "fix" this back to 9
-- without re-checking against the ROM.
--
-- Struct layout (pokefirered include/pokemon.h, struct BattleMove):
--   0x00 effect                 u8
--   0x01 power                  u8
--   0x02 type                   u8
--   0x03 accuracy               u8
--   0x04 pp                     u8
--   0x05 secondaryEffectChance  u8
--   0x06 target                 u8
--   0x07 priority               s8 (signed -- e.g. Quick Attack is +1, Counter is -5)
--   0x08 flags                  u8
--   0x09-0x0B padding to 12 bytes
local RECORD_SIZE = 12

local BattleMove = {}
BattleMove.RECORD_SIZE = RECORD_SIZE

local byte = string.byte

local function s8(record, index1based)
  local b = byte(record, index1based)
  if b >= 128 then return b - 256 end
  return b
end

function BattleMove.parseRecord(record)
  assert(#record == RECORD_SIZE, ("battle move record must be %d bytes, got %d"):format(RECORD_SIZE, #record))
  return {
    effect = byte(record, 0x01),
    power = byte(record, 0x02),
    type = byte(record, 0x03),
    accuracy = byte(record, 0x04),
    pp = byte(record, 0x05),
    secondaryEffectChance = byte(record, 0x06),
    target = byte(record, 0x07),
    priority = s8(record, 0x08),
    flags = byte(record, 0x09),
  }
end

function BattleMove.parseTable(data, tableOffset, count)
  local out = {}
  for i = 0, count - 1 do
    local start = tableOffset + i * RECORD_SIZE
    local record = data:sub(start + 1, start + RECORD_SIZE)
    if #record < RECORD_SIZE then
      error(("battle move table read ran past end of data at index %d"):format(i))
    end
    out[i] = BattleMove.parseRecord(record)
  end
  return out
end

return BattleMove
