-- Pure-Lua PNG decoder/encoder -- zero LÖVE dependency, so the pixel-diff
-- CLI (tools/pixeldiff/main.lua) and its tests can run under plain
-- `lua5.1` like every other test in this repo, with no `love.image`
-- available. Implements just enough of RFC 1950 (zlib) / RFC 1951
-- (DEFLATE) / the PNG spec to round-trip the images this project
-- produces:
--   Decode: stored, fixed-Huffman, and dynamic-Huffman DEFLATE blocks;
--     PNG filter types 0-4 (None/Sub/Up/Average/Paeth); color types
--     0 (grayscale), 2 (RGB), 3 (indexed, via PLTE [+tRNS]), 6 (RGBA),
--     all at 8 bits/channel (no interlacing, no 16-bit depth).
--   Encode: RGBA8, filter type 0 (None) per scanline, DEFLATE "stored"
--     (uncompressed) blocks only -- valid per RFC 1951 3.2.4 (compression
--     is optional; stored blocks are explicitly part of the format) and
--     trivial to get bit-exact right without a Huffman encoder. Bigger
--     files than a real PNG encoder would produce, but correctness, not
--     size, is what this tool needs.
-- No `bit`/5.3 bitwise ops anywhere (project runs under LuaJIT + plain
-- Lua 5.1) -- every shift/mask/xor below is done with math.floor/%,
-- matching import/Lz77.lua's house convention.
--
-- Verified: (1) round-trip -- PNG.encode(pixels) piped back through
-- PNG.decode() reproduces the exact original pixels for both synthetic
-- gradient/checkerboard images and this project's real title-screen
-- composite (see tests/pixeldiff_test.lua). (2) cross-implementation --
-- a PNG written by Python's Pillow (which uses dynamic-Huffman DEFLATE,
-- exercising the decoder path our own encoder never emits) was decoded
-- with PNG.decode() here and compared pixel-for-pixel against the source
-- array with an independent Python check; see the manual verification
-- note in this task's handoff/checklist entry.

local PNG = {}

local byte, char, sub = string.byte, string.char, string.sub
local floor = math.floor

--------------------------------------------------------------------------
-- Bit-level primitives (pure arithmetic, no bit library)
--------------------------------------------------------------------------

-- 32-bit XOR via per-bit arithmetic. Only used to build the CRC32 table
-- once (8 shifts x 256 entries) and to fold bytes into the running CRC,
-- so performance is a non-issue.
local function xor32(a, b)
  local result, bitVal = 0, 1
  for _ = 1, 32 do
    local abit, bbit = a % 2, b % 2
    if abit ~= bbit then result = result + bitVal end
    a, b = floor(a / 2), floor(b / 2)
    bitVal = bitVal * 2
  end
  return result
end

local CRC_TABLE = {}
do
  for n = 0, 255 do
    local c = n
    for _ = 1, 8 do
      if c % 2 == 1 then
        c = xor32(0xEDB88320, floor(c / 2))
      else
        c = floor(c / 2)
      end
    end
    CRC_TABLE[n] = c
  end
end

-- Standard CRC32: c = table[(c XOR byte) & 0xFF] XOR (c >> 8), starting
-- from 0xFFFFFFFF and inverting the result (RFC 1952 / PNG spec 6).
local function crc32Bytes(data, startPos, endPos)
  local c = 0xFFFFFFFF
  for i = startPos, endPos do
    local b = byte(data, i)
    local idx = xor32(c % 256, b)
    c = xor32(CRC_TABLE[idx], floor(c / 256))
  end
  return xor32(c, 0xFFFFFFFF)
end

local function adler32(data)
  local a, b = 1, 0
  for i = 1, #data do
    a = (a + byte(data, i)) % 65521
    b = (b + a) % 65521
  end
  return b * 65536 + a
end

