-- Run: lua5.1 tests/metatile_attributes_test.lua
-- POKEPORT_ROM=<path> exercises the real-ROM-gated checks below.
package.path = package.path .. ";./?.lua"
local MetatileAttributes = require("import.MetatileAttributes")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- Synthetic packing test: raw = behavior | terrain<<9 | encounterType<<24 | layerType<<29
-- (real bit layout, src/fieldmap.c sMetatileAttrMasks/sMetatileAttrShifts).
local function packRaw(behavior, terrain, encounterType, layerType)
  return behavior + terrain * 512 + encounterType * 16777216 + layerType * 536870912
end

local function u32leBytes(v)
  return string.char(v % 256, math.floor(v / 256) % 256, math.floor(v / 65536) % 256, math.floor(v / 16777216) % 256)
end

-- Build a tiny fake "ROM" where metatileAttributesPtr = 0x08000000 (offset 0)
-- so a single u32 entry sits right at the start of the data string.
local fakeData = u32leBytes(packRaw(0x69, 5, 3, 2))
local decoded = MetatileAttributes.resolve(fakeData, 0x08000000, 0)
check("behavior decodes", decoded.behavior == 0x69, decoded.behavior)
check("terrain decodes", decoded.terrain == 5, decoded.terrain)
check("encounterType decodes", decoded.encounterType == 3, decoded.encounterType)
check("layerType decodes", decoded.layerType == 2, decoded.layerType)

-- Combined-space addressing: metatile 640 should read the SECOND tileset's
-- first entry (local index 0), metatile 0 the FIRST tileset's first entry.
local primaryData = u32leBytes(packRaw(0x02, 0, 0, 0)) -- MB_TALL_GRASS
local secondaryData = u32leBytes(packRaw(0x69, 0, 0, 0)) -- MB_WARP_DOOR
-- Concatenate so both live in one buffer at different fake ROM addresses.
local combined = primaryData .. secondaryData
local primaryPtr = 0x08000000
local secondaryPtr = 0x08000000 + #primaryData
local atPrimary = MetatileAttributes.resolveCombined(combined, primaryPtr, secondaryPtr, 0)
local atSecondary = MetatileAttributes.resolveCombined(combined, primaryPtr, secondaryPtr, 640)
check("combined id 0 reads primary", atPrimary.behavior == 0x02, atPrimary.behavior)
check("combined id 640 reads secondary", atSecondary.behavior == 0x69, atSecondary.behavior)

-- Real-ROM-gated: cross-check against Phase 1's already-verified MapEvents
-- warp coordinate and against Route 1's real wild-encounter grass.
local romPath = os.getenv("POKEPORT_ROM")
if romPath then
  local RomAddresses = require("import.RomAddresses")
  local MapHeader = require("import.MapHeader")
  local MapLayout = require("import.MapLayout")
  local MapBlockData = require("import.MapBlockData")
  local Tileset = require("import.Tileset")

  local f = io.open(romPath, "rb")
  local data = f:read("*a")
  f:close()
  local addrs = RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"]

  local function tilesetsFor(mapId)
    local header = MapHeader.resolve(data, addrs.gMapGroups, mapId)
    local layout = MapLayout.resolve(data, header.mapLayoutPtr)
    local blockData = MapBlockData.resolve(data, layout.mapPtr, layout.width, layout.height)
    local primary = Tileset.resolve(data, layout.primaryTilesetPtr)
    local secondary = Tileset.resolve(data, layout.secondaryTilesetPtr)
    return layout, blockData, primary, secondary
  end

  -- Pallet Town (3,0): the player's-house warp-door tile at block (6,7)
  -- (MapEvents.lua's already-verified warp coordinate) must decode to
  -- MB_WARP_DOOR (0x69) -- confirms the real door metatile's BEHAVIOR
  -- byte matches its real warp event, independent of raw collision bits.
  local layout, blockData, primary, secondary = tilesetsFor(3 * 256 + 0)
  local doorCell = blockData[7 * layout.width + 6]
  local doorAttr = MetatileAttributes.resolveCombined(data, primary.metatileAttributesPtr, secondary.metatileAttributesPtr, doorCell.metatileId)
  check("Pallet Town player's-house door is MB_WARP_DOOR", doorAttr.behavior == 0x69, doorAttr.behavior)

  -- Route 1 (3,19): a real, wild-encounter-bearing map must contain a
  -- nonzero number of MB_TALL_GRASS (0x02) tiles.
  layout, blockData, primary, secondary = tilesetsFor(3 * 256 + 19)
  local grassCount = 0
  for i = 0, layout.width * layout.height - 1 do
    local cell = blockData[i]
    local attr = MetatileAttributes.resolveCombined(data, primary.metatileAttributesPtr, secondary.metatileAttributesPtr, cell.metatileId)
    if attr.behavior == 0x02 then grassCount = grassCount + 1 end
  end
  check("Route 1 has real tall-grass tiles", grassCount > 0, grassCount)
else
  print("SKIP: real-ROM checks (set POKEPORT_ROM to run them)")
end

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
