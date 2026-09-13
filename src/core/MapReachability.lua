-- Pure directed map graph for ROM-derived warp and connection records.
-- Map ids use FireRed's packed (group << 8 | number) convention.
local MapReachability = {}

local function id(group, num) return group * 256 + num end

MapReachability.mapId = id

function MapReachability.build(maps)
  local graph = {}
  for mapId, map in pairs(maps) do
    local edges, seen = {}, {}
    local function add(group, num, kind)
      local target = id(group, num)
      local key = kind .. ":" .. target
      if not seen[key] then
        seen[key] = true
        edges[#edges + 1] = { mapId=target, kind=kind }
      end
    end
    for _, warp in pairs((map.events or {}).warps or {}) do add(warp.mapGroup, warp.mapNum, "warp") end
    for _, connection in pairs(map.connections or {}) do add(connection.mapGroup, connection.mapNum, "connection") end
    graph[mapId] = edges
  end
  return graph
end

function MapReachability.path(graph, startId, goalId)
  if startId == goalId then return { startId } end
  local queue, head, previous = { startId }, 1, { [startId]=false }
  while queue[head] do
    local current = queue[head]; head = head + 1
    for _, edge in ipairs(graph[current] or {}) do
      if previous[edge.mapId] == nil then
        previous[edge.mapId] = current
        if edge.mapId == goalId then
          local out, node = { goalId }, current
          while node do out[#out + 1] = node; node = previous[node] end
          local reversed = {}
          for i = #out, 1, -1 do reversed[#reversed + 1] = out[i] end
          return reversed
        end
        queue[#queue + 1] = edge.mapId
      end
    end
  end
  return nil
end

-- Returns the deterministic breadth-first reachable set from one map. An
-- optional predicate lets callers exclude sentinel/unimported destinations
-- without teaching this pure graph module about one ROM profile's catalog.
function MapReachability.reachable(graph, startId, include)
  include = include or function() return true end
  local queue, head, seen = { startId }, 1, { [startId]=true }
  while queue[head] do
    local current = queue[head]
    head = head + 1
    for _, edge in ipairs(graph[current] or {}) do
      if not seen[edge.mapId] and include(edge.mapId, edge) then
        seen[edge.mapId] = true
        queue[#queue + 1] = edge.mapId
      end
    end
  end
  return seen
end

return MapReachability
