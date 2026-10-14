-- Bounded pre-spawn projection, not a map-script or dynamic-graphics system.
-- Source: pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788,
-- data/maps/ViridianCity/{map.json,scripts.inc}: local ID 4, VAR_0 graphics,
-- and SetOldManBlockingRoad/SetOldManStandingByRoad/SetOldManNormal.
-- The accepted project seam reconstructs a temporary template per map load;
-- it does not persist retail setobjectxyperm/setobjectmovementtype writes.
local ViridianOldManProjection = {}

-- Input is MapEvents' zero-based decoded list (possibly hide-filtered).
-- Success returns a new list with only the admitted template copied/changed.
-- Refusal returns the original list and an explicit diagnostic. No input,
-- session field, flag, scene variable, RNG or generic graphics policy changes.
function ViridianOldManProjection.apply(mapId, objectEvents, session)
  if mapId ~= 3 * 256 + 1 then return objectEvents, "wrong_map" end
  if type(session) ~= "table" or type(session.getVar) ~= "function" then
    return objectEvents, "missing_session"
  end
  if type(objectEvents) ~= "table" then return objectEvents, "invalid_templates" end

  local selectedIndex, index = nil, 0
  while objectEvents[index] ~= nil do
    local template = objectEvents[index]
    if type(template) == "table" and template.localId == 4 then
      if selectedIndex ~= nil then return objectEvents, "ambiguous_local_id" end
      selectedIndex = index
    end
    index = index + 1
  end
  if selectedIndex == nil then return objectEvents, "missing_template" end
  local template = objectEvents[selectedIndex]
  if template.kind ~= 0 then return objectEvents, "wrong_template_kind" end
  if template.graphicsId ~= 240 then return objectEvents, "wrong_base_graphics" end

  local ok, scene = pcall(session.getVar, session, 0x4051)
  if not ok then return objectEvents, "scene_read_failed" end
  if type(scene) ~= "number" or scene < 0 or scene == math.huge
      or scene ~= math.floor(scene) then
    return objectEvents, "invalid_scene"
  end

  local projected = {}
  for key, value in pairs(template) do projected[key] = value end
  projected.graphicsId = scene == 0 and 34 or 32
  if scene == 0 then
    projected.x, projected.y, projected.movementType = 21, 11, 8
  elseif scene == 1 then
    projected.x, projected.y, projected.movementType = 21, 8, 1
  end -- >=2 retains the decoded template's coordinates and movement type.

  local result = {}
  for key, value in pairs(objectEvents) do result[key] = value end
  result[selectedIndex] = projected
  return result
end

return ViridianOldManProjection
