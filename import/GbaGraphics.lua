-- Decodes GBA 4bpp tile graphics and BGR555 palettes into plain pixel/color
-- data a renderer (LÖVE or otherwise) can turn into an image. Pure data
-- transforms, no love.* calls, so this is testable under plain lua5.1.
--
-- GBA 4bpp tiles: 32 bytes per 8x8-pixel tile, 2 pixels per byte (low
-- nibble = left pixel, high nibble = right pixel), row-major, each pixel a
-- 4-bit index into a 16-color palette.
--
-- GBA palette colors: 16-bit BGR555 (bits 0-4 red, 5-9 green, 10-14 blue,
-- bit 15 unused), NOT RGB555 -- easy to get backwards.

local GbaGraphics = {}

local byte = string.byte

-- tileBytes: exactly 32 bytes (one 4bpp tile). Returns a 64-entry array (row
-- major, index 0 = top-left) of palette indices (0-15). Index 0 is
-- conventionally transparent in GBA tile graphics; callers decide that.
function GbaGraphics.decode4bppTile(tileBytes)
  assert(#tileBytes == 32, ("4bpp tile must be 32 bytes, got %d"):format(#tileBytes))
  local pixels = {}
  for i = 0, 31 do
    local b = byte(tileBytes, i + 1)
    pixels[i * 2] = b % 16          -- low nibble = left pixel
    pixels[i * 2 + 1] = math.floor(b / 16) % 16 -- high nibble = right pixel
  end
  return pixels
end

-- data: full ROM bytes (or any buffer). tilesOffset: 0-based byte offset of
-- the first tile. count: how many 32-byte tiles to decode.
-- Returns a list of decoded tiles (each a 64-entry pixel-index array).
function GbaGraphics.decodeTiles(data, tilesOffset, count)
  local out = {}
  for i = 0, count - 1 do
    local start = tilesOffset + i * 32
    local tileBytes = data:sub(start + 1, start + 32)
    if #tileBytes < 32 then
      error(("tile read ran past end of data at index %d"):format(i))
    end
    out[i] = GbaGraphics.decode4bppTile(tileBytes)
  end
  return out
end

-- 8bpp tiles (used where a BgTemplate's paletteMode is 1, e.g. the FireRed
-- title screen's logo layer -- confirmed by decoding it two ways: as 4bpp
-- it's visual noise, as 8bpp it's exactly the real "Pokémon FireRed
-- Version" logo art). 64 bytes per 8x8 tile, one full byte per pixel
-- (0-255 palette index directly, no nibble packing).
function GbaGraphics.decode8bppTile(tileBytes)
  assert(#tileBytes == 64, ("8bpp tile must be 64 bytes, got %d"):format(#tileBytes))
  local pixels = {}
  for i = 0, 63 do
    pixels[i] = byte(tileBytes, i + 1)
  end
  return pixels
end

function GbaGraphics.decodeTiles8bpp(data, tilesOffset, count)
  local out = {}
  for i = 0, count - 1 do
    local start = tilesOffset + i * 64
    local tileBytes = data:sub(start + 1, start + 64)
    if #tileBytes < 64 then
      error(("8bpp tile read ran past end of data at index %d"):format(i))
    end
    out[i] = GbaGraphics.decode8bppTile(tileBytes)
  end
  return out
end

-- colorBytes: exactly 2 bytes (one BGR555 color, little-endian u16).
-- Returns r, g, b each 0-255 (5-bit channels scaled up to 8-bit by
-- replicating the top 3 bits into the low bits, the standard GBA->RGB888
-- upscale so pure white/black stay pure).
function GbaGraphics.decodeColor(colorBytes)
  local lo, hi = byte(colorBytes, 1), byte(colorBytes, 2)
  local raw = lo + hi * 256
  local r5 = raw % 32
  local g5 = math.floor(raw / 32) % 32
  local b5 = math.floor(raw / 1024) % 32
  local function to8(c5) return math.floor(c5 * 255 / 31 + 0.5) end
  return to8(r5), to8(g5), to8(b5)
end

-- data: full ROM bytes. paletteOffset: 0-based byte offset of a 16-color
-- palette (32 bytes). Returns a 16-entry array of {r,g,b} (0-255 each).
function GbaGraphics.decodePalette(data, paletteOffset)
  local out = {}
  for i = 0, 15 do
    local start = paletteOffset + i * 2
    local colorBytes = data:sub(start + 1, start + 2)
    if #colorBytes < 2 then
      error(("palette read ran past end of data at color %d"):format(i))
    end
    local r, g, b = GbaGraphics.decodeColor(colorBytes)
    out[i] = { r = r, g = g, b = b }
  end
  return out
end

-- data: full ROM bytes. paletteOffset: 0-based byte offset. count: how many
-- colors to decode. For 8bpp ("256-color") backgrounds, GBA palette RAM
-- isn't split into 16-color banks the way 4bpp is -- an 8bpp tile's pixel
-- byte indexes directly into one flat palette, however many banks were
-- loaded into it. Same color format as decodePalette, just not fixed at 16.
function GbaGraphics.decodeFlatPalette(data, paletteOffset, count)
  local out = {}
  for i = 0, count - 1 do
    local start = paletteOffset + i * 2
    local colorBytes = data:sub(start + 1, start + 2)
    if #colorBytes < 2 then
      error(("palette read ran past end of data at color %d"):format(i))
    end
    local r, g, b = GbaGraphics.decodeColor(colorBytes)
    out[i] = { r = r, g = g, b = b }
  end
  return out
end

return GbaGraphics
