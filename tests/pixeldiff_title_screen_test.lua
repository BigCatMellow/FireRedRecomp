-- Integration proof for tools/pixeldiff, against real project output.
-- Opt-in via POKEPORT_ROM, skips cleanly otherwise.
--
-- Proves the tool two ways (per the screenshot-parity handoff spec):
--   1. Self-consistency: compositing the real title screen twice via
--      import/TitleScreen.lua's compositeFull (the same deterministic
--      ROM-decode pipeline run twice) diffs to exactly 0 -- confirms the
--      tool reports no false positives on a genuinely identical pair.
--   2. Regression detection: (a) a deliberately pixel-flipped copy of the
--      title screen, and (b) the title screen diffed against a
--      completely different real map composite (Pallet Town Player's
--      House 1F, group 4 map 0) -- both must be reported as large,
--      correct differences (including the dimension-mismatch path for
--      (b), since the house composite is a different pixel size).
--
-- Run: POKEPORT_ROM=/path/to/verified/pokefirered.gba lua5.1 tests/pixeldiff_title_screen_test.lua
package.path = package.path .. ";./?.lua"

local romPath = os.getenv("POKEPORT_ROM")
if not romPath then
  print("SKIP: set POKEPORT_ROM=/path/to/verified/pokefirered.gba to run this test")
  os.exit(0)
end

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local TitleScreen = require("import.TitleScreen")
local MapHeader = require("import.MapHeader")
local MapLayout = require("import.MapLayout")
local MapBlockData = require("import.MapBlockData")
local MapCompositor = require("import.MapCompositor")
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

local ok, info = RomImporter.verify(romPath)
if not ok then
  print("FAIL: ROM did not verify -- " .. tostring(info))
  os.exit(1)
end

local sha1 = RomImporter._sha1HexOfFile(romPath)
local addrs = RomAddresses[sha1]
local f = io.open(romPath, "rb")
local data = f:read("*a")
f:close()

--------------------------------------------------------------------------
-- 1. Self-consistency: same deterministic decode, run twice
--------------------------------------------------------------------------

local titleA = TitleScreen.compositeFull(data, addrs)
local titleB = TitleScreen.compositeFull(data, addrs)
local selfSummary = PixelDiff.compare(titleA, titleB)

check("self-consistency: dimensions match", selfSummary.dimensionsMatch)
check("self-consistency: reports IDENTICAL", selfSummary.identical, PixelDiff.formatSummary(selfSummary))
check("self-consistency: 0 diff pixels", selfSummary.diffPixelCount == 0, selfSummary.diffPixelCount)
check("self-consistency: 0%% differing", selfSummary.percentDiffering == 0, selfSummary.percentDiffering)
check("self-consistency: 0 max delta", selfSummary.maxChannelDelta == 0, selfSummary.maxChannelDelta)
print("self-consistency: " .. PixelDiff.formatSummary(selfSummary))

--------------------------------------------------------------------------
-- 2a. Regression detection: deliberately corrupt a copy (flip pixels)
--------------------------------------------------------------------------

-- Wrap titleA's pixel data, but invert the RGB of every pixel in a 40x40
-- block near the top-left (well inside the 256x160 canvas) -- a clean,
-- large, localized corruption whose exact pixel count we know in advance
-- (1600 pixels) so we can check the tool's count is exactly right, not
-- just "nonzero".
local CORRUPT_SIZE = 40
local corrupted = {
  width = titleA.width, height = titleA.height,
  getPixel = function(x, y)
    local p = titleA.getPixel(x, y)
    if x < CORRUPT_SIZE and y < CORRUPT_SIZE then
      return { r = 255 - p.r, g = 255 - p.g, b = 255 - p.b, a = p.a }
    end
    return p
  end,
}
local corruptSummary, diffImage = PixelDiff.compare(titleA, corrupted, { makeDiffImage = true })
print("corrupted-copy diff: " .. PixelDiff.formatSummary(corruptSummary))

