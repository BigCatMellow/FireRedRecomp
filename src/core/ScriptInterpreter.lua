-- A steppable VM that executes import/ScriptBytecode.lua's decoded
-- instruction list, one instruction per Interpreter:step() call (never
-- "run to completion" internally), so a future caller can pause between
-- steps -- e.g. to let a real dialogue box finish animating a message
-- before advancing past a `message`/`waitmessage` pair. Does NOT wire to
-- actual game state or UI (see the handoff doc); instead it drives a
-- caller-supplied "world" table of small callback hooks (get/set
-- flag/var, and one hook per observable side effect: message, warp,
-- give item/pokemon, trainer battle, fade, movement, native "callback"
-- calls). Every hook is optional -- an absent hook is simply skipped, so
-- a bare `{}` world is enough to exercise pure control flow (see
-- tests/script_interpreter_unit_test.lua).
--
-- Real control-flow semantics traced directly from pokefirered's
-- src/script.c / src/scrcmd.c (function names cited per-branch in
-- ScriptInterpreter:step() below) -- notably:
--   - ScriptCall/ScriptReturn (src/script.c): `call`/`call_if` push the
--     address of the NEXT instruction onto a real call stack;
--     `return` pops it. An empty-stack `return` (or `end`) halts the
--     whole script -- mirrored here as vm.finished = true.
--   - sScriptConditionTable (src/scrcmd.c, reproduced verbatim as
--     import/ScriptBytecode.lua's CONDITION_TABLE) -- `goto_if`/`call_if`
--     look up [condition][ctx->comparisonResult] to decide whether to
--     branch; comparisonResult is set by compare_var_to_value/
--     compare_var_to_var (a real 3-way </==/> compare, see Compare() in
--     scrcmd.c) OR, for checkflag/checktrainerflag, directly assigned a
--     raw 0/1 (FlagGet()/HasTrainerBeenFought() are booleans, not 3-way
--     compares) -- both cases still index the same table correctly
--     because condition 0 (<) and 1 (==) alone are what the real
--     `goto_if_unset`/`goto_if_set` macros use after a flag check.
--   - setvar/addvar: ScrCmd_setvar and ScrCmd_addvar both use the RAW
--     halfword as the value (`*ptr = ScriptReadHalfword(ctx)` /
--     `*ptr += ScriptReadHalfword(ctx)`) -- NOT resolved through
--     VarGet() (scrcmd.c even comments "addvar doesn't support adding
--     from a variable in vanilla"). subvar, compare_var_to_var, and
--     copyvar's SOURCE all DO resolve their second operand through
--     GetVarPointer/VarGet. This asymmetry is real, not a typo -- it's
--     reproduced exactly below (see handleAddvar vs handleSubvar).
--   - ScrCmd_message (scrcmd.c): a NULL text pointer (0) falls back to
--     `ctx->data[0]` -- the register `loadword 0, <text>` (0x0f) fills.
--     This is exactly what the real `msgbox` assembler macro compiles to
--     (asm/macros/event.inc: `loadword 0, \text` + `callstd \type`), so
--     decoding a real `msgbox` invocation and running it through this
--     interpreter reproduces that indirection faithfully.
--   - callstd/gotostd (0x09/0x08) real targets are gStdScripts[stdIndex]
--     -- MORE real script bytecode at fixed ROM addresses this repo
--     doesn't have an entry for in import/RomAddresses.lua, so rather
--     than leaving them as opaque no-ops, the 5 message-box std script
--     bodies (indices 2-6, the ones actually reachable from ordinary map
--     scripts) are transcribed verbatim from
--     pokefirered-master/data/scripts/std_msgbox.inc below (STD_SCRIPTS)
--     and executed as an inline op sequence -- callstd falls through
--     afterward (ScrCmd_callstd's ScriptCall pushed a real return
--     address), gotostd instead performs the std body's own trailing
--     `return` against the CALLER's stack (ScrCmd_gotostd's ScriptJump
--     does NOT push a frame -- a real tail call). Std indices 0/1/7/8/9
--     (item-pickup flows, data/scripts/obtain_item.inc /
--     event_scripts.s) are NOT transcribed -- hitting one raises the
--     same loud "unimplemented" error as an undecoded opcode.
--
-- World hook interface (all optional, called with plain args, no `self`):
--   getVar(varId) -> number | setVar(varId, value)
--   getFlag(flagId) -> boolean | setFlag(flagId) | clearFlag(flagId)
--   getTrainerFlag(trainerId) -> boolean | setTrainerFlag(id) | clearTrainerFlag(id)
--   onMessage(textPtr)  onWaitMessage()  onCloseMessage()
--   onLock() onLockAll() onRelease() onReleaseAll() onFacePlayer()
--   onWaitButtonPress() onYesNo(left,top) onMultichoice(left,top,id,ignoreB)
--   onWarp({mapGroup,mapNum,warpId,x,y}) onSetWarp(same shape)
--   onGiveItem(itemId,qty) onRemoveItem(itemId,qty)
--   onGivePokemon({species,level,item,unk1,unk2,unk3}) onGiveEgg(species)
--   onApplyMovement(localId,movementScriptPtr) onWaitMovement(localId)
--   onTrainerBattle(instr) onTrainerBattleStart()
--   onFadeScreen(mode,speed) onSpecial(specialId) -> result|nil
--   onSpecialVar(varId,specialId) -> result|nil onNative(funcPtr)
-- getVar with no hook falls back to VarGet()'s real "unresolved id reads
-- back as itself" behavior (src/event_data.c: `if (ptr==NULL) return idx`).

local ScriptBytecode = require("import.ScriptBytecode")

local ScriptInterpreter = {}
ScriptInterpreter.__index = ScriptInterpreter

local CONDITION_TABLE = ScriptBytecode.CONDITION_TABLE

-- Real bodies of pokefirered-master's data/scripts/std_msgbox.inc (indices
-- 2-6 of gStdScripts -- MSGBOX_NPC/SIGN/DEFAULT/YESNO/AUTOCLOSE), reduced
-- to the ops this interpreter can act on (real `message 0x0` is `message`
-- with textPtr=0, which resolves through ctx->data[0] exactly like the
-- real handler -- see ScrCmd_message note above). `yesnobox 20, 8`'s
-- literal args are the real ones from that file's Std_MsgboxYesNo body.
local STD_SCRIPTS = {
  [2] = { "lock", "faceplayer", "message0", "waitmessage", "waitbuttonpress", "release" }, -- Std_MsgboxNPC
  [3] = { "lockall", "message0", "waitmessage", "waitbuttonpress", "releaseall" }, -- Std_MsgboxSign
  [4] = { "message0", "waitmessage", "waitbuttonpress" }, -- Std_MsgboxDefault
  [5] = { "message0", "waitmessage", "yesnobox2008" }, -- Std_MsgboxYesNo (yesnobox 20, 8)
  [6] = { "message0", "waitmessage", "waitbuttonpress", "release" }, -- Std_MsgboxAutoclose (data/scripts/trainer_battle.inc)
}

