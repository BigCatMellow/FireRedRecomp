-- Run: lua5.1 tests/map_connections_test.lua
package.path = package.path .. ";./?.lua"
local MapConnections = require("import.MapConnections")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local romBase = MapConnections.romBase
local function u32le(n)
  return string.char(n % 256, math.floor(n / 256) % 256, math.floor(n / 65536) % 256, math.floor(n / 16777216) % 256)
end

-- Real Pallet Town connections: NORTH to MAP_ROUTE1 (group 3 num 19),
-- SOUTH to MAP_ROUTE21_NORTH (group 3 num 39).
local conn0 = string.char(MapConnections.CONNECTION_NORTH, 0, 0, 0) .. u32le(0) .. string.char(3, 19, 0, 0)
local conn1 = string.char(MapConnections.CONNECTION_SOUTH, 0, 0, 0) .. u32le(0) .. string.char(3, 39, 0, 0)
check("connection fixture is 12 bytes", #conn0 == 12)

local header = u32le(2) .. u32le(romBase + 0x100) -- count=2, list at 0x100
local rom = header .. string.rep("\0", 0x100 - #header) .. conn0 .. conn1

local conns = MapConnections.resolve(rom, romBase)
check("2 connections", conns[0] ~= nil and conns[1] ~= nil and conns[2] == nil)
check("connection 0 is north to Route 1", conns[0].direction == MapConnections.CONNECTION_NORTH and conns[0].mapGroup == 3 and conns[0].mapNum == 19)
check("connection 1 is south to Route 21 North", conns[1].direction == MapConnections.CONNECTION_SOUTH and conns[1].mapGroup == 3 and conns[1].mapNum == 39)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
