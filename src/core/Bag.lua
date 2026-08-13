-- Real Bag pocket model, pokefirered include/constants/global.h (pocket
-- IDs + per-pocket capacities) and src/item.c (AddBagItem/RemoveBagItem/
-- CheckBagHasItem, GetBagItemQuantity/SetBagItemQuantity, struct ItemSlot
-- in include/global.h).
--
-- Real pocket IDs (include/constants/global.h):
--   POCKET_ITEMS       = 1   BAG_ITEMS_COUNT     = 42
--   POCKET_KEY_ITEMS   = 2   BAG_KEYITEMS_COUNT  = 30
--   POCKET_POKE_BALLS  = 3   BAG_POKEBALLS_COUNT = 13
--   POCKET_TM_CASE     = 4   BAG_TMHM_COUNT      = 58
--   POCKET_BERRY_POUCH = 5   BAG_BERRIES_COUNT   = 43
-- (NUM_BAG_POCKETS = 5). Each real pocket is a fixed-size
-- struct ItemSlot[capacity] array inside struct SaveBlock1
-- (bagPocket_Items/_KeyItems/_PokeBalls/_TMHM/_Berries) -- confirmed by
-- reading their declared array sizes directly in include/global.h, which
-- match the BAG_*_COUNT constants above exactly.
--
-- struct ItemSlot (include/global.h): { u16 itemId; u16 quantity; } --
-- this module's slot shape mirrors that directly.
--
-- Per-item pocket assignment comes from `gItems[itemId].pocket`
-- (struct Item, include/item.h), already decoded by Phase 1's
-- import/Item.lua (`Item.parseRecord` exposes `.pocket` per item record,
-- see its 0x1A offset comment) -- this module takes an item-lookup table
-- shaped like Item.parseTable()'s output (indexed by itemId, each entry
-- having a `.pocket` field) rather than re-deriving pocket assignment.
--
-- Real per-slot stack cap: AddBagItem (src/item.c) hard-codes
-- `if (quantity + count <= 999)` -- transcribed directly, not guessed.
--
-- Real quantity encryption: GetBagItemQuantity/SetBagItemQuantity XOR
-- the raw stored quantity with gSaveBlock2Ptr->encryptionKey (same
-- encryptionKey used by money.c's GetMoney/SetMoney -- see Money.lua).
-- This module stores quantities as plain in-memory integers (same
-- policy as PartyModel/BoxPokemonCodec's callers -- no ROM/save-block
-- wiring yet); the XOR is real save-block-representation behavior and
-- is documented here as the save-block handoff's job, not implemented
-- in this in-memory model.
--
-- Real FireRed also auto-adds an ITEM_TM_CASE / ITEM_BERRY_POUCH key
-- item the first time you receive a TM/berry (see AddBagItem's
-- POCKET_TM_CASE/POCKET_BERRY_POUCH special-casing) -- that's a gameplay
-- event-flag interaction, out of scope for this pure container model.

local Bag = {}
Bag.__index = Bag

Bag.MAX_STACK = 999 -- real hard-coded cap in AddBagItem, src/item.c

Bag.POCKET_ITEMS = 1
Bag.POCKET_KEY_ITEMS = 2
Bag.POCKET_POKE_BALLS = 3
Bag.POCKET_TM_CASE = 4
Bag.POCKET_BERRY_POUCH = 5

-- Real per-pocket capacities, include/constants/global.h.
Bag.POCKET_CAPACITY = {
  [Bag.POCKET_ITEMS] = 42,      -- BAG_ITEMS_COUNT
  [Bag.POCKET_KEY_ITEMS] = 30,  -- BAG_KEYITEMS_COUNT
  [Bag.POCKET_POKE_BALLS] = 13, -- BAG_POKEBALLS_COUNT
  [Bag.POCKET_TM_CASE] = 58,    -- BAG_TMHM_COUNT
  [Bag.POCKET_BERRY_POUCH] = 43,-- BAG_BERRIES_COUNT
}

-- itemLookup: table indexed by itemId, each entry having a `.pocket`
-- field (e.g. import/Item.lua's Item.parseTable() output). Required so
-- the bag knows which pocket an itemId belongs in, same as the real
-- `ItemId_GetPocket(itemId)` -> `gItems[itemId].pocket` lookup.
function Bag.new(itemLookup)
  assert(itemLookup ~= nil, "Bag.new requires an itemId -> {pocket=...} lookup table")
  local self = setmetatable({ itemLookup = itemLookup, pockets = {} }, Bag)
  for pocket, capacity in pairs(Bag.POCKET_CAPACITY) do
    local slots = {}
    for i = 1, capacity do
      slots[i] = false -- empty slot; real ItemSlot itemId==0 means empty, this model uses false
    end
    self.pockets[pocket] = slots
  end
  return self
end

function Bag:pocketFor(itemId)
  local item = self.itemLookup[itemId]
  assert(item ~= nil, "unknown itemId: " .. tostring(itemId))
  return item.pocket
end

function Bag:capacityOf(pocket)
  return Bag.POCKET_CAPACITY[pocket]
end

-- Adds `count` of `itemId`, stacking into an existing slot for that item
-- if present (matching real AddBagItem's stack-first scan), else the
-- first empty slot in its pocket. Returns true on success, or false plus
-- an error message if the pocket is full or the stack cap would be
-- exceeded (real AddBagItem also just returns FALSE in both cases --
-- "RS and Emerald check whether there is enough of the item across all
-- stacks. For whatever reason, FR/LG assume there's only one stack of
-- the item," per the real source comment, transcribed here since it's
-- FireRed-specific behavior this module intentionally matches).
function Bag:addItem(itemId, count)
  assert(count ~= nil and count > 0, "count must be positive")
  local pocket = self:pocketFor(itemId)
  local slots = self.pockets[pocket]

  for i = 1, #slots do
    local slot = slots[i]
    if slot and slot.itemId == itemId then
      if slot.quantity + count > Bag.MAX_STACK then
        return false, "stack would exceed max quantity"
      end
      slot.quantity = slot.quantity + count
      return true
    end
  end

  for i = 1, #slots do
    if not slots[i] then
      slots[i] = { itemId = itemId, quantity = count }
      return true
    end
  end

  return false, "pocket is full"
end

-- Removes `count` of `itemId` from its pocket. Returns true on success,
-- or false plus an error message if there isn't enough (matching real
-- CheckBagHasItem's semantics: FR/LG only look at a single stack, not
-- the sum across stacks).
function Bag:removeItem(itemId, count)
  assert(count ~= nil and count > 0, "count must be positive")
  local pocket = self:pocketFor(itemId)
  local slots = self.pockets[pocket]

  for i = 1, #slots do
    local slot = slots[i]
    if slot and slot.itemId == itemId then
      if slot.quantity < count then
        return false, "not enough quantity"
      end
      slot.quantity = slot.quantity - count
      if slot.quantity == 0 then
        slots[i] = false
      end
      return true
    end
  end

  return false, "item not in bag"
end

function Bag:quantityOf(itemId)
  local pocket = self:pocketFor(itemId)
  local slots = self.pockets[pocket]
  for i = 1, #slots do
    local slot = slots[i]
    if slot and slot.itemId == itemId then
      return slot.quantity
    end
  end
  return 0
end

-- Iterates occupied slots of `pocket` in slot order:
-- for i, itemId, quantity in bag:iteratePocket(Bag.POCKET_ITEMS) do ... end
function Bag:iteratePocket(pocket)
  local slots = self.pockets[pocket]
  local i = 0
  return function()
    repeat
      i = i + 1
      if i > #slots then return nil end
    until slots[i]
    return i, slots[i].itemId, slots[i].quantity
  end
end

return Bag
