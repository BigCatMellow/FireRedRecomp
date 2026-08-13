-- Real NPC interaction trigger detection: "player faces an object event and
-- presses A" (pokefirered src/field_control_avatar.c's
-- CheckStandardWildEncounter-adjacent input handling ->
-- GetInFrontOfPlayer/TryStartInteraction chain -- the general shape of
-- which real object event is "in front of and adjacent to" the player).
-- This module only builds the PURE detection function ("which NPC, if any,
-- is the player currently facing"); actually wiring an A-button press to
-- calling this + running the result's scriptPtr through
-- ScriptInterpreter.lua (with the real `faceplayer` opcode turning the NPC
-- to face back) is the deferred main.lua integration step -- see the
-- handoff doc / this file's header for exactly what that would need to do.
--
-- Real adjacency rule (src/field_player_avatar.c's
-- GetPlayerFacingDirection-adjacent logic, and general series-documented
-- behavior): the tile exactly one step in the player's current facing
-- direction, at the SAME real elevation the interaction system checks
-- (elevation mismatches are intentionally not modeled here -- same
-- documented simplification as PlayerMovement.lua's collision scope, which
-- also skips elevation). An NPC standing exactly on that tile is the
-- interaction target; ties (two objects on one tile) aren't possible in
-- real data (object-event collision already prevents two objects sharing a
-- tile, per event_object_movement.c's DoesObjectCollideWithObjectAt) so
-- this returns the first match without needing tie-breaking logic.

local PlayerMovement = require("src.core.PlayerMovement")

local ObjectEventInteraction = {}

local DIRECTION_DELTA = {
  [PlayerMovement.DOWN] = { dx = 0, dy = 1 },
  [PlayerMovement.UP] = { dx = 0, dy = -1 },
  [PlayerMovement.LEFT] = { dx = -1, dy = 0 },
  [PlayerMovement.RIGHT] = { dx = 1, dy = 0 },
}

-- playerX/playerY: the player's current tile position (integers -- a
-- mid-step player, per PlayerMovement.lua's tileX/tileY, is "still on" the
-- tile it's walking away from until the step completes, matching real
-- ObjectEventIsMovementOverridden-guarded input rejection during a step;
-- callers are expected to only invoke this when the player isn't mid-step,
-- same as the real game ignoring interact input during a queued movement).
-- playerFacingDirection: one of PlayerMovement.DOWN/UP/LEFT/RIGHT.
-- npcs: a list of ObjectEventState NPC states (this map's `.new()` result).
-- Returns the NPC standing on the faced tile, or nil if none.
function ObjectEventInteraction.findInteractionTarget(playerX, playerY, playerFacingDirection, npcs)
  local delta = DIRECTION_DELTA[playerFacingDirection]
  if not delta then
    error("ObjectEventInteraction: unknown facing direction " .. tostring(playerFacingDirection))
  end
  local targetX, targetY = playerX + delta.dx, playerY + delta.dy

  for _, npc in ipairs(npcs) do
    if npc.x == targetX and npc.y == targetY then
      return npc
    end
  end
  return nil
end

return ObjectEventInteraction
