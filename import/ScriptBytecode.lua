-- Decodes real FireRed map-script bytecode (the byte stream a MapScripts /
-- MapEvents script pointer points at) into a flat list of typed Lua
-- instruction tables -- same "decode a real command byte stream" pattern as
-- import/SpriteAnim.lua / import/SongEvents.lua. NOT a full ~100+ opcode
-- implementation -- scoped to the checklist line "message, choice, flag/var
-- ops, movement, warp, give item/pokemon, trainer trigger, fade, callback"
-- plus the minimal control flow (goto/call/return/end/if) needed to walk a
-- real script to completion. See src/core/ScriptInterpreter.lua for the VM
-- that executes this module's output.
--
-- Real opcode table traced from (NOT guessed from generic docs):
--   - data/script_cmd_table.inc: gScriptCmdTable[], the real, fixed
--     opcode-byte -> ScrCmd_* handler mapping (0x00-0xd4, 213 real
--     commands). Opcode N's handler is table entry N; this module's opcode
--     numbers below are those literal table indices.
--   - src/scrcmd.c: every ScrCmd_* handler's body, read directly to see
--     exactly which ScriptReadByte()/ScriptReadHalfword()/ScriptReadWord()
--     calls it makes (byte/u16 LE/u32 LE respectively -- confirmed in
--     src/script.c's ScriptReadHalfword/ScriptReadWord, which build the
--     value byte-by-byte from ctx->scriptPtr, least-significant byte
--     first, i.e. real little-endian, matching every other import/*.lua
--     module already in this repo).
--   - src/battle_setup.c: BattleSetup_ConfigureTrainerBattle /
--     TrainerBattleLoadArgs / the six sTrainer*BattleParams tables --
--     ScrCmd_trainerbattle (0x5c)'s single argument byte selects one of
--     six different variable-length argument layouts (see decodeTrainerbattle
--     below); this is the single most involved opcode in the whole table.
--   - data/scripts/std_msgbox.inc, data/scripts/trainer_battle.inc: real
--     "std script" bodies (what gotostd/callstd/gotopostbattlescript jump
--     into) -- these are themselves ordinary script bytecode at fixed real
--     addresses this repo doesn't have ROM-address table entries for, so
--     they're NOT auto-followed by the decoder; see ScriptInterpreter.lua's
--     header for how MSGBOX_* std indices are still handled faithfully
--     (their real bodies transcribed there, cited to these same files).
--
-- Implemented opcodes (37, opcode byte -> gScriptCmdTable name):
--   0x00 nop, 0x02 end, 0x03 return, 0x04 call, 0x05 goto,
--   0x06 goto_if, 0x07 call_if, 0x08 gotostd, 0x09 callstd,
--   0x0f loadword (msgbox macro's `loadword 0, text` -- feeds ctx->data[0],
--        which ScrCmd_message/ScrCmd_loadhelp/etc read when passed a NULL
--        text pointer),
--   0x16 setvar, 0x17 addvar, 0x18 subvar, 0x19 copyvar,
--   0x21 compare_var_to_value, 0x22 compare_var_to_var,
--   0x23 callnative, 0x24 gotonative, 0x25 special, 0x26 specialvar,
--   0x29 setflag, 0x2a clearflag, 0x2b checkflag,
--   0x39 warp, 0x3a warpsilent, 0x3b warpdoor, 0x3d warpteleport, 0x3e setwarp,
--   0x44 additem, 0x45 removeitem,
--   0x4f applymovement, 0x51 waitmovement,
--   0x53 removeobject, 0x54 removeobjectat,
--   0x5a faceplayer, 0x5c trainerbattle, 0x5d dotrainerbattle,
--   0x5e gotopostbattlescript, 0x5f gotobeatenscript,
--   0x60 checktrainerflag, 0x61 settrainerflag, 0x62 cleartrainerflag,
--   0x66 waitmessage, 0x67 message, 0x68 closemessage,
--   0x69 lockall, 0x6a lock, 0x6b releaseall, 0x6c release,
--   0x6d waitbuttonpress, 0x6e yesnobox, 0x6f multichoice,
--   0x79 givemon, 0x7a giveegg,
--   0x86 pokemart,
--   0x97 fadescreen, 0x98 fadescreenspeed.
--
-- Explicitly NOT implemented (real opcodes, deliberately out of scope --
-- decoding stops at these and reports an "unimplemented" instruction
-- rather than guessing an argument width):
--   - Every other warp variant (warphole has a genuinely different 2-byte
--     arg shape -- PlayerGetDestCoords instead of reading x/y off the
--     stream; setdynamicwarp/setdivewarp/setholewarp/setescapewarp/
--     warpspinenter share warp's exact 5-byte shape but are skipped for
--     scope -- trivial to add by copying the warp entry).
--   - All decoration/contest/mystery-gift/quest-log/pokemart/slot-machine/
--     coins/mystery-event/braille/berry-tree/help-window/door-animation/
--     elevator-menu/vobject/weather/RTC-clock opcodes (~140 remaining
--     entries in gScriptCmdTable) -- none named in the checklist line.
--   - setptr/copybyte/loadbyte/loadbytefromptr/setptrbyte/copylocal/
--     compare_local_*/compare_ptr_* (ctx->data[] scratch-register and raw
--     RAM-pointer commands -- real but rare in map scripts, and not named
--     in the checklist).
--   - vgoto/vcall/vgoto_if/vcall_if/setvaddress (Mystery Event's relocatable
--     script addressing -- not reachable from ordinary map scripts).
--
-- A script hitting an unimplemented opcode byte decodes to a single
-- { op = "unimplemented", opcode = <byte>, addr = <romAddr> } instruction
-- and that code path is NOT followed further (the arg width past an
-- unknown opcode is unknown, so guessing would corrupt every later byte)
-- -- see ScriptInterpreter.lua, which errors loudly if execution actually
-- reaches one.

local ScriptBytecode = {}

ScriptBytecode.romBase = 0x08000000

local byte = string.byte

local function u16le(data, off0)
  return byte(data, off0 + 1) + byte(data, off0 + 2) * 256
end

local function u32le(data, off0)
  return byte(data, off0 + 1)
    + byte(data, off0 + 2) * 256
    + byte(data, off0 + 3) * 65536
    + byte(data, off0 + 4) * 16777216
end

-- A tiny cursor over `data` starting at ROM address `addr`. Mirrors
-- script.c's ScriptReadByte/ScriptReadHalfword/ScriptReadWord exactly
-- (post-increment reads, little-endian multi-byte).
local function newCursor(data, addr)
  return { data = data, pos = addr - ScriptBytecode.romBase }
end

local function readU8(cur)
  local v = byte(cur.data, cur.pos + 1)
  cur.pos = cur.pos + 1
  return v
end

local function readU16(cur)
  local v = u16le(cur.data, cur.pos)
  cur.pos = cur.pos + 2
  return v
end

local function readU32(cur)
  local v = u32le(cur.data, cur.pos)
  cur.pos = cur.pos + 4
  return v
end

-- Real sScriptConditionTable (src/scrcmd.c) -- condition byte (0-5, in
-- source order <,==,>,<=,>=,!=) x comparisonResult (0=<,1=,2=>) -> bool.
-- Shared with ScriptInterpreter (duplicated there as plain data, not
-- required-back-in, since Lua modules shouldn't need to cross-require just
-- for a literal table).
-- Both dimensions explicitly 0-indexed ([condition][comparisonResult]) to
-- match Compare()'s real 0/1/2 (</==/>) result values exactly -- avoids
-- any off-by-one between C's 0-based array and Lua's normal 1-based one.
ScriptBytecode.CONDITION_TABLE = {
  [0] = { [0] = 1, [1] = 0, [2] = 0 }, -- <
  [1] = { [0] = 0, [1] = 1, [2] = 0 }, -- ==
  [2] = { [0] = 0, [1] = 0, [2] = 1 }, -- >
  [3] = { [0] = 1, [1] = 1, [2] = 0 }, -- <=
  [4] = { [0] = 0, [1] = 1, [2] = 1 }, -- >=
  [5] = { [0] = 1, [1] = 0, [2] = 1 }, -- !=
}

-- src/battle_setup.c's six sTrainer*BattleParams tables, reduced to which
-- of the 4 speech-pointer slots are TRAINER_PARAM_LOAD_VAL_32BIT (consumes
-- 4 real bytes) vs TRAINER_PARAM_CLEAR_VAL_32BIT (consumes 0 -- the field
-- is just zeroed in RAM, nothing to read). `second` is always
-- LOAD_VAL_16BIT (2 bytes: gTrainerBattleOpponent_A or, for mode 9 only,
-- sRivalBattleFlags), `third` is always LOAD_VAL_16BIT (2 bytes:
-- sTrainerObjectEventLocalId, or sRivalBattleFlags for mode 9 -- see
-- sEarlyRivalBattleParams). `defeat` is LOAD_32BIT in every one of the six
-- tables, so it's not listed per-mode below (always true).
local TRAINER_BATTLE_MODE_SHAPE = {
  [0] = { intro = true, victory = false, cannot = false, retAddr = false }, -- SINGLE (sOrdinaryBattleParams)
  [1] = { intro = true, victory = false, cannot = false, retAddr = true },  -- CONTINUE_SCRIPT_NO_MUSIC
  [2] = { intro = true, victory = false, cannot = false, retAddr = true },  -- CONTINUE_SCRIPT
  [3] = { intro = false, victory = false, cannot = false, retAddr = false }, -- SINGLE_NO_INTRO_TEXT
  [4] = { intro = true, victory = false, cannot = true, retAddr = false },  -- DOUBLE
  [5] = { intro = true, victory = false, cannot = false, retAddr = false }, -- REMATCH (sOrdinaryBattleParams)
  [6] = { intro = true, victory = false, cannot = true, retAddr = true },   -- CONTINUE_SCRIPT_DOUBLE
  [7] = { intro = true, victory = false, cannot = true, retAddr = false },  -- REMATCH_DOUBLE (sDoubleBattleParams)
  [8] = { intro = true, victory = false, cannot = true, retAddr = true },   -- CONTINUE_SCRIPT_DOUBLE_NO_MUSIC
  [9] = { intro = false, victory = true, cannot = false, retAddr = false }, -- EARLY_RIVAL
}
local TRAINER_BATTLE_DEFAULT_SHAPE = TRAINER_BATTLE_MODE_SHAPE[0]

-- Decodes ScrCmd_trainerbattle's (0x5c) real variable-length argument
-- block, per BattleSetup_ConfigureTrainerBattle's real mode dispatch.
-- Consumes exactly as many bytes as the real C code's TrainerBattleLoadArgs
-- would for this mode, then captures the resulting cursor position as
-- postBattleScriptPtr -- the real TRAINER_PARAM_LOAD_SCRIPT_RET_ADDR
-- behavior (SetPtr(specs->varPtr, data); return; -- captures the pointer
-- without consuming further bytes). gotopostbattlescript (0x5e) /
-- gotobeatenscript (0x5f) jump there at runtime (see ScriptInterpreter).
local function decodeTrainerbattle(cur)
  local mode = readU8(cur)
  local shape = TRAINER_BATTLE_MODE_SHAPE[mode] or TRAINER_BATTLE_DEFAULT_SHAPE
  local out = { mode = mode }
  out.opponentOrSecond = readU16(cur) -- gTrainerBattleOpponent_A (or rivalFlags source for mode 9 -- same slot)
  out.thirdField = readU16(cur)       -- sTrainerObjectEventLocalId (mode 9: sRivalBattleFlags)
  out.introSpeechPtr = shape.intro and readU32(cur) or nil
  out.defeatSpeechPtr = readU32(cur) -- always LOAD_32BIT in all 6 real tables
  out.victorySpeechPtr = shape.victory and readU32(cur) or nil
  out.cannotBattleSpeechPtr = shape.cannot and readU32(cur) or nil
  out.retAddrOverride = shape.retAddr and readU32(cur) or nil
  out.postBattleScriptPtr = cur.pos + ScriptBytecode.romBase -- LOAD_SCRIPT_RET_ADDR: captured, 0 bytes consumed
  return out
end

-- Each entry: { args = function(cur) -> argsTable, flow = "..." }.
-- flow describes how the *decoder's* worklist walk should treat this
-- instruction (not full runtime semantics -- see ScriptInterpreter for
-- that): "seq" = normal fallthrough only; "jump" = unconditional transfer
-- to args.target, no fallthrough; "condJump" = fallthrough AND args.target
-- both reachable; "call"/"condCall" = like seq but also enqueues
-- args.target (a callee, which real bytecode returns from via `return`);
-- "terminal" = script ends here, nothing reachable after (end, dotrainerbattle);
-- "external" = transfers to a real address this module doesn't have (a
-- native C table like gStdScripts by index, or a runtime-computed pointer
-- like gotopostbattlescript) -- decoding stops on this path only.
local OPS = {}

