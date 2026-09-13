package.path = package.path .. ";./?.lua"

local Center = require("src.core.PokemonCenter")
local passed, failed = 0, 0
local function check(name, value)
  if value then passed = passed + 1 else failed = failed + 1; print("FAIL: " .. name) end
end

local nurse = {localId=1, graphicsId=Center.NURSE_GRAPHICS_ID}
check("a real Nurse object identifies a Pokémon Center", Center.isCenter({[0]=nurse}))
check("only Nurse graphics select the heal interaction", Center.isNurse(nurse) and not Center.isNurse({graphicsId=63}))
check("ordinary indoor maps are not inferred as Centers", not Center.isCenter({[0]={graphicsId=12}}))

local location = Center.respawnLocation({[0]=nurse}, {
  [0]={mapGroup=3, mapNum=1, warpId=0},
}, function(warp)
  check("resolver receives the real outward warp", warp.mapGroup == 3 and warp.mapNum == 1 and warp.warpId == 0)
  return {x=26, y=27}
end)
check("Center entry stores the outward map and exact door tile", location
  and location.mapGroup == 3 and location.mapNum == 1 and location.warpId == -1
  and location.x == 26 and location.y == 27)
check("non-Centers never manufacture a respawn point", Center.respawnLocation({}, {}, function() error("must not resolve") end) == nil)

local romPath = os.getenv("POKEPORT_ROM")
if romPath then
  local RomImporter = require("import.RomImporter")
  local RomAddresses = require("import.RomAddresses")
  local MapCatalog = require("import.MapCatalog")
  local ok = RomImporter.verify(romPath)
  check("ROM profile verifies before Center-map coverage", ok)
  local hash = assert(RomImporter._sha1HexOfFile(romPath))
  local profile = assert(RomAddresses[hash])
  local file = assert(io.open(romPath, "rb"))
  local data = assert(file:read("*a"))
  file:close()
  local catalog = MapCatalog.collect(data, profile)
  local centers = 0
  for _, mapId in ipairs(catalog.ids) do
    local map = catalog.maps[mapId]
    if Center.isCenter(map.events.objectEvents) then
      centers = centers + 1
      local location = Center.respawnLocation(map.events.objectEvents, map.events.warps, function(warp)
        local destination = catalog.maps[warp.mapGroup * 256 + warp.mapNum]
        return destination and destination.events.warps[warp.warpId]
      end)
      check("every Nurse map has a resolvable outward respawn door", location and catalog.maps[location.mapGroup * 256 + location.mapNum])
    end
  end
  -- The real sPokeCenter1FMaps list has 19 Centers plus Union Room.
  check("all 20 real Nurse maps are recognized", centers == 20, centers)
end

print(("pokemon_center_test: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
