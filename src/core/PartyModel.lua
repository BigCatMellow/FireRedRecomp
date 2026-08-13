-- In-memory player party: up to MAX_PARTY_SIZE (6, pokefirered
-- include/constants/global.h's PARTY_SIZE) Pokémon instances in slot
-- order. This is project-specific plumbing on top of the real data
-- modeled by PokemonStats/ExperienceTable/BoxPokemonCodec -- there's no
-- ROM struct to verify here, just clean, tested behavior matching how
-- pokefirered's own party array behaves (a fixed 6-slot array, add-to-
-- first-empty-slot, no gaps/compaction between occupied slots).
--
-- A "Pokémon instance" here is any plain Lua table the caller wants to
-- store (e.g. built by combining BoxPokemonCodec.decode()'s substructs
-- with PokemonStats.calculateAll()'s computed stats) -- this module
-- doesn't dictate that shape, it only manages the 6-slot container.

local PartyModel = {}
PartyModel.__index = PartyModel

PartyModel.MAX_PARTY_SIZE = 6 -- PARTY_SIZE, include/constants/global.h

function PartyModel.new()
  return setmetatable({ slots = {}, count = 0 }, PartyModel)
end

function PartyModel:isFull()
  return self.count >= PartyModel.MAX_PARTY_SIZE
end

-- Adds `mon` to the first empty slot (1-indexed, matching how the rest
-- of this project 1-indexes Lua arrays -- see PokemonStats/ExperienceTable
-- usage). Returns the slot index it was placed in, or nil + an error
-- message if the party is already full.
function PartyModel:add(mon)
  if self:isFull() then
    return nil, "party is full"
  end
  local slot = self.count + 1
  self.slots[slot] = mon
  self.count = self.count + 1
  return slot
end

-- 1-indexed slot lookup. Returns nil for an empty/out-of-range slot.
function PartyModel:get(slot)
  return self.slots[slot]
end

function PartyModel:size()
  return self.count
end

-- Removes the mon at `slot` and shifts every later slot down by one, so
-- the party never has gaps between occupied slots (this project's own
-- policy, not a cited real function -- kept simple since this task's
-- scope is party structure/plumbing, not the exact real party-slot-
-- shifting call sites). Returns the removed mon, or nil if the slot was
-- empty/out of range.
function PartyModel:removeAt(slot)
  if slot < 1 or slot > self.count then
    return nil
  end
  local removed = self.slots[slot]
  for i = slot, self.count - 1 do
    self.slots[i] = self.slots[i + 1]
  end
  self.slots[self.count] = nil
  self.count = self.count - 1
  return removed
end

-- Iterates occupied slots in order: for i, mon in party:iterate() do ... end
function PartyModel:iterate()
  local i = 0
  return function()
    i = i + 1
    if i <= self.count then
      return i, self.slots[i]
    end
  end
end

return PartyModel
