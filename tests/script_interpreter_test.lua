-- Integration test: decodes and runs a real script from a real FireRed(US)
-- v1.0 ROM through import/ScriptBytecode.lua + src/core/ScriptInterpreter.lua.
-- Opt-in, skips cleanly with no ROM present (see tests/species_integration_test.lua
-- for the same pattern).
--
-- Run: POKEPORT_ROM=/path/to/pokefirered.gba lua5.1 tests/script_interpreter_test.lua
package.path = package.path .. ";./?.lua"

local romPath = os.getenv("POKEPORT_ROM")
if not romPath then
  print("SKIP: set POKEPORT_ROM=/path/to/verified/pokefirered.gba to run this test")
  os.exit(0)
end

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local MapHeader = require("import.MapHeader")
local MapEvents = require("import.MapEvents")
local Charmap = require("import.Charmap")
local ScriptBytecode = require("import.ScriptBytecode")
local ScriptInterpreter = require("src.core.ScriptInterpreter")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local ok, info = RomImporter.verify(romPath)
check("ROM verifies", ok == true, info)
if not ok then
  print(("%d passed, %d failed"):format(passed, failed))
  os.exit(1)
end

local f = assert(io.open(romPath, "rb"))
local data = f:read("*a")
f:close()

local sha1 = RomImporter._sha1HexOfFile(romPath)
local addrs = RomAddresses[sha1]
if not addrs then
  print("SKIP: ROM SHA-1 " .. tostring(sha1) .. " has no RomAddresses entry")
  os.exit(0)
end

local MAP_PALLET_TOWN = 3 * 256 + 0
local palletTown = MapHeader.resolve(data, addrs.gMapGroups, MAP_PALLET_TOWN)
local events = MapEvents.resolve(data, palletTown.eventsPtr)

-- bg_sign_event order in data/maps/PalletTown/events.inc: 0=OaksLabSign,
-- 1=PlayersHouseSign, 2=RivalsHouseSign, 3=TownSign, 4=TrainerTips.
-- PalletTown_EventScript_TownSign (data/maps/PalletTown/scripts.inc):
--   msgbox PalletTown_Text_TownSign, MSGBOX_SIGN
--   end
-- which the `msgbox` macro (asm/macros/event.inc) compiles to exactly
-- `loadword 0, PalletTown_Text_TownSign` + `callstd MSGBOX_SIGN(3)` + `end`
-- -- a real, short, branch-free script: perfect end-to-end coverage of
-- message decoding (via the loadword->data[0]->message(0) indirection)
-- and the transcribed Std_MsgboxSign std-script body, with no unimplemented
-- opcodes anywhere on its path.
check("Pallet Town has a bg sign event at index 3 (Town Sign)", events.bgEvents[3] ~= nil)
local townSignPtr = events.bgEvents[3].union
check("Town Sign bg event is at (9,11), kind 0 (script)", events.bgEvents[3].x == 9 and events.bgEvents[3].y == 11
  and events.bgEvents[3].kind == 0, ("x=%d y=%d kind=%d"):format(events.bgEvents[3].x, events.bgEvents[3].y, events.bgEvents[3].kind))

