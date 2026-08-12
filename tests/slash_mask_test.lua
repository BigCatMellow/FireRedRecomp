-- Integration test: decodes the real slash sprite as a window mask and
-- checks it against the known real diagonal-band shape (confirmed by
-- ASCII-art render during development -- see SlashMask.lua's header
-- comment). Opt-in via POKEPORT_ROM, skips cleanly otherwise.
--
-- Run: POKEPORT_ROM=/path/to/verified/pokefirered.gba lua5.1 tests/slash_mask_test.lua
package.path = package.path .. ";./?.lua"

local romPath = os.getenv("POKEPORT_ROM")
if not romPath then
  print("SKIP: set POKEPORT_ROM=/path/to/verified/pokefirered.gba to run this test")
  os.exit(0)
end

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local SlashMask = require("import.SlashMask")

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

local isOpaque = SlashMask.decode(data, addrs.sSlash_Gfx)

check("top-left corner is transparent (the band starts further right at the top)", not isOpaque(0, 0))
check("bottom-left corner is transparent (the band has moved right by row 63)", not isOpaque(0, 63))

-- The real shape is a diagonal band running from upper-right to
-- lower-left (confirmed by eye during development): each row's opaque
-- span starts further LEFT as y increases. Verify this diagonal
-- monotonicity directly rather than hardcoding exact column numbers.
local function firstOpaqueColumn(y)
  for x = 0, SlashMask.PIXEL_WIDTH - 1 do
    if isOpaque(x, y) then return x end
  end
  return nil
end

local topStart = firstOpaqueColumn(0)
local midStart = firstOpaqueColumn(32)
local bottomStart = firstOpaqueColumn(63)
check("every sampled row has an opaque span (not an empty/garbage decode)", topStart ~= nil and midStart ~= nil and bottomStart ~= nil)
check("the band's start column decreases monotonically top to bottom (a real diagonal, not noise)", topStart > midStart and midStart > bottomStart, ("top=%s mid=%s bottom=%s"):format(tostring(topStart), tostring(midStart), tostring(bottomStart)))

check("out-of-bounds coordinates are safely transparent", not isOpaque(-1, 0) and not isOpaque(64, 0) and not isOpaque(0, -1) and not isOpaque(0, 64))

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
