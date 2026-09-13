-- Enumerates a ROM profile's complete map catalog into the canonical map
-- shape consumed by field systems.  Map groups carry no length in ROM, so
-- the verified profile supplies mapGroupCounts; never scan raw pointers for
-- a guessed terminator.
--
-- This boundary intentionally accepts a profile table, not just the retail
-- address table. A mod/import source can supply its own group counts and
-- still produce the same { maps, ids } catalog for downstream consumers.

local MapHeader = require("import.MapHeader")
local MapLayout = require("import.MapLayout")
local MapEvents = require("import.MapEvents")
local MapConnections = require("import.MapConnections")
local MapScripts = require("import.MapScripts")

local MapCatalog = {}

MapCatalog.UNDEFINED_MAP_GROUP = 127
MapCatalog.UNDEFINED_MAP_NUM = 127
MapCatalog.UNDEFINED_MAP_ID = 127 * 256 + 127

local function mapId(group, num)
  return group * 256 + num
end

function MapCatalog.isUndefinedMapId(id)
  return id == MapCatalog.UNDEFINED_MAP_ID
end

-- data: complete ROM bytes. profile: a verified address profile containing
-- gMapGroups and mapGroupCounts. Returns { maps = {[packedId] = record},
-- ids = {packedId, ...} }, where each record has header/layout/events/
-- connections/scripts.
function MapCatalog.collect(data, profile)
  assert(type(data) == "string", "ROM data is required")
  assert(type(profile) == "table" and type(profile.gMapGroups) == "number",
    "map profile with gMapGroups is required")
  assert(type(profile.mapGroupCounts) == "table",
    "map profile must provide verified mapGroupCounts")

  local catalog = { maps = {}, ids = {} }
  for group, count in ipairs(profile.mapGroupCounts) do
    assert(type(count) == "number" and count >= 0 and count == math.floor(count),
      "mapGroupCounts entries must be non-negative integers")
    group = group - 1 -- Lua arrays are one-based; FireRed map groups are zero-based.
    for num = 0, count - 1 do
      local id = mapId(group, num)
      local header = MapHeader.resolve(data, profile.gMapGroups, id)
      local layout = MapLayout.resolve(data, header.mapLayoutPtr)
      local events = header.eventsPtr ~= 0 and MapEvents.resolve(data, header.eventsPtr) or { warps = {} }
      local connections = header.connectionsPtr ~= 0
        and MapConnections.resolve(data, header.connectionsPtr) or {}
      local scripts = header.mapScriptsPtr ~= 0 and MapScripts.resolve(data, header.mapScriptsPtr) or {}
      catalog.maps[id] = {
        id = id,
        group = group,
        num = num,
        header = header,
        layout = layout,
        events = events,
        connections = connections,
        scripts = scripts,
      }
      catalog.ids[#catalog.ids + 1] = id
    end
  end
  return catalog
end

return MapCatalog
