-- Integration test: decodes the real player overworld sprite (Red,
-- standing/facing-down frame) and checks known pixel colors + transparency.
-- Opt-in via POKEPORT_ROM, skips cleanly otherwise.
--
-- Run: POKEPORT_ROM=/path/to/verified/pokefirered.gba lua5.1 tests/object_sprite_test.lua
package.path = package.path .. ";./?.lua"

local romPath = os.getenv("POKEPORT_ROM")
if not romPath then
  print("SKIP: set POKEPORT_ROM=/path/to/verified/pokefirered.gba to run this test")
  os.exit(0)
end

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local ObjectSprite = require("import.ObjectSprite")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local ok, info = RomImporter.verify(romPath)
if not ok then
  print("FAIL: ROM did not verify -- " .. tostring(info))
  os.exit(1)
end

local sha1 = RomImporter._sha1HexOfFile(romPath)
local addrs = RomAddresses[sha1]
local f = io.open(romPath, "rb")
local data = f:read("*a")
f:close()

-- gObjectEventGraphicsInfo_RedNormal: width=2, height=4 tiles (16x32px).
local img = ObjectSprite.decodeFrame(data, addrs.gObjectEventPic_RedNormal, addrs.gObjectEventPal_Player, 2, 4, 0)

check("player sprite frame is 16x32", img.width == 16 and img.height == 32)

check("top rows are transparent (canvas padding above the head)", img.getPixel(8, 2).a == 0)

local capColor = img.getPixel(4, 14)
check("has the real player cap color", capColor.a == 1 and capColor.r == 255 and capColor.g == 107 and capColor.b == 74, capColor.r .. "," .. capColor.g .. "," .. capColor.b .. ",a" .. capColor.a)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
