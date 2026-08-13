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

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
