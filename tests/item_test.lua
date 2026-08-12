-- Run: lua5.1 tests/item_test.lua
package.path = package.path .. ";./?.lua"
local Item = require("import.Item")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

check("record size is 44", Item.RECORD_SIZE == 44)

-- Master Ball, exactly as it appears in the real ROM (verified byte-for-byte
-- against pokefirered.gba built locally): itemId=1, price=0, pocket=3,
-- fieldUseFunc=NULL, battleUseFunc=0x080a1e1d (Thumb function pointer).
local masterBall = string.char(
  0xc7, 0xbb, 0xcd, 0xce, 0xbf, 0xcc, 0x00, 0xbc, 0xbb, 0xc6, 0xc6, 0xff, 0x00, 0x00, -- name[14]
  0x01, 0x00, -- itemId = 1
  0x00, 0x00, -- price = 0
  0x00,       -- holdEffect
  0x00,       -- holdEffectParam
  0xcc, 0x4e, 0x3d, 0x08, -- description ptr
  0x00, -- importance
  0x00, -- registrability
  0x03, -- pocket
  0x00, -- type
  0x00, 0x00, 0x00, 0x00, -- fieldUseFunc = NULL
  0x02, -- battleUsage
  0x00, 0x00, 0x00, -- padding
  0x1d, 0x1e, 0x0a, 0x08, -- battleUseFunc ptr
  0x00, -- secondaryId
  0x00, 0x00, 0x00 -- trailing padding
)

check("record is 44 bytes", #masterBall == 44)

local parsed = Item.parseRecord(masterBall)
check("itemId", parsed.itemId == 1, parsed.itemId)
check("price", parsed.price == 0, parsed.price)
check("pocket", parsed.pocket == 3, parsed.pocket)
check("fieldUseFuncPtr is null", parsed.fieldUseFuncPtr == 0, parsed.fieldUseFuncPtr)
check("battleUseFuncPtr", parsed.battleUseFuncPtr == 0x080a1e1d, parsed.battleUseFuncPtr)
check("battleUsage", parsed.battleUsage == 2, parsed.battleUsage)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
