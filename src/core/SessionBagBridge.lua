-- Pure bridge between the save-compatible SaveFileCodec bag pocket arrays
-- (SaveFileCodec.decodeSaveBlock1's `bagPocket_Items`/`bagPocket_KeyItems`/
-- `bagPocket_PokeBalls`/`bagPocket_TMHM`/`bagPocket_Berries` -- each a
-- fixed-length real `struct ItemSlot[capacity]` array, empty slots stored
-- as itemId=0/quantity=0) and Bag.lua's live in-memory container. Same
-- shape of bridge BattlePartyBridge.lua already is for party records --
-- this project's session state stores plain save-compatible arrays, not
-- object instances, so anything that wants to *use* the bag through
-- Bag.lua's real add/remove/capacity rules (BattleSceneController,
-- PokemonMart) needs this conversion at both ends.
--
-- Real item slot positions carry no gameplay meaning of their own (unlike
-- a party's ordered slots) -- Bag.lua's add-to-first-empty-slot policy
-- already matches the real AddBagItem behavior this project ports, so a
-- round trip through this bridge does not need to preserve exact physical
-- slot indices, only which items/quantities exist per pocket.

local Bag = require("src.core.Bag")

local SessionBagBridge = {}

SessionBagBridge.POCKET_FIELD = {
  [Bag.POCKET_ITEMS] = "bagPocket_Items",
  [Bag.POCKET_KEY_ITEMS] = "bagPocket_KeyItems",
  [Bag.POCKET_POKE_BALLS] = "bagPocket_PokeBalls",
  [Bag.POCKET_TM_CASE] = "bagPocket_TMHM",
  [Bag.POCKET_BERRY_POUCH] = "bagPocket_Berries",
}

-- Builds a fresh Bag.lua instance from a session's saveBlock1, populated
-- with every real nonzero item slot. `itemLookup` is import/Item.lua's
-- parseTable() output (indexed by itemId, each entry exposing `.pocket`),
-- the same shape Bag.new() already expects.
function SessionBagBridge.fromSaveBlock1(sb1, itemLookup)
  local bag = Bag.new(itemLookup)
  for pocketId, fieldName in pairs(SessionBagBridge.POCKET_FIELD) do
    local slots = (sb1 and sb1[fieldName]) or {}
    for i = 1, #slots do
      local slot = slots[i]
      if slot and slot.itemId and slot.itemId ~= 0 and (slot.quantity or 0) > 0 then
        assert(bag:addItem(slot.itemId, slot.quantity),
          ("session bag pocket %d slot %d could not be restored (itemId %d x%d)")
            :format(pocketId, i, slot.itemId, slot.quantity))
      end
    end
  end
  return bag
end

-- Writes a Bag.lua instance's contents back into sb1's five real fixed-
-- length pocket arrays, in the exact shape SaveFileCodec.encodeSaveBlock1
-- expects (occupied slots as {itemId=,quantity=}, everything past that
-- compacted to the real empty-slot sentinel {itemId=0,quantity=0}).
function SessionBagBridge.toSaveBlock1(bag, sb1)
  for pocketId, fieldName in pairs(SessionBagBridge.POCKET_FIELD) do
    local capacity = Bag.POCKET_CAPACITY[pocketId]
    local out = {}
    local nextSlot = 1
    for _, itemId, quantity in bag:iteratePocket(pocketId) do
      out[nextSlot] = { itemId = itemId, quantity = quantity }
      nextSlot = nextSlot + 1
    end
    for i = nextSlot, capacity do
      out[i] = { itemId = 0, quantity = 0 }
    end
    sb1[fieldName] = out
  end
end

return SessionBagBridge
