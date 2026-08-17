-- Real Poké Mart buy/sell transactions (src/shop.c, src/item_menu.c).
-- This is the pure data-layer piece a future shop UI (the real `pokemart`
-- script command's presentation) will call into -- no map/script/UI
-- wiring here, matching this project's established pattern of building
-- the tested rules layer before its live-scene trigger exists (see
-- CaptureRewards.lua/WhiteoutRules.lua for the same shape).
--
-- Real buy price (Cmd_BuyMenuBuyItem's confirm handler, src/shop.c):
--   sShopData.itemPrice = ItemId_GetPrice(itemId) * quantity
-- ItemId_GetPrice returns the item's real, unmarked-up `gItems[id].price`
-- field directly (import/Item.lua's already-decoded `.price`) -- there is
-- no buy-side markup in FireRed.
--
-- Real sell price (src/berry_pouch.c's SellMultiple_UpdateSellPriceDisplay,
-- the same real halving item_menu.c's ordinary bag-item sell flow also
-- uses): `ItemId_GetPrice(itemId) / 2 * quantity` (integer division,
-- floored once on the unit price, not on the total). A price of exactly 0
-- (key items, and any item the real data marks unsellable) can never be
-- sold -- real item_menu.c explicitly checks `ItemId_GetPrice(id) == 0`
-- before allowing a sell attempt at all.
--
-- Money is a plain integer field on GameSession's save-compatible state
-- (see main.lua's GameSession/EarlyRivalRewards/WhiteoutRules -- none of
-- them wrap it in Money.lua's object either), clamped at the real
-- MAX_MONEY (999999, src/money.c) on the sell path since a sale could
-- otherwise push it over the cap; RemoveMoney's buy-side floor at 0 is
-- enforced here by refusing a purchase the player can't afford outright
-- rather than clamping a negative result.

local PokemonMart = {}

PokemonMart.MAX_MONEY = 999999 -- MAX_MONEY, src/money.c

local function priceOf(itemLookup, itemId)
  local entry = itemLookup[itemId]
  assert(entry and entry.price ~= nil, ("unknown item or missing price for item %d"):format(itemId))
  return entry.price
end

-- Returns the new money total on success, or nil + an error message.
-- `bag` is a Bag.lua instance; `itemLookup` is the same import/Item.lua-
-- shaped {[itemId]={pocket=,price=,...}} table Bag.new() already expects,
-- just also carrying the real `.price` field this module needs.
function PokemonMart.buy(bag, money, itemId, quantity, itemLookup)
  assert(quantity ~= nil and quantity > 0, "quantity must be positive")
  local cost = priceOf(itemLookup, itemId) * quantity
  if cost > (money or 0) then
    return nil, "not enough money"
  end
  local ok, reason = bag:addItem(itemId, quantity)
  if not ok then
    return nil, reason
  end
  return money - cost
end

-- Returns the new money total on success, or nil + an error message.
function PokemonMart.sell(bag, money, itemId, quantity, itemLookup)
  assert(quantity ~= nil and quantity > 0, "quantity must be positive")
  local price = priceOf(itemLookup, itemId)
  if price == 0 then
    return nil, "item cannot be sold"
  end
  if bag:quantityOf(itemId) < quantity then
    return nil, "not enough of that item to sell"
  end
  local ok, reason = bag:removeItem(itemId, quantity)
  if not ok then
    return nil, reason
  end
  local proceeds = math.floor(price / 2) * quantity
  return math.min(PokemonMart.MAX_MONEY, (money or 0) + proceeds)
end

return PokemonMart
