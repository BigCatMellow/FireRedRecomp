-- Real BoxPokemon layout/encryption, pokefirered include/pokemon.h
-- (struct BoxPokemon, struct PokemonSubstruct0-3) and src/pokemon.c
-- (EncryptBoxMon/DecryptBoxMon, GetSubstruct's sSubstructCase-table
-- personality%24 shuffle, CalculateBoxMonChecksum).
--
-- struct BoxPokemon is 80 bytes total, laid out exactly as declared (no
-- padding surprises found -- every field up to the union is naturally
-- aligned: u32,u32,u8[10],u8,u8,u8[7],u8,u16,u16 = 4+4+10+1+1+7+1+2+2 =
-- 32 bytes, then the 48-byte `secure` union starts on a 4-byte boundary
-- already):
--   0x00 personality        u32
--   0x04 otId               u32
--   0x08 nickname[10]       u8
--   0x12 language            u8
--   0x13 flags: isBadEgg:1, hasSpecies:1, isEgg:1, blockBoxRS:1, unused:4
--   0x14 otName[7]           u8
--   0x1B markings            u8
--   0x1C checksum            u16
--   0x1E unknown             u16
--   0x20 secure (48 bytes, encrypted, see below)
--   -- total 0x50 = 80 bytes
--
-- `secure` is 4 substructs x 12 bytes (NUM_SUBSTRUCT_BYTES==12 -- every
-- one of PokemonSubstruct0-3 happens to be naturally 12 bytes with no
-- internal padding, confirmed by hand-summing each struct's declared
-- fields, so the "4 substructs" union member and the flat 48-byte
-- `raw[12]` u32 view line up with no gap).
--
-- Encryption (EncryptBoxMon/DecryptBoxMon): every one of the 12 u32
-- words in `secure.raw` gets XORed with `personality`, then with `otId`.
-- Both directions do the identical two XORs in the same order -- XOR is
-- its own inverse and the two keys don't interact, so
-- "encrypt" and "decrypt" are the exact same operation; this module
-- only implements one (`xorSecureBlock`) and both encode()/decode() call
-- it. There is no missing "encrypt" path: encoding a plaintext block
-- back into on-disk form is xorSecureBlock again, same as decoding.
--
-- Substruct shuffle (GetSubstruct): which of the 4 physical 12-byte
-- slots holds which logical substruct type (0=Growth/1=Attacks/
-- 2=EVs&Condition/3=Misc) depends on `personality % 24`. Transcribed
-- directly from the real SUBSTRUCT_CASE(n, v1,v2,v3,v4) table in
-- src/pokemon.c's GetSubstruct -- v1..v4 are the physical slot index
-- for logical type 0..3 respectively when personality%24==n.
-- CalculateBoxMonChecksum always sums logical types 0,1,2,3 in that
-- order (via GetSubstruct), i.e. checksum is invariant to which
-- physical slot each type landed in -- this module's checksum() takes
-- already-slot-resolved 12-byte substructs in logical type order to
-- match.
--
-- No `bit` library (see Lz77.lua's header) -- XOR is done byte-wise via
-- a small precomputed 256x256 lookup table (built once at require time),
-- which is exact and avoids the float-precision pitfalls of 32-bit
-- multiply-based bit tricks.

local BoxPokemonCodec = {}

local byte = string.byte
local char = string.char

-- 256x256 byte XOR lookup, built once.
local XOR8 = {}
for a = 0, 255 do
  local row = {}
  for b = 0, 255 do
    local x, ac, bc, r, pw = 0, a, b, 0, 1
    for _ = 1, 8 do
      local abit, bbit = ac % 2, bc % 2
      if abit ~= bbit then r = r + pw end
      ac = math.floor(ac / 2)
      bc = math.floor(bc / 2)
      pw = pw * 2
    end
    row[b] = r
  end
  XOR8[a] = row
end

-- Real SUBSTRUCT_CASE table from GetSubstruct, personality%24 -> the
-- physical slot index (0-3) holding each logical substruct type 0-3.
local SUBSTRUCT_ORDERS = {
  [0] = { 0, 1, 2, 3 },  [1] = { 0, 1, 3, 2 },  [2] = { 0, 2, 1, 3 },
  [3] = { 0, 3, 1, 2 },  [4] = { 0, 2, 3, 1 },  [5] = { 0, 3, 2, 1 },
  [6] = { 1, 0, 2, 3 },  [7] = { 1, 0, 3, 2 },  [8] = { 2, 0, 1, 3 },
  [9] = { 3, 0, 1, 2 },  [10] = { 2, 0, 3, 1 }, [11] = { 3, 0, 2, 1 },
  [12] = { 1, 2, 0, 3 }, [13] = { 1, 3, 0, 2 }, [14] = { 2, 1, 0, 3 },
  [15] = { 3, 1, 0, 2 }, [16] = { 2, 3, 0, 1 }, [17] = { 3, 2, 0, 1 },
  [18] = { 1, 2, 3, 0 }, [19] = { 1, 3, 2, 0 }, [20] = { 2, 1, 3, 0 },
  [21] = { 3, 1, 2, 0 }, [22] = { 2, 3, 1, 0 }, [23] = { 3, 2, 1, 0 },
}

BoxPokemonCodec.SUBSTRUCT_ORDERS = SUBSTRUCT_ORDERS
BoxPokemonCodec.SECURE_SIZE = 48
BoxPokemonCodec.SUBSTRUCT_SIZE = 12
BoxPokemonCodec.BOX_POKEMON_SIZE = 80

function BoxPokemonCodec.getSubstructOrder(personality)
  return SUBSTRUCT_ORDERS[personality % 24]
end

local function u32le(data, offset)
  return byte(data, offset + 1) + byte(data, offset + 2) * 256
    + byte(data, offset + 3) * 65536 + byte(data, offset + 4) * 16777216
end

local function packU16le(value)
  value = value or 0
  return char(value % 256, math.floor(value / 256) % 256)
end

local function packU32le(value)
  value = value or 0
  return char(
    value % 256,
    math.floor(value / 256) % 256,
    math.floor(value / 65536) % 256,
    math.floor(value / 16777216) % 256)
end

local function fixedBytes(value, size)
  value = value or ""
  return (value .. string.rep("\0", size)):sub(1, size)
end

-- Applies EncryptBoxMon/DecryptBoxMon's XOR (both directions, identical
-- operation -- see header comment). secureBytes: exactly SECURE_SIZE (48)
-- raw bytes. personality/otId: u32 values. Returns 48 transformed bytes.
function BoxPokemonCodec.xorSecureBlock(secureBytes, personality, otId)
  assert(#secureBytes == BoxPokemonCodec.SECURE_SIZE,
    ("secure block must be %d bytes, got %d"):format(BoxPokemonCodec.SECURE_SIZE, #secureBytes))
  local pBytes = {
    personality % 256,
    math.floor(personality / 256) % 256,
    math.floor(personality / 65536) % 256,
    math.floor(personality / 16777216) % 256,
  }
  local oBytes = {
    otId % 256,
    math.floor(otId / 256) % 256,
    math.floor(otId / 65536) % 256,
    math.floor(otId / 16777216) % 256,
  }
  local out = {}
  for i = 1, #secureBytes do
    local lane = (i - 1) % 4 + 1
    local v = byte(secureBytes, i)
    v = XOR8[v][pBytes[lane]]
    v = XOR8[v][oBytes[lane]]
    out[i] = char(v)
  end
  return table.concat(out)
end

-- Decodes a plaintext (already-decrypted) 12-byte type0 substruct
-- (Growth): species, heldItem, experience, ppBonuses, friendship.
function BoxPokemonCodec.parseSubstruct0(bytes)
  return {
    species = byte(bytes, 1) + byte(bytes, 2) * 256,
    heldItem = byte(bytes, 3) + byte(bytes, 4) * 256,
    experience = u32le(bytes, 4),
    ppBonuses = byte(bytes, 9),
    friendship = byte(bytes, 10),
    filler = byte(bytes, 11) + byte(bytes, 12) * 256,
  }
end

-- type1 substruct (Attacks): 4 moves + 4 pp values.
function BoxPokemonCodec.parseSubstruct1(bytes)
  local moves = {}
  for i = 0, 3 do
    moves[i + 1] = byte(bytes, i * 2 + 1) + byte(bytes, i * 2 + 2) * 256
  end
  local pp = {}
  for i = 0, 3 do
    pp[i + 1] = byte(bytes, 8 + i + 1)
  end
  return { moves = moves, pp = pp }
end

-- type2 substruct (EVs & Condition): 6 EVs + 6 contest stats.
function BoxPokemonCodec.parseSubstruct2(bytes)
  return {
    hpEV = byte(bytes, 1), attackEV = byte(bytes, 2), defenseEV = byte(bytes, 3),
    speedEV = byte(bytes, 4), spAttackEV = byte(bytes, 5), spDefenseEV = byte(bytes, 6),
    cool = byte(bytes, 7), beauty = byte(bytes, 8), cute = byte(bytes, 9),
    smart = byte(bytes, 10), tough = byte(bytes, 11), sheen = byte(bytes, 12),
  }
end

-- type3 substruct (Misc): pokerus/met info/IVs/isEgg/abilityNum.
-- Ribbon bitfields (bytes 8-11) are real but not decoded here -- out of
-- scope for stats/party modeling; see struct PokemonSubstruct3 in
-- pokefirered include/pokemon.h for their bit layout if needed later.
function BoxPokemonCodec.parseSubstruct3(bytes)
  -- metLevel:7, metGame:4, pokeball:4, otGender:1 are one contiguous
  -- 16-bit bitfield spanning bytes 2-3 (LE), LSB-first in declaration
  -- order (the real agbcc/ARM EABI bitfield packing order): bits0-6
  -- metLevel, bits7-10 metGame, bits11-14 pokeball, bit15 otGender.
  -- metGame and pokeball each straddle the byte2/byte3 boundary, so
  -- they're read from the combined 16-bit word, not byte3 alone.
  local metWord = byte(bytes, 3) + byte(bytes, 4) * 256
  local ivWord = u32le(bytes, 4) -- bytes 4-7: hpIV:5 attackIV:5 defenseIV:5 speedIV:5 spAttackIV:5 spDefenseIV:5 isEgg:1 abilityNum:1

  return {
    pokerus = byte(bytes, 1),
    metLocation = byte(bytes, 2),
    metLevel = metWord % 128,
    metGame = math.floor(metWord / 128) % 16,
    pokeball = math.floor(metWord / 2048) % 16,
    otGender = math.floor(metWord / 32768) % 2,
    ivs = {
      hp = ivWord % 32,
      attack = math.floor(ivWord / 32) % 32,
      defense = math.floor(ivWord / 1024) % 32,
      speed = math.floor(ivWord / 32768) % 32,
      spAttack = math.floor(ivWord / 1048576) % 32,
      spDefense = math.floor(ivWord / 33554432) % 32,
    },
    isEgg = math.floor(ivWord / 1073741824) % 2 == 1,
    abilityNum = math.floor(ivWord / 2147483648) % 2,
    -- The ribbon/fateful-encounter bitfield is not interpreted by this
    -- project yet, but retaining the four raw bytes lets encode(decode(x))
    -- preserve it exactly instead of silently destroying save data.
    ribbonBytes = bytes:sub(9, 12),
  }
end

-- Encodes a logical BoxPokemon table into the real encrypted 80-byte
-- representation. The accepted shape is the same one decode() returns:
-- top-level identity/flag fields plus substructs[0..3]. This is the write
-- counterpart to decode(), using the same real personality%24 shuffle,
-- checksum, and personality/OT-ID XOR described above.
--
-- Fields this project does not interpret (the misc ribbon bitfield) are
-- accepted as substructs[3].ribbonBytes and preserved byte-for-byte. New
-- records may omit it, in which case CreateBoxMon's zeroed value is used.
function BoxPokemonCodec.encode(mon)
  assert(type(mon) == "table", "BoxPokemonCodec.encode expects a table")
  local personality = assert(mon.personality, "BoxPokemon personality is required")
  local otId = assert(mon.otId, "BoxPokemon otId is required")
  local sub = assert(mon.substructs, "BoxPokemon substructs are required")
  local growth = sub[0] or {}
  local attacks = sub[1] or {}
  local condition = sub[2] or {}
  local misc = sub[3] or {}
  local ivs = misc.ivs or {}
  local moves = attacks.moves or {}
  local pp = attacks.pp or {}

  local type0 = packU16le(growth.species)
    .. packU16le(growth.heldItem)
    .. packU32le(growth.experience)
    .. char((growth.ppBonuses or 0) % 256, (growth.friendship or 0) % 256)
    .. packU16le(growth.filler)

  local type1Parts = {}
  for i = 1, 4 do type1Parts[#type1Parts + 1] = packU16le(moves[i]) end
  for i = 1, 4 do type1Parts[#type1Parts + 1] = char((pp[i] or 0) % 256) end
  local type1 = table.concat(type1Parts)

  local type2 = char(
    (condition.hpEV or 0) % 256,
    (condition.attackEV or 0) % 256,
    (condition.defenseEV or 0) % 256,
    (condition.speedEV or 0) % 256,
    (condition.spAttackEV or 0) % 256,
    (condition.spDefenseEV or 0) % 256,
    (condition.cool or 0) % 256,
    (condition.beauty or 0) % 256,
    (condition.cute or 0) % 256,
    (condition.smart or 0) % 256,
    (condition.tough or 0) % 256,
    (condition.sheen or 0) % 256)

  local metWord = (misc.metLevel or 0) % 128
    + ((misc.metGame or 0) % 16) * 128
    + ((misc.pokeball or 0) % 16) * 2048
    + ((misc.otGender or 0) % 2) * 32768
  local ivWord = (ivs.hp or 0) % 32
    + ((ivs.attack or 0) % 32) * 32
    + ((ivs.defense or 0) % 32) * 1024
    + ((ivs.speed or 0) % 32) * 32768
    + ((ivs.spAttack or 0) % 32) * 1048576
    + ((ivs.spDefense or 0) % 32) * 33554432
    + (misc.isEgg and 1 or 0) * 1073741824
    + ((misc.abilityNum or 0) % 2) * 2147483648
  local type3 = char((misc.pokerus or 0) % 256, (misc.metLocation or 0) % 256)
    .. packU16le(metWord) .. packU32le(ivWord)
    .. fixedBytes(misc.ribbonBytes, 4)

  local logical = { [0] = type0, [1] = type1, [2] = type2, [3] = type3 }
  local order = BoxPokemonCodec.getSubstructOrder(personality)
  local physical = {}
  for logicalType = 0, 3 do
    physical[order[logicalType + 1]] = logical[logicalType]
  end
  local securePlain = physical[0] .. physical[1] .. physical[2] .. physical[3]
  local secureEncrypted = BoxPokemonCodec.xorSecureBlock(securePlain, personality, otId)

  local flags = (mon.isBadEgg and 1 or 0)
    + (mon.hasSpecies and 2 or 0)
    + (mon.isEgg and 4 or 0)
    + (mon.blockBoxRS and 8 or 0)
    + ((mon.unusedFlags or 0) % 16) * 16
  local checksum = BoxPokemonCodec.checksum(logical)
  return packU32le(personality) .. packU32le(otId)
    .. fixedBytes(mon.nickname, 10)
    .. char((mon.language or 0) % 256, flags)
    .. fixedBytes(mon.otName, 7)
    .. char((mon.markings or 0) % 256)
    .. packU16le(checksum)
    .. packU16le(mon.unknown)
    .. secureEncrypted
end

-- Real CalculateBoxMonChecksum: sum of every u16 word across all 4
-- logical substructs (type order 0,1,2,3, NOT physical slot order),
-- wrapping at 16 bits. substructsByType: { [0]=bytes12, [1]=bytes12,
-- [2]=bytes12, [3]=bytes12 } already resolved to logical type order.
function BoxPokemonCodec.checksum(substructsByType)
  local sum = 0
  for t = 0, 3 do
    local bytes = substructsByType[t]
    for i = 0, 5 do
      sum = sum + byte(bytes, i * 2 + 1) + byte(bytes, i * 2 + 2) * 256
    end
  end
  return sum % 65536
end

-- Decodes a full real 80-byte BoxPokemon blob (as read from a save
-- file/party buffer) into a plain Lua table. Does NOT verify the ROM --
-- this is pure struct/crypto decoding, no ROM bytes involved.
-- Returns { personality, otId, nickname (raw bytes), language, isBadEgg,
-- hasSpecies, isEgg, otName (raw bytes), markings, checksum,
-- checksumValid, substructs = {[0]=growth,[1]=attacks,[2]=evCondition,
-- [3]=misc} }.
function BoxPokemonCodec.decode(blob)
  assert(#blob == BoxPokemonCodec.BOX_POKEMON_SIZE,
    ("BoxPokemon blob must be %d bytes, got %d"):format(BoxPokemonCodec.BOX_POKEMON_SIZE, #blob))

  local personality = u32le(blob, 0)
  local otId = u32le(blob, 4)
  local nickname = blob:sub(9, 18) -- 0x08, 10 bytes
  local language = byte(blob, 19) -- 0x12
  local flags = byte(blob, 20) -- 0x13
  local otName = blob:sub(21, 27) -- 0x14, 7 bytes
  local markings = byte(blob, 28) -- 0x1B
  local storedChecksum = byte(blob, 29) + byte(blob, 30) * 256 -- 0x1C
  local unknown = byte(blob, 31) + byte(blob, 32) * 256 -- 0x1E

  local secureEncrypted = blob:sub(33, 80) -- 0x20, 48 bytes
  local securePlain = BoxPokemonCodec.xorSecureBlock(secureEncrypted, personality, otId)

  local order = BoxPokemonCodec.getSubstructOrder(personality)
  local slots = {}
  for i = 0, 3 do
    local start = order[i + 1] * BoxPokemonCodec.SUBSTRUCT_SIZE
    slots[i] = securePlain:sub(start + 1, start + BoxPokemonCodec.SUBSTRUCT_SIZE)
  end

  local substructs = {
    [0] = BoxPokemonCodec.parseSubstruct0(slots[0]),
    [1] = BoxPokemonCodec.parseSubstruct1(slots[1]),
    [2] = BoxPokemonCodec.parseSubstruct2(slots[2]),
    [3] = BoxPokemonCodec.parseSubstruct3(slots[3]),
  }

  return {
    personality = personality,
    otId = otId,
    nickname = nickname,
    language = language,
    isBadEgg = flags % 2 == 1,
    hasSpecies = math.floor(flags / 2) % 2 == 1,
    isEgg = math.floor(flags / 4) % 2 == 1,
    blockBoxRS = math.floor(flags / 8) % 2 == 1,
    unusedFlags = math.floor(flags / 16) % 16,
    otName = otName,
    markings = markings,
    unknown = unknown,
    checksum = storedChecksum,
    checksumValid = storedChecksum == BoxPokemonCodec.checksum(slots),
    substructs = substructs,
  }
end

return BoxPokemonCodec
