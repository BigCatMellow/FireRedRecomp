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

local boxArt = TitleScreen.compositeLayer4bpp(data, addrs.gGraphics_TitleScreen_BoxArtMonTiles, addrs.gGraphics_TitleScreen_BoxArtMonMap, addrs.gGraphics_TitleScreen_BoxArtMonPals)
check("box art image is 256x160", boxArt.width == 256 and boxArt.height == 160)
local charizardOrange = boxArt.getPixel(160, 80)
check("box art has Charizard's orange body color", charizardOrange.r > 80 and charizardOrange.g > 10 and charizardOrange.b < 20, charizardOrange.r .. "," .. charizardOrange.g .. "," .. charizardOrange.b)

local copyright = TitleScreen.compositeLayer4bpp(data, addrs.gGraphics_TitleScreen_CopyrightPressStartTiles, addrs.gGraphics_TitleScreen_CopyrightPressStartMap, addrs.gGraphics_TitleScreen_BackgroundPals)
check("copyright/press-start image is 256x160", copyright.width == 256 and copyright.height == 160)
local copyrightBar = copyright.getPixel(100, 150)
check("copyright layer has the red bottom bar color", copyrightBar.r > 100 and copyrightBar.g < 20 and copyrightBar.b < 20, copyrightBar.r .. "," .. copyrightBar.g .. "," .. copyrightBar.b)

local border = TitleScreen.compositeLayer4bpp(data, addrs.sBorderBgTiles, addrs.sBorderBgMap, addrs.gGraphics_TitleScreen_BackgroundPals)
check("border image is 256x160", border.width == 256 and border.height == 160)
local borderTeal = border.getPixel(100, 80)
check("border layer has the teal backdrop band color", borderTeal.r < 100 and borderTeal.g > 150 and borderTeal.b > 130, borderTeal.r .. "," .. borderTeal.g .. "," .. borderTeal.b)

local full = TitleScreen.compositeFull(data, addrs)
check("compositeFull is 256x160", full.width == 256 and full.height == 160)
check("compositeFull shows the logo on top (yellow at the same spot as the standalone logo)", (function()
  local p = full.getPixel(20, 20)
  return p.r == 255 and p.g == 247 and p.b == 41
end)())
check("compositeFull shows the copyright bar behind the logo/box art", (function()
  local p = full.getPixel(100, 150)
  return p.r > 100 and p.g < 20 and p.b < 20
end)())
check("compositeFull shows the border backdrop where no other layer covers", (function()
  local p = full.getPixel(230, 80)
  return p.r < 100 and p.g > 150 and p.b > 130
end)())

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
