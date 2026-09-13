-- Pure adjacent-map connection selection/placement, ported from
-- fieldmap.c's GetIncomingConnection / IsPosInIncomingConnectingMap /
-- IsCoordInIncomingConnectingMap / SetPositionFromConnection.  Keeping the
-- geometry separate from ROM loading lets every map source (including a
-- future mod) use the same traversal rule.

local Traversal = {}

Traversal.SOUTH = 1
Traversal.NORTH = 2
Traversal.WEST = 3
Traversal.EAST = 4

local function orderedConnections(connections)
  local indexes = {}
  for index in pairs(connections or {}) do
    if type(index) == "number" then indexes[#indexes + 1] = index end
  end
  table.sort(indexes)
  local out = {}
  for _, index in ipairs(indexes) do out[#out + 1] = connections[index] end
  return out
end

-- Direct translation of IsCoordInIncomingConnectingMap. Source/destination
-- sizes are the layout's width or height, matching the source function.
function Traversal.coversCoordinate(coord, sourceSize, destinationSize, offset)
  local offset2 = math.max(offset, 0)
  if destinationSize + offset < sourceSize then
    sourceSize = destinationSize + offset
  end
  return offset2 <= coord and coord <= sourceSize
end

-- Returns the edge direction and the source-map coordinate along the edge.
-- x/y may be exactly one tile beyond the current map after a completed step.
function Traversal.edgeAt(x, y, width, height)
  if x < 0 then return Traversal.WEST, y end
  if x >= width then return Traversal.EAST, y end
  if y < 0 then return Traversal.NORTH, x end
  if y >= height then return Traversal.SOUTH, x end
  return nil
end

-- destinationSize(connection) returns the destination width for north/south
-- connections or height for east/west connections. Returns the first
-- same-direction connection whose actual span covers sourceCoord.
function Traversal.findIncoming(connections, direction, sourceCoord, sourceSize, destinationSize)
  for _, connection in ipairs(orderedConnections(connections)) do
    if connection.direction == direction then
      local targetSize = destinationSize(connection)
      if targetSize and Traversal.coversCoordinate(sourceCoord, sourceSize, targetSize, connection.offset) then
        return connection
      end
    end
  end
  return nil
end

-- Computes the tile in the destination map after a one-tile edge step. The
-- caller provides destination dimensions after loading/resolving that map.
function Traversal.destinationPosition(connection, x, y, width, height)
  if connection.direction == Traversal.NORTH then
    return x - connection.offset, height - 1
  elseif connection.direction == Traversal.SOUTH then
    return x - connection.offset, 0
  elseif connection.direction == Traversal.WEST then
    return width - 1, y - connection.offset
  elseif connection.direction == Traversal.EAST then
    return 0, y - connection.offset
  end
  error("unsupported map connection direction " .. tostring(connection.direction))
end

return Traversal