local function op(opcode, name, argsFn, flow)
  OPS[opcode] = { name = name, args = argsFn, flow = flow }
end

op(0x00, "nop", function(_) return {} end, "seq")
op(0x02, "end", function(_) return {} end, "terminal")
op(0x03, "return", function(_) return {} end, "terminal")
op(0x04, "call", function(cur) return { target = readU32(cur) } end, "call")
op(0x05, "goto", function(cur) return { target = readU32(cur) } end, "jump")
op(0x06, "goto_if", function(cur)
  local cond = readU8(cur)
  return { condition = cond, target = readU32(cur) }
end, "condJump")
op(0x07, "call_if", function(cur)
  local cond = readU8(cur)
  return { condition = cond, target = readU32(cur) }
end, "condCall")
op(0x08, "gotostd", function(cur) return { stdIndex = readU8(cur) } end, "external")
op(0x09, "callstd", function(cur) return { stdIndex = readU8(cur) } end, "seq")
op(0x0f, "loadword", function(cur)
  local index = readU8(cur)
  return { index = index, value = readU32(cur) }
end, "seq")
op(0x16, "setvar", function(cur)
  local varId = readU16(cur)
  return { varId = varId, value = readU16(cur) }
end, "seq")
op(0x17, "addvar", function(cur)
  local varId = readU16(cur)
  return { varId = varId, value = readU16(cur) }
end, "seq")
op(0x18, "subvar", function(cur)
  local varId = readU16(cur)
  return { varId = varId, value = readU16(cur) }
end, "seq")
op(0x19, "copyvar", function(cur)
  local destVarId = readU16(cur)
  return { destVarId = destVarId, srcVarId = readU16(cur) }
end, "seq")
op(0x21, "compare_var_to_value", function(cur)
  local varId = readU16(cur)
  return { varId = varId, value = readU16(cur) }
end, "seq")
op(0x22, "compare_var_to_var", function(cur)
  local varId1 = readU16(cur)
  return { varId1 = varId1, varId2 = readU16(cur) }
end, "seq")
op(0x23, "callnative", function(cur) return { funcPtr = readU32(cur) } end, "seq")
op(0x24, "gotonative", function(cur) return { funcPtr = readU32(cur) } end, "seq")
op(0x25, "special", function(cur) return { specialId = readU16(cur) } end, "seq")
op(0x26, "specialvar", function(cur)
  local varId = readU16(cur)
  return { varId = varId, specialId = readU16(cur) }
end, "seq")
op(0x29, "setflag", function(cur) return { flagId = readU16(cur) } end, "seq")
op(0x2a, "clearflag", function(cur) return { flagId = readU16(cur) } end, "seq")
op(0x2b, "checkflag", function(cur) return { flagId = readU16(cur) } end, "seq")

