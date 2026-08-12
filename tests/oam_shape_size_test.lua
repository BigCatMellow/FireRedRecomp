-- Integration test: decodes two real OamData structs and one real
-- non-player object sprite (the Item Ball), verifying OamShapeSize.lua
-- against real ROM bytes -- not just the standard hardware table in
-- isolation. Opt-in via POKEPORT_ROM, skips cleanly otherwise.
--
-- Run: POKEPORT_ROM=/path/to/verified/pokefirered.gba lua5.1 tests/oam_shape_size_test.lua
package.path = package.path .. ";./?.lua"

local romPath = os.getenv("POKEPORT_ROM")
if not romPath then
  print("SKIP: set POKEPORT_ROM=/path/to/verified/pokefirered.gba to run this test")
  os.exit(0)
end

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local OamShapeSize = require("import.OamShapeSize")
local ObjectSprite = require("import.ObjectSprite")
local GbaGraphics = require("import.GbaGraphics")

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

local oam16x32 = OamShapeSize.decodeOamData(data, addrs.gObjectEventBaseOam_16x32)
check("16x32 OAM template decodes to V_RECTANGLE shape", oam16x32.shape == OamShapeSize.SHAPE_V_RECTANGLE, oam16x32.shape)
check("16x32 OAM template decodes to size 2", oam16x32.size == 2, oam16x32.size)
check("16x32 OAM template's real dimensions match its own name", oam16x32.width == 16 and oam16x32.height == 32)
check("16x32 OAM template's tile dimensions match the player sprite's known-correct 2x4", oam16x32.widthTiles == 2 and oam16x32.heightTiles == 4)

local oam16x16 = OamShapeSize.decodeOamData(data, addrs.gObjectEventBaseOam_16x16)
check("16x16 OAM template decodes to SQUARE shape", oam16x16.shape == OamShapeSize.SHAPE_SQUARE, oam16x16.shape)
check("16x16 OAM template decodes to size 1", oam16x16.size == 1, oam16x16.size)
check("16x16 OAM template's real dimensions match its own name", oam16x16.width == 16 and oam16x16.height == 16)

-- Decode the real Item Ball sprite using OamShapeSize's computed tile
-- dimensions (not a hand-fed constant like the player sprite's tests
-- use) -- proving the pipeline generalizes to a second, different real
-- object.
local tiles = ObjectSprite.decodeFrameTiles(data, addrs.gObjectEventPic_ItemBall, oam16x16.widthTiles, oam16x16.heightTiles, 0)
local palette = GbaGraphics.decodePalette(data, addrs.gObjectEventPal_NpcWhite)
local img = ObjectSprite.buildImage(tiles, palette, oam16x16.widthTiles, oam16x16.heightTiles)
check("Item Ball decodes to the OAM-derived 16x16 size", img.width == 16 and img.height == 16)

local hasOpaquePixel = false
for y = 0, img.height - 1 do
  for x = 0, img.width - 1 do
    if img.getPixel(x, y).a == 1 then hasOpaquePixel = true end
  end
end
check("Item Ball decode has real visible pixels, not a blank/garbage frame", hasOpaquePixel)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
