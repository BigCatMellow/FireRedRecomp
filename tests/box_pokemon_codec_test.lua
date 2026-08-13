-- Run: lua5.1 tests/box_pokemon_codec_test.lua
package.path = package.path .. ";./?.lua"
local BoxPokemonCodec = require("src.core.BoxPokemonCodec")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- Spot-check the transcribed SUBSTRUCT_CASE table against real
-- src/pokemon.c source lines (SUBSTRUCT_CASE(n,v1,v2,v3,v4)).
local orders = BoxPokemonCodec.SUBSTRUCT_ORDERS
check("case 0: 0,1,2,3", orders[0][1] == 0 and orders[0][2] == 1 and orders[0][3] == 2 and orders[0][4] == 3)
check("case 6: 1,0,2,3", orders[6][1] == 1 and orders[6][2] == 0 and orders[6][3] == 2 and orders[6][4] == 3)
check("case 23: 3,2,1,0", orders[23][1] == 3 and orders[23][2] == 2 and orders[23][3] == 1 and orders[23][4] == 0)
check("case 12: 1,2,0,3", orders[12][1] == 1 and orders[12][2] == 2 and orders[12][3] == 0 and orders[12][4] == 3)

local function u16le(v) return string.char(v % 256, math.floor(v / 256) % 256) end
local function u32le(v)
  return string.char(v % 256, math.floor(v / 256) % 256, math.floor(v / 65536) % 256, math.floor(v / 16777216) % 256)
end

-- xorSecureBlock is its own inverse (real EncryptBoxMon/DecryptBoxMon do
-- the identical two XORs regardless of direction).
local sample = string.rep("\1\2\3\4\5\6\7\8\9\10\11\12", 4) -- 48 bytes
local personality, otId = 0x12345678, 0xABCD1234
local encrypted = BoxPokemonCodec.xorSecureBlock(sample, personality, otId)
check("encrypted differs from plaintext", encrypted ~= sample)
local roundTrip = BoxPokemonCodec.xorSecureBlock(encrypted, personality, otId)
check("xorSecureBlock is its own inverse (encrypt==decrypt)", roundTrip == sample)

-- Full decode() round trip: personality chosen so personality%24==6
-- (order {1,0,2,3} -- type0 physically sits in slot 1, not slot 0),
-- proving the shuffle is actually exercised, not just an identity case.
local pers = 6 -- 6 % 24 == 6
local ot = 0xDEAD0001
local order = BoxPokemonCodec.getSubstructOrder(pers)
check("chosen personality exercises a non-identity shuffle", order[1] ~= 0, order)

-- type0 (Growth): species=1 (Bulbasaur), heldItem=0, experience=1000,
-- ppBonuses=0, friendship=70, filler=0.
local type0 = u16le(1) .. u16le(0) .. u32le(1000) .. string.char(0, 70) .. u16le(0)
-- type1 (Attacks): moves = {33 (Tackle), 45 (Growl), 0, 0}, pp = {35,40,0,0}.
local type1 = u16le(33) .. u16le(45) .. u16le(0) .. u16le(0) .. string.char(35, 40, 0, 0)
-- type2 (EVs & Condition): all zero.
local type2 = string.rep("\0", 12)
-- type3 (Misc): pokerus=0, metLocation=1, metLevel=5, metGame=0,
-- pokeball=4, otGender=0, ivs hp=31 attack=20 defense=15 speed=10
-- spAttack=5 spDefense=0, isEgg=false, abilityNum=1.
local metWord = 5 + 0 * 128 + 4 * 2048 + 0 * 32768 -- metLevel:7 metGame:4 pokeball:4 otGender:1
local ivWord = 31 + 20 * 32 + 15 * 1024 + 10 * 32768 + 5 * 1048576 + 0 * 33554432 + 0 * 1073741824 + 1 * 2147483648
local type3 = string.char(0, 1) .. u16le(metWord) .. u32le(ivWord) .. string.rep("\0", 4)

