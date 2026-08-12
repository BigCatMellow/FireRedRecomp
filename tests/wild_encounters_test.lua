-- Run: lua5.1 tests/wild_encounters_test.lua
package.path = package.path .. ";./?.lua"
local WildEncounters = require("import.WildEncounters")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local romBase = WildEncounters.romBase
local function u32le(n)
  return string.char(n % 256, math.floor(n / 256) % 256, math.floor(n / 65536) % 256, math.floor(n / 16777216) % 256)
end
local function u16le(n) return string.char(n % 256, math.floor(n / 256) % 256) end

-- Real Route 1 header: mapGroup=3, mapNum=19, landMonsInfo at 0x300.
local header0 = string.char(2, 27, 0, 0) .. u32le(0) .. u32le(0) .. u32le(0) .. u32le(0) -- unrelated entry, group 2 num 27
local header1 = string.char(3, 19, 0, 0) .. u32le(romBase + 0x300) .. u32le(0) .. u32le(0) .. u32le(0) -- Route 1
local terminator = string.char(WildEncounters.TERMINATOR_MAP_GROUP, 0, 0, 0) .. u32le(0) .. u32le(0) .. u32le(0) .. u32le(0)

local headers = header0 .. header1 .. terminator

local rom = headers
rom = rom .. string.rep("\0", 0x300 - #rom) -- pad to landMonsInfo's address
  .. string.char(21, 0, 0, 0) .. u32le(romBase + 0x340) -- WildPokemonInfo: encounterRate=21, wildPokemon ptr
rom = rom .. string.rep("\0", 0x340 - #rom)
  .. string.char(3, 3) .. u16le(16) -- minLevel=3, maxLevel=3, species=PIDGEY(16)
  .. string.char(3, 3) .. u16le(19) -- minLevel=3, maxLevel=3, species=RATTATA(19)

local h = WildEncounters.findHeader(rom, 0, 3, 19)
check("finds Route 1's header", h ~= nil)
check("header fields", h.mapGroup == 3 and h.mapNum == 19)
check("landMonsInfoPtr", h.landMonsInfoPtr == romBase + 0x300)

local notFound = WildEncounters.findHeader(rom, 0, 99, 99)
check("returns nil for a map not in the table", notFound == nil)

local info = WildEncounters.resolveInfo(rom, h.landMonsInfoPtr, 2)
check("encounterRate", info.encounterRate == 21, info.encounterRate)
check("mon0 is PIDGEY lvl 3-3", info.mons[0].minLevel == 3 and info.mons[0].maxLevel == 3 and info.mons[0].species == 16)
check("mon1 is RATTATA lvl 3-3", info.mons[1].species == 19, info.mons[1].species)

check("resolveInfo returns nil for a NULL pointer (no encounters of that type)", WildEncounters.resolveInfo(rom, 0, 5) == nil)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