local function warpArgs(cur)
  local mapGroup = readU8(cur)
  local mapNum = readU8(cur)
  local warpId = readU8(cur)
  local xVarId = readU16(cur)
  return { mapGroup = mapGroup, mapNum = mapNum, warpId = warpId, xVarId = xVarId, yVarId = readU16(cur) }
end
op(0x39, "warp", warpArgs, "terminal") -- real ScrCmd_warp does DoWarp() + returns TRUE (halts this script)
op(0x3a, "warpsilent", warpArgs, "terminal")
op(0x3b, "warpdoor", warpArgs, "terminal")
op(0x3d, "warpteleport", warpArgs, "terminal")
op(0x3e, "setwarp", warpArgs, "seq") -- ScrCmd_setwarp doesn't actually warp, just records the destination

op(0x44, "additem", function(cur)
  local itemVarId = readU16(cur)
  return { itemVarId = itemVarId, quantityVarId = readU16(cur) }
end, "seq")
op(0x45, "removeitem", function(cur)
  local itemVarId = readU16(cur)
  return { itemVarId = itemVarId, quantityVarId = readU16(cur) }
end, "seq")

-- Real ScrCmd_removeobject/ScrCmd_removeobjectat (src/scrcmd.c):
-- RemoveObjectEventByLocalIdAndMap(localId, mapNum, mapGroup) -- sets the
-- object's own real FLAG_HIDE-equivalent flag (FlagSet(GetObjectEventFlag
-- IdByObjectEventId(...))) AND despawns its live sprite immediately,
-- without waiting for a map reload. localId is VarGet-resolved (same
-- convention as applymovement's localIdVarId); removeobjectat additionally
-- reads an explicit mapGroup/mapNum pair (real read order: mapGroup byte
-- then mapNum byte) instead of assuming the current map.
op(0x53, "removeobject", function(cur) return { localIdVarId = readU16(cur) } end, "seq")
op(0x54, "removeobjectat", function(cur)
  local localIdVarId = readU16(cur)
  local mapGroup = readU8(cur)
  return { localIdVarId = localIdVarId, mapGroup = mapGroup, mapNum = readU8(cur) }
end, "seq")

op(0x4f, "applymovement", function(cur)
  local localIdVarId = readU16(cur)
  return { localIdVarId = localIdVarId, movementScriptPtr = readU32(cur) }
end, "seq")
op(0x51, "waitmovement", function(cur) return { localIdVarId = readU16(cur) } end, "seq")

op(0x5a, "faceplayer", function(_) return {} end, "seq")
op(0x5c, "trainerbattle", decodeTrainerbattle, "external")
op(0x5d, "dotrainerbattle", function(_) return {} end, "terminal")
op(0x5e, "gotopostbattlescript", function(_) return {} end, "external")
op(0x5f, "gotobeatenscript", function(_) return {} end, "external")
op(0x60, "checktrainerflag", function(cur) return { trainerVarId = readU16(cur) } end, "seq")
op(0x61, "settrainerflag", function(cur) return { trainerVarId = readU16(cur) } end, "seq")
op(0x62, "cleartrainerflag", function(cur) return { trainerVarId = readU16(cur) } end, "seq")

op(0x66, "waitmessage", function(_) return {} end, "seq")
op(0x67, "message", function(cur) return { textPtr = readU32(cur) } end, "seq")
op(0x68, "closemessage", function(_) return {} end, "seq")
op(0x69, "lockall", function(_) return {} end, "seq")
op(0x6a, "lock", function(_) return {} end, "seq")
op(0x6b, "releaseall", function(_) return {} end, "seq")
op(0x6c, "release", function(_) return {} end, "seq")
op(0x6d, "waitbuttonpress", function(_) return {} end, "seq")
op(0x6e, "yesnobox", function(cur)
  local left = readU8(cur)
  return { left = left, top = readU8(cur) }
end, "seq")
op(0x6f, "multichoice", function(cur)
  local left = readU8(cur)
  local top = readU8(cur)
  local multichoiceId = readU8(cur)
  return { left = left, top = top, multichoiceId = multichoiceId, ignoreBPress = readU8(cur) }
end, "seq")

op(0x79, "givemon", function(cur)
  local speciesVarId = readU16(cur)
  local level = readU8(cur)
  local itemVarId = readU16(cur)
  local unkParam1 = readU32(cur)
  local unkParam2 = readU32(cur)
  return { speciesVarId = speciesVarId, level = level, itemVarId = itemVarId,
    unkParam1 = unkParam1, unkParam2 = unkParam2, unkParam3 = readU8(cur) }
end, "seq")
op(0x7a, "giveegg", function(cur) return { speciesVarId = readU16(cur) } end, "seq")

-- Real ScrCmd_pokemart (src/scrcmd.c): one real u32 pointer arg (the
-- item-list table, e.g. ViridianCity_Mart_Items -- an array of real u16
-- item ids terminated by ITEM_NONE, a separate real table this decoder
-- does not itself resolve, matching how e.g. warp's destination map data
-- is decoded as raw ids without this module reaching into MapHeader).
-- Real handler body is exactly `CreatePokemartMenu(ptr);
-- ScriptContext_Stop();` -- ScriptContext_Stop pauses THIS script's own
-- execution until the real mart menu closes and calls back in, but the
-- script does resume afterward at the real next instruction (confirmed
-- against ViridianCity_Mart/scripts.inc: `pokemart ...` is directly
-- followed by a real `msgbox`/`release`/`end` sequence that only makes
-- sense if execution continues past it) -- "seq" here, same as
-- waitbuttonpress/message, not "terminal": the actual pause-until-closed
-- behavior belongs to whatever real-time driver calls :step() (see
-- ScriptInterpreter.lua's callHook comments), not to this decoder's flow
-- classification.
op(0x86, "pokemart", function(cur) return { itemListPtr = readU32(cur) } end, "seq")

op(0x97, "fadescreen", function(cur) return { mode = readU8(cur) } end, "seq")
op(0x98, "fadescreenspeed", function(cur)
  local mode = readU8(cur)
  return { mode = mode, speed = readU8(cur) }
end, "seq")

ScriptBytecode.OPS = OPS

-- Decodes one instruction at ROM address `addr`. Returns the instruction
-- table (always has .op, .addr, .size) and the address immediately after
-- it (addr + size) -- callers needing control-flow walking should use
-- ScriptBytecode.decode instead of calling this directly.
function ScriptBytecode.decodeOne(data, addr)
  local cur = newCursor(data, addr)
  local opcode = readU8(cur)
  local def = OPS[opcode]
  if not def then
    return { op = "unimplemented", opcode = opcode, addr = addr, size = 1 }, addr + 1
  end
  local args = def.args(cur)
  local instr = { op = def.name, opcode = opcode, addr = addr, flow = def.flow, size = cur.pos - (addr - ScriptBytecode.romBase) }
  for k, v in pairs(args) do instr[k] = v end
  return instr, addr + instr.size
end

-- Recursive-descent disassembly starting at `entryAddr`: decodes the
-- instruction there, then follows its real control flow (per each
-- opcode's `flow` above) to decode every other instruction reachable
-- within this same script, stopping at "terminal"/"external" edges and
-- never decoding the same address twice (handles loops/shared targets
-- safely). Returns instructions sorted by address (a flat, ordered list,
-- matching this repo's other bytecode-decoder modules) plus an
-- addr -> array-index map for the interpreter's jump resolution.
function ScriptBytecode.decode(data, entryAddr)
  local byAddr = {}
  local order = {}
  local queue = { entryAddr }
  local queued = { [entryAddr] = true }

  while #queue > 0 do
    local addr = table.remove(queue)
    if not byAddr[addr] then
      local instr, nextAddr = ScriptBytecode.decodeOne(data, addr)
      byAddr[addr] = instr
      order[#order + 1] = addr

      if instr.op == "unimplemented" then
        -- Can't know its real width; don't guess at what follows.
      else
        local flow = instr.flow
        if flow == "seq" then
          if not queued[nextAddr] then queued[nextAddr] = true; queue[#queue + 1] = nextAddr end
        elseif flow == "jump" then
          if not queued[instr.target] then queued[instr.target] = true; queue[#queue + 1] = instr.target end
        elseif flow == "condJump" or flow == "call" or flow == "condCall" then
          if not queued[nextAddr] then queued[nextAddr] = true; queue[#queue + 1] = nextAddr end
          if not queued[instr.target] then queued[instr.target] = true; queue[#queue + 1] = instr.target end
        end
        -- "terminal" / "external": nothing further to enqueue on this path.
      end
    end
  end

  table.sort(order)
  local list = {}
  local addrToIndex = {}
  for i, addr in ipairs(order) do
    list[i] = byAddr[addr]
    addrToIndex[addr] = i
  end
  return list, addrToIndex
end

return ScriptBytecode