check("type0 substruct is 12 bytes", #type0 == 12, #type0)
check("type1 substruct is 12 bytes", #type1 == 12, #type1)
check("type3 substruct is 12 bytes", #type3 == 12, #type3)

-- Assemble the 48-byte plaintext secure block by placing each logical
-- type at its shuffled physical slot for this personality.
local plainSlots = { [0] = type0, [1] = type1, [2] = type2, [3] = type3 }
local physicalBlocks = { [0] = "", [1] = "", [2] = "", [3] = "" }
for logicalType = 0, 3 do
  local physicalSlot = order[logicalType + 1]
  physicalBlocks[physicalSlot] = plainSlots[logicalType]
end
local securePlain = physicalBlocks[0] .. physicalBlocks[1] .. physicalBlocks[2] .. physicalBlocks[3]
check("assembled secure block is 48 bytes", #securePlain == 48, #securePlain)

local secureEncrypted = BoxPokemonCodec.xorSecureBlock(securePlain, pers, ot)
local realChecksum = BoxPokemonCodec.checksum(plainSlots)

local nickname = "BULBASAUR "
local otName = "ASH    "
-- flags byte: bit0 isBadEgg, bit1 hasSpecies, bit2 isEgg -- 2 means only
-- hasSpecies is set.
local blob = u32le(pers) .. u32le(ot) .. nickname .. string.char(2) -- language=2 (English)
  .. string.char(2) -- flags = hasSpecies
  .. otName .. string.char(0) -- markings
  .. u16le(realChecksum) .. u16le(0) -- unknown
  .. secureEncrypted

check("assembled blob is 80 bytes", #blob == 80, #blob)

local decoded = BoxPokemonCodec.decode(blob)
check("decoded personality", decoded.personality == pers, decoded.personality)
check("decoded otId", decoded.otId == ot, decoded.otId)
check("checksum validates", decoded.checksumValid == true)
check("hasSpecies flag decoded", decoded.hasSpecies == true)
check("isBadEgg flag decoded false", decoded.isBadEgg == false)

check("type0 species", decoded.substructs[0].species == 1, decoded.substructs[0].species)
check("type0 experience", decoded.substructs[0].experience == 1000, decoded.substructs[0].experience)
check("type0 friendship", decoded.substructs[0].friendship == 70, decoded.substructs[0].friendship)

check("type1 moves", decoded.substructs[1].moves[1] == 33 and decoded.substructs[1].moves[2] == 45, decoded.substructs[1].moves)
check("type1 pp", decoded.substructs[1].pp[1] == 35 and decoded.substructs[1].pp[2] == 40, decoded.substructs[1].pp)

check("type3 metLevel", decoded.substructs[3].metLevel == 5, decoded.substructs[3].metLevel)
check("type3 pokeball", decoded.substructs[3].pokeball == 4, decoded.substructs[3].pokeball)
check("type3 ivs.hp", decoded.substructs[3].ivs.hp == 31, decoded.substructs[3].ivs.hp)
check("type3 ivs.attack", decoded.substructs[3].ivs.attack == 20, decoded.substructs[3].ivs.attack)
check("type3 ivs.defense", decoded.substructs[3].ivs.defense == 15, decoded.substructs[3].ivs.defense)
check("type3 ivs.speed", decoded.substructs[3].ivs.speed == 10, decoded.substructs[3].ivs.speed)
check("type3 ivs.spAttack", decoded.substructs[3].ivs.spAttack == 5, decoded.substructs[3].ivs.spAttack)
check("type3 abilityNum", decoded.substructs[3].abilityNum == 1, decoded.substructs[3].abilityNum)
check("type3 isEgg", decoded.substructs[3].isEgg == false, decoded.substructs[3].isEgg)

-- Corrupting one byte of the encrypted block should now fail checksum.
local corruptSecure = "\255" .. secureEncrypted:sub(2)
local corruptBlob = blob:sub(1, 32) .. corruptSecure
local corruptDecoded = BoxPokemonCodec.decode(corruptBlob)
check("corrupted data fails checksum validation", corruptDecoded.checksumValid == false)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