--------------------------------------------------------------------------
-- Bit reader (LSB-first, matching DEFLATE's bit order) for decoding
--------------------------------------------------------------------------

local BitReader = {}
BitReader.__index = BitReader

function BitReader.new(data, pos)
  return setmetatable({ data = data, pos = pos or 1, bitPos = 0 }, BitReader)
end

function BitReader:readBit()
  local b = byte(self.data, self.pos) or error("bit reader ran past end of data")
  local bit = floor(b / (2 ^ self.bitPos)) % 2
  self.bitPos = self.bitPos + 1
  if self.bitPos == 8 then
    self.bitPos = 0
    self.pos = self.pos + 1
  end
  return bit
end

function BitReader:readBits(n)
  local v, mult = 0, 1
  for _ = 1, n do
    v = v + self:readBit() * mult
    mult = mult * 2
  end
  return v
end

function BitReader:alignToByte()
  if self.bitPos ~= 0 then
    self.bitPos = 0
    self.pos = self.pos + 1
  end
end

--------------------------------------------------------------------------
-- Huffman decode (RFC 1951 3.2.2 canonical-code construction)
--------------------------------------------------------------------------

-- lengths: array (1-based) of code length per symbol (0-based symbol =
-- index-1); 0 means "symbol unused". Returns {byLen[len][code] = symbol}
-- and the max code length.
local function buildHuffman(lengths)
  local maxLen = 0
  for i = 1, #lengths do
    if lengths[i] > maxLen then maxLen = lengths[i] end
  end
  local blCount = {}
  for i = 0, maxLen do blCount[i] = 0 end
  for i = 1, #lengths do
    if lengths[i] > 0 then blCount[lengths[i]] = blCount[lengths[i]] + 1 end
  end
  local code = 0
  local nextCode = {}
  for bits = 1, maxLen do
    code = (code + (blCount[bits - 1] or 0)) * 2
    nextCode[bits] = code
  end
  local byLen = {}
  for i = 1, #lengths do
    local len = lengths[i]
    if len > 0 then
      byLen[len] = byLen[len] or {}
      byLen[len][nextCode[len]] = i - 1
      nextCode[len] = nextCode[len] + 1
    end
  end
  return byLen, maxLen
end

local function decodeSymbol(br, byLen, maxLen)
  local code = 0
  for len = 1, maxLen do
    code = code * 2 + br:readBit()
    local entry = byLen[len]
    if entry and entry[code] ~= nil then return entry[code] end
  end
  error("invalid Huffman code in DEFLATE stream")
end

--------------------------------------------------------------------------
-- DEFLATE (RFC 1951) inflate
--------------------------------------------------------------------------

-- Length code 257..285 -> {base, extraBits}. Code 285 has base 258/0
-- extra per spec (not the arithmetic pattern the others follow).
local LENGTH_TABLE = {
  [257] = { 3, 0 }, [258] = { 4, 0 }, [259] = { 5, 0 }, [260] = { 6, 0 },
  [261] = { 7, 0 }, [262] = { 8, 0 }, [263] = { 9, 0 }, [264] = { 10, 0 },
  [265] = { 11, 1 }, [266] = { 13, 1 }, [267] = { 15, 1 }, [268] = { 17, 1 },
  [269] = { 19, 2 }, [270] = { 23, 2 }, [271] = { 27, 2 }, [272] = { 31, 2 },
  [273] = { 35, 3 }, [274] = { 43, 3 }, [275] = { 51, 3 }, [276] = { 59, 3 },
  [277] = { 67, 4 }, [278] = { 83, 4 }, [279] = { 99, 4 }, [280] = { 115, 4 },
  [281] = { 131, 5 }, [282] = { 163, 5 }, [283] = { 195, 5 }, [284] = { 227, 5 },
  [285] = { 258, 0 },
}

local DIST_TABLE = {
  [0] = { 1, 0 }, [1] = { 2, 0 }, [2] = { 3, 0 }, [3] = { 4, 0 },
  [4] = { 5, 1 }, [5] = { 7, 1 }, [6] = { 9, 2 }, [7] = { 13, 2 },
  [8] = { 17, 3 }, [9] = { 25, 3 }, [10] = { 33, 4 }, [11] = { 49, 4 },
  [12] = { 65, 5 }, [13] = { 97, 5 }, [14] = { 129, 6 }, [15] = { 193, 6 },
  [16] = { 257, 7 }, [17] = { 385, 7 }, [18] = { 513, 8 }, [19] = { 769, 8 },
  [20] = { 1025, 9 }, [21] = { 1537, 9 }, [22] = { 2049, 10 }, [23] = { 3073, 10 },
  [24] = { 4097, 11 }, [25] = { 6145, 11 }, [26] = { 8193, 12 }, [27] = { 12289, 12 },
  [28] = { 16385, 13 }, [29] = { 24577, 13 },
}

local CL_ORDER = { 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 }

local fixedLitLenTable, fixedLitLenMax
local fixedDistTable, fixedDistMax
local function fixedTables()
  if fixedLitLenTable then return fixedLitLenTable, fixedLitLenMax, fixedDistTable, fixedDistMax end
  local lens = {}
  for i = 0, 143 do lens[i + 1] = 8 end
  for i = 144, 255 do lens[i + 1] = 9 end
  for i = 256, 279 do lens[i + 1] = 7 end
  for i = 280, 287 do lens[i + 1] = 8 end
  fixedLitLenTable, fixedLitLenMax = buildHuffman(lens)
  local dlens = {}
  for i = 0, 29 do dlens[i + 1] = 5 end
  fixedDistTable, fixedDistMax = buildHuffman(dlens)
  return fixedLitLenTable, fixedLitLenMax, fixedDistTable, fixedDistMax
end

local function readDynamicTables(br)
  local hlit = br:readBits(5) + 257
  local hdist = br:readBits(5) + 1
  local hclen = br:readBits(4) + 4
  local clLens = {}
  for i = 1, 19 do clLens[i] = 0 end
  for i = 1, hclen do
    clLens[CL_ORDER[i] + 1] = br:readBits(3)
  end
  local clTable, clMax = buildHuffman(clLens)

  local allLens = {}
  local i = 1
  while i <= hlit + hdist do
    local sym = decodeSymbol(br, clTable, clMax)
    if sym < 16 then
      allLens[i] = sym
      i = i + 1
    elseif sym == 16 then
      local repeatLen = allLens[i - 1]
      local count = br:readBits(2) + 3
      for _ = 1, count do allLens[i] = repeatLen; i = i + 1 end
    elseif sym == 17 then
      local count = br:readBits(3) + 3
      for _ = 1, count do allLens[i] = 0; i = i + 1 end
    else -- 18
      local count = br:readBits(7) + 11
      for _ = 1, count do allLens[i] = 0; i = i + 1 end
    end
  end
  local litLens, distLens = {}, {}
  for j = 1, hlit do litLens[j] = allLens[j] end
  for j = 1, hdist do distLens[j] = allLens[hlit + j] end
  local litTable, litMax = buildHuffman(litLens)
  local distTable, distMax = buildHuffman(distLens)
  return litTable, litMax, distTable, distMax
end

-- Returns the decompressed bytes as a Lua string.
local function inflate(data, startPos)
  local br = BitReader.new(data, startPos)
  local out = {}
  local outLen = 0
  local function put(b)
    outLen = outLen + 1
    out[outLen] = char(b)
  end

  local final = 0
  repeat
    final = br:readBit()
    local btype = br:readBits(2)
    if btype == 0 then
      br:alignToByte()
      local lo, hi = byte(br.data, br.pos), byte(br.data, br.pos + 1)
      local len = lo + hi * 256
      br.pos = br.pos + 4 -- skip LEN + NLEN
      for _ = 1, len do
        put(byte(br.data, br.pos))
        br.pos = br.pos + 1
      end
    else
      local litTable, litMax, distTable, distMax
      if btype == 1 then
        litTable, litMax, distTable, distMax = fixedTables()
      elseif btype == 2 then
        litTable, litMax, distTable, distMax = readDynamicTables(br)
      else
        error("invalid DEFLATE block type 3")
      end
      while true do
        local sym = decodeSymbol(br, litTable, litMax)
        if sym < 256 then
          put(sym)
        elseif sym == 256 then
          break
        else
          local lengthInfo = LENGTH_TABLE[sym] or error("bad length code " .. sym)
          local length = lengthInfo[1] + br:readBits(lengthInfo[2])
          local distSym = decodeSymbol(br, distTable, distMax)
          local distInfo = DIST_TABLE[distSym] or error("bad distance code " .. distSym)
          local dist = distInfo[1] + br:readBits(distInfo[2])
          local startIdx = outLen - dist + 1
          for k = 0, length - 1 do
            out[outLen + 1] = out[startIdx + k]
            outLen = outLen + 1
          end
        end
      end
    end
  until final == 1
  return table.concat(out)
end

-- zlib wrapper (RFC 1950): 2-byte header, DEFLATE stream, 4-byte Adler32.
local function zlibInflate(data)
  -- data[1] = CMF, data[2] = FLG; no preset dictionary expected in PNG.
  return inflate(data, 3)
end

--------------------------------------------------------------------------
-- PNG filter reconstruction (spec section 9)
--------------------------------------------------------------------------

local function paeth(a, b, c)
  local p = a + b - c
  local pa, pb, pc = math.abs(p - a), math.abs(p - b), math.abs(p - c)
  if pa <= pb and pa <= pc then return a
  elseif pb <= pc then return b
  else return c end
end

-- raw: inflated scanline data (filter byte + bpp*width bytes per row).
-- Returns a flat byte array (1-based) of reconstructed, unfiltered pixel
-- bytes: width*height*bpp entries, row-major.
local function unfilter(raw, width, height, bpp)
  local stride = width * bpp
  local out = {}
  local pos = 1
  for y = 0, height - 1 do
    local filterType = byte(raw, pos)
    pos = pos + 1
    local rowStart = y * stride
    for x = 0, stride - 1 do
      local filt = byte(raw, pos)
      pos = pos + 1
      local a = x >= bpp and out[rowStart + x - bpp + 1] or 0
      local b = y > 0 and out[rowStart - stride + x + 1] or 0
      local c = (x >= bpp and y > 0) and out[rowStart - stride + x - bpp + 1] or 0
      local recon
      if filterType == 0 then recon = filt
      elseif filterType == 1 then recon = filt + a
      elseif filterType == 2 then recon = filt + b
      elseif filterType == 3 then recon = filt + floor((a + b) / 2)
      elseif filterType == 4 then recon = filt + paeth(a, b, c)
      else error("unsupported PNG filter type " .. tostring(filterType)) end
      out[rowStart + x + 1] = recon % 256
    end
  end
  return out
end

--------------------------------------------------------------------------
-- Public: decode
--------------------------------------------------------------------------

local SIGNATURE = char(137, 80, 78, 71, 13, 10, 26, 10)

-- Returns { width, height, getPixel(x,y) -> {r,g,b,a}, isFullyOpaque }
-- matching this project's image protocol (see import/TitleScreen.lua,
-- import/MapCompositor.lua), or nil, errorMessage on failure. r/g/b/a are
-- each 0-255 here (PNG's native 8bpc range).
function PNG.decode(data)
  if sub(data, 1, 8) ~= SIGNATURE then return nil, "not a PNG file (bad signature)" end
  local pos = 9
  local width, height, bitDepth, colorType
  local idatChunks = {}
  local palette, trns

  while pos <= #data do
    local len = byte(data, pos) * 16777216 + byte(data, pos + 1) * 65536 + byte(data, pos + 2) * 256 + byte(data, pos + 3)
    local ctype = sub(data, pos + 4, pos + 7)
    local dataStart = pos + 8
    if ctype == "IHDR" then
      width = byte(data, dataStart) * 16777216 + byte(data, dataStart + 1) * 65536 + byte(data, dataStart + 2) * 256 + byte(data, dataStart + 3)
      height = byte(data, dataStart + 4) * 16777216 + byte(data, dataStart + 5) * 65536 + byte(data, dataStart + 6) * 256 + byte(data, dataStart + 7)
      bitDepth = byte(data, dataStart + 8)
      colorType = byte(data, dataStart + 9)
      local interlace = byte(data, dataStart + 12)
      if bitDepth ~= 8 then return nil, "only 8-bit-depth PNGs are supported (got " .. bitDepth .. ")" end
      if interlace ~= 0 then return nil, "interlaced PNGs are not supported" end
    elseif ctype == "PLTE" then
      palette = {}
      for i = 0, len / 3 - 1 do
        palette[i] = {
          r = byte(data, dataStart + i * 3),
          g = byte(data, dataStart + i * 3 + 1),
          b = byte(data, dataStart + i * 3 + 2),
        }
      end
    elseif ctype == "tRNS" then
      trns = {}
      for i = 0, len - 1 do trns[i] = byte(data, dataStart + i) end
    elseif ctype == "IDAT" then
      idatChunks[#idatChunks + 1] = sub(data, dataStart, dataStart + len - 1)
    elseif ctype == "IEND" then
      break
    end
    pos = dataStart + len + 4 -- skip CRC
  end

  if not width then return nil, "no IHDR chunk found" end
  local bppByColorType = { [0] = 1, [2] = 3, [3] = 1, [4] = 2, [6] = 4 }
  local bpp = bppByColorType[colorType]
  if not bpp then return nil, "unsupported PNG color type " .. tostring(colorType) end

  local compressed = table.concat(idatChunks)
  local raw = zlibInflate(compressed)
  local bytes = unfilter(raw, width, height, bpp)

  local stride = width * bpp
  local function getPixel(x, y)
    local base = y * stride + x * bpp
    if colorType == 6 then
      return { r = bytes[base + 1], g = bytes[base + 2], b = bytes[base + 3], a = bytes[base + 4] }
    elseif colorType == 2 then
      return { r = bytes[base + 1], g = bytes[base + 2], b = bytes[base + 3], a = 255 }
    elseif colorType == 0 then
      local v = bytes[base + 1]
      return { r = v, g = v, b = v, a = 255 }
    elseif colorType == 3 then
      local idx = bytes[base + 1]
      local c = palette[idx] or { r = 0, g = 0, b = 0 }
      local a = trns and trns[idx] or 255
      return { r = c.r, g = c.g, b = c.b, a = a }
    elseif colorType == 4 then
      local v = bytes[base + 1]
      return { r = v, g = v, b = v, a = bytes[base + 2] }
    end
  end

  return { width = width, height = height, getPixel = getPixel }
end

function PNG.decodeFile(path)
  local f, ferr = io.open(path, "rb")
  if not f then return nil, ferr end
  local data = f:read("*a")
  f:close()
  return PNG.decode(data)
end

--------------------------------------------------------------------------
-- Public: encode (RGBA8, filter-None, DEFLATE stored blocks)
--------------------------------------------------------------------------

local function u32be(n)
  return char(floor(n / 16777216) % 256, floor(n / 65536) % 256, floor(n / 256) % 256, n % 256)
end

local function chunk(ctype, data)
  local body = ctype .. data
  return u32be(#data) .. body .. u32be(crc32Bytes(body, 1, #body))
end

-- DEFLATE "stored" (uncompressed) blocks: each covers at most 65535
-- bytes, final block gets BFINAL=1. Block header (after byte-align,
-- which we always are since this is byte 1 of the stream): 1 byte with
-- bit0=BFINAL, bits1-2=00 (unused/reserved bits 3-7 unused for stored) --
-- but per spec the type bits still consume the bit-stream position; since
-- we start byte-aligned and stored blocks re-align anyway, encoding the
-- 3-bit header as a whole byte (0x00 or 0x01) then aligning is spec-legal.
local function deflateStored(data)
  local parts = {}
  local pos = 1
  local total = #data
  if total == 0 then
    parts[1] = char(1) .. char(0, 0) .. char(255, 255)
  end
  while pos <= total do
    local remaining = total - pos + 1
    local blockLen = math.min(remaining, 65535)
    local isFinal = (pos + blockLen - 1) >= total
    local header = isFinal and 1 or 0
    local nlen = 65535 - blockLen
    parts[#parts + 1] = char(header)
      .. char(blockLen % 256, floor(blockLen / 256) % 256)
      .. char(nlen % 256, floor(nlen / 256) % 256)
      .. sub(data, pos, pos + blockLen - 1)
    pos = pos + blockLen
  end
  return table.concat(parts)
end

local function zlibDeflate(data)
  local cmf, flg = 0x78, 0x01 -- CM=8 (deflate), CINFO=7 (32K window); FLG chosen so (cmf*256+flg)%31==0
  local header = char(cmf, flg)
  local body = deflateStored(data)
  local trailer = u32be(adler32(data))
  return header .. body .. trailer
end

-- image: { width, height, getPixel(x,y) -> {r,g,b,a} }. a defaults to
-- 255 (opaque) if the source protocol uses a different alpha scale (this
-- project's in-memory composites use a in {0,1}, not 0-255 -- callers
-- diffing those directly with PixelDiff never go through PNG at all; this
-- encoder path is for writing real 8bpc PNG files, e.g. diff-visualization
-- output).
function PNG.encode(image)
  local width, height = image.width, image.height
  local rows = {}
  for y = 0, height - 1 do
    local rowBytes = { char(0) } -- filter type 0 = None
    for x = 0, width - 1 do
      local p = image.getPixel(x, y)
      rowBytes[#rowBytes + 1] = char(p.r % 256, p.g % 256, p.b % 256, (p.a or 255) % 256)
    end
    rows[#rows + 1] = table.concat(rowBytes)
  end
  local raw = table.concat(rows)
  local compressed = zlibDeflate(raw)

  local ihdrData = u32be(width) .. u32be(height) .. char(8, 6, 0, 0, 0) -- 8bpc, RGBA, no interlace
  local out = { SIGNATURE, chunk("IHDR", ihdrData), chunk("IDAT", compressed), chunk("IEND", "") }
  return table.concat(out)
end

function PNG.encodeToFile(image, path)
  local data = PNG.encode(image)
  local f, ferr = io.open(path, "wb")
  if not f then return nil, ferr end
  f:write(data)
  f:close()
  return true
end

return PNG
