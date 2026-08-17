-- Drives a decoded real script (import/ScriptBytecode.lua) through
-- src/core/ScriptInterpreter.lua with the minimal "world" implementation a
-- MESSAGE BOX needs, and nothing else. This is the missing piece between
-- ScriptInterpreter (which has no idea what a dialogue box is) and
-- main.lua's real TextWindow/TextRenderer/TextPrinterState rendering
-- primitives -- deliberately a separate pure-Lua module (no love2d, no ROM
-- decode) so the pause/advance state machine is unit-testable exactly like
-- TextPrinterState.lua is (see tests/dialogue_runner_test.lua).
--
-- Scope (per the Phase 3 integration handoff): the real
-- `lock`/`faceplayer`/`message`/`waitmessage`/`waitbuttonpress`/`release`
-- family -- i.e. what `msgbox` compiles to (`loadword 0, <text>` +
-- `callstd MSGBOX_NPC/SIGN/DEFAULT`), which is what essentially every
-- ordinary NPC and every Town Sign in the real game uses. Verified live
-- against Pallet Town's real Fat Man NPC script (0x0816582F: loadword,
-- callstd 2, end) and its real Town Sign bg-event scripts (callstd 3).
--
-- Every OTHER real opcode's world effect (warp, flag/var writes, special,
-- applymovement, trainerbattle, giveitem, ...) is INTENTIONALLY left
-- unhooked, with one exception: `pokemart`. Real ScrCmd_pokemart's
-- ScriptContext_Stop() pauses the SCRIPT until the real mart menu closes,
-- the exact same "pause until an external close signal" shape as
-- message/waitbuttonpress above -- just gated on the mart UI's own
-- isDone() instead of a button press. See onPokemart in buildWorld() and
-- self.pendingMartItemListPtr below. Every other unhooked opcode:
-- ScriptInterpreter's callHook() treats an absent hook as a
-- no-op, so those opcodes still execute their real control flow (a
-- `setvar` still advances the pc, a `goto_if` still branches) but produce
-- no world side effect. That is the "stubbed handler that returns
-- immediately" option the handoff offered, chosen over the loud-error
-- option because a real script's UNTAKEN branches are decoded too --
-- refusing to run any script containing a single warp opcode would rule
-- out most real NPCs, including ones whose live path is pure dialogue.
-- What is NOT papered over: a genuinely undecodable opcode
-- (ScriptBytecode's "unimplemented") still raises ScriptInterpreter's loud
-- error, which :tick() catches into `self.error` and surfaces to the
-- caller instead of crashing the game -- e.g. Pallet Town's real Sign Lady
-- script (0x0816575C) hits one on a rival-cutscene branch and reports it
-- rather than pretending to have run.
--
-- Because ScriptInterpreter:runStdBody() executes an entire callstd body
-- (lock, faceplayer, message, waitmessage, waitbuttonpress, release)
-- synchronously inside ONE :step() call, the whole body's hooks fire
-- before this runner regains control. The observable consequence is only
-- that `release` is recorded before the player has actually dismissed the
-- box (self.locked flips back early); the message itself still holds
-- execution, because :tick() below refuses to step further while
-- `waitingForButton` is set. Documented rather than worked around: fixing
-- it properly means making runStdBody itself steppable, which is a
-- ScriptInterpreter change out of this task's scope.

local TextPrinterState = require("src.core.TextPrinterState")
local ScriptInterpreter = require("src.core.ScriptInterpreter")

local DialogueRunner = {}
DialogueRunner.__index = DialogueRunner

-- Runaway guard: a real message-box script reaches waitbuttonpress within a
-- handful of instructions. Anything past this is a decode/interpreter bug
-- (or an unbounded real loop this module has no business running), and is
-- reported through self.error like any other failure.
local MAX_STEPS_PER_TICK = 256

-- instructions, addrToIndex: ScriptBytecode.decode(data, entryAddr)'s two
-- return values.
-- opts.tokenize(textPtr) -> Charmap token list: how this runner turns a
--   real text ROM pointer into printable tokens. Supplied by the caller so
--   this module stays free of ROM/Charmap dependencies (main.lua passes a
--   closure over the loaded ROM bytes).
-- opts.ticksPerChar: TextPrinterState reveal speed (same knob main.lua's
--   FONT_REVEAL_TICKS_PER_CHAR sets for the other text views).
-- opts.onFacePlayer(): called for the real `faceplayer` opcode -- main.lua
--   turns the interacted NPC's ObjectEventState facing toward the player.
-- opts.onRemoveObject(localId)/opts.onRemoveObjectAt(localId,mapGroup,mapNum):
--   called for the real `removeobject`/`removeobjectat` opcodes -- forwarded
--   straight through, same shape as onFacePlayer. Real ScrCmd_removeobject*
--   (src/scrcmd.c) both set the object's own real hide flag AND despawn its
--   live sprite immediately, without waiting for a map reload; main.lua's
--   hook is expected to do both (see world.removeNpcLive).
function DialogueRunner.new(instructions, addrToIndex, opts)
  opts = opts or {}
  local self = setmetatable({
    tokenize = opts.tokenize,
    ticksPerChar = opts.ticksPerChar,
    onFacePlayer = opts.onFacePlayer,
    onRemoveObject = opts.onRemoveObject,
    onRemoveObjectAt = opts.onRemoveObjectAt,
    printer = nil,          -- TextPrinterState for the currently-displayed message, or nil when no box is up
    messageTextPtr = nil,
    waitingForButton = false,
    pendingMartItemListPtr = nil, -- real u32 item-list ROM pointer while a pokemart is open, else nil
    locked = false,
    finished = false,
    error = nil,
  }, DialogueRunner)

  self.vm = ScriptInterpreter.new(instructions, addrToIndex, self:buildWorld())
  return self
end

function DialogueRunner:buildWorld()
  local self_ = self
  return {
    onMessage = function(textPtr)
      self_.messageTextPtr = textPtr
      self_.printer = TextPrinterState.new(self_.tokenize(textPtr), self_.ticksPerChar)
      self_.startedMessageThisTick = true
    end,
    -- Real waitmessage blocks until the printer finishes; here the
    -- immediately-following waitbuttonpress already refuses to advance
    -- until the message is fully revealed, so this needs no state of its
    -- own (kept as an explicit hook so the trace shows it ran).
    onWaitMessage = function() self_.sawWaitMessage = true end,
    onCloseMessage = function()
      self_.printer = nil
      self_.messageTextPtr = nil
    end,
    onWaitButtonPress = function() self_.waitingForButton = true end,
    onLock = function() self_.locked = true end,
    onLockAll = function() self_.locked = true end,
    onRelease = function() self_.locked = false end,
    onReleaseAll = function() self_.locked = false end,
    onFacePlayer = function()
      if self_.onFacePlayer then self_.onFacePlayer() end
    end,
    onRemoveObject = function(localId)
      if self_.onRemoveObject then self_.onRemoveObject(localId) end
    end,
    onRemoveObjectAt = function(localId, mapGroup, mapNum)
      if self_.onRemoveObjectAt then self_.onRemoveObjectAt(localId, mapGroup, mapNum) end
    end,
    onPokemart = function(itemListPtr)
      self_.pendingMartItemListPtr = itemListPtr
    end,
  }
end

-- True while this runner owns the screen: either a message box is up or
-- the script still has instructions to run. main.lua uses this to suppress
-- player movement input (a real `lock`-alike) and to know whether to draw
-- the dialogue box.
function DialogueRunner:isActive()
  return not self.finished or self.printer ~= nil or self.pendingMartItemListPtr ~= nil
end

-- Called by the caller once the real mart menu it opened (driven off
-- self.pendingMartItemListPtr) has closed -- the external "close signal"
-- equivalent of a button press clearing waitingForButton above, except
-- there is no single input edge to poll every tick for a multi-screen
-- shop flow, so the caller must tell us explicitly. Clears the pending
-- pointer so the *next* tick() resumes stepping the script past
-- `pokemart` into whatever real instructions follow it.
function DialogueRunner:notifyMartClosed()
  self.pendingMartItemListPtr = nil
end

-- The tokens currently revealed, for the caller to render -- nil when no
-- message box should be drawn.
function DialogueRunner:revealedTokens()
  if not self.printer then return nil end
  return self.printer:revealedTokens()
end

-- Advances one real 60Hz tick. aButtonNewlyPressed: from the caller's
-- InputState (the same "newly pressed" edge the Yes/No menu uses).
--
-- Order matters and mirrors the real printer: an A press first goes to the
-- text printer (real EXT_CTRL_CODE_PAUSE_UNTIL_PRESS / speeding past a
-- partially-revealed message), and only advances PAST a finished message
-- once it is fully revealed -- so one press never both finishes a message
-- and dismisses it.
function DialogueRunner:tick(aButtonNewlyPressed)
  if self.error then return end

  if self.pendingMartItemListPtr ~= nil then
    -- Mirrors the waitingForButton gate below, but there is no per-tick
    -- input edge to check here -- only notifyMartClosed() (called by the
    -- caller once the real mart UI it opened reports itself done) clears
    -- this, so until then every tick() is a safe no-op on the
    -- script-stepping side, exactly like repeated ticks while
    -- waitingForButton is set and no press has landed.
    return
  end

  local revealedBefore = self.printer and self.printer:isFullyRevealed()
  if self.printer then
    self.printer:tick(aButtonNewlyPressed)
  end

  if self.waitingForButton then
    if self.printer and not self.printer:isFullyRevealed() then
      return -- still revealing; the press above went to the printer
    end
    if not aButtonNewlyPressed then return end
    if self.printer and not revealedBefore then
      -- This press is what completed the reveal (or landed on the tick it
      -- completed) -- don't let it also dismiss the box.
      return
    end
    self.waitingForButton = false
    self.printer = nil
    self.messageTextPtr = nil
  end

  if self.finished then return end

  self.startedMessageThisTick = false
  for _ = 1, MAX_STEPS_PER_TICK do
    local ok, running = pcall(self.vm.step, self.vm)
    if not ok then
      self.error = tostring(running)
      self.finished = true
      self.printer = nil
      self.waitingForButton = false
      return
    end
    if not running then
      self.finished = true
      return
    end
    if self.waitingForButton or self.startedMessageThisTick or self.pendingMartItemListPtr ~= nil then return end
  end

  self.error = ("DialogueRunner: script ran %d instructions in one tick without reaching a " ..
    "message/waitbuttonpress -- treating as a runaway loop"):format(MAX_STEPS_PER_TICK)
  self.finished = true
  self.printer = nil
end

return DialogueRunner
