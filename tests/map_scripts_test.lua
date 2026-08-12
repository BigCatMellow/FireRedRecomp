-- Run: lua5.1 tests/map_scripts_test.lua
package.path = package.path .. ";./?.lua"
local MapScripts = require("import.MapScripts")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local romBase = MapScripts.romBase
local function u32le(n)
  return string.char(n % 256, math.floor(n / 256) % 256, math.floor(n / 65536) % 256, math.floor(n / 16777216) % 256)
end
local function u16le(n) return string.char(n % 256, math.floor(n / 256) % 256) end

-- Real Pallet Town data: ON_TRANSITION -> direct script, ON_FRAME_TABLE ->
-- sub-table with one entry (var=0x4050, compare=2), then terminator.
local topTable = string.char(MapScripts.ON_TRANSITION) .. u32le(0x08165465)
  .. string.char(MapScripts.ON_FRAME_TABLE) .. u32le(romBase + 0x100)
  .. string.char(0) -- terminator

local subTable = u16le(0x4050) .. u16le(2) .. u32le(0x081654d8)
  .. u16le(0) -- terminator (var=0)

local rom = topTable
rom = rom .. string.rep("\0", 0x100 - #rom) .. subTable

local scripts = MapScripts.resolve(rom, romBase)
check("2 entries before terminator", scripts[1] ~= nil and scripts[2] == nil)
check("entry 0 is ON_TRANSITION with direct script ptr", scripts[0].type == MapScripts.ON_TRANSITION and scripts[0].scriptPtr == 0x08165465)
check("entry 0 has no varTable (not a table-type hook)", scripts[0].varTable == nil)
check("entry 1 is ON_FRAME_TABLE with a resolved varTable", scripts[1].type == MapScripts.ON_FRAME_TABLE and scripts[1].varTable ~= nil)
check("varTable has exactly 1 entry", scripts[1].varTable[0] ~= nil and scripts[1].varTable[1] == nil)
check("varTable entry matches VAR_MAP_SCENE_PALLET_TOWN_OAK/compare 2", scripts[1].varTable[0].var == 0x4050 and scripts[1].varTable[0].compare == 2 and scripts[1].varTable[0].scriptPtr == 0x081654d8)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
