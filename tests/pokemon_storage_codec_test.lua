-- Run: lua5.1 tests/pokemon_storage_codec_test.lua
package.path = package.path .. ";./?.lua"
local Codec = require("src.core.PokemonStorageCodec")

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
  end
end

check("real struct size is 0x83D0", Codec.SIZE == 0x83D0, Codec.SIZE)
local storage = Codec.new()
storage.currentBox = 5
storage.boxNames[1] = "BOX ONE\0\0"
storage.boxNames[14] = "LAST BOX\0"
storage.boxWallpapers[1] = 3
storage.boxWallpapers[14] = 15
local firstBlob = string.char(1) .. string.rep("\0", 79)
local lastBlob = string.char(2) .. string.rep("\0", 79)
assert(storage.boxes:add(1, { box=firstBlob }) == 1)
assert(storage.boxes:add(14, { box=lastBlob }) == 1)

local encoded = Codec.encode(storage)
check("encoded byte size matches real struct", #encoded == 0x83D0, #encoded)
check("current box is stored 0-based", encoded:byte(1) == 4, encoded:byte(1))
check("first BoxPokemon starts at 0x0001", encoded:byte(2) == 1, encoded:byte(2))
check("box names begin at the source offset", encoded:sub(0x8344 + 1, 0x8344 + 3) == "BOX")
check("wallpapers begin at the source offset", encoded:byte(0x83C2 + 1) == 3)

local decoded = Codec.decode(encoded)
check("current box round-trips into 1-based PcBoxes convention", decoded.currentBox == 5, decoded.currentBox)
check("first occupied slot round-trips", decoded.boxes:get(1, 1).box == firstBlob)
check("empty slots stay empty", decoded.boxes:get(1, 2) == nil)
check("last box data round-trips", decoded.boxes:get(14, 1).box == lastBlob)
check("box name round-trips", decoded.boxNames[14]:sub(1, 8) == "LAST BOX", decoded.boxNames[14])
check("wallpaper round-trips", decoded.boxWallpapers[14] == 15, decoded.boxWallpapers[14])

if failed > 0 then os.exit(1) end
print(('%d passed, %d failed'):format(passed, failed))
