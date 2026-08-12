-- Run: lua5.1 tests/gba_graphics_test.lua
package.path = package.path .. ";./?.lua"
local GbaGraphics = require("import.GbaGraphics")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- Tile where every byte is 0x21: low nibble 1, high nibble 2 -> alternating
-- pixel indices 1,2,1,2,... across all 64 pixels.
local tile = string.rep(string.char(0x21), 32)
local pixels = GbaGraphics.decode4bppTile(tile)
check("64 pixels decoded", #pixels + 1 == 64) -- 0-indexed, so max index is 63
check("even pixels are the low nibble (1)", pixels[0] == 1 and pixels[2] == 1)
check("odd pixels are the high nibble (2)", pixels[1] == 2 and pixels[3] == 2)

local badSize = pcall(GbaGraphics.decode4bppTile, string.rep("\0", 10))
check("rejects wrong-size tile data", badSize == false)

-- Colors: GBA white (0x7FFF) -> 255,255,255; black (0x0000) -> 0,0,0;
-- pure red (0x001F, R=31 G=0 B=0) -> 255,0,0.
local function u16le(n) return string.char(n % 256, math.floor(n / 256) % 256) end

local r, g, b = GbaGraphics.decodeColor(u16le(0x7FFF))
check("white decodes to 255,255,255", r == 255 and g == 255 and b == 255, r .. "," .. g .. "," .. b)

r, g, b = GbaGraphics.decodeColor(u16le(0x0000))
check("black decodes to 0,0,0", r == 0 and g == 0 and b == 0)

r, g, b = GbaGraphics.decodeColor(u16le(0x001F))
check("pure red (R=31) decodes to 255,0,0", r == 255 and g == 0 and b == 0, r .. "," .. g .. "," .. b)

-- decodePalette over 16 colors: white, then 15 blacks.
local paletteBlob = u16le(0x7FFF) .. string.rep(u16le(0x0000), 15)
local palette = GbaGraphics.decodePalette(paletteBlob, 0)
check("16 colors decoded", palette[15] ~= nil and palette[16] == nil)
check("color 0 is white", palette[0].r == 255 and palette[0].g == 255 and palette[0].b == 255)
check("color 1 is black", palette[1].r == 0 and palette[1].g == 0 and palette[1].b == 0)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
