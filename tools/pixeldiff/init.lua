-- Pixel-diff comparison primitive: given two images, reports exactly how
-- different they are (dimension check, per-pixel RGBA delta, summary
-- stats), instead of the ad-hoc "screenshot it and eyeball it" that was
-- this project's only visual-verification method before Phase 2's
-- "screenshot-parity comparison tooling" checklist line.
--
-- Image protocol: any table with `width`, `height`, and
-- `getPixel(x, y) -> {r, g, b, a}` (0-based x/y) -- exactly what every
-- compositor in this project already returns (see
-- import/TitleScreen.lua's pixelsToImage, import/MapCompositor.lua's
-- composite()) and what tools/pixeldiff/png.lua's PNG.decode() also
-- returns, so this module never cares whether an image came from a real
-- ROM composite or a PNG file on disk.
--
-- Verified: tests/pixeldiff_test.lua exercises identical/differing
-- synthetic images (exact expected percentDiffering/maxDelta/meanDelta
-- arithmetic checked by hand) and a PNG encode/decode round trip.
-- tests/pixeldiff_title_screen_test.lua (ROM-gated) proves this against
-- real project output: compositing the real title screen twice and
-- diffing them reports exactly 0 difference (self-consistency of the
-- deterministic ROM-decode pipeline), and diffing it against a corrupted
-- copy / against a different real map composite reports a large,
-- correctly-computed difference (regression-detection proof).

local PixelDiff = {}

-- imageA, imageB: image-protocol tables (see header). opts (optional):
--   diffThreshold: per-channel delta at/above which a pixel counts as
--     "differing" (default 0 -- any delta at all counts).
--   makeDiffImage: if true and dimensions match, also returns a third
--     value -- an image-protocol table highlighting differing pixels in
--     solid red (255,0,0,255) and matching pixels as a dim greyscale copy
--     of imageA, for visual inspection (e.g. write it out with
--     PNG.encodeToFile).
--
-- Returns a summary table:
--   dimensionsMatch (bool)
--   widthA, heightA, widthB, heightB
--   identical (bool) -- only meaningful/true when dimensionsMatch
--   totalPixels, diffPixelCount, percentDiffering (0-100)
--   maxChannelDelta -- largest single |channel delta| seen anywhere
--   meanDelta -- mean over all pixels of (|dr|+|dg|+|db|+|da|)/4
-- and, if dimensionsMatch is false, that's the whole story -- no
-- per-pixel work is done (matches the task's "report immediately" spec).
function PixelDiff.compare(imageA, imageB, opts)
  opts = opts or {}
  local threshold = opts.diffThreshold or 0

  local summary = {
    widthA = imageA.width, heightA = imageA.height,
    widthB = imageB.width, heightB = imageB.height,
    dimensionsMatch = imageA.width == imageB.width and imageA.height == imageB.height,
  }

  if not summary.dimensionsMatch then
    summary.identical = false
    summary.totalPixels = 0
    summary.diffPixelCount = 0
    summary.percentDiffering = nil
    summary.maxChannelDelta = nil
    summary.meanDelta = nil
    return summary
  end

  local width, height = imageA.width, imageA.height
  local totalPixels = width * height
  local diffPixelCount = 0
  local maxChannelDelta = 0
  local sumDelta = 0 -- sum of per-pixel mean-of-4-channel delta

  local diffPixels -- only populated if opts.makeDiffImage
  if opts.makeDiffImage then diffPixels = {} end

  for y = 0, height - 1 do
    if diffPixels then diffPixels[y] = {} end
    for x = 0, width - 1 do
      local pa, pb = imageA.getPixel(x, y), imageB.getPixel(x, y)
      local dr = math.abs(pa.r - pb.r)
      local dg = math.abs(pa.g - pb.g)
      local db = math.abs(pa.b - pb.b)
      local da = math.abs((pa.a or 0) - (pb.a or 0))
      local pixelMax = math.max(dr, dg, db, da)
      if pixelMax > maxChannelDelta then maxChannelDelta = pixelMax end
      sumDelta = sumDelta + (dr + dg + db + da) / 4
      local differs = pixelMax > threshold
      if differs then diffPixelCount = diffPixelCount + 1 end
      if diffPixels then
        if differs then
          diffPixels[y][x] = { r = 255, g = 0, b = 0, a = 255 }
        else
          -- dim greyscale echo of A so the unchanged regions are still
          -- visually legible context around the highlighted diff.
          local grey = math.floor((pa.r + pa.g + pa.b) / 3 / 2)
          diffPixels[y][x] = { r = grey, g = grey, b = grey, a = 255 }
        end
      end
    end
  end

  summary.identical = diffPixelCount == 0
  summary.totalPixels = totalPixels
  summary.diffPixelCount = diffPixelCount
  summary.percentDiffering = totalPixels > 0 and (diffPixelCount / totalPixels * 100) or 0
  summary.maxChannelDelta = maxChannelDelta
  summary.meanDelta = totalPixels > 0 and (sumDelta / totalPixels) or 0

  local diffImage
  if diffPixels then
    diffImage = {
      width = width, height = height,
      getPixel = function(x, y) return diffPixels[y][x] end,
    }
  end

  return summary, diffImage
end

-- Human-readable one-block report string for CLI / test-log use.
function PixelDiff.formatSummary(summary)
  if not summary.dimensionsMatch then
    return ("DIMENSION MISMATCH: A is %dx%d, B is %dx%d -- images cannot be pixel-compared")
      :format(summary.widthA, summary.heightA, summary.widthB, summary.heightB)
  end
  return ("%dx%d: %s -- %d/%d pixels differ (%.4f%%), max channel delta %d, mean delta %.4f")
    :format(
      summary.widthA, summary.heightA,
      summary.identical and "IDENTICAL" or "DIFFERS",
      summary.diffPixelCount, summary.totalPixels, summary.percentDiffering,
      summary.maxChannelDelta, summary.meanDelta
    )
end

return PixelDiff
