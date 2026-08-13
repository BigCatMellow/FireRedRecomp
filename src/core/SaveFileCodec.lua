-- Real save-file byte format: encode/decode an in-memory save state (the
-- shape defined by SaveBlockLayout.lua) into actual FireRed on-disk save
-- bytes, and back. Transcribed from pokefirered's real save system:
--   * src/save.c: HandleWriteSector/HandleSavingData/TrySavingData
--     (write path), CopySaveSlotData/GetSaveValidStatus/TryLoadSaveSlot/
--     LoadGameSave (read/validate/slot-selection path), CalculateChecksum
--     (checksum algorithm).
--   * include/save.h: struct SaveSector, struct SaveSectorLocation,
--     SECTOR_DATA_SIZE/SECTOR_FOOTER_SIZE/SECTOR_SIZE/SECTOR_SIGNATURE/
--     NUM_SAVE_SLOTS/NUM_SECTORS_PER_SLOT/SECTOR_ID_* constants.
--
-- REAL SECTOR/SLOT SCHEME (src/save.c's own header comment + save.h):
--   Each save is split into 4 KiB "sectors" (struct SaveSector): 3968
--   bytes of section data (SECTOR_DATA_SIZE) + a 128-byte footer of which
--   only 12 bytes are used: u16 id, u16 checksum, u32 signature
--   (SECTOR_SIGNATURE == 0x08012025, marks a sector as written/valid),
--   u32 counter (the save-generation number, `gSaveCounter`).
--   Real layout: sectors 0-13 = save slot 1, sectors 14-27 = save slot 2
--   (NUM_SECTORS_PER_SLOT == 14, NUM_SAVE_SLOTS == 2); within a slot,
--   sector id 0 = SaveBlock2, ids 1-4 = SaveBlock1 split into 4 chunks of
--   up to SECTOR_DATA_SIZE bytes each (sSaveSlotLayout's SAVEBLOCK_CHUNK
--   macro, transcribed below as chunkInfo()), ids 5-13 = struct
--   PokemonStorage (PC boxes) split into 9 chunks.
--   The game alternates which physical slot it writes to every save
--   (`gSaveCounter % NUM_SAVE_SLOTS` inside HandleWriteSector/
--   HandleReplaceSector), so a power-loss mid-write can only ever corrupt
--   the slot NOT holding the previous good save. GetSaveValidStatus reads
--   every sector of BOTH physical slots, verifies each sector's signature
--   + checksum, and only accepts a slot if every sector in it is valid
--   (`validSectors == ALL_SECTORS`); when both slots are fully valid it
--   picks the one with the higher `counter` (see chooseNewerCounter()
--   below, transcribed from GetSaveValidStatus lines ~534-550).
--
-- REAL CHECKSUM (CalculateChecksum, src/save.c): NOT a CRC. It's a
-- straight little-endian-u32-word additive checksum: sum every 4-byte
-- word of the sector's data (size/4 whole words -- any 1-3 trailing
-- bytes that don't fill a whole word are NOT included, matching the
-- real `for (i = 0; i < size/4; i++)` integer-division loop exactly),
-- wrapping at 32 bits, then fold: `(checksum >> 16) + checksum`,
-- truncated to a u16 (the function's real return type). See
-- calculateChecksum() below -- transcribed 1:1, not a guessed variant.
--
-- SCOPE (per this project's SaveBlockLayout.lua, deliberately partial):
-- only sector ids 0-4 (SaveBlock2 + SaveBlock1) are modeled/produced by
-- this codec. Real sector ids 5-13 (struct PokemonStorage / PC boxes)
-- are NOT written here -- PcBoxes.lua is an in-memory container only and
-- has no real on-disk PokemonStorage layout transcribed yet (that's a
-- SaveBlockLayout.lua gap, not this codec's to invent). Real Hall of
-- Fame / Trainer Tower sectors (28-31) are entirely out of scope too.
-- The physical sector-rotation-within-a-slot behavior (HandleWriteSector
-- rotating `gLastWrittenSector` to spread wear across flash) is also not
-- modeled -- it's a flash-wear optimization irrelevant to an in-memory
-- byte buffer with no real flash underneath; sector ids are always
-- written/read at their fixed logical position within each slot here.
--
-- PROJECT-SPECIFIC VERSION WRAPPER (NOT from src/save.c -- FireRed does
-- not version its own save format): every buffer this codec produces
-- starts with an 8-byte header, MAGIC ("FRSV") + VERSION (u8) + 3
-- reserved zero bytes, ahead of the two real 5-sector slots. decode()
-- refuses (returns nil, error) any buffer whose magic/version doesn't
-- match, rather than guessing how to read a shape SaveBlockLayout.lua
-- may have changed since. This is deliberately minimal -- a single
-- current schema version, no migration framework.
--
-- No `bit` library / Lua 5.3 bitwise ops (LuaJIT + plain Lua 5.1
-- compatibility) -- byte-wise XOR done via a div/mod bit loop, same
-- established pattern as BoxPokemonCodec.lua's XOR8 table (this module's
-- XOR operands are used far less often, so a plain per-call bit loop is
-- used instead of a precomputed table).

local SaveBlockLayout = require("src.core.SaveBlockLayout")

local SaveFileCodec = {}

local byte = string.byte
local char = string.char

--------------------------------------------------------------------------
-- Real save.h constants
--------------------------------------------------------------------------

local SECTOR_DATA_SIZE = 3968
local SECTOR_FOOTER_SIZE = 128
local SECTOR_SIZE = SECTOR_DATA_SIZE + SECTOR_FOOTER_SIZE -- 4096
local NUM_SAVE_SLOTS = 2
local SECTOR_SIGNATURE = 0x08012025

local SECTOR_ID_SAVEBLOCK2 = 0
local SECTOR_ID_SAVEBLOCK1_START = 1
local SECTOR_ID_SAVEBLOCK1_END = 4
local NUM_SECTORS_MODELED = 5 -- ids 0-4 only; see header "SCOPE" note

SaveFileCodec.SECTOR_DATA_SIZE = SECTOR_DATA_SIZE
SaveFileCodec.SECTOR_SIZE = SECTOR_SIZE
SaveFileCodec.NUM_SAVE_SLOTS = NUM_SAVE_SLOTS
SaveFileCodec.NUM_SECTORS_MODELED = NUM_SECTORS_MODELED
SaveFileCodec.SECTOR_SIGNATURE = SECTOR_SIGNATURE

--------------------------------------------------------------------------
-- Project-specific version wrapper (not real save format)
--------------------------------------------------------------------------

SaveFileCodec.MAGIC = "FRSV"
SaveFileCodec.VERSION = 1
local HEADER_SIZE = 8 -- 4-byte magic + 1-byte version + 3 reserved bytes
SaveFileCodec.HEADER_SIZE = HEADER_SIZE

local SLOT_BYTES = NUM_SECTORS_MODELED * SECTOR_SIZE -- 5 * 4096 = 20480
SaveFileCodec.SLOT_BYTES = SLOT_BYTES

--------------------------------------------------------------------------
-- Low-level byte helpers (little-endian, 0-based offsets into a mutable
-- byte-table buffer; final output built with table.concat)
--------------------------------------------------------------------------

local function newBuffer(size)
  local buf = {}
  for i = 1, size do buf[i] = "\0" end
  return buf
end

local function setBytes(buf, off, str)
  for i = 1, #str do
    buf[off + i] = str:sub(i, i)
  end
end

local function setU8(buf, off, v)
  buf[off + 1] = char((v or 0) % 256)
end

local function setS8(buf, off, v)
  v = v or 0
  if v < 0 then v = v + 256 end
  setU8(buf, off, v)
end

local function setU16(buf, off, v)
  v = v or 0
  buf[off + 1] = char(v % 256)
  buf[off + 2] = char(math.floor(v / 256) % 256)
end

local function setS16(buf, off, v)
  v = v or 0
  if v < 0 then v = v + 65536 end
  setU16(buf, off, v)
end

local function setU32(buf, off, v)
  v = v or 0
  buf[off + 1] = char(v % 256)
  buf[off + 2] = char(math.floor(v / 256) % 256)
  buf[off + 3] = char(math.floor(v / 65536) % 256)
  buf[off + 4] = char(math.floor(v / 16777216) % 256)
end

local function readU8(s, off) return byte(s, off + 1) end

local function readS8(s, off)
  local v = readU8(s, off)
  if v >= 128 then v = v - 256 end
  return v
end

local function readU16(s, off)
  return byte(s, off + 1) + byte(s, off + 2) * 256
end

local function readS16(s, off)
  local v = readU16(s, off)
  if v >= 32768 then v = v - 65536 end
  return v
end

local function readU32(s, off)
  return byte(s, off + 1) + byte(s, off + 2) * 256
    + byte(s, off + 3) * 65536 + byte(s, off + 4) * 16777216
end

-- Bitwise XOR of two non-negative integers over `bits` width, via
-- div/mod (no bit library -- see header comment).
local function xorInt(a, b, bits)
  a, b = a or 0, b or 0
  local result, pw = 0, 1
  for _ = 1, bits do
    local abit, bbit = a % 2, b % 2
    if abit ~= bbit then result = result + pw end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    pw = pw * 2
  end
  return result
end

--------------------------------------------------------------------------
-- Real CalculateChecksum (src/save.c) -- additive u32-word checksum, NOT
-- CRC. `data` is a raw byte string, `size` the real byte count (trailing
-- 1-3 bytes that don't fill a whole u32 word are excluded, matching the
-- real `size / 4` integer-division loop bound).
--------------------------------------------------------------------------

local function calculateChecksum(data, size)
  local checksum = 0
  local words = math.floor(size / 4)
  for i = 0, words - 1 do
    checksum = checksum + readU32(data, i * 4)
  end
  checksum = checksum % 4294967296 -- wrap at 32 bits (u32 accumulator)
  return math.floor(checksum / 65536 + checksum) % 65536
end
SaveFileCodec.calculateChecksum = calculateChecksum

--------------------------------------------------------------------------
-- Real SAVEBLOCK_CHUNK macro (src/save.c): given a struct's total byte
-- size and a 0-based chunk number, returns (offset, size) of that chunk
-- within the struct, each chunk capped at SECTOR_DATA_SIZE bytes.
--------------------------------------------------------------------------

local function chunkInfo(structSize, chunkNum)
  local offset = chunkNum * SECTOR_DATA_SIZE
  local size
  if structSize >= offset then
    size = math.min(structSize - offset, SECTOR_DATA_SIZE)
  else
    size = 0
  end
  return offset, size
end

--------------------------------------------------------------------------
-- WarpData (8 bytes) / ItemSlot (4 bytes) / Coords16 (4 bytes) struct
-- codecs -- shapes come straight from SaveBlockLayout.lua's WARP_DATA/
-- ITEM_SLOT locals (re-declared here since those locals aren't exported,
-- but the field offsets/sizes are cross-checked against
-- SaveBlockLayout.SaveBlock1/SaveBlock2 field entries below).
--------------------------------------------------------------------------

local function encodeWarpData(buf, base, v)
  v = v or {}
  setS8(buf, base + 0, v.mapGroup)
  setS8(buf, base + 1, v.mapNum)
  setS8(buf, base + 2, v.warpId)
  setS16(buf, base + 4, v.x)
  setS16(buf, base + 6, v.y)
end

local function decodeWarpData(s, base)
  return {
    mapGroup = readS8(s, base + 0),
    mapNum = readS8(s, base + 1),
    warpId = readS8(s, base + 2),
    x = readS16(s, base + 4),
    y = readS16(s, base + 6),
  }
end

local function encodeItemSlot(buf, base, v, quantityKey)
  v = v or {}
  setU16(buf, base + 0, v.itemId)
  local q = v.quantity or 0
  if quantityKey then q = xorInt(q, quantityKey, 16) end
  setU16(buf, base + 2, q)
end

local function decodeItemSlot(s, base, quantityKey)
  local itemId = readU16(s, base + 0)
  local q = readU16(s, base + 2)
  if quantityKey then q = xorInt(q, quantityKey, 16) end
  return { itemId = itemId, quantity = q }
end

--------------------------------------------------------------------------
-- Pokedex struct (0x78 bytes) -- see SaveBlockLayout.lua's POKEDEX local.
--------------------------------------------------------------------------

local function encodePokedex(buf, base, v)
  v = v or {}
  setU8(buf, base + 0x00, v.order)
  setU8(buf, base + 0x01, v.mode)
  setU8(buf, base + 0x02, v.unused)
  setU8(buf, base + 0x03, v.nationalMagic)
  setU32(buf, base + 0x04, v.unownPersonality)
  setU32(buf, base + 0x08, v.spindaPersonality)
  setU32(buf, base + 0x0C, v.unknown3)
  setBytes(buf, base + 0x10, (v.owned or "\0"):sub(1, 52) .. string.rep("\0", math.max(0, 52 - #(v.owned or ""))))
  setBytes(buf, base + 0x44, (v.seen or "\0"):sub(1, 52) .. string.rep("\0", math.max(0, 52 - #(v.seen or ""))))
end

local function decodePokedex(s, base)
  return {
    order = readU8(s, base + 0x00),
    mode = readU8(s, base + 0x01),
    unused = readU8(s, base + 0x02),
    nationalMagic = readU8(s, base + 0x03),
    unownPersonality = readU32(s, base + 0x04),
    spindaPersonality = readU32(s, base + 0x08),
    unknown3 = readU32(s, base + 0x0C),
    owned = s:sub(base + 0x10 + 1, base + 0x10 + 52),
    seen = s:sub(base + 0x44 + 1, base + 0x44 + 52),
  }
end

--------------------------------------------------------------------------
-- Party Pokemon slot (100 bytes -- see SaveBlockLayout.lua's playerParty
-- comment: 80-byte BoxPokemon-shaped `box` payload, matching
-- BoxPokemonCodec.lua's on-disk 80-byte format verbatim, immediately
-- followed by struct Pokemon's extra battle-stat-cache fields: u32
-- status, u8 level, u8 mail, then 7x u16 (hp/maxHP/attack/defense/speed/
-- spAttack/spDefense)). SaveBlockLayout.lua doesn't sub-model these 20
-- extra bytes field-by-field (it only cross-checks the 100-byte slot
-- total), so the field list here is transcribed directly from struct
-- Pokemon (include/pokemon.h) instead.
--------------------------------------------------------------------------

local PARTY_MON_SIZE = 100
local BOX_MON_SIZE = 80

local function encodePartyMon(buf, base, mon)
  mon = mon or {}
  local box = mon.box or string.rep("\0", BOX_MON_SIZE)
  if #box ~= BOX_MON_SIZE then
    box = (box .. string.rep("\0", BOX_MON_SIZE)):sub(1, BOX_MON_SIZE)
  end
  setBytes(buf, base, box)
  setU32(buf, base + 80, mon.status)
  setU8(buf, base + 84, mon.level)
  setU8(buf, base + 85, mon.mail)
  setU16(buf, base + 86, mon.hp)
  setU16(buf, base + 88, mon.maxHP)
  setU16(buf, base + 90, mon.attack)
  setU16(buf, base + 92, mon.defense)
  setU16(buf, base + 94, mon.speed)
  setU16(buf, base + 96, mon.spAttack)
  setU16(buf, base + 98, mon.spDefense)
end

local function decodePartyMon(s, base)
  return {
    box = s:sub(base + 1, base + BOX_MON_SIZE),
    status = readU32(s, base + 80),
    level = readU8(s, base + 84),
    mail = readU8(s, base + 85),
    hp = readU16(s, base + 86),
    maxHP = readU16(s, base + 88),
    attack = readU16(s, base + 90),
    defense = readU16(s, base + 92),
    speed = readU16(s, base + 94),
    spAttack = readU16(s, base + 96),
    spDefense = readU16(s, base + 98),
  }
end

--------------------------------------------------------------------------
-- SaveBlock2 encode/decode (offsets sourced from SaveBlockLayout.SaveBlock2)
--
-- Options bitfields (optionsTextSpeed/optionsWindowFrameType at 0x014,
-- optionsSound/optionsBattleStyle/optionsBattleSceneOff/regionMapZoom at
-- 0x016): SaveBlockLayout.lua's own header says it "doesn't compute
-- bit-exact packing" for these (real ARM EABI bitfield packing wasn't
-- needed for default-value modeling there). This codec needs SOME byte
-- representation to round-trip them, so it packs each byte's fields
-- LSB-first in field-declaration order (textSpeed:3 + windowFrameType:5
-- in the first byte; sound:1 + battleStyle:1 + battleSceneOff:1 +
-- regionMapZoom:1 in the second). This is this project's own simplified
-- packing, NOT verified bit-for-bit against the real compiled struct
-- layout -- flagged here same as SaveBlockLayout.lua flags it.
--------------------------------------------------------------------------

local SB2 = SaveBlockLayout.SaveBlock2
local SB2_SIZE = SB2.size

function SaveFileCodec.encodeSaveBlock2(sb2)
  sb2 = sb2 or {}
  local buf = newBuffer(SB2_SIZE)
  setBytes(buf, 0x000, ((sb2.playerName or "") .. string.rep("\0", 8)):sub(1, 8))
  setU8(buf, 0x008, sb2.playerGender)
  setU8(buf, 0x009, sb2.specialSaveWarpFlags)
  setBytes(buf, 0x00A, ((sb2.playerTrainerId or "") .. string.rep("\0", 4)):sub(1, 4))
  setU16(buf, 0x00E, sb2.playTimeHours)
  setU8(buf, 0x010, sb2.playTimeMinutes)
  setU8(buf, 0x011, sb2.playTimeSeconds)
  setU8(buf, 0x012, sb2.playTimeVBlanks)
  setU8(buf, 0x013, sb2.optionsButtonMode)

  local options = sb2.options or {}
  local textSpeedByte = (options.textSpeed or 0) % 8 + ((options.windowFrameType or 0) % 32) * 8
  setU8(buf, 0x014, textSpeedByte)
  local flagsByte = (options.sound and 1 or 0) + (options.battleStyle and 1 or 0) * 2
    + (options.battleSceneOff and 1 or 0) * 4 + (options.regionMapZoom and 1 or 0) * 8
  setU8(buf, 0x016, flagsByte)

  encodePokedex(buf, 0x018, sb2.pokedex)
  setU32(buf, 0x0A8, sb2.gcnLinkFlags)
  setU8(buf, 0x0AC, sb2.unkFlag1 and 1 or 0)
  setU8(buf, 0x0AD, sb2.unkFlag2 and 1 or 0)
  setU32(buf, 0xF20, sb2.encryptionKey)
  return table.concat(buf)
end

function SaveFileCodec.decodeSaveBlock2(s)
  assert(#s == SB2_SIZE, ("SaveBlock2 bytes must be %d bytes, got %d"):format(SB2_SIZE, #s))
  local textSpeedByte = readU8(s, 0x014)
  local flagsByte = readU8(s, 0x016)
  return {
    playerName = s:sub(0x000 + 1, 0x000 + 8),
    playerGender = readU8(s, 0x008),
    specialSaveWarpFlags = readU8(s, 0x009),
    playerTrainerId = s:sub(0x00A + 1, 0x00A + 4),
    playTimeHours = readU16(s, 0x00E),
    playTimeMinutes = readU8(s, 0x010),
    playTimeSeconds = readU8(s, 0x011),
    playTimeVBlanks = readU8(s, 0x012),
    optionsButtonMode = readU8(s, 0x013),
    options = {
      textSpeed = textSpeedByte % 8,
      windowFrameType = math.floor(textSpeedByte / 8) % 32,
      sound = flagsByte % 2 == 1,
      battleStyle = math.floor(flagsByte / 2) % 2 == 1,
      battleSceneOff = math.floor(flagsByte / 4) % 2 == 1,
      regionMapZoom = math.floor(flagsByte / 8) % 2 == 1,
    },
    pokedex = decodePokedex(s, 0x018),
    gcnLinkFlags = readU32(s, 0x0A8),
    unkFlag1 = readU8(s, 0x0AC) == 1,
    unkFlag2 = readU8(s, 0x0AD) == 1,
    encryptionKey = readU32(s, 0xF20),
  }
end

--------------------------------------------------------------------------
-- SaveBlock1 encode/decode (offsets sourced from SaveBlockLayout.SaveBlock1).
-- encryptionKey (from the paired SaveBlock2) is required: money.c's
-- SetMoney/GetMoney and item.c's SetBagItemQuantity/GetBagItemQuantity
-- both XOR against it (see Money.lua/Bag.lua headers) -- pcItems'
-- quantity is explicitly NOT XORed (GetPcItemQuantity does `0 ^ *ptr`,
-- src/item.c), transcribed exactly as that asymmetry.
--------------------------------------------------------------------------

local SB1 = SaveBlockLayout.SaveBlock1
local SB1_SIZE = SB1.size

local BAG_POCKET_FIELDS = {
  "bagPocket_Items", "bagPocket_KeyItems", "bagPocket_PokeBalls",
  "bagPocket_TMHM", "bagPocket_Berries",
}
local BAG_POCKET_SET = {}
for _, name in ipairs(BAG_POCKET_FIELDS) do BAG_POCKET_SET[name] = true end

local function findField(fields, name)
  for _, f in ipairs(fields) do
    if f.name == name then return f end
  end
  error("no such field: " .. name)
end

function SaveFileCodec.encodeSaveBlock1(sb1, encryptionKey)
  sb1 = sb1 or {}
  encryptionKey = encryptionKey or 0
  local buf = newBuffer(SB1_SIZE)

  local pos = findField(SB1.fields, "pos").offset
  setS16(buf, pos + 0, (sb1.pos or {}).x)
  setS16(buf, pos + 2, (sb1.pos or {}).y)

  for _, warpName in ipairs({ "location", "continueGameWarp", "dynamicWarp", "lastHealLocation", "escapeWarp" }) do
    local off = findField(SB1.fields, warpName).offset
    encodeWarpData(buf, off, sb1[warpName])
  end

  setU16(buf, findField(SB1.fields, "savedMusic").offset, sb1.savedMusic)
  setU8(buf, findField(SB1.fields, "weather").offset, sb1.weather)
  setU8(buf, findField(SB1.fields, "weatherCycleStage").offset, sb1.weatherCycleStage)
  setU8(buf, findField(SB1.fields, "flashLevel").offset, sb1.flashLevel)
  setU16(buf, findField(SB1.fields, "mapLayoutId").offset, sb1.mapLayoutId)
  setU8(buf, findField(SB1.fields, "playerPartyCount").offset, sb1.playerPartyCount)

  local partyOff = findField(SB1.fields, "playerParty").offset
  local party = sb1.playerParty or {}
  for i = 0, 5 do
    encodePartyMon(buf, partyOff + i * PARTY_MON_SIZE, party[i + 1])
  end

  local money = xorInt(sb1.money or 0, encryptionKey, 32)
  setU32(buf, findField(SB1.fields, "money").offset, money)
  setU16(buf, findField(SB1.fields, "coins").offset, sb1.coins)
  setU16(buf, findField(SB1.fields, "registeredItem").offset, sb1.registeredItem)

  local pcItemsOff = findField(SB1.fields, "pcItems").offset
  local pcItems = sb1.pcItems or {}
  for i = 0, 29 do
    encodeItemSlot(buf, pcItemsOff + i * 4, pcItems[i + 1], nil) -- not XORed, see header
  end

  local bagKey16 = encryptionKey % 65536
  for _, pocketName in ipairs(BAG_POCKET_FIELDS) do
    local field = findField(SB1.fields, pocketName)
    local count = tonumber(field.type:match("%[(%d+)%]"))
    local pocketData = sb1[pocketName] or {}
    for i = 0, count - 1 do
      encodeItemSlot(buf, field.offset + i * 4, pocketData[i + 1], bagKey16)
    end
  end

  setBytes(buf, findField(SB1.fields, "seen1").offset, ((sb1.seen1 or "") .. string.rep("\0", 52)):sub(1, 52))
  setBytes(buf, findField(SB1.fields, "flags").offset, ((sb1.flags or "") .. string.rep("\0", 288)):sub(1, 288))

  local varsOff = findField(SB1.fields, "vars").offset
  local vars = sb1.vars or {}
  for i = 0, 255 do
    setU16(buf, varsOff + i * 2, vars[i + 1])
  end

  local statsOff = findField(SB1.fields, "gameStats").offset
  local stats = sb1.gameStats or {}
  for i = 0, 63 do
    setU32(buf, statsOff + i * 4, stats[i + 1])
  end

  setBytes(buf, findField(SB1.fields, "rivalName").offset, ((sb1.rivalName or "") .. string.rep("\0", 8)):sub(1, 8))

  return table.concat(buf)
end

function SaveFileCodec.decodeSaveBlock1(s, encryptionKey)
  assert(#s == SB1_SIZE, ("SaveBlock1 bytes must be %d bytes, got %d"):format(SB1_SIZE, #s))
  encryptionKey = encryptionKey or 0
  local out = {}

  local posOff = findField(SB1.fields, "pos").offset
  out.pos = { x = readS16(s, posOff + 0), y = readS16(s, posOff + 2) }

  for _, warpName in ipairs({ "location", "continueGameWarp", "dynamicWarp", "lastHealLocation", "escapeWarp" }) do
    out[warpName] = decodeWarpData(s, findField(SB1.fields, warpName).offset)
  end

  out.savedMusic = readU16(s, findField(SB1.fields, "savedMusic").offset)
  out.weather = readU8(s, findField(SB1.fields, "weather").offset)
  out.weatherCycleStage = readU8(s, findField(SB1.fields, "weatherCycleStage").offset)
  out.flashLevel = readU8(s, findField(SB1.fields, "flashLevel").offset)
  out.mapLayoutId = readU16(s, findField(SB1.fields, "mapLayoutId").offset)
  out.playerPartyCount = readU8(s, findField(SB1.fields, "playerPartyCount").offset)

  local partyOff = findField(SB1.fields, "playerParty").offset
  out.playerParty = {}
  for i = 0, 5 do
    out.playerParty[i + 1] = decodePartyMon(s, partyOff + i * PARTY_MON_SIZE)
  end

  out.money = xorInt(readU32(s, findField(SB1.fields, "money").offset), encryptionKey, 32)
  out.coins = readU16(s, findField(SB1.fields, "coins").offset)
  out.registeredItem = readU16(s, findField(SB1.fields, "registeredItem").offset)

  local pcItemsOff = findField(SB1.fields, "pcItems").offset
  out.pcItems = {}
  for i = 0, 29 do
    out.pcItems[i + 1] = decodeItemSlot(s, pcItemsOff + i * 4, nil)
  end

  local bagKey16 = encryptionKey % 65536
  for _, pocketName in ipairs(BAG_POCKET_FIELDS) do
    local field = findField(SB1.fields, pocketName)
    local count = tonumber(field.type:match("%[(%d+)%]"))
    local pocketOut = {}
    for i = 0, count - 1 do
      pocketOut[i + 1] = decodeItemSlot(s, field.offset + i * 4, bagKey16)
    end
    out[pocketName] = pocketOut
  end

  out.seen1 = s:sub(findField(SB1.fields, "seen1").offset + 1, findField(SB1.fields, "seen1").offset + 52)
  out.flags = s:sub(findField(SB1.fields, "flags").offset + 1, findField(SB1.fields, "flags").offset + 288)

  local varsOff = findField(SB1.fields, "vars").offset
  out.vars = {}
  for i = 0, 255 do
    out.vars[i + 1] = readU16(s, varsOff + i * 2)
  end

  local statsOff = findField(SB1.fields, "gameStats").offset
  out.gameStats = {}
  for i = 0, 63 do
    out.gameStats[i + 1] = readU32(s, statsOff + i * 4)
  end

  out.rivalName = s:sub(findField(SB1.fields, "rivalName").offset + 1, findField(SB1.fields, "rivalName").offset + 8)

  return out
end

--------------------------------------------------------------------------
-- Sector/slot packing -- real HandleWriteSector / CopySaveSlotData /
-- GetSaveValidStatus, restricted to the modeled sector ids 0-4 (see
-- header "SCOPE" note).
--------------------------------------------------------------------------

-- Real sSaveSlotLayout, restricted to ids 0-4.
local function slotLayout(sb2Bytes, sb1Bytes)
  local layout = {}
  do
    local off, size = chunkInfo(#sb2Bytes, 0)
    layout[SECTOR_ID_SAVEBLOCK2] = { source = sb2Bytes, offset = off, size = size }
  end
  for chunk = 0, SECTOR_ID_SAVEBLOCK1_END - SECTOR_ID_SAVEBLOCK1_START do
    local off, size = chunkInfo(#sb1Bytes, chunk)
    layout[SECTOR_ID_SAVEBLOCK1_START + chunk] = { source = sb1Bytes, offset = off, size = size }
  end
  return layout
end

-- Encodes one real 4096-byte struct SaveSector for `sectorId`.
local function encodeSector(sectorId, chunk, counter)
  local buf = newBuffer(SECTOR_SIZE)
  local chunkData = chunk.source:sub(chunk.offset + 1, chunk.offset + chunk.size)
  setBytes(buf, 0, chunkData) -- rest of the 3968-byte data field stays zero, real behavior
  setU16(buf, SECTOR_DATA_SIZE + 116, sectorId) -- id
  setU16(buf, SECTOR_DATA_SIZE + 118, calculateChecksum(chunkData, chunk.size)) -- checksum
  setU32(buf, SECTOR_DATA_SIZE + 120, SECTOR_SIGNATURE) -- signature
  setU32(buf, SECTOR_DATA_SIZE + 124, counter) -- counter
  return table.concat(buf)
end

-- Reads one real sector's footer + data; does NOT validate here (real
-- GetSaveValidStatus/CopySaveSlotData validate per-sector, see below).
local function readSectorFooter(sectorBytes)
  return {
    id = readU16(sectorBytes, SECTOR_DATA_SIZE + 116),
    checksum = readU16(sectorBytes, SECTOR_DATA_SIZE + 118),
    signature = readU32(sectorBytes, SECTOR_DATA_SIZE + 120),
    counter = readU32(sectorBytes, SECTOR_DATA_SIZE + 124),
  }
end

-- Encodes one real 5-sector slot (SLOT_BYTES == 20480 bytes) for
-- `state` at generation `counter`.
local function encodeSlot(state, counter)
  local sb2Bytes = SaveFileCodec.encodeSaveBlock2(state.saveBlock2)
  local sb1Bytes = SaveFileCodec.encodeSaveBlock1(state.saveBlock1, (state.saveBlock2 or {}).encryptionKey)
  local layout = slotLayout(sb2Bytes, sb1Bytes)
  local parts = {}
  for sectorId = 0, NUM_SECTORS_MODELED - 1 do
    parts[#parts + 1] = encodeSector(sectorId, layout[sectorId], counter)
  end
  return table.concat(parts)
end

-- Real GetSaveValidStatus, restricted to the 5 modeled sectors: a slot is
-- only valid if EVERY modeled sector has the real signature and its
-- checksum matches. Returns status ("OK"/"EMPTY"/"ERROR"), counter (from
-- sector 0, or nil), and the decoded SaveBlock2/SaveBlock1 byte chunks
-- (nil if not OK).
local function validateSlot(slotBytes)
  local sb2Chunk, sb1Chunks = nil, {}
  local anySignature = false
  local validCount = 0
  local counter = nil

  for sectorId = 0, NUM_SECTORS_MODELED - 1 do
    local sectorBytes = slotBytes:sub(sectorId * SECTOR_SIZE + 1, (sectorId + 1) * SECTOR_SIZE)
    local footer = readSectorFooter(sectorBytes)
    if footer.signature == SECTOR_SIGNATURE then
      anySignature = true
      -- Real CalculateChecksum(data, locations[id].size) needs the real
      -- chunk size for whichever id this sector actually claims to be;
      -- since our modeled ids always occupy fixed positions 0-4 (no
      -- physical rotation, see header "SCOPE" note), the expected size
      -- for footer.id is derived the same way encodeSector did.
      local expectedSize
      if footer.id == SECTOR_ID_SAVEBLOCK2 then
        local _, size = chunkInfo(SB2_SIZE, 0)
        expectedSize = size
      elseif footer.id >= SECTOR_ID_SAVEBLOCK1_START and footer.id <= SECTOR_ID_SAVEBLOCK1_END then
        local _, size = chunkInfo(SB1_SIZE, footer.id - SECTOR_ID_SAVEBLOCK1_START)
        expectedSize = size
      end
      if expectedSize and footer.id == sectorId then
        local data = sectorBytes:sub(1, SECTOR_DATA_SIZE)
        if footer.checksum == calculateChecksum(data, expectedSize) then
          validCount = validCount + 1
          counter = footer.counter
          if sectorId == SECTOR_ID_SAVEBLOCK2 then
            sb2Chunk = data:sub(1, expectedSize)
          else
            sb1Chunks[sectorId] = data:sub(1, expectedSize)
          end
        end
      end
    end
  end

  local status
  if not anySignature then
    status = "EMPTY"
  elseif validCount == NUM_SECTORS_MODELED then
    status = "OK"
  else
    status = "ERROR"
  end

  local sb1Bytes = nil
  if status == "OK" then
    local parts = {}
    for chunk = 0, SECTOR_ID_SAVEBLOCK1_END - SECTOR_ID_SAVEBLOCK1_START do
      parts[#parts + 1] = sb1Chunks[SECTOR_ID_SAVEBLOCK1_START + chunk] or ""
    end
    sb1Bytes = table.concat(parts)
  end

  return status, counter, sb2Chunk, sb1Bytes
end

--------------------------------------------------------------------------
-- Public encode: builds the full versioned, dual-slot buffer.
--
-- state = { saveBlock2 = {...}, saveBlock1 = {...} } (in-memory shapes
-- matching decodeSaveBlock2/decodeSaveBlock1's output).
-- previousCounter: the last save-generation number this codec produced
-- (default 0, matching gSaveCounter starting at 0 for a brand new save
-- file -- this is an in-RAM counter in the real game too, not something
-- re-derived from flash except at load time, so callers are expected to
-- track it the same way).
-- previousBytes: an earlier full buffer this codec produced (optional).
-- When given, the physical slot NOT being written this call keeps its
-- old bytes untouched, exactly matching real save.c's alternating-slot
-- write (the other slot is simply never touched by a given save).
--
-- Returns encodedBytes, newCounter.
--------------------------------------------------------------------------

function SaveFileCodec.encode(state, previousCounter, previousBytes)
  previousCounter = previousCounter or 0
  local newCounter = previousCounter + 1
  local targetSlot = newCounter % NUM_SAVE_SLOTS -- real: gSaveCounter % NUM_SAVE_SLOTS

  local slots = { [0] = string.rep("\0", SLOT_BYTES), [1] = string.rep("\0", SLOT_BYTES) }
  if previousBytes and #previousBytes == HEADER_SIZE + NUM_SAVE_SLOTS * SLOT_BYTES then
    for slotIdx = 0, NUM_SAVE_SLOTS - 1 do
      local start = HEADER_SIZE + slotIdx * SLOT_BYTES
      slots[slotIdx] = previousBytes:sub(start + 1, start + SLOT_BYTES)
    end
  end
  slots[targetSlot] = encodeSlot(state, newCounter)

  local headerBuf = newBuffer(HEADER_SIZE)
  setBytes(headerBuf, 0, SaveFileCodec.MAGIC)
  setU8(headerBuf, 4, SaveFileCodec.VERSION)
  local bytes = table.concat(headerBuf) .. slots[0] .. slots[1]
  return bytes, newCounter
end

--------------------------------------------------------------------------
-- Public decode: real slot-selection + corruption handling
-- (GetSaveValidStatus, transcribed above per-slot as validateSlot()).
--
-- Returns state, info on success (info = {status="OK", saveCounter=N,
-- slotUsed=0/1}), or nil, info/errorMessage otherwise. info.status can
-- be "EMPTY" (both slots blank -- brand new file) or "ERROR" (at least
-- one slot was written but neither slot is fully valid -- real
-- GetSaveValidStatus's SAVE_STATUS_ERROR/INVALID cases collapsed into
-- one, since this codec doesn't model the separate partial-recovery
-- paths those distinguish in the full 32-sector real game).
--------------------------------------------------------------------------

function SaveFileCodec.decode(bytes)
  if #bytes < HEADER_SIZE + NUM_SAVE_SLOTS * SLOT_BYTES then
    return nil, "buffer too short for a save file"
  end
  if bytes:sub(1, 4) ~= SaveFileCodec.MAGIC then
    return nil, "bad magic -- not a recognized save file"
  end
  local version = readU8(bytes, 4)
  if version ~= SaveFileCodec.VERSION then
    return nil, ("unsupported save schema version %d (expected %d) -- refusing to guess"):format(version, SaveFileCodec.VERSION)
  end

  local slotBytes = {}
  for slotIdx = 0, NUM_SAVE_SLOTS - 1 do
    local start = HEADER_SIZE + slotIdx * SLOT_BYTES
    slotBytes[slotIdx] = bytes:sub(start + 1, start + SLOT_BYTES)
  end

  local status, counter, sb2, sb1 = {}, {}, {}, {}
  for slotIdx = 0, NUM_SAVE_SLOTS - 1 do
    status[slotIdx], counter[slotIdx], sb2[slotIdx], sb1[slotIdx] = validateSlot(slotBytes[slotIdx])
  end

  -- Real GetSaveValidStatus (src/save.c lines ~534-581), transcribed:
  local chosen = nil
  if status[0] == "OK" and status[1] == "OK" then
    -- Choose the higher counter (real code's -1/0 wraparound special
    -- case collapses to plain unsigned comparison for all counters this
    -- codec ever produces; see header note).
    chosen = (counter[1] > counter[0]) and 1 or 0
  elseif status[0] == "OK" then
    chosen = 0
  elseif status[1] == "OK" then
    chosen = 1
  elseif status[0] == "EMPTY" and status[1] == "EMPTY" then
    return nil, { status = "EMPTY" }
  else
    return nil, { status = "ERROR" }
  end

  local sb2State = SaveFileCodec.decodeSaveBlock2(sb2[chosen])
  local sb1State = SaveFileCodec.decodeSaveBlock1(sb1[chosen], sb2State.encryptionKey)
  return { saveBlock2 = sb2State, saveBlock1 = sb1State },
    { status = "OK", saveCounter = counter[chosen], slotUsed = chosen }
end

return SaveFileCodec
