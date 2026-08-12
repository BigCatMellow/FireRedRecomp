-- Decodes a real `union AffineAnimCmd[]` array (include/sprite.h) --
-- sprite rotation/scaling animation data (e.g. src/pokeball.c's real
-- Pokéball wobble animation, sAffineAnim_BallRotate_*).
--
-- Struct layout confirmed against real ROM bytes, NOT assumed from the C
-- declaration alone: `struct AffineAnimFrameCmd { s16 xScale; s16
-- yScale; u8 rotation; u8 duration; }` is 6 raw bytes, but decoding real
-- sAffineAnim_BallRotate_3 (verified via `nm`/`objdump`) showed each
-- array entry actually occupies 8 bytes, with the last 2 always zero --
-- agbcc pads structs/unions to 4-byte-aligned array strides, the exact
-- same padding surprise already documented for BattleMove/TrainerParty
-- earlier in this project (see RomAddresses.lua's history). Verified
-- entries: `sAffineAnim_BallRotate_3`'s two entries decode to exactly
-- `AFFINEANIMCMD_FRAME(256, 256, 0, 0)` then a type=0x7FFF `END`;
-- `sAffineAnim_BallRotate_Right`/`_0` decode to
-- `AFFINEANIMCMD_FRAME(0, 0, -3, 1)` / `(0, 0, 0, 1)` followed by a
-- type=0x7FFE `JUMP` to index 0 (both real, matching their real names).
--
-- Sentinel type values (bytes 0-1 read as signed s16), same reserved-
-- near-max-value pattern as SpriteAnim.lua's regular AnimCmd:
--   0x7FFF (32767) = END
--   0x7FFE (32766) = JUMP (target = bytes 2-3, u16)
--   0x7FFD (32765) = LOOP (count = bytes 2-3, u16)
--   anything else  = a real FRAME (xScale = bytes0-1 signed,
--                    yScale = bytes2-3 signed, rotation = byte4,
--                    duration = byte5)

local AffineAnim = {}

local byte = string.byte

local ENTRY_STRIDE = 8 -- agbcc-padded, see header comment

-- data: full ROM bytes. offset: 0-based offset of the AffineAnimCmd
-- array. Returns a list of commands (same shape family as
-- SpriteAnim.decodeCmds, plus a "loop" type this format has but the
-- regular AnimCmd format doesn't):
--   { type = "frame", xScale = n, yScale = n, rotation = n, duration = n }
--   { type = "jump", target = n }
--   { type = "loop", count = n }
--   { type = "end" }
-- The list always ends with an "end"/"jump"/"loop" entry -- decoding
-- stops there rather than reading past it.
function AffineAnim.decodeCmds(data, offset)
  local cmds = {}
  local i = 0
  while true do
    local p = offset + i * ENTRY_STRIDE
    local b0, b1 = byte(data, p + 1), byte(data, p + 2)
    local b2, b3 = byte(data, p + 3), byte(data, p + 4)
    local b4, b5 = byte(data, p + 5), byte(data, p + 6)

    local rawType = b0 + b1 * 256
    local signedType = rawType >= 32768 and (rawType - 65536) or rawType

    if signedType == 0x7FFF then
      cmds[#cmds + 1] = { type = "end" }
      break
    elseif signedType == 0x7FFE then
      cmds[#cmds + 1] = { type = "jump", target = b2 + b3 * 256 }
      break
    elseif signedType == 0x7FFD then
      cmds[#cmds + 1] = { type = "loop", count = b2 + b3 * 256 }
      break
    else
      local rawYScale = b2 + b3 * 256
      local signedYScale = rawYScale >= 32768 and (rawYScale - 65536) or rawYScale
      cmds[#cmds + 1] = { type = "frame", xScale = signedType, yScale = signedYScale, rotation = b4, duration = b5 }
    end
    i = i + 1
  end
  return cmds
end

return AffineAnim