local instrs, addrToIndex = ScriptBytecode.decode(data, townSignPtr)
check("Town Sign script decodes to exactly 3 instructions (loadword, callstd, end)", #instrs == 3, #instrs)
check("decoded op sequence matches the real `msgbox ..., MSGBOX_SIGN` + `end` macro expansion",
  instrs[1] and instrs[1].op == "loadword" and instrs[2] and instrs[2].op == "callstd" and instrs[2].stdIndex == 3
  and instrs[3] and instrs[3].op == "end",
  instrs[1] and (instrs[1].op .. "," .. instrs[2].op .. "(" .. tostring(instrs[2].stdIndex) .. ")," .. instrs[3].op))

local messages = {}
local hookOrder = {}
local world = {
  onLockAll = function() hookOrder[#hookOrder + 1] = "lockall" end,
  onMessage = function(ptr) messages[#messages + 1] = ptr; hookOrder[#hookOrder + 1] = "message" end,
  onWaitMessage = function() hookOrder[#hookOrder + 1] = "waitmessage" end,
  onWaitButtonPress = function() hookOrder[#hookOrder + 1] = "waitbuttonpress" end,
  onReleaseAll = function() hookOrder[#hookOrder + 1] = "releaseall" end,
}
local vm = ScriptInterpreter.new(instrs, addrToIndex, world)
local finished = vm:run(100)
check("real Town Sign script runs to completion without error or infinite loop", finished)
check("real MSGBOX_SIGN std body ran in order (lockall, message, waitmessage, waitbuttonpress, releaseall)",
  table.concat(hookOrder, ",") == "lockall,message,waitmessage,waitbuttonpress,releaseall", table.concat(hookOrder, ","))
check("exactly one real message was shown", #messages == 1, #messages)

local textPtr = messages[1]
local textBytes = data:sub(textPtr - ScriptBytecode.romBase + 1, textPtr - ScriptBytecode.romBase + 128)
local text = Charmap.decode(textBytes)
check("real decoded text is PalletTown_Text_TownSign's exact real content",
  text == "PALLET TOWN\nShades of your journey await!", text)

-- Real Viridian City Mart clerk script (data/maps/ViridianCity_Mart/
-- scripts.inc): message, waitmessage, then `pokemart
-- ViridianCity_Mart_Items`, then a real trailing msgbox/release/end --
-- the clerk's object event script is at ViridianCity_Mart's group 5,
-- map 3 (MAP_VIRIDIAN_CITY_MART, include/constants/map_groups.h:
-- `(3 | (5 << 8))` -- num=3, group=5).
local MAP_VIRIDIAN_CITY_MART = 5 * 256 + 3
local martHeader = MapHeader.resolve(data, addrs.gMapGroups, MAP_VIRIDIAN_CITY_MART)
local martEvents = MapEvents.resolve(data, martHeader.eventsPtr)
check("Viridian Mart map has at least one object event (the clerk)",
  martEvents.objectEvents and martEvents.objectEvents[0] ~= nil)

-- Real script content confirms which object event is the clerk (its
-- decoded instructions must reach a real `pokemart` opcode); scan every
-- object event on the map rather than assuming a specific local id, so
-- this doesn't silently break if the real event ordering ever surprises.
local pokemartInstr, pokemartAddrToIndex, clerkPtr
local i = 0
while martEvents.objectEvents[i] do
  local obj = martEvents.objectEvents[i]
  if obj.scriptPtr and obj.scriptPtr ~= 0 then
    local ok2, decoded, a2i = pcall(ScriptBytecode.decode, data, obj.scriptPtr)
    if ok2 then
      for _, instr in ipairs(decoded) do
        if instr.op == "pokemart" then
          pokemartInstr, pokemartAddrToIndex, clerkPtr = decoded, a2i, obj.scriptPtr
          break
        end
      end
    end
  end
  if pokemartInstr then break end
  i = i + 1
end
check("found the real clerk object event whose script contains a real pokemart opcode",
  pokemartInstr ~= nil, "no object event script on Viridian Mart decoded a pokemart opcode")

if pokemartInstr then
  local pokemartAt
  for _, instr in ipairs(pokemartInstr) do
    if instr.op == "pokemart" then pokemartAt = instr end
  end
  -- Real ViridianCity_Mart_Items: ITEM_POKE_BALL(4), ITEM_POTION(13),
  -- ITEM_ANTIDOTE(14), ITEM_PARALYZE_HEAL(18), ITEM_NONE(0) terminator --
  -- confirms the decoded pointer really does resolve to the same real
  -- stock list src/core/PokemonMartMenu.lua/main.lua's `M` view hardcodes.
  local base = pokemartAt.itemListPtr - ScriptBytecode.romBase
  local function u16leAt(off)
    local b1, b2 = data:byte(base + off + 1), data:byte(base + off + 2)
    return b1 + b2 * 256
  end
  local realItems = { u16leAt(0), u16leAt(2), u16leAt(4), u16leAt(6), u16leAt(8) }
  check("real ViridianCity_Mart_Items resolves to POKE_BALL/POTION/ANTIDOTE/PARALYZE_HEAL/NONE",
    realItems[1] == 4 and realItems[2] == 13 and realItems[3] == 14
      and realItems[4] == 18 and realItems[5] == 0,
    table.concat(realItems, ","))
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
