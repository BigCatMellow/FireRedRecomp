-- Shared Pokémon Center rules.  The real map script sets lastHealLocation
-- when the player enters a Center; the Nurse then calls HealPlayerParty.
-- MapEvents already exposes the Center's outward door warp, so this keeps
-- the rule data-driven instead of maintaining a hand-written town table.

local PokemonCenter = {}

PokemonCenter.NURSE_GRAPHICS_ID = 64 -- OBJ_EVENT_GFX_NURSE

function PokemonCenter.isCenter(objectEvents)
  for _, event in pairs(objectEvents or {}) do
    if event.graphicsId == PokemonCenter.NURSE_GRAPHICS_ID then return true end
  end
  return false
end

function PokemonCenter.isNurse(event)
  return event and event.graphicsId == PokemonCenter.NURSE_GRAPHICS_ID
end

-- resolveDoor(warp) returns the corresponding destination warp event.  A
-- Center's first outward warp is its front door; its destination supplies
-- the exact outdoor map and tile that setrespawn stores in FireRed.
function PokemonCenter.respawnLocation(objectEvents, warps, resolveDoor)
  if not PokemonCenter.isCenter(objectEvents) then return nil end
  for _, warp in pairs(warps or {}) do
    local door = resolveDoor(warp)
    if door then
      return {
        mapGroup=warp.mapGroup, mapNum=warp.mapNum, warpId=-1,
        x=door.x, y=door.y,
      }
    end
  end
  return nil
end

return PokemonCenter
