-- Unit test: verifies SpriteAnimator's frame-duration ticking, jump
-- looping, and end-freezing behavior against synthetic AnimCmd-shaped
-- command lists (SpriteAnim.decodeCmds' output shape) -- no ROM needed.
-- Run: lua5.1 tests/sprite_animator_test.lua
package.path = package.path .. ";./?.lua"
local SpriteAnimator = require("src.core.SpriteAnimator")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local function frame(imageValue, duration) return { type = "frame", imageValue = imageValue, duration = duration } end

-- Basic frame holding: each frame displays for exactly `duration` ticks
-- before advancing.
do
  local cmds = { frame(0, 3), frame(4, 2), { type = "end" } }
  local a = SpriteAnimator.new(cmds)
  check("starts on the first frame", a:currentFrame().imageValue == 0)
  a:tick(); a:tick()
  check("still on frame 0 after 2 of 3 ticks", a:currentFrame().imageValue == 0)
  a:tick()
  check("advances to frame 1 on the 3rd tick", a:currentFrame().imageValue == 4)
  a:tick()
  check("still on frame 1 after 1 of 2 ticks", a:currentFrame().imageValue == 4)
  a:tick()
  check("reaching END freezes on the last real frame", a:currentFrame().imageValue == 4 and a.ended)
  a:tick(); a:tick(); a:tick()
  check("stays frozen indefinitely after END, no matter how many more ticks", a:currentFrame().imageValue == 4)
end

-- ANIMCMD_JUMP loops back to an earlier (or any) index in the same list --
-- verified against the real sSpriteAnim_Leaf (LeafGreen's title screen
-- animation, which uses ANIMCMD_JUMP(0) to loop forever, unlike FireRed's
-- flame animation which ends).
do
  local cmds = { frame(0, 1), frame(4, 1), frame(8, 1), { type = "jump", target = 0 } }
  local a = SpriteAnimator.new(cmds)
  local seen = {}
  for i = 1, 7 do
    seen[#seen + 1] = a:currentFrame().imageValue
    a:tick()
  end
  check("jump loops the animation back to the target frame indefinitely", table.concat(seen, ",") == "0,4,8,0,4,8,0", table.concat(seen, ","))
  check("looping animation never sets ended", not a.ended)
end

-- A jump target other than 0 still resolves correctly (not hardcoded to
-- "restart from the beginning").
do
  local cmds = { frame(0, 1), frame(4, 1), frame(8, 1), { type = "jump", target = 1 } }
  local a = SpriteAnimator.new(cmds)
  local seen = {}
  for i = 1, 6 do
    seen[#seen + 1] = a:currentFrame().imageValue
    a:tick()
  end
  check("jump to a non-zero target loops from that frame, not frame 0", table.concat(seen, ",") == "0,4,8,4,8,4", table.concat(seen, ","))
end

-- hFlip/vFlip pass through untouched on the current frame.
do
  local cmds = { { type = "frame", imageValue = 0, duration = 5, hFlip = true, vFlip = false }, { type = "end" } }
  local a = SpriteAnimator.new(cmds)
  check("hFlip/vFlip are exposed on the current frame", a:currentFrame().hFlip == true and a:currentFrame().vFlip == false)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
