-- Bounded Viridian City C0 roadblock adapter: one coordinate event, its
-- fixed-layout script descriptor, and its two-page message presenter.
-- Source: pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788,
-- data/maps/ViridianCity/scripts.inc:1-3,188-201 (map-script table and
-- the RoadBlocked script), text.inc:39-42 (two pages), asm/macros/event.inc
-- (opcode/operand layout), src/text.c:550-585,639-650 (paragraph wait and
-- A/B speedup latch), src/new_menu_helpers.c:27-32 (delays 8/4/1) and
-- src/scrcmd.c:1313-1318 (final NEW A before NEW B).
--
-- This module never writes session state, never executes generic bytecode
-- and makes no source male-glyph/arrow/audio/cycle-exact parity claim. The
-- host (main.lua) owns admission timing, input locks and forced movement.
local ViridianRoadblock = {}

local Charmap = require("import.Charmap")
local InputState = require("src.core.InputState")

local ROM_BASE = 0x08000000
local ROM_LIMIT = 0x02000000 -- 32MiB cartridge address window
local MAP_VIRIDIAN_CITY = 3 * 256 + 1
local C0_X, C0_Y = 22, 11
local VAR_MAP_SCENE_VIRIDIAN_CITY_OLD_MAN = 0x4051
local MAP_SCRIPT_ON_TRANSITION = 3
local MOVEMENT_WALK_NORMAL_DOWN, MOVEMENT_STEP_END = 0x10, 0xFE
local CHAR_PROMPT_CLEAR, CHAR_NEWLINE, EOS = 0xFB, 0xFE, 0xFF
local FIRST_CONTROL_BYTE = 0xF7 -- CHAR_DYNAMIC; F7..FD are controls
local TEXT_SCAN_LIMIT = 1024 -- conservative bound, not a source constant
-- Source GetTextSpeedSetting delays for OPTIONS_TEXT_SPEED_SLOW/MID/FAST.
local TEXT_SPEED_DELAYS = { [0] = 8, [1] = 4, [2] = 1 }

-- lockall / textcolor 0 / loadword 0,text / callstd MSGBOX_DEFAULT /
-- closemessage / applymovement OBJ_EVENT_ID_PLAYER,movement /
-- waitmovement 0 / releaseall / end. Byte offset -> required value; the two
-- u32 operands (text at 5, movement at 15) are resolved, never guessed.
local SCRIPT_LENGTH = 24
local SCRIPT_FIXED_BYTES = {
  [0] = 0x69,                                   -- lockall
  [1] = 0xC7, [2] = 0x00,                       -- textcolor 0
  [3] = 0x0F, [4] = 0x00,                       -- loadword 0, <text u32>
  [9] = 0x09, [10] = 0x04,                      -- callstd MSGBOX_DEFAULT
  [11] = 0x68,                                  -- closemessage
  [12] = 0x4F, [13] = 0xFF, [14] = 0x00,        -- applymovement PLAYER, <u32>
  [19] = 0x51, [20] = 0x00, [21] = 0x00,        -- waitmovement 0
  [22] = 0x6B,                                  -- releaseall
  [23] = 0x02,                                  -- end
}
local TEXT_OPERAND, MOVEMENT_OPERAND = 5, 15

local function isInteger(value, lo, hi)
  return type(value) == "number" and value % 1 == 0 and value >= lo and value <= hi
end

-- Zero-based file offset for `count` readable bytes at ROM address `ptr`.
local function romOffset(data, ptr, count)
  if type(data) ~= "string" or not isInteger(ptr, ROM_BASE, ROM_BASE + ROM_LIMIT - 1) then return nil end
  local offset = ptr - ROM_BASE
  if offset + count > #data then return nil end
  return offset
end

local function u32le(data, offset)
  local a, b, c, d = data:byte(offset + 1, offset + 4)
  return a + b * 256 + c * 65536 + d * 16777216
end

