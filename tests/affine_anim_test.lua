-- Integration test: decodes real sprite affine animation data (the
-- Pokéball wobble animation) and checks it against the exact
-- AFFINEANIMCMD_FRAME(...) argument lists from the real C source
-- (src/pokeball.c). Opt-in via POKEPORT_ROM, skips cleanly otherwise.
--
-- Run: POKEPORT_ROM=/path/to/verified/pokefirered.gba lua5.1 tests/affine_anim_test.lua
package.path = package.path .. ";./?.lua"

local romPath = os.getenv("POKEPORT_ROM")
if not romPath then
  print("SKIP: set POKEPORT_ROM=/path/to/verified/pokefirered.gba to run this test")
  os.exit(0)
end

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local AffineAnim = require("import.AffineAnim")

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

-- Real source: AFFINEANIMCMD_FRAME(256, 256, 0, 0), AFFINEANIMCMD_END.
local rotate3 = AffineAnim.decodeCmds(data, addrs.sAffineAnim_BallRotate_3)
check("BallRotate_3 decodes exactly 2 entries", #rotate3 == 2, #rotate3)
check("BallRotate_3 frame 0 is the identity scale (256,256,0,0)", rotate3[1].type == "frame" and rotate3[1].xScale == 256 and rotate3[1].yScale == 256 and rotate3[1].rotation == 0 and rotate3[1].duration == 0)
check("BallRotate_3 terminates with END", rotate3[2].type == "end")

-- Real source: AFFINEANIMCMD_FRAME(0, 0, -3, 1), then (per the real
-- disassembly-confirmed layout) a JUMP back to index 0 -- rotation is a
-- real u8 field, so -3 wraps to 253.
local rotateRight = AffineAnim.decodeCmds(data, addrs.sAffineAnim_BallRotate_Right)
check("BallRotate_Right decodes exactly 2 entries", #rotateRight == 2, #rotateRight)
check("BallRotate_Right frame 0 matches FRAME(0,0,-3,1) (rotation wraps to u8 253)", rotateRight[1].type == "frame" and rotateRight[1].xScale == 0 and rotateRight[1].yScale == 0 and rotateRight[1].rotation == 253 and rotateRight[1].duration == 1)
check("BallRotate_Right loops back to index 0", rotateRight[2].type == "jump" and rotateRight[2].target == 0)

-- Real source: AFFINEANIMCMD_FRAME(0, 0, 3, 1), same loop-back shape.
local rotateLeft = AffineAnim.decodeCmds(data, addrs.sAffineAnim_BallRotate_Left)
check("BallRotate_Left frame 0 matches FRAME(0,0,3,1)", rotateLeft[1].type == "frame" and rotateLeft[1].rotation == 3 and rotateLeft[1].duration == 1)
check("BallRotate_Left loops back to index 0", rotateLeft[2].type == "jump" and rotateLeft[2].target == 0)

-- Real source: AFFINEANIMCMD_FRAME(0, 0, 0, 1), same loop-back shape --
-- the "hold still" idle variant.
local rotate0 = AffineAnim.decodeCmds(data, addrs.sAffineAnim_BallRotate_0)
check("BallRotate_0 frame 0 matches FRAME(0,0,0,1)", rotate0[1].type == "frame" and rotate0[1].rotation == 0 and rotate0[1].duration == 1)
check("BallRotate_0 loops back to index 0", rotate0[2].type == "jump" and rotate0[2].target == 0)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