function ScriptInterpreter.new(instructions, addrToIndex, world)
  return setmetatable({
    instructions = instructions,
    addrToIndex = addrToIndex,
    world = world or {},
    pc = 1,
    stack = {},
    comparisonResult = 1, -- real ctx->comparisonResult has no documented reset value; 1 (==) is script.c's InitScriptContext-adjacent default of "no branch taken" in practice
    data0 = 0,             -- only ctx->data[0] is modeled (see loadword note above)
    finished = false,
    postBattleScriptPtr = nil,
    trace = {},
  }, ScriptInterpreter)
end

function ScriptInterpreter:resolveAddr(addr)
  local idx = self.addrToIndex[addr]
  if not idx then
    error(("ScriptInterpreter: jump target 0x%08X is not part of this decoded script " ..
      "(ScriptBytecode.decode didn't reach it -- likely an external/std/native target)"):format(addr))
  end
  return idx
end

function ScriptInterpreter:getVar(varId)
  if self.world.getVar then return self.world.getVar(varId) end
  return varId
end

function ScriptInterpreter:setVar(varId, value)
  if self.world.setVar then self.world.setVar(varId, value) end
end

function ScriptInterpreter:getFlag(flagId)
  if self.world.getFlag then return self.world.getFlag(flagId) end
  return false
end

local function callHook(world, name, ...)
  local fn = world[name]
  if fn then return fn(...) end
  return nil
end

-- Executes one of the fixed STD_SCRIPTS pseudo-ops inline (see header
-- comment). Not a real sub-interpreter -- these bodies are short and
-- linear (no branches in any real msgbox std script), so a plain list
-- walk is sufficient and avoids the complexity of a second call stack.
function ScriptInterpreter:runStdBody(stdIndex)
  local body = STD_SCRIPTS[stdIndex]
  if not body then
    error(("ScriptInterpreter: gStdScripts[%d] is not implemented (real body in " ..
      "pokefirered data/scripts/obtain_item.inc or event_scripts.s, not transcribed here)"):format(stdIndex))
  end
  local world = self.world
  for _, pseudoOp in ipairs(body) do
    if pseudoOp == "message0" then
      callHook(world, "onMessage", self.data0)
    elseif pseudoOp == "waitmessage" then
      callHook(world, "onWaitMessage")
    elseif pseudoOp == "waitbuttonpress" then
      callHook(world, "onWaitButtonPress")
    elseif pseudoOp == "lock" then
      callHook(world, "onLock")
    elseif pseudoOp == "lockall" then
      callHook(world, "onLockAll")
    elseif pseudoOp == "release" then
      callHook(world, "onRelease")
    elseif pseudoOp == "releaseall" then
      callHook(world, "onReleaseAll")
    elseif pseudoOp == "faceplayer" then
      callHook(world, "onFacePlayer")
    elseif pseudoOp == "yesnobox2008" then
      callHook(world, "onYesNo", 20, 8)
    end
  end
