-- Port of pokefirered's real per-frame input state (src/main.c's ReadKeys,
-- called once per VBlank from the main loop) -- held/newly-pressed/
-- repeated key tracking, including the actual key-repeat timing (an
-- initial 40-tick delay, then repeating every 5 ticks while held). This is
-- the Phase 2 "input repeat" checklist item.
--
-- Real GBA key bit values (include/gba/io_reg.h), kept as the real bitmask
-- convention rather than inventing new constants:
--   A=0x0001 B=0x0002 SELECT=0x0004 START=0x0008 RIGHT=0x0010 LEFT=0x0020
--   UP=0x0040 DOWN=0x0080 R=0x0100 L=0x0200
--
-- Deliberately not ported: the L=A button-mode remap (real ReadKeys reads
-- gSaveBlock2Ptr->optionsButtonMode) -- this project has no save data/
-- options system yet (checklist: "display settings" still open), and the
-- real code's own comment flags that remap as interacting buggily with
-- key repeat anyway, so it's not a loss worth carrying forward without the
-- options system it depends on.
--
-- InputState:update(rawKeyMask) is meant to be called once per fixed 60Hz
-- tick (see main.lua's love.update, which already ticks TaskScheduler the
-- same way) with the current frame's raw held-key bitmask (e.g. built with
-- InputState.buildMask{A_BUTTON=true, ...} from polled key state) --
-- matching ReadKeys being called once per real VBlank.

local InputState = {}

local ALL_KEY_BITS = { 0x0001, 0x0002, 0x0004, 0x0008, 0x0010, 0x0020, 0x0040, 0x0080, 0x0100, 0x0200 }

InputState.A_BUTTON = 0x0001
InputState.B_BUTTON = 0x0002
InputState.SELECT_BUTTON = 0x0004
InputState.START_BUTTON = 0x0008
InputState.DPAD_RIGHT = 0x0010
InputState.DPAD_LEFT = 0x0020
InputState.DPAD_UP = 0x0040
InputState.DPAD_DOWN = 0x0080
InputState.R_BUTTON = 0x0100
InputState.L_BUTTON = 0x0200

local DEFAULT_KEY_REPEAT_START_DELAY = 40 -- gKeyRepeatStartDelay
local DEFAULT_KEY_REPEAT_CONTINUE_DELAY = 5 -- gKeyRepeatContinueDelay

-- Lua 5.1/LuaJIT compatibility: no bitwise operators anywhere in this
-- project (see Lz77.lua's header comment for the same constraint), so
-- "bits set in a but not in b" is computed per-bit via arithmetic rather
-- than `a & ~b`. Only the 10 real GBA key bits ever need testing, so this
-- is a fixed small loop, not a general bit-twiddling routine.
local function bitsOnlyInFirst(a, b)
  local result = 0
  for _, bit in ipairs(ALL_KEY_BITS) do
    local aHasBit = (a % (bit * 2)) >= bit
    local bHasBit = (b % (bit * 2)) >= bit
    if aHasBit and not bHasBit then
      result = result + bit
    end
  end
  return result
end

-- Builds a raw key bitmask from a { A_BUTTON = true, DPAD_UP = true, ... }
-- table of InputState.*_BUTTON-keyed booleans -- the normal way a caller
-- assembles this frame's held-key state from whatever input source it's
-- polling (keyboard, gamepad, touch).
function InputState.buildMask(heldByName)
  local mask = 0
  for name, bit in pairs({
    A_BUTTON = InputState.A_BUTTON, B_BUTTON = InputState.B_BUTTON,
    SELECT_BUTTON = InputState.SELECT_BUTTON, START_BUTTON = InputState.START_BUTTON,
    DPAD_RIGHT = InputState.DPAD_RIGHT, DPAD_LEFT = InputState.DPAD_LEFT,
    DPAD_UP = InputState.DPAD_UP, DPAD_DOWN = InputState.DPAD_DOWN,
    R_BUTTON = InputState.R_BUTTON, L_BUTTON = InputState.L_BUTTON,
  }) do
    if heldByName[name] then mask = mask + bit end
  end
  return mask
end

local function newState()
  return setmetatable({
    heldKeysRaw = 0,
    newKeysRaw = 0,
    heldKeys = 0,
    newKeys = 0,
    newAndRepeatedKeys = 0,
    keyRepeatCounter = DEFAULT_KEY_REPEAT_START_DELAY,
    keyRepeatStartDelay = DEFAULT_KEY_REPEAT_START_DELAY,
    keyRepeatContinueDelay = DEFAULT_KEY_REPEAT_CONTINUE_DELAY,
  }, { __index = InputState })
end
InputState.new = newState

-- rawKeyMask: this tick's raw held-key bitmask (InputState.buildMask or
-- hand-assembled). Ported 1:1 from the real ReadKeys (the L=A remap
-- aside, see header comment).
function InputState:update(rawKeyMask)
  self.newKeysRaw = bitsOnlyInFirst(rawKeyMask, self.heldKeysRaw)
  self.newKeys = self.newKeysRaw
  self.newAndRepeatedKeys = self.newKeysRaw

  if rawKeyMask ~= 0 and self.heldKeys == rawKeyMask then
    self.keyRepeatCounter = self.keyRepeatCounter - 1
    if self.keyRepeatCounter == 0 then
      self.newAndRepeatedKeys = rawKeyMask
      self.keyRepeatCounter = self.keyRepeatContinueDelay
    end
  else
    self.keyRepeatCounter = self.keyRepeatStartDelay
  end

  self.heldKeysRaw = rawKeyMask
  self.heldKeys = self.heldKeysRaw
end

-- Convenience: was `button` newly pressed this tick, or held long enough
-- to have auto-repeated? (JOY_NEW(newAndRepeatedKeys) in real code terms.)
function InputState:isPressedOrRepeated(button)
  return (self.newAndRepeatedKeys % (button * 2)) >= button
end

function InputState:isNewlyPressed(button)
  return (self.newKeys % (button * 2)) >= button
end

function InputState:isHeld(button)
  return (self.heldKeys % (button * 2)) >= button
end

return InputState
