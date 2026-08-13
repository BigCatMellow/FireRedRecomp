-- Run: lua5.1 tests/save_block_layout_test.lua
package.path = package.path .. ";./?.lua"
local SaveBlockLayout = require("src.core.SaveBlockLayout")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local function findField(fields, name)
  for _, f in ipairs(fields) do
    if f.name == name then return f end
  end
  return nil
end

-- SaveBlock1: spot-check real offsets against include/global.h's own
-- /*0xNNNN*/ comments (struct SaveBlock1, line 759).
local sb1 = SaveBlockLayout.SaveBlock1
check("SaveBlock1 size is 0x3D68", sb1.size == 0x3D68, sb1.size)
check("pos at 0x0000", findField(sb1.fields, "pos").offset == 0x0000)
check("playerParty at 0x0038", findField(sb1.fields, "playerParty").offset == 0x0038)
check("money at 0x0290", findField(sb1.fields, "money").offset == 0x0290)
check("pcItems at 0x0298", findField(sb1.fields, "pcItems").offset == 0x0298)
check("flags at 0x0EE0", findField(sb1.fields, "flags").offset == 0x0EE0)
check("vars at 0x1000", findField(sb1.fields, "vars").offset == 0x1000)
check("gameStats at 0x1200", findField(sb1.fields, "gameStats").offset == 0x1200)
check("rivalName at 0x3A4C", findField(sb1.fields, "rivalName").offset == 0x3A4C)

-- Struct-math cross-checks (not just copied numbers): the gap between
-- consecutive fields should equal the real declared array size.
local function gap(fields, a, b)
  return findField(fields, b).offset - findField(fields, a).offset
end
check("playerParty->money gap is 600 bytes (6 slots x 100-byte Pokemon)",
  gap(sb1.fields, "playerParty", "money") == 600)
check("pcItems->bagPocket_Items gap is 120 bytes (30 x 4-byte ItemSlot)",
  gap(sb1.fields, "pcItems", "bagPocket_Items") == 120)
check("flags->vars gap is 288 bytes (NUM_FLAG_BYTES)",
  gap(sb1.fields, "flags", "vars") == 288)
check("vars->gameStats gap is 512 bytes (256 u16 VARS_COUNT)",
  gap(sb1.fields, "vars", "gameStats") == 512)

-- SaveBlock2 (struct SaveBlock2, line 327).
local sb2 = SaveBlockLayout.SaveBlock2
check("SaveBlock2 size is 0xF24", sb2.size == 0xF24, sb2.size)
check("playerName at 0x000", findField(sb2.fields, "playerName").offset == 0x000)
check("playerGender at 0x008", findField(sb2.fields, "playerGender").offset == 0x008)
check("pokedex at 0x018", findField(sb2.fields, "pokedex").offset == 0x018)
check("encryptionKey at 0xF20", findField(sb2.fields, "encryptionKey").offset == 0xF20)

local pokedex = findField(sb2.fields, "pokedex").struct
check("Pokedex struct size is 0x78", pokedex.size == 0x78, pokedex.size)
check("Pokedex.owned at 0x10", findField(pokedex.fields, "owned").offset == 0x10)
check("Pokedex.seen at 0x44", findField(pokedex.fields, "seen").offset == 0x44)

print(string.format("save_block_layout_test: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
