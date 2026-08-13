-- Run: lua5.1 tests/dialogue_runner_test.lua
--
-- Covers src/core/DialogueRunner.lua's pause/advance state machine on
-- synthetic decoded-instruction lists (no ROM, no love2d) -- the same
-- "structure it as a pure function main.lua calls" testability rule
-- TextPrinterState.lua/PlayerMovement.lua already follow. The real
-- shapes reproduced here are the two that actually occur in verified data:
-- Pallet Town's Fat Man NPC (loadword, callstd MSGBOX_NPC=2, end) and its
-- Town Sign bg events (loadword, callstd MSGBOX_SIGN=3, end).
package.path = package.path .. ";./?.lua"
local DialogueRunner = require("src.core.DialogueRunner")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- Three real "HI" characters' worth of tokens is enough to exercise the
-- per-character reveal gate without a long test loop.
local function tokensFor(textPtr)
  return {
    { type = "char", char = "H" },
    { type = "char", char = "I" },
    { type = "char", char = "!" },
  }
end

-- loadword 0, 0x08165838 / callstd <stdIndex> / end -- the exact real
-- instruction sequence a `msgbox` macro compiles to.
local function msgboxScript(stdIndex)
  local instructions = {
    { op = "loadword", index = 0, value = 0x08165838, addr = 0x08165000, size = 6 },
    { op = "callstd", stdIndex = stdIndex, addr = 0x08165006, size = 2 },
    { op = "end", addr = 0x08165008, size = 1 },
  }
  local addrToIndex = { [0x08165000] = 1, [0x08165006] = 2, [0x08165008] = 3 }
  return instructions, addrToIndex
end

--------------------------------------------------------------- MSGBOX_NPC

local faced = 0
local npcInstructions, npcAddrToIndex = msgboxScript(2)
local runner = DialogueRunner.new(npcInstructions, npcAddrToIndex, {
  tokenize = tokensFor,
  ticksPerChar = 1,
  onFacePlayer = function() faced = faced + 1 end,
})

check("runner is active before it has run anything", runner:isActive())
check("no message box is up before the first tick", runner:revealedTokens() == nil)

runner:tick(false)
check("first tick reaches the real message (loadword + callstd body ran)", runner.printer ~= nil)
check("real MSGBOX_NPC body called faceplayer exactly once", faced == 1, faced)
check("real waitbuttonpress is holding execution", runner.waitingForButton == true)
check("the real message text pointer came from ctx->data[0] (loadword 0)",
  runner.messageTextPtr == 0x08165838, runner.messageTextPtr)

-- ticksPerChar = 1, so three ticks reveal the three characters.
for _ = 1, 3 do runner:tick(false) end
check("message fully revealed after 3 ticks at 1 tick/char", runner.printer:isFullyRevealed())
check("a fully-revealed message still waits for the real button press", runner.waitingForButton == true)
check("script has not ended while the box is up", runner:isActive())

runner:tick(false)
check("no press means no advance", runner.printer ~= nil)

runner:tick(true)
check("A press dismisses the finished message box", runner.printer == nil)
check("A press cleared the real waitbuttonpress", runner.waitingForButton == false)

runner:tick(false)
check("script reaches its real `end` and goes inactive", not runner:isActive())
check("no error was recorded on a clean run", runner.error == nil, runner.error)

------------------------------------------- one press never does two jobs

local signInstructions, signAddrToIndex = msgboxScript(3)
local fast = DialogueRunner.new(signInstructions, signAddrToIndex, { tokenize = tokensFor, ticksPerChar = 60 })
fast:tick(false)
check("MSGBOX_SIGN body also puts a real message up", fast.printer ~= nil)
check("MSGBOX_SIGN body ran its real waitmessage", fast.sawWaitMessage == true)
check("MSGBOX_SIGN uses the real lockall (not the NPC body's lock+faceplayer)", fast.locked == false and fast.waitingForButton == true)
-- At 60 ticks/char the message is nowhere near revealed; a press here is
-- the real "speed the printer up" press, and must NOT also close the box.
fast:tick(true)
check("a press during reveal does not dismiss the box", fast.printer ~= nil)

--------------------------------------------- loud failure is not swallowed

local badInstructions = {
  { op = "unimplemented", opcode = 0xB2, addr = 0x08165100, size = 1 },
}
local bad = DialogueRunner.new(badInstructions, { [0x08165100] = 1 }, { tokenize = tokensFor })
bad:tick(false)
check("an undecodable real opcode surfaces as an error, not a crash", bad.error ~= nil)
check("an errored script stops being active", not bad:isActive())
check("the error names the real opcode", tostring(bad.error):find("0xB2") ~= nil, bad.error)

-------------------------------------------------- unhooked opcodes no-op

-- setvar/special/warp have no world hook by design (see the module header):
-- they must still advance control flow rather than erroring.
local sideEffectInstructions = {
  { op = "setvar", varId = 0x4001, value = 3, addr = 0x08165200, size = 5 },
  { op = "special", specialId = 0x21, addr = 0x08165205, size = 3 },
  { op = "loadword", index = 0, value = 0x08165838, addr = 0x08165208, size = 6 },
  { op = "callstd", stdIndex = 4, addr = 0x0816520E, size = 2 },
  { op = "end", addr = 0x08165210, size = 1 },
}
local sideEffectIndex = { [0x08165200] = 1, [0x08165205] = 2, [0x08165208] = 3, [0x0816520E] = 4, [0x08165210] = 5 }
local mixed = DialogueRunner.new(sideEffectInstructions, sideEffectIndex, { tokenize = tokensFor, ticksPerChar = 1 })
mixed:tick(false)
check("unhooked real opcodes (setvar/special) run through to the message", mixed.printer ~= nil)
check("unhooked opcodes did not record an error", mixed.error == nil, mixed.error)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
