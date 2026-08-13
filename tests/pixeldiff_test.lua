-- Plain-Lua unit tests for tools/pixeldiff (PixelDiff.compare + the PNG
-- codec it can run against). No ROM required -- always runs.
--
-- Run: lua5.1 tests/pixeldiff_test.lua
package.path = package.path .. ";./?.lua"

local PixelDiff = require("tools.pixeldiff.init")
local PNG = require("tools.pixeldiff.png")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- A small synthetic "image" builder: solid color, or a per-pixel function.
local function solidImage(width, height, r, g, b, a)
  return {
    width = width, height = height,
    getPixel = function(x, y) return { r = r, g = g, b = b, a = a } end,
  }
end

local function checkerboard(width, height)
  return {
    width = width, height = height,
    getPixel = function(x, y)
      local on = (x + y) % 2 == 0
      return { r = on and 255 or 0, g = on and 255 or 0, b = on and 255 or 0, a = 255 }
    end,
  }
end

--------------------------------------------------------------------------
-- PixelDiff.compare
--------------------------------------------------------------------------

do
  local a = solidImage(4, 4, 100, 100, 100, 255)
  local b = solidImage(4, 4, 100, 100, 100, 255)
  local summary = PixelDiff.compare(a, b)
  check("identical solid images: dimensionsMatch", summary.dimensionsMatch)
  check("identical solid images: identical", summary.identical)
  check("identical solid images: 0 diff pixels", summary.diffPixelCount == 0)
  check("identical solid images: 0%% differing", summary.percentDiffering == 0)
  check("identical solid images: 0 max delta", summary.maxChannelDelta == 0)
  check("identical solid images: 0 mean delta", summary.meanDelta == 0)
end

do
  local a = solidImage(2, 2, 0, 0, 0, 255)
  local b = solidImage(3, 2, 0, 0, 0, 255)
  local summary = PixelDiff.compare(a, b)
  check("mismatched dimensions reported immediately", summary.dimensionsMatch == false)
  check("mismatched dimensions: no per-pixel stats computed", summary.percentDiffering == nil)
  check("mismatched dimensions: widths recorded", summary.widthA == 2 and summary.widthB == 3)
end

do
  -- 4x4 = 16 pixels, all black vs all white: every pixel differs by 255
  -- on every channel (a included, both fully opaque 255 -> delta 0 there
  -- -- so per-pixel mean is (255+255+255+0)/4 = 191.25).
  local a = solidImage(4, 4, 0, 0, 0, 255)
  local b = solidImage(4, 4, 255, 255, 255, 255)
  local summary = PixelDiff.compare(a, b)
  check("all-black vs all-white: not identical", summary.identical == false)
  check("all-black vs all-white: 100%% differ", summary.percentDiffering == 100, summary.percentDiffering)
  check("all-black vs all-white: max delta 255", summary.maxChannelDelta == 255)
  check("all-black vs all-white: mean delta 191.25", math.abs(summary.meanDelta - 191.25) < 1e-9, summary.meanDelta)
end

do
  -- Exactly one pixel differs out of 4 -> 25% differing, known deltas.
  local pixels = {
    [0] = { [0] = { r = 0, g = 0, b = 0, a = 255 }, [1] = { r = 0, g = 0, b = 0, a = 255 } },
    [1] = { [0] = { r = 0, g = 0, b = 0, a = 255 }, [1] = { r = 10, g = 0, b = 0, a = 255 } },
  }
  local a = solidImage(2, 2, 0, 0, 0, 255)
  local b = { width = 2, height = 2, getPixel = function(x, y) return pixels[y][x] end }
  local summary, diffImage = PixelDiff.compare(a, b, { makeDiffImage = true })
  check("single-pixel diff: diffPixelCount 1", summary.diffPixelCount == 1, summary.diffPixelCount)
  check("single-pixel diff: 25%% differing", summary.percentDiffering == 25, summary.percentDiffering)
  check("single-pixel diff: max delta 10", summary.maxChannelDelta == 10)
  check("single-pixel diff: mean delta 2.5/4 = 0.625", math.abs(summary.meanDelta - 0.625) < 1e-9, summary.meanDelta)
  check("diff image marks the differing pixel red", (function()
    local p = diffImage.getPixel(1, 1)
    return p.r == 255 and p.g == 0 and p.b == 0
  end)())
  check("diff image leaves a matching pixel non-red", (function()
    local p = diffImage.getPixel(0, 0)
    return p.r ~= 255 or p.g ~= 0 or p.b ~= 0
  end)())
