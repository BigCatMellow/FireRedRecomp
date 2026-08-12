-- Run: lua5.1 tests/metatile_test.lua
package.path = package.path .. ";./?.lua"
local Metatile = require("import.Metatile")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- Real metatile 2 from Pallet Town's primary tileset: bottom layer is tile
-- 19 (flat ground) repeated 4x with palette 0; top layer is tiles
-- 304,305,320,321 with palette 2. Values confirmed against the built ROM.
local function tileEntry(tileId, hFlip, vFlip, palette)
  local v = tileId + (hFlip and 1024 or 0) + (vFlip and 2048 or 0) + palette * 4096
  return string.char(v % 256, math.floor(v / 256) % 256)
end

local metatileBlob = tileEntry(19, false, false, 0)
  .. tileEntry(19, false, false, 0)
  .. tileEntry(19, false, false, 0)
  .. tileEntry(19, false, false, 0)
  .. tileEntry(304, false, false, 2)
  .. tileEntry(305, false, false, 2)
  .. tileEntry(320, false, false, 2)
  .. tileEntry(321, false, false, 2)

check("metatile fixture is 16 bytes (8 entries x 2 bytes)", #metatileBlob == 16)

local entries = Metatile.resolve(metatileBlob, 0, 0)
check("bottom-left tile", entries[0].tileId == 19 and entries[0].palette == 0)
check("top-left tile", entries[4].tileId == 304 and entries[4].palette == 2)
check("top-right tile", entries[7].tileId == 321 and entries[7].palette == 2)

-- Flip bits: tileId=5, hFlip=true, vFlip=true, palette=9.
local flipped = Metatile.decodeTileEntry(5 + 1024 + 2048 + 9 * 4096)
check("hFlip decodes", flipped.hFlip == true)
check("vFlip decodes", flipped.vFlip == true)
check("palette decodes", flipped.palette == 9, flipped.palette)
check("tileId decodes under flip/palette bits", flipped.tileId == 5, flipped.tileId)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
