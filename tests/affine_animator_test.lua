-- Unit test: verifies AffineAnimator's frame-duration ticking, jump
-- looping, and the module's documented simplified scale(absolute)/
-- rotation(accumulating) value semantics -- against synthetic
-- AffineAnim.decodeCmds-shaped command lists (no ROM needed).
-- Run: lua5.1 tests/affine_animator_test.lua
package.path = package.path .. ";./?.lua"
local AffineAnimator = require("src.core.AffineAnimator")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local function frame(xScale, yScale, rotation, duration)
  return { type = "frame", xScale = xScale, yScale = yScale, rotation = rotation, duration = duration }
end

-- Starts at the real identity state (1.0x scale, 0 rotation) before any
-- frame is applied, then immediately applies frame 0 on construction
-- (matching real BeginAffineAnim applying the first frame right away).
do
  local a = AffineAnimator.new({ frame(256, 256, 0, 0), { type = "end" } })
  check("applies frame 0's identity scale immediately on construction", a.xScale == 1 and a.yScale == 1)
end

-- Scale is applied absolute per frame (real AFFINEANIMCMD_FRAME(256,256,...)
-- clearly means "set to 1.0x", not "add 256").
do
  local a = AffineAnimator.new({ frame(512, 128, 0, 2), frame(256, 256, 0, 1), { type = "end" } })
  check("frame 0 scale is absolute (2.0x, 0.5x)", a.xScale == 2 and a.yScale == 0.5)
  a:tick(); a:tick()
  check("frame 1 scale replaces (not adds to) frame 0's", a.xScale == 1 and a.yScale == 1)
end

-- A literal 0 scale value means "don't touch this axis" -- real
-- rotation-only wobble data (sAffineAnim_BallRotate_Right etc.) has
-- xScale=yScale=0, and must NOT collapse the sprite to nothing.
do
  local a = AffineAnimator.new({ frame(512, 512, 0, 5), frame(0, 0, 10, 1), { type = "end" } })
  check("starts at frame 0's real absolute scale (2.0x)", a.xScale == 2 and a.yScale == 2)
  for i = 1, 5 do a:tick() end
  check("a zero-scale frame leaves the previous scale untouched, not zeroed", a.xScale == 2 and a.yScale == 2)
end

-- Rotation accumulates across frame activations (real small deltas like
-- -3/+3 mean "turn a bit more", matching the real Pokéball wobble data).
do
  local a = AffineAnimator.new({ frame(0, 0, 10, 1), frame(0, 0, 10, 1), { type = "jump", target = 1 } })
  local firstAngle = a.rotationAngle
  a:tick() -- advance to frame 1 (10 more)
  check("rotation accumulates across frame transitions", a.rotationAngle > firstAngle)
  local secondAngle = a.rotationAngle
  a:tick() -- jump back to frame 1, reapplies its +10 delta again
  check("looping back re-accumulates the same delta again", a.rotationAngle > secondAngle)
end

-- Negative (wrapped-to-u8) rotation deltas decrease the angle -- real
-- sAffineAnim_BallRotate_Right stores -3 as the u8 253. Starts from a
-- non-zero angle so the expected decrease doesn't fall exactly on the
-- 0/1 wraparound boundary (a small negative delta from angle 0 wraps to
-- just-under-1.0, which is mathematically correct but numerically
-- *larger* than 0 -- not a useful "did it decrease" comparison).
do
  local a = AffineAnimator.new({ frame(0, 0, 64, 1), frame(0, 0, 253, 1), { type = "end" } }) -- 64/256 = quarter turn, then -3
  local before = a.rotationAngle
  a:tick()
  check("a wrapped-negative rotation byte (253 = -3) decreases the angle", a.rotationAngle < before, a.rotationAngle)
end

-- rotationRadians() converts the 0..1 fraction to real radians.
do
  local a = AffineAnimator.new({ frame(0, 0, 128, 1), { type = "end" } }) -- 128/256 = half a turn
  local rad = a:rotationRadians()
  check("half a turn (rotation byte 128) is pi radians", math.abs(rad - math.pi) < 0.001, rad)
end

-- Duration gating: a frame holds for its real duration before advancing.
do
  local a = AffineAnimator.new({ frame(256, 256, 0, 3), frame(512, 512, 0, 1), { type = "end" } })
  a:tick(); a:tick()
  check("still on frame 0 after 2 of 3 ticks", a.xScale == 1)
  a:tick()
  check("advances to frame 1 on the 3rd tick", a.xScale == 2)
end

-- Reaching END freezes the animator (matches SpriteAnimator's real
-- animEnded-checked-by-caller convention).
do
  local a = AffineAnimator.new({ frame(256, 256, 0, 1), { type = "end" } })
  a:tick()
  check("reaching END sets ended", a.ended)
  local xBefore = a.xScale
  a:tick(); a:tick()
  check("stays frozen after END regardless of further ticks", a.ended and a.xScale == xBefore)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
