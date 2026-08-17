-- Per-step glue between the player actually walking and
-- src/core/WildEncounterSelector.lua's real dice rolls. Pure Lua (no
-- love2d, no ROM decode) so "does a step into real tall grass roll the
-- real trigger dice" is unit-testable without a running game -- see
-- tests/wild_encounter_trigger_test.lua.
--
-- WildEncounterSelector.shouldTrigger() needs a `behaviorChanged` flag,
-- because real DoGlobalWildEncounterDiceRoll (src/wild_encounter.c,
-- reached from StandardWildEncounter) only runs its 60% global roll when
-- the metatile behavior under the player DIFFERS from the previous step's
-- (`sWildEncounterData.previousMetatileBehavior`). Nothing else in this
-- project tracks that, so this module owns it: :onStep(behavior, info)
-- remembers the previous step's behavior across calls, exactly like the
-- real static does.
--
-- Real StandardWildEncounter also gates on the behavior being an encounter
-- tile at all (MetatileBehavior_IsLandWildEncounter /
-- _IsWaterWildEncounter). Only the LAND case is wired here, and only for
-- MB_TALL_GRASS -- the one behavior main.lua already detects and the one
-- the handoff scoped. Real land encounters also fire on MB_LONG_GRASS and
-- several cave/other behaviors; surfing/fishing water encounters are a
-- separate real path entirely. Passing a different behavior byte in
-- `landBehaviors` at construction is how that gets widened later.
--
-- Explicitly NOT ported (same list WildEncounterSelector.lua documents):
-- repel level filtering, Bike/Flute/Cleanse Tag/ability rate modifiers,
-- the encounterRateBuff step accumulator, roamers. This pure module still
-- only returns the rolled species/level; main.lua owns the separate
-- integration boundary that starts the bounded Phase 4 live battle scene.

local WildEncounterSelector = require("src.core.WildEncounterSelector")

local WildEncounterTrigger = {}
WildEncounterTrigger.__index = WildEncounterTrigger

-- MetatileAttributes.BEHAVIOR.MB_TALL_GRASS's real value. Hardcoded rather
-- than required from MetatileAttributes.lua so this module stays a pure
-- state machine with one dependency; the caller can override via
-- opts.landBehaviors anyway.
WildEncounterTrigger.MB_TALL_GRASS = 0x02

-- opts.globalRng: an Rng instance for the real global Random() stream --
--   the SAME instance the rest of the game's Random() calls use (real
--   gRngValue is one shared stream; the global 60% dice roll and the
--   slot/level rolls both draw from it).
-- opts.triggerRng: WildEncounterSelector.newTriggerRng(seed) -- the real
--   SEPARATE WildEncounterRandom() stream (ISO_RANDOMIZE2). Must not be
--   the same object as globalRng.
-- opts.landBehaviors: optional set of metatile behavior bytes treated as
--   real land encounter tiles (defaults to just MB_TALL_GRASS).
function WildEncounterTrigger.new(opts)
  opts = opts or {}
  if not opts.globalRng or not opts.triggerRng then
    error("WildEncounterTrigger: needs both opts.globalRng and opts.triggerRng (two real, separate RNG streams)")
  end
  if opts.globalRng == opts.triggerRng then
    error("WildEncounterTrigger: globalRng and triggerRng must be different Rng instances " ..
      "(real Random() and WildEncounterRandom() are independently-seeded streams)")
  end
  return setmetatable({
    globalRng = opts.globalRng,
    triggerRng = opts.triggerRng,
    landBehaviors = opts.landBehaviors or { [WildEncounterTrigger.MB_TALL_GRASS] = true },
    previousBehavior = nil, -- real sWildEncounterData.previousMetatileBehavior
  }, WildEncounterTrigger)
end

-- Call once per COMPLETED player step (real StandardWildEncounter is
-- reached from the field-control step handler, not every frame).
--   behavior: the real metatile behavior byte under the player's new tile
--     (nil is fine -- off-map/unloaded, treated as a non-encounter tile
--     that still updates the previous-behavior memory).
--   landInfo: this map's real WildEncounters.resolveInfo(...) land table
--     ({ encounterRate, mons }), or nil if the map has no land encounters.
-- Returns nil if no encounter triggers, or WildEncounterSelector.roll()'s
-- real result table ({ slot, species, level }) if one does.
function WildEncounterTrigger:onStep(behavior, landInfo)
  local changed = behavior ~= self.previousBehavior
  self.previousBehavior = behavior

  if not self.landBehaviors[behavior] then return nil end
  if not landInfo then return nil end

  if not WildEncounterSelector.shouldTrigger(self.globalRng, self.triggerRng, landInfo.encounterRate, changed) then
    return nil
  end
  return WildEncounterSelector.roll(landInfo, self.globalRng, "land")
end

return WildEncounterTrigger
