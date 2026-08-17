-- Save-compatible bag-pocket-array <-> live Bag.lua round-trip coverage.
-- Pure Lua, no ROM needed.
-- Run: lua5.1 tests/session_bag_bridge_test.lua
package.path = package.path .. ";./?.lua"

local Bag = require("src.core.Bag")
local SessionBagBridge = require("src.core.SessionBagBridge")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local itemLookup = {
  [4] = { pocket = Bag.POCKET_POKE_BALLS, price = 200 },  -- ITEM_POKE_BALL
  [13] = { pocket = Bag.POCKET_ITEMS, price = 300 },      -- ITEM_POTION
}

-- A session save-block1 with a real, save-compatible empty bag (every
-- pocket present as its real fixed-length all-zero array, matching
-- SaveFileCodec.decodeSaveBlock1's output for a fresh save).
local function emptySb1()
  local sb1 = {}
  for pocketId, fieldName in pairs(SessionBagBridge.POCKET_FIELD) do
    local slots = {}
    for i = 1, Bag.POCKET_CAPACITY[pocketId] do slots[i] = { itemId = 0, quantity = 0 } end
    sb1[fieldName] = slots
  end
  return sb1
end

do
  local bag = SessionBagBridge.fromSaveBlock1(emptySb1(), itemLookup)
  check("a fresh all-zero session bag decodes to a real empty Bag", bag:quantityOf(4) == 0)
end

do
  local sb1 = emptySb1()
  sb1.bagPocket_PokeBalls[1] = { itemId = 4, quantity = 5 }
  sb1.bagPocket_Items[3] = { itemId = 13, quantity = 2 }
  local bag = SessionBagBridge.fromSaveBlock1(sb1, itemLookup)
  check("real nonzero slots restore into the live bag", bag:quantityOf(4) == 5 and bag:quantityOf(13) == 2)
end

do
  -- Full round trip: decode, mutate through Bag.lua's real API (as
  -- BattleSceneController/PokemonMart would), re-encode, and confirm the
  -- change is reflected in the save-compatible arrays.
  local sb1 = emptySb1()
  local bag = SessionBagBridge.fromSaveBlock1(sb1, itemLookup)
  bag:addItem(4, 3)
  SessionBagBridge.toSaveBlock1(bag, sb1)
  check("a purchase made through Bag.lua persists back into saveBlock1",
    sb1.bagPocket_PokeBalls[1].itemId == 4 and sb1.bagPocket_PokeBalls[1].quantity == 3)

  bag:removeItem(4, 1)
  SessionBagBridge.toSaveBlock1(bag, sb1)
  check("a consumed ball (battle throw) persists back too",
    sb1.bagPocket_PokeBalls[1].itemId == 4 and sb1.bagPocket_PokeBalls[1].quantity == 2)

  bag:removeItem(4, 2)
  SessionBagBridge.toSaveBlock1(bag, sb1)
  check("an emptied slot re-encodes to the real itemId=0/quantity=0 sentinel",
    sb1.bagPocket_PokeBalls[1].itemId == 0 and sb1.bagPocket_PokeBalls[1].quantity == 0)
end

do
  -- Every real pocket array keeps its full fixed length after a round
  -- trip, not just the occupied prefix -- SaveFileCodec.encodeSaveBlock1
  -- iterates a fixed real slot count per pocket.
  local sb1 = emptySb1()
  local bag = SessionBagBridge.fromSaveBlock1(sb1, itemLookup)
  SessionBagBridge.toSaveBlock1(bag, sb1)
  check("re-encoded pocket arrays keep the real fixed POCKET_POKE_BALLS(13) length",
    #sb1.bagPocket_PokeBalls == Bag.POCKET_CAPACITY[Bag.POCKET_POKE_BALLS])
end

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
