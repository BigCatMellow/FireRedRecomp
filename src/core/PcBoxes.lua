-- In-memory PC box stub: TOTAL_BOXES_COUNT boxes x IN_BOX_COUNT slots
-- each, storing BoxPokemonCodec-shaped entries. Real constants,
-- pokefirered include/pokemon_storage_system.h:
--   #define TOTAL_BOXES_COUNT 14
--   #define IN_BOX_ROWS       5   -- "5 rows"
--   #define IN_BOX_COLUMNS    6   -- "6 Pokémon per row"
--   #define IN_BOX_COUNT      (IN_BOX_ROWS * IN_BOX_COLUMNS)  -- 30
-- (the header's own row/column comments read a little confusingly --
-- "Number of rows, 6 Pokémon per row" on the ROWS=5 line -- but the
-- IN_BOX_COUNT product is unambiguous: 5*6 = 30 slots per box either
-- way, confirmed against the real struct's declared array size below).
--
-- Real backing struct (struct PokemonStorage,
-- include/pokemon_storage_system.h):
--   /*0x0001*/ struct BoxPokemon boxes[TOTAL_BOXES_COUNT][IN_BOX_COUNT];
-- i.e. each slot holds exactly one real 80-byte BoxPokemon (same shape
-- BoxPokemonCodec.lua decodes/encodes) -- a boxed Pokémon has no
-- battle-stat cache the way a party member (struct Pokemon) does, so
-- this module makes no assumption about extra fields; it stores
-- whatever table the caller gives it (same duck-typed policy as
-- PartyModel.lua -- this module doesn't dictate the mon's shape, only
-- manages the 14x30 slot container), following PartyModel's pattern:
-- add-to-first-empty-slot, get/removeAt by index, no gap-compaction
-- forced on removeAt (PC boxes are a sparse 2D grid in the real game --
-- unlike the flat party array, real box slots do NOT shift on removal,
-- so removeAt here leaves a hole, matching real PC-box behavior more
-- closely than PartyModel's shifting policy would).
--
-- This is a lightweight in-memory container only, no save-file I/O
-- (that's the save-block handoff's territory) and no UI/scrolling.

local PcBoxes = {}
PcBoxes.__index = PcBoxes

PcBoxes.TOTAL_BOXES_COUNT = 14 -- TOTAL_BOXES_COUNT, include/pokemon_storage_system.h
PcBoxes.IN_BOX_COUNT = 30      -- IN_BOX_COUNT (IN_BOX_ROWS(5) * IN_BOX_COLUMNS(6))

function PcBoxes.new()
  local self = setmetatable({ boxes = {} }, PcBoxes)
  for b = 1, PcBoxes.TOTAL_BOXES_COUNT do
    self.boxes[b] = {}
  end
  return self
end

local function checkBox(box)
  assert(box >= 1 and box <= PcBoxes.TOTAL_BOXES_COUNT, "box out of range: " .. tostring(box))
end

-- Adds `mon` to the first empty slot in `box` (1-indexed). Returns the
-- slot index, or nil + an error message if the box is full.
function PcBoxes:add(box, mon)
  checkBox(box)
  local slots = self.boxes[box]
  for i = 1, PcBoxes.IN_BOX_COUNT do
    if slots[i] == nil then
      slots[i] = mon
      return i
    end
  end
  return nil, "box is full"
end

function PcBoxes:get(box, slot)
  checkBox(box)
  if slot < 1 or slot > PcBoxes.IN_BOX_COUNT then
    return nil
  end
  return self.boxes[box][slot]
end

-- Removes and returns the mon at (box, slot), leaving a hole (real PC
-- boxes don't compact on removal -- see header). Returns nil if the
-- slot was already empty/out of range.
function PcBoxes:removeAt(box, slot)
  checkBox(box)
  if slot < 1 or slot > PcBoxes.IN_BOX_COUNT then
    return nil
  end
  local removed = self.boxes[box][slot]
  self.boxes[box][slot] = nil
  return removed
end

function PcBoxes:isFull(box)
  checkBox(box)
  local slots = self.boxes[box]
  for i = 1, PcBoxes.IN_BOX_COUNT do
    if slots[i] == nil then
      return false
    end
  end
  return true
end

-- Iterates occupied slots of `box` in slot order (skipping holes):
-- for i, mon in pc:iterate(box) do ... end
function PcBoxes:iterate(box)
  checkBox(box)
  local slots = self.boxes[box]
  local i = 0
  return function()
    repeat
      i = i + 1
      if i > PcBoxes.IN_BOX_COUNT then return nil end
    until slots[i] ~= nil
    return i, slots[i]
  end
end

return PcBoxes