-- Nonmutating admission at an already completed field step. `context`:
-- mapId, x, y, normalStep (completed ordinary-input step), moving,
-- generation/stepGeneration, scene (raw saved var entry), events
-- (MapEvents' zero-based coord events) and elevation (effective E or nil).
-- Returns "not_selected" (legacy fallthrough), "owned", event (selected
-- C0) or "refused", reason (selected but unsupported context).
function ViridianRoadblock.classify(context)
  local c = context
  if c.mapId ~= MAP_VIRIDIAN_CITY or c.x ~= C0_X or c.y ~= C0_Y then return "not_selected" end
  -- Missing storage is not default 0; a valid nonzero scene is not C0.
  if not isInteger(c.scene, 0, 65535) then return "refused", "invalid_scene" end
  if c.scene ~= 0 then return "not_selected" end
  if not c.normalStep or c.moving or c.generation == nil or c.stepGeneration ~= c.generation then
    return "refused", "unqualified_step"
  end
  local event = type(c.events) == "table" and c.events[0]
  if type(event) ~= "table" or event.x ~= C0_X or event.y ~= C0_Y
      or event.trigger ~= VAR_MAP_SCENE_VIRIDIAN_CITY_OLD_MAN or event.index ~= 0
      or not isInteger(event.elevation, 0, 15) then
    return "refused", "invalid_c0"
  end
  for key, other in pairs(c.events) do
    if key ~= 0 and type(other) == "table" and other.x == C0_X and other.y == C0_Y then
      return "refused", "conflicting_c0"
    end
  end
  -- field_control_avatar.c:1045-1063: event E0 is a wildcard for any known
  -- player E; unknown E never qualifies, even for the wildcard.
  if not isInteger(c.elevation, 0, 15) then return "refused", "unknown_elevation" end
  if event.elevation ~= 0 and c.elevation ~= event.elevation then return "not_selected" end
  return "owned", event
end

-- Validates the selected C0 script, its movement and text from raw bytes.
-- Returns a descriptor { scriptPtr, textPtr, movementPtr, pages = {tokens,
-- tokens} } or nil, reason. Charmap.tokenize collapses 0xFB to a newline,
-- so pages are split here first; the generic decoder is not widened.
function ViridianRoadblock.describe(data, scriptPtr, mapScriptsPtr)
  -- Pinned Viridian has exactly one ON_TRANSITION hook and no on-frame
  -- table: (type u8, script u32) then the 0 terminator.
  local tableOffset = romOffset(data, mapScriptsPtr, 6)
  if not tableOffset or data:byte(tableOffset + 1) ~= MAP_SCRIPT_ON_TRANSITION
      or data:byte(tableOffset + 6) ~= 0
      or not romOffset(data, u32le(data, tableOffset + 1), 1) then
    return nil, "unsupported_map_scripts"
  end

  local script = romOffset(data, scriptPtr, SCRIPT_LENGTH)
  if not script then return nil, "truncated_script" end
  for index, value in pairs(SCRIPT_FIXED_BYTES) do
    if data:byte(script + index + 1) ~= value then return nil, "unsupported_script" end
  end
  local textPtr = u32le(data, script + TEXT_OPERAND)
  local movementPtr = u32le(data, script + MOVEMENT_OPERAND)

  local movement = romOffset(data, movementPtr, 2)
  if not movement or data:byte(movement + 1) ~= MOVEMENT_WALK_NORMAL_DOWN
      or data:byte(movement + 2) ~= MOVEMENT_STEP_END then
    return nil, "unsupported_movement"
  end

  local text = romOffset(data, textPtr, 1)
  if not text then return nil, "unavailable_text" end
  -- Accepted shape: plain glyphs, exactly one newline on page 1, one
  -- paragraph clear, plain glyphs on page 2, then EOS.
  local pages, page, newlines = { {}, {} }, 1, 0
  for i = 1, TEXT_SCAN_LIMIT do
    local b = data:byte(text + i)
    if not b then return nil, "truncated_text" end
    local bytes = pages[page]
    if b == EOS then
      if page ~= 2 or newlines ~= 1 or #pages[2] == 0 then return nil, "unsupported_text_shape" end
      return {
        scriptPtr = scriptPtr, textPtr = textPtr, movementPtr = movementPtr,
        pages = { Charmap.tokenize(table.concat(pages[1])), Charmap.tokenize(table.concat(pages[2])) },
      }
    elseif b == CHAR_PROMPT_CLEAR then
      if page ~= 1 or #bytes == 0 or bytes[#bytes] == string.char(CHAR_NEWLINE) then
        return nil, "unsupported_paragraph"
      end
      page = 2
    elseif b == CHAR_NEWLINE then
      if page ~= 1 or newlines ~= 0 or #bytes == 0 then return nil, "unsupported_newline" end
      newlines = 1
      bytes[#bytes + 1] = string.char(b)
    elseif b >= FIRST_CONTROL_BYTE then
      return nil, "unsupported_text_control"
    else
      bytes[#bytes + 1] = string.char(b)
    end
  end
  return nil, "unterminated_text"
end

-- Narrow page-printer view compatible with main's existing dialogue image
-- path (tokenIndex + revealedTokens). It has no revealAll.
local function pagePrinter(tokens)
  return {
    tokens = tokens, tokenIndex = 0,
    revealedTokens = function(self)
      local out = {}
      for i = 1, self.tokenIndex do out[i] = self.tokens[i] end
      return out
    end,
  }
end

-- textSpeed: the saved OPTIONS_TEXT_SPEED value. Unsupported values are
-- refused; saved options are never repaired here.
function ViridianRoadblock.new(descriptor, textSpeed)
  local delay = TEXT_SPEED_DELAYS[textSpeed]
  if not delay then return nil, "unsupported_text_speed" end
  return setmetatable({
    state = "PRINT_PAGE1", descriptor = descriptor, delay = delay, remaining = 0,
    accelerated = false, page = 1, printer = pagePrinter(descriptor.pages[1]),
  }, { __index = ViridianRoadblock })
end

-- A C0-owned suppression for a selected but unsupported context. It is
-- active (locks the field) until the host tears it down on map load.
function ViridianRoadblock.refused(reason)
  return setmetatable({ state = "REFUSED", reason = reason }, { __index = ViridianRoadblock })
end

function ViridianRoadblock:isActive()
  return self.state ~= "DONE" and self.state ~= "CANCELLED"
end

function ViridianRoadblock:cancel(reason)
  self.state, self.reason, self.printer = "CANCELLED", reason, nil
end

-- Presenter step, called once per fixed tick after InputState.update. Only
-- PRINT/WAIT states consume input; one call changes at most one state, so
-- a single NEW press cannot finish a page and acknowledge it. The host
-- performs CLOSE_PENDING and later states on later ticks.
function ViridianRoadblock:update(input)
  local newA = input:isNewlyPressed(InputState.A_BUTTON)
  local newB = input:isNewlyPressed(InputState.B_BUTTON)
  local state = self.state
  if state == "PRINT_PAGE1" or state == "PRINT_PAGE2" then
    -- text.c RENDER_STATE_HANDLE_CHAR: a latched speedup clears the delay
    -- while A/B is held; otherwise a pending delay counts down, and a NEW
    -- A/B latches the speedup on a frame that prints nothing.
    if self.accelerated and (input:isHeld(InputState.A_BUTTON) or input:isHeld(InputState.B_BUTTON)) then
      self.remaining = 0
    end
    if self.remaining > 0 then
      self.remaining = self.remaining - 1
      if newA or newB then self.accelerated, self.remaining = true, 0 end
      return
    end
    self.remaining = self.delay
    self.printer.tokenIndex = self.printer.tokenIndex + 1
    if self.printer.tokenIndex >= #self.printer.tokens then
      self.state = self.page == 1 and "WAIT_PAGE" or "WAIT_FINAL"
    end
  elseif state == "WAIT_PAGE" and (newA or newB) then
    -- Paragraph clear: new window contents, cursor reset, latch retained.
    self.page, self.printer, self.remaining = 2, pagePrinter(self.descriptor.pages[2]), 0
    self.state = "PRINT_PAGE2"
  elseif state == "WAIT_FINAL" and (newA or newB) then
    self.acknowledgedBy = newA and "A" or "B"
    self.state = "CLOSE_PENDING"
  end
end

return ViridianRoadblock
