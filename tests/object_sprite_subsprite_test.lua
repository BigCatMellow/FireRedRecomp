-- Integration test: decodes the real SS Anne overworld object (128x64px,
-- exceeding the 64x64px single-OAM-entry cap) by compositing its real
-- 4-entry SubspriteTable, and separately decodes the player's real 16x32
-- SubspriteTable (a structurally different, single-real-entry table) to
-- prove SubspriteTable.lua isn't special-cased to the 4-way SS Anne case.
-- Opt-in via POKEPORT_ROM, skips cleanly otherwise.
--
-- Run: POKEPORT_ROM=/path/to/verified/pokefirered.gba lua5.1 tests/object_sprite_subsprite_test.lua
package.path = package.path .. ";./?.lua"

local romPath = os.getenv("POKEPORT_ROM")
if not romPath then
  print("SKIP: set POKEPORT_ROM=/path/to/verified/pokefirered.gba to run this test")
  os.exit(0)
end

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local ObjectSprite = require("import.ObjectSprite")
local SubspriteTable = require("import.SubspriteTable")

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

-- SS Anne: 4 real subsprites (gObjectEventSpriteOamTable_128x64_0), each
-- 64x32, arranged in a 2x2 grid -- should composite to exactly the real
-- declared 128x64 gObjectEventGraphicsInfo_SSAnne dimensions.
local ssAnneSubsprites = SubspriteTable.decodeSubsprites(data, addrs.gObjectEventSpriteOamTable_128x64_0, 4)
check("SS Anne real subsprite count", #ssAnneSubsprites == 4)
check("SS Anne subsprite 1 real offset/shape/size", ssAnneSubsprites[1].x == -32 and ssAnneSubsprites[1].y == -16
  and ssAnneSubsprites[1].shape == 1 and ssAnneSubsprites[1].size == 3, ssAnneSubsprites[1].x)
check("SS Anne subsprite 4 real offset/tileOffset", ssAnneSubsprites[4].x == 32 and ssAnneSubsprites[4].y == 16
  and ssAnneSubsprites[4].tileOffset == 96, ssAnneSubsprites[4].tileOffset)

local ssAnneImg = ObjectSprite.compositeSubsprites(data, addrs.gObjectEventPic_SSAnne, addrs.gObjectEventPal_SSAnne, ssAnneSubsprites)
check("SS Anne composited bounding box matches real declared 128x64", ssAnneImg.width == 128 and ssAnneImg.height == 64,
  ssAnneImg.width .. "x" .. ssAnneImg.height)

-- Structural sanity: each of the 4 quadrants should contain at least one
-- opaque pixel (real ship hull/deck art, not a blank/garbage subsprite),
-- and quadrants shouldn't be identical copies of each other (would
-- indicate the tileOffset math is a no-op / all reading the same tiles).
local function quadrantHasOpaquePixel(x0, y0, x1, y1)
  for y = y0, y1 - 1 do
    for x = x0, x1 - 1 do
      if ssAnneImg.getPixel(x, y).a == 1 then return true end
    end
  end
  return false
end

check("SS Anne top-left quadrant has real visible pixels", quadrantHasOpaquePixel(0, 0, 64, 32))
check("SS Anne top-right quadrant has real visible pixels", quadrantHasOpaquePixel(64, 0, 128, 32))
check("SS Anne bottom-left quadrant has real visible pixels", quadrantHasOpaquePixel(0, 32, 64, 64))
check("SS Anne bottom-right quadrant has real visible pixels", quadrantHasOpaquePixel(64, 32, 128, 64))

local function quadrantSignature(x0, y0, x1, y1)
  local sig = {}
  for y = y0, y1 - 1 do
    for x = x0, x1 - 1 do
      local p = ssAnneImg.getPixel(x, y)
      sig[#sig + 1] = p.a == 1 and (p.r * 65536 + p.g * 256 + p.b) or -1
    end
  end
  return table.concat(sig, ",")
end

local topLeftSig = quadrantSignature(0, 0, 64, 32)
local topRightSig = quadrantSignature(64, 0, 128, 32)
local bottomLeftSig = quadrantSignature(0, 32, 64, 64)
check("SS Anne quadrants decode distinct tile data (top-left != top-right)", topLeftSig ~= topRightSig)
check("SS Anne quadrants decode distinct tile data (top-left != bottom-left)", topLeftSig ~= bottomLeftSig)

-- Player's real 16x32 SubspriteTable: index 0 is a real {0, NULL}
-- passthrough entry (fits one OAM entry, no compositing needed) --
-- confirms decodeTable correctly recognizes the real passthrough case
-- rather than assuming every SubspriteTable implies multi-OAM.
local playerTables = addrs.gObjectEventSpriteOamTables_16x16 -- structurally identical passthrough-first layout to the real _16x32 table
local firstEntry = SubspriteTable.decodeTable(data, playerTables)
check("real gObjectEventSpriteOamTables_16x16[0] is a passthrough (count=0)", firstEntry.count == 0, firstEntry.count)

-- gObjectEventSpriteOamTables_16x16[1] (8 bytes further in) is the real
-- {1, gObjectEventSpriteOamTable_16x16_0} entry -- resolves its raw ROM
-- pointer to exactly the address `nm` reports for that symbol.
local secondEntry = SubspriteTable.decodeTable(data, playerTables + 8)
check("real gObjectEventSpriteOamTables_16x16[1] has 1 subsprite", secondEntry.count == 1, secondEntry.count)
check("real gObjectEventSpriteOamTables_16x16[1] pointer resolves to the real known symbol address",
  #secondEntry.subsprites == 1 and secondEntry.subsprites[1].x == -8 and secondEntry.subsprites[1].priority == 2)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
