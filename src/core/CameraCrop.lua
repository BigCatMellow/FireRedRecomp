-- Pure field-camera crop geometry used by the live overworld renderer.
--
-- FireRed's visible field is exactly 240x160 pixels.  The map crop follows
-- the player's 16px tile centre while that centre can remain inside the map;
-- near an edge it clamps to the composited map bounds.  Keeping this math in
-- one pure module lets the parity harness prove the same coordinates used by
-- the live map quad and object/scissor draws, without changing camera policy.
--
-- Verified by tests/camera_crop_test.lua, including centred and both-edge
-- cases at the real 240x160 dimensions.

local CameraCrop = {}

CameraCrop.WIDTH = 240
CameraCrop.HEIGHT = 160

local function clamp(value, low, high)
  if value < low then return low end
  if value > high then return high end
  return value
end

-- playerX/playerY are the player's top-left pixel positions in the
-- composited map. mapWidth/mapHeight are the composited image dimensions.
-- Maps presented through this field renderer must be at least screen-sized;
-- failing loudly is safer than silently producing a negative quad origin.
function CameraCrop.forPlayer(playerX, playerY, mapWidth, mapHeight)
  assert(type(playerX) == "number" and type(playerY) == "number", "camera player coordinates must be numbers")
  assert(type(mapWidth) == "number" and type(mapHeight) == "number", "camera map dimensions must be numbers")
  assert(mapWidth >= CameraCrop.WIDTH and mapHeight >= CameraCrop.HEIGHT,
    "camera map dimensions must be at least 240x160")

  return {
    x = clamp(playerX + 8 - CameraCrop.WIDTH / 2, 0, mapWidth - CameraCrop.WIDTH),
    y = clamp(playerY + 8 - CameraCrop.HEIGHT / 2, 0, mapHeight - CameraCrop.HEIGHT),
    width = CameraCrop.WIDTH,
    height = CameraCrop.HEIGHT,
  }
end

return CameraCrop
