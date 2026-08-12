-- Run: lua5.1 tests/asset_pointer_tables_test.lua
package.path = package.path .. ";./?.lua"
local CompressedSpriteSheetTable = require("import.CompressedSpriteSheetTable")
local CryTable = require("import.CryTable")
local SongTable = require("import.SongTable")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local function u32le(n)
  return string.char(n % 256, math.floor(n / 256) % 256, math.floor(n / 65536) % 256, math.floor(n / 16777216) % 256)
end
local function u16le(n) return string.char(n % 256, math.floor(n / 256) % 256) end

-- CompressedSpriteSheetTable: real Bulbasaur front-sprite entry (index 1):
-- dataPtr=0x08d2fbd4, size=2048, tag=1.
local sheetBlob = u32le(0) .. u16le(0) .. u16le(0) -- index 0, unused
  .. u32le(0x08d2fbd4) .. u16le(2048) .. u16le(1)  -- index 1 (Bulbasaur)
local sheet = CompressedSpriteSheetTable.resolve(sheetBlob, 0, 1)
check("sprite sheet dataPtr/size/tag", sheet.dataPtr == 0x08d2fbd4 and sheet.size == 2048 and sheet.tag == 1)

-- CryTable: real entry 1, type=32, key=60, wavPtr=0x08510c50, ADSR=255,0,255,0.
local cryBlob = string.rep("\0", 12) -- index 0, unused
  .. string.char(32, 60, 0, 0) .. u32le(0x08510c50) .. string.char(255, 0, 255, 0)
local cry = CryTable.resolve(cryBlob, 0, 1)
check("cry type/key/wavPtr", cry.type == 32 and cry.key == 60 and cry.wavPtr == 0x08510c50)
check("cry ADSR envelope", cry.attack == 255 and cry.decay == 0 and cry.sustain == 255 and cry.release == 0)

-- SongTable: real entries 0-2 (mus_dummy, se_use_item, se_pc_login).
local songBlob = u32le(0x086b5640) .. u16le(0) .. u16le(0)
  .. u32le(0x086b5660) .. u16le(1) .. u16le(1)
  .. u32le(0x086b568c) .. u16le(1) .. u16le(1)
check("song 0 (mus_dummy) ms/me are 0,0", SongTable.resolve(songBlob, 0, 0).ms == 0 and SongTable.resolve(songBlob, 0, 0).me == 0)
check("song 1 (se_use_item) ms/me are 1,1", SongTable.resolve(songBlob, 0, 1).ms == 1 and SongTable.resolve(songBlob, 0, 1).me == 1)
check("song 2 (se_pc_login) headerPtr", SongTable.resolve(songBlob, 0, 2).headerPtr == 0x086b568c)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
