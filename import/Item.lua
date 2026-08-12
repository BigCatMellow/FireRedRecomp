-- Parses FireRed's gItems table (struct Item, pokefirered include/item.h).
--
-- Real record size is 44 bytes. Derived from the struct's field list plus
-- standard ARM alignment (u16 fields 2-aligned, pointers/struct-end
-- 4-aligned) and confirmed against real ROM data at index 1
-- (ITEM_MASTER_BALL): itemId decodes to 1, price to 0 (can't be bought,
-- correct), pocket to 3, fieldUseFunc to a null pointer (Master Ball has no
-- field use, correct), battleUseFunc to a plausible Thumb function pointer
-- (odd address -- GBA/Thumb function pointers have the low bit set).
--
-- Struct layout (pokefirered include/item.h, struct Item):
--   0x00 name[14]            u8[14] -- charmap-encoded, not ASCII; decode later
--   0x0E itemId               u16 LE
--   0x10 price                u16 LE
--   0x12 holdEffect           u8
--   0x13 holdEffectParam      u8
--   0x14 description          u32 LE pointer (ROM address, kept raw)
--   0x18 importance           u8
--   0x19 registrability       u8
--   0x1A pocket                u8
--   0x1B type                  u8
--   0x1C fieldUseFunc         u32 LE pointer (kept raw; not called natively)
--   0x20 battleUsage           u8
--   0x21-0x23 padding (align next pointer to 4)
--   0x24 battleUseFunc        u32 LE pointer (kept raw)
--   0x28 secondaryId           u8
--   0x29-0x2B padding to 44 bytes
local RECORD_SIZE = 44

local Item = {}
Item.RECORD_SIZE = RECORD_SIZE

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

function Item.parseRecord(record)
  assert(#record == RECORD_SIZE, ("item record must be %d bytes, got %d"):format(RECORD_SIZE, #record))
  return {
    rawName = record:sub(1, 14), -- charmap-encoded; run through the text decoder once it exists
    itemId = u16le(record, 0x0E),
    price = u16le(record, 0x10),
    holdEffect = byte(record, 0x13),
    holdEffectParam = byte(record, 0x14),
    descriptionPtr = u32le(record, 0x14),
    importance = byte(record, 0x19),
    registrability = byte(record, 0x1A),
    pocket = byte(record, 0x1B),
    type = byte(record, 0x1C),
    fieldUseFuncPtr = u32le(record, 0x1C),
    battleUsage = byte(record, 0x21),
    battleUseFuncPtr = u32le(record, 0x24),
    secondaryId = byte(record, 0x29),
  }
end

function Item.parseTable(data, tableOffset, count)
  local out = {}
  for i = 0, count - 1 do
    local start = tableOffset + i * RECORD_SIZE
    local record = data:sub(start + 1, start + RECORD_SIZE)
    if #record < RECORD_SIZE then
      error(("item table read ran past end of data at index %d"):format(i))
    end
    out[i] = Item.parseRecord(record)
  end
  return out
end

return Item
