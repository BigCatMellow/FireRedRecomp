-- Integration test: composites the real title screen logo and checks
-- known pixel colors. Opt-in via POKEPORT_ROM, skips cleanly otherwise.
--
-- Run: POKEPORT_ROM=/path/to/verified/pokefirered.gba lua5.1 tests/title_screen_test.lua
package.path = package.path .. ";./?.lua"

local romPath = os.getenv("POKEPORT_ROM")
if not romPath then
  print("SKIP: set POKEPORT_ROM=/path/to/verified/pokefirered.gba to run this test")
  os.exit(0)
end

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local TitleScreen = require("import.TitleScreen")

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

local img = TitleScreen.compositeLogo(data, addrs.gGraphics_TitleScreen_GameTitleLogoTiles, addrs.gGraphics_TitleScreen_GameTitleLogoMap, addrs.gGraphics_TitleScreen_GameTitleLogoPals)

check("logo image is 256x160", img.width == 256 and img.height == 160)

-- Known pixel colors, spot-checked by eye against the rendered logo and
-- confirmed against FireRed's real yellow/blue logo palette.
local yellow = img.getPixel(20, 20)
check("logo has the correct yellow lettering color", yellow.r == 255 and yellow.g == 247 and yellow.b == 41, yellow.r .. "," .. yellow.g .. "," .. yellow.b)

local blue = img.getPixel(30, 15)
check("logo has a blue outline pixel", blue.r < 50 and blue.b > 200, blue.r .. "," .. blue.g .. "," .. blue.b)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
