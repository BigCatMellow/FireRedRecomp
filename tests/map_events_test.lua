-- Run: lua5.1 tests/map_events_test.lua
package.path = package.path .. ";./?.lua"
local MapEvents = require("import.MapEvents")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local romBase = MapEvents.romBase
local function u32le(n)
  return string.char(n % 256, math.floor(n / 256) % 256, math.floor(n / 65536) % 256, math.floor(n / 16777216) % 256)
end
local function u16le(n)
  return string.char(n % 256, math.floor(n / 256) % 256)
end

-- One of each event type, real Pallet Town field values, laid out at fixed
-- ROM addresses in a synthetic image.
local objEvent = string.char(1, 0x17, 0) .. string.char(0) -- localId,graphicsId,kind=0,pad
  .. u16le(3) .. u16le(10)                                  -- x, y
  .. string.char(3, 2)                                       -- elevation, movementType
  .. string.char(0x41)                                        -- rangeX=1, rangeY=4
  .. string.char(0)                                            -- pad
  .. u16le(0) .. u16le(0)                                      -- trainerType, trainerRange
  .. u32le(0x0816575c)                                          -- script ptr
  .. u16le(0)                                                    -- flagId
  .. string.char(0, 0)                                            -- trailing pad to 24
check("objEvent fixture is 24 bytes", #objEvent == 24)

local warp = u16le(6) .. u16le(7) .. string.char(0, 1, 0, 4) -- x,y,elevation,warpId,mapNum,mapGroup
check("warp fixture is 8 bytes", #warp == 8)

local coord = u16le(12) .. u16le(1) .. string.char(3, 0) .. u16le(0x4050) .. u16le(0) .. string.char(0, 0) .. u32le(0x08165800)
check("coord fixture is 16 bytes", #coord == 16)

local bg = u16le(16) .. u16le(16) .. string.char(0, 0) .. string.char(0, 0) .. u32le(0x08165900)
check("bg fixture is 12 bytes", #bg == 12)

local mapEventsHeader = string.char(1, 1, 1, 1) -- 1 of each
  .. u32le(romBase + 0x100) -- objectEvents ptr
  .. u32le(romBase + 0x200) -- warps ptr
  .. u32le(romBase + 0x300) -- coordEvents ptr
  .. u32le(romBase + 0x400) -- bgEvents ptr

local rom = mapEventsHeader
rom = rom .. string.rep("\0", 0x100 - #rom) .. objEvent
rom = rom .. string.rep("\0", 0x200 - #rom) .. warp
rom = rom .. string.rep("\0", 0x300 - #rom) .. coord
rom = rom .. string.rep("\0", 0x400 - #rom) .. bg

local ev = MapEvents.resolve(rom, romBase)

check("1 object event", ev.objectEvents[0] ~= nil and ev.objectEvents[1] == nil)
check("object event x/y/elevation", ev.objectEvents[0].x == 3 and ev.objectEvents[0].y == 10 and ev.objectEvents[0].elevation == 3)
check("object event movement range bitfield", ev.objectEvents[0].movementRangeX == 1 and ev.objectEvents[0].movementRangeY == 4)

check("warp x/y/warpId/mapGroup", ev.warps[0].x == 6 and ev.warps[0].y == 7 and ev.warps[0].warpId == 1 and ev.warps[0].mapGroup == 4)

check("coord trigger is VAR_MAP_SCENE_PALLET_TOWN_OAK (0x4050)", ev.coordEvents[0].trigger == 0x4050, ev.coordEvents[0].trigger)

check("bg event x/y/kind", ev.bgEvents[0].x == 16 and ev.bgEvents[0].y == 16 and ev.bgEvents[0].kind == 0)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