end

-- Runs one instruction and advances self.pc per its real control flow.
-- Returns (running, instr): running is false once the script has ended
-- (end/return-with-empty-stack/a "terminal"-flow op like warp or
-- dotrainerbattle/trainerbattle). Errors loudly (does not return) on an
-- unimplemented opcode or an unresolvable jump target, per the handoff
-- doc's "fail loudly, don't silently no-op" requirement.
function ScriptInterpreter:step()
  if self.finished then return false, nil end
  local instr = self.instructions[self.pc]
  if not instr then
    self.finished = true
    return false, nil
  end
  self.trace[#self.trace + 1] = instr.op

  if instr.op == "unimplemented" then
    error(("ScriptInterpreter: hit unimplemented opcode 0x%02X at ROM addr 0x%08X"):format(instr.opcode, instr.addr))
  end

  local world = self.world
  local nextAddr = instr.addr + instr.size
  local op = instr.op

  if op == "nop" then
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "end" then
    self.finished = true
    return false, instr
  elseif op == "return" then
    if #self.stack == 0 then
      self.finished = true
      return false, instr
    end
    self.pc = table.remove(self.stack)
  elseif op == "goto" then
    self.pc = self:resolveAddr(instr.target)
  elseif op == "call" then
    self.stack[#self.stack + 1] = self:resolveAddr(nextAddr)
    self.pc = self:resolveAddr(instr.target)
  elseif op == "goto_if" then
    if CONDITION_TABLE[instr.condition][self.comparisonResult] == 1 then
      self.pc = self:resolveAddr(instr.target)
    else
      self.pc = self:resolveAddr(nextAddr)
    end
  elseif op == "call_if" then
    if CONDITION_TABLE[instr.condition][self.comparisonResult] == 1 then
      self.stack[#self.stack + 1] = self:resolveAddr(nextAddr)
      self.pc = self:resolveAddr(instr.target)
    else
      self.pc = self:resolveAddr(nextAddr)
    end
  elseif op == "gotostd" then
    self:runStdBody(instr.stdIndex)
    -- Real ScrCmd_gotostd does NOT push a frame -- the std body's own
    -- trailing `return` (already executed above, inline) pops whatever
    -- the CALLER previously pushed.
    if #self.stack == 0 then
      self.finished = true
      return false, instr
    end
    self.pc = table.remove(self.stack)
  elseif op == "callstd" then
    self:runStdBody(instr.stdIndex)
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "loadword" then
    if instr.index == 0 then self.data0 = instr.value end
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "setvar" then
    self:setVar(instr.varId, instr.value) -- real: raw halfword, not VarGet-resolved
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "addvar" then
    self:setVar(instr.varId, (self:getVar(instr.varId) + instr.value) % 65536) -- real: raw halfword added, not VarGet-resolved
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "subvar" then
    local delta = self:getVar(instr.value) -- real: VarGet-resolved
    self:setVar(instr.varId, (self:getVar(instr.varId) - delta) % 65536)
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "copyvar" then
    self:setVar(instr.destVarId, self:getVar(instr.srcVarId))
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "compare_var_to_value" then
    local a = self:getVar(instr.varId)
    self.comparisonResult = a < instr.value and 0 or (a == instr.value and 1 or 2)
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "compare_var_to_var" then
    local a, b = self:getVar(instr.varId1), self:getVar(instr.varId2)
    self.comparisonResult = a < b and 0 or (a == b and 1 or 2)
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "callnative" or op == "gotonative" then
    callHook(world, "onNative", instr.funcPtr)
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "special" then
    callHook(world, "onSpecial", instr.specialId)
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "specialvar" then
    local result = callHook(world, "onSpecialVar", instr.varId, instr.specialId)
    if result ~= nil then self:setVar(instr.varId, result) end
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "setflag" then
    if world.setFlag then world.setFlag(instr.flagId) end
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "clearflag" then
    if world.clearFlag then world.clearFlag(instr.flagId) end
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "checkflag" then
    self.comparisonResult = self:getFlag(instr.flagId) and 1 or 0
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "warp" or op == "warpsilent" or op == "warpdoor" or op == "warpteleport" then
    callHook(world, "onWarp", {
      mapGroup = instr.mapGroup, mapNum = instr.mapNum, warpId = instr.warpId,
      x = self:getVar(instr.xVarId), y = self:getVar(instr.yVarId),
    })
    self.finished = true -- real: DoWarp()/etc + return TRUE halts this script
    return false, instr
  elseif op == "setwarp" then
    callHook(world, "onSetWarp", {
      mapGroup = instr.mapGroup, mapNum = instr.mapNum, warpId = instr.warpId,
      x = self:getVar(instr.xVarId), y = self:getVar(instr.yVarId),
    })
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "additem" then
    callHook(world, "onGiveItem", self:getVar(instr.itemVarId), self:getVar(instr.quantityVarId))
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "removeitem" then
    callHook(world, "onRemoveItem", self:getVar(instr.itemVarId), self:getVar(instr.quantityVarId))
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "applymovement" then
    callHook(world, "onApplyMovement", self:getVar(instr.localIdVarId), instr.movementScriptPtr)
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "waitmovement" then
    callHook(world, "onWaitMovement", self:getVar(instr.localIdVarId))
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "faceplayer" then
    callHook(world, "onFacePlayer")
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "trainerbattle" then
    self.postBattleScriptPtr = instr.postBattleScriptPtr
    callHook(world, "onTrainerBattle", instr)
    -- Real: ctx->scriptPtr is redirected into a native engine helper
    -- script (EventScript_TryDoNormalTrainerBattle etc, not decoded --
    -- see ScriptBytecode.lua header). Nothing further in THIS decoded
    -- list is reachable from here.
    self.finished = true
    return false, instr
  elseif op == "dotrainerbattle" then
    callHook(world, "onTrainerBattleStart")
    self.finished = true -- real: StartTrainerBattle() + return TRUE, swaps the whole callback out
    return false, instr
  elseif op == "gotopostbattlescript" or op == "gotobeatenscript" then
    if not self.postBattleScriptPtr then
      error("ScriptInterpreter: " .. op .. " with no prior trainerbattle in this script")
    end
    local idx = self.addrToIndex[self.postBattleScriptPtr]
    if not idx then
      error(("ScriptInterpreter: %s target 0x%08X was not decoded in this script " ..
        "(chain a fresh ScriptBytecode.decode(data, postBattleScriptPtr) to continue)"):format(op, self.postBattleScriptPtr))
    end
    self.pc = idx
  elseif op == "checktrainerflag" then
    self.comparisonResult = (callHook(world, "getTrainerFlag", self:getVar(instr.trainerVarId)) and 1) or 0
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "settrainerflag" then
    callHook(world, "setTrainerFlag", self:getVar(instr.trainerVarId))
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "cleartrainerflag" then
    callHook(world, "clearTrainerFlag", self:getVar(instr.trainerVarId))
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "message" then
    local textPtr = instr.textPtr
    if textPtr == 0 then textPtr = self.data0 end
    callHook(world, "onMessage", textPtr)
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "waitmessage" then
    callHook(world, "onWaitMessage")
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "closemessage" then
    callHook(world, "onCloseMessage")
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "lockall" then
    callHook(world, "onLockAll")
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "lock" then
    callHook(world, "onLock")
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "releaseall" then
    callHook(world, "onReleaseAll")
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "release" then
    callHook(world, "onRelease")
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "waitbuttonpress" then
    callHook(world, "onWaitButtonPress")
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "yesnobox" then
    callHook(world, "onYesNo", instr.left, instr.top)
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "multichoice" then
    callHook(world, "onMultichoice", instr.left, instr.top, instr.multichoiceId, instr.ignoreBPress)
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "givemon" then
    callHook(world, "onGivePokemon", {
      species = self:getVar(instr.speciesVarId), level = instr.level, item = self:getVar(instr.itemVarId),
      unk1 = instr.unkParam1, unk2 = instr.unkParam2, unk3 = instr.unkParam3,
    })
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "giveegg" then
    callHook(world, "onGiveEgg", self:getVar(instr.speciesVarId))
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "fadescreen" then
    callHook(world, "onFadeScreen", instr.mode, 0)
    self.pc = self:resolveAddr(nextAddr)
  elseif op == "fadescreenspeed" then
    callHook(world, "onFadeScreen", instr.mode, instr.speed)
    self.pc = self:resolveAddr(nextAddr)
  else
    error("ScriptInterpreter: no handler wired for decoded op '" .. tostring(op) .. "' (decoder/interpreter opcode lists have drifted apart)")
  end

  return true, instr
end

-- Convenience: steps until the script finishes or maxSteps is exceeded
-- (a runaway-loop guard for tests, not a real engine limit). Returns
-- true if the script finished cleanly, false if maxSteps was hit first.
function ScriptInterpreter:run(maxSteps)
  maxSteps = maxSteps or 10000
  for _ = 1, maxSteps do
    local running = self:step()
    if not running then return true end
  end
  return false
end

return ScriptInterpreter
