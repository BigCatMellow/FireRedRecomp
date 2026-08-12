-- Run: lua5.1 tests/map_header_test.lua
package.path = package.path .. ";./?.lua"
local MapHeader = require("import.MapHeader")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

check("record size is 28", MapHeader.RECORD_SIZE == 28)

-- Build a synthetic ROM image: gMapGroups at file offset 0, pointing at a
-- group table at ROM address romBase+0x100, pointing at a MapHeader at
-- romBase+0x200, with mapLayoutId=78 (matching real Pallet Town) and a few
-- other known-shape fields.
local romBase = MapHeader.romBase

local function u32le(n)
  return string.char(n % 256, math.floor(n / 256) % 256, math.floor(n / 65536) % 256, math.floor(n / 16777216) % 256)
end
local function u16le(n)
  return string.char(n % 256, math.floor(n / 256) % 256)
end

local header = u32le(0xAABBCCDD) -- mapLayout ptr (raw, not resolved)
  .. u32le(0xEEFF0011)           -- events ptr
  .. u32le(0x22334455)           -- mapScripts ptr
  .. u32le(0x66778899)           -- connections ptr
  .. u16le(300)                   -- music
  .. u16le(78)                    -- mapLayoutId
  .. string.char(88)              -- regionMapSectionId
  .. string.char(0)               -- cave
  .. string.char(0)               -- weather
  .. string.char(1)               -- mapType
  .. string.char(1)               -- bikingAllowed
  .. string.char(3)               -- flags: allowEscaping=1, allowRunning=1, showMapName=0
  .. string.char(0xFE)            -- floorNum = -2 (s8)
  .. string.char(0)               -- battleType

check("synthetic header is 28 bytes", #header == 28)

local groupTable = u32le(romBase + 0x200) -- group table's single entry (map num 0)
local gMapGroupsBlob = string.rep("\0", 3 * 4) .. u32le(romBase + 0x100) -- 3 empty groups, group 3 at 0x100

-- Assemble a flat "ROM": gMapGroups at 0, group table at 0x100, header at 0x200.
local rom = gMapGroupsBlob
rom = rom .. string.rep("\0", 0x100 - #rom) .. groupTable
rom = rom .. string.rep("\0", 0x200 - #rom) .. header

local MAP_ID = 3 * 256 + 0 -- group 3, num 0, matching real MAP_PALLET_TOWN
local h = MapHeader.resolve(rom, 0, MAP_ID)

check("mapLayoutId", h.mapLayoutId == 78, h.mapLayoutId)
check("music", h.music == 300, h.music)
check("regionMapSectionId", h.regionMapSectionId == 88, h.regionMapSectionId)
check("mapType", h.mapType == 1, h.mapType)
check("bikingAllowed", h.bikingAllowed == true)
check("allowEscaping", h.allowEscaping == true)
check("allowRunning", h.allowRunning == true)
check("floorNum is signed (-2)", h.floorNum == -2, h.floorNum)
check("mapLayoutPtr kept raw", h.mapLayoutPtr == 0xAABBCCDD, h.mapLayoutPtr)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
