-- Integration test: composites several structurally different real maps
-- (not just Pallet Town) to prove the compositor generalizes -- an outdoor
-- town, an outdoor route, and an indoor building with an entirely
-- different tileset. Opt-in via POKEPORT_ROM, skips cleanly otherwise.
--
-- Run: POKEPORT_ROM=/path/to/verified/pokefirered.gba lua5.1 tests/map_generalization_test.lua
package.path = package.path .. ";./?.lua"

local romPath = os.getenv("POKEPORT_ROM")
if not romPath then
  print("SKIP: set POKEPORT_ROM=/path/to/verified/pokefirered.gba to run this test")
  os.exit(0)
end

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local MapHeader = require("import.MapHeader")
local MapLayout = require("import.MapLayout")
local MapBlockData = require("import.MapBlockData")
local MapCompositor = require("import.MapCompositor")

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

local function compositeMap(mapId)
  local header = MapHeader.resolve(data, addrs.gMapGroups, mapId)
  local layout = MapLayout.resolve(data, header.mapLayoutPtr)
  local blockData = MapBlockData.resolve(data, layout.mapPtr, layout.width, layout.height)
  local primary = MapCompositor.loadTilesetData(data, layout.primaryTilesetPtr)
  local secondary = MapCompositor.loadTilesetData(data, layout.secondaryTilesetPtr)
  local composited = MapCompositor.composite(data, primary, secondary, blockData, layout.width, layout.height)
  return layout, composited
end

-- MAP_ROUTE1 = group 3, num 19. Known layout: width 24, height 40
-- (data/layouts/layouts.json LAYOUT_ROUTE1).
local route1Layout, route1Image = compositeMap(3 * 256 + 19)
check("Route 1 composites without error and is 24x40 metatiles", route1Layout.width == 24 and route1Layout.height == 40, route1Layout.width .. "x" .. route1Layout.height)
check("Route 1 image is 384x640 px", route1Image.width == 384 and route1Image.height == 640)

-- MAP_PALLET_TOWN_PLAYERS_HOUSE_1F = group 4, num 0. Known layout: width 13,
-- height 10 (data/layouts/layouts.json LAYOUT_PALLET_TOWN_PLAYERS_HOUSE_1F)
-- -- an indoor map with a completely different tileset than Pallet Town's.
local houseLayout, houseImage = compositeMap(4 * 256 + 0)
check("Player's House 1F composites without error and is 13x10 metatiles", houseLayout.width == 13 and houseLayout.height == 10, houseLayout.width .. "x" .. houseLayout.height)
check("Player's House 1F image is 208x160 px", houseImage.width == 208 and houseImage.height == 160)

-- Sanity: neither image is blank (all-black) -- a real bug (e.g. wrong
-- tileset pointer) tends to produce that instead of a clean crash.
local function hasNonBlackPixel(image)
  for y = 0, image.height - 1, 7 do
    for x = 0, image.width - 1, 7 do
      local p = image.getPixel(x, y)
      if p.r > 0 or p.g > 0 or p.b > 0 then return true end
    end
  end
  return false
end
check("Route 1 image has non-black pixels", hasNonBlackPixel(route1Image))
check("Player's House 1F image has non-black pixels", hasNonBlackPixel(houseImage))

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