end

do
  -- diffThreshold: small deltas below threshold don't count as "differing".
  local a = solidImage(2, 2, 100, 100, 100, 255)
  local b = solidImage(2, 2, 102, 100, 100, 255) -- delta 2 everywhere
  local loose = PixelDiff.compare(a, b, { diffThreshold = 5 })
  local strict = PixelDiff.compare(a, b, { diffThreshold = 0 })
  check("diffThreshold suppresses small deltas", loose.diffPixelCount == 0, loose.diffPixelCount)
  check("diffThreshold 0 still catches them", strict.diffPixelCount == 4, strict.diffPixelCount)
  check("maxChannelDelta unaffected by threshold", loose.maxChannelDelta == 2 and strict.maxChannelDelta == 2)
end

check("formatSummary reports IDENTICAL", PixelDiff.formatSummary(PixelDiff.compare(solidImage(1, 1, 0, 0, 0, 255), solidImage(1, 1, 0, 0, 0, 255))):find("IDENTICAL") ~= nil)
check("formatSummary reports DIMENSION MISMATCH", PixelDiff.formatSummary(PixelDiff.compare(solidImage(1, 1, 0, 0, 0, 255), solidImage(2, 1, 0, 0, 0, 255))):find("DIMENSION MISMATCH") ~= nil)

--------------------------------------------------------------------------
-- PNG round-trip (encode then decode reproduces the exact pixels)
--------------------------------------------------------------------------

do
  local img = checkerboard(9, 5) -- odd dims, exercises row-stride math
  local encoded = PNG.encode(img)
  check("PNG.encode produces a valid signature", encoded:sub(1, 8) == string.char(137, 80, 78, 71, 13, 10, 26, 10))
  local decoded, err = PNG.decode(encoded)
  check("PNG.decode succeeds on our own encoder output", decoded ~= nil, err)
  if decoded then
    check("round-trip preserves dimensions", decoded.width == 9 and decoded.height == 5)
    local summary = PixelDiff.compare(img, decoded)
    check("round-trip is pixel-identical (checkerboard)", summary.identical, PixelDiff.formatSummary(summary))
  end
end

do
  -- Image with actual alpha variation and non-uniform colors per pixel.
  local img = {
    width = 6, height = 4,
    getPixel = function(x, y)
      return { r = (x * 37) % 256, g = (y * 61) % 256, b = ((x + y) * 19) % 256, a = (x == 0) and 0 or 255 }
    end,
  }
  local decoded = PNG.decode(PNG.encode(img))
  local summary = PixelDiff.compare(img, decoded)
  check("round-trip is pixel-identical (varied RGBA)", summary.identical, PixelDiff.formatSummary(summary))
end

do
  -- File-based round trip via encodeToFile/decodeFile, through /tmp.
  local img = solidImage(3, 3, 12, 34, 56, 78)
  local path = os.tmpname() .. ".png"
  local ok = PNG.encodeToFile(img, path)
  check("encodeToFile succeeds", ok == true)
  local decoded, err = PNG.decodeFile(path)
  check("decodeFile succeeds", decoded ~= nil, err)
  if decoded then
    check("file round-trip is pixel-identical", PixelDiff.compare(img, decoded).identical)
  end
  os.remove(path)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