check("corruption: dimensions still match", corruptSummary.dimensionsMatch)
check("corruption: not identical", corruptSummary.identical == false)
-- Some pixels inside the inverted block may coincidentally invert to the
-- same value they started at (e.g. a channel already at 128 -> 127, off
-- by one and still "differs", but a channel at exactly 0 stays inverted
-- to 255, never equal) -- true self-inversion (255-p==p) is only possible
-- at p=127.5, impossible for an integer channel, so every corrupted pixel
-- must count as differing.
check("corruption: exactly the 1600 corrupted pixels are flagged", corruptSummary.diffPixelCount == CORRUPT_SIZE * CORRUPT_SIZE, corruptSummary.diffPixelCount)
check("corruption: max delta can reach 255 (channel 0 inverts to 255)", corruptSummary.maxChannelDelta > 0)

check("diff visualization: a known-corrupted pixel is marked red", (function()
  local p = diffImage.getPixel(5, 5)
  return p.r == 255 and p.g == 0 and p.b == 0
end)())
check("diff visualization: a known-untouched pixel is not marked red", (function()
  local p = diffImage.getPixel(200, 100)
  return not (p.r == 255 and p.g == 0 and p.b == 0)
end)())

-- Also write the diff visualization to disk via the PNG encoder, as a
-- concrete artifact a human can open and look at.
local diffOutPath = os.tmpname() .. "_title_diff.png"
local wroteOk = PNG.encodeToFile(diffImage, diffOutPath)
check("diff visualization PNG was written successfully", wroteOk == true)
os.remove(diffOutPath)

--------------------------------------------------------------------------
-- 2b. Regression detection: diff against a genuinely different composite
--------------------------------------------------------------------------

-- MAP_PALLET_TOWN_PLAYERS_HOUSE_1F = group 4, num 0 (208x160px, per
-- tests/map_generalization_test.lua) -- a real indoor map with an
-- entirely different tileset than the title screen's graphics, and
-- different pixel dimensions, so this exercises the dimension-mismatch
-- reporting path specifically.
local houseHeader = MapHeader.resolve(data, addrs.gMapGroups, 4 * 256 + 0)
local houseLayout = MapLayout.resolve(data, houseHeader.mapLayoutPtr)
local houseBlockData = MapBlockData.resolve(data, houseLayout.mapPtr, houseLayout.width, houseLayout.height)
local housePrimary = MapCompositor.loadTilesetData(data, houseLayout.primaryTilesetPtr)
local houseSecondary = MapCompositor.loadTilesetData(data, houseLayout.secondaryTilesetPtr)
local houseImage = MapCompositor.composite(data, housePrimary, houseSecondary, houseBlockData, houseLayout.width, houseLayout.height)

local crossSummary = PixelDiff.compare(titleA, houseImage)
print("title-screen vs. Player's House 1F map: " .. PixelDiff.formatSummary(crossSummary))

check("title screen vs. house map: dimensions differ (256x160 vs 208x160)", crossSummary.dimensionsMatch == false, crossSummary.widthB .. "x" .. crossSummary.heightB)
check("title screen vs. house map: reports mismatch immediately, no per-pixel stats", crossSummary.percentDiffering == nil)

-- To also prove large-difference detection on genuinely different *same-
-- sized* content, crop the house image's top-left 256x160 region (padding
-- with black where it runs out) and diff that -- still a completely
-- different scene, now dimension-comparable.
local croppedHouse = {
  width = titleA.width, height = titleA.height,
  getPixel = function(x, y)
    if x < houseImage.width and y < houseImage.height then
      return houseImage.getPixel(x, y)
    end
    return { r = 0, g = 0, b = 0, a = 1 }
  end,
}
local croppedSummary = PixelDiff.compare(titleA, croppedHouse)
print("title screen vs. cropped house map (same dims): " .. PixelDiff.formatSummary(croppedSummary))
check("title screen vs. cropped house map: dimensions match", croppedSummary.dimensionsMatch)
check("title screen vs. cropped house map: not identical", croppedSummary.identical == false)
check("title screen vs. cropped house map: large fraction of pixels differ", croppedSummary.percentDiffering > 50, croppedSummary.percentDiffering)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
