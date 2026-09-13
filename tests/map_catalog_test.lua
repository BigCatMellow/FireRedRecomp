-- Complete ROM map enumeration and reachability validation. Opt-in because
-- the canonical catalog is created from a verified player-provided ROM.
package.path = package.path .. ";./?.lua"

local romPath = os.getenv("POKEPORT_ROM")
if not romPath then
  print("SKIP: set POKEPORT_ROM=/path/to/verified/pokefirered.gba to run this test")
  os.exit(0)
end

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local MapCatalog = require("import.MapCatalog")
local MapReachability = require("src.core.MapReachability")

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and " -- " .. tostring(detail) or ""))
  end
end

local ok, info = RomImporter.verify(romPath)
if not ok then
  print("FAIL: ROM did not verify -- " .. tostring(info))
  os.exit(1)
end
local hash = assert(RomImporter._sha1HexOfFile(romPath))
local profile = assert(RomAddresses[hash])
local file = assert(io.open(romPath, "rb"))
local data = assert(file:read("*a"))
file:close()

local catalog = MapCatalog.collect(data, profile)
check("all 425 verified FireRed maps enumerate", #catalog.ids == 425, #catalog.ids)

local validLayouts, scriptTables = 0, 0
for _, id in ipairs(catalog.ids) do
  local map = catalog.maps[id]
  if map.layout.width > 0 and map.layout.height > 0 then validLayouts = validLayouts + 1 end
  if map.header.mapScriptsPtr ~= 0 and map.scripts then scriptTables = scriptTables + 1 end
end
check("every cataloged map has a positive-size layout", validLayouts == #catalog.ids, validLayouts)
check("every map script-hook table resolves", scriptTables == #catalog.ids, scriptTables)

local graph = MapReachability.build(catalog.maps)
local invalidEdges = 0
for _, sourceId in ipairs(catalog.ids) do
  for _, edge in ipairs(graph[sourceId]) do
    if not MapCatalog.isUndefinedMapId(edge.mapId) and not catalog.maps[edge.mapId] then
      invalidEdges = invalidEdges + 1
    end
  end
end
check("every non-sentinel warp and connection target is cataloged", invalidEdges == 0, invalidEdges)

local house = MapReachability.mapId(4, 0)
local route1 = MapReachability.mapId(3, 19)
local path = MapReachability.path(graph, house, route1)
check("Player's House reaches Route 1 through the real map graph",
  path and #path >= 3 and path[1] == house and path[#path] == route1)

local reachable = MapReachability.reachable(graph, house, function(mapId)
  return not MapCatalog.isUndefinedMapId(mapId) and catalog.maps[mapId] ~= nil
end)
local reachableCount = 0
for _ in pairs(reachable) do reachableCount = reachableCount + 1 end
check("255 imported maps are graph-reachable from Player's House", reachableCount == 255, reachableCount)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
