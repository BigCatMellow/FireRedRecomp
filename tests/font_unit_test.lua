-- Run: lua5.1 tests/font_unit_test.lua
package.path = package.path .. ";./?.lua"
local Font = require("import.Font")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- Fully synthetic offsets/glyph data: sFontHalfRowOffsets is normally a
-- 256-entry ROM table mapping byte -> combination index (0-80). For a
-- deterministic unit test, build a minimal one where byte 0 -> index 0
-- (decodes to pixel types 0,0,0,0) and byte 1 -> index 40 (13*3+1 -> i=1,
-- rem=13, j=1, rem2=4, k=1, l=1 -- i.e. index 40 = 1*27+1*9+1*3+1 -> all
-- foreground). Every other byte maps to index 0 (background).
local offsets = {}
for b = 0, 255 do offsets[b] = 0 end
offsets[1] = 40 -- all-foreground half-row
local offsetsBlob = {}
for b = 0, 255 do offsetsBlob[#offsetsBlob + 1] = string.char(offsets[b]) end
offsetsBlob = table.concat(offsetsBlob)

-- decodeGlyphPixelTypes reads both the offsets table and the glyph source
-- out of the *same* buffer (matching how the real ROM has one combined
-- address space) -- offsetsTableOffset/glyphsOffset are just two offsets
-- into it. Build one combined buffer here rather than two separate blobs.

-- Glyph source for glyphId=0: 4 tiles x 16 bytes = 64 bytes. Fill every
-- byte with 1 so every half-row decodes to all-foreground (solid glyph).
local glyphSource = string.rep(string.char(1), 64)
local data = offsetsBlob .. glyphSource

local pixelTypes = Font.decodeGlyphPixelTypes(data, 0, 256, 0)
check("16x16 pixel type grid produced", pixelTypes[15] ~= nil and pixelTypes[15][15] ~= nil)
check("all-foreground source decodes to all foreground pixels", pixelTypes[0][0] == Font.GLYPH_PIXEL_TYPE_FOREGROUND and pixelTypes[15][15] == Font.GLYPH_PIXEL_TYPE_FOREGROUND)

-- Glyph source of all zero bytes -> offsets[0]=0 -> index 0 -> i=j=k=l=0 -> all background.
local blankGlyphSource = string.rep(string.char(0), 64)
local blankData = offsetsBlob .. blankGlyphSource
local blankTypes = Font.decodeGlyphPixelTypes(blankData, 0, 256, 0)
check("all-zero source decodes to all background pixels", blankTypes[0][0] == Font.GLYPH_PIXEL_TYPE_BACKGROUND)

local img = Font.buildGlyphImage(pixelTypes, 6, { r = 10, g = 20, b = 30 }, { r = 100, g = 110, b = 120 })
check("image width matches visibleWidth, not the full 16px cell", img.width == 6 and img.height == 16)
check("foreground pixel renders with the given fgColor, opaque", (function()
  local p = img.getPixel(0, 0)
  return p.a == 1 and p.r == 10 and p.g == 20 and p.b == 30
end)())
check("pixels past visibleWidth are transparent (advance-width clipping)", img.getPixel(10, 0).a == 0)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
