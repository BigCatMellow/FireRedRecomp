-- Real player money wrapper, pokefirered src/money.c.
--
-- Real storage: struct SaveBlock1 (include/global.h) has
--   /*0x0290*/ u32 money;
-- Real cap: `#define MAX_MONEY 999999` (src/money.c) -- confirmed
-- directly in source (not assumed); also cross-checked against
-- src/shop.c's shop-history clamp and src/trainer_card.c's max-money
-- trainer card entries, which both independently hard-code 999999.
--
-- Real AddMoney/RemoveMoney (src/money.c), transcribed directly:
--   AddMoney: if (toSet + toAdd > MAX_MONEY) toSet = MAX_MONEY
--             else { toSet += toAdd; if toSet < old toSet, overflow -> MAX_MONEY }
--   RemoveMoney: if (toSet < toSub) toSet = 0 else toSet -= toSub
-- i.e. add clamps at the cap (including on any wraparound), subtract
-- floors at zero -- this module's add()/subtract() reproduce that
-- clamping exactly.
--
-- Real encryption: GetMoney/SetMoney XOR the raw stored u32 with
-- gSaveBlock2Ptr->encryptionKey on every read/write --
--   GetMoney: return *moneyPtr ^ gSaveBlock2Ptr->encryptionKey
--   SetMoney: *moneyPtr = gSaveBlock2Ptr->encryptionKey ^ newValue
-- (the same encryptionKey also XORs bag item quantities, see Bag.lua's
-- header). This module stores and returns the plain decrypted value --
-- the encryptionKey XOR is real save-block *representation* behavior,
-- not part of the money value/cap logic itself, and is explicitly left
-- for the save-block handoff to apply when it wires an in-memory Money
-- to actual save bytes. Stated per the task brief: XOR is documented
-- here, not implemented here.

local Money = {}
Money.__index = Money

Money.MAX_MONEY = 999999 -- MAX_MONEY, src/money.c

function Money.new(initial)
  local self = setmetatable({ amount = 0 }, Money)
  if initial ~= nil then
    self.amount = initial
  end
  return self
end

function Money:get()
  return self.amount
end

function Money:isEnough(cost)
  return self.amount >= cost -- real IsEnoughMoney
end

-- Real AddMoney: clamps to MAX_MONEY on cap-exceeding or overflow.
function Money:add(toAdd)
  local toSet = self.amount + toAdd
  if toSet > Money.MAX_MONEY or toSet < self.amount then
    toSet = Money.MAX_MONEY
  end
  self.amount = toSet
end

-- Real RemoveMoney: floors at 0, never goes negative.
function Money:subtract(toSub)
  if self.amount < toSub then
    self.amount = 0
  else
    self.amount = self.amount - toSub
  end
end

return Money
