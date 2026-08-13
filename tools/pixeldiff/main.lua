-- CLI for the pixel-diff tool: compares two PNG files and prints a
-- summary (dimension check, %-differing, max/mean channel delta),
-- optionally writing a red-highlighted diff-visualization PNG.
--
-- Plain Lua script, not a LÖVE2D project -- see tools/pixeldiff/png.lua's
-- header for why (zero love.image dependency, so this runs under plain
-- `lua5.1` like every other tool/test in this repo).
--
-- Usage:
--   lua5.1 tools/pixeldiff/main.lua <imageA.png> <imageB.png> [diffOut.png]
--
-- Exit code 0 if images are identical (or within --threshold), 1 if they
-- differ, 2 on a usage/load error.
package.path = package.path .. ";./?.lua"

local PNG = require("tools.pixeldiff.png")
local PixelDiff = require("tools.pixeldiff.init")

local pathA, pathB, diffOutPath = arg[1], arg[2], arg[3]
if not pathA or not pathB then
  print("usage: lua5.1 tools/pixeldiff/main.lua <imageA.png> <imageB.png> [diffOut.png]")
  os.exit(2)
end

local imageA, errA = PNG.decodeFile(pathA)
if not imageA then
  print("error loading " .. pathA .. ": " .. tostring(errA))
  os.exit(2)
end

local imageB, errB = PNG.decodeFile(pathB)
if not imageB then
  print("error loading " .. pathB .. ": " .. tostring(errB))
  os.exit(2)
end

local summary, diffImage = PixelDiff.compare(imageA, imageB, { makeDiffImage = diffOutPath ~= nil })
print(PixelDiff.formatSummary(summary))

if diffOutPath and diffImage then
  local ok, ferr = PNG.encodeToFile(diffImage, diffOutPath)
  if ok then
    print("diff visualization written to " .. diffOutPath)
  else
    print("failed to write diff visualization: " .. tostring(ferr))
  end
end

os.exit((summary.dimensionsMatch and summary.identical) and 0 or 1)
