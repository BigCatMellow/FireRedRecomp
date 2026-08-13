-- Run: lua5.1 tests/save_file_codec_test.lua
package.path = package.path .. ";./?.lua"
local SaveFileCodec = require("src.core.SaveFileCodec")
local BoxPokemonCodec = require("src.core.BoxPokemonCodec")
local NewGameDefaults = require("src.core.NewGameDefaults")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

--------------------------------------------------------------------------
-- CalculateChecksum sanity check: transcribed directly from src/save.c
-- (additive u32-word sum, folded (checksum>>16)+checksum, truncated to
-- u16 -- NOT a CRC). Hand-computed on a tiny known buffer.
--------------------------------------------------------------------------

do
  -- 8 bytes = two u32 words: 0x00000001 and 0x00000002 (LE).
  local data = string.char(1, 0, 0, 0) .. string.char(2, 0, 0, 0)
  local checksum = SaveFileCodec.calculateChecksum(data, 8)
  -- sum = 3, (3>>16)+3 = 3.
  check("checksum of two small u32 words", checksum == 3, checksum)

  -- Trailing bytes that don't fill a whole u32 word are excluded (real
  -- `size/4` integer-division loop bound) -- adding 3 extra bytes here
  -- must not change the result.
  local dataWithTrailer = data .. string.char(0xFF, 0xFF, 0xFF)
  local checksumTrailer = SaveFileCodec.calculateChecksum(dataWithTrailer, 8)
  check("trailing partial word excluded from checksum", checksumTrailer == checksum, checksumTrailer)

  -- Fold path: a word large enough to require the >>16 fold.
  local big = string.char(0xFF, 0xFF, 0xFF, 0xFF) -- 0xFFFFFFFF
  local checksumBig = SaveFileCodec.calculateChecksum(big, 4)
  -- sum = 0xFFFFFFFF, (0xFFFFFFFF>>16) + 0xFFFFFFFF = 0xFFFF + 0xFFFFFFFF
  -- = 0x1_0000_FFFE, truncated to u16 = 0xFFFE.
  check("checksum fold on max u32 word", checksumBig == 0xFFFE, checksumBig)
end

--------------------------------------------------------------------------
-- Build a synthetic party member's 80-byte on-disk BoxPokemon blob (same
-- approach as box_pokemon_codec_test.lua -- BoxPokemonCodec has no
-- separate "encode" function since xorSecureBlock is its own inverse).
--------------------------------------------------------------------------

local function u16le(v) return string.char(v % 256, math.floor(v / 256) % 256) end
local function u32le(v)
  return string.char(v % 256, math.floor(v / 256) % 256, math.floor(v / 65536) % 256, math.floor(v / 16777216) % 256)
end

local function buildBoxMonBlob(personality, otId, species, level)
  local order = BoxPokemonCodec.getSubstructOrder(personality)
  local type0 = u16le(species) .. u16le(0) .. u32le(500) .. string.char(0, 40) .. u16le(0)
  local type1 = u16le(33) .. u16le(0) .. u16le(0) .. u16le(0) .. string.char(35, 0, 0, 0)
  local type2 = string.rep("\0", 12)
  local type3 = string.char(0, 1) .. u16le(5) .. u32le(31) .. string.rep("\0", 4)
  local plainSlots = { [0] = type0, [1] = type1, [2] = type2, [3] = type3 }
  local physicalBlocks = { [0] = "", [1] = "", [2] = "", [3] = "" }
  for logicalType = 0, 3 do
    physicalBlocks[order[logicalType + 1]] = plainSlots[logicalType]
  end
  local securePlain = physicalBlocks[0] .. physicalBlocks[1] .. physicalBlocks[2] .. physicalBlocks[3]
  local secureEncrypted = BoxPokemonCodec.xorSecureBlock(securePlain, personality, otId)
  local checksum = BoxPokemonCodec.checksum(plainSlots)
  return u32le(personality) .. u32le(otId) .. "TESTMON   " .. string.char(2) .. string.char(2)
    .. "TESTER " .. string.char(0) .. u16le(checksum) .. u16le(0) .. secureEncrypted
end

--------------------------------------------------------------------------
-- Build a synthetic new-game-shaped save state, using
-- NewGameDefaults.lua's real fresh-game values as a starting point.
--------------------------------------------------------------------------

