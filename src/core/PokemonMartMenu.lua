-- Real Poké Mart BUY flow state machine (src/shop.c: Task_BuyMenu ->
-- Task_BuyHowManyDialogueInit/HandleInput -> BuyMenuTryMakePurchase),
-- operating on the already-real PokemonMart.buy()/Bag.lua pair. Pure
-- Lua: no ROM/love2d/script dependency, same "pure state machine before
-- its ROM-backed presentation" pattern as NamingScreenState.lua (which
-- NamingScreenScene.lua later composited real ROM art on top of without
-- touching this module). SELL is deliberately not built yet -- BUY is
-- the only flow a fresh, money-only session actually needs to reach
-- live capture; PokemonMart.sell already exists for whenever it is.
--
-- Real quantity-adjustment stepping, transcribed from
-- AdjustQuantityAccordingToDPadInput (src/menu_helpers.c): Up +1
-- (wraps 1 at the top back to 1), Down -1 (wraps 0-or-below back to
-- max), Right +10 (clamped at max, no wrap), Left -10 (clamped at 1, no
-- wrap -- floors at 1, never 0). Real maxQuantity = min(99,
-- floor(money / unitPrice)) (Task_BuyHowManyDialogueInit).
--
-- Real state order: item list -> (money check) -> quantity dialog ->
-- confirm Yes/No -> AddBagItem (fails visibly with "no more room" if the
-- real per-stack/pocket capacity would be exceeded, matching Bag.lua's
-- own real MAX_STACK/pocket-full checks) -> money deducted only on
-- success -> back to the item list ("Will that be all?").

local PokemonMartMenu = {}
PokemonMartMenu.__index = PokemonMartMenu

PokemonMartMenu.LIST = "list"
PokemonMartMenu.QUANTITY = "quantity"
PokemonMartMenu.CONFIRM = "confirm"
PokemonMartMenu.MESSAGE = "message"
PokemonMartMenu.DONE = "done"

local InputState = require("src.core.InputState")
local PokemonMart = require("src.core.PokemonMart")

-- opts.itemIds: ordered real item ids this mart sells (the real
-- `pokemart` script command's own data table, e.g. ViridianCity_Mart_
-- Items -- this module doesn't hardcode any specific mart's stock).
-- opts.itemLookup: import/Item.lua's parseTable() output.
-- opts.bag: a real Bag.lua instance (mutated in place on purchase).
-- opts.money: the session's current money (plain integer).
function PokemonMartMenu.new(opts)
  assert(opts and opts.itemIds and #opts.itemIds > 0, "PokemonMartMenu needs a nonempty item list")
  assert(opts.itemLookup, "PokemonMartMenu needs the real item table")
  assert(opts.bag, "PokemonMartMenu needs a real Bag instance")
  return setmetatable({
    itemIds = opts.itemIds,
    itemLookup = opts.itemLookup,
    bag = opts.bag,
    money = opts.money or 0,
    state = PokemonMartMenu.LIST,
    listCursor = 0,
    quantity = 1,
    maxQuantity = 1,
    selectedItemId = nil,
    message = nil,
    afterMessage = PokemonMartMenu.LIST,
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
      self.state = PokemonMartMenu.DONE
    elseif input:isNewlyPressed(InputState.A_BUTTON) then
      local itemId = self:currentItemId()
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
    end
    return
  end
end

return PokemonMartMenu
