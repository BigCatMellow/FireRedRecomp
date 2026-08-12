-- Decodes a real `union AnimCmd[]` array (include/sprite.h) into a plain
-- Lua list of typed commands. Each entry is one packed 32-bit little-
-- endian word (agbcc bitfield layout, confirmed against real ROM data --
-- see below): bits0-15 = imageValue (a tile offset for sheet-based sprites
-- like the title screen flame, or an array index for image-array
-- sprites), bits16-21 = duration (frames the image displays), bit22 =
-- hFlip, bit23 = vFlip. The low 16 bits doubling as a signed `s16 type`
-- is how the union tells a frame command apart from the two control
-- commands: type == -1 (0xFFFF) is ANIMCMD_END, type == -2 (0xFFFE) is
-- ANIMCMD_JUMP (whose target, a 0-based index back into this same array,
-- lives in the same bits16-21 duration would otherwise occupy).
-- ANIMCMD_LOOP (type -3) is a real third control command (not used by
-- the title screen flame animation this module was built against) --
-- deliberately not decoded; SpriteAnimator would need loop-count state
-- to act on it, which isn't implemented, so it's left as a documented
-- gap rather than half-supported.
--
-- Verified against real ROM data: pokefirered's sSpriteAnim_Flame (the
-- title screen flame animation, src/title_screen.c) decodes to exactly
-- ANIMCMD_FRAME(0,3), ANIMCMD_FRAME(4,6), ANIMCMD_FRAME(8,6), ...,
-- ANIMCMD_FRAME(36,6), ANIMCMD_END -- byte-for-byte matching the real C
-- source's literal ANIMCMD_FRAME(...) argument list.

local SpriteAnim = {}

local byte = string.byte

-- data: full ROM bytes (or any buffer). offset: 0-based offset of the
-- AnimCmd array. Returns a list of commands, each one of:
--   { type = "frame", imageValue = n, duration = n, hFlip = bool, vFlip = bool }
--   { type = "jump", target = n }  -- n is a 0-based index into this same list
--   { type = "end" }
-- The list always ends with a "jump" or "end" entry (real AnimCmd arrays
-- are always properly terminated) -- decoding stops there rather than
-- reading past it.
function SpriteAnim.decodeCmds(data, offset)
  local cmds = {}
  local i = 0
  while true do
    local p = offset + i * 4
    local b0, b1, b2, b3 = byte(data, p + 1), byte(data, p + 2), byte(data, p + 3), byte(data, p + 4)
    local word = b0 + b1 * 256 + b2 * 65536 + b3 * 16777216
    local low16 = word % 65536
    local signedType = low16 >= 32768 and (low16 - 65536) or low16
    local rest = math.floor(word / 65536)

    if signedType == -1 then
      cmds[#cmds + 1] = { type = "end" }
      break
    elseif signedType == -2 then
      cmds[#cmds + 1] = { type = "jump", target = rest % 64 }
      break
    else
      local duration = rest % 64
      local hFlip = math.floor(rest / 64) % 2
      local vFlip = math.floor(rest / 128) % 2
      cmds[#cmds + 1] = { type = "frame", imageValue = low16, duration = duration, hFlip = hFlip == 1, vFlip = vFlip == 1 }
    end
    i = i + 1
  end
  return cmds
end

return SpriteAnim
