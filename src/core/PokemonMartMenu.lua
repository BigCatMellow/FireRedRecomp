-- Real Poké Mart BUY/SELL flow state machine. Top-level choice mirrors
-- real `Task_ShopMenu` (src/shop.c: `sShopMenuActions_BuySellQuit` --
-- Buy/Sell/Quit); BUY is `Task_BuyMenu -> Task_BuyHowManyDialogueInit/
-- HandleInput -> BuyMenuTryMakePurchase`, operating on the already-real
-- PokemonMart.buy()/Bag.lua pair. Pure Lua: no ROM/love2d/script
-- dependency, same "pure state machine before its ROM-backed
-- presentation" pattern as NamingScreenState.lua (which
-- NamingScreenScene.lua later composited real ROM art on top of without
-- touching this module).
--
-- SELL is a deliberate simplification of the real flow, not a full port:
-- real `CB2_GoToSellMenu` (src/shop.c) doesn't have its own sell UI at
-- all -- it opens the entire general Bag menu in a special
-- `ITEMMENULOCATION_SHOP` mode (`src/item_menu.c`'s `Task_ItemContext_
-- Sell`/`Task_SelectQuantityToSell`/`Task_SellItem_Yes`), a whole
-- separate system (list scrolling across every bag pocket, TM
-- Case/Berry Pouch as their own real sub-screens) this project doesn't
-- have. This module instead reuses its own existing LIST/QUANTITY/
-- CONFIRM/MESSAGE machinery for SELL too, sourced from the bag's own
-- POCKET_ITEMS/POCKET_POKE_BALLS contents (TM Case/Berry Pouch excluded
-- to match real source's own special-casing of those two pockets into
-- separate screens, `GoToTMCase_Sell`/`GoToBerryPouch_Sell`). The real
-- per-item mechanics ARE ported exactly: max sell quantity = min(99,
-- quantity owned) (`Task_ItemContext_Sell`'s `data[2] > 99` clamp over
-- the real owned count, not a money-based cap like buying), a real
-- single-copy item skips the quantity dialog entirely and goes straight
-- to the sale confirmation (`data[2] == 1` branch), sell price is
-- `floor(price/2) * quantity` (already `PokemonMart.sell`), and a
-- price-0 item is real-unsellable (already filtered out of the sell
-- list here, mirroring `ItemId_GetPrice(id) == 0`'s real block).
--
-- Real quantity-adjustment stepping, transcribed from
-- AdjustQuantityAccordingToDPadInput (src/menu_helpers.c): Up +1
-- (wraps 1 at the top back to 1), Down -1 (wraps 0-or-below back to
-- max), Right +10 (clamped at max, no wrap), Left -10 (clamped at 1, no
-- wrap -- floors at 1, never 0). Real BUY maxQuantity = min(99,
-- floor(money / unitPrice)) (Task_BuyHowManyDialogueInit); real SELL
-- maxQuantity = min(99, quantityOwned) (Task_ItemContext_Sell), as above.
--
-- Real BUY state order: item list -> (money check) -> quantity dialog ->
-- confirm Yes/No -> AddBagItem (fails visibly with "no more room" if the
-- real per-stack/pocket capacity would be exceeded, matching Bag.lua's
-- own real MAX_STACK/pocket-full checks) -> money deducted only on
-- success -> back to the item list ("Will that be all?"). B at either
-- item list returns to the real top BUY/SELL/QUIT menu (not straight out
-- of the mart) -- B at that top menu is this module's own bounded
-- "Quit" equivalent.

local PokemonMartMenu = {}
PokemonMartMenu.__index = PokemonMartMenu

PokemonMartMenu.TOPMENU = "topmenu"
PokemonMartMenu.LIST = "list"
PokemonMartMenu.QUANTITY = "quantity"
PokemonMartMenu.CONFIRM = "confirm"
PokemonMartMenu.MESSAGE = "message"
PokemonMartMenu.DONE = "done"

local InputState = require("src.core.InputState")
local PokemonMart = require("src.core.PokemonMart")
local Bag = require("src.core.Bag")

-- opts.itemIds: ordered real item ids this mart sells (the real
-- `pokemart` script command's own data table, e.g. ViridianCity_Mart_
-- Items -- this module doesn't hardcode any specific mart's stock).
-- opts.itemLookup: import/Item.lua's parseTable() output.
-- opts.bag: a real Bag.lua instance (mutated in place on purchase/sale).
-- opts.money: the session's current money (plain integer).
function PokemonMartMenu.new(opts)
  assert(opts and opts.itemIds and #opts.itemIds > 0, "PokemonMartMenu needs a nonempty item list")
  assert(opts.itemLookup, "PokemonMartMenu needs the real item table")
  assert(opts.bag, "PokemonMartMenu needs a real Bag instance")
  return setmetatable({
    martItemIds = opts.itemIds,
    itemIds = opts.itemIds,
    itemLookup = opts.itemLookup,
    bag = opts.bag,
    money = opts.money or 0,
    state = PokemonMartMenu.TOPMENU,
    topCursor = 0,
    transactionType = nil, -- "buy" | "sell", set on entering LIST
    listCursor = 0,
    quantity = 1,
    maxQuantity = 1,
    selectedItemId = nil,
    message = nil,
    afterMessage = PokemonMartMenu.TOPMENU,
  }, PokemonMartMenu)
end

function PokemonMartMenu:currentItemId()
  return self.itemIds[self.listCursor + 1]
end

function PokemonMartMenu:isDone()
  return self.state == PokemonMartMenu.DONE
end

local function unitPrice(self, itemId)
  return assert(self.itemLookup[itemId], "unknown mart item").price
end

-- Real sell price is floor(unitPrice/2) per unit (PokemonMart.sell
-- applies the same floor to the total, not per-unit, but floor(p/2)*n ==
-- floor(p/2*n) is only true because both use the same floor-once-on-
-- unit-price shape -- this mirrors it for display).
local function sellUnitPrice(self, itemId)
  return math.floor(unitPrice(self, itemId) / 2)
end

-- Builds the real sell list: every POCKET_ITEMS/POCKET_POKE_BALLS item
-- actually owned (quantity > 0) with a nonzero real price (unsellable
-- key items/price-0 items never appear, matching real `ItemId_GetPrice
-- (id) == 0` filtering). TM Case/Berry Pouch pockets are real separate
-- screens (see header) and are not included.
function PokemonMartMenu:_buildSellList()
  local ids = {}
  for _, pocket in ipairs({ Bag.POCKET_ITEMS, Bag.POCKET_POKE_BALLS }) do
    for _, itemId, quantity in self.bag:iteratePocket(pocket) do
      if quantity > 0 then
        local entry = self.itemLookup[itemId]
        if entry and entry.price and entry.price > 0 then
          ids[#ids + 1] = itemId
        end
      end
    end
  end
  return ids
end

function PokemonMartMenu:_setMessage(text, afterState)
  self.message = text
  self.afterMessage = afterState
  self.state = PokemonMartMenu.MESSAGE
end

-- input: an InputState instance already ticked this frame (same
-- isNewlyPressed/isPressedOrRepeated interface every other menu in this
-- project already consumes).
function PokemonMartMenu:processInput(input)
  if self.state == PokemonMartMenu.MESSAGE then
    if input:isNewlyPressed(InputState.A_BUTTON) or input:isNewlyPressed(InputState.B_BUTTON) then
      self.state = self.afterMessage
      self.message = nil
    end
    return
  end

  if self.state == PokemonMartMenu.TOPMENU then
    -- Real sShopMenuActions_BuySellQuit: Buy/Sell/Quit, a plain 3-item
    -- vertical menu (src/shop.c's Task_ShopMenu).
    if input:isPressedOrRepeated(InputState.DPAD_UP) and self.topCursor > 0 then
      self.topCursor = self.topCursor - 1
    elseif input:isPressedOrRepeated(InputState.DPAD_DOWN) and self.topCursor < 2 then
      self.topCursor = self.topCursor + 1
    elseif input:isNewlyPressed(InputState.B_BUTTON) then
      self.state = PokemonMartMenu.DONE
    elseif input:isNewlyPressed(InputState.A_BUTTON) then
      if self.topCursor == 0 then
        self.transactionType = "buy"
        self.itemIds = self.martItemIds
        self.listCursor = 0
        self.state = PokemonMartMenu.LIST
      elseif self.topCursor == 1 then
        self.transactionType = "sell"
        self.itemIds = self:_buildSellList()
        self.listCursor = 0
        self.state = PokemonMartMenu.LIST
      else
        self.state = PokemonMartMenu.DONE
      end
    end
    return
  end

  if self.state == PokemonMartMenu.LIST then
    -- Real ListMenu Up/Down navigation. This project's own clamp policy
    -- (not verified against the real ListMenu template's exact
    -- scroll/wrap behavior at the list ends) -- functionally correct
    -- item selection either way, just not asserted as a verified-real
    -- wraparound choice.
    if input:isPressedOrRepeated(InputState.DPAD_UP) and self.listCursor > 0 then
      self.listCursor = self.listCursor - 1
    elseif input:isPressedOrRepeated(InputState.DPAD_DOWN) and self.listCursor < #self.itemIds - 1 then
      self.listCursor = self.listCursor + 1
    elseif input:isNewlyPressed(InputState.B_BUTTON) then
      -- Real B at either the buy or sell item list returns to the top
      -- BUY/SELL/QUIT shop menu, not straight out of the mart.
      self.state = PokemonMartMenu.TOPMENU
    elseif input:isNewlyPressed(InputState.A_BUTTON) and #self.itemIds > 0 then
      local itemId = self:currentItemId()
      if self.transactionType == "buy" then
        local price = unitPrice(self, itemId)
        if price > self.money then
          self:_setMessage("You don't have enough money.", PokemonMartMenu.LIST)
        else
          self.selectedItemId = itemId
          self.quantity = 1
          -- Real Task_BuyHowManyDialogueInit: maxQuantity = min(99, money/price).
          self.maxQuantity = math.min(99, math.floor(self.money / price))
          self.state = PokemonMartMenu.QUANTITY
        end
      else
        self.selectedItemId = itemId
        -- Real Task_ItemContext_Sell: maxQuantity = min(99, quantityOwned).
        self.maxQuantity = math.min(99, self.bag:quantityOf(itemId))
        if self.maxQuantity == 1 then
          -- Real data[2] == 1 branch: a single-copy item skips the
          -- quantity dialog entirely and goes straight to confirmation.
          self.quantity = 1
          self.state = PokemonMartMenu.CONFIRM
        else
          self.quantity = 1
          self.state = PokemonMartMenu.QUANTITY
        end
      end
    end
    return
  end

  if self.state == PokemonMartMenu.QUANTITY then
    -- Real AdjustQuantityAccordingToDPadInput, src/menu_helpers.c.
    if input:isPressedOrRepeated(InputState.DPAD_UP) then
      self.quantity = self.quantity + 1
      if self.quantity > self.maxQuantity then self.quantity = 1 end
    elseif input:isPressedOrRepeated(InputState.DPAD_DOWN) then
      self.quantity = self.quantity - 1
      if self.quantity <= 0 then self.quantity = self.maxQuantity end
    elseif input:isPressedOrRepeated(InputState.DPAD_RIGHT) then
      self.quantity = math.min(self.maxQuantity, self.quantity + 10)
    elseif input:isPressedOrRepeated(InputState.DPAD_LEFT) then
      self.quantity = math.max(1, self.quantity - 10)
    elseif input:isNewlyPressed(InputState.B_BUTTON) then
      self.state = PokemonMartMenu.LIST
    elseif input:isNewlyPressed(InputState.A_BUTTON) then
      self.state = PokemonMartMenu.CONFIRM
    end
    return
  end

  if self.state == PokemonMartMenu.CONFIRM then
    if input:isNewlyPressed(InputState.B_BUTTON) then
      self.state = PokemonMartMenu.LIST
      return
    end
    if input:isNewlyPressed(InputState.A_BUTTON) then
      if self.transactionType == "buy" then
        local newMoney, reason = PokemonMart.buy(
          self.bag, self.money, self.selectedItemId, self.quantity, self.itemLookup)
        if newMoney then
          self.money = newMoney
          self:_setMessage("Here you go! Thank you!", PokemonMartMenu.LIST)
        else
          -- Real BuyMenuTryMakePurchase: AddBagItem failing (no room) is
          -- the one real post-confirm failure path; money is untouched.
          self:_setMessage("There's no more room for this.", PokemonMartMenu.LIST)
          -- Not persisted per real source's own wording -- flag anything
          -- else PokemonMart.buy might refuse for completeness/debugging.
          self.lastError = reason
        end
      else
        local newMoney, reason = PokemonMart.sell(
          self.bag, self.money, self.selectedItemId, self.quantity, self.itemLookup)
        if newMoney then
          self.money = newMoney
          -- Real gText_TurnedOverItemsWorthYen: "Turned over the
          -- <ITEM> and got $<price>!"
          self:_setMessage("Turned over the item and got some cash!", PokemonMartMenu.LIST)
          -- Real Task_FinalizeSaleToShop rebuilds the bag's ListMenu
          -- from its now-changed contents; this module's equivalent is
          -- rebuilding the sell list (a fully-sold stack disappears).
          self.itemIds = self:_buildSellList()
          if self.listCursor >= #self.itemIds then
            self.listCursor = math.max(0, #self.itemIds - 1)
          end
        else
          self:_setMessage("That item can't be sold.", PokemonMartMenu.LIST)
          self.lastError = reason
        end
      end
    end
    return
  end
end

return PokemonMartMenu
