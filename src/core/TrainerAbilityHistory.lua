-- Standalone native ability knowledge; deliberately not wired into live AI.
-- Source: pret/pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788:
-- include/battle.h:295-302 (side-owned abilities[2]);
-- src/battle_ai_script_commands.c:262-286 (fresh history), 481-485 (record),
-- 1138-1195 (query); include/constants/abilities.h:27,46,75 (trapping IDs).
--
-- new(speciesLookup): lookup(speciesId) returns a native imported species
-- record with abilities = { firstId, secondId } (Lua's 1-based slots).
-- :record(side, abilityId): side 0=player, 1=foe. Player writes include zero;
-- foe calls are no-ops. No species lookup or RNG is used.
-- :query(side, speciesId, actualAbilityId, rng): rng is the caller's shared
-- object with :next16(). Only two nonzero candidates require RNG. No guess
-- is cached. Species and RNG arguments are validated only when needed;
-- actual ability is likewise unnecessary when player history is nonzero.
-- Native IDs are unsigned integers: side 0/1, species u16, abilities u8,
-- RNG result u16. Missing/malformed required inputs raise an error, never
-- substitute actual ability. This helper neither owns nor seeds the RNG.
-- Each new object is a fresh battle; replacement does not clear history.

local TrainerAbilityHistory = {}

local function unsigned(value, maximum, name)
  assert(type(value) == "number" and value >= 0 and value <= maximum
    and value == math.floor(value), "TrainerAbilityHistory: invalid " .. name)
  return value
end

local function sourceSide(side)
  return unsigned(side, 1, "source side (0=player, 1=foe)")
end

function TrainerAbilityHistory.new(speciesLookup)
  assert(type(speciesLookup) == "function", "TrainerAbilityHistory: species lookup required")
  -- Private side-owned state, never returned as a mutable table. Foe history
  -- is always zero because the source writer only accepts player-side writes.
  local playerAbility = 0
  local history = {}

  function history:record(side, abilityId)
    -- RecordAbilityBattle:481-485: no comparison to current species/ability.
    if sourceSide(side) == 0 then
      playerAbility = unsigned(abilityId, 255, "recorded ability")
    end
  end

  function history:query(side, speciesId, actualAbilityId, rng)
    -- Cmd_get_ability:1189-1193: foe knows its actual ability directly.
    if sourceSide(side) == 1 then
      return unsigned(actualAbilityId, 255, "actual ability")
    end
    -- :1151-1156: recorded knowledge wins even after species replacement.
    if playerAbility ~= 0 then return playerAbility end

    unsigned(actualAbilityId, 255, "actual ability")
    -- :1159-1166: trapping abilities are known before consulting species.
    if actualAbilityId == 23 or actualAbilityId == 42 or actualAbilityId == 71 then
      return actualAbilityId
    end

    unsigned(speciesId, 65535, "species")
    local species = speciesLookup(speciesId)
    assert(type(species) == "table" and type(species.abilities) == "table",
      "TrainerAbilityHistory: missing species abilities")
    local first = unsigned(species.abilities[1], 255, "first species ability")
    local second = unsigned(species.abilities[2], 255, "second species ability")
    -- :1168-1187: zero-first fallback, including [0,0], consumes no draw.
    if first == 0 then return second end
    if second == 0 then return first end

    assert(type(rng) == "table" and type(rng.next16) == "function",
      "TrainerAbilityHistory: shared RNG required")
    local draw = unsigned(rng:next16(), 65535, "RNG result")
    -- :1173-1178: odd chooses first, even chooses second, every query.
    if draw % 2 ~= 0 then return first end
    return second
  end

  return history
end

return TrainerAbilityHistory
