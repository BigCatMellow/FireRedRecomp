-- GBA BIOS LZ77UnCompVram-compatible decompressor. FireRed's graphics,
-- tilemaps, and some data tables are LZ77-compressed with this exact format
-- (see ../../Disassembled_Games/Bios/gba_bios-master for the BIOS reference
-- implementation this must match byte-for-byte).
--
-- Header (4 bytes, little-endian): byte0 == 0x10 (LZ77 type tag), then a
-- 24-bit uncompressed size. Body: a stream of 8-flag-bit tokens; each 0 bit
-- is a literal byte, each 1 bit is a (disp, len) back-reference into the
-- already-decompressed output.

local Lz77 = {}

local byte = string.byte

-- data: a Lua string of the compressed block, starting at its 0x10 header.
-- Returns the decompressed bytes as a string, or (nil, errorMessage).
function Lz77.decompress(data, startOffset)
  startOffset = startOffset or 1
  local pos = startOffset

  local tag = byte(data, pos)
  if tag ~= 0x10 then
    return nil, ("expected LZ77 tag 0x10 at offset %d, got 0x%02x"):format(pos - 1, tag or -1)
  end

  local size = byte(data, pos + 1) + byte(data, pos + 2) * 256 + byte(data, pos + 3) * 65536
  pos = pos + 4

  local out = {}
  local outLen = 0

  while outLen < size do
    local flags = byte(data, pos)
    pos = pos + 1
    if not flags then
      return nil, "unexpected end of data reading flag byte"
    end

    -- Pure arithmetic bit extraction (no `bit` lib / 5.3 operators): this
    -- module has to run identically under LuaJIT (LÖVE's runtime) and plain
    -- lua5.1 (the standalone test harness), and division/modulo works on
    -- both.
    for bitIndex = 7, 0, -1 do
      if outLen >= size then break end

      local isRef = math.floor(flags / (2 ^ bitIndex)) % 2 == 1
      if not isRef then
        local b = byte(data, pos)
        if not b then return nil, "unexpected end of data reading literal" end
        pos = pos + 1
        outLen = outLen + 1
        out[outLen] = string.char(b)
      else
        local b1, b2 = byte(data, pos), byte(data, pos + 1)
        if not b1 or not b2 then return nil, "unexpected end of data reading back-reference" end
        pos = pos + 2
        -- b1's low nibble is the high bits of length; b2 is the low byte of
        -- displacement's low bits combined with b1's high nibble.
        local len = math.floor(b1 / 16) + 3
        local disp = (b1 % 16) * 256 + b2 + 1

        if disp > outLen then
          return nil, ("back-reference disp %d exceeds output length %d at out offset %d"):format(disp, outLen, outLen)
        end

        for _ = 1, len do
          if outLen >= size then break end
          outLen = outLen + 1
          out[outLen] = out[outLen - disp]
        end
      end
    end
  end

  return table.concat(out)
end

return Lz77