local function freshState()
  local sb2 = {
    playerName = "RED\0\0\0\0\0",
    playerGender = 0,
    specialSaveWarpFlags = NewGameDefaults.saveBlock2.specialSaveWarpFlags,
    playerTrainerId = string.char(1, 2, 3, 4),
    playTimeHours = 0, playTimeMinutes = 0, playTimeSeconds = 0, playTimeVBlanks = 0,
    optionsButtonMode = NewGameDefaults.options.buttonMode,
    options = {
      textSpeed = NewGameDefaults.options.textSpeed,
      windowFrameType = NewGameDefaults.options.windowFrameType,
      sound = NewGameDefaults.options.sound == 1,
      battleStyle = NewGameDefaults.options.battleStyle == 1,
      battleSceneOff = NewGameDefaults.options.battleSceneOff,
      regionMapZoom = NewGameDefaults.options.regionMapZoom,
    },
    pokedex = {
      order = 0, mode = 0, unused = NewGameDefaults.saveBlock2.pokedexUnused, nationalMagic = 0,
      unownPersonality = 0, spindaPersonality = 0, unknown3 = 0,
      owned = string.rep("\0", 52), seen = string.rep("\0", 52),
    },
    gcnLinkFlags = NewGameDefaults.saveBlock2.gcnLinkFlags,
    unkFlag1 = NewGameDefaults.saveBlock2.unkFlag1,
    unkFlag2 = NewGameDefaults.saveBlock2.unkFlag2,
    encryptionKey = NewGameDefaults.saveBlock2.encryptionKey, -- 0 on a new game
  }

  local sb1 = {
    pos = { x = 0, y = 0 },
    location = { mapGroup = 0, mapNum = 0, warpId = -1, x = 6, y = 6 },
    continueGameWarp = { mapGroup = 0, mapNum = 0, warpId = -1, x = 6, y = 6 },
    dynamicWarp = { mapGroup = -1, mapNum = -1, warpId = -1, x = 0, y = 0 },
    lastHealLocation = { mapGroup = 0, mapNum = 0, warpId = -1, x = 6, y = 6 },
    escapeWarp = { mapGroup = -1, mapNum = -1, warpId = -1, x = 0, y = 0 },
    savedMusic = 0, weather = 0, weatherCycleStage = 0, flashLevel = 0, mapLayoutId = 0,
    playerPartyCount = 0,
    playerParty = {},
    money = NewGameDefaults.startingMoney, -- 3000
    coins = 0, registeredItem = 0,
    pcItems = { { itemId = 13, quantity = 1 } }, -- ITEM_POTION == 13 in FireRed's real item table
    bagPocket_Items = {}, bagPocket_KeyItems = {}, bagPocket_PokeBalls = {},
    bagPocket_TMHM = {}, bagPocket_Berries = {},
    seen1 = string.rep("\0", 52),
    flags = string.rep("\0", 288),
    vars = {},
    gameStats = {},
    rivalName = "BLUE\0\0\0\0",
  }

  return { saveBlock2 = sb2, saveBlock1 = sb1 }
end

