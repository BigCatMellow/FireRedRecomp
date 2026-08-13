-- Plain-Lua unit test (no ROM needed) for import/ScriptBytecode.lua's
-- decoder and src/core/ScriptInterpreter.lua's VM, using synthetic byte
-- streams built to exercise the real opcode encodings traced in those
-- modules' header comments (data/script_cmd_table.inc, src/scrcmd.c,
-- src/battle_setup.c). tests/script_interpreter_test.lua covers the real
-- ROM integration path (a real Pallet Town sign script); this covers the
-- decoder/interpreter logic itself in isolation.
--
-- Run: lua5.1 tests/script_interpreter_unit_test.lua
package.path = package.path .. ";./?.lua"
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

local ROM_BASE = ScriptBytecode.romBase

local function u8(n) return string.char(n % 256) end
local function u16le(n) return string.char(n % 256, math.floor(n / 256) % 256) end
local function u32le(n)
  return string.char(n % 256, math.floor(n / 256) % 256, math.floor(n / 65536) % 256, math.floor(n / 16777216) % 256)
end

-- Builds a synthetic "ROM" (just the raw bytes, addressed from ROM_BASE)
-- and returns (data, entryAddr).
local function image(bytes)
  return bytes, ROM_BASE
end

-- 1) Linear script: setflag, setvar, loadword+message(0)->data0, waitmessage,
--    waitbuttonpress, end. Exercises the message/loadword indirection
--    (ScrCmd_message's real "NULL text pointer falls back to ctx->data[0]"
--    behavior) and the flag/var/message/choice op families end to end.
do
  local bytes = u8(0x29) .. u16le(0x0800)                    -- setflag 0x0800
    .. u8(0x16) .. u16le(0x4000) .. u16le(5)                 -- setvar 0x4000, 5
    .. u8(0x0f) .. u8(0) .. u32le(0x08001000)                -- loadword 0, 0x08001000
    .. u8(0x67) .. u32le(0)                                  -- message 0x0 (-> data[0])
    .. u8(0x66)                                               -- waitmessage
    .. u8(0x6d)                                               -- waitbuttonpress
    .. u8(0x02)                                               -- end
  local data, entry = image(bytes)
  local instrs, addrToIndex = ScriptBytecode.decode(data, entry)
  check("linear script decodes to 7 instructions", #instrs == 7, #instrs)
  check("op order matches source", instrs[1].op == "setflag" and instrs[2].op == "setvar"
    and instrs[3].op == "loadword" and instrs[4].op == "message" and instrs[5].op == "waitmessage"
    and instrs[6].op == "waitbuttonpress" and instrs[7].op == "end")

  local flagsSet, varsSet, messages = {}, {}, {}
  local waitMessageCalls, waitButtonCalls = 0, 0
  local world = {
    setFlag = function(id) flagsSet[id] = true end,
    setVar = function(id, v) varsSet[id] = v end,
    onMessage = function(ptr) messages[#messages + 1] = ptr end,
    onWaitMessage = function() waitMessageCalls = waitMessageCalls + 1 end,
    onWaitButtonPress = function() waitButtonCalls = waitButtonCalls + 1 end,
  }
  local vm = ScriptInterpreter.new(instrs, addrToIndex, world)
  local finished = vm:run(100)
  check("script finished cleanly", finished)
  check("setflag hook fired for 0x0800", flagsSet[0x0800] == true)
  check("setvar hook fired for 0x4000=5", varsSet[0x4000] == 5)
  check("message used data[0] (loadword's value) for a NULL text ptr", messages[1] == 0x08001000)
  check("waitmessage/waitbuttonpress hooks each fired once", waitMessageCalls == 1 and waitButtonCalls == 1)
end

-- 2) call/return: a `call` should push a real return address and resume
--    right after the call site once the callee `return`s.
do
  -- addr0: call ->10 (size5)   addr5: end (size1)
  -- addr10: setflag 99 (size3)  addr13: return (size1)
  local bytes = u8(0x04) .. u32le(ROM_BASE + 10) -- call 0x...+10
    .. u8(0x02)                                    -- end (addr5)
  bytes = bytes .. string.rep("\0", 10 - #bytes)   -- pad to addr10
  bytes = bytes .. u8(0x29) .. u16le(99)           -- setflag 99 (addr10)
    .. u8(0x03)                                     -- return (addr13)
  local data, entry = image(bytes)
  local instrs, addrToIndex = ScriptBytecode.decode(data, entry)
  check("call/return script decodes to 4 instructions", #instrs == 4, #instrs)

  local calledFlag = false
  local world = { setFlag = function(id) if id == 99 then calledFlag = true end end }
  local vm = ScriptInterpreter.new(instrs, addrToIndex, world)
  local finished = vm:run(100)
  check("call/return script finished", finished)
  check("callee's setflag ran", calledFlag)
  check("execution trace visited call, setflag, return, end in that order",
    vm.trace[1] == "call" and vm.trace[2] == "setflag" and vm.trace[3] == "return" and vm.trace[4] == "end",
    table.concat(vm.trace, ","))
end

-- 3) Backward goto + compare/goto_if loop: real sScriptConditionTable
--    condition 1 (==) branches when comparisonResult==1 (Compare()'s "a==b"
--    result). Also a runaway-loop safety check: run(maxSteps) must
--    actually terminate this real decrement-to-zero loop well under the
--    cap, not just hit the cap.
do
  -- addr0: setvar VAR=3 (size5)                -> addr5
  -- addr5: LOOP: compare_var_to_value VAR,0 (size5) -> addr10
  -- addr10: goto_if ==, ->26 (size6)            -> addr16
  -- addr16: subvar VAR, <literal 1> (size5)     -> addr21
  -- addr21: goto ->5 (size5)                    -> addr26
  -- addr26: end
  local VAR = 0x0100
  local bytes = u8(0x16) .. u16le(VAR) .. u16le(3)                     -- addr0 setvar
    .. u8(0x21) .. u16le(VAR) .. u16le(0)                              -- addr5 compare_var_to_value
    .. u8(0x06) .. u8(1) .. u32le(ROM_BASE + 26)                       -- addr10 goto_if ==, ->26
    .. u8(0x18) .. u16le(VAR) .. u16le(1)                              -- addr16 subvar VAR, 1(unresolved literal)
    .. u8(0x05) .. u32le(ROM_BASE + 5)                                 -- addr21 goto ->5
    .. u8(0x02)                                                         -- addr26 end
  check("loop fixture end byte lands at offset 26", #bytes == 27, #bytes)
  local data, entry = image(bytes)
  local instrs, addrToIndex = ScriptBytecode.decode(data, entry)

  local vars = { [VAR] = 0 }
  local world = {
    getVar = function(id) return vars[id] or id end, -- real VarGet(): unresolved id reads back as itself
    setVar = function(id, v) vars[id] = v end,
  }
  local vm = ScriptInterpreter.new(instrs, addrToIndex, world)
  local finished = vm:run(1000)
  check("decrement-to-zero loop terminates", finished)
  check("loop counter reached exactly 0", vars[VAR] == 0, vars[VAR])
  check("terminated well under the step cap (real early exit, not a cap hit)", #vm.trace < 20, #vm.trace)
end

-- 4) checkflag sets comparisonResult directly from a real boolean
--    (FlagGet(), not a 3-way Compare()) -- condition 1 (==) is exactly
--    what the real goto_if_set macro compiles to.
do
  local bytes = u8(0x29) .. u16le(7)   -- setflag 7
    .. u8(0x2b) .. u16le(7)             -- checkflag 7
    .. u8(0x02)                         -- end
  local data, entry = image(bytes)
  local instrs, addrToIndex = ScriptBytecode.decode(data, entry)
  local flags = {}
  local world = {
    setFlag = function(id) flags[id] = true end,
    getFlag = function(id) return flags[id] == true end,
  }
  local vm = ScriptInterpreter.new(instrs, addrToIndex, world)
  vm:step() -- setflag
  vm:step() -- checkflag
  check("checkflag on a set flag yields comparisonResult=1 (matches goto_if_set's condition)", vm.comparisonResult == 1)
end

-- 5) callstd/gotostd: the real `msgbox text, MSGBOX_SIGN` macro compiles
--    to loadword 0,text + callstd 3. Verifies the transcribed
--    Std_MsgboxSign body (data/scripts/std_msgbox.inc) runs inline and
--    falls through afterward (callstd is call-shaped, unlike gotostd).
do
  local bytes = u8(0x0f) .. u8(0) .. u32le(0xDEAD0000)  -- loadword 0, 0xDEAD0000
    .. u8(0x09) .. u8(3)                                  -- callstd MSGBOX_SIGN(3)
    .. u8(0x02)                                            -- end
  local data, entry = image(bytes)
  local instrs, addrToIndex = ScriptBytecode.decode(data, entry)

  local hookOrder = {}
  local world = {
    onLockAll = function() hookOrder[#hookOrder + 1] = "lockall" end,
    onMessage = function(ptr) hookOrder[#hookOrder + 1] = "message:" .. string.format("%08X", ptr) end,
    onWaitMessage = function() hookOrder[#hookOrder + 1] = "waitmessage" end,
    onWaitButtonPress = function() hookOrder[#hookOrder + 1] = "waitbuttonpress" end,
    onReleaseAll = function() hookOrder[#hookOrder + 1] = "releaseall" end,
  }
  local vm = ScriptInterpreter.new(instrs, addrToIndex, world)
  local finished = vm:run(100)
  check("callstd msgbox script finished (fell through to `end`)", finished)
  check("Std_MsgboxSign body ran in the real order", table.concat(hookOrder, ",") ==
    "lockall,message:DEAD0000,waitmessage,waitbuttonpress,releaseall", table.concat(hookOrder, ","))
end

-- 6) trainerbattle's real variable-length argument decode (src/battle_setup.c):
--    mode 0 (ordinary/sOrdinaryBattleParams: intro+defeat present, victory
--    and cannotBattle cleared) vs mode 9 (EARLY_RIVAL: intro cleared,
--    defeat+victory present) must produce different byte widths and land
--    postBattleScriptPtr at the real "right after the last consumed field"
--    address in each case.
do
  local opponentA, localIdA, introA, defeatA = 5, 12, 0x08001111, 0x08002222
  local mode0Bytes = u8(0x5c) .. u8(0) .. u16le(opponentA) .. u16le(localIdA) .. u32le(introA) .. u32le(defeatA)
  local data0, entry0 = image(mode0Bytes)
  local instr0 = ScriptBytecode.decodeOne(data0, entry0)
  check("trainerbattle mode 0 total size is 14 (1 op + 13 real arg bytes)", instr0.size == 14, instr0.size)
  check("trainerbattle mode 0 fields", instr0.mode == 0 and instr0.opponentOrSecond == opponentA
    and instr0.thirdField == localIdA and instr0.introSpeechPtr == introA and instr0.defeatSpeechPtr == defeatA
    and instr0.victorySpeechPtr == nil and instr0.cannotBattleSpeechPtr == nil)
  check("trainerbattle mode 0 postBattleScriptPtr is right after the last consumed byte",
    instr0.postBattleScriptPtr == entry0 + 14)

  local opponentB, rivalFlagsB, defeatB, victoryB = 7, 1, 0x08003333, 0x08004444
  local mode9Bytes = u8(0x5c) .. u8(9) .. u16le(opponentB) .. u16le(rivalFlagsB) .. u32le(defeatB) .. u32le(victoryB)
  local data9, entry9 = image(mode9Bytes)
  local instr9 = ScriptBytecode.decodeOne(data9, entry9)
  check("trainerbattle mode 9 (EARLY_RIVAL) total size is 14 (1 op + 13 real arg bytes, no intro speech)", instr9.size == 14, instr9.size)
  check("trainerbattle mode 9 fields", instr9.mode == 9 and instr9.introSpeechPtr == nil
    and instr9.defeatSpeechPtr == defeatB and instr9.victorySpeechPtr == victoryB and instr9.cannotBattleSpeechPtr == nil)
end

-- 7) An unimplemented opcode byte must decode to a stub and make the
--    interpreter fail loudly (not silently no-op), per the handoff doc.
do
  local bytes = u8(0xFF) -- not in gScriptCmdTable's decoded subset
  local data, entry = image(bytes)
  local instrs, addrToIndex = ScriptBytecode.decode(data, entry)
  check("unimplemented opcode decodes to a single stub instruction", #instrs == 1 and instrs[1].op == "unimplemented")
  local vm = ScriptInterpreter.new(instrs, addrToIndex, {})
  local ok, err = pcall(function() vm:step() end)
  check("stepping onto an unimplemented opcode raises an error", not ok and tostring(err):find("unimplemented"), err)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
