-- Pure geometry for the native FireRed field viewport.  This module owns
-- only the 240x160 camera crop inside a composited map; ViewportScale owns
-- the separate outer-window scaling/letterboxing contract.
--
-- Player coordinates and map dimensions are in composited-map pixels.  A
-- player object occupies a 16x16 field tile, so follow() anchors on its
-- center.  Origins intentionally retain fractional coordinates if a caller
-- has sub-pixel motion: the world then scrolls continuously rather than
-- snapping while PlayerMovement completes a tile step.

local CameraViewport = {
  WIDTH = 240,
  HEIGHT = 160,
  PLAYER_CENTER_X = 8,
  PLAYER_CENTER_Y = 8,
}

local function clamp(value, minimum, maximum)
  if value < minimum then return minimum end
  if value > maximum then return maximum end
  return value
end

-- Return the fixed logical viewport, its clamped world origin, and the part
-- of that viewport that may be sampled from the map image.  sourceWidth and
-- sourceHeight make maps smaller than a GBA screen explicit: the renderer
-- clears the fixed viewport first, then only draws the available map region.
function CameraViewport.follow(mapWidth, mapHeight, playerX, playerY)
  assert(type(mapWidth) == "number" and mapWidth > 0, "mapWidth must be positive")
  assert(type(mapHeight) == "number" and mapHeight > 0, "mapHeight must be positive")
  assert(type(playerX) == "number", "playerX must be numeric")
  assert(type(playerY) == "number", "playerY must be numeric")

  local x = clamp(playerX + CameraViewport.PLAYER_CENTER_X - CameraViewport.WIDTH / 2,
    0, math.max(0, mapWidth - CameraViewport.WIDTH))
  local y = clamp(playerY + CameraViewport.PLAYER_CENTER_Y - CameraViewport.HEIGHT / 2,
    0, math.max(0, mapHeight - CameraViewport.HEIGHT))
  return {
    width = CameraViewport.WIDTH,
    height = CameraViewport.HEIGHT,
    x = x,
    y = y,
    sourceWidth = math.min(CameraViewport.WIDTH, mapWidth),
    sourceHeight = math.min(CameraViewport.HEIGHT, mapHeight),
  }
end

function CameraViewport.worldToScreen(camera, worldX, worldY)
  assert(camera and camera.x and camera.y, "camera origin is required")
  return worldX - camera.x, worldY - camera.y
end

return CameraViewport