-- Sets bit `flagIndex` (0-based, matching FLAG_* numbering) in a
-- 288-byte flags string. Mirrors the real bit-per-FLAG_* packing this
-- project documents in SaveBlockLayout.lua ("NUM_FLAG_BYTES gap...
-- bit-per-FLAG_*").
local function setFlagBit(flagsStr, flagIndex)
  local byteIdx = math.floor(flagIndex / 8)
  local bit = flagIndex % 8
  local b = string.byte(flagsStr, byteIdx + 1)
  local mask = 2 ^ bit
  if math.floor(b / mask) % 2 == 0 then
    b = b + mask
  end
  return flagsStr:sub(1, byteIdx) .. string.char(b) .. flagsStr:sub(byteIdx + 2)
end

local function isFlagBitSet(flagsStr, flagIndex)
  local byteIdx = math.floor(flagIndex / 8)
  local bit = flagIndex % 8
  local b = string.byte(flagsStr, byteIdx + 1)
  return math.floor(b / (2 ^ bit)) % 2 == 1
end

--------------------------------------------------------------------------
-- Round-trip test: fresh state -> encode -> decode -> compare.
--------------------------------------------------------------------------

local state1 = freshState()
local bytes1, counter1 = SaveFileCodec.encode(state1, 0, nil)
check("first encode produces the expected total buffer size",
  #bytes1 == SaveFileCodec.HEADER_SIZE + 2 * SaveFileCodec.SLOT_BYTES, #bytes1)
check("first encode's counter is 1", counter1 == 1, counter1)

local decoded1, info1 = SaveFileCodec.decode(bytes1)
check("decode of a fresh single-copy buffer succeeds", decoded1 ~= nil, info1)
if decoded1 then
  check("decode status OK", info1.status == "OK", info1.status)
  check("decode picked counter 1", info1.saveCounter == 1, info1.saveCounter)
  check("money round-trips", decoded1.saveBlock1.money == 3000, decoded1.saveBlock1.money)
  check("playerName round-trips", decoded1.saveBlock2.playerName:sub(1, 3) == "RED", decoded1.saveBlock2.playerName)
  check("pcItems[1] itemId round-trips", decoded1.saveBlock1.pcItems[1].itemId == 13)
  check("pcItems[1] quantity round-trips", decoded1.saveBlock1.pcItems[1].quantity == 1)
  check("location warpId round-trips (signed)", decoded1.saveBlock1.location.warpId == -1, decoded1.saveBlock1.location.warpId)
  check("dynamicWarp.mapGroup round-trips (signed -1)", decoded1.saveBlock1.dynamicWarp.mapGroup == -1)
  check("rivalName round-trips", decoded1.saveBlock1.rivalName:sub(1, 4) == "BLUE")
end

--------------------------------------------------------------------------
-- Mutate: money, a party member (via BoxPokemonCodec), and a flag.
-- Also gives a non-zero encryptionKey, exercising money/bag XOR.
--------------------------------------------------------------------------

local state2 = freshState()
state2.saveBlock2.encryptionKey = 0xA5A5A5A5
state2.saveBlock1.money = 45250
state2.saveBlock1.playerPartyCount = 1
state2.saveBlock1.playerParty[1] = {
  box = buildBoxMonBlob(0x12345678, 0xABCD1234, 1, 5), -- Bulbasaur-shaped
  status = 0, level = 5, mail = 0xFF,
  hp = 20, maxHP = 20, attack = 10, defense = 10, speed = 8, spAttack = 9, spDefense = 9,
}
state2.saveBlock1.bagPocket_Items[1] = { itemId = 19, quantity = 3 } -- e.g. an Antidote-shaped slot
local FLAG_INDEX = 0x838 -- FLAG_0x838, real NewGameDefaults.setFlags entry
state2.saveBlock1.flags = setFlagBit(state2.saveBlock1.flags, FLAG_INDEX)

local bytes2, counter2 = SaveFileCodec.encode(state2, counter1, bytes1)
check("second encode's counter is 2", counter2 == 2, counter2)
check("second encode goes to the other physical slot",
  counter2 % SaveFileCodec.NUM_SAVE_SLOTS ~= counter1 % SaveFileCodec.NUM_SAVE_SLOTS)

local decoded2, info2 = SaveFileCodec.decode(bytes2)
check("decode of the mutated buffer succeeds", decoded2 ~= nil, info2)
if decoded2 then
  check("decode picked the newer counter (2)", info2.saveCounter == 2, info2.saveCounter)
  check("mutated money round-trips through nonzero encryptionKey", decoded2.saveBlock1.money == 45250, decoded2.saveBlock1.money)
  check("encryptionKey round-trips", decoded2.saveBlock2.encryptionKey == 0xA5A5A5A5)

  local mon = decoded2.saveBlock1.playerParty[1]
  check("party mon level round-trips", mon.level == 5, mon.level)
  check("party mon hp round-trips", mon.hp == 20, mon.hp)
  check("party mon box blob round-trips byte-for-byte", mon.box == state2.saveBlock1.playerParty[1].box)
  local decodedMon = BoxPokemonCodec.decode(mon.box)
  check("round-tripped box blob still decodes via BoxPokemonCodec", decodedMon.checksumValid == true)
  check("round-tripped box blob species is Bulbasaur", decodedMon.substructs[0].species == 1)

  check("bag item quantity round-trips through XOR encryption",
    decoded2.saveBlock1.bagPocket_Items[1].quantity == 3, decoded2.saveBlock1.bagPocket_Items[1].quantity)
  check("bag item itemId round-trips", decoded2.saveBlock1.bagPocket_Items[1].itemId == 19)

  check("mutated flag bit round-trips", isFlagBitSet(decoded2.saveBlock1.flags, FLAG_INDEX) == true)
  check("an unrelated flag bit stays clear", isFlagBitSet(decoded2.saveBlock1.flags, FLAG_INDEX + 1) == false)
end

--------------------------------------------------------------------------
-- Schema version guard: a buffer with an unrecognized version byte must
-- be refused outright, not silently misread.
--------------------------------------------------------------------------

do
  local corruptedVersion = bytes1:sub(1, 4) .. string.char(99) .. bytes1:sub(6)
  local result, err = SaveFileCodec.decode(corruptedVersion)
  check("unsupported version is refused", result == nil)
  check("unsupported version error message is descriptive", type(err) == "string" and err:find("version") ~= nil, err)
end

do
  local badMagic = "XXXX" .. bytes1:sub(5)
  local result, err = SaveFileCodec.decode(badMagic)
  check("bad magic is refused", result == nil, err)
end

--------------------------------------------------------------------------
-- Corruption-fallback test: corrupt the NEWER slot's checksum (slot
-- holding counter 2, the mutated save) and confirm decode falls back to
-- the OLDER but still-valid slot (counter 1, the original fresh save) --
-- matching real GetSaveValidStatus: a slot missing even one valid sector
-- is entirely rejected in favor of the other slot, not partially trusted.
--------------------------------------------------------------------------

do
  local targetSlot = counter2 % SaveFileCodec.NUM_SAVE_SLOTS -- slot holding counter2 (mutated save)
  local sectorStart = SaveFileCodec.HEADER_SIZE + targetSlot * (SaveFileCodec.NUM_SECTORS_MODELED * SaveFileCodec.SECTOR_SIZE)
  -- Flip one byte inside sector 0's data region -- breaks that sector's
  -- checksum without touching its signature, exactly like real
  -- silently-corrupted flash data.
  local flipAt = sectorStart + 10 -- well within the 3968-byte data region
  local flippedByte = (string.byte(bytes2, flipAt + 1) + 1) % 256
  local corrupted = bytes2:sub(1, flipAt) .. string.char(flippedByte) .. bytes2:sub(flipAt + 2)

  local decoded3, info3 = SaveFileCodec.decode(corrupted)
  check("decode still succeeds after corrupting the newer slot", decoded3 ~= nil, info3)
  if decoded3 then
    check("corruption fallback picked the OLDER valid slot (counter 1)", info3.saveCounter == 1, info3.saveCounter)
    check("fallback data is the ORIGINAL save, not the corrupted mutated one",
      decoded3.saveBlock1.money == 3000, decoded3.saveBlock1.money)
    check("fallback party is empty (original fresh save had no party member)",
      decoded3.saveBlock1.playerPartyCount == 0)
  end
end

-- Corrupting BOTH slots leaves no valid copy -- decode must fail cleanly,
-- not fabricate data.
do
  local corrupted = bytes2
  for slotIdx = 0, 1 do
    local sectorStart = SaveFileCodec.HEADER_SIZE + slotIdx * (SaveFileCodec.NUM_SECTORS_MODELED * SaveFileCodec.SECTOR_SIZE)
    local flipAt = sectorStart + 10
    local flippedByte = (string.byte(corrupted, flipAt + 1) + 1) % 256
    corrupted = corrupted:sub(1, flipAt) .. string.char(flippedByte) .. corrupted:sub(flipAt + 2)
  end
  local decoded4, info4 = SaveFileCodec.decode(corrupted)
  check("decode fails cleanly when both slots are corrupted", decoded4 == nil)
  check("failure info reports ERROR status", type(info4) == "table" and info4.status == "ERROR", info4)
end

--------------------------------------------------------------------------
-- End-to-end demonstration with real io.open file I/O (not wired into
-- the live game loop -- explicitly out of scope per the handoff brief --
-- just proves the byte buffer this codec produces is a real writable/
-- readable file, using a scratch path outside the repo).
--------------------------------------------------------------------------

do
  local path = os.getenv("TMPDIR")
  path = (path or "/tmp") .. "/firered_recomp_save_codec_test.sav"
  local f = assert(io.open(path, "wb"))
  f:write(bytes2)
  f:close()

  local rf = assert(io.open(path, "rb"))
  local readBack = rf:read("*a")
  rf:close()
  os.remove(path)

  check("bytes written to and read back from a real file match", readBack == bytes2, #readBack)
  local decoded5 = SaveFileCodec.decode(readBack)
  check("save file read from disk decodes correctly", decoded5 ~= nil and decoded5.saveBlock1.money == 45250)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
